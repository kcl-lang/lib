import Foundation

/// Signature of a KCL plugin method implementation. `args` holds the
/// positional arguments and `kwargs` the keyword arguments the KCL code
/// passed, both JSON-decoded (`null` becomes `nil`). The return value is
/// JSON-serialized back into the KCL value; `nil` serializes to `None`.
/// Throwing fails the surrounding KCL evaluation with the error message.
public typealias KclPluginMethod = (_ args: [Any?], _ kwargs: [String: Any?]) throws -> Any?

/// Registry of host functions callable from KCL through the plugin protocol:
///
/// ```kcl
/// import kcl_plugin.my_plugin
/// result = my_plugin.add(1, 1)
/// ```
///
/// Mirrors the Python binding's `PluginContext` / `register_plugin`.
public final class PluginContext {

  /// The error key the runtime looks for to turn a plugin failure into a
  /// KCL evaluation error (crates/runtime/src/stdlib/plugin.rs).
  static let panicInfoKey = "__kcl_PanicInfo__"

  private var pluginMap: [String: [String: KclPluginMethod]] = [:]
  private let lock = NSLock()

  public init() {}

  /// Registers (or replaces) the method table of the plugin imported as
  /// `kcl_plugin.<name>`.
  public func registerPlugin(_ name: String, methods: [String: KclPluginMethod]) {
    lock.lock()
    pluginMap[name] = methods
    lock.unlock()
  }

  /// Registers (or replaces) a single method on a plugin, leaving the
  /// plugin's other methods untouched.
  public func registerMethod(
    _ plugin: String, name method: String, callback: @escaping KclPluginMethod
  ) {
    lock.lock()
    var methods = pluginMap[plugin] ?? [:]
    methods[method] = callback
    pluginMap[plugin] = methods
    lock.unlock()
  }

  /// Dispatches one plugin invocation coming from the runtime through the
  /// C trampoline. Mirrors `PluginContext.call_method` in the Python
  /// binding: parses `kcl_plugin.<plugin>.<method>`, decodes the JSON
  /// arguments, invokes the registered closure and re-encodes the result.
  /// Any error is reported back to the runtime as a `__kcl_PanicInfo__`
  /// payload, which surfaces in the run's `err_message`.
  func callMethod(_ name: String, argsJson: String, kwargsJson: String) -> String {
    do {
      return try callMethodUnsafe(name, argsJson: argsJson, kwargsJson: kwargsJson)
    } catch {
      return PluginContext.panicInfo("\(error)")
    }
  }

  private func callMethodUnsafe(_ name: String, argsJson: String, kwargsJson: String) throws
    -> String
  {
    // "kcl_plugin.<module_path>.<method_name>"
    guard let dotIdx = name.lastIndex(of: ".") else {
      return ""
    }
    let modulePath = name[..<dotIdx]
    let methodName = name[name.index(after: dotIdx)...]
    let pluginName = modulePath.lastIndex(of: ".").map {
      modulePath[modulePath.index(after: $0)...]
    } ?? modulePath

    // Copy the closure out under the lock but invoke it unlocked: the
    // closure may run nested KCL evaluation (e.g. a plugin that renders
    // another package), which would deadlock on a non-reentrant lock —
    // the same fix crates/runtime/src/stdlib/plugin.rs applied to its own
    // dispatch lock.
    lock.lock()
    let method = pluginMap[String(pluginName)]?[String(methodName)]
    lock.unlock()

    // Python: malformed JSON raises out of `json.loads`; a decoded payload
    // that is not a list/dict yields "" (which the runtime rejects as an
    // invalid plugin result); an empty payload means no arguments.
    let argsValue: Any? = argsJson.isEmpty ? nil : try decodeJson(argsJson)
    if let argsValue, !(argsValue is [Any]) {
      return ""
    }
    let kwargsValue: Any? = kwargsJson.isEmpty ? nil : try decodeJson(kwargsJson)
    if let kwargsValue, !(kwargsValue is [String: Any]) {
      return ""
    }

    let args = (argsValue as? [Any])?.map { $0 is NSNull ? nil : $0 } ?? []
    let kwargs = (kwargsValue as? [String: Any])?.mapValues { $0 is NSNull ? nil : $0 } ?? [:]

    let result = try method?(args, kwargs) as Any?
    return try encodeResult(result)
  }

  private func decodeJson(_ json: String) throws -> Any {
    guard let data = json.data(using: .utf8) else {
      throw KclError.runtime("plugin arguments are not valid UTF-8")
    }
    return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
  }

  /// Python: `json.dumps(result)` — `None` serializes to "null", and a
  /// non-serializable result raises (surfacing as `__kcl_PanicInfo__`).
  private func encodeResult(_ result: Any?) throws -> String {
    let value: Any = (result as Any?) is NSNull ? NSNull() : (result ?? NSNull())
    let data = try JSONSerialization.data(
      withJSONObject: value, options: [.fragmentsAllowed])
    return String(data: data, encoding: .utf8) ?? ""
  }

  static func panicInfo(_ message: String) -> String {
    let data = try? JSONSerialization.data(withJSONObject: [panicInfoKey: message])
    return data.flatMap { String(data: $0, encoding: .utf8) }
      ?? #"{"__kcl_PanicInfo__":"plugin invocation failed"}"#
  }
}

/// Global link between the native plugin trampoline and the attached
/// context. The trampoline is a bare C function pointer that receives no
/// user data, so the active context has to live in a global — the same
/// trade-off as the Python binding's module-level `__plugin_context__` and
/// .NET's static `API.pluginContext`: one context is active per process,
/// and attaching a new one replaces the previous.
enum PluginAgentRegistry {

  /// The C entry point invoked by the runtime for every
  /// `kcl_plugin.<name>.<method>` call. The runtime transmutes this
  /// address back into
  /// `extern "C-unwind" fn(*const c_char, *const c_char, *const c_char) -> *const c_char`.
  /// It must not throw: failures are encoded as `__kcl_PanicInfo__` JSON.
  private static let entry: @convention(c) (
    UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?
  ) -> UnsafePointer<CChar>? = { method, argsJson, kwargsJson in
    let methodString = method.map { String(cString: $0) } ?? ""
    let argsString = argsJson.map { String(cString: $0) } ?? ""
    let kwargsString = kwargsJson.map { String(cString: $0) } ?? ""
    let result = current()?.callMethod(
      methodString, argsJson: argsString, kwargsJson: kwargsString) ?? ""
    return PluginResultBuffer.store(result)
  }

  /// Address of `entry` as a plain integer for `kcl_service_new`.
  static let pointer: UInt64 = UInt64(
    UInt(bitPattern: unsafeBitCast(entry, to: UnsafeRawPointer.self)))

  private static let lock = NSLock()
  private static var active: PluginContext?

  static func attach(_ context: PluginContext) {
    lock.lock()
    active = context
    lock.unlock()
  }

  static func detach(_ context: PluginContext) {
    lock.lock()
    if active === context {
      active = nil
    }
    lock.unlock()
  }

  private static func current() -> PluginContext? {
    lock.lock()
    let context = active
    lock.unlock()
    return context
  }
}

/// Ownership for the JSON string the trampoline hands back to native code.
/// The runtime reads the returned pointer synchronously inside
/// `kcl_plugin_invoke_json` and never frees it. The buffer is written as
/// the very last step of the callback — after any nested KCL evaluation
/// triggered by the closure has completed — and native consumes it before
/// the next callback can run, so a single slot per thread is safe. This
/// mirrors the Python binding's global `__plugin_method_agent_buffer__`,
/// but thread-local so concurrent evaluations on different threads don't
/// race. One buffer per thread lingers until that thread's next plugin
/// call; the bound is one small string per thread.
private enum PluginResultBuffer {
  private static let key = "org.kcl-lang.KclLib.pluginResultBuffer"

  static func store(_ string: String) -> UnsafePointer<CChar>? {
    var bytes = Array(string.utf8)
    bytes.append(0)
    let buffer = NSMutableData(bytes: bytes, length: bytes.count)
    Thread.current.threadDictionary[Self.key] = buffer
    return UnsafeRawPointer(buffer.mutableBytes).assumingMemoryBound(to: CChar.self)
  }
}

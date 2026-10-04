// KCL plugin support for the Dart binding.
//
// KCL source can call host functions as `kcl_plugin.<plugin>.<method>(...)`.
// The runtime resolves those names by invoking a plugin-agent callback with
// the method name plus JSON-encoded args/kwargs, and reads back a JSON-encoded
// result (docs/abi.md §7). Python, .NET, Go, Node.js, Java, Kotlin, Ruby,
// Swift, C, C++, Zig and Julia all ship such an agent; this brings the same
// capability to Dart.
//
// ```dart
// import 'package:kcl_lib/kcl_lib.dart';
//
// registerPlugin('strings', 'join', (args, kwargs) => '"KCL.KCL.123"');
//
// final result = execProgram(ExecProgramArgs(
//   kCodeList: ['import kcl_plugin.strings\nresult = strings.join("KCL", "KCL", 123)\n'],
// ));
// ```
//
// Registering the first method binds a `kcl_service_new` handle carrying the
// agent, after which every RPC dispatches through it. With nothing registered
// the binding keeps using the stateless `call_native` entry point, so programs
// that do not use plugins are unaffected.
//
// Two properties are worth calling out:
//
//   + **No JSON dependency.** Arguments arrive as raw JSON strings and the
//     result must be JSON-encoded, so a method that ignores its arguments needs
//     no parser at all. One that inspects them can add `dart:convert`.
//   + **Errors are data, not crashes.** Calling a method that was never
//     registered — or one that threw — yields a
//     `{"__kcl_PanicInfo__": "..."}` object, matching what Go's
//     `plugin.JSONError` and Python's `_call_py_method` return, so it surfaces
//     through the normal `err_message` path rather than as a native crash.
//
// Threading: the registry is process-wide and the agent is isolate-local, so
// the callback runs on the mutator thread of the isolate that registered it —
// the same thread that drives `execProgram`. Register methods during start-up,
// before any KCL evaluation runs, the same way Go registers them from `init()`.

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'kcl_lib_ffi.dart';

/// A plugin method. Receives the JSON-encoded positional arguments and the
/// JSON-encoded keyword arguments (either may be empty), and returns a
/// JSON-encoded result. Throwing is allowed — the exception is reported to the
/// runtime as a `__kcl_PanicInfo__` object.
typedef PluginMethod = String Function(String args, String kwargs);

const String _pluginPrefix = 'kcl_plugin.';

/// The registered `kcl_plugin.<plugin>.<method>` methods.
final Map<String, PluginMethod> _registry = <String, PluginMethod>{};

/// The reply handed back to the runtime. The runtime parses it as soon as the
/// agent returns and never frees the pointer, so one buffer is enough — and a
/// plugin method must not hold on to the previous result. A nested evaluation
/// (a method that itself calls `execProgram`) re-enters this agent, but it does
/// so *before* the outer invocation writes its own reply, so the outer pointer
/// is never stale.
Pointer<Uint8>? _reply;

/// How many payload bytes `_reply` can hold, excluding the trailing NUL.
int _replyCapacity = 0;

/// Keeps the `NativeCallable` (and therefore this isolate) alive for as long
/// as the agent is installed. Closing it invalidates the native function
/// pointer, so it is only closed by [disablePlugins].
NativeCallable<NativePluginAgent>? _callable;

/// The C signature of the plugin agent:
/// `const char *(*)(const char *method, const char *args, const char *kwargs)`.
typedef NativePluginAgent = Pointer<Utf8> Function(
  Pointer<Utf8> method,
  Pointer<Utf8> args,
  Pointer<Utf8> kwargs,
);

/// The Dart-side signature of the same function.
typedef PluginAgent = Pointer<Utf8> Function(
  Pointer<Utf8> method,
  Pointer<Utf8> args,
  Pointer<Utf8> kwargs,
);

/// Copy `text` into the shared reply buffer, NUL-terminated, and return it as
/// a C string. The buffer grows to fit and is reused afterwards.
Pointer<Utf8> _setReply(String text) {
  final bytes = utf8.encode(text);
  final stale = _reply;
  if (stale == null || bytes.length > _replyCapacity) {
    _reply = calloc<Uint8>(bytes.length + 1);
    if (stale != null) calloc.free(stale);
    _replyCapacity = bytes.length;
  }
  final buffer = _reply!;
  buffer.asTypedList(bytes.length).setAll(0, bytes);
  buffer[bytes.length] = 0;
  return buffer.cast<Utf8>();
}

/// Build `{"__kcl_PanicInfo__":"<message>"}`, the same shape Go's
/// `plugin.JSONError` and Python's `_call_py_method` produce.
String _panicInfo(String message) {
  final escaped = StringBuffer('"');
  for (final ch in message.codeUnits) {
    switch (ch) {
      case 0x22: // "
        escaped.write(r'\"');
        break;
      case 0x5C: // \
        escaped.write(r'\\');
        break;
      case 0x0A:
        escaped.write(r'\n');
        break;
      case 0x0D:
        escaped.write(r'\r');
        break;
      case 0x09:
        escaped.write(r'\t');
        break;
      default:
        // `\u` needs four hex digits; the control characters a Dart exception
        // message can realistically carry are all below 0x20.
        if (ch < 0x20) {
          escaped.write('\\u${ch.toRadixString(16).padLeft(4, '0')}');
        } else {
          escaped.writeCharCode(ch);
        }
        break;
    }
  }
  escaped.write('"');
  return '{"__kcl_PanicInfo__":$escaped}';
}

/// The C entry point the KCL runtime calls. `method` is the fully-qualified
/// plugin name; `args` / `kwargs` are the JSON arguments. The runtime sends
/// the fully-qualified name, which is exactly the key [registerPlugin] stored.
///
/// `NativeCallable` substitutes `exceptionalReturn` if an exception escapes,
/// but a null reply would be worse than a diagnostic — so every failure is
/// turned into a `__kcl_PanicInfo__` object here instead.
Pointer<Utf8> _onAgent(
    Pointer<Utf8> method, Pointer<Utf8> args, Pointer<Utf8> kwargs) {
  final name = method == nullptr ? '' : method.toDartString();
  final target = _registry[name];
  if (target == null) {
    return _setReply(_panicInfo('invalid method: $name is not found'));
  }
  try {
    final result =
        target(args == nullptr ? '' : args.toDartString(), kwargs == nullptr ? '' : kwargs.toDartString());
    return _setReply(result);
  } catch (err) {
    return _setReply(_panicInfo(err.toString()));
  }
}

/// Add or replace `kcl_plugin.<plugin>.<method>`, binding the runtime to the
/// agent on the first registration. Register methods at start-up: nothing
/// evaluated before the first registration can reach the plugin.
///
/// The method is called as `fn(args, kwargs) -> String` where both arguments
/// are the raw JSON the runtime sends, and it must return a JSON-encoded
/// result.
void registerPlugin(String plugin, String method, PluginMethod fn) {
  if (plugin.isEmpty || method.isEmpty) {
    throw ArgumentError(
        'registerPlugin: plugin and method names must not be empty');
  }
  _registry['$_pluginPrefix$plugin.$method'] = fn;
  if (_callable == null) {
    _callable = NativeCallable<NativePluginAgent>.isolateLocal(_onAgent);
    LibKcl().bindService(_callable!.nativeFunction.address);
  }
}

/// Whether `kcl_plugin.<plugin>.<method>` resolves to a registered method.
bool pluginRegistered(String plugin, String method) =>
    _registry.containsKey('$_pluginPrefix$plugin.$method');

/// Whether any plugin method is currently registered.
bool hasPlugins() => _registry.isNotEmpty;

/// Drop every registered method and unbind the runtime, returning the binding
/// to the stateless `call_native` path.
void disablePlugins() {
  if (_callable != null) {
    LibKcl().unbindService();
    // Closing invalidates the native function pointer, so it has to happen
    // after the handle that carries it is gone.
    _callable!.close();
    _callable = null;
  }
  _registry.clear();
  final reply = _reply;
  if (reply != null) {
    calloc.free(reply);
  }
  _reply = null;
  _replyCapacity = 0;
}

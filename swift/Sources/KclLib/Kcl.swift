import Foundation

/// High-level facade over the protobuf-shaped `API` RPC layer, mirroring the
/// ergonomic surface of kcl-go's `pkg/kcl` and the Python/.NET/Java facades
/// of this repo: `Kcl.run` evaluates in-memory source, `Kcl.runFiles`
/// evaluates files, and every failure throws `KclError` — a non-empty runtime
/// `err_message`, a failed native call, or invalid options.
public enum Kcl {

  // MARK: - Entry points

  /// Evaluate in-memory KCL `code` and return the parsed documents.
  ///
  /// The positional `code` merges after the options, matching kcl-go's
  /// `ParseArgs` ordering (options first, positional input appended last).
  public static func run(_ code: String, options: KclOptions = KclOptions()) throws
    -> KclResultList
  {
    try runInternal(positionalCodes: [code], positionalPaths: [], options: options)
  }

  /// Evaluate the KCL file(s) at `paths` and return the parsed documents.
  /// The paths may be empty when `options.settings` provides input files.
  public static func runFiles(_ paths: [String], options: KclOptions = KclOptions()) throws
    -> KclResultList
  {
    try runInternal(positionalCodes: [], positionalPaths: paths, options: options)
  }

  /// Validate `data` against the schema defined in `code` in memory, using
  /// the `ValidateCode` RPC. Returns the runtime's success flag; a validation
  /// failure returns `false` rather than throwing.
  public static func validate(code: String, data: String, format: String = "yaml") throws
    -> Bool
  {
    var args = ValidateCodeArgs()
    args.code = code
    args.data = data
    args.format = format
    return try API().validateCode(args).success
  }

  /// Split a YAML stream into its documents on `---` separator lines
  /// (trailing whitespace or `#` comments allowed), mirroring kcl-go's
  /// exported `SplitDocuments`. Anything else on the separator line throws.
  public static func splitDocuments(_ text: String) throws -> [String] {
    var docs: [String] = []
    if text.isEmpty {
      return docs
    }
    var current: [String] = []
    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = rawLine.hasSuffix("\r") ? rawLine.dropLast() : rawLine
      if line.hasPrefix("---") {
        let rest = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty && !rest.hasPrefix("#") {
          throw KclError.runtime(
            "invalid document separator: \(line.trimmingCharacters(in: .whitespaces))")
        }
        docs.append(current.joined(separator: "\n"))
        current = []
      } else {
        current.append(String(rawLine))
      }
    }
    docs.append(current.joined(separator: "\n"))
    // Drop empty documents (e.g. a leading separator).
    return docs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  // MARK: - Internal plumbing

  private static func runInternal(
    positionalCodes: [String], positionalPaths: [String], options: KclOptions
  ) throws -> KclResultList {
    var bag = KclOptionBag()
    // 1. Settings files form the base layer. They are resolved by the
    //    runtime through the LoadSettingsFiles RPC — no YAML parsing happens
    //    in Swift.
    if !options.settings.isEmpty {
      try bag.merge(settingsFiles: options.settings, workDir: options.workDir ?? ".")
    }
    // 2. Explicit option fields overlay the file: repeated fields append,
    //    scalar fields are last-wins.
    bag.overlay(options)
    // 3. The positional inputs merge last, matching kcl-go's ParseArgs.
    bag.kCodeList.append(contentsOf: positionalCodes)
    bag.kFilenameList.append(contentsOf: positionalPaths)
    guard !bag.kCodeList.isEmpty || !bag.kFilenameList.isEmpty else {
      throw KclError.runtime("kcl.Run: no kcl file or code")
    }
    let resp = try API().execProgram(bag.makeExecProgramArgs())
    return try wrapResult(resp, bag: bag)
  }

  /// Port of kcl-go's `ExecResultToKCLResult`: raise a non-empty
  /// `err_message`, forward `log_message` to the configured logger, then
  /// pair the YAML documents (split on `---`) with the values of the JSON
  /// result stream by position.
  private static func wrapResult(_ resp: ExecProgramResult, bag: KclOptionBag) throws
    -> KclResultList
  {
    if !resp.errMessage.isEmpty {
      throw KclError.runtime(resp.errMessage)
    }
    if let logger = bag.logger, !resp.logMessage.isEmpty {
      logger(resp.logMessage)
    }

    let isBlank = { (s: String) in
      s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    if isBlank(resp.yamlResult) && isBlank(resp.jsonResult) {
      return KclResultList(
        results: [], yamlResult: resp.yamlResult, jsonResult: resp.jsonResult,
        logMessage: resp.logMessage, errMessage: resp.errMessage)
    }

    let documents = try splitDocuments(resp.yamlResult)
    let stream = parseJsonStream(resp.jsonResult)
    var results: [KclResult] = []
    for i in 0..<max(documents.count, stream.values.count) {
      var yamlDoc = i < documents.count ? documents[i] : ""
      var jsonDoc = i < stream.lines.count ? stream.lines[i] : nil
      var value: Any? = i < stream.values.count ? stream.values[i] : nil
      if let v = value, bag.includeSchemaTypePath == true, !bag.fullTypePath {
        // kcl-go's DefaultHooks: with include_schema_type_path (and no full
        // type path requested) every `_type` attribute is rewritten to its
        // last path segment. The raw list-level payloads stay unmodified;
        // the rewritten tree is re-rendered into this document's strings.
        value = TypeAttributeHook.rewrite(v)
        jsonDoc = FacadeJson.string(value)
        yamlDoc = YamlEmitter.render(value)
      }
      if value == nil && jsonDoc == nil
        && yamlDoc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        continue
      }
      results.append(
        KclResult(value: value, yamlDocument: yamlDoc, jsonDocument: jsonDoc))
    }
    return KclResultList(
      results: results, yamlResult: resp.yamlResult, jsonResult: resp.jsonResult,
      logMessage: resp.logMessage, errMessage: resp.errMessage)
  }

  /// Parse the runtime's `json_result`. It is usually one compact JSON value
  /// per line (a JSON stream for multi-document results); a pretty-printed
  /// single document is accepted as a fallback.
  private static func parseJsonStream(_ json: String) -> (values: [Any], lines: [String]) {
    let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty,
      let data = trimmed.data(using: .utf8),
      let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    {
      return ([value], [trimmed])
    }
    var values: [Any] = []
    var lines: [String] = []
    for rawLine in json.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = rawLine.trimmingCharacters(in: .whitespaces)
      if line.isEmpty {
        continue
      }
      guard let data = line.data(using: .utf8),
        let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
      else {
        continue
      }
      values.append(value)
      lines.append(line)
    }
    return (values, lines)
  }
}

// MARK: - Options

/// Value-type option bag accepted by `Kcl.run` / `Kcl.runFiles`, covering the
/// union of the kcl-go `With*` options and the Python/.NET facade fields.
///
/// Repeated fields (`code`, `args`, `overrides`, `selectors`, `settings`,
/// `externalPkgs`) replace their settings-file counterparts when non-empty;
/// optional scalars (`Bool?` / `String?` / `Int32?`) overlay the settings
/// file only when set, so an explicit `false` wins over the file. Everything
/// is appended after the settings-file values, mirroring kcl-go's
/// `Option.Merge` order semantics.
public struct KclOptions {
  /// Working directory for the evaluation; also handed to the settings RPC.
  public var workDir: String?
  /// Additional in-memory KCL sources (kcl-go `WithCode`).
  public var code: [String]
  /// `option("key")` arguments in `key=value` form (the `-D` flag).
  /// Entries without an `=` separator (or with an empty key) are ignored,
  /// matching kcl-go's `WithOptions`.
  public var args: [String]
  /// Override specs (the `-O` flag).
  public var overrides: [String]
  /// Path selectors (the `-S` flag).
  public var selectors: [String]
  /// `kcl.yaml` settings file paths, resolved through the `LoadSettingsFiles`
  /// RPC. Note: the settings file paths themselves are resolved against the
  /// process working directory (native runtime behavior); the `files` entries
  /// inside them resolve against `workDir`.
  public var settings: [String]
  /// External package mappings in `name=path` form (the `-E` flag).
  public var externalPkgs: [String]

  /// Toggle `disable_none` (`-n`); explicit value wins over the settings file.
  public var disableNone: Bool?
  /// Toggle `include_schema_type_path`; explicit value wins over the file.
  /// When on (and `fullTypePath` is off), the facade rewrites `_type`
  /// attributes to their short name, mirroring kcl-go's `DefaultHooks`.
  public var includeSchemaTypePath: Bool?
  /// Keep the fully qualified `_type` paths (kcl-go `WithFullTypePath`).
  /// Implies `includeSchemaTypePath` and disables the `_type` rewriting.
  public var fullTypePath: Bool
  /// Toggle `sort_keys` (`-k`); explicit value wins over the settings file.
  public var sortKeys: Bool?
  /// Toggle `show_hidden` (`-H`); explicit value wins over the settings file.
  public var showHidden: Bool?
  /// Toggle `strict_range_check`; explicit value wins over the settings file.
  public var strictRangeCheck: Bool?
  /// Toggle compile-only mode.
  public var compileOnly: Bool?
  /// Toggle fast evaluation; explicit value wins over the settings file.
  public var fastEval: Bool?
  /// Toggle printing the override AST.
  public var printOverrideAst: Bool?
  /// Toggle suppressing the YAML result (JSON navigation then requires the
  /// runtime to still emit `json_result`).
  public var disableYamlResult: Bool?
  /// Verbose level; only positive values take effect (kcl-go `Merge`).
  public var verbose: Int32?
  /// Debug flag, mapped to the runtime's 0/1 field.
  public var debug: Bool?
  /// Diagnostic output format: one of "pretty" (default), "short",
  /// "arcanist" or "sarif" (`--error_format`).
  public var errorFormat: String?
  /// Output format selector passed to the runtime: "yaml" or "json". When
  /// empty the runtime emits both representations.
  public var format: String?
  /// Sink receiving the runtime's `log_message` output (kcl-go `WithLogger`).
  public var logger: ((String) -> Void)?

  public init() {
    self.workDir = nil
    self.code = []
    self.args = []
    self.overrides = []
    self.selectors = []
    self.settings = []
    self.externalPkgs = []
    self.disableNone = nil
    self.includeSchemaTypePath = nil
    self.fullTypePath = false
    self.sortKeys = nil
    self.showHidden = nil
    self.strictRangeCheck = nil
    self.compileOnly = nil
    self.fastEval = nil
    self.printOverrideAst = nil
    self.disableYamlResult = nil
    self.verbose = nil
    self.debug = nil
    self.errorFormat = nil
    self.format = nil
    self.logger = nil
  }
}

// MARK: - Internal option bag

/// Mutable merge bag, mirroring the kcl-go `Option` / .NET `KclOptionBag`
/// field set. Private: users only ever see `KclOptions`.
private struct KclOptionBag {
  var workDir: String?
  var kFilenameList: [String] = []
  var kCodeList: [String] = []
  var args: [Argument] = []
  var overrides: [String] = []
  var selectors: [String] = []
  var externalPkgs: [ExternalPkg] = []
  var disableNone: Bool?
  var includeSchemaTypePath: Bool?
  var fullTypePath = false
  var sortKeys: Bool?
  var showHidden: Bool?
  var strictRangeCheck: Bool?
  var compileOnly: Bool?
  var fastEval: Bool?
  var printOverrideAst: Bool?
  var disableYamlResult: Bool?
  var verbose: Int32?
  var debug: Int32?
  var errorFormat: String?
  var format: String?
  var logger: ((String) -> Void)?

  /// Populate the bag from settings files via the `LoadSettingsFiles` RPC,
  /// mirroring kcl-go's `SettingsFile.To_ExecProgramArgs`: the file
  /// contributes input files, output format, overrides, selectors, flags and
  /// `kcl_options` entries, and later explicit options merge on top.
  ///
  /// `kcl_cli_configs.package_maps` is not visible through the RPC's
  /// `CliConfig` message, so external packages from settings files are
  /// silently dropped — the same limitation as the Node.js facade.
  mutating func merge(settingsFiles files: [String], workDir: String) throws {
    var req = LoadSettingsFilesArgs()
    req.workDir = workDir
    req.files = files
    let loaded = try API().loadSettingsFiles(req)
    let cfg = loaded.kclCliConfigs
    kFilenameList.append(contentsOf: cfg.files.filter { !$0.isEmpty })
    if !cfg.output.isEmpty {
      format = cfg.output
    }
    overrides.append(contentsOf: cfg.overrides.filter { !$0.isEmpty })
    selectors.append(contentsOf: cfg.pathSelector.filter { !$0.isEmpty })
    // Settings booleans only propagate when true, matching kcl-go's Merge
    // (a settings file cannot express "false").
    if cfg.strictRangeCheck { strictRangeCheck = true }
    if cfg.disableNone { disableNone = true }
    if cfg.sortKeys { sortKeys = true }
    if cfg.showHidden { showHidden = true }
    if cfg.includeSchemaTypePath { includeSchemaTypePath = true }
    if cfg.fastEval { fastEval = true }
    if cfg.verbose > 0 { verbose = Int32(cfg.verbose) }
    if cfg.debug { debug = 1 }
    for kv in loaded.kclOptions where !kv.key.isEmpty {
      var arg = Argument()
      arg.name = kv.key
      arg.value = kv.value
      args.append(arg)
    }
  }

  mutating func overlay(_ o: KclOptions) {
    if let workDir = o.workDir {
      self.workDir = workDir
    }
    kCodeList.append(contentsOf: o.code)
    for (name, value) in parseKeyValueList(o.args) {
      var arg = Argument()
      arg.name = name
      arg.value = value
      args.append(arg)
    }
    overrides.append(contentsOf: o.overrides)
    selectors.append(contentsOf: o.selectors)
    for (name, path) in parseKeyValueList(o.externalPkgs) {
      var pkg = ExternalPkg()
      pkg.pkgName = name
      pkg.pkgPath = path
      externalPkgs.append(pkg)
    }
    if let v = o.disableNone { disableNone = v }
    if let v = o.includeSchemaTypePath { includeSchemaTypePath = v }
    if o.fullTypePath { fullTypePath = true }
    if let v = o.sortKeys { sortKeys = v }
    if let v = o.showHidden { showHidden = v }
    if let v = o.strictRangeCheck { strictRangeCheck = v }
    if let v = o.compileOnly { compileOnly = v }
    if let v = o.fastEval { fastEval = v }
    if let v = o.printOverrideAst { printOverrideAst = v }
    if let v = o.disableYamlResult { disableYamlResult = v }
    if let v = o.verbose, v > 0 { verbose = v }
    if let v = o.debug { debug = v ? 1 : 0 }
    if let v = o.errorFormat { errorFormat = v }
    if let v = o.format { format = v }
    if let logger = o.logger { self.logger = logger }
  }

  func makeExecProgramArgs() -> ExecProgramArgs {
    var a = ExecProgramArgs()
    if let workDir = workDir {
      a.workDir = workDir
    }
    a.kFilenameList = kFilenameList
    a.kCodeList = kCodeList
    a.args = args
    a.overrides = overrides
    a.pathSelector = selectors
    a.externalPkgs = externalPkgs
    if let v = disableNone { a.disableNone = v }
    // kcl-go's WithFullTypePath forces include_schema_type_path on.
    if let v = includeSchemaTypePath { a.includeSchemaTypePath = v }
    if fullTypePath { a.includeSchemaTypePath = true }
    if let v = sortKeys { a.sortKeys = v }
    if let v = showHidden { a.showHidden = v }
    if let v = strictRangeCheck { a.strictRangeCheck = v }
    if let v = compileOnly { a.compileOnly = v }
    if let v = fastEval { a.fastEval = v }
    if let v = printOverrideAst { a.printOverrideAst = v }
    if let v = disableYamlResult { a.disableYamlResult = v }
    if let v = verbose { a.verbose = v }
    if let v = debug { a.debug = v }
    if let v = errorFormat { a.errorFormat = v }
    if let v = format { a.format = v }
    return a
  }
}

/// Parse `key=value` strings into pairs, skipping entries without an `=`
/// separator or with an empty key (kcl-go's `strings.Index(kv, "=") > 0`).
private func parseKeyValueList(_ list: [String]) -> [(String, String)] {
  list.compactMap { kv in
    guard let idx = kv.firstIndex(of: "="), idx > kv.startIndex else {
      return nil
    }
    return (String(kv[kv.startIndex..<idx]), String(kv[kv.index(after: idx)...]))
  }
}

// MARK: - Results

/// One evaluated configuration document, mirroring kcl-go's `KCLResult`.
public struct KclResult {
  /// The parsed document value (nested `[String: Any]` / `[Any]` / scalars),
  /// or `nil` when the run was YAML-only (`format: "yaml"`); use
  /// `yamlString()` in that case.
  public let value: Any?

  let yamlDocument: String
  let jsonDocument: String?

  /// The YAML rendering of this document as emitted by the runtime ("" when
  /// the run was JSON-only).
  public func yamlString() -> String {
    yamlDocument
  }

  /// The JSON rendering of this document's value.
  public func jsonString() -> String {
    if let jsonDocument = jsonDocument {
      return jsonDocument
    }
    return FacadeJson.string(value) ?? ""
  }

  /// Look up `path` in the parsed document: dots navigate nested mappings
  /// (`"a.b.c"`) and integer segments index into lists (`"items.0.name"`).
  /// Returns `nil` when any segment is missing.
  public func get(_ path: String) -> Any? {
    var current: Any? = value
    for segment in path.split(separator: ".") {
      guard let piece = current else {
        return nil
      }
      if let dict = piece as? [String: Any] {
        current = dict[String(segment)]
      } else if let list = piece as? [Any], let index = Int(segment),
        list.indices.contains(index)
      {
        current = list[index]
      } else {
        return nil
      }
    }
    return current
  }

  /// The document as a map, mirroring kcl-go's `KCLResult.ToMap`.
  /// - Throws: `KclError` when the document is not a map (or no JSON result
  ///   was available to navigate).
  public func toMap() throws -> [String: Any] {
    guard let value = value else {
      throw KclError.runtime(
        "failed to convert result to map: the runtime emitted YAML only (format \"yaml\");"
          + " drop the format option or read yamlString() instead")
    }
    guard let map = value as? [String: Any] else {
      throw KclError.runtime("failed to convert result to map: got \(typeName(of: value))")
    }
    return map
  }

  /// The document as a list, mirroring kcl-go's `KCLResult.ToList`.
  public func toList() throws -> [Any] {
    guard let value = value else {
      throw KclError.runtime(
        "failed to convert result to list: the runtime emitted YAML only (format \"yaml\");"
          + " drop the format option or read yamlString() instead")
    }
    guard let list = value as? [Any] else {
      throw KclError.runtime("failed to convert result to list: got \(typeName(of: value))")
    }
    return list
  }
}

/// The documents produced by a run, mirroring kcl-go's `KCLResultList`:
/// random-access collection semantics over the per-document `KclResult`
/// items, plus the raw runtime payloads (`yamlResult` / `jsonResult`) and
/// the run's log/error messages, all unmodified.
public struct KclResultList: RandomAccessCollection {
  public let results: [KclResult]

  /// The unmodified `yaml_result` payload returned by the runtime
  /// (documents separated by `---`).
  public let yamlResult: String
  /// The unmodified `json_result` payload (one JSON value per line for
  /// multi-document results).
  public let jsonResult: String
  /// Log output produced by the run, if any.
  public let logMessage: String
  /// Error message produced by the run; empty on success (a non-empty value
  /// would have been thrown as `KclError`).
  public let errMessage: String

  public var count: Int { results.count }
  public var isEmpty: Bool { results.isEmpty }
  public subscript(position: Int) -> KclResult { results[position] }
  public var startIndex: Int { results.startIndex }
  public var endIndex: Int { results.endIndex }
  public func index(after i: Int) -> Int { results.index(after: i) }

  /// Document at `index`, or `nil` when out of range (kcl-go
  /// `KCLResultList.Get`); the first document is also available as `first`.
  public func get(_ index: Int) -> KclResult? {
    results.indices.contains(index) ? results[index] : nil
  }

  /// Dotted-path lookup on the first document; `nil` when the result is
  /// empty or the path is missing.
  public func get(_ path: String) -> Any? {
    results.first?.get(path)
  }

  /// The first document as a map, mirroring kcl-go's `KCLResultList.ToMap`.
  public func toMap() throws -> [String: Any] {
    guard let first = results.first else {
      throw KclError.runtime("result is nil")
    }
    return try first.toMap()
  }
}

// MARK: - `_type` rewriting (kcl-go DefaultHooks)

/// Port of kcl-go's `typeAttributeHook` / `modifyType`: with
/// `include_schema_type_path` on (and no full type path requested), strip
/// the package qualifier — everything up to the last `.` — from every
/// `_type` attribute. Unlike kcl-go (which only descends into nested maps)
/// this also recurses into lists, so schema instances inside arrays are
/// rewritten too.
private enum TypeAttributeHook {
  static func rewrite(_ value: Any) -> Any {
    if var dict = value as? [String: Any] {
      for (key, child) in dict {
        if key == "_type", let typeName = child as? String {
          dict[key] = typeName.split(separator: ".").last.map(String.init) ?? typeName
        } else {
          dict[key] = rewrite(child)
        }
      }
      return dict
    }
    if let list = value as? [Any] {
      return list.map(rewrite)
    }
    return value
  }
}

// MARK: - JSON / YAML rendering helpers

private enum FacadeJson {
  /// Compact-ish JSON rendering of a parsed document tree; `nil` when the
  /// value cannot be serialized.
  static func string(_ value: Any?) -> String? {
    guard let value = value,
      let data = try? JSONSerialization.data(
        withJSONObject: value, options: [.fragmentsAllowed, .prettyPrinted])
    else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }
}

/// Minimal block-style YAML emitter for the document trees this facade
/// handles (mappings, sequences and scalars — the subset the KCL runtime
/// itself emits). Only used to re-render a document after the `_type` hook
/// rewrote it; no third-party YAML dependency is introduced.
private enum YamlEmitter {
  static func render(_ value: Any?) -> String {
    var lines: [String] = []
    write(value, indent: "", into: &lines)
    return lines.joined(separator: "\n")
  }

  private static func write(_ value: Any?, indent: String, into lines: inout [String]) {
    switch value {
    case nil, is NSNull:
      lines.append(indent + "null")
    case let dict as [String: Any]:
      if dict.isEmpty {
        lines.append(indent + "{}")
        return
      }
      for (key, child) in dict {
        if isScalar(child) {
          lines.append("\(indent)\(string(key)): \(scalar(child))")
        } else {
          lines.append("\(indent)\(string(key)):")
          write(child, indent: indent + "  ", into: &lines)
        }
      }
    case let list as [Any]:
      if list.isEmpty {
        lines.append(indent + "[]")
        return
      }
      for item in list {
        if isScalar(item) {
          lines.append("\(indent)- \(scalar(item))")
        } else {
          var sub: [String] = []
          write(item, indent: indent + "  ", into: &sub)
          if let first = sub.first {
            lines.append("\(indent)- " + String(first.dropFirst(indent.count + 2)))
            lines.append(contentsOf: sub.dropFirst())
          }
        }
      }
    default:
      lines.append(indent + scalar(value))
    }
  }

  private static func isScalar(_ value: Any?) -> Bool {
    switch value {
    case nil, is NSNull, is String, is Bool, is Int, is Double, is Float, is NSNumber:
      return true
    default:
      return false
    }
  }

  private static func scalar(_ value: Any?) -> String {
    if value == nil || value is NSNull {
      return "null"
    }
    // `NSNumber as? Bool` bridges lossily on Darwin (NSNumber(1) casts to
    // true), so booleans must be told apart from numeric NSNumbers. On
    // Darwin we use CFBoolean's type ID; on Linux (swift-corelibs-foundation)
    // CFBoolean isn't exposed, so we fall back to the Objective-C type
    // encoding — NSNumber stores Bool as signed char ('c') on both platforms.
    if let n = value as? NSNumber {
      if YamlEmitter.isBoolNumber(n) {
        return n.boolValue ? "true" : "false"
      }
      return String(describing: n)
    }
    if let s = value as? String {
      return string(s)
    }
    return string(String(describing: value))
  }

  /// Plain-style YAML scalar when safe, double-quoted otherwise.
  private static func string(_ s: String) -> String {
    if isPlainSafe(s) {
      return s
    }
    var out = "\""
    for ch in s {
      switch ch {
      case "\\": out += "\\\\"
      case "\"": out += "\\\""
      case "\n": out += "\\n"
      case "\t": out += "\\t"
      case "\r": out += "\\r"
      default: out.append(ch)
      }
    }
    out += "\""
    return out
  }

  private static func isPlainSafe(_ s: String) -> Bool {
    if s.isEmpty || s != s.trimmingCharacters(in: .whitespaces) {
      return false
    }
    let lower = s.lowercased()
    if ["null", "~", "true", "false", "yes", "no", "on", "off", "-"].contains(lower) {
      return false
    }
    if Double(s) != nil || Int(s) != nil {
      return false
    }
    if s.contains(": ") || s.contains(" #") || s.contains("\n") {
      return false
    }
    let unsafeLeading: Set<Character> = [
      "-", "?", ":", ",", "[", "]", "{", "}", "#", "&", "*", "!", "|", ">", "'", "\"", "%", "@",
      "`", ".",
    ]
    guard let first = s.first, !unsafeLeading.contains(first) else {
      return false
    }
    return true
  }

  /// True if `n` wraps a `Bool` rather than a numeric value.
  ///
  /// On Darwin, CFBoolean is exposed by Foundation and `CFGetTypeID` gives
  /// the most reliable answer (and is what the original code used). On
  /// Linux, swift-corelibs-foundation does not link CoreFoundation, so we
  /// fall back to the Objective-C type encoding — Bool is encoded as
  /// `'c'` (signed char) on both platforms, while Int/Double/Float use
  /// different codes ('i'/'q', 'd', 'f', ...).
  fileprivate static func isBoolNumber(_ n: NSNumber) -> Bool {
    #if canImport(Darwin)
    return CFGetTypeID(n) == CFBooleanGetTypeID()
    #else
    return n.objCType.pointee == 0x63  // 'c'
    #endif
  }
}

private func typeName(of value: Any) -> String {
  if value is [String: Any] {
    return "map"
  }
  if value is [Any] {
    return "list"
  }
  if let n = value as? NSNumber {
    return YamlEmitter.isBoolNumber(n) ? "bool" : "number"
  }
  if value is String {
    return "string"
  }
  return "unknown"
}

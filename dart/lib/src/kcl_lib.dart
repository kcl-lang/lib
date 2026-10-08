// Public Dart API for the KCL language core.
//
// Each typed wrapper below encodes a message, dispatches it through
// `libkcl.call_native` (see `kcl_lib_ffi.dart`) and decodes the reply.
// Error responses from the native dispatcher are surfaced as `KclError` —
// the Rust side prefixes every error reply with `"ERROR:"`, and we strip the
// prefix before decoding the rest as UTF-8.
//
// Naming follows the Dart convention (camelCase), even though the spec.proto
// field names are snake_case — for example `kFilenameList` on the message
// class but `execProgram(ExecProgramArgs(kFilenameList: ...))` here.
//
// **Service names:** the core registers every RPC under `service KclService`
// except the two `spec.proto` puts in `service BuiltinService` — `Ping` and
// `ListMethod`. There is no `KclService.ListMethod` alias, so `listMethod()`
// below has to use the `BuiltinService` name; every other wrapper uses
// `KclService.*`. See `dart/README.md` for details.

import 'dart:convert';
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import 'kcl_lib_ffi.dart';
import 'pb/spec.pb.dart';

// Re-export every generated message type so callers can `import 'package:kcl_lib/kcl_lib.dart'`
// and have everything they need in scope.
export 'pb/spec.pb.dart';

/// Thrown when the native dispatcher returns an error reply.
///
/// The KCL Rust side prefixes every error payload with the UTF-8 sequence
/// `"ERROR:"` (see `crates/api/src/service/capi.rs`); the public wrappers
/// strip the prefix and surface the rest of the payload as `message`.
class KclError implements Exception {
  final String message;
  KclError(this.message);

  @override
  String toString() => 'KclError: $message';
}

const String _errorPrefix = 'ERROR:';

bool _hasErrorPrefix(Uint8List bytes) {
  if (bytes.length < _errorPrefix.length) return false;
  for (var i = 0; i < _errorPrefix.length; i++) {
    if (bytes[i] != _errorPrefix.codeUnitAt(i)) return false;
  }
  return true;
}

T _invoke<T extends GeneratedMessage>(
  String rpcName,
  GeneratedMessage args,
  T Function(Uint8List) decode,
) {
  final bytes = LibKcl().call(rpcName, args.writeToBuffer());
  if (_hasErrorPrefix(bytes)) {
    throw KclError(utf8.decode(bytes.sublist(_errorPrefix.length)));
  }
  return decode(bytes);
}

// ---------------------------------------------------------------------------
// KclService — the main 20 RPCs.
// ---------------------------------------------------------------------------

/// Executes a KCL module and returns its YAML/JSON output.
ExecProgramResult execProgram(ExecProgramArgs args) =>
    _invoke('KclService.ExecProgram', args, ExecProgramResult.fromBuffer);

/// Returns the version info of the bundled `libkcl`.
GetVersionResult getVersion() => _invoke(
      'KclService.GetVersion',
      GetVersionArgs(),
      GetVersionResult.fromBuffer,
    );

/// Parses a set of KCL files and returns the AST JSON.
ParseProgramResult parseProgram(ParseProgramArgs args) =>
    _invoke('KclService.ParseProgram', args, ParseProgramResult.fromBuffer);

/// Parses a single KCL file and returns its dependencies + errors.
ParseFileResult parseFile(ParseFileArgs args) =>
    _invoke('KclService.ParseFile', args, ParseFileResult.fromBuffer);

/// Loads a package and resolves its full symbol table.
LoadPackageResult loadPackage(LoadPackageArgs args) =>
    _invoke('KclService.LoadPackage', args, LoadPackageResult.fromBuffer);

/// Lists the `--option` keys defined in a KCL program.
ListOptionsResult listOptions(ParseProgramArgs args) =>
    _invoke('KclService.ListOptions', args, ListOptionsResult.fromBuffer);

/// Lists the top-level variables defined in a set of KCL files.
ListVariablesResult listVariables(ListVariablesArgs args) =>
    _invoke('KclService.ListVariables', args, ListVariablesResult.fromBuffer);

/// Overrides attribute values in a KCL file in place.
OverrideFileResult overrideFile(OverrideFileArgs args) =>
    _invoke('KclService.OverrideFile', args, OverrideFileResult.fromBuffer);

/// Returns the schema type mapping produced by executing a KCL program.
GetSchemaTypeMappingResult getSchemaTypeMapping(
        GetSchemaTypeMappingArgs args) =>
    _invoke(
      'KclService.GetSchemaTypeMapping',
      args,
      GetSchemaTypeMappingResult.fromBuffer,
    );

/// Like [getSchemaTypeMapping], but keyed by the package the schema lives in.
GetSchemaTypeMappingUnderPathResult getSchemaTypeMappingUnderPath(
    GetSchemaTypeMappingArgs args) =>
    _invoke(
      'KclService.GetSchemaTypeMappingUnderPath',
      args,
      GetSchemaTypeMappingUnderPathResult.fromBuffer,
    );

/// Formats a KCL source string in memory.
FormatCodeResult formatCode(FormatCodeArgs args) =>
    _invoke('KclService.FormatCode', args, FormatCodeResult.fromBuffer);

/// Formats KCL files on disk and reports which files changed.
FormatPathResult formatPath(FormatPathArgs args) =>
    _invoke('KclService.FormatPath', args, FormatPathResult.fromBuffer);

/// Lints a set of KCL files and returns the lint results.
LintPathResult lintPath(LintPathArgs args) =>
    _invoke('KclService.LintPath', args, LintPathResult.fromBuffer);

/// Validates `code` against the JSON/YAML `data` payload.
ValidateCodeResult validateCode(ValidateCodeArgs args) =>
    _invoke('KclService.ValidateCode', args, ValidateCodeResult.fromBuffer);

/// Loads a set of KCL settings files (CLI config).
LoadSettingsFilesResult loadSettingsFiles(LoadSettingsFilesArgs args) => _invoke(
      'KclService.LoadSettingsFiles',
      args,
      LoadSettingsFilesResult.fromBuffer,
    );

/// Renames a symbol across the given KCL files, rewriting them in place.
RenameResult rename(RenameArgs args) =>
    _invoke('KclService.Rename', args, RenameResult.fromBuffer);

/// Renames a symbol in memory without touching the filesystem.
RenameCodeResult renameCode(RenameCodeArgs args) =>
    _invoke('KclService.RenameCode', args, RenameCodeResult.fromBuffer);

/// Runs the KCL test runner against a set of packages.
///
/// Named `runTests` (not `test`) to avoid colliding with the `test()`
/// function re-exported from `package:test` when both are imported in the
/// same file. The RPC name is still `KclService.Test`.
TestResult runTests(TestArgs args) =>
    _invoke('KclService.Test', args, TestResult.fromBuffer);

/// Formats a test result into a human-readable report.
///
/// The output is byte-identical to the kcl-go `PrettyReporter` format and is
/// deterministic for a given result. Every line, including the last one, ends
/// with `\n`:
///
/// - One line per case in result order: `{name}: {STATUS} ({duration_ms}ms)`,
///   where STATUS is `PASS` or `FAIL` and `duration_ms` is the case duration
///   in microseconds truncated to whole milliseconds (integer division, so
///   `1500µs` renders as `1ms`). A case with a non-empty log message appends
///   the log on the next line; otherwise a failed case appends its error
///   string as-is.
/// - A separator line of exactly 80 `-` characters.
/// - Only for non-zero counts, in this order: `PASS: {p}/{total}`,
///   `FAIL: {f}/{total}`, `SKIPPED: {s}/{total}`.
/// - An empty result (no cases, no coverage) renders exactly `no test files\n`.
///
/// The input is the [TestResult] returned by [runTests].
FormatTestReportResult formatTestReport(FormatTestReportArgs args) => _invoke(
      'KclService.FormatTestReport',
      args,
      FormatTestReportResult.fromBuffer,
    );

/// Resolves and updates the KCL module dependencies.
UpdateDependenciesResult updateDependencies(UpdateDependenciesArgs args) =>
    _invoke(
      'KclService.UpdateDependencies',
      args,
      UpdateDependenciesResult.fromBuffer,
    );

// ---------------------------------------------------------------------------
// KclService.Generate* — the schema / data generator RPCs.
//
// These five only exist on runtimes built after the `Generate*` family was
// added to spec.proto. Every one of them takes its input as protobuf payload
// (`ExecProgramArgs` or `ParseProgramArgs`) rather than as a CLI argv, so the
// wrappers below are thin: they encode, dispatch and decode like the rest.
// A runtime that predates an RPC answers with an `ERROR:`-prefixed payload,
// which surfaces as a [KclError] just like any other dispatch failure.
// ---------------------------------------------------------------------------

/// Serializes the evaluated result of a KCL program to TOML.
///
/// Pass [GenerateTomlArgs.sortKeys] to emit the keys in sorted order instead of
/// source order.
GenerateTomlResult generateToml(GenerateTomlArgs args) => _invoke(
      'KclService.GenerateToml',
      args,
      GenerateTomlResult.fromBuffer,
    );

/// Generates KCL source from data content.
///
/// [GenerateKclArgs.source] is JSON, YAML or TOML text;
/// [GenerateKclArgs.format] (`"json"` / `"yaml"` / `"toml"`) selects the input
/// format and defaults to being inferred from the
/// [GenerateKclArgs.filename] extension, falling back to JSON.
GenerateKclResult generateKcl(GenerateKclArgs args) => _invoke(
      'KclService.GenerateKcl',
      args,
      GenerateKclResult.fromBuffer,
    );

/// Generates an OpenAPI spec from the schemas of a KCL package.
///
/// [GenerateOpenAPIArgs.version] is `"v3"` (the runtime default) for OpenAPI
/// 3.x or `"v2"` for a Swagger 2.0 document.
GenerateOpenAPIResult generateOpenAPI(GenerateOpenAPIArgs args) => _invoke(
      'KclService.GenerateOpenAPI',
      args,
      GenerateOpenAPIResult.fromBuffer,
    );

/// Generates proto3 definitions from the schemas of a KCL package.
///
/// [GenerateProtoArgs.package] is the proto package name, e.g. `"example.v1"`;
/// leaving it empty omits the `package` clause.
GenerateProtoResult generateProto(GenerateProtoArgs args) => _invoke(
      'KclService.GenerateProto',
      args,
      GenerateProtoResult.fromBuffer,
    );

/// Generates documentation for the schemas of a KCL package.
///
/// [GenerateDocArgs.format] is `"md"` (the runtime default) for Markdown,
/// `"openapi"` for a Swagger 2.0 spec or `"json-schema"` for a JSON Schema
/// draft per schema. `"html"` is not supported yet.
GenerateDocResult generateDoc(GenerateDocArgs args) => _invoke(
      'KclService.GenerateDoc',
      args,
      GenerateDocResult.fromBuffer,
    );

// ---------------------------------------------------------------------------
// The bundled libkcl registers every RPC under `KclService` except the two
// `spec.proto` declares in `BuiltinService`, so the wrappers above follow the
// registration rather than a blanket rule; see dart/README for details.
//
// `ListMethod` is one of those two: `KclService.ListMethod` is unknown to the
// dispatcher, which raises `unknown method name` and prints a Rust panic on
// the way out.
// ---------------------------------------------------------------------------

/// Round-trips a value through the KCL dispatcher — useful as a smoke test.
///
/// `Ping` is declared in *both* services in spec.proto, and the core registers
/// it under both names; this wrapper uses `KclService.Ping`.
PingResult ping(PingArgs args) =>
    _invoke('KclService.Ping', args, PingResult.fromBuffer);

/// Lists every RPC name known to the dispatcher — 28 of them.
///
/// Reports the fully-qualified names, e.g. `KclService.ExecProgram` and
/// `BuiltinService.ListMethod` — i.e. its own entry appears under the
/// `BuiltinService` prefix.
ListMethodResult listMethod() => _invoke(
      'BuiltinService.ListMethod',
      ListMethodArgs(),
      ListMethodResult.fromBuffer,
    );

/// Low-level escape hatch: invoke any RPC by its fully-qualified name with
/// pre-encoded protobuf bytes. Most callers should prefer the typed wrappers
/// above; this exists for forward compatibility with RPCs added after this
/// binding was generated.
///
/// Returns the raw response bytes. Decodes the `ERROR:` prefix and raises
/// [KclError] on error replies, otherwise returns the success payload
/// unmodified.
Uint8List rawCall(String rpcName, Uint8List encodedArgs) {
  final bytes = LibKcl().call(rpcName, encodedArgs);
  if (_hasErrorPrefix(bytes)) {
    throw KclError(utf8.decode(bytes.sublist(_errorPrefix.length)));
  }
  return bytes;
}
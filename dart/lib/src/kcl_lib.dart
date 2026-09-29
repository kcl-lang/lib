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
// **Service-name divergence:** `spec.proto` declares `FormatCode`,
// `FormatPath`, `LintPath`, `ValidateCode`, `LoadSettingsFiles`, `Rename`,
// `RenameCode`, `Test`, `UpdateDependencies`, `Ping`, and `ListMethod`
// under `service BuiltinService`, but the prebuilt `libkcl` v0.13.0 ships
// every RPC under `service KclService` (the `BuiltinService.*` dispatch
// path panics with `unknown method name`). The wrappers therefore route
// every call through `KclService.*`. See `dart/README.md` for details.

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
// KclService — the main 19 RPCs.
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

/// Resolves and updates the KCL module dependencies.
UpdateDependenciesResult updateDependencies(UpdateDependenciesArgs args) =>
    _invoke(
      'KclService.UpdateDependencies',
      args,
      UpdateDependenciesResult.fromBuffer,
    );

// ---------------------------------------------------------------------------
// BuiltinService-equivalent — the bundled libkcl v0.13.0 registers every
// RPC under `KclService` regardless of the service declared in spec.proto.
// We follow the implementation, not the spec; see dart/README for details.
// ---------------------------------------------------------------------------

/// Round-trips a value through the KCL dispatcher — useful as a smoke test.
PingResult ping(PingArgs args) =>
    _invoke('KclService.Ping', args, PingResult.fromBuffer);

/// Lists every RPC name known to the dispatcher.
ListMethodResult listMethod() => _invoke(
      'KclService.ListMethod',
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
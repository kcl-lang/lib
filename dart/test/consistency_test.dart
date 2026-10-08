// Cross-language consistency runner for the Dart binding.
//
// Executes the hermetic cases from `tests/consistency/cases.json` (generated
// by `tests/consistency/generate_cases.py`) against the prebuilt `libkcl` and
// asserts the same golden expectations as the Python / Node.js / Go / Java /
// .NET runners. Every expectation is read from the manifest — nothing about a
// case is hardcoded here — so this file needs no update when the shared
// manifest grows a field or a case.
//
// Run it the same way as the rest of the suite (from `dart/`):
//
//     KCL_DART_LIB=../go/lib/<platform>/libkcl.dylib dart test
//
// The runner follows the three-step shape of the Java reference
// (`java/src/test/java/com/kcl/ConsistencyTest.java`):
//
//   1. load + validate the manifest (`version == 1`),
//   2. probe the core's RPC surface once, so a `new_core` case whose RPC this
//      runtime does not know is skipped instead of failed,
//   3. dispatch on the case's `rpc` and compare only the fields that actually
//      appear in the case's `expect` object.

import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:kcl_lib/kcl_lib.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Step 1 — the shared manifest
// ---------------------------------------------------------------------------

/// The repository root, i.e. the directory that holds `tests/consistency/`.
///
/// `dart test` runs with the CWD set to the package root, but that is an
/// implementation detail rather than a guarantee, so walk upwards looking for
/// the manifest itself instead of hardcoding `../tests/...`. That keeps the
/// runner working when it is invoked from the repository root
/// (`dart test dart/test`) or from an IDE.
Directory _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/tests/consistency/cases.json').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'consistency manifest not found: walked up from '
        '${Directory.current.path} without finding tests/consistency/cases.json. '
        'Run `python tests/consistency/generate_cases.py` to generate it.',
      );
    }
    dir = parent;
  }
}

final Directory _repoRoot = _findRepoRoot();
final File _manifestFile =
    File('${_repoRoot.path}/tests/consistency/cases.json');

Map<String, Object?>? _manifest;

/// Loads and validates the manifest once per run.
Map<String, Object?> _loadManifest() {
  final cached = _manifest;
  if (cached != null) return cached;

  if (!_manifestFile.existsSync()) {
    throw StateError(
      'consistency manifest not found at ${_manifestFile.path}. '
      'Run `python tests/consistency/generate_cases.py` to generate it.',
    );
  }
  final decoded = jsonDecode(_manifestFile.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw StateError(
      'consistency manifest at ${_manifestFile.path} is not a JSON object',
    );
  }
  final version = decoded['version'];
  if (version != 1) {
    throw StateError('unsupported consistency manifest version: $version');
  }
  return _manifest = decoded;
}

final List<Map<String, Object?>> _cases =
    (_loadManifest()['cases']! as List<Object?>).cast<Map<String, Object?>>();

/// Finds one case by `name`, failing the test when the manifest does not have
/// it — a missing case is a manifest bug, never a skip.
Map<String, Object?> _case(String name) {
  for (final c in _cases) {
    if (c['name'] == name) return c;
  }
  throw StateError('consistency case not found in manifest: $name');
}

// ---------------------------------------------------------------------------
// Step 2 — the core's RPC surface
// ---------------------------------------------------------------------------

Set<String>? _methodCache;

/// The RPC names the loaded `libkcl` actually registers, or an empty set when
/// the core cannot answer.
///
/// Goes through the typed `listMethod()` wrapper, which dispatches to
/// `BuiltinService.ListMethod` — the only RPC the prebuilt libkcl registers
/// under the service name spec.proto gives it. `KclService.ListMethod` is not
/// registered and makes the native dispatcher raise `unknown method name`.
Set<String> _methods() {
  final cached = _methodCache;
  if (cached != null) return cached;
  try {
    return _methodCache = listMethod().methodNameList.toSet();
  } catch (_) {
    return _methodCache = const {};
  }
}

// ---------------------------------------------------------------------------
// Manifest helpers
// ---------------------------------------------------------------------------

Map<String, Object?> _obj(Object? value, String what) {
  if (value is Map<String, Object?>) return value;
  throw StateError('$what must be a JSON object, got ${value.runtimeType}');
}

List<Object?> _arr(Object? value, String what) {
  if (value is List<Object?>) return value;
  throw StateError('$what must be a JSON array, got ${value.runtimeType}');
}

String _str(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw StateError('field `$key` must be a string, got ${value.runtimeType}');
}

/// `args.<key>` as a string, falling back to `''` when the manifest omits it.
String _optStr(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return '';
  if (value is String) return value;
  throw StateError('field `$key` must be a string, got ${value.runtimeType}');
}

bool _optBool(Map<String, Object?> json, String key) => json[key] == true;

List<String> _strList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  return _arr(value, key).map((e) => e as String).toList();
}

int _optInt(Map<String, Object?> json, String key, int fallback) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw StateError('field `$key` must be a number, got ${value.runtimeType}');
}

/// Builds `ParseProgramArgs` from the manifest.
///
/// `paths` entries are pinned repo-relative by `generate_cases.py`; they are
/// resolved against the repository root (the parent of the directory holding
/// `cases.json`) while absolute entries are kept as-is — otherwise the core
/// would resolve them against the runner's CWD and not find the fixture.
ParseProgramArgs _parseArgs(Map<String, Object?> json) {
  final paths = _strList(json, 'paths').map((p) {
    if (p.startsWith('/') || _hasWindowsDrive(p)) return p;
    return '${_repoRoot.path}/$p';
  }).toList();
  return ParseProgramArgs(
    paths: paths,
    sources: _strList(json, 'sources'),
    externalPkgs: _externalPkgs(json),
  );
}

bool _hasWindowsDrive(String p) => p.length >= 2 && p[1] == ':';

/// Builds `ExecProgramArgs` from the manifest, honouring every field the
/// manifest happens to carry. Optional fields are read defensively so a case
/// that omits one — or a manifest that grows one — still works.
ExecProgramArgs _execArgs(Map<String, Object?> json) {
  final args = ExecProgramArgs(
    workDir: _optStr(json, 'work_dir'),
    kFilenameList: _strList(json, 'k_filename_list'),
    kCodeList: _strList(json, 'k_code_list'),
    overrides: _strList(json, 'overrides'),
    disableYamlResult: _optBool(json, 'disable_yaml_result'),
    printOverrideAst: _optBool(json, 'print_override_ast'),
    strictRangeCheck: _optBool(json, 'strict_range_check'),
    disableNone: _optBool(json, 'disable_none'),
    verbose: _optInt(json, 'verbose', 0),
    debug: _optInt(json, 'debug', 0),
    sortKeys: _optBool(json, 'sort_keys'),
    includeSchemaTypePath: _optBool(json, 'include_schema_type_path'),
    compileOnly: _optBool(json, 'compile_only'),
    showHidden: _optBool(json, 'show_hidden'),
    pathSelector: _strList(json, 'path_selector'),
    fastEval: _optBool(json, 'fast_eval'),
    errorFormat: _optStr(json, 'error_format'),
    format: _optStr(json, 'format'),
    emitAttributeMetadata: _optBool(json, 'emit_attribute_metadata'),
    externalPkgs: _externalPkgs(json),
  );
  for (final entry in _arr(json['args'] ?? const <Object?>[], 'args')) {
    final a = _obj(entry, 'args[]');
    args.args.add(Argument(
      name: _optStr(a, 'name'),
      value: _optStr(a, 'value'),
    ));
  }
  return args;
}

// ---------------------------------------------------------------------------
// Step 3 — dispatch and comparison
// ---------------------------------------------------------------------------

/// Invokes the case's RPC and returns the response fields the manifest could
/// assert on, keyed by the `spec.proto` field name (`snake_case`, matching the
/// keys used in `expect`).
Map<String, Object?> _dispatch(String rpc, Map<String, Object?> args) {
  switch (rpc) {
    case 'KclService.Ping':
      return {'value': ping(PingArgs(value: _str(args, 'value'))).value};

    case 'KclService.ExecProgram':
      final r = execProgram(_execArgs(args));
      return {
        'yaml_result': r.yamlResult,
        'json_result': r.jsonResult,
        'err_message': r.errMessage,
      };

    case 'KclService.FormatCode':
      // `formatted` is a proto `bytes` field, hence a Uint8List here.
      return {
        'formatted': utf8.decode(
          formatCode(FormatCodeArgs(source: _str(args, 'source'))).formatted,
        ),
      };

    case 'KclService.ValidateCode':
      final r = validateCode(ValidateCodeArgs(
        data: _optStr(args, 'data'),
        code: _optStr(args, 'code'),
        datafile: _optStr(args, 'datafile'),
        file: _optStr(args, 'file'),
        schema: _optStr(args, 'schema'),
        attributeName: _optStr(args, 'attribute_name'),
        format: _optStr(args, 'format'),
        externalPkgs: _externalPkgs(args),
      ));
      return {'success': r.success, 'err_message': r.errMessage};

    case 'KclService.FormatTestReport':
      final info = _arr(
        _obj(args['result'] ?? const <String, Object?>{}, 'result')['info'],
        'result.info',
      ).map((e) {
        final m = _obj(e, 'result.info[]');
        return TestCaseInfo(
          name: _optStr(m, 'name'),
          error: _optStr(m, 'error'),
          // The manifest carries the duration as a decimal string because it
          // is a proto uint64; Int64.parseInt handles the unsigned range.
          duration: Int64.parseInt(_optStr(m, 'duration')),
          logMessage: _optStr(m, 'log_message'),
        );
      }).toList();
      return {
        'report': formatTestReport(
          FormatTestReportArgs(result: TestResult(info: info)),
        ).report,
      };

    case 'KclService.GenerateToml':
      return {
        'toml': generateToml(GenerateTomlArgs(
          execArgs: _execArgs(
            _obj(args['exec_args'] ?? const <String, Object?>{}, 'exec_args'),
          ),
          sortKeys: _optBool(args, 'sort_keys'),
        )).toml,
      };

    case 'KclService.GenerateKcl':
      return {
        'kcl': generateKcl(GenerateKclArgs(
          source: _str(args, 'source'),
          filename: _optStr(args, 'filename'),
          format: _optStr(args, 'format'),
        )).kcl,
      };

    case 'KclService.GenerateOpenAPI':
      return {
        'spec': generateOpenAPI(GenerateOpenAPIArgs(
          parseArgs: _parseArgs(
            _obj(args['parse_args'] ?? const <String, Object?>{}, 'parse_args'),
          ),
          version: _optStr(args, 'version'),
        )).spec,
      };

    case 'KclService.GenerateProto':
      return {
        'proto': generateProto(GenerateProtoArgs(
          parseArgs: _parseArgs(
            _obj(args['parse_args'] ?? const <String, Object?>{}, 'parse_args'),
          ),
          package: _optStr(args, 'package'),
        )).proto,
      };

    case 'KclService.GenerateDoc':
      return {
        'content': generateDoc(GenerateDocArgs(
          parseArgs: _parseArgs(
            _obj(args['parse_args'] ?? const <String, Object?>{}, 'parse_args'),
          ),
          format: _optStr(args, 'format'),
        )).content,
      };

    default:
      throw StateError('no runner support for rpc $rpc');
  }
}

List<ExternalPkg> _externalPkgs(Map<String, Object?> json) {
  final raw = json['external_pkgs'];
  if (raw is! List<Object?>) return const [];
  return raw.map((e) {
    final m = _obj(e, 'external_pkgs[]');
    return ExternalPkg(
      pkgName: _optStr(m, 'pkg_name'),
      pkgPath: _optStr(m, 'pkg_path'),
    );
  }).toList();
}

/// A line-oriented `--- expected / +++ actual` rendering, so a mismatch on a
/// 2 KB OpenAPI document points at the differing line instead of dumping both
/// blobs into the failure message.
String _diff(String expected, String actual) {
  final e = expected.split('\n');
  final a = actual.split('\n');
  final buf = StringBuffer('--- expected\n+++ actual\n');
  final n = e.length > a.length ? e.length : a.length;
  for (var i = 0; i < n; i++) {
    final el = i < e.length ? e[i] : null;
    final al = i < a.length ? a[i] : null;
    if (el != null && el == al) {
      buf.writeln('  $el');
    } else {
      if (el != null) buf.writeln('- $el');
      if (al != null) buf.writeln('+ $al');
    }
  }
  return buf.toString();
}

/// Runs one manifest case end to end: skip-if-unsupported, dispatch, then
/// compare every field the case's `expect` object actually mentions.
void _runCase(String name) {
  final c = _case(name);
  final rpc = c['rpc']! as String;
  final args = _obj(c['args'] ?? const <String, Object?>{}, 'args');
  // Named `wanted`, not `expect`, so it does not shadow package:test's
  // `expect` inside this function.
  final wanted = _obj(c['expect'], 'expect');

  // A `new_core` case exercises an RPC added after the oldest runtime this
  // binding supports. If this core does not register it, the case is not
  // applicable — skip it rather than fail the suite.
  if (c['new_core'] == true && !_methods().contains(rpc)) {
    markTestSkipped(
      'the loaded core does not register $rpc (old core); '
      'ListMethod reported ${_methods().length} RPCs',
    );
    return;
  }

  final actual = _dispatch(rpc, args);

  expect(
    actual.keys.toSet(),
    containsAll(wanted.keys),
    reason: 'runner produced no value for a field the manifest asserts on '
        '(case `$name`, rpc $rpc)',
  );

  for (final entry in wanted.entries) {
    final field = entry.key;
    final expected = entry.value;
    final got = actual[field];
    if (expected is String && got is String) {
      expect(got, expected,
          reason: 'consistency case `$name` field `$field` mismatch:\n'
              '${_diff(expected, got)}');
    } else {
      expect(got, expected,
          reason: 'consistency case `$name` field `$field` mismatch');
    }
  }
}

void main() {
  group('consistency', () {
    test('manifest is readable and version 1', () {
      expect(_loadManifest()['version'], 1);
      expect(_cases, isNotEmpty);
      // Every case the Java/Go/.NET/Node/Python runners execute.
      expect(
        _cases.map((c) => c['name']),
        containsAll([
          'ping',
          'exec_program_basic',
          'exec_program_overrides',
          'format_code',
          'validate_code_ok',
          'validate_code_invalid',
          'generate_kcl_json',
          'generate_kcl_yaml',
          'generate_toml',
          'format_test_report',
          'generate_openapi_v3',
          'generate_proto',
          'generate_doc_md',
        ]),
      );
    });

    test('core advertises the Generate* RPC surface', () {
      // Informational: prints what this libkcl registers so a skip below is
      // explainable from the log alone.
      final methods = _methods().toList()..sort();
      // ignore: avoid_print
      print('core RPC surface (${methods.length}): ${methods.join(', ')}');
      // Pin the registry size so a method cannot be dropped from the core
      // without this binding noticing -- `KclService.ListDepFiles` was removed
      // in v0.13.1, replaced by `LoadPackageResult.imports` / `kcl_mod` / `apps`.
      expect(methods, hasLength(28));
    });

    // One test per manifest case, mirroring ConsistencyTest.java.
    test('ping', () => _runCase('ping'));
    test('exec_program_basic', () => _runCase('exec_program_basic'));
    test('exec_program_overrides', () => _runCase('exec_program_overrides'));
    test('format_code', () => _runCase('format_code'));
    test('validate_code_ok', () => _runCase('validate_code_ok'));
    test('validate_code_invalid', () => _runCase('validate_code_invalid'));
    test('generate_kcl_json', () => _runCase('generate_kcl_json'));
    test('generate_kcl_yaml', () => _runCase('generate_kcl_yaml'));
    test('generate_toml', () => _runCase('generate_toml'));
    test('format_test_report', () => _runCase('format_test_report'));
    test('generate_openapi_v3', () => _runCase('generate_openapi_v3'));
    test('generate_proto', () => _runCase('generate_proto'));
    test('generate_doc_md', () => _runCase('generate_doc_md'));
  });
}

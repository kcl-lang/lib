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
//
// A final test then checks that every case in the manifest has a test above it,
// so the manifest growing a case this runner does not dispatch is a build
// failure rather than a silent gap.

import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:kcl_lib/kcl_lib.dart';
// The barrel export deliberately prefers the AST's `Decorator` and
// `FunctionType` over the protobuf messages of the same name — the AST wins
// because that is what a caller walking a parsed file wants — but the schema
// mapping nests the protobuf ones. A prefix keeps both names unambiguous.
// ignore: implementation_imports
import 'package:kcl_lib/src/pb/spec.pb.dart' as pb show Decorator, FunctionType;
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

bool _hasWindowsDrive(String p) => p.length >= 2 && p[1] == ':';

/// `tests/consistency/testdata`, the tree the `scratch:` templates come from.
final Directory _testdata =
    Directory('${_repoRoot.path}/tests/consistency/testdata');

/// The marker `generate_cases.py` writes into a path that names a template
/// rather than a file. `scratch:a/b.k` means "b.k inside a copy of
/// testdata/a"; the copy is what makes the RPCs that rewrite files safe to
/// run, and it is also why those cases pin the RPC's answer rather than a
/// path.
const String _scratchPrefix = 'scratch:';

/// The temporary roots [_scratch] has created for the case now running.
final List<Directory> _scratchRoots = <Directory>[];

/// Copies a scratch template and returns the path inside the copy.
///
/// Each case gets its own temporary directory, so two cases — and two runs —
/// never observe each other's writes and the repository is never the target of
/// an RPC that rewrites files. [_removeScratch] takes the copy away again when
/// the case is done with it.
String _scratch(String rest) {
  final slash = rest.indexOf('/');
  final template = slash < 0 ? rest : rest.substring(0, slash);
  final tail = slash < 0 ? '' : rest.substring(slash + 1);
  final source = Directory('${_testdata.path}/$template');
  if (!source.existsSync()) {
    throw StateError('scratch template is not a directory: ${source.path}');
  }
  final root = Directory.systemTemp.createTempSync('kcl-consistency-');
  _scratchRoots.add(root);
  final destination = Directory('${root.path}/$template');
  _copyTree(source, destination);
  return tail.isEmpty ? destination.path : '${destination.path}/$tail';
}

void _copyTree(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync(recursive: true)) {
    final target =
        '${destination.path}/${entity.path.substring(source.path.length + 1)}';
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

/// Deletes the scratch copies made by the case that is finishing.
void _removeScratch() {
  for (final root in _scratchRoots) {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
  _scratchRoots.clear();
}

/// One manifest path entry, as a path the local core can open.
///
/// Scratch references become a fresh copy, the repo-relative form
/// `generate_cases.py` pins resolves against the repository root, and an
/// absolute entry is kept as-is — otherwise the core would resolve it against
/// the runner's CWD and not find the fixture.
String _resolvePath(String p) {
  if (p.startsWith(_scratchPrefix)) {
    return _scratch(p.substring(_scratchPrefix.length));
  }
  if (p.startsWith('/') || _hasWindowsDrive(p)) return p;
  return '${_repoRoot.path}/$p';
}

List<String> _paths(Map<String, Object?> json, String key) =>
    _strList(json, key).map(_resolvePath).toList();

/// The manifest pins basenames rather than the absolute paths the parse, lint
/// and format RPCs report, which differ on every machine.
String _basename(String p) {
  final slash = p.lastIndexOf('/');
  return slash < 0 ? p : p.substring(slash + 1);
}

/// Builds `ParseProgramArgs` from the manifest.
ParseProgramArgs _parseArgs(Map<String, Object?> json) {
  return ParseProgramArgs(
    paths: _paths(json, 'paths'),
    sources: _strList(json, 'sources'),
    externalPkgs: _externalPkgs(json),
  );
}

/// Builds `ExecProgramArgs` from the manifest, honouring every field the
/// manifest happens to carry. Optional fields are read defensively so a case
/// that omits one — or a manifest that grows one — still works.
ExecProgramArgs _execArgs(Map<String, Object?> json) {
  // A case that pins no `work_dir` runs against the repository root, which is
  // the same default the manifest generator resolves an absent one to.
  final workDir = json['work_dir'] == null
      ? _repoRoot.path
      : _resolvePath(_optStr(json, 'work_dir'));
  final args = ExecProgramArgs(
    workDir: workDir,
    // The core resolves `k_filename_list` against the process working directory
    // rather than against `work_dir`, so a relative entry has to be made
    // absolute here or it will not survive being run from another directory.
    kFilenameList: [
      for (final name in _strList(json, 'k_filename_list'))
        _hasWindowsDrive(name) || name.startsWith('/')
            ? name
            : '$workDir/$name',
    ],
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
      return {
        'success': r.success,
        // The diagnostic carries ANSI colour escapes, a random temp path and a
        // temp filename, so the string itself is not pinnable — but a manifest
        // that pins it (the success case pins the empty one) still gets the
        // real value, and `has_error_message` pins only its presence.
        'err_message': r.errMessage,
        'has_error_message': r.errMessage.isNotEmpty,
      };

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

    case 'KclService.ParseFile':
      final r = parseFile(ParseFileArgs(
        path: _optStr(args, 'path'),
        source: _optStr(args, 'source'),
        externalPkgs: _externalPkgs(args),
      ));
      return {
        // A bare `Module` document, so the statements sit at `body` rather than
        // under `pkgs` the way `ParseProgram` hands the same tree back.
        'body_count': _bodyCount(r.astJson),
        'error_count': r.errors.length,
        'deps': r.deps.toList(),
      };

    case 'KclService.ParseProgram':
      final r = parseProgram(_parseArgs(args));
      return {
        'module_count': _mainPackageModules(r.astJson),
        'error_count': r.errors.length,
        'paths': [for (final p in r.paths) _basename(p)],
      };

    case 'KclService.ListOptions':
      final r = listOptions(_parseArgs(args));
      final options = r.options.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return {
        'option_count': r.options.length,
        'options': [for (final o in options) [o.name, o.required]],
      };

    case 'KclService.ListVariables':
      final r = listVariables(ListVariablesArgs(
        files: _paths(args, 'files'),
        specs: _strList(args, 'specs'),
        options: ListVariablesOptions(
          mergeProgram: _optBool(
            _obj(args['options'] ?? const <String, Object?>{}, 'options'),
            'merge_program',
          ),
        ),
      ));
      final specs = r.variables.keys.toList()..sort();
      return {
        'values': {
          for (final spec in specs)
            spec: [
              for (final v in r.variables[spec]!.variables) v.value,
            ],
        },
        'unsupported_codes': r.unsupportedCodes.toList(),
        'parse_error_count': r.parseErrors.length,
      };

    case 'KclService.LoadPackage':
      final r = loadPackage(LoadPackageArgs(
        parseArgs: _parseArgs(
          _obj(args['parse_args'] ?? const <String, Object?>{}, 'parse_args'),
        ),
        resolveAst: _optBool(args, 'resolve_ast'),
        loadBuiltin: _optBool(args, 'load_builtin'),
        withAstIndex: _optBool(args, 'with_ast_index'),
      ));
      // The symbol and scope tables are the core's, not the binding's, so only
      // their size is pinned; `kcl_mod`/`apps`/`imports` are the fields that go
      // red on a binding built against an older `kcl-api`.
      return {
        'path_count': r.paths.length,
        'type_error_count': r.typeErrors.length,
        'parse_error_count': r.parseErrors.length,
        'symbol_count': r.symbols.length,
        'scope_count': r.scopes.length,
        'has_kcl_mod': r.hasKclMod(),
        'kcl_mod_name': r.hasKclMod() ? r.kclMod.package.name : '',
        'app_count': r.apps.length,
        'import_count': r.imports.length,
      };

    case 'KclService.GetSchemaTypeMapping':
    case 'KclService.GetSchemaTypeMappingUnderPath':
      final a = GetSchemaTypeMappingArgs(
        execArgs: _execArgs(
          _obj(args['exec_args'] ?? const <String, Object?>{}, 'exec_args'),
        ),
        schemaName: _optStr(args, 'schema_name'),
      );
      // Same schema through two entry points that do not share a result
      // message: the plain one maps a package name straight to a `KclType`,
      // the under-path one wraps that package's schemas in a `SchemaTypes`.
      // Wiring either to the other would produce the other case's answer, and
      // neither case alone would notice.
      final Object? mapping = rpc == 'KclService.GetSchemaTypeMapping'
          ? _kclTypes(getSchemaTypeMapping(a).schemaTypeMapping)
          : _schemaTypes(getSchemaTypeMappingUnderPath(a).schemaTypeMapping);
      return {'type_mapping': mapping};

    case 'KclService.GetVersion':
      final r = getVersion();
      // Only the first two components are pinned: a patch release must not
      // churn the manifest, a major or minor one must.
      final parts = r.version.split('.');
      return {
        'version': parts.length >= 2 ? '${parts[0]}.${parts[1]}' : r.version,
        'has_checksum': r.checksum.isNotEmpty,
        'has_git_sha': r.gitSha.isNotEmpty,
        'has_version_info': r.versionInfo.isNotEmpty,
      };

    case 'BuiltinService.ListMethod':
      final names = listMethod().methodNameList.toList();
      return {
        'has_kclservice_ping': names.contains('KclService.Ping'),
        'has_kclservice_parse_program':
            names.contains('KclService.ParseProgram'),
        'has_builtinservice_list_method':
            names.contains('BuiltinService.ListMethod'),
        'method_count': names.length,
        'has_empty_name': names.any((n) => n.isEmpty),
      };

    case 'KclService.LintPath':
      final r = lintPath(LintPathArgs(paths: _paths(args, 'paths')));
      // The message text is the linter's and moves with the linter, so only
      // the count — and, for the case that must report something, the
      // presence — is a contract.
      return {
        'result_count': r.results.length,
        'has_result': r.results.isNotEmpty,
      };

    case 'KclService.FormatPath':
      final r = formatPath(FormatPathArgs(
        path: _resolvePath(_optStr(args, 'path')),
        dryRun: _optBool(args, 'dry_run'),
      ));
      final changed = [
        for (final p in r.changedPaths) _basename(p),
      ]..sort();
      return {'changed_count': r.changedPaths.length, 'changed': changed};

    case 'KclService.Test':
      final r = runTests(TestArgs(
        execArgs: _execArgs(
          _obj(args['exec_args'] ?? const <String, Object?>{}, 'exec_args'),
        ),
        pkgList: _paths(args, 'pkg_list'),
        runRegexp: _optStr(args, 'run_regexp'),
        failFast: _optBool(args, 'fail_fast'),
        coverage: _optBool(args, 'coverage'),
      ));
      // Durations are wall-clock and would make the case fail at random, so
      // only the names are pinned.
      return {
        'names': [for (final i in r.info) i.name]..sort(),
        'failed': [
          for (final i in r.info)
            if (i.error.isNotEmpty) i.name,
        ]..sort(),
      };

    case 'KclService.OverrideFile':
      final r = overrideFile(OverrideFileArgs(
        file: _resolvePath(_optStr(args, 'file')),
        specs: _strList(args, 'specs'),
        importPaths: _paths(args, 'import_paths'),
      ));
      return {'result': r.result, 'parse_error_count': r.parseErrors.length};

    case 'KclService.LoadSettingsFiles':
      final r = loadSettingsFiles(LoadSettingsFilesArgs(
        workDir: _resolvePath(_optStr(args, 'work_dir')),
        files: _paths(args, 'files'),
      ));
      final options = r.kclOptions.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return {
        'options': [for (final o in options) [o.key, o.value]],
        'output': r.kclCliConfigs.output,
        'overrides': r.kclCliConfigs.overrides.toList(),
        'strict_range_check': r.kclCliConfigs.strictRangeCheck,
        // A proto int64, so it arrives as an Int64 rather than a Dart int.
        'verbose': r.kclCliConfigs.verbose.toInt(),
      };

    case 'KclService.UpdateDependencies':
      final r = updateDependencies(UpdateDependenciesArgs(
        manifestPath: _resolvePath(_optStr(args, 'manifest_path')),
        vendor: _optBool(args, 'vendor'),
      ));
      return {'external_pkg_count': r.externalPkgs.length};

    default:
      throw StateError('no runner support for rpc $rpc');
  }
}

/// `ParseFile` returns a bare `Module`; an empty `ast_json` means the core had
/// nothing to say, which the manifest reads as zero statements rather than as
/// a failure to decode.
int _bodyCount(String astJson) {
  if (astJson.isEmpty) return 0;
  final module = _obj(jsonDecode(astJson), 'ast_json');
  return _arr(module['body'] ?? const <Object?>[], 'body').length;
}

/// `ParseProgram` returns a `pkgs` document rather than a module: one Module
/// per file, keyed by package path.
int _mainPackageModules(String astJson) {
  if (astJson.isEmpty) return 0;
  final document = _obj(jsonDecode(astJson), 'ast_json');
  final pkgs = _obj(document['pkgs'] ?? const <String, Object?>{}, 'pkgs');
  return _arr(pkgs['__main__'] ?? const <Object?>[], 'pkgs.__main__').length;
}

/// The schema-mapping documents, in the form every binding can produce.
///
/// Canonical protobuf JSON — the default dialect, so a field the core left
/// unset is absent rather than rendered as an empty value — spelled with the
/// proto field names the manifest is written in. `package:protobuf`'s own
/// `toProto3Json()` emits the camelCase names protoc reports (`pkgPath`) and
/// has no hook for the other dialect, so the document is projected by hand.
Object? _kclTypes(Map<String, KclType> mapping) => _canonical({
      for (final entry in mapping.entries) entry.key: _kclType(entry.value),
    });

/// The under-path variant of [_kclTypes]: the schemas of one package, wrapped
/// in the list the result message holds them in.
Object? _schemaTypes(Map<String, SchemaTypes> mapping) => _canonical({
      for (final entry in mapping.entries)
        entry.key: {
          'schema_type': [
            for (final t in entry.value.schemaType) _kclType(t),
          ],
        },
    });

/// Drops `filename` — an absolute path, so it differs on every machine — and
/// sorts every remaining object key recursively, because `KclType` holds two
/// protobuf maps whose iteration order is undefined. Dart compares maps without
/// regard to order, so the sort is about the golden file churning on every
/// regeneration and about the failure message lining up with the manifest.
Object? _canonical(Object? node) {
  if (node is Map) {
    final keys = node.keys.cast<String>().toList()..sort();
    return {
      for (final key in keys)
        if (key != 'filename') key: _canonical(node[key]),
    };
  }
  if (node is List) return [for (final item in node) _canonical(item)];
  return node;
}

/// The singular scalars of `KclType` are proto3 implicit-presence fields, so a
/// value equal to the default is indistinguishable from one the core never set
/// and must be left out entirely. The three sub-message fields always carry
/// explicit presence instead, so those need the generated `has...` check.
Map<String, Object?> _kclType(KclType t) {
  final out = <String, Object?>{};
  void keep(String key, Object? value) {
    if (value != null) out[key] = value;
  }

  keep('type', t.type.isEmpty ? null : t.type);
  keep('default', t.default_3.isEmpty ? null : t.default_3);
  keep('schema_name', t.schemaName.isEmpty ? null : t.schemaName);
  keep('schema_doc', t.schemaDoc.isEmpty ? null : t.schemaDoc);
  keep('line', t.line == 0 ? null : t.line);
  keep('filename', t.filename.isEmpty ? null : t.filename);
  keep('pkg_path', t.pkgPath.isEmpty ? null : t.pkgPath);
  keep('description', t.description.isEmpty ? null : t.description);
  if (t.hasBaseSchema()) keep('base_schema', _kclType(t.baseSchema));
  if (t.hasFunction()) keep('function', _functionType(t.function));
  if (t.hasIndexSignature()) {
    keep('index_signature', _indexSignature(t.indexSignature));
  }
  if (t.unionTypes.isNotEmpty) {
    keep('union_types', [for (final u in t.unionTypes) _kclType(u)]);
  }
  if (t.required.isNotEmpty) keep('required', t.required.toList());
  if (t.properties.isNotEmpty) {
    keep('properties', {
      for (final entry in t.properties.entries)
        entry.key: _kclType(entry.value),
    });
  }
  if (t.decorators.isNotEmpty) {
    keep('decorators', [for (final d in t.decorators) _decorator(d)]);
  }
  if (t.examples.isNotEmpty) {
    keep('examples', {
      for (final entry in t.examples.entries)
        entry.key: _example(entry.value),
    });
  }
  return out;
}

Map<String, Object?> _functionType(pb.FunctionType f) {
  final out = <String, Object?>{};
  if (f.params.isNotEmpty) {
    out['params'] = [
      for (final p in f.params)
        {
          if (p.name.isNotEmpty) 'name': p.name,
          if (p.hasTy()) 'ty': _kclType(p.ty),
        },
    ];
  }
  if (f.hasReturnTy()) out['return_ty'] = _kclType(f.returnTy);
  return out;
}

Map<String, Object?> _indexSignature(IndexSignature s) {
  final out = <String, Object?>{};
  if (s.hasKeyName()) out['key_name'] = s.keyName;
  if (s.hasKey()) out['key'] = _kclType(s.key);
  if (s.hasVal()) out['val'] = _kclType(s.val);
  if (s.anyOther) out['any_other'] = true;
  return out;
}

Map<String, Object?> _decorator(pb.Decorator d) {
  final out = <String, Object?>{};
  if (d.name.isNotEmpty) out['name'] = d.name;
  if (d.arguments.isNotEmpty) out['arguments'] = d.arguments.toList();
  if (d.keywords.isNotEmpty) {
    out['keywords'] = {for (final e in d.keywords.entries) e.key: e.value};
  }
  return out;
}

Map<String, Object?> _example(Example e) {
  final out = <String, Object?>{};
  if (e.summary.isNotEmpty) out['summary'] = e.summary;
  if (e.description.isNotEmpty) out['description'] = e.description;
  if (e.value.isNotEmpty) out['value'] = e.value;
  return out;
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

/// Every case this runner executes, recorded at the top of [_runCase] rather
/// than at the end so a case that fails is not additionally reported as
/// unexecuted. The coverage guard below is what turns "this runner quietly
/// covers half the spec" into a build failure.
final Set<String> _executed = <String>{};

/// Runs one manifest case end to end: skip-if-unsupported, dispatch, then
/// compare every field the case's `expect` object actually mentions.
void _runCase(String name) {
  _executed.add(name);
  addTearDown(_removeScratch);
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
      // Everything that is not a blob is compared through `jsonEncode`, so a
      // mismatch inside the schema-mapping document gets the same line diff
      // the generated documents do rather than a structural dump.
      final want = jsonEncode(expected);
      final have = jsonEncode(got);
      expect(have, want,
          reason: 'consistency case `$name` field `$field` mismatch:\n'
              '${_diff(want, have)}');
    }
  }
}

void main() {
  group('consistency', () {
    test('manifest is readable and version 1', () {
      expect(_loadManifest()['version'], 1);
      expect(_cases, isNotEmpty);
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
    test('parse_file', () => _runCase('parse_file'));
    test('parse_program', () => _runCase('parse_program'));
    test('list_options', () => _runCase('list_options'));
    test('list_variables', () => _runCase('list_variables'));
    test('load_package', () => _runCase('load_package'));
    test('get_schema_type_mapping', () => _runCase('get_schema_type_mapping'));
    test('get_schema_type_mapping_under_path',
        () => _runCase('get_schema_type_mapping_under_path'));
    test('get_version', () => _runCase('get_version'));
    test('list_method', () => _runCase('list_method'));
    test('lint_path_clean', () => _runCase('lint_path_clean'));
    test('lint_path_with_errors', () => _runCase('lint_path_with_errors'));
    test('format_path_dry_run', () => _runCase('format_path_dry_run'));
    test('test_run', () => _runCase('test_run'));
    test('override_file', () => _runCase('override_file'));
    test('load_settings_files', () => _runCase('load_settings_files'));
    test('update_dependencies_no_deps',
        () => _runCase('update_dependencies_no_deps'));

    // Every case in the manifest must be dispatched by a test above. Without
    // this, a runner that covers half the spec passes silently — which is how
    // this file sat at 13 cases while the manifest held 29. Declared last
    // because package:test runs a suite in declaration order: run first it
    // would report a half-covered manifest as a failure on a green run.
    test('every manifest case has a runner', () {
      final missing = [
        for (final c in _cases)
          if (!_executed.contains(c['name'])) c['name'],
      ];
      expect(missing, isEmpty, reason: 'cases.json has cases this runner does '
          'not execute; add a test method for each: $missing');
    });
  });
}

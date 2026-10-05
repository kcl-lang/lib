// End-to-end tests for the kcl_lib Dart binding.
//
// Run from the dart/ directory with `make test`. Fixtures live in
// test/test_data/ (copied from ../python/tests/test_data, mirroring the
// Julia binding's layout).
//
// The tests reference the prebuilt `libkcl` shipped under
// ../go/lib/<platform>/ via the `KCL_DART_LIB` environment variable, which
// `make test` sets automatically.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:kcl_lib/kcl_lib.dart';
import 'package:test/test.dart';

// Resolve paths relative to the package root. The `dart test` runner
// compiles tests to a kernel file under a temp directory, so `Platform.script`
// does NOT point back at `test/kcl_lib_test.dart` — but it always sets CWD
// to the package root (verified by inspection).
final String _pkgRoot = Directory.current.path;
final String _testData = '$_pkgRoot/test/test_data';
final String _schemaK = '$_testData/schema.k';

void main() {
  group('KclLib', () {
    test('libkcl is loadable', () {
      // Trigger the singleton; this opens libkcl and looks up call_native.
      // Throws StateError if KCL_DART_LIB is unset or the file is missing.
      // Field 1 wire-tag (0x0a) + length 5 + ASCII "hello".
      final raw = LibKcl().call(
        'KclService.Ping',
        Uint8List.fromList(const [0x0a, 0x05, 0x68, 0x65, 0x6c, 0x6c, 0x6f]),
      );
      expect(raw.length, greaterThan(0));
    });

    test('ping round-trips', () {
      final result = ping(PingArgs(value: 'Hello, KCL!'));
      expect(result.value, 'Hello, KCL!');
    });

    test('get_version reports the bundled libkcl', () {
      final result = getVersion();
      expect(result.version, isNotEmpty);
      expect(result.versionInfo, contains('Version'));
      expect(result.versionInfo, contains('GitCommit'));
    });

    test('exec_program runs a file', () {
      final result = execProgram(ExecProgramArgs(kFilenameList: [_schemaK]));
      expect(result.errMessage, isEmpty);
      expect(result.yamlResult, 'app:\n  replicas: 2');
      expect(result.jsonResult, contains('"app"'));
    });

    test('exec_program runs inline code', () {
      final inline = execProgram(
        ExecProgramArgs(kCodeList: ['alice = {age = 18}']),
      );
      expect(inline.errMessage, isEmpty);
      expect(inline.yamlResult, contains('age: 18'));
    });

    test('exec_program error raises KclError', () {
      Object? caught;
      try {
        execProgram(ExecProgramArgs(kFilenameList: ['file_not_found']));
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<KclError>());
      expect((caught as KclError).message, contains('Cannot find the kcl file'));
    });

    test('parse_program', () {
      final result = parseProgram(ParseProgramArgs(paths: [_schemaK]));
      expect(result.paths.length, 1);
      expect(result.errors, isEmpty);
      expect(result.astJson, isNotEmpty);
    });

    test('parse_file', () {
      final result = parseFile(ParseFileArgs(path: _schemaK));
      expect(result.deps, isEmpty);
      expect(result.errors, isEmpty);
      expect(result.astJson, isNotEmpty);
    });

    test('load_package', () {
      final result = loadPackage(LoadPackageArgs(
        parseArgs: ParseProgramArgs(paths: [_schemaK]),
        resolveAst: true,
      ));
      expect(result.parseErrors, isEmpty);
      expect(result.typeErrors, isEmpty);
      expect(result.program, contains('AppConfig'));
      final symbols = result.symbols.values.toList();
      expect(
        symbols.any((s) => s.ty.schemaName == 'AppConfig'),
        isTrue,
        reason: 'expected AppConfig in symbols, got $symbols',
      );
    });

    test('list_options', () {
      final result =
          listOptions(ParseProgramArgs(paths: ['$_testData/option/main.k']));
      expect(result.options.length, 3);
      expect(result.options[0].name, 'key1');
      expect(result.options[1].name, 'key2');
      expect(result.options[2].name, 'metadata-key');
    });

    test('list_variables', () {
      final result = listVariables(ListVariablesArgs(files: [_schemaK]));
      expect(result.parseErrors, isEmpty);
      final app = result.variables['app']!;
      expect(app.variables[0].value, contains('replicas: 2'));
    });

    test('override_file rewrites a temp copy', () async {
      final dir = await Directory.systemTemp.createTemp('kcl_lib_test_');
      try {
        final file = File('${dir.path}/main.k');
        await file.writeAsString(
          await File('$_testData/override_file/main.bak').readAsString(),
        );
        final result = overrideFile(OverrideFileArgs(
          file: file.path,
          specs: ['b.a=2'],
        ));
        expect(result.result, isTrue);
        expect(result.parseErrors, isEmpty);
        expect(
          await file.readAsString(),
          'a = 1\nb = {\n    "a": 2\n    "b": 2\n}\n',
        );
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('get_schema_type_mapping', () {
      final result = getSchemaTypeMapping(GetSchemaTypeMappingArgs(
        execArgs: ExecProgramArgs(kFilenameList: [_schemaK]),
      ));
      final app = result.schemaTypeMapping['app']!;
      expect(app.properties['replicas']!.type, 'int');
      expect(app.properties['my_func']!.type, 'function');
      final maps = app.properties['maps']!;
      expect(maps.type, 'schema');
      expect(maps.indexSignature.keyName, 'name');
      expect(maps.indexSignature.key.type, 'str');
      expect(maps.indexSignature.val.type, 'schema');
      expect(maps.indexSignature.val.properties['name']!.type, 'str');
    });

    test('get_schema_type_mapping_under_path', () {
      final root = '$_testData/get_schema_ty_under_path';
      final result = getSchemaTypeMappingUnderPath(GetSchemaTypeMappingArgs(
        execArgs: ExecProgramArgs(
          kFilenameList: ['$root/aaa'],
          externalPkgs: [ExternalPkg(pkgName: 'bbb', pkgPath: '$root/bbb')],
        ),
      ));
      expect(result.schemaTypeMapping.containsKey('__main__'), isTrue);
      expect(result.schemaTypeMapping.containsKey('bbb'), isTrue);
      final bbb = {
        for (final s in result.schemaTypeMapping['bbb']!.schemaType)
          s.schemaName: s,
      };
      expect(bbb.containsKey('Base'), isTrue);
      expect(bbb.containsKey('B'), isTrue);
      expect(bbb['Base']!.pkgPath, 'bbb');
      expect(bbb['B']!.pkgPath, 'bbb');
      expect(bbb['B']!.baseSchema.schemaName, 'Base');
      expect(bbb['B']!.baseSchema.pkgPath, 'bbb');
    });

    test('format_code', () {
      const source = 'schema Person:\n'
          '    name:   str\n'
          '    age:    int\n\n'
          '    check:\n'
          '        0 <   age <   120\n';
      final result = formatCode(FormatCodeArgs(source: source));
      expect(
        utf8.decode(result.formatted),
        'schema Person:\n'
        '    name: str\n'
        '    age: int\n\n'
        '    check:\n'
        '        0 < age < 120\n',
      );
    });

    test('format_path rewrites a temp copy', () async {
      final dir = await Directory.systemTemp.createTemp('kcl_lib_format_');
      try {
        final file = File('${dir.path}/test.k');
        await file.writeAsString('a=1\n');
        final result = formatPath(FormatPathArgs(path: file.path));
        expect(result.changedPaths.length, 1);
        expect(result.changedPaths[0], endsWith('test.k'));
        expect(await file.readAsString(), contains('a = 1'));
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('lint_path', () {
      final result = lintPath(
        LintPathArgs(paths: ['$_testData/lint_path/test-lint.k']),
      );
      expect(
        result.results
            .any((m) => m.toLowerCase().contains('imported but unused')),
        isTrue,
        reason: 'expected "imported but unused" in $result',
      );
    });

    test('validate_code accepts good data', () {
      const code = 'schema Person:\n'
          '    name: str\n'
          '    age: int\n\n'
          '    check:\n'
          '        0 < age < 120\n';
      final ok = validateCode(ValidateCodeArgs(
        code: code,
        data: '{"name": "Alice", "age": 10}',
        format: 'json',
      ));
      expect(ok.success, isTrue);
      expect(ok.errMessage, isEmpty);
    });

    test('validate_code rejects bad data', () {
      const code = 'schema Person:\n'
          '    name: str\n'
          '    age: int\n\n'
          '    check:\n'
          '        0 < age < 120\n';
      final bad = validateCode(ValidateCodeArgs(
        code: code,
        data: '{"name": "Alice", "age": 1110}',
        format: 'json',
      ));
      expect(bad.success, isFalse);
      expect(bad.errMessage, isNotEmpty);
    });

    test('load_settings_files', () {
      final result = loadSettingsFiles(LoadSettingsFilesArgs(
        workDir: _testData,
        files: ['$_testData/settings/kcl.yaml'],
      ));
      expect(result.kclCliConfigs.strictRangeCheck, isTrue);
      expect(result.kclOptions.length, 1);
      expect(result.kclOptions[0].key, 'key');
      expect(result.kclOptions[0].value, contains('value'));
    });

    test('rename rewrites a temp copy', () async {
      final dir = await Directory.systemTemp.createTemp('kcl_lib_rename_');
      try {
        final file = File('${dir.path}/main.k');
        await file.writeAsString(
          await File('$_testData/rename/main.bak').readAsString(),
        );
        final result = rename(RenameArgs(
          packageRoot: dir.path,
          symbolPath: 'a',
          filePaths: [file.path],
          newName: 'a2',
        ));
        expect(result.changedFiles.length, 1);
        expect(result.changedFiles[0], endsWith('main.k'));
        final content = await file.readAsString();
        expect(content, contains('a2 = 1'));
        expect(content, contains('b = a2'));
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('rename_code', () {
      final result = renameCode(RenameCodeArgs(
        packageRoot: '/mock/path',
        symbolPath: 'a',
        sourceCodes: {'/mock/path/main.k': 'a = 1\nb = a'}.entries,
        newName: 'a2',
      ));
      expect(result.changedCodes['/mock/path/main.k'], 'a2 = 1\nb = a2');
    });

    test('test runner', () {
      final result = runTests(
        TestArgs(pkgList: ['$_testData/testing/module/...']),
      );
      expect(result.info.length, 2);
      expect(result.info.every((i) => i.error.isEmpty), isTrue);
    });

    test('format_test_report', () {
      // The durations are microseconds; the report truncates them to whole
      // milliseconds by integer division, so 1500 renders as `1ms`.
      final report = formatTestReport(FormatTestReportArgs(
        result: TestResult(info: [
          TestCaseInfo(name: 'test_case_1', duration: Int64(1500)),
          TestCaseInfo(
            name: 'test_case_2',
            error: 'Error: assert failed',
            duration: Int64(2500),
          ),
        ]),
      )).report;

      // The prebuilt libkcl v0.13.0 runtime predates this RPC: the native
      // dispatcher panics with "unknown method name" on a background thread
      // and answers with an empty payload, so there is nothing to assert
      // against it.
      if (report.isEmpty) {
        markTestSkipped(
          'the native runtime does not implement KclService.FormatTestReport',
        );
        return;
      }

      expect(
        report,
        'test_case_1: PASS (1ms)\n'
        'test_case_2: FAIL (2ms)\n'
        'Error: assert failed\n'
        '${'-' * 80}\n'
        'PASS: 1/2\n'
        'FAIL: 1/2\n',
      );
    });

    test('format_test_report (empty result)', () {
      final report = formatTestReport(FormatTestReportArgs()).report;
      if (report.isEmpty) {
        markTestSkipped(
          'the native runtime does not implement KclService.FormatTestReport',
        );
        return;
      }
      expect(report, 'no test files\n');
    });

    test('update_dependencies (dependency-free module)', () async {
      final dir = await Directory.systemTemp.createTemp('kcl_lib_upd_');
      try {
        await File('${dir.path}/kcl.mod').writeAsString(
          '[package]\nname = "tmp_mod"\nedition = "0.0.1"\nversion = "0.0.1"\n',
        );
        final result = updateDependencies(
          UpdateDependenciesArgs(manifestPath: dir.path),
        );
        expect(result.externalPkgs, isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('update_dependencies (helloworld and flask — local sibling pkgs)',
        () async {
      // The dependencies are local sibling packages under
      // test_data/update_dependencies/{helloworld,flask}/, so no network is
      // required and a failure here is a real fixture mistake.
      final result = updateDependencies(
        UpdateDependenciesArgs(
          manifestPath: '$_testData/update_dependencies',
        ),
      );
      final pkgNames = result.externalPkgs.map((p) => p.pkgName).toList();
      expect(pkgNames.length, 2);
      expect(pkgNames, containsAll(['helloworld', 'flask']));
    });

    test('list_method reports the dispatcher RPC surface', () {
      // Routed through BuiltinService.ListMethod: spec.proto declares it
      // there, and that is where the core registers it.
      //
      // Not every prebuilt core has it. darwin-arm64 was rebuilt with the
      // RPCs; the other platforms still ship a runtime that predates them and
      // answers `unknown method name`, so the table comes back empty. Hence
      // the split: the `KclService.ListMethod` check runs either way, because
      // a table naming it would mean this wrapper is pointed at the wrong
      // service again — the bug this pins down, which failed silently by
      // decoding that empty payload into a default-valued message. The rest
      // only mean something once there is a table to inspect.
      final names = listMethod().methodNameList;
      expect(names, isNot(contains('KclService.ListMethod')));
      if (names.isEmpty) return;
      expect(names, contains('KclService.ExecProgram'));
      expect(names, contains('KclService.Ping'));
      expect(names, contains('BuiltinService.ListMethod'));
    });

    test('rawCall escapes to any RPC', () {
      // Hand-encoded PingArgs{value: "hello-kcl"}: field 1, 9-byte string.
      final payload = [0x0a, 0x09, ...utf8.encode('hello-kcl')];
      final raw = rawCall('KclService.Ping', Uint8List.fromList(payload));
      expect(raw.length, greaterThan(2));

      // rawCall shares the ERROR: convention with the typed wrappers.
      final errPayload = [0x12, 0x0e, ...utf8.encode('file_not_found')];
      Object? caught;
      try {
        rawCall('KclService.ExecProgram', Uint8List.fromList(errPayload));
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<KclError>());
      expect((caught as KclError).message,
          contains('Cannot find the kcl file'));
    });
  });

  group('plugins', () {
    tearDown(disablePlugins);

    test('routes a KCL call into a registered Dart function', () {
      // A method that ignores its arguments needs no JSON parser at all: the
      // result is handed back as raw JSON.
      registerPlugin('strings', 'join', (args, kwargs) => '"KCL.KCL.123"');
      expect(hasPlugins(), isTrue);
      expect(pluginRegistered('strings', 'join'), isTrue);
      expect(pluginRegistered('strings', 'missing'), isFalse);

      final result = execProgram(ExecProgramArgs(kCodeList: [
        'import kcl_plugin.strings\nresult = strings.join("KCL", "KCL", 123)\n'
      ]));
      expect(result.errMessage, isEmpty);
      expect(result.yamlResult, contains('KCL.KCL.123'));
    });

    test('passes the arguments as JSON strings', () {
      String? seenArgs, seenKwargs;
      registerPlugin('strings', 'args', (args, kwargs) {
        seenArgs = args;
        seenKwargs = kwargs;
        // Re-emitting the raw JSON is enough — the runtime decodes it, so the
        // KCL side sees a real list and a real dict.
        return '{"args":$args,"kwargs":$kwargs}';
      });

      final result = execProgram(ExecProgramArgs(kCodeList: [
        'import kcl_plugin.strings\nresult = strings.args("a", b = 2)\n'
      ]));
      expect(seenArgs, '["a"]');
      expect(seenKwargs, '{"b": 2}');
      expect(result.errMessage, isEmpty);
      expect(result.yamlResult, contains('- a'));
      expect(result.yamlResult, contains('b: 2'));
    });

    // A missing or throwing method is reported the way every other KCL
    // evaluation failure is: in `errMessage`, not as a native crash. These
    // wrappers return the result rather than throwing, so that is where the
    // diagnostic shows up.
    test('reports an unknown method as a KCL error rather than crashing', () {
      registerPlugin('strings', 'join', (args, kwargs) => '"unused"');
      final result = execProgram(ExecProgramArgs(kCodeList: [
        'import kcl_plugin.strings\nresult = strings.nope()\n'
      ]));
      expect(result.errMessage, contains('nope'));
      expect(result.yamlResult, isEmpty);
    });

    test('reports a throwing method as a KCL error', () {
      registerPlugin('strings', 'boom', (args, kwargs) {
        throw StateError('boom went off');
      });
      final result = execProgram(ExecProgramArgs(kCodeList: [
        'import kcl_plugin.strings\nresult = strings.boom()\n'
      ]));
      expect(result.errMessage, contains('boom went off'));
      expect(result.yamlResult, isEmpty);
    });

    test('keeps working after the registry is cleared', () {
      registerPlugin('strings', 'join', (args, kwargs) {
        throw StateError('must not be called');
      });
      disablePlugins();
      expect(hasPlugins(), isFalse);
      final result = execProgram(ExecProgramArgs(kCodeList: ['a = 1\n']));
      expect(result.errMessage, isEmpty);
      expect(result.yamlResult, contains('a: 1'));
    });
  });
}

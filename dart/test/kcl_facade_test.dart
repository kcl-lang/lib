// Tests for the high-level facade (`lib/src/kcl_facade.dart`).
//
// Run from dart/ with `make test`, or directly:
//     KCL_DART_LIB=../go/lib/<platform>/libkcl.dylib dart test
//
// The pure helpers (`splitDocuments`, `parseJsonStream`, dotted-path `get`)
// are exercised without touching the native core; the entry points need
// `libkcl` like the rest of the suite.

import 'dart:io';

import 'package:kcl_lib/kcl_lib.dart';
import 'package:test/test.dart';

// Fixtures live in test/test_data/, resolved against the package root: the
// `dart test` runner compiles to a temp kernel file, so `Platform.script` does
// not point back at the test source, but the CWD is always the package root.
final String _testData = '${Directory.current.path}/test/test_data';

void main() {
  group('splitDocuments', () {
    test('returns a single document when there is no separator', () {
      expect(splitDocuments('a: 1\nb: 2\n'), ['a: 1\nb: 2']);
    });

    test('splits on --- and drops empty documents', () {
      expect(
        splitDocuments('---\na: 1\n---\nb: 2\n'),
        ['a: 1', 'b: 2'],
      );
      expect(splitDocuments('---\n---\na: 1\n'), ['a: 1']);
    });

    test('tolerates trailing whitespace and comments on the separator', () {
      expect(splitDocuments('a: 1\n---   \nb: 2\n'), ['a: 1', 'b: 2']);
      expect(splitDocuments('a: 1\n--- # first\nb: 2\n'), ['a: 1', 'b: 2']);
    });

    test('strips trailing newlines from each document', () {
      expect(splitDocuments('a: 1\n\n\n---\nb: 2'), ['a: 1', 'b: 2']);
    });

    test('rejects a separator carrying content', () {
      expect(
        () => splitDocuments('a: 1\n--- oops\nb: 2\n'),
        throwsA(isA<KclError>()),
      );
    });

    test('returns an empty list for empty input', () {
      expect(splitDocuments(''), isEmpty);
      expect(splitDocuments('\n\n'), isEmpty);
    });
  });

  group('parseJsonStream', () {
    test('decodes one value per non-blank line', () {
      expect(
        parseJsonStream('{"a": 1}\n\n{"b": [1, 2]}\n'),
        [
          {'a': 1},
          {
            'b': [1, 2]
          }
        ],
      );
    });

    test('returns an empty list when there is no JSON', () {
      expect(parseJsonStream(''), isEmpty);
    });

    test('raises KclError on malformed JSON', () {
      expect(() => parseJsonStream('{not json}'), throwsA(isA<KclError>()));
    });
  });

  group('KclResult', () {
    final doc = KclResult(
      {
        'alice': {
          'age': 18,
          'tags': ['a', 'b'],
        },
        'n': 3,
      },
      'alice:\n  age: 18',
      '{"alice":{"age":18,"tags":["a","b"]},"n":3}',
    );

    test('exposes the yaml and json renderings', () {
      expect(doc.yamlString, 'alice:\n  age: 18');
      expect(doc.jsonString, '{"alice":{"age":18,"tags":["a","b"]},"n":3}');
    });

    test('navigates nested maps with a dotted path', () {
      expect(doc.get('n'), 3);
      expect(doc.get('alice.age'), 18);
    });

    test('indexes into lists with integer segments', () {
      expect(doc.get('alice.tags.0'), 'a');
      expect(doc.get('alice.tags.1'), 'b');
    });

    test('returns null for a null or unknown path', () {
      expect(doc.get(null), isNotNull, reason: 'null path yields the document');
      expect(doc.get('missing'), isNull);
      expect(doc.get('alice.missing.deeper'), isNull);
      expect(doc.get('alice.tags.9'), isNull);
      expect(doc.get('alice.tags.notAnIndex'), isNull);
      expect(doc.get('n.deeper'), isNull, reason: 'cannot descend into a scalar');
    });

    test('toMap returns the document', () {
      expect(doc.toMap(), {
        'alice': {
          'age': 18,
          'tags': ['a', 'b'],
        },
        'n': 3,
      });
    });

    test('toMap rejects a non-map document', () {
      expect(() => KclResult([1], '', null).toMap(),
          throwsA(isA<KclError>()));
      // A YAML-only run has no decoded value at all.
      expect(
        () => const KclResult(null, 'a: 1', null).toMap(),
        throwsA(isA<KclError>()),
      );
    });

    test('toList returns a list document', () {
      expect(KclResult([1, 2], '', null).toList(), [1, 2]);
      expect(
        () => KclResult({'a': 1}, '', null).toList(),
        throwsA(isA<KclError>()),
      );
    });

    test('jsonString re-encodes when the runtime emitted no JSON line', () {
      expect(const KclResult({'a': 1}, 'a: 1', null).jsonString, '{"a":1}');
      expect(const KclResult(null, 'a: 1', null).jsonString, '');
    });
  });

  group('KclResultList', () {
    test('is an unmodifiable list of KclResult', () {
      final list = KclResultList([const KclResult(1, 'a: 1', '1')]);
      expect(list.length, 1);
      expect(list.first.value, 1);
      expect(list[0].yamlString, 'a: 1');
      expect(() => list[0] = const KclResult(2, '', '2'),
          throwsUnsupportedError);
    });

    test('exposes the raw runtime output', () {
      final list = KclResultList(
        [const KclResult(1, 'a: 1', '1')],
        ExecProgramResult(yamlResult: 'a: 1', jsonResult: '1', logMessage: 'hi'),
      );
      expect(list.rawYamlResult, 'a: 1');
      expect(list.rawJsonResult, '1');
      expect(list.logMessage, 'hi');
    });

    test('raw output defaults to empty without a source result', () {
      final list = KclResultList([const KclResult(1, 'a: 1', '1')]);
      expect(list.rawYamlResult, '');
      expect(list.rawJsonResult, '');
      expect(list.logMessage, '');
    });

    test('first and last throw StateError when empty', () {
      final list = KclResultList(const []);
      expect(list, isEmpty);
      expect(() => list.first, throwsStateError);
    });
  });

  group('run', () {
    test('evaluates inline code into one document', () {
      final results = run('alice = {age = 18}');
      expect(results.length, 1);
      expect(results.first.yamlString, 'alice:\n  age: 18');
      expect(results.first.get('alice.age'), 18);
      expect(results.first.toMap(), {
        'alice': {'age': 18}
      });
    });

    test('throws KclError on a failing program', () {
      expect(() => run('a = '), throwsA(isA<KclError>()));
    });

    test('throws KclError when there is nothing to run', () {
      // `run('')` still has one (empty) source, so it evaluates; the guard is
      // reached through runFiles with an empty path list.
      expect(() => runFiles(const []), throwsA(isA<KclError>()));
    });

    test('applies overrides', () {
      final results = run('alice = {age = 1}',
          options: const KclOptions(overrides: ['alice.age=18']));
      expect(results.first.get('alice.age'), 18);
    });

    test('applies sortKeys', () {
      final sorted =
          run('b = 1\na = 2', options: const KclOptions(sortKeys: true));
      expect(sorted.first.yamlString, 'a: 2\nb: 1');
    });

    test('format "json" yields the json rendering only', () {
      final results =
          run('alice = {age = 18}', options: const KclOptions(format: 'json'));
      expect(results.first.jsonString, '{"alice": {"age": 18}}');
      expect(results.first.yamlString, isEmpty);
      expect(results.first.get('alice.age'), 18);
    });

    test('format "yaml" makes the value unavailable but keeps yamlString', () {
      final results =
          run('alice = {age = 18}', options: const KclOptions(format: 'yaml'));
      expect(results.first.yamlString, 'alice:\n  age: 18');
      expect(results.first.value, isNull);
      expect(
        () => results.first.toMap(),
        throwsA(isA<KclError>()),
        reason: 'value access needs the JSON result',
      );
    });
  });

  group('runFiles', () {
    test('evaluates a file from disk', () {
      final results = runFiles(['$_testData/schema.k']);
      expect(results.length, 1);
      expect(results.first.get('app.replicas'), 2);
    });

    test('rejects an empty path list', () {
      expect(() => runFiles(const []), throwsA(isA<KclError>()));
      expect(() => runFiles(['']), throwsA(isA<KclError>()));
    });
  });

  group('KclOptions', () {
    test('exposes the -E settings map form', () {
      const opts = KclOptions(settings: {'helloworld': '/tmp/hello'});
      expect(opts.settingsPackageMap, {'helloworld': '/tmp/hello'});
      expect(opts.settingsFiles, isEmpty);
    });

    test('normalizes settings files', () {
      expect(const KclOptions(settings: 'kcl.yaml').settingsFiles, ['kcl.yaml']);
      expect(
        const KclOptions(settings: ['a.yaml', 'b.yaml']).settingsFiles,
        ['a.yaml', 'b.yaml'],
      );
      expect(const KclOptions().settingsFiles, isEmpty);
    });

    test('rejects malformed settings', () {
      expect(() => const KclOptions(settings: '').settingsFiles,
          throwsA(isA<KclError>()));
      expect(() => const KclOptions(settings: <String>[]).settingsFiles,
          throwsA(isA<KclError>()));
    });
  });

  group('settings files', () {
    test('run() loads options from a kcl.yaml settings file', () {
      // test_data/settings/kcl.yaml sets strict_range_check: true and one
      // --option (`key` = `value`), so the option must reach the run.
      final results = run(
        'result = option("key")',
        options: KclOptions(settings: '$_testData/settings/kcl.yaml'),
      );
      expect(results.first.get('result'), 'value');
    });

    test('explicit options win over the settings file', () {
      final results = run(
        'alice = {age = 18}',
        options: KclOptions(
          settings: '$_testData/settings/kcl.yaml',
          // strictRangeCheck is true in the file; leaving it out here must not
          // break the run, and overriding a scalar must still win.
          sortKeys: false,
        ),
      );
      expect(results.first.get('alice.age'), 18);
    });
  });

  group('Kcl', () {
    test('exposes the same entry points as the top-level functions', () {
      expect(Kcl.run('a = 1').first.get('a'), 1);
      expect(Kcl.runFiles(['$_testData/schema.k']).first.get('app.replicas'), 2);
    });
  });
}

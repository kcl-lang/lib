import path from 'node:path'
import { fileURLToPath } from 'node:url'

import test from 'ava'

import { Kcl, KclError, KclResult, KclResultList, run, runFiles, splitDocuments } from '../facade.js'

const fixtureDir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'test_data', 'facade_settings')
const settingsYaml = path.join(fixtureDir, 'kcl.yaml')
const extPkgDir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'test_data', 'facade_extpkg', 'mypkg')
const schemaK = '__test__/test_data/schema.k'

// ---------------------------------------------------------------------------
// run / runFiles
// ---------------------------------------------------------------------------

test('run evaluates inline code', (t) => {
  const result = Kcl.run('a = 1\nb = {c = 2, d = [3, 4]}')
  t.true(result instanceof KclResultList)
  t.is(result.length, 1)
  t.true(result.first() instanceof KclResult)
  t.is(result.first().get('a'), 1)
  t.is(result.first().get('b.c'), 2)
  t.is(result.first().get('b.d.1'), 4)
  t.deepEqual(result.first().toMap(), { a: 1, b: { c: 2, d: [3, 4] } })
})

test('runFiles accepts a single path string', (t) => {
  const result = Kcl.runFiles(schemaK)
  t.is(result.length, 1)
  t.is(result.first().get('app.replicas'), 2)
})

test('runFiles accepts an array of paths', (t) => {
  const result = runFiles([schemaK])
  t.is(result.first().get('app.replicas'), 2)
})

test('functional run/runFiles aliases behave like Kcl statics', (t) => {
  t.is(run('a = 1').first().get('a'), 1)
  t.is(runFiles(schemaK).first().get('app.replicas'), 2)
})

test('instance form behaves like the static form', (t) => {
  const kcl = new Kcl()
  t.is(kcl.run('a = 1').first().get('a'), 1)
  t.is(kcl.runFiles(schemaK).first().get('app.replicas'), 2)
})

test('run without input throws KclError', (t) => {
  const err = t.throws(() => Kcl.runFiles([]), { instanceOf: KclError })
  t.true(err.message.includes('no kcl file or code'))
})

test('options overlay: overrides, selectors, disableNone, sortKeys', (t) => {
  t.is(
    Kcl.run('x = "default"', { overrides: ['x="bob"'] })
      .first()
      .get('x'),
    'bob',
  )
  t.is(
    Kcl.run('a = 1\nb = 2', { selectors: ['a'] })
      .first()
      .get(),
    1,
  )
  const omitted = Kcl.run('x = None\ny = 1', { disableNone: true })
  t.is(omitted.first().get('x'), undefined)
  t.is(omitted.first().get('y'), 1)
  const sorted = Kcl.run('z = 1\na = 2\nm = 3', { sortKeys: true })
  t.deepEqual(Object.keys(sorted.first().toMap()), ['a', 'm', 'z'])
})

test('externalPkgs accepts the name-to-path object form', (t) => {
  const result = Kcl.run('import mypkg\na = mypkg.The_answer', { externalPkgs: { mypkg: extPkgDir } })
  t.is(result.first().get('a'), 42)
})

test('externalPkgs accepts the native { pkgName, pkgPath } entry form', (t) => {
  const result = Kcl.run('import mypkg\na = mypkg.The_answer', {
    externalPkgs: [{ pkgName: 'mypkg', pkgPath: extPkgDir }],
  })
  t.is(result.first().get('a'), 42)
})

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

test('compile errors throw KclError with the diagnostic code', (t) => {
  const err = t.throws(() => Kcl.run('a = '), { instanceOf: KclError })
  t.is(err.code, 'E1001')
  t.true(err.message.includes('E1001'))
  t.true(err instanceof Error)
})

test('evaluation errors (non-empty errMessage) throw KclError', (t) => {
  const code = ['schema P:', '    age: int', '    check:', '        age > 0', 'p = P { age = -1 }'].join('\n')
  const err = t.throws(() => Kcl.run(code), { instanceOf: KclError })
  t.is(err.code, undefined)
  t.true(err.message.includes('Check failed'))
})

test('a missing settings file throws KclError', (t) => {
  const err = t.throws(() => Kcl.run('a = 1', { settings: '/nonexistent/kcl.yaml' }), { instanceOf: KclError })
  t.true(err.message.includes('no such file'))
})

test('invalid option shapes throw KclError', (t) => {
  t.throws(() => Kcl.run('a = 1', { overrides: 'not-an-array' }), { instanceOf: KclError })
  t.throws(() => Kcl.run('a = 1', { settings: [] }), { instanceOf: KclError })
  t.throws(() => Kcl.runFiles('x.k', null), { instanceOf: KclError })
})

// ---------------------------------------------------------------------------
// Settings integration
// ---------------------------------------------------------------------------

test('settings file provides the base program via the loadSettingsFiles RPC', (t) => {
  const result = Kcl.runFiles([], { settings: settingsYaml, workDir: fixtureDir })
  t.is(result.length, 1)
  // kcl_options map onto option(...) values.
  t.is(result.first().get('app.env'), 'prod')
  t.is(result.first().get('app.replicas'), 3)
  // kcl_cli_configs.files provides the entry file, overrides apply, and
  // disable_none from the file drops the `empty` attribute.
  t.is(result.first().get('app.name'), 'from-settings')
  t.is(result.first().get('empty'), undefined)
  t.false('empty' in result.first().toMap())
})

test('settings options still apply to inline code; settings files are superseded by it', (t) => {
  // `code` is the explicit input, so it wins over the `files` the settings
  // file lists (mixing both would make the runtime treat the code as the
  // replacement content of those files). kcl_options and overrides from the
  // settings file still apply to the code.
  const result = Kcl.run('env = option("env", default="dev")\napp = {name = "demo", env = env}', {
    settings: [settingsYaml],
    workDir: fixtureDir,
  })
  t.is(result.first().get('env'), 'prod')
  t.is(result.first().get('app.name'), 'from-settings')
})

test('explicit options win over the settings file', (t) => {
  // Scalar boolean: settings sets disable_none: true, the explicit false wins.
  const restored = Kcl.runFiles([], { settings: settingsYaml, workDir: fixtureDir, disableNone: false })
  t.is(restored.first().get('empty'), null)
  // Repeated fields append: the explicit override applies on top of the
  // settings-file override.
  const overridden = Kcl.runFiles([], {
    settings: settingsYaml,
    workDir: fixtureDir,
    overrides: ['app.replicas=7'],
  })
  t.is(overridden.first().get('app.name'), 'from-settings')
  t.is(overridden.first().get('app.replicas'), 7)
})

// ---------------------------------------------------------------------------
// Result helpers
// ---------------------------------------------------------------------------

test('KclResult get supports dotted paths, list indexes and dash keys', (t) => {
  const doc = Kcl.run('x = [{v = 1}, {v = 2}]\ny = {"a-b": {c = 42}}').first()
  t.is(doc.get('x.1.v'), 2)
  t.is(doc.get('y.a-b.c'), 42)
  t.is(doc.get('x.9.v'), undefined)
  t.is(doc.get('missing.key'), undefined)
  t.deepEqual(doc.get('x'), [{ v: 1 }, { v: 2 }])
})

test('KclResult yamlString / jsonString', (t) => {
  const doc = Kcl.run('a = 1\nb = "x"').first()
  t.is(doc.yamlString, 'a: 1\nb: x')
  t.true(doc.jsonString.includes('"a": 1'))
})

test('toMap / toList validate the document shape', (t) => {
  const list = Kcl.run('x = [1, 2, 3]', { selectors: ['x'] })
  t.deepEqual(list.first().toList(), [1, 2, 3])
  const err = t.throws(() => list.first().toMap(), { instanceOf: KclError })
  t.true(err.message.includes('list'))
  const mapErr = t.throws(() => Kcl.run('a = 1').first().toList(), { instanceOf: KclError })
  t.true(mapErr.message.includes('map'))
})

test('KclResultList has array semantics without the species trap', (t) => {
  const result = Kcl.run('a = 1')
  t.true(Array.isArray(result))
  t.is(result.length, 1)
  t.is(result[0], result.first())
  t.is(result.last(), result.first())
  t.is(result.get(1), undefined)
  t.deepEqual([...result], [result.first()])
  let iterated = 0
  for (const doc of result) {
    t.true(doc instanceof KclResult)
    iterated += 1
  }
  t.is(iterated, 1)
  // Symbol.species is pinned to Array: derived arrays are plain Arrays.
  const mapped = result.map((doc) => doc)
  t.true(Array.isArray(mapped))
  t.false(mapped instanceof KclResultList)
})

test('getRawJsonResult / getRawYamlResult / logMessage expose the raw response', (t) => {
  const result = Kcl.run('a = 1')
  t.is(result.getRawJsonResult(), '{"a": 1}')
  t.is(result.getRawYamlResult(), 'a: 1')
  t.is(typeof result.logMessage, 'string')
})

// ---------------------------------------------------------------------------
// Output formats
// ---------------------------------------------------------------------------

test('format json yields a JSON-only result', (t) => {
  const result = Kcl.run('a = 1', { format: 'json' })
  t.is(result.getRawYamlResult(), '')
  t.is(result.first().yamlString, '')
  t.is(result.first().get('a'), 1)
})

test('format yaml yields a YAML-only result and value access explains the gap', (t) => {
  const result = Kcl.run('a = 1', { format: 'yaml' })
  t.is(result.getRawJsonResult(), '')
  t.is(result.first().yamlString, 'a: 1')
  t.is(result.first().get('a'), undefined)
  const err = t.throws(() => result.first().toMap(), { instanceOf: KclError })
  t.true(err.message.includes('JSON'))
})

// ---------------------------------------------------------------------------
// Multi-document results
// ---------------------------------------------------------------------------

test('multi-document results split on --- with per-document access', (t) => {
  const code = 'import manifests\nx = manifests.yaml_stream([{a = 1}, {b = 2}])'
  const result = Kcl.run(code)
  t.is(result.length, 2)
  t.is(result.first().get('a'), 1)
  t.is(result.last().get('b'), 2)
  t.is(result[0].yamlString, 'a: 1')
  t.is(result[1].yamlString, 'b: 2')
  // The raw streams are preserved verbatim.
  t.is(result.getRawYamlResult(), 'a: 1\n---\nb: 2')
  t.is(result.getRawJsonResult(), '{"a": 1}\n{"b": 2}')
})

test('splitDocuments mirrors kcl-go SplitDocuments semantics', (t) => {
  t.deepEqual(splitDocuments('a: 1\n---\nb: 2\n'), ['a: 1', 'b: 2'])
  t.deepEqual(splitDocuments('a: 1\n--- \nc: 3'), ['a: 1', 'c: 3'])
  t.deepEqual(splitDocuments('a: 1\n--- # trailing comment\nc: 3'), ['a: 1', 'c: 3'])
  t.deepEqual(splitDocuments(''), [])
  // Empty documents are dropped.
  t.deepEqual(splitDocuments('---\na: 1\n---\n'), ['a: 1'])
  // A separator line carrying content raises, like kcl-go.
  const err = t.throws(() => splitDocuments('a: 1\n--- b: 2\n'), { instanceOf: KclError })
  t.true(err.message.includes('invalid document separator'))
})

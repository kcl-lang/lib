import test from 'ava'

import { execProgram, ExecProgramArgs } from '../index.js'

// Covers the fields added to the ExecProgramArgs constructor alongside
// the proto fields disable_yaml_result (6), print_override_ast (7),
// include_schema_type_path (14), show_hidden (16), error_format (19),
// format (20) and emit_attribute_metadata (21). All are optional;
// ExecProgramArgs is an input-only bag with no getters, so the wiring is
// asserted through end-to-end behaviour.
const SCHEMA_K = '__test__/test_data/schema.k'
const INFO_ATTR_K = '__test__/test_data/info_attr.k'

test('ExecProgramArgs constructor accepts the new optional fields', (t) => {
  const args = new ExecProgramArgs(
    [SCHEMA_K],
    null, // sources
    null, // workDir
    null, // args
    null, // overrides
    true, // disableYamlResult
    false, // printOverrideAst
    null, // strictRangeCheck
    null, // disableNone
    null, // verbose
    null, // debug
    null, // sortKeys
    null, // externalPkgs
    true, // includeSchemaTypePath
    null, // compileOnly
    true, // showHidden
    null, // pathSelector
    null, // fastEval
    'short', // errorFormat
    'json', // format
    null, // sourcemapOutput
    true, // emitAttributeMetadata
  )
  t.true(args instanceof ExecProgramArgs)
})

test('execProgram with format json populates jsonResult only', (t) => {
  const result = execProgram(
    new ExecProgramArgs(
      [SCHEMA_K],
      null, // sources
      null, // workDir
      null, // args
      null, // overrides
      null, // disableYamlResult
      null, // printOverrideAst
      null, // strictRangeCheck
      null, // disableNone
      null, // verbose
      null, // debug
      null, // sortKeys
      null, // externalPkgs
      null, // includeSchemaTypePath
      null, // compileOnly
      null, // showHidden
      null, // pathSelector
      null, // fastEval
      null, // errorFormat
      'json', // format
    ),
  )
  t.deepEqual(JSON.parse(result.jsonResult), { app: { replicas: 2 } })
  t.is(result.yamlResult, '')
})

test('execProgram with format yaml populates yamlResult only', (t) => {
  const result = execProgram(
    new ExecProgramArgs(
      [SCHEMA_K],
      null, // sources
      null, // workDir
      null, // args
      null, // overrides
      null, // disableYamlResult
      null, // printOverrideAst
      null, // strictRangeCheck
      null, // disableNone
      null, // verbose
      null, // debug
      null, // sortKeys
      null, // externalPkgs
      null, // includeSchemaTypePath
      null, // compileOnly
      null, // showHidden
      null, // pathSelector
      null, // fastEval
      null, // errorFormat
      'yaml', // format
    ),
  )
  t.is(result.yamlResult, 'app:\n  replicas: 2')
  t.is(result.jsonResult, '')
})

test('execProgram accepts errorFormat on the success path', (t) => {
  const result = execProgram(
    new ExecProgramArgs(
      [SCHEMA_K],
      null, // sources
      null, // workDir
      null, // args
      null, // overrides
      null, // disableYamlResult
      null, // printOverrideAst
      null, // strictRangeCheck
      null, // disableNone
      null, // verbose
      null, // debug
      null, // sortKeys
      null, // externalPkgs
      null, // includeSchemaTypePath
      null, // compileOnly
      null, // showHidden
      null, // pathSelector
      null, // fastEval
      'sarif', // errorFormat
    ),
  )
  t.is(result.yamlResult, 'app:\n  replicas: 2')
})

test('execProgram rejects an unknown errorFormat', (t) => {
  t.throws(() =>
    execProgram(
      new ExecProgramArgs(
        [SCHEMA_K],
        null, // sources
        null, // workDir
        null, // args
        null, // overrides
        null, // disableYamlResult
        null, // printOverrideAst
        null, // strictRangeCheck
        null, // disableNone
        null, // verbose
        null, // debug
        null, // sortKeys
        null, // externalPkgs
        null, // includeSchemaTypePath
        null, // compileOnly
        null, // showHidden
        null, // pathSelector
        null, // fastEval
        'bogus', // errorFormat
      ),
    ),
  )
})

// emitAttributeMetadata (proto field 21): when true, the planner appends a
// `__kcl_info_meta__` marker to schema instances whose attributes carry the
// `@info(type="attr")` role; when false/absent the output is byte-identical
// to a run without the flag.
function _infoAttrArgs(emitAttributeMetadata) {
  return new ExecProgramArgs(
    [INFO_ATTR_K],
    null, // sources
    null, // workDir
    null, // args
    null, // overrides
    null, // disableYamlResult
    null, // printOverrideAst
    null, // strictRangeCheck
    null, // disableNone
    null, // verbose
    null, // debug
    null, // sortKeys
    null, // externalPkgs
    null, // includeSchemaTypePath
    null, // compileOnly
    null, // showHidden
    null, // pathSelector
    null, // fastEval
    null, // errorFormat
    'json', // format
    null, // sourcemapOutput
    emitAttributeMetadata,
  )
}

test('execProgram with emitAttributeMetadata true succeeds and emits the info meta marker', (t) => {
  const result = execProgram(_infoAttrArgs(true))
  const parsed = JSON.parse(result.jsonResult)
  t.deepEqual(parsed.app.__kcl_info_meta__, ['id'])
  t.is(parsed.app.id, 'v1')
  t.is(parsed.app.name, 'n')
})

test('execProgram without emitAttributeMetadata omits the info meta marker', (t) => {
  const off = execProgram(_infoAttrArgs(null))
  t.false(off.jsonResult.includes('__kcl_info_meta__'))
  const absent = execProgram(_infoAttrArgs(false))
  t.false(absent.jsonResult.includes('__kcl_info_meta__'))
})

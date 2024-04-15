import test from 'ava'

import { execProgram, ExecProgramArgs } from '../index.js'

test('execProgram', (t) => {
  const result = execProgram(ExecProgramArgs(['__test__/test_data/schema.k']))
  t.is(result.yamlResult, 'app:\n  replicas: 2')
})

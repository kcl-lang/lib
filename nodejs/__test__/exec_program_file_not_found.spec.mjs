import test from 'ava'

import { execProgram, ExecProgramArgs } from '../index.js'

test('execProgramFileNotFound', (t) => {
  try {
    const result = execProgram(new ExecProgramArgs(['__test__/test_data/file_not_found.k']))
    t.is(result.yamlResult, 'app:\n  replicas: 2')
  } catch (error) {
    t.is(error.message, 'Cannot find the kcl file, please check the file path __test__/test_data/file_not_found.k')
  }
})

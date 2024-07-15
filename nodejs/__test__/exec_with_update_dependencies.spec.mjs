import test from 'ava'

import { execProgram, ExecProgramArgs, updateDependencies, UpdateDependenciesArgs } from '../index.js'

test('execWithUpdateDependencies', (t) => {
  const result = updateDependencies(new UpdateDependenciesArgs('./__test__/test_data/update_dependencies', false))
  const execResult = execProgram(
    new ExecProgramArgs(
      ['./__test__/test_data/update_dependencies/main.k'],
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      result.externalPkgs,
    ),
  )
  t.is(execResult.yamlResult, 'a: Hello World!')
})

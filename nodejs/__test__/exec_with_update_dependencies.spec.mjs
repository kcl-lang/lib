import test from 'ava'

import { execProgram, ExecProgramArgs } from '../index.js'

test('execWithUpdateDependencies', (t) => {
  // The local kcl.mod declares both deps as `path = "../_mocks/..."`, but
  // `updateDependencies` always returns `pkgPath = <manifest>/<dep_name>`
  // (it ignores the `path` directive), so we hand-build `externalPkgs`
  // pointing at the actual mock locations.
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
      undefined,
      undefined,
      [
        { pkgName: 'helloworld', pkgPath: './__test__/test_data/_mocks/helloworld' },
        { pkgName: 'flask', pkgPath: './__test__/test_data/_mocks/flask' },
      ],
    ),
  )
  t.is(execResult.yamlResult, 'a: Hello World!')
})

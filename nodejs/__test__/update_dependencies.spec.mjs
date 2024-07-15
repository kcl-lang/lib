import test from 'ava'

import { updateDependencies, UpdateDependenciesArgs } from '../index.js'

test('updateDependencies', (t) => {
  const result = updateDependencies(new UpdateDependenciesArgs('./__test__/test_data/update_dependencies', false))
  t.is(result.externalPkgs.length, 2)
})

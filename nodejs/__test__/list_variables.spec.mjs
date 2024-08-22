import test from 'ava'

import { listVariables, ListVariablesArgs } from '../index.js'

test('listVariables', (t) => {
  const result = listVariables(new ListVariablesArgs(['__test__/test_data/schema.k'], []))
  t.is(result.variables['app'][0].value, 'AppConfig {\n    replicas: 2\n}')
})

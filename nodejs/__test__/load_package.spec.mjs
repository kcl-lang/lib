import test from 'ava'

import { loadPackage, LoadPackageArgs } from '../index.js'

test('loadPackage', (t) => {
  const result = loadPackage(LoadPackageArgs(['__test__/test_data/schema.k'], [], true))
  t.deepEqual(result.parseErrors, [])
  t.deepEqual(result.typeErrors, [])
})

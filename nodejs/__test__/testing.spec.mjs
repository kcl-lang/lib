import test from 'ava'

import { test as kclTest, TestArgs } from '../index.js'

test('test', (t) => {
  const result = kclTest(new TestArgs(['./__test__/test_data/testing/module/...']))
  t.is(result.info.length, 2)
})

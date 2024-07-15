import test from 'ava'

import { parseFile, ParseFileArgs } from '../index.js'

test('parseFile', (t) => {
  const result = parseFile(new ParseFileArgs('__test__/test_data/schema.k'))
  t.is(result.deps.length, 0)
  t.is(result.errors.length, 0)
})

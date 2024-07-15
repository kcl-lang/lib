import test from 'ava'

import { parseProgram, ParseProgramArgs } from '../index.js'

test('parseProgram', (t) => {
  const result = parseProgram(new ParseProgramArgs(['__test__/test_data/schema.k']))
  t.is(result.paths.length, 1)
  t.is(result.errors.length, 0)
})

import test from 'ava'

import { formatCode, FormatCodeArgs } from '../index.js'

test('formatCode', (t) => {
  const schemaCode = `
schema Person:
    name:   str
    age:    int

    check:
        0 <   age <   120
`
  const result = formatCode(new FormatCodeArgs(schemaCode))
  t.is(
    result.formatted,
    `schema Person:
    name: str
    age: int

    check:
        0 < age < 120

`,
  )
})

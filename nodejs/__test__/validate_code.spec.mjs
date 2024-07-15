import test from 'ava'

import { validateCode, ValidateCodeArgs } from '../index.js'

test('validateCode', (t) => {
  const code = `
schema Person:
    name: str
    age: int

    check:
        0 < age < 120
`
  const data = '{"name": "Alice", "age": 10}'
  const result = validateCode(new ValidateCodeArgs(undefined, data, undefined, code))
  t.is(result.success, true)
  t.is(result.errMessage, '')
})

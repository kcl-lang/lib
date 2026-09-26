import test from 'ava'

import { ping, PingArgs } from '../index.js'

test('ping echoes back the value', (t) => {
  const args = new PingArgs('hello-kcl')
  const result = ping(args)
  t.is(result.value, 'hello-kcl')
})

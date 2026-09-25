import test from 'ava'

import { listMethod } from '../index.js'

test('listMethod returns RPC method names', (t) => {
  const result = listMethod()
  t.true(Array.isArray(result.methodNameList))
  t.true(result.methodNameList.length > 0)
  // Spot-check a couple of well-known entries so the surface stays honest.
  t.true(result.methodNameList.includes('KclService.ExecProgram'))
  t.true(result.methodNameList.includes('KclService.GetVersion'))
})

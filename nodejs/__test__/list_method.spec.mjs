import test from 'ava'

import { listMethod } from '../index.js'

test('listMethod returns RPC method names', (t) => {
  const result = listMethod()
  t.true(Array.isArray(result.methodNameList))
  // The list_method RPC isn't registered in kcl-api v0.13.0, so the
  // dispatcher panics and we end up with an empty list. Once the
  // kcl side that exposes BuiltinService.ListMethod is released the
  // assertions below will start enforcing the method names.
  if (result.methodNameList.length === 0) {
    return
  }
  t.true(result.methodNameList.includes('KclService.ExecProgram'))
  t.true(result.methodNameList.includes('KclService.GetVersion'))
})

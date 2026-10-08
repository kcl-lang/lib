import test from 'ava'

import { listMethod } from '../index.js'

test('listMethod returns RPC method names', (t) => {
  const result = listMethod()
  t.true(Array.isArray(result.methodNameList))
  t.true(result.methodNameList.includes('KclService.ExecProgram'))
  t.true(result.methodNameList.includes('KclService.GetVersion'))
  // Pin the registry size so a method cannot be dropped from the core
  // without this binding noticing -- `KclService.ListDepFiles` was removed
  // in v0.13.1, replaced by `LoadPackageResult.imports` / `kcl_mod` / `apps`.
  t.is(result.methodNameList.length, 28)
  t.false(result.methodNameList.includes('KclService.ListDepFiles'))
})

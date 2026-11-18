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
  // This binding links kcl v0.13.3 (so `TestArgs.eval_once` exists). That
  // release adds five generator RPCs that are not in this repo's spec yet.
  const addedIn0133 = [
    'KclService.GenerateRust',
    'KclService.GeneratePython',
    'KclService.GenerateGo',
    'KclService.GenerateJava',
    'KclService.GenerateTypeScript',
  ]
  for (const name of addedIn0133) {
    t.true(result.methodNameList.includes(name))
  }
  t.is(result.methodNameList.length, 28 + addedIn0133.length)
  t.false(result.methodNameList.includes('KclService.ListDepFiles'))
})

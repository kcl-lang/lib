import test from 'ava'

import { getVersion } from '../index.js'

test('getVersion', (t) => {
  const result = getVersion()
  t.is(result.versionInfo.includes('Version'), true)
  t.is(result.versionInfo.includes('GitCommit'), true)
})

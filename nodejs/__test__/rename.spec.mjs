import test from 'ava'

import { rename, RenameArgs } from '../index.js'
import { readFileSync, writeFileSync } from 'fs'
import { join } from 'path'

test('rename', (t) => {
  // Restore original content from backup
  const originalContent = readFileSync(join('__test__/test_data/rename/main.bak'), 'utf8')
  writeFileSync(join('__test__/test_data/rename/main.k'), originalContent)

  const args = new RenameArgs('__test__/test_data/rename', 'a', ['__test__/test_data/rename/main.k'], 'a2')
  const result = rename(args)
  t.is(result.changedFiles.length, 1)
})

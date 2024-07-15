import test from 'ava'

import { renameCode, RenameCodeArgs } from '../index.js'

test('renameCode', (t) => {
  const args = RenameCodeArgs('/mock/path', 'a', { '/mock/path/main.k': 'a = 1\nb = a' }, 'a2')
  const result = renameCode(args)
  t.is(result.changedCodes['/mock/path/main.k'], 'a2 = 1\nb = a2')
})

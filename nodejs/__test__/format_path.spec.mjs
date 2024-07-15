import test from 'ava'

import { formatPath, FormatPathArgs } from '../index.js'

test('formatPath', (t) => {
  const result = formatPath(new FormatPathArgs('__test__/test_data/format_path/test.k'))
  t.is(result.changedPaths.length, 0)
})

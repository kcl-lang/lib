import test from 'ava'

import { listOptions, ListOptionsArgs } from '../index.js'

test('listOptions', (t) => {
  const result = listOptions(new ListOptionsArgs(['__test__/test_data/option/main.k']))
  t.is(result.options[0].name, 'key1')
  t.is(result.options[1].name, 'key2')
  t.is(result.options[2].name, 'metadata-key')
})

import test from 'ava'

import { overrideFile, OverrideFileArgs } from '../index.js'

test('overrideFile', (t) => {
  const result = overrideFile(new OverrideFileArgs('__test__/test_data/override_file/config.k', ['app.replicas=4'], []))
  t.is(result.result, true)
})

import test from 'ava'

import { loadSettingsFiles, LoadSettingsFilesArgs } from '../index.js'

test('loadSettingsFiles', (t) => {
  const result = loadSettingsFiles(
    new LoadSettingsFilesArgs('./__test__/test_data', ['./__test__/test_data/settings/kcl.yaml']),
  )
  t.is(result.kclCliConfigs?.files.length, 0)
  t.is(result.kclCliConfigs?.strictRangeCheck, true)
  t.is(result.kclOptions[0].key, 'key')
  t.is(result.kclOptions[0].value, '"value"')
})

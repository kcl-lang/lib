import test from 'ava'

import { lintPath, LintPathArgs } from '../index.js'

test('lintPath', (t) => {
  const result = lintPath(new LintPathArgs(['__test__/test_data/lint_path/test-lint.k']))
  t.is(result.results.includes("Module 'math' imported but unused"), true)
})

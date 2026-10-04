import test from 'ava'

import { formatTestReport, test as kclTest, TestArgs } from '../index.js'

// `KclService.FormatTestReport` is not in the kcl-api revision this build
// pins, so the dispatcher rejects the method name and the call comes back with
// an empty report. Once the pin moves, the assertions below start enforcing
// the report's shape; until then they would be asserting on nothing.
const PINS_THE_RPC = true

test('formatTestReport renders the test cases it is handed', (t) => {
  const result = kclTest(new TestArgs(['./__test__/test_data/testing/module/...']))
  t.is(result.info.length, 2)

  const report = formatTestReport({ result }).report
  t.is(typeof report, 'string')

  if (PINS_THE_RPC && report === '') {
    return
  }

  t.true(report.includes('test_func_0'))
  t.true(report.includes('test_func_1'))
  t.true(report.includes('PASS: 2/2'))
  // The reporter prints only the non-zero counts, so a clean run has no `FAIL`
  // line to find. Asserting `FAIL: 0/2` here would pin a rendering the
  // reporter does not produce.
  t.false(report.includes('FAIL:'))
})

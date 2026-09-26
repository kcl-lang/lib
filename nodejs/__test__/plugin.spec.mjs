import test from 'ava'

import { execProgram, ExecProgramArgs, registerPlugin } from '../index.js'

const pluginK = '__test__/test_data/plugin.k'

test('execProgram with plugin', (t) => {
  registerPlugin('my_plugin', {
    add: (args, _kwargs) => args[0] + args[1],
  })
  const result = execProgram(new ExecProgramArgs([pluginK]))
  t.is(result.yamlResult, 'result: 2')
})

test('execProgram with plugin error', (t) => {
  const errorMsg = 'plugin error'
  registerPlugin('my_plugin', {
    add: (_args, _kwargs) => {
      throw new Error(errorMsg)
    },
  })
  const result = execProgram(new ExecProgramArgs([pluginK]))
  t.true(result.errMessage.includes(errorMsg))
})

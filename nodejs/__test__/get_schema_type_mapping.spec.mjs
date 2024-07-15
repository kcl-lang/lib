import test from 'ava'

import { getSchemaTypeMapping, GetSchemaTypeMappingArgs } from '../index.js'

test('getSchemaTypeMapping', (t) => {
  const result = getSchemaTypeMapping(new GetSchemaTypeMappingArgs(['__test__/test_data/schema.k']))
  t.is(result.schemaTypeMapping['app'], 'schema')
})

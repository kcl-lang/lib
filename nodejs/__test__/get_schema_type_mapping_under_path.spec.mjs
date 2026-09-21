import path from 'node:path'
import { fileURLToPath } from 'node:url'

import test from 'ava'

import { getSchemaTypeMappingUnderPath, GetSchemaTypeMappingArgs } from '../index.js'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), 'test_data', 'get_schema_ty_under_path')

test('getSchemaTypeMappingUnderPath', (t) => {
  const result = getSchemaTypeMappingUnderPath(
    new GetSchemaTypeMappingArgs([path.join(root, 'aaa')], null, null, [
      { pkgName: 'bbb', pkgPath: path.join(root, 'bbb') },
    ]),
  )
  // Schemas from the external dependency package must be keyed under their
  // own package name, not flattened into "__main__" — regression for
  // https://github.com/kcl-lang/kcl/issues/1546.
  t.deepEqual(result.schemaTypeMapping['bbb'].sort(), ['B', 'Base'])
  t.true(result.schemaTypeMapping['__main__'].includes('A'))
})

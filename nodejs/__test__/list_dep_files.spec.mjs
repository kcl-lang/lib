import test from 'ava'
import path from 'path'
import { fileURLToPath } from 'url'

import { listDepFiles, ListDepFilesArgs } from '../index.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
// `kcl.mod` next to the test files roots a KCL package so ListDepFiles
// has something to enumerate.
const workDir = path.resolve(__dirname, 'test_data/list_dep_files')

test('listDepFiles returns the file list under a package root', (t) => {
  const args = new ListDepFilesArgs(workDir, false, true, false)
  const result = listDepFiles(args)
  t.truthy(result.pkgroot)
  t.truthy(result.pkgpath)
  t.true(Array.isArray(result.files))
})

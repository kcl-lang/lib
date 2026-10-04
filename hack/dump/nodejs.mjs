// Cross-language AST dump for the Node.js binding.
//
//   node hack/dump/nodejs.mjs <golden.json> <out.json>
//
// Runs the binding's real decoder (`parseModule` from `nodejs/src/ast`) over
// the shared capture and writes the tree in the shape
// `hack/ast_diff/canonical.rb` compares.
//
// The Node.js decoder returns plain objects, so there is nothing to reflect
// *over*: the walk copies the object graph and, where an object carries a
// `type`, records that string as `@tag` so the comparator can check the
// binding's own claim about the discriminant. There is no `@cls`: the decoder
// has no classes, so the class cross-check the harness does for Ruby, Dart,
// Julia and Swift is not available here, and the report says so.
//
// Nothing is renamed and nothing is reshaped. A field the decoder read
// wrongly is wrong in the dump, which is the entire point.

import { readFileSync, writeFileSync } from 'node:fs'
import { parseModule } from '../../nodejs/src/ast/index.mjs'

/**
 * @param {any} value
 * @returns {any}
 */
function dump(value) {
  if (value === null || value === undefined) return value
  if (Array.isArray(value)) return value.map(dump)
  if (typeof value !== 'object') return value

  /** @type {Record<string, any>} */
  const out = {}
  for (const [k, v] of Object.entries(value)) {
    // `type` is kept as an ordinary key *and* mirrored into `@tag`; the
    // comparator drops `@`-prefixed keys and compares `type` on its own, so
    // the mirror costs nothing and gives the tag check a source.
    out[k] = dump(v)
  }
  if (typeof value.type === 'string') out['@tag'] = value.type
  return out
}

const [goldenPath, outPath] = process.argv.slice(2)
if (!goldenPath || !outPath) {
  console.error('usage: node hack/dump/nodejs.mjs <golden.json> <out.json>')
  process.exit(2)
}

const moduleAst = parseModule(readFileSync(goldenPath, 'utf8'))

writeFileSync(
  outPath,
  JSON.stringify(
    {
      schema: 'kcl-ast-canonical/1',
      binding: 'nodejs',
      mode: 'reflect',
      root: dump(moduleAst)
    },
    null,
    2
  )
)

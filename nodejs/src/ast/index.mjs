// index.mjs — Public surface of the typed AST package.
//
// Mirrors the Python ``kcl_lib.ast`` package: a thin loader that converts
// the JSON strings emitted by ``parseFile`` / ``parseProgram`` into typed
// JavaScript objects matching Rust's AST in ``crates/ast/src/ast.rs`.
//
// The wire contract those objects have to match — which nodes carry a `type`
// discriminator, which do not, and why a newtype variant's fields arrive
// flattened — is documented once in `testdata/ast/README.md` and pinned by
// `test/ast_test.mjs`.

export { parseModule, parseProgram, moduleFromWire } from './_module.mjs'
export { posFromWire, nodeFromWire, commentFromWire } from './_base.mjs'

// Flat DTOs — plain structs nested inside `NodeRef<T>`, with no tag.
export {
  configEntryFromWire,
  keywordFromWire,
  argumentsFromWire,
  checkExprFromWire,
  decoratorFromWire,
  compClauseFromWire,
  schemaIndexSignatureFromWire,
  memberOrIndexFromWire,
  targetFromWire,
} from './_dto.mjs'

// Polymorphic dispatch.
export { exprFromWire, schemaConfigFromWire } from './_expr.mjs'
export { stmtFromWire } from './_stmt.mjs'
export { typeFromWire, identifierFromWire } from './_types.mjs'

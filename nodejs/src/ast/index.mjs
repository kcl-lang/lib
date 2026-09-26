// index.mjs — Public surface of the typed AST package.
//
// Mirrors the Python ``kcl_lib.ast`` package: a thin loader that converts
// the JSON strings emitted by ``parseFile`` / ``parseProgram`` into typed
// JavaScript objects matching Rust's AST in ``crates/ast/src/ast.rs``.

export { parseModule, parseProgram, moduleFromWire } from './_module.mjs'
export {
  posFromWire,
  nodeFromWire,
  commentFromWire,
} from './_base.mjs'

// Flat DTOs (positions where the wire shape lacks the polymorphic `type` tag).
export {
  decoratorFromWire,
  schemaConfigFromWire,
  configEntryFromWire,
  keywordFromWire,
  argumentsFromWire,
  memberOrIndexFromWire,
  targetFromWire,
} from './_dto.mjs'

// Polymorphic dispatch.
export { exprFromWire } from './_expr.mjs'
export { stmtFromWire } from './_stmt.mjs'
export { typeFromWire } from './_types.mjs'

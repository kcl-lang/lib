// index.ts — Public surface of the typed AST package.
//
// Mirrors the Python ``kcl_lib.ast`` and Node.js ``src/ast`` packages: a
// thin loader that converts the JSON strings emitted by ``parseFile`` /
// ``parseProgram`` into typed objects matching Rust's AST in
// ``crates/ast/src/ast.rs``.

export { parseModule, parseProgram, moduleFromWire } from "./_module";
export { posFromWire, nodeFromWire, commentFromWire } from "./_base";

export {
  decoratorFromWire,
  schemaConfigFromWire,
  configEntryFromWire,
  keywordFromWire,
  argumentsFromWire,
  memberOrIndexFromWire,
  targetFromWire,
} from "./_dto";

export { exprFromWire } from "./_expr";
export { stmtFromWire } from "./_stmt";
export { typeFromWire } from "./_types";
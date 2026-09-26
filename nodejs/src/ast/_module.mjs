// _module.mjs — Module AST node + parseModule/parseProgram helpers.
//
// Mirrors `ast::Module` in `crates/ast/src/ast.rs`. The Rust struct has no
// `pkg` field — the Java/Go bindings previously exposed one and were aligned
// to drop it.

import { commentFromWire, nodeFromWire } from './_base.mjs'
import { stmtFromWire } from './_stmt.mjs'

/**
 * Top-level AST node for a single KCL file.
 * @typedef {Object} Module
 * @property {string} filename
 * @property {Node<string>} [doc]
 * @property {Array<Node<Stmt>>} [body]
 * @property {Array<Comment>} [comments]
 */

/**
 * @param {Record<string,any>} w
 * @returns {Module}
 */
export function moduleFromWire(w) {
  return {
    filename: w.filename || '',
    doc: nodeFromWire(w.doc, (x) => /** @type {string} */ (x)),
    body: (w.body || []).map((b) => nodeFromWire(b, stmtFromWire)),
    comments: (w.comments || []).map(commentFromWire),
  }
}

/**
 * Parse an `ast_json` string emitted by `parseFile` into a Module.
 * @param {string} astJson
 * @returns {Module}
 */
export function parseModule(astJson) {
  return moduleFromWire(JSON.parse(astJson))
}

/**
 * Parse a program `ast_json` envelope (`{root, pkgs: {__main__: [...]}}`)
 * into a list of Modules.
 * @param {string} programJson
 * @returns {Array<Module>}
 */
export function parseProgram(programJson) {
  const env = JSON.parse(programJson)
  if (Array.isArray(env)) {
    return env.map(moduleFromWire)
  }
  const main = (env.pkgs && env.pkgs.__main__) || []
  return main.map(moduleFromWire)
}

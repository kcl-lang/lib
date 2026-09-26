// _base.mjs — Pos, Node<T>, Comment, and the top-level parse helpers.
// Mirrors `ast::Pos` / `NodeRef<T>` / `Comment` in `crates/ast/src/ast.rs`.

/**
 * Source position — `Pos` in Rust.
 * @typedef {Object} Pos
 * @property {string} filename
 * @property {number} line
 * @property {number} column
 * @property {number} endLine
 * @property {number} endColumn
 */

/**
 * Wrap a value of type T with source position information — `NodeRef<T>` in Rust.
 * @template T
 * @typedef {Object} Node
 * @property {T} node
 * @property {string} [filename]
 * @property {number} [line]
 * @property {number} [column]
 * @property {number} [endLine]
 * @property {number} [endColumn]
 */

/**
 * @typedef {Node<string>} Comment
 */

/**
 * @typedef {Object} WirePos
 * @property {string} filename
 * @property {number} line
 * @property {number} column
 * @property {number} end_line
 * @property {number} end_column
 */

/**
 * @template T
 * @typedef {Object} WireNode
 * @property {T} node
 * @property {string} [filename]
 * @property {number} [line]
 * @property {number} [column]
 * @property {number} [end_line]
 * @property {number} [end_column]
 */

/**
 * Build a Pos from the wire-shape keys.
 * @param {WirePos|undefined|null} w
 * @returns {Pos|undefined}
 */
export function posFromWire(w) {
  if (!w) return undefined
  return {
    filename: w.filename,
    line: w.line,
    column: w.column,
    endLine: w.end_line,
    endColumn: w.end_column,
  }
}

/**
 * Build a Node<T> from the wire shape, applying `load` to the inner `node`.
 * @template T,U
 * @param {WireNode<U>|undefined|null} w
 * @param {(inner: U) => T} load
 * @returns {Node<T>|undefined}
 */
export function nodeFromWire(w, load) {
  if (!w) return undefined
  const inner = w.node !== undefined ? load(w.node) : undefined
  return {
    node: /** @type {T} */ (inner),
    filename: w.filename,
    line: w.line,
    column: w.column,
    endLine: w.end_line,
    endColumn: w.end_column,
  }
}

/**
 * @param {WireNode<string>|undefined|null} w
 * @returns {Comment|undefined}
 */
export function commentFromWire(w) {
  return /** @type {Comment|undefined} */ (nodeFromWire(w, (x) => /** @type {string} */ (x)))
}

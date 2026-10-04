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
 * @property {string|undefined} filename
 * @property {number|undefined} line
 * @property {number|undefined} column
 * @property {number|undefined} endLine
 * @property {number|undefined} endColumn
 */

/**
 * `NodeRef<T>` at both levels of optionality: the wrapper itself may be absent
 * — an `Option<NodeRef<T>>` field serialises as `null` — and a present wrapper
 * may still hold no value, since serde emits `"node": null` rather than
 * dropping the key. `Vec<Option<…>>` fields, `Arguments.defaults` and
 * `Arguments.ty_list` among them, are the same idea elementwise: the nulls are
 * meaningful and have to keep their slot.
 * @template T
 * @typedef {Node<T|undefined>|undefined} MaybeNode
 */

/**
 * `Comment` is a plain struct with one `String` field in Rust, so the object
 * under `node` is `{"text": "…"}` and not the text itself. Typing it as
 * `Node<string>` hands every caller an object where it promised a string.
 * @typedef {Object} Comment
 * @property {string} text
 * @property {string|undefined} filename
 * @property {number|undefined} line
 * @property {number|undefined} column
 * @property {number|undefined} endLine
 * @property {number|undefined} endColumn
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
 * @property {string|undefined} filename
 * @property {number|undefined} line
 * @property {number|undefined} column
 * @property {number|undefined} end_line
 * @property {number|undefined} end_column
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
 * @returns {MaybeNode<T>}
 */
export function nodeFromWire(w, load) {
  if (!w) return undefined
  // Not `Node<T>`: serde emits `"node": null` rather than dropping the key, so
  // a present wrapper can still carry no value. Casting `inner` to `T` here
  // would be a claim the code below does not make.
  const inner = w.node !== undefined ? load(w.node) : undefined
  return {
    node: inner,
    filename: w.filename,
    line: w.line,
    column: w.column,
    endLine: w.end_line,
    endColumn: w.end_column,
  }
}

/**
 * @param {WireNode<{text?: string}>|undefined|null} w
 * @returns {Comment|undefined}
 */
export function commentFromWire(w) {
  const n = nodeFromWire(w, (x) => x)
  if (n === undefined) return undefined
  // `nodeFromWire` wraps whatever the loader returns, so the struct is still
  // under `node` — the position keys are the ones worth keeping, and the text
  // is the one field the struct actually has.
  const { node, ...pos } = n
  return { ...pos, text: (node && node.text) || '' }
}

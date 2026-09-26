// _types.mjs — Type hierarchy. Mirrors `ast::Type` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]` so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `typeFromWire` dispatches on that tag.

import { nodeFromWire } from './_base.mjs'

/**
 * @typedef {Object} BasicType
 * @property {string} type     "Bool" | "Int" | "Float" | "Str" | "None" | "Any" | "Void" | "Undefined"
 * @property {boolean} [isLiteral]
 */

/** @param {Record<string,any>} w */
function basicFromWire(w) {
  return { type: w.type, isLiteral: w.is_literal === true }
}

/**
 * @typedef {Object} ListType
 * @property {string} type   "List"
 * @property {*} [innerType]
 */

/** @param {Record<string,any>} w */
function listFromWire(w) {
  return { type: w.type, innerType: w.inner_type }
}

/**
 * @typedef {Object} DictType
 * @property {string} type   "Dict"
 * @property {*} [keyType]
 * @property {*} [valueType]
 */

/** @param {Record<string,any>} w */
function dictFromWire(w) {
  return { type: w.type, keyType: w.key_type, valueType: w.value_type }
}

/**
 * @typedef {Object} SchemaRefType
 * @property {string} type   "SchemaRef"
 * @property {string} [schemaName]
 * @property {string} [pkgpath]
 */

/** @param {Record<string,any>} w */
function schemaRefFromWire(w) {
  return { type: w.type, schemaName: w.schema_name, pkgpath: w.pkgpath }
}

/**
 * @typedef {Object} LiteralType
 * @property {string} type   "Literal"
 * @property {*} [value]
 */

/** @param {Record<string,any>} w */
function literalFromWire(w) {
  return { type: w.type, value: w.value }
}

/**
 * @typedef {Object} FunctionType
 * @property {string} type   "Function"
 * @property {*} [params]
 * @property {*} [returnTy]
 */

/** @param {Record<string,any>} w */
function functionFromWire(w) {
  return { type: w.type, params: w.params, returnTy: w.return_ty }
}

/**
 * @typedef {Object} UnionType
 * @property {string} type   "Union"
 * @property {Array<*>} [types]
 */

/** @param {Record<string,any>} w */
function unionFromWire(w) {
  return { type: w.type, types: w.types }
}

/**
 * @typedef {Object} KeyValueType
 * @property {string} type   "KeyValue"
 * @property {*} [key]
 * @property {*} [value]
 */

/** @param {Record<string,any>} w */
function keyValueFromWire(w) {
  return { type: w.type, key: w.key, value: w.value }
}

const REGISTRY = {
  Bool: basicFromWire,
  Int: basicFromWire,
  Float: basicFromWire,
  Str: basicFromWire,
  None: basicFromWire,
  Any: basicFromWire,
  Void: basicFromWire,
  Undefined: basicFromWire,
  List: listFromWire,
  Dict: dictFromWire,
  SchemaRef: schemaRefFromWire,
  Literal: literalFromWire,
  Function: functionFromWire,
  Union: unionFromWire,
  KeyValue: keyValueFromWire,
}

/**
 * Polymorphic Type loader.
 * @param {Record<string,any>|undefined|null} w
 */
export function typeFromWire(w) {
  if (!w) return undefined
  if (!w.type) return undefined
  const loader = REGISTRY[w.type]
  if (loader) return loader(w)
  return { type: w.type }
}

// Re-export the Node helper for callers that want it.
export { nodeFromWire }

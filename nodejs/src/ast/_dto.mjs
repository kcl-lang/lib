// _dto.mjs — Flat DTOs for positions inside NodeRef<T> where the wire shape
// lacks the polymorphic `type` discriminator. Mirrors the Java/Go bindings
// (see AST_DRIFT.md note A).
//
// The cycle between this module and _expr is broken with namespace imports —
// `_expr.exprFromWire` is read lazily at call time, so it's safe even though
// the modules load each other.

import { nodeFromWire } from './_base.mjs'
import * as _expr from './_expr.mjs'
import * as _types from './_types.mjs'

/**
 * Flat decorator payload — `@deprecated(strict=True)`.
 * @typedef {Object} Decorator
 * @property {Node<*>} [func]
 * @property {Array<Node<*>>} [args]
 * @property {Array<Node<*>>} [keywords]
 */

/** @param {Record<string,any>|undefined|null} w */
export function decoratorFromWire(w) {
  if (!w) return undefined
  return {
    func: nodeFromWire(w.func, _expr.exprFromWire),
    args: (w.args || []).map((a) => nodeFromWire(a, _expr.exprFromWire)),
    keywords: (w.keywords || []).map((k) => nodeFromWire(k, keywordFromWire)),
  }
}

/**
 * Inline schema instantiation payload — `ASchema(args) { ... }`.
 * @typedef {Object} SchemaConfig
 * @property {Node<*>} [name]
 * @property {Array<Node<*>>} [args]
 * @property {Array<Node<*>>} [kwargs]
 * @property {Node<*>} [config]
 */

/** @param {Record<string,any>|undefined|null} w */
export function schemaConfigFromWire(w) {
  if (!w) return undefined
  return {
    name: nodeFromWire(w.name, _expr.exprFromWire),
    args: (w.args || []).map((a) => nodeFromWire(a, _expr.exprFromWire)),
    kwargs: (w.kwargs || []).map((k) => nodeFromWire(k, keywordFromWire)),
    config: nodeFromWire(w.config, _expr.exprFromWire),
  }
}

/**
 * Config entry — `key = value` or `key: value`.
 * @typedef {Object} ConfigEntry
 * @property {Node<*>} [key]
 * @property {Node<*>} [value]
 * @property {string} [operation]  ConfigEntryOperation
 * @property {boolean} [isShorthand]
 */

/** @param {Record<string,any>|undefined|null} w */
export function configEntryFromWire(w) {
  if (!w) return undefined
  return {
    key: nodeFromWire(w.key, _expr.exprFromWire),
    value: nodeFromWire(w.value, _expr.exprFromWire),
    operation: w.operation,
    isShorthand: w.is_shorthand === true,
  }
}

/**
 * Keyword argument — `arg = value`.
 * @typedef {Object} Keyword
 * @property {Node<*>} [arg]
 * @property {Node<*>} [value]
 */

/** @param {Record<string,any>|undefined|null} w */
export function keywordFromWire(w) {
  if (!w) return undefined
  return {
    arg: nodeFromWire(w.arg, _expr.exprFromWire),
    value: nodeFromWire(w.value, _expr.exprFromWire),
  }
}

/**
 * Lambda parameter list.
 * @typedef {Object} Arguments
 * @property {Array<Node<*>>} [args]
 * @property {Array<Node<*>>} [defaults]
 * @property {Array<Node<*>>} [tyList]
 */

/** @param {Record<string,any>|undefined|null} w */
export function argumentsFromWire(w) {
  if (!w) return undefined
  return {
    args: (w.args || []).map((a) => nodeFromWire(a, _expr.exprFromWire)),
    defaults: (w.defaults || []).map((d) => nodeFromWire(d, _expr.exprFromWire)),
    tyList: (w.ty_list || []).map((t) => nodeFromWire(t, _types.typeFromWire)),
  }
}

/**
 * Member or index — `a.b` or `a[0]`.
 * @typedef {Object} MemberOrIndex
 * @property {Node<string>} [member]   payload for `{"type":"Member", "value":<NodeRef<String>>}`
 * @property {Node<*>} [index]         payload for `{"type":"Index",  "value":<NodeRef<Expr>>}`
 */

/** @param {Record<string,any>|undefined|null} w */
export function memberOrIndexFromWire(w) {
  if (!w) return undefined
  if (w.type === 'Member') return { member: nodeFromWire(w.value, (x) => /** @type {string} */ x) }
  if (w.type === 'Index') return { index: nodeFromWire(w.value, _expr.exprFromWire) }
  return {}
}

/**
 * `ast::Target` struct — `a.b.c`.
 * @typedef {Object} Target
 * @property {Node<string>} [name]
 * @property {Array<MemberOrIndex>} [paths]
 * @property {string} pkgpath
 */

/** @param {Record<string,any>|undefined|null} w */
export function targetFromWire(w) {
  if (!w) return undefined
  return {
    name: nodeFromWire(w.name, (x) => /** @type {string} */ x),
    paths: (w.paths || []).map(memberOrIndexFromWire),
    pkgpath: w.pkgpath || '',
  }
}

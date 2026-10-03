// _dto.mjs — Flat DTOs the AST nests inside `NodeRef<T>` where the wire shape
// lacks a polymorphic `type` discriminator. Mirrors
// `../kcl/crates/ast/src/ast.rs`, where these are plain structs rather than
// enum variants.
//
// Two things are easy to get wrong here and both fail silently, because an
// object with no `type` key decodes to null rather than throwing:
//
//   1. `ast::Expr` and `ast::Stmt` are internally tagged, and their variants
//      are *newtypes over a struct*, so serde flattens the struct's fields
//      into the same object. `Expr::Check(CheckExpr)` arrives as
//      `{"type": "Check", "test": ..., "if_cond": ..., "msg": ...}` — there is
//      no `check` wrapper key to descend through.
//   2. These structs carry no tag at all, so they cannot be dispatched on.
//      `SchemaStmt.checks` is `Vec<NodeRef<CheckExpr>>` and its elements are
//      bare `{test, if_cond, msg}` objects.
//
// The cycle between this module and _expr is broken with namespace imports —
// `_expr.exprFromWire` is read lazily at call time, so it's safe even though
// the modules load each other.

import { nodeFromWire } from './_base.mjs'
import * as _expr from './_expr.mjs'
import { identifierFromWire, typeFromWire } from './_types.mjs'

/**
 * `ast::ConfigEntry` — one `key = value` / `key: value` / `key += value`.
 * @typedef {Object} ConfigEntry
 * @property {MaybeNode<*>|undefined} key
 * @property {MaybeNode<*>} value
 * @property {string|undefined} operation  "Union" | "Override" | "Insert"
 * @property {boolean} isShorthand  ES6 `{name}` form; absent on the wire
 *   when false, so this is always a real boolean here
 */

/** @param {Record<string,any>|undefined|null} w */
export function configEntryFromWire(w) {
  if (!w) return undefined
  return {
    key: nodeFromWire(w.key, _expr.exprFromWire),
    value: nodeFromWire(w.value, _expr.exprFromWire),
    operation: w.operation,
    // `is_shorthand` carries `skip_serializing_if = "is_false"`, so the key
    // is missing rather than false on the wire.
    isShorthand: w.is_shorthand === true,
  }
}

/**
 * `ast::Keyword` — `arg=value`.
 * @typedef {Object} Keyword
 * @property {MaybeNode<Identifier>} arg
 * @property {MaybeNode<*>|undefined} value
 */

/** @param {Record<string,any>|undefined|null} w */
export function keywordFromWire(w) {
  if (!w) return undefined
  return {
    // `Keyword.arg` is a `NodeRef<Identifier>`, not a `NodeRef<Expr>`.
    arg: nodeFromWire(w.arg, identifierFromWire),
    value: nodeFromWire(w.value, _expr.exprFromWire),
  }
}

/**
 * `ast::Arguments` — a lambda's parameter list.
 * @typedef {Object} Arguments
 * @property {Array<MaybeNode<Identifier>>} args
 * @property {Array<MaybeNode<*>|null>} defaults  same length as `args`; nulls kept
 * @property {Array<MaybeNode<Type>|null>} tyList  same length as `args`; nulls kept
 */

/** @param {Record<string,any>|undefined|null} w */
export function argumentsFromWire(w) {
  if (!w) return undefined
  return {
    args: (w.args || []).map((/** @type {any} */ a) => nodeFromWire(a, identifierFromWire)),
    defaults: (w.defaults || []).map((/** @type {any} */ d) => nodeFromWire(d, _expr.exprFromWire)),
    tyList: (w.ty_list || []).map((/** @type {any} */ t) => nodeFromWire(t, typeFromWire)),
  }
}

/**
 * `ast::CheckExpr` — `len(attr) > 3 if attr, "message"`. It is also the payload
 * of `Expr::Check`, which serde flattens into the same object, so the `type`
 * key is only present on the expression.
 * @typedef {Object} CheckExpr
 * @property {'Check'|undefined|'Check'|undefined} type
 * @property {MaybeNode<Expr>} test
 * @property {MaybeNode<Expr>|undefined} ifCond
 * @property {MaybeNode<Expr>|undefined} msg
 */

/** @param {Record<string,any>|undefined|null} w */
export function checkExprFromWire(w) {
  if (!w) return undefined
  return {
    test: nodeFromWire(w.test, _expr.exprFromWire),
    ifCond: nodeFromWire(w.if_cond, _expr.exprFromWire),
    msg: nodeFromWire(w.msg, _expr.exprFromWire),
  }
}

/**
 * `ast::CallExpr`. A decorator (`@deprecated(strict=True)`) is one of these
 * — `SchemaStmt.decorators` is `Vec<NodeRef<CallExpr>>`, and only the *enum*
 * is tagged, so each element arrives as a bare `{func, args, keywords}`.
 * @typedef {Object} Decorator
 * @property {MaybeNode<Expr>} func
 * @property {Array<MaybeNode<Expr>>} args
 * @property {Array<MaybeNode<Keyword>>} keywords
 */

/** @param {Record<string,any>|undefined|null} w */
export function decoratorFromWire(w) {
  if (!w) return undefined
  return {
    func: nodeFromWire(w.func, _expr.exprFromWire),
    args: (w.args || []).map((/** @type {any} */ a) => nodeFromWire(a, _expr.exprFromWire)),
    keywords: (w.keywords || []).map((/** @type {any} */ k) => nodeFromWire(k, keywordFromWire)),
  }
}

/**
 * `ast::CompClause` — one `for x in y if z` leg of a comprehension.
 * @typedef {Object} CompClause
 * @property {Array<MaybeNode<*>>} targets
 * @property {MaybeNode<*>} iter
 * @property {Array<MaybeNode<*>>} ifs
 */

/** @param {Record<string,any>|undefined|null} w */
export function compClauseFromWire(w) {
  if (!w) return undefined
  return {
    // `CompClause.targets` is `Vec<NodeRef<Identifier>>`, not `NodeRef<Expr>`.
    targets: (w.targets || []).map((/** @type {any} */ t) => nodeFromWire(t, identifierFromWire)),
    iter: nodeFromWire(w.iter, _expr.exprFromWire),
    ifs: (w.ifs || []).map((/** @type {any} */ i) => nodeFromWire(i, _expr.exprFromWire)),
  }
}

/**
 * `ast::SchemaIndexSignature` — the `[k: str]: int` statement in a schema
 * body. Note it is a *body statement*, not part of the `schema` header:
 * `schema Bag[k: str]` is a generic schema whose `args` is an `Arguments`.
 * @typedef {Object} SchemaIndexSignature
 * @property {MaybeNode<string>|undefined} keyName
 * @property {MaybeNode<*>|undefined} value
 * @property {boolean} anyOther
 * @property {MaybeNode<Type>} keyTy
 * @property {MaybeNode<Type>} valueTy
 */

/** @param {Record<string,any>|undefined|null} w */
export function schemaIndexSignatureFromWire(w) {
  if (!w) return undefined
  return {
    keyName: nodeFromWire(w.key_name, (x) => /** @type {string} */ x),
    value: nodeFromWire(w.value, _expr.exprFromWire),
    anyOther: w.any_other === true,
    keyTy: nodeFromWire(w.key_ty, typeFromWire),
    valueTy: nodeFromWire(w.value_ty, typeFromWire),
  }
}

/**
 * `ast::SchemaExpr` — the untagged form, which is what
 * `UnificationStmt.value` carries. The tagged `Expr::Schema` variant is
 * `SchemaExpr` in `_expr.mjs`, which adds the `type` key to this shape; Java
 * draws the same distinction with a second, field-identical `SchemaConfig`.
 * @typedef {Object} SchemaConfig
 * @property {MaybeNode<Identifier>} name
 * @property {Array<MaybeNode<Expr>>} args
 * @property {Array<MaybeNode<Keyword>>} kwargs
 * @property {MaybeNode<Expr>} config
 */

/**
 * `ast::MemberOrIndex` — the `tag + content` enum behind a `Target`'s paths.
 * Its `value` is itself a `NodeRef`, so `Member` wraps a `NodeRef<String>`
 * and `Index` a `NodeRef<Expr>`.
 * @typedef {Object} MemberOrIndex
 * @property {'Member'|'Index'} [type]
 * @property {MaybeNode<string>} [member]
 * @property {MaybeNode<*>} [index]
 */

/** @param {Record<string,any>|undefined|null} w @returns {MemberOrIndex|undefined} */
export function memberOrIndexFromWire(w) {
  if (!w) return undefined
  if (w.type === 'Member') {
    return { type: 'Member', member: nodeFromWire(w.value, (x) => /** @type {string} */ x) }
  }
  if (w.type === 'Index') return { type: 'Index', index: nodeFromWire(w.value, _expr.exprFromWire) }
  return {}
}

/**
 * `ast::Target` — `a.b[0].c`.
 * @typedef {Object} Target
 * @property {MaybeNode<string>} name
 * @property {Array<MemberOrIndex>} paths
 * @property {string} pkgpath
 */

/** @param {Record<string,any>|undefined|null} w */
export function targetFromWire(w) {
  if (!w) return undefined
  return {
    name: nodeFromWire(w.name, (x) => /** @type {string} */ x),
    paths: (w.paths || [])
      .map((/** @type {any} */ p) => memberOrIndexFromWire(p))
      .filter((/** @type {MemberOrIndex|undefined} */ p) => p !== undefined),
    pkgpath: w.pkgpath || '',
  }
}

/**
 * @template T
 * @typedef {import('./_base.mjs').Node<T>} Node
 */
/** @template T @typedef {import('./_base.mjs').MaybeNode<T>} MaybeNode */
/** @typedef {import('./_types.mjs').Identifier} Identifier */
/** @typedef {import('./_types.mjs').Type} Type */
/** @typedef {import('./_expr.mjs').Expr} Expr */

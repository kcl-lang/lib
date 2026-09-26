// _stmt.mjs — Statement hierarchy. Mirrors `ast::Stmt` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]`, so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `stmtFromWire` dispatches on that tag.

import { nodeFromWire } from './_base.mjs'
import * as _dto from './_dto.mjs'
import * as _expr from './_expr.mjs'
import * as _types from './_types.mjs'

/** @param {Record<string,any>} w */
function exprStmtFromWire(w) {
  return {
    exprs: (w.exprs || []).map((e) => nodeFromWire(e, _expr.exprFromWire)),
  }
}

/** @param {Record<string,any>} w */
function unificationStmtFromWire(w) {
  return {
    target: nodeFromWire(w.target, (x) => x),
    value: nodeFromWire(w.value, _dto.schemaConfigFromWire),
  }
}

/** @param {Record<string,any>} w */
function assignStmtFromWire(w) {
  return {
    targets: (w.targets || []).map((t) => nodeFromWire(t, _dto.targetFromWire)),
    ty: nodeFromWire(w.ty, _types.typeFromWire),
    value: nodeFromWire(w.value, _expr.exprFromWire),
  }
}

/** @param {Record<string,any>} w */
function schemaStmtFromWire(w) {
  return {
    doc: nodeFromWire(w.doc, (x) => /** @type {string} */ (x)),
    name: nodeFromWire(w.name, (x) => /** @type {string} */ (x)),
    parentName: nodeFromWire(w.parent_name, (x) => x),
    forHostName: nodeFromWire(w.for_host_name, (x) => x),
    isMixin: w.is_mixin === true,
    isProtocol: w.is_protocol === true,
    args: nodeFromWire(w.args, _dto.argumentsFromWire),
    mixins: (w.mixins || []).map((m) => nodeFromWire(m, (x) => x)),
    body: (w.body || []).map((b) => nodeFromWire(b, stmtFromWire)),
    decorators: (w.decorators || []).map((deco) => nodeFromWire(deco, _dto.decoratorFromWire)),
    checks: (w.checks || []).map((c) => nodeFromWire(c, _expr.exprFromWire)),
    indexSignature: nodeFromWire(w.index_signature, (x) => x),
  }
}

/** @param {Record<string,any>} w */
function schemaAttrFromWire(w) {
  return {
    doc: w.doc || '',
    name: nodeFromWire(w.name, (x) => /** @type {string} */ (x)),
    op: w.op,
    value: nodeFromWire(w.value, _expr.exprFromWire),
    isOptional: w.is_optional === true,
    decorators: (w.decorators || []).map((deco) => nodeFromWire(deco, _dto.decoratorFromWire)),
    ty: nodeFromWire(w.ty, _types.typeFromWire),
  }
}

/** @param {Record<string,any>} w */
function ruleStmtFromWire(w) {
  return {
    doc: nodeFromWire(w.doc, (x) => /** @type {string} */ (x)),
    name: nodeFromWire(w.name, (x) => /** @type {string} */ (x)),
    parentRules: (w.parent_rules || []).map((p) => nodeFromWire(p, (x) => x)),
    decorators: (w.decorators || []).map((deco) => nodeFromWire(deco, _dto.decoratorFromWire)),
    checks: (w.checks || []).map((c) => nodeFromWire(c, _expr.exprFromWire)),
    args: nodeFromWire(w.args, _dto.argumentsFromWire),
    forHostName: nodeFromWire(w.for_host_name, (x) => x),
  }
}

/** @param {Record<string,any>} w */
function importStmtFromWire(w) {
  const node = w.node || {}
  return {
    path: node.path,
    asName: node.as_name,
    pkgName: node.pkg_name,
    pkgRoot: node.pkg_root,
  }
}

const REGISTRY = {
  Expr: exprStmtFromWire,
  Unification: unificationStmtFromWire,
  Assign: assignStmtFromWire,
  Schema: schemaStmtFromWire,
  SchemaAttr: schemaAttrFromWire,
  Rule: ruleStmtFromWire,
  Import: importStmtFromWire,
}

/**
 * Polymorphic Stmt loader.
 * @param {Record<string,any>|undefined|null} w
 */
export function stmtFromWire(w) {
  if (!w) return undefined
  if (!w.type) return undefined
  const variant = w.type
  const loader = REGISTRY[variant]
  if (loader) return Object.assign({ type: variant }, loader(w))
  return { type: variant }
}

// _stmt.mjs — Statement hierarchy. Mirrors `ast::Stmt` in `crates/ast/src/ast.rs`.
//
// `Stmt` is `#[serde(tag = "type")]` and its variants are newtypes over
// structs, so serde flattens the fields into the same object. `If` is both
// a `Stmt` and an `Expr` — the tag alone does not say which, so the
// statement loader and the expression loader each own their own `If`.

import { nodeFromWire } from './_base.mjs'
import * as _dto from './_dto.mjs'
import * as _expr from './_expr.mjs'
import { identifierFromWire, typeFromWire } from './_types.mjs'

/**
 * @typedef {Object} TypeAliasStmt
 * @property {'TypeAlias'} type
 * @property {MaybeNode<Identifier>} typeName
 * @property {MaybeNode<string>} typeValue
 * @property {MaybeNode<Type>} ty
 */

/** @typedef {Object} ExprStmt @property {'Expr'} type @property {Array<MaybeNode<Expr>>} exprs */

/**
 * `s: Person { ... }`. `target` is a single `NodeRef<Identifier>` — the
 * declaration name — where `AssignStmt` has a list of `Target`s.
 * @typedef {Object} UnificationStmt
 * @property {'Unification'} type
 * @property {MaybeNode<Identifier>} target
 * @property {MaybeNode<SchemaConfig>} value
 */

/** @typedef {Object} AssignStmt @property {'Assign'} type @property {Array<MaybeNode<Target>>} targets @property {MaybeNode<Type>} ty @property {MaybeNode<Expr>} value */

/**
 * `AugAssign` takes a singular `target` where `Assign` takes `targets`.
 * @typedef {Object} AugAssignStmt
 * @property {'AugAssign'} type
 * @property {MaybeNode<Target>} target
 * @property {MaybeNode<Expr>} value
 * @property {string|undefined} op
 */

/** @typedef {Object} AssertStmt @property {'Assert'} type @property {MaybeNode<Expr>} test @property {MaybeNode<Expr>} ifCond @property {MaybeNode<Expr>} msg */

/**
 * `If` is both a `Stmt` and an `Expr`; the tag alone does not say which, so
 * the statement loader and the expression loader each own their own `If`.
 * @typedef {Object} IfStmt
 * @property {'If'} type
 * @property {Array<MaybeNode<Stmt>>} body
 * @property {MaybeNode<Expr>} cond
 * @property {Array<MaybeNode<Stmt>>} orelse
 */

/**
 * `ImportStmt` is flat: `path` is a `NodeRef<String>` and `rawpath`, `name`,
 * `asname` and `pkgName` are plain strings beside it. There is no `node`
 * wrapper object, and no `asName` / `pkgRoot` field.
 * @typedef {Object} ImportStmt
 * @property {'Import'} type
 * @property {MaybeNode<string>} path
 * @property {string} rawpath
 * @property {string} name
 * @property {MaybeNode<string>} asname
 * @property {string} pkgName
 */

/**
 * @typedef {Object} SchemaStmt
 * @property {'Schema'} type
 * @property {MaybeNode<string>} doc
 * @property {MaybeNode<string>} name
 * @property {MaybeNode<Identifier>} parentName
 * @property {MaybeNode<Identifier>} forHostName
 * @property {boolean} isMixin
 * @property {boolean} isProtocol
 * @property {MaybeNode<Arguments>} args
 * @property {Array<MaybeNode<Identifier>>} mixins
 * @property {Array<MaybeNode<Stmt>>} body
 * @property {Array<MaybeNode<Decorator>>} decorators
 * @property {Array<MaybeNode<CheckExpr>>} checks
 * @property {MaybeNode<SchemaIndexSignature>} indexSignature
 */

/** @typedef {Object} SchemaAttr @property {'SchemaAttr'} type @property {string} doc @property {MaybeNode<string>} name @property {string|undefined} op @property {MaybeNode<Expr>} value @property {boolean} isOptional @property {Array<MaybeNode<Decorator>>} decorators @property {MaybeNode<Type>} ty */

/** @typedef {Object} RuleStmt @property {'Rule'} type @property {MaybeNode<string>} doc @property {MaybeNode<string>} name @property {Array<MaybeNode<Identifier>>} parentRules @property {Array<MaybeNode<Decorator>>} decorators @property {Array<MaybeNode<CheckExpr>>} checks @property {MaybeNode<Arguments>} args @property {MaybeNode<Identifier>} forHostName */

/**
 * A tag this build does not know about. Kept rather than dropped, so a caller
 * can still see what the parser emitted. Java has no equivalent — Jackson
 * raises on an unregistered subtype — so this is a nodejs-only variant.
 * @typedef {Object} UnknownStmt
 * @property {string} type
 * @property {true} unknown
 */

/**
 * @typedef {TypeAliasStmt|ExprStmt|UnificationStmt|AssignStmt|AugAssignStmt|AssertStmt|IfStmt|ImportStmt|SchemaStmt|SchemaAttr|RuleStmt|UnknownStmt} Stmt
 */

/** @param {Record<string,any>} w @returns {Omit<TypeAliasStmt,'type'>} */
function typeAliasStmtFromWire(w) {
  return {
    typeName: nodeFromWire(w.type_name, identifierFromWire),
    typeValue: nodeFromWire(w.type_value, (x) => /** @type {string} */ x),
    ty: nodeFromWire(w.ty, typeFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<ExprStmt,'type'>} */
function exprStmtFromWire(w) {
  return {
    exprs: (w.exprs || []).map((/** @type {any} */ e) => nodeFromWire(e, _expr.exprFromWire)),
  }
}

/** @param {Record<string,any>} w @returns {Omit<UnificationStmt,'type'>} */
function unificationStmtFromWire(w) {
  return {
    target: nodeFromWire(w.target, identifierFromWire),
    // `UnificationStmt.value` is a `NodeRef<SchemaExpr>` — a plain struct, so
    // it arrives untagged and cannot be dispatched on. Running it through the
    // `Expr` loader returns undefined.
    value: nodeFromWire(w.value, _expr.schemaConfigFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<AssignStmt,'type'>} */
function assignStmtFromWire(w) {
  return {
    targets: (w.targets || []).map((/** @type {any} */ t) => nodeFromWire(t, _dto.targetFromWire)),
    ty: nodeFromWire(w.ty, typeFromWire),
    value: nodeFromWire(w.value, _expr.exprFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<AugAssignStmt,'type'>} */
function augAssignStmtFromWire(w) {
  return {
    // Note the singular `target` — `Assign` uses plural `targets`.
    target: nodeFromWire(w.target, _dto.targetFromWire),
    value: nodeFromWire(w.value, _expr.exprFromWire),
    op: w.op,
  }
}

/** @param {Record<string,any>} w @returns {Omit<AssertStmt,'type'>} */
function assertStmtFromWire(w) {
  return {
    test: nodeFromWire(w.test, _expr.exprFromWire),
    ifCond: nodeFromWire(w.if_cond, _expr.exprFromWire),
    msg: nodeFromWire(w.msg, _expr.exprFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<IfStmt,'type'>} */
function ifStmtFromWire(w) {
  return {
    body: (w.body || []).map((/** @type {any} */ b) => nodeFromWire(b, stmtFromWire)),
    cond: nodeFromWire(w.cond, _expr.exprFromWire),
    orelse: (w.orelse || []).map((/** @type {any} */ o) => nodeFromWire(o, stmtFromWire)),
  }
}

/** @param {Record<string,any>} w @returns {Omit<ImportStmt,'type'>} */
function importStmtFromWire(w) {
  // `ImportStmt` is flat: `path` is a `MaybeNode<String>`, and `rawpath`, `name`,
  // `asname` and `pkg_name` are plain strings sitting next to it. There is
  // no `node` wrapper object and no `as_name` / `pkg_root` field.
  return {
    path: nodeFromWire(w.path, (x) => /** @type {string} */ x),
    rawpath: w.rawpath,
    name: w.name,
    asname: nodeFromWire(w.asname, (x) => /** @type {string} */ x),
    pkgName: w.pkg_name,
  }
}

/** @param {Record<string,any>} w @returns {Omit<SchemaStmt,'type'>} */
function schemaStmtFromWire(w) {
  return {
    doc: nodeFromWire(w.doc, (x) => /** @type {string} */ x),
    name: nodeFromWire(w.name, (x) => /** @type {string} */ x),
    parentName: nodeFromWire(w.parent_name, identifierFromWire),
    forHostName: nodeFromWire(w.for_host_name, identifierFromWire),
    isMixin: w.is_mixin === true,
    isProtocol: w.is_protocol === true,
    args: nodeFromWire(w.args, _dto.argumentsFromWire),
    mixins: (w.mixins || []).map((/** @type {any} */ m) => nodeFromWire(m, identifierFromWire)),
    body: (w.body || []).map((/** @type {any} */ b) => nodeFromWire(b, stmtFromWire)),
    // `decorators` is `Vec<NodeRef<CallExpr>>`; a decorator is a call.
    decorators: (w.decorators || []).map((/** @type {any} */ d) => nodeFromWire(d, _dto.decoratorFromWire)),
    // `checks` is `Vec<NodeRef<CheckExpr>>` — a plain struct, not a tagged
    // `Expr`, so the element must be decoded as a `CheckExpr`.
    checks: (w.checks || []).map((/** @type {any} */ c) => nodeFromWire(c, _dto.checkExprFromWire)),
    indexSignature: nodeFromWire(w.index_signature, _dto.schemaIndexSignatureFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<SchemaAttr,'type'>} */
function schemaAttrFromWire(w) {
  return {
    doc: w.doc || '',
    name: nodeFromWire(w.name, (x) => /** @type {string} */ x),
    op: w.op,
    value: nodeFromWire(w.value, _expr.exprFromWire),
    isOptional: w.is_optional === true,
    decorators: (w.decorators || []).map((/** @type {any} */ d) => nodeFromWire(d, _dto.decoratorFromWire)),
    ty: nodeFromWire(w.ty, typeFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<RuleStmt,'type'>} */
function ruleStmtFromWire(w) {
  return {
    doc: nodeFromWire(w.doc, (x) => /** @type {string} */ x),
    name: nodeFromWire(w.name, (x) => /** @type {string} */ x),
    parentRules: (w.parent_rules || []).map((/** @type {any} */ p) => nodeFromWire(p, identifierFromWire)),
    decorators: (w.decorators || []).map((/** @type {any} */ d) => nodeFromWire(d, _dto.decoratorFromWire)),
    checks: (w.checks || []).map((/** @type {any} */ c) => nodeFromWire(c, _dto.checkExprFromWire)),
    args: nodeFromWire(w.args, _dto.argumentsFromWire),
    forHostName: nodeFromWire(w.for_host_name, identifierFromWire),
  }
}

/**
 * Variant tag -> loader. `stmtFromWire` supplies the tag itself with
 * `Object.assign({type: variant}, loader(w))`, so every loader above returns
 * the *un-tagged* body of its struct — which is why each one is annotated
 * `Omit<X,'type'>` rather than `X`.
 *
 * The annotation belongs on the declaration rather than at the `REGISTRY[variant]`
 * lookup: `prettier --check` is a CI gate and it strips the parentheses an
 * inline cast needs, which silently demotes the cast to the whole expression
 * and brings `TS7053` straight back.
 * @type {Record<string, (w: Record<string,any>) => any>}
 */
const REGISTRY = {
  TypeAlias: typeAliasStmtFromWire,
  Expr: exprStmtFromWire,
  Unification: unificationStmtFromWire,
  Assign: assignStmtFromWire,
  AugAssign: augAssignStmtFromWire,
  Assert: assertStmtFromWire,
  If: ifStmtFromWire,
  Import: importStmtFromWire,
  SchemaAttr: schemaAttrFromWire,
  Schema: schemaStmtFromWire,
  Rule: ruleStmtFromWire,
}

/**
 * Polymorphic Stmt loader. Returns `undefined` for a payload with no `type`.
 * @param {Record<string,any>|undefined|null} w
 * @returns {Stmt|undefined}
 */
export function stmtFromWire(w) {
  if (!w) return undefined
  const variant = w.type
  if (!variant) return undefined
  const loader = REGISTRY[variant]
  if (loader) return Object.assign({ type: variant }, loader(w))
  return { type: variant, unknown: true }
}

/**
 * @template T
 * @typedef {import('./_base.mjs').Node<T>} Node
 */
/** @template T @typedef {import('./_base.mjs').MaybeNode<T>} MaybeNode */
/** @typedef {import('./_types.mjs').Identifier} Identifier */
/** @typedef {import('./_types.mjs').Type} Type */
/** @typedef {import('./_expr.mjs').Expr} Expr */
/** @typedef {import('./_dto.mjs').Arguments} Arguments */
/** @typedef {import('./_dto.mjs').CheckExpr} CheckExpr */
/** @typedef {import('./_dto.mjs').SchemaConfig} SchemaConfig */
/** @typedef {import('./_dto.mjs').SchemaIndexSignature} SchemaIndexSignature */
/** @typedef {import('./_dto.mjs').Target} Target */
/**
 * `ast::CallExpr` is what `SchemaStmt.decorators` / `SchemaAttr.decorators` /
 * `RuleStmt.decorators` actually hold — a decorator *is* a call. `_dto.mjs`
 * names that shape `Decorator` and exports the `decoratorFromWire` loader, so
 * the alias is spelled to match the DTO name.
 * @typedef {import('./_dto.mjs').Decorator} Decorator
 */

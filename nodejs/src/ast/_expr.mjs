// _expr.mjs — Expression hierarchy. Mirrors `ast::Expr` in `crates/ast/src/ast.rs`.
//
// `Expr` is `#[serde(tag = "type")]`, and because every variant is a
// *newtype over a struct*, serde flattens the struct's fields into the same
// object. An identifier is `{"type": "Identifier", "names": [...]}` — there
// is no `identifier` wrapper key to descend through. Getting that wrong is
// the single most common bug in a hand-written AST loader, and it is silent:
// the wrapper key is always absent, so every identifier comes back empty.

import { nodeFromWire } from './_base.mjs'
import * as _dto from './_dto.mjs'
import { identifierFromWire, typeFromWire } from './_types.mjs'

/**
 * `Expr::Target(Target)` — flattened, so the tag sits beside `Target`'s own
 * fields. There is no `target` wrapper key to descend through. Java models the
 * same split as `TargetExpr extends Target`, which is what `extends` below
 * reproduces.
 * @typedef {Object} TargetExpr
 * @property {'Target'} type
 * @property {MaybeNode<string>} name
 * @property {Array<MemberOrIndex>} paths  `Vec<MemberOrIndex>` in Rust
 * @property {string} pkgpath
 */

/** `Expr::Identifier(Identifier)` — likewise flattened. @typedef {Object} IdentifierExpr @property {'Identifier'} type @property {Array<MaybeNode<string>>} names @property {string} pkgpath @property {string|undefined} ctx */

/** @typedef {Object} UnaryExpr @property {'Unary'} type @property {string|undefined} op @property {MaybeNode<Expr>} operand */

/** @typedef {Object} BinaryExpr @property {'Binary'} type @property {MaybeNode<Expr>} left @property {string|undefined} op @property {MaybeNode<Expr>} right */

/**
 * The `If` *expression*. `Stmt::If` shares the tag with a different shape —
 * `IfStmt` in `_stmt.mjs` — because the tag alone does not say which it is.
 * @typedef {Object} IfExpr
 * @property {'If'} type
 * @property {MaybeNode<Expr>} body
 * @property {MaybeNode<Expr>} cond
 * @property {MaybeNode<Expr>} orelse
 */

/**
 * @typedef {Object} SelectorExpr
 * @property {'Selector'} type
 * @property {MaybeNode<Expr>} value
 * @property {MaybeNode<Identifier>} attr  a `NodeRef<Identifier>`, not a `NodeRef<Expr>`
 * @property {string|undefined} ctx
 * @property {boolean} hasQuestion
 */

/**
 * `Expr::Call(CallExpr)`. `type` is optional rather than required because the
 * same struct is what a decorator is: `SchemaStmt.decorators` is
 * `Vec<NodeRef<CallExpr>>` and those elements arrive untagged. Java draws the
 * distinction with a second, field-identical `Decorator` class.
 * @typedef {Object} CallExpr
 * @property {'Call'|undefined} type
 * @property {MaybeNode<Expr>} func
 * @property {Array<MaybeNode<Expr>>} args
 * @property {Array<MaybeNode<Keyword>>} keywords
 */

/** @typedef {Object} ParenExpr @property {'Paren'} type @property {MaybeNode<Expr>} expr */

/**
 * @typedef {Object} QuantExpr
 * @property {'Quant'} type
 * @property {MaybeNode<Expr>} target
 * @property {Array<MaybeNode<Identifier>>} variables
 * @property {string|undefined} op
 * @property {MaybeNode<Expr>} test
 * @property {MaybeNode<Expr>} ifCond
 * @property {string|undefined} ctx
 */

/** @typedef {Object} ListExpr @property {'List'} type @property {Array<MaybeNode<Expr>>} elts @property {string|undefined} ctx */

/** @typedef {Object} ListIfItemExpr @property {'ListIfItem'} type @property {MaybeNode<Expr>} ifCond @property {Array<MaybeNode<Expr>>} exprs @property {MaybeNode<Expr>} orelse */

/**
 * @typedef {Object} ListComp
 * @property {'ListComp'} type
 * @property {MaybeNode<Expr>} elt
 * @property {Array<MaybeNode<CompClause>>} generators  `CompClause` is a plain
 *   struct, so its elements carry no `type` tag of their own.
 */

/** @typedef {Object} StarredExpr @property {'Starred'} type @property {MaybeNode<Expr>} value @property {string|undefined} ctx */

/**
 * A `DictComp` has exactly one `entry: ConfigEntry` — not separate
 * key/value/entry_key fields.
 * @typedef {Object} DictComp
 * @property {'DictComp'} type
 * @property {ConfigEntry|undefined} entry  the Rust field is a required
 *   `ConfigEntry`, but the loader guards on a missing payload and yields
 *   `undefined`, so the type follows the code
 * @property {Array<MaybeNode<CompClause>>} generators
 */

/** @typedef {Object} ConfigIfEntryExpr @property {'ConfigIfEntry'} type @property {MaybeNode<Expr>} ifCond @property {Array<MaybeNode<ConfigEntry>>} items @property {MaybeNode<Expr>} orelse */

/**
 * `Expr::CompClause(CompClause)`. `ListComp.generators` and `DictComp.generators`
 * are `Vec<NodeRef<CompClause>>` of *untagged* clauses, so `type` is optional.
 * @typedef {CompClause & {type: 'CompClause'|undefined}} CompClauseExpr
 */

/**
 * `Expr::Keyword(Keyword)` — flattened, so there is no `keyword` wrapper key,
 * and the same struct is what a call's `keywords` entries hold.
 * @typedef {Keyword & {type: 'Keyword'|undefined}} KeywordExpr
 */

/** @typedef {Arguments & {type: 'Arguments'|undefined}} ArgumentsExpr */

/**
 * `Expr::Schema(SchemaExpr)`. The untagged twin of this struct is
 * `SchemaConfig`, which is what `UnificationStmt.value` carries — see
 * `schemaConfigFromWire`.
 * @typedef {Object} SchemaExpr
 * @property {'Schema'|undefined|'Schema'|undefined} type
 * @property {MaybeNode<Identifier>} name
 * @property {Array<MaybeNode<Expr>>} args
 * @property {Array<MaybeNode<Keyword>>} kwargs
 * @property {MaybeNode<Expr>} config
 */

/** @typedef {Object} ConfigExpr @property {'Config'} type @property {Array<MaybeNode<ConfigEntry>>} items */

/**
 * @typedef {Object} LambdaExpr
 * @property {'Lambda'} type
 * @property {MaybeNode<Arguments>} args
 * @property {Array<MaybeNode<Stmt>>} body  a lambda body is
 *   `Vec<NodeRef<Stmt>>`, not a list of expressions
 * @property {MaybeNode<Type>} returnTy
 */

/**
 * @typedef {Object} Subscript
 * @property {'Subscript'} type
 * @property {MaybeNode<Expr>} value
 * @property {MaybeNode<Expr>|undefined} index  set for `a[0]`
 * @property {MaybeNode<Expr>|undefined} lower  a slice sets these three instead
 * @property {MaybeNode<Expr>|undefined} upper
 * @property {MaybeNode<Expr>|undefined} step
 * @property {string|undefined} ctx
 * @property {boolean} hasQuestion
 */

/**
 * `NumberLitValue` is its own `tag + content` enum, so `value` is an object —
 * `{"type": "Int", "value": 0}` — and not a bare number.
 * @typedef {Object} NumberLit
 * @property {'NumberLit'} type
 * @property {string|undefined} binarySuffix
 * @property {unknown} value
 */

/** @typedef {Object} StringLit @property {'StringLit'} type @property {boolean} isLongString @property {string} rawValue @property {string} value */

/** @typedef {Object} NameConstantLit @property {'NameConstantLit'} type @property {boolean|undefined} value */

/** @typedef {Object} JoinedString @property {'JoinedString'} type @property {boolean} isLongString @property {Array<MaybeNode<Expr>>} values @property {string} rawValue */

/**
 * @typedef {Object} FormattedValue
 * @property {'FormattedValue'} type
 * @property {boolean} isLongString
 * @property {MaybeNode<Expr>} value
 * @property {string|undefined} formatSpec  a plain `Option<String>`, not a `NodeRef<Expr>`
 */

/**
 * `Expr::Missing` has no fields. The parser only emits it during error
 * recovery, so it never appears in a clean parse.
 * @typedef {Object} MissingExpr
 * @property {'Missing'} type
 */

/**
 * A tag this build does not know about. Kept rather than dropped, so a caller
 * can still see what the parser emitted. Java has no equivalent — Jackson
 * raises on an unregistered subtype — so this is a nodejs-only variant.
 * @typedef {Object} UnknownExpr
 * @property {string} type
 * @property {true} unknown
 */

/** @typedef {Object} Compare @property {'Compare'} type @property {MaybeNode<Expr>} left @property {Array<string>} ops @property {Array<MaybeNode<Expr>>} comparators */

/**
 * @typedef {TargetExpr|IdentifierExpr|UnaryExpr|BinaryExpr|IfExpr|SelectorExpr|CallExpr|ParenExpr|QuantExpr|ListExpr|ListIfItemExpr|ListComp|StarredExpr|DictComp|ConfigIfEntryExpr|CompClauseExpr|SchemaExpr|ConfigExpr|CheckExpr|LambdaExpr|Subscript|KeywordExpr|ArgumentsExpr|Compare|NumberLit|StringLit|NameConstantLit|JoinedString|FormattedValue|MissingExpr|UnknownExpr} Expr
 */
/** @param {Record<string,any>} w @returns {Omit<TargetExpr,'type'>|undefined} */
function targetFromWire(w) {
  // `Expr::Target(Target)` carries the same fields as the bare `ast::Target`
  // struct, so delegate and let `_dto` read them straight off the wire object.
  return _dto.targetFromWire(w)
}

/** @param {Record<string,any>} w @returns {Omit<UnaryExpr,'type'>} */
function unaryFromWire(w) {
  return {
    op: w.op,
    operand: nodeFromWire(w.operand, exprFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<BinaryExpr,'type'>} */
function binaryFromWire(w) {
  return {
    left: nodeFromWire(w.left, exprFromWire),
    op: w.op,
    right: nodeFromWire(w.right, exprFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<IfExpr,'type'>} */
function ifFromWire(w) {
  return {
    body: nodeFromWire(w.body, exprFromWire),
    cond: nodeFromWire(w.cond, exprFromWire),
    orelse: nodeFromWire(w.orelse, exprFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<SelectorExpr,'type'>} */
function selectorFromWire(w) {
  return {
    value: nodeFromWire(w.value, exprFromWire),
    // `SelectorExpr.attr` is a `NodeRef<Identifier>`.
    attr: nodeFromWire(w.attr, identifierFromWire),
    ctx: w.ctx,
    hasQuestion: w.has_question === true,
  }
}

/** @param {Record<string,any>} w @returns {Omit<CallExpr,'type'>|undefined} */
function callFromWire(w) {
  return _dto.decoratorFromWire(w)
}

/** @param {Record<string,any>} w @returns {Omit<ParenExpr,'type'>} */
function parenFromWire(w) {
  return { expr: nodeFromWire(w.expr, exprFromWire) }
}

/** @param {Record<string,any>} w @returns {Omit<QuantExpr,'type'>} */
function quantFromWire(w) {
  return {
    target: nodeFromWire(w.target, exprFromWire),
    // `QuantExpr.variables` is `Vec<NodeRef<Identifier>>`.
    variables: (w.variables || []).map((/** @type {any} */ v) => nodeFromWire(v, identifierFromWire)),
    op: w.op,
    test: nodeFromWire(w.test, exprFromWire),
    ifCond: nodeFromWire(w.if_cond, exprFromWire),
    ctx: w.ctx,
  }
}

/** @param {Record<string,any>} w @returns {Omit<ListExpr,'type'>} */
function listFromWire(w) {
  return {
    elts: (w.elts || []).map((/** @type {any} */ e) => nodeFromWire(e, exprFromWire)),
    ctx: w.ctx,
  }
}

/** @param {Record<string,any>} w @returns {Omit<ListIfItemExpr,'type'>} */
function listIfItemFromWire(w) {
  return {
    ifCond: nodeFromWire(w.if_cond, exprFromWire),
    exprs: (w.exprs || []).map((/** @type {any} */ e) => nodeFromWire(e, exprFromWire)),
    orelse: nodeFromWire(w.orelse, exprFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<ListComp,'type'>} */
function listCompFromWire(w) {
  return {
    elt: nodeFromWire(w.elt, exprFromWire),
    // `generators` is `Vec<NodeRef<CompClause>>`, and `CompClause` is a plain
    // struct — its elements carry no `type` tag.
    generators: (w.generators || []).map((/** @type {any} */ g) => nodeFromWire(g, _dto.compClauseFromWire)),
  }
}

/** @param {Record<string,any>} w @returns {Omit<StarredExpr,'type'>} */
function starredFromWire(w) {
  return {
    value: nodeFromWire(w.value, exprFromWire),
    ctx: w.ctx,
  }
}

/** @param {Record<string,any>} w @returns {Omit<DictComp,'type'>} */
function dictCompFromWire(w) {
  return {
    // A `DictComp` has exactly one `entry: ConfigEntry` — not separate
    // key/value/entry_key fields.
    entry: _dto.configEntryFromWire(w.entry),
    generators: (w.generators || []).map((/** @type {any} */ g) => nodeFromWire(g, _dto.compClauseFromWire)),
  }
}

/** @param {Record<string,any>} w @returns {Omit<ConfigIfEntryExpr,'type'>} */
function configIfEntryFromWire(w) {
  return {
    ifCond: nodeFromWire(w.if_cond, exprFromWire),
    items: (w.items || []).map((/** @type {any} */ i) => nodeFromWire(i, _dto.configEntryFromWire)),
    orelse: nodeFromWire(w.orelse, exprFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<SchemaExpr,'type'>|undefined} */
function schemaFromWire(w) {
  return schemaConfigFromWire(w)
}

/**
 * `ast::SchemaExpr` — the payload of both the `Schema` expression variant and
 * `UnificationStmt.value`. It is a plain struct, so when it appears *outside*
 * the `Expr` enum (as the right-hand side of `s: Person { ... }`) it arrives
 * with no `type` tag and cannot go through `exprFromWire`.
 * @param {Record<string,any>|undefined|null} w
 * @returns {SchemaConfig|undefined}
 */
export function schemaConfigFromWire(w) {
  if (!w) return undefined
  return {
    // `SchemaExpr.name` is a `NodeRef<Identifier>`.
    name: nodeFromWire(w.name, identifierFromWire),
    args: (w.args || []).map((/** @type {any} */ a) => nodeFromWire(a, exprFromWire)),
    kwargs: (w.kwargs || []).map((/** @type {any} */ k) => nodeFromWire(k, _dto.keywordFromWire)),
    config: nodeFromWire(w.config, exprFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<ConfigExpr,'type'>} */
function configFromWire(w) {
  return {
    items: (w.items || []).map((/** @type {any} */ i) => nodeFromWire(i, _dto.configEntryFromWire)),
  }
}

/** @param {Record<string,any>} w @returns {Omit<CheckExpr,'type'>|undefined} */
function checkExprFromWire(w) {
  // `Expr::Check(CheckExpr)` — flattened, no `check` wrapper key.
  return _dto.checkExprFromWire(w)
}

/** @param {Record<string,any>} w @returns {Omit<KeywordExpr,'type'>|undefined} */
function keywordFromWire(w) {
  // `Expr::Keyword(Keyword)` — flattened, no `keyword` wrapper key.
  return _dto.keywordFromWire(w)
}

/** @param {Record<string,any>} w @returns {Omit<ArgumentsExpr,'type'>|undefined} */
function argumentsFromWire(w) {
  // `Expr::Arguments(Arguments)` — flattened, no `arguments` wrapper key.
  return _dto.argumentsFromWire(w)
}

/** @param {Record<string,any>} w @returns {Omit<LambdaExpr,'type'>} */
function lambdaFromWire(w) {
  return {
    args: nodeFromWire(w.args, _dto.argumentsFromWire),
    // A lambda body is `Vec<NodeRef<Stmt>>`, not a list of expressions.
    body: (w.body || []).map((/** @type {any} */ b) => nodeFromWire(b, stmtFromWire)),
    returnTy: nodeFromWire(w.return_ty, typeFromWire),
  }
}

/** @param {Record<string,any>} w @returns {Omit<Subscript,'type'>} */
function subscriptFromWire(w) {
  return {
    value: nodeFromWire(w.value, exprFromWire),
    // A slice is `lower`/`upper`/`step`; `index` is only set for `a[0]`.
    index: nodeFromWire(w.index, exprFromWire),
    lower: nodeFromWire(w.lower, exprFromWire),
    upper: nodeFromWire(w.upper, exprFromWire),
    step: nodeFromWire(w.step, exprFromWire),
    ctx: w.ctx,
    hasQuestion: w.has_question === true,
  }
}

/** @param {Record<string,any>} w @returns {Omit<Compare,'type'>} */
function compareFromWire(w) {
  return {
    left: nodeFromWire(w.left, exprFromWire),
    ops: w.ops || [],
    comparators: (w.comparators || []).map((/** @type {any} */ c) => nodeFromWire(c, exprFromWire)),
  }
}

/** @param {Record<string,any>} w @returns {Omit<NumberLit,'type'>} */
function numberLitFromWire(w) {
  return {
    binarySuffix: w.binary_suffix,
    // `NumberLitValue` is its own `tag + content` enum, so the value is an
    // object — `{"type": "Int", "value": 0}` — and not a bare number.
    value: w.value,
  }
}

/** @param {Record<string,any>} w @returns {Omit<StringLit,'type'>} */
function stringLitFromWire(w) {
  return {
    isLongString: w.is_long_string === true,
    rawValue: w.raw_value === undefined ? '""' : w.raw_value,
    value: w.value === undefined ? '' : w.value,
  }
}

/** @param {Record<string,any>} w @returns {Omit<NameConstantLit,'type'>} */
function nameConstantLitFromWire(w) {
  return { value: w.value }
}

/** @param {Record<string,any>} w @returns {Omit<JoinedString,'type'>} */
function joinedStringFromWire(w) {
  return {
    isLongString: w.is_long_string === true,
    values: (w.values || []).map((/** @type {any} */ v) => nodeFromWire(v, exprFromWire)),
    rawValue: w.raw_value === undefined ? '' : w.raw_value,
  }
}

/** @param {Record<string,any>} w @returns {Omit<FormattedValue,'type'>} */
function formattedValueFromWire(w) {
  return {
    isLongString: w.is_long_string === true,
    value: nodeFromWire(w.value, exprFromWire),
    // `format_spec` is a plain `Option<String>`, not a `NodeRef<Expr>`.
    formatSpec: w.format_spec,
  }
}

/** @param {Record<string,any>} _w @returns {Omit<MissingExpr,'type'>} */
function missingFromWire(_w) {
  // `Expr::Missing` has no fields. The parser only emits it during error
  // recovery, so it never appears in a clean parse.
  return {}
}

/**
 * Variant tag -> loader. `exprFromWire` supplies the tag itself with
 * `Object.assign({type: variant}, loader(w))`, so every loader above returns
 * the *un-tagged* body of its struct — which is why each one is annotated
 * `Omit<X,'type'>` rather than `X`.
 * @type {Record<string, (w: Record<string,any>) => any>}
 */
const REGISTRY = {
  Target: targetFromWire,
  Identifier: identifierFromWire,
  Unary: unaryFromWire,
  Binary: binaryFromWire,
  If: ifFromWire,
  Selector: selectorFromWire,
  Call: callFromWire,
  Paren: parenFromWire,
  Quant: quantFromWire,
  List: listFromWire,
  ListIfItem: listIfItemFromWire,
  ListComp: listCompFromWire,
  Starred: starredFromWire,
  DictComp: dictCompFromWire,
  ConfigIfEntry: configIfEntryFromWire,
  CompClause: (/** @type {Record<string,any>} */ w) => _dto.compClauseFromWire(w),
  Schema: schemaFromWire,
  Config: configFromWire,
  Check: checkExprFromWire,
  Lambda: lambdaFromWire,
  Subscript: subscriptFromWire,
  Keyword: keywordFromWire,
  Arguments: argumentsFromWire,
  Compare: compareFromWire,
  NumberLit: numberLitFromWire,
  StringLit: stringLitFromWire,
  NameConstantLit: nameConstantLitFromWire,
  JoinedString: joinedStringFromWire,
  FormattedValue: formattedValueFromWire,
  Missing: missingFromWire,
}

/**
 * Polymorphic Expr loader. Returns `undefined` for a payload with no `type`.
 * @param {Record<string,any>|undefined|null} w
 * @returns {Expr|undefined}
 */
export function exprFromWire(w) {
  if (!w) return undefined
  const variant = w.type
  if (!variant) return undefined
  const loader = REGISTRY[variant]
  if (loader) return Object.assign({ type: variant }, loader(w))
  return { type: variant, unknown: true }
}

// Imported last on purpose: `_expr` and `_stmt` reference each other, and
// ESM hoists the bindings so the cycle resolves as long as neither module
// calls into the other at load time. Every reference above is inside a
// function body, which runs after both modules are initialized.
import { stmtFromWire } from './_stmt.mjs'

/**
 * @template T
 * @typedef {import('./_base.mjs').Node<T>} Node
 */
/** @template T @typedef {import('./_base.mjs').MaybeNode<T>} MaybeNode */
/** @typedef {import('./_types.mjs').Identifier} Identifier */
/** @typedef {import('./_types.mjs').Type} Type */
/** @typedef {import('./_dto.mjs').Keyword} Keyword */
/** @typedef {import('./_dto.mjs').Arguments} Arguments */
/** @typedef {import('./_dto.mjs').CompClause} CompClause */
/** @typedef {import('./_dto.mjs').ConfigEntry} ConfigEntry */
/** @typedef {import('./_dto.mjs').MemberOrIndex} MemberOrIndex */
/** @typedef {import('./_dto.mjs').SchemaConfig} SchemaConfig */
/** @typedef {import('./_dto.mjs').CheckExpr} CheckExpr */
/** @typedef {import('./_stmt.mjs').Stmt} Stmt */

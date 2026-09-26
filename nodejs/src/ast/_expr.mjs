// _expr.mjs — Expression hierarchy. Mirrors `ast::Expr` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]` so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `exprFromWire` dispatches on that tag.

import { nodeFromWire } from './_base.mjs'
import * as _dto from './_dto.mjs'
import * as _types from './_types.mjs'

/** @param {Record<string,any>} w */
function targetFromWire(w) {
  // `Expr::Target` wraps the same flat payload as `ast::Target` — delegate.
  return _dto.targetFromWire(Object.assign({}, w, { type: undefined }))
}

/** @param {Record<string,any>} w */
function identifierFromWire(w) {
  return {
    names: (w.names || []).map((n) => nodeFromWire(n, (x) => /** @type {string} */ x)),
    pkgpath: w.pkgpath || '',
    ctx: w.ctx,
  }
}

/** @param {Record<string,any>} w */
function unaryFromWire(w) {
  return {
    op: w.op,
    operand: nodeFromWire(w.operand, exprFromWire),
  }
}

/** @param {Record<string,any>} w */
function binaryFromWire(w) {
  return {
    left: nodeFromWire(w.left, exprFromWire),
    op: w.op,
    right: nodeFromWire(w.right, exprFromWire),
  }
}

/** @param {Record<string,any>} w */
function ifFromWire(w) {
  return {
    body: nodeFromWire(w.body, exprFromWire),
    cond: nodeFromWire(w.cond, exprFromWire),
    orelse: nodeFromWire(w.orelse, exprFromWire),
  }
}

/** @param {Record<string,any>} w */
function selectorFromWire(w) {
  return {
    value: nodeFromWire(w.value, exprFromWire),
    attr: nodeFromWire(w.attr, exprFromWire),
    ctx: w.ctx,
    hasQuestion: w.has_question === true,
  }
}

/** @param {Record<string,any>} w */
function callFromWire(w) {
  return {
    func: nodeFromWire(w.func, exprFromWire),
    args: (w.args || []).map((a) => nodeFromWire(a, exprFromWire)),
    keywords: (w.keywords || []).map((k) => nodeFromWire(k, _dto.keywordFromWire)),
  }
}

/** @param {Record<string,any>} w */
function parenFromWire(w) {
  return { expr: nodeFromWire(w.expr, exprFromWire) }
}

/** @param {Record<string,any>} w */
function quantFromWire(w) {
  return {
    target: nodeFromWire(w.target, exprFromWire),
    variables: (w.variables || []).map((v) => nodeFromWire(v, exprFromWire)),
    op: w.op,
    test: nodeFromWire(w.test, exprFromWire),
    ifCond: nodeFromWire(w.if_cond, exprFromWire),
    ctx: w.ctx,
  }
}

/** @param {Record<string,any>} w */
function listFromWire(w) {
  return {
    elts: (w.elts || []).map((e) => nodeFromWire(e, exprFromWire)),
    ctx: w.ctx,
  }
}

/** @param {Record<string,any>} w */
function listIfItemFromWire(w) {
  return {
    ifCond: nodeFromWire(w.if_cond, exprFromWire),
    exprs: (w.exprs || []).map((e) => nodeFromWire(e, exprFromWire)),
    orelse: nodeFromWire(w.orelse, exprFromWire),
  }
}

/** @param {Record<string,any>} w */
function listCompFromWire(w) {
  return {
    elt: nodeFromWire(w.elt, exprFromWire),
    generators: (w.generators || []).map((g) => nodeFromWire(g, exprFromWire)),
  }
}

/** @param {Record<string,any>} w */
function starredFromWire(w) {
  return {
    value: nodeFromWire(w.value, exprFromWire),
    ctx: w.ctx,
  }
}

/** @param {Record<string,any>} w */
function dictCompFromWire(w) {
  return {
    entryKey: nodeFromWire(w.entry_key, exprFromWire),
    key: nodeFromWire(w.key, exprFromWire),
    value: nodeFromWire(w.value, exprFromWire),
    generators: (w.generators || []).map((g) => nodeFromWire(g, exprFromWire)),
  }
}

/** @param {Record<string,any>} w */
function configIfEntryFromWire(w) {
  return {
    ifCond: nodeFromWire(w.if_cond, exprFromWire),
    items: (w.items || []).map((i) => nodeFromWire(i, _dto.configEntryFromWire)),
    orelse: nodeFromWire(w.orelse, exprFromWire),
  }
}

/** @param {Record<string,any>} w */
function compClauseFromWire(w) {
  return {
    targets: (w.targets || []).map((t) => nodeFromWire(t, exprFromWire)),
    iter: nodeFromWire(w.iter, exprFromWire),
    ifs: (w.ifs || []).map((i) => nodeFromWire(i, exprFromWire)),
  }
}

/** @param {Record<string,any>} w */
function schemaFromWire(w) {
  return {
    name: nodeFromWire(w.name, exprFromWire),
    args: (w.args || []).map((a) => nodeFromWire(a, exprFromWire)),
    kwargs: (w.kwargs || []).map((k) => nodeFromWire(k, _dto.keywordFromWire)),
    config: nodeFromWire(w.config, exprFromWire),
  }
}

/** @param {Record<string,any>} w */
function configFromWire(w) {
  return {
    items: (w.items || []).map((i) => nodeFromWire(i, _dto.configEntryFromWire)),
  }
}

/** @param {Record<string,any>} w */
function lambdaFromWire(w) {
  return {
    args: nodeFromWire(w.args, _dto.argumentsFromWire),
    body: (w.body || []).map((b) => nodeFromWire(b, exprFromWire)),
    returnTy: nodeFromWire(w.return_ty, _types.typeFromWire),
  }
}

/** @param {Record<string,any>} w */
function subscriptFromWire(w) {
  return {
    value: nodeFromWire(w.value, exprFromWire),
    index: nodeFromWire(w.index, exprFromWire),
    ctx: w.ctx,
  }
}

/** @param {Record<string,any>} w */
function compareFromWire(w) {
  return {
    left: nodeFromWire(w.left, exprFromWire),
    ops: w.ops || [],
    comparators: (w.comparators || []).map((c) => nodeFromWire(c, exprFromWire)),
  }
}

/** @param {Record<string,any>} w */
function numberLitFromWire(w) {
  return {
    binarySuffix: w.binary_suffix,
    value: w.value,
  }
}

/** @param {Record<string,any>} w */
function stringLitFromWire(w) {
  return {
    isLongString: w.is_long_string === true,
    rawValue: w.raw_value || '""',
    value: w.value || '',
  }
}

/** @param {Record<string,any>} w */
function nameConstantLitFromWire(w) {
  return { value: w.value }
}

/** @param {Record<string,any>} w */
function joinedStringFromWire(w) {
  return {
    values: (w.values || []).map((v) => nodeFromWire(v, exprFromWire)),
  }
}

/** @param {Record<string,any>} w */
function formattedValueFromWire(w) {
  return {
    value: nodeFromWire(w.value, exprFromWire),
    conversion: w.conversion,
    formatSpec: nodeFromWire(w.format_spec, exprFromWire),
  }
}

/** @param {Record<string,any>} w */
function missingFromWire(_w) {
  return {}
}

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
  CompClause: compClauseFromWire,
  Schema: schemaFromWire,
  Config: configFromWire,
  Lambda: lambdaFromWire,
  Subscript: subscriptFromWire,
  Compare: compareFromWire,
  NumberLit: numberLitFromWire,
  StringLit: stringLitFromWire,
  NameConstantLit: nameConstantLitFromWire,
  JoinedString: joinedStringFromWire,
  FormattedValue: formattedValueFromWire,
  Missing: missingFromWire,
}

/**
 * Polymorphic Expr loader. Returns `undefined` for missing/empty payloads.
 * @param {Record<string,any>|undefined|null} w
 */
export function exprFromWire(w) {
  if (!w) return undefined
  if (!w.type) return undefined
  const variant = w.type
  const loader = REGISTRY[variant]
  if (loader) return Object.assign({ type: variant }, loader(w))
  return { type: variant }
}

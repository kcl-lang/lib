// _expr.ts — Expression hierarchy. Mirrors `ast::Expr` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]` so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `exprFromWire` dispatches on that tag.

import { nodeFromWire } from "./_base";
import * as _dto from "./_dto";
import * as _types from "./_types";

function targetFromWire(w: Record<string, unknown>): unknown {
  return _dto.targetFromWire(Object.assign({}, w, { type: undefined }));
}

function identifierFromWire(w: Record<string, unknown>): unknown {
  return {
    names: ((w.names as unknown[]) || []).map((n) => nodeFromWire(n as never, (x: string) => x)),
    pkgpath: w.pkgpath || "",
    ctx: w.ctx,
  };
}

function unaryFromWire(w: Record<string, unknown>): unknown {
  return {
    op: w.op,
    operand: nodeFromWire(w.operand as never, exprFromWire as never),
  };
}

function binaryFromWire(w: Record<string, unknown>): unknown {
  return {
    left: nodeFromWire(w.left as never, exprFromWire as never),
    op: w.op,
    right: nodeFromWire(w.right as never, exprFromWire as never),
  };
}

function ifFromWire(w: Record<string, unknown>): unknown {
  return {
    body: nodeFromWire(w.body as never, exprFromWire as never),
    cond: nodeFromWire(w.cond as never, exprFromWire as never),
    orelse: nodeFromWire(w.orelse as never, exprFromWire as never),
  };
}

function selectorFromWire(w: Record<string, unknown>): unknown {
  return {
    value: nodeFromWire(w.value as never, exprFromWire as never),
    attr: nodeFromWire(w.attr as never, exprFromWire as never),
    ctx: w.ctx,
    hasQuestion: w.has_question === true,
  };
}

function callFromWire(w: Record<string, unknown>): unknown {
  return {
    func: nodeFromWire(w.func as never, exprFromWire as never),
    args: ((w.args as unknown[]) || []).map((a) => nodeFromWire(a as never, exprFromWire as never)),
    keywords: ((w.keywords as unknown[]) || []).map((k) => nodeFromWire(k as never, _dto.keywordFromWire as never)),
  };
}

function parenFromWire(w: Record<string, unknown>): unknown {
  return { expr: nodeFromWire(w.expr as never, exprFromWire as never) };
}

function quantFromWire(w: Record<string, unknown>): unknown {
  return {
    target: nodeFromWire(w.target as never, exprFromWire as never),
    variables: ((w.variables as unknown[]) || []).map((v) => nodeFromWire(v as never, exprFromWire as never)),
    op: w.op,
    test: nodeFromWire(w.test as never, exprFromWire as never),
    ifCond: nodeFromWire(w.if_cond as never, exprFromWire as never),
    ctx: w.ctx,
  };
}

function listFromWire(w: Record<string, unknown>): unknown {
  return {
    elts: ((w.elts as unknown[]) || []).map((e) => nodeFromWire(e as never, exprFromWire as never)),
    ctx: w.ctx,
  };
}

function listIfItemFromWire(w: Record<string, unknown>): unknown {
  return {
    ifCond: nodeFromWire(w.if_cond as never, exprFromWire as never),
    exprs: ((w.exprs as unknown[]) || []).map((e) => nodeFromWire(e as never, exprFromWire as never)),
    orelse: nodeFromWire(w.orelse as never, exprFromWire as never),
  };
}

function listCompFromWire(w: Record<string, unknown>): unknown {
  return {
    elt: nodeFromWire(w.elt as never, exprFromWire as never),
    generators: ((w.generators as unknown[]) || []).map((g) => nodeFromWire(g as never, exprFromWire as never)),
  };
}

function starredFromWire(w: Record<string, unknown>): unknown {
  return {
    value: nodeFromWire(w.value as never, exprFromWire as never),
    ctx: w.ctx,
  };
}

function dictCompFromWire(w: Record<string, unknown>): unknown {
  return {
    entryKey: nodeFromWire(w.entry_key as never, exprFromWire as never),
    key: nodeFromWire(w.key as never, exprFromWire as never),
    value: nodeFromWire(w.value as never, exprFromWire as never),
    generators: ((w.generators as unknown[]) || []).map((g) => nodeFromWire(g as never, exprFromWire as never)),
  };
}

function configIfEntryFromWire(w: Record<string, unknown>): unknown {
  return {
    ifCond: nodeFromWire(w.if_cond as never, exprFromWire as never),
    items: ((w.items as unknown[]) || []).map((i) => nodeFromWire(i as never, _dto.configEntryFromWire as never)),
    orelse: nodeFromWire(w.orelse as never, exprFromWire as never),
  };
}

function compClauseFromWire(w: Record<string, unknown>): unknown {
  return {
    targets: ((w.targets as unknown[]) || []).map((t) => nodeFromWire(t as never, exprFromWire as never)),
    iter: nodeFromWire(w.iter as never, exprFromWire as never),
    ifs: ((w.ifs as unknown[]) || []).map((i) => nodeFromWire(i as never, exprFromWire as never)),
  };
}

function schemaFromWire(w: Record<string, unknown>): unknown {
  return {
    name: nodeFromWire(w.name as never, exprFromWire as never),
    args: ((w.args as unknown[]) || []).map((a) => nodeFromWire(a as never, exprFromWire as never)),
    kwargs: ((w.kwargs as unknown[]) || []).map((k) => nodeFromWire(k as never, _dto.keywordFromWire as never)),
    config: nodeFromWire(w.config as never, exprFromWire as never),
  };
}

function configFromWire(w: Record<string, unknown>): unknown {
  return {
    items: ((w.items as unknown[]) || []).map((i) => nodeFromWire(i as never, _dto.configEntryFromWire as never)),
  };
}

function lambdaFromWire(w: Record<string, unknown>): unknown {
  return {
    args: nodeFromWire(w.args as never, _dto.argumentsFromWire as never),
    body: ((w.body as unknown[]) || []).map((b) => nodeFromWire(b as never, exprFromWire as never)),
    returnTy: nodeFromWire(w.return_ty as never, _types.typeFromWire as never),
  };
}

function subscriptFromWire(w: Record<string, unknown>): unknown {
  return {
    value: nodeFromWire(w.value as never, exprFromWire as never),
    index: nodeFromWire(w.index as never, exprFromWire as never),
    ctx: w.ctx,
  };
}

function compareFromWire(w: Record<string, unknown>): unknown {
  return {
    left: nodeFromWire(w.left as never, exprFromWire as never),
    ops: w.ops || [],
    comparators: ((w.comparators as unknown[]) || []).map((c) => nodeFromWire(c as never, exprFromWire as never)),
  };
}

function numberLitFromWire(w: Record<string, unknown>): unknown {
  return {
    binarySuffix: w.binary_suffix,
    value: w.value,
  };
}

function stringLitFromWire(w: Record<string, unknown>): unknown {
  return {
    isLongString: w.is_long_string === true,
    rawValue: w.raw_value || '""',
    value: w.value || "",
  };
}

function nameConstantLitFromWire(w: Record<string, unknown>): unknown {
  return { value: w.value };
}

function joinedStringFromWire(w: Record<string, unknown>): unknown {
  return {
    values: ((w.values as unknown[]) || []).map((v) => nodeFromWire(v as never, exprFromWire as never)),
  };
}

function formattedValueFromWire(w: Record<string, unknown>): unknown {
  return {
    value: nodeFromWire(w.value as never, exprFromWire as never),
    conversion: w.conversion,
    formatSpec: nodeFromWire(w.format_spec as never, exprFromWire as never),
  };
}

function missingFromWire(_w: Record<string, unknown>): unknown {
  return {};
}

const REGISTRY: Record<string, (w: Record<string, unknown>) => unknown> = {
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
};

export function exprFromWire(w: Record<string, unknown> | undefined | null): unknown {
  if (!w) return undefined;
  if (!w.type) return undefined;
  const variant = w.type as string;
  const loader = REGISTRY[variant];
  if (loader) return Object.assign({ type: variant }, loader(w));
  return { type: variant };
}
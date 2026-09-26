// _stmt.ts — Statement hierarchy. Mirrors `ast::Stmt` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]`, so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `stmtFromWire` dispatches on that tag.

import { nodeFromWire } from "./_base";
import * as _dto from "./_dto";
import * as _expr from "./_expr";
import * as _types from "./_types";

function exprStmtFromWire(w: Record<string, unknown>): unknown {
  return {
    exprs: ((w.exprs as unknown[]) || []).map((e) => nodeFromWire(e as never, _expr.exprFromWire as never)),
  };
}

function unificationStmtFromWire(w: Record<string, unknown>): unknown {
  return {
    target: nodeFromWire(w.target as never, ((x: unknown) => x) as never),
    value: nodeFromWire(w.value as never, _dto.schemaConfigFromWire as never),
  };
}

function assignStmtFromWire(w: Record<string, unknown>): unknown {
  return {
    targets: ((w.targets as unknown[]) || []).map((t) => nodeFromWire(t as never, _dto.targetFromWire as never)),
    ty: nodeFromWire(w.ty as never, _types.typeFromWire as never),
    value: nodeFromWire(w.value as never, _expr.exprFromWire as never),
  };
}

function schemaStmtFromWire(w: Record<string, unknown>): unknown {
  return {
    doc: nodeFromWire(w.doc as never, (x: string) => x),
    name: nodeFromWire(w.name as never, (x: string) => x),
    parentName: nodeFromWire(w.parent_name as never, ((x: unknown) => x) as never),
    forHostName: nodeFromWire(w.for_host_name as never, ((x: unknown) => x) as never),
    isMixin: w.is_mixin === true,
    isProtocol: w.is_protocol === true,
    args: nodeFromWire(w.args as never, _dto.argumentsFromWire as never),
    mixins: ((w.mixins as unknown[]) || []).map((m) => nodeFromWire(m as never, ((x: unknown) => x) as never)),
    body: ((w.body as unknown[]) || []).map((b) => nodeFromWire(b as never, stmtFromWire as never)),
    decorators: ((w.decorators as unknown[]) || []).map((deco) => nodeFromWire(deco as never, _dto.decoratorFromWire as never)),
    checks: ((w.checks as unknown[]) || []).map((c) => nodeFromWire(c as never, _expr.exprFromWire as never)),
    indexSignature: nodeFromWire(w.index_signature as never, ((x: unknown) => x) as never),
  };
}

function schemaAttrFromWire(w: Record<string, unknown>): unknown {
  return {
    doc: w.doc || "",
    name: nodeFromWire(w.name as never, (x: string) => x),
    op: w.op,
    value: nodeFromWire(w.value as never, _expr.exprFromWire as never),
    isOptional: w.is_optional === true,
    decorators: ((w.decorators as unknown[]) || []).map((deco) => nodeFromWire(deco as never, _dto.decoratorFromWire as never)),
    ty: nodeFromWire(w.ty as never, _types.typeFromWire as never),
  };
}

function ruleStmtFromWire(w: Record<string, unknown>): unknown {
  return {
    doc: nodeFromWire(w.doc as never, (x: string) => x),
    name: nodeFromWire(w.name as never, (x: string) => x),
    parentRules: ((w.parent_rules as unknown[]) || []).map((p) => nodeFromWire(p as never, ((x: unknown) => x) as never)),
    decorators: ((w.decorators as unknown[]) || []).map((deco) => nodeFromWire(deco as never, _dto.decoratorFromWire as never)),
    checks: ((w.checks as unknown[]) || []).map((c) => nodeFromWire(c as never, _expr.exprFromWire as never)),
    args: nodeFromWire(w.args as never, _dto.argumentsFromWire as never),
    forHostName: nodeFromWire(w.for_host_name as never, ((x: unknown) => x) as never),
  };
}

function importStmtFromWire(w: Record<string, unknown>): unknown {
  const node = (w.node as Record<string, unknown>) || {};
  return {
    path: node.path,
    asName: node.as_name,
    pkgName: node.pkg_name,
    pkgRoot: node.pkg_root,
  };
}

const REGISTRY: Record<string, (w: Record<string, unknown>) => unknown> = {
  Expr: exprStmtFromWire,
  Unification: unificationStmtFromWire,
  Assign: assignStmtFromWire,
  Schema: schemaStmtFromWire,
  SchemaAttr: schemaAttrFromWire,
  Rule: ruleStmtFromWire,
  Import: importStmtFromWire,
};

export function stmtFromWire(w: Record<string, unknown> | undefined | null): unknown {
  if (!w) return undefined;
  if (!w.type) return undefined;
  const variant = w.type as string;
  const loader = REGISTRY[variant];
  if (loader) return Object.assign({ type: variant }, loader(w));
  return { type: variant };
}
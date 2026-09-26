// _dto.ts — Flat DTOs for positions inside NodeRef<T> where the wire shape
// lacks the polymorphic `type` discriminator. Mirrors the Java/Go bindings
// (see AST_DRIFT.md note A).
//
// The cycle between this module and _expr is broken with namespace imports —
// `_expr.exprFromWire` is read lazily at call time, so it's safe even though
// the modules load each other.

import { Node, nodeFromWire } from "./_base";
import * as _expr from "./_expr";
import * as _types from "./_types";

function mapNodes<T>(items: unknown[] | undefined, load: (inner: any) => T): Array<Node<T>> {
  return (items || [])
    .map((b) => nodeFromWire(b as never, load as never))
    .filter((n): n is Node<T> => n !== undefined);
}

export interface Decorator {
  func?: Node<unknown>;
  args?: Array<Node<unknown>>;
  keywords?: Array<Node<unknown>>;
}

export function decoratorFromWire(w: Record<string, unknown> | undefined | null): Decorator | undefined {
  if (!w) return undefined;
  return {
    func: nodeFromWire(w.func as never, _expr.exprFromWire as never),
    args: mapNodes(w.args as unknown[], _expr.exprFromWire),
    keywords: mapNodes(w.keywords as unknown[], keywordFromWire),
  };
}

export interface SchemaConfig {
  name?: Node<unknown>;
  args?: Array<Node<unknown>>;
  kwargs?: Array<Node<unknown>>;
  config?: Node<unknown>;
}

export function schemaConfigFromWire(w: Record<string, unknown> | undefined | null): SchemaConfig | undefined {
  if (!w) return undefined;
  return {
    name: nodeFromWire(w.name as never, _expr.exprFromWire as never),
    args: mapNodes(w.args as unknown[], _expr.exprFromWire),
    kwargs: mapNodes(w.kwargs as unknown[], keywordFromWire),
    config: nodeFromWire(w.config as never, _expr.exprFromWire as never),
  };
}

export interface ConfigEntry {
  key?: Node<unknown>;
  value?: Node<unknown>;
  operation?: string;
  isShorthand?: boolean;
}

export function configEntryFromWire(w: Record<string, unknown> | undefined | null): ConfigEntry | undefined {
  if (!w) return undefined;
  return {
    key: nodeFromWire(w.key as never, _expr.exprFromWire as never),
    value: nodeFromWire(w.value as never, _expr.exprFromWire as never),
    operation: w.operation as string | undefined,
    isShorthand: w.is_shorthand === true,
  };
}

export interface Keyword {
  arg?: Node<unknown>;
  value?: Node<unknown>;
}

export function keywordFromWire(w: Record<string, unknown> | undefined | null): Keyword | undefined {
  if (!w) return undefined;
  return {
    arg: nodeFromWire(w.arg as never, _expr.exprFromWire as never),
    value: nodeFromWire(w.value as never, _expr.exprFromWire as never),
  };
}

export interface Arguments {
  args?: Array<Node<unknown>>;
  defaults?: Array<Node<unknown>>;
  tyList?: Array<Node<unknown>>;
}

export function argumentsFromWire(w: Record<string, unknown> | undefined | null): Arguments | undefined {
  if (!w) return undefined;
  return {
    args: mapNodes(w.args as unknown[], _expr.exprFromWire),
    defaults: mapNodes(w.defaults as unknown[], _expr.exprFromWire),
    tyList: mapNodes(w.ty_list as unknown[], _types.typeFromWire),
  };
}

export interface MemberOrIndex {
  member?: Node<string>;
  index?: Node<unknown>;
}

export function memberOrIndexFromWire(w: Record<string, unknown> | undefined | null): MemberOrIndex | undefined {
  if (!w) return undefined;
  if (w.type === "Member") return { member: nodeFromWire(w.value as never, (x: string) => x) };
  if (w.type === "Index") return { index: nodeFromWire(w.value as never, _expr.exprFromWire as never) };
  return {};
}

export interface Target {
  name?: Node<string>;
  paths?: Array<MemberOrIndex>;
  pkgpath: string;
}

export function targetFromWire(w: Record<string, unknown> | undefined | null): Target | undefined {
  if (!w) return undefined;
  const paths = ((w.paths as unknown[]) || [])
    .map((p) => memberOrIndexFromWire(p as never))
    .filter((p): p is MemberOrIndex => p !== undefined);
  return {
    name: nodeFromWire(w.name as never, (x: string) => x),
    paths,
    pkgpath: (w.pkgpath as string) || "",
  };
}

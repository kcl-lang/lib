// _types.ts — Type hierarchy. Mirrors `ast::Type` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]` so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `typeFromWire` dispatches on that tag.

interface BasicType {
  type: string;
  isLiteral?: boolean;
}

function basicFromWire(w: Record<string, unknown>): BasicType {
  return { type: w.type as string, isLiteral: w.is_literal === true };
}

interface ListType {
  type: "List";
  innerType?: unknown;
}

function listFromWire(w: Record<string, unknown>): ListType {
  return { type: "List", innerType: w.inner_type };
}

interface DictType {
  type: "Dict";
  keyType?: unknown;
  valueType?: unknown;
}

function dictFromWire(w: Record<string, unknown>): DictType {
  return { type: "Dict", keyType: w.key_type, valueType: w.value_type };
}

interface SchemaRefType {
  type: "SchemaRef";
  schemaName?: string;
  pkgpath?: string;
}

function schemaRefFromWire(w: Record<string, unknown>): SchemaRefType {
  return { type: "SchemaRef", schemaName: w.schema_name as string | undefined, pkgpath: w.pkgpath as string | undefined };
}

interface LiteralType {
  type: "Literal";
  value?: unknown;
}

function literalFromWire(w: Record<string, unknown>): LiteralType {
  return { type: "Literal", value: w.value };
}

interface FunctionType {
  type: "Function";
  params?: unknown;
  returnTy?: unknown;
}

function functionFromWire(w: Record<string, unknown>): FunctionType {
  return { type: "Function", params: w.params, returnTy: w.return_ty };
}

interface UnionType {
  type: "Union";
  types?: unknown[];
}

function unionFromWire(w: Record<string, unknown>): UnionType {
  return { type: "Union", types: w.types as unknown[] | undefined };
}

interface KeyValueType {
  type: "KeyValue";
  key?: unknown;
  value?: unknown;
}

function keyValueFromWire(w: Record<string, unknown>): KeyValueType {
  return { type: "KeyValue", key: w.key, value: w.value };
}

const REGISTRY: Record<string, (w: Record<string, unknown>) => unknown> = {
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
};

export function typeFromWire(w: Record<string, unknown> | undefined | null): unknown {
  if (!w) return undefined;
  if (!w.type) return undefined;
  const loader = REGISTRY[w.type as string];
  if (loader) return loader(w);
  return { type: w.type as string };
}
/**
 * TypeScript type definitions for the typed KCL AST package.
 *
 * Mirrors the runtime loaders in `src/ast/*.mjs`, which convert the JSON
 * emitted by `parseFile` / `parseProgram` into camelCase objects matching
 * Rust's AST in `crates/ast/src/ast.rs`.
 */

// ---------------------------------------------------------------------------
// Base nodes
// ---------------------------------------------------------------------------

/** Source position — `ast::Pos` in Rust. */
export interface Pos {
  filename: string;
  line: number;
  column: number;
  endLine: number;
  endColumn: number;
}

/** A value of type `T` wrapped with source position — `NodeRef<T>` in Rust. */
export interface Node<T> {
  node: T;
  filename?: string;
  line?: number;
  column?: number;
  endLine?: number;
  endColumn?: number;
}

/** A comment attached to the module. */
export type Comment = Node<string>;

/** Raw wire shape of `Pos` (snake_case keys, as serialized by Rust). */
export interface WirePos {
  filename: string;
  line: number;
  column: number;
  end_line: number;
  end_column: number;
}

/** Raw wire shape of `NodeRef<T>` (snake_case keys, as serialized by Rust). */
export interface WireNode<T> {
  node: T;
  filename?: string;
  line?: number;
  column?: number;
  end_line?: number;
  end_column?: number;
}

// ---------------------------------------------------------------------------
// Types (`ast::Type`)
// ---------------------------------------------------------------------------

/** Basic named type: `"Bool" | "Int" | "Float" | "Str" | "None" | "Any" | "Void" | "Undefined"`. */
export interface BasicType {
  type:
    | "Bool"
    | "Int"
    | "Float"
    | "Str"
    | "None"
    | "Any"
    | "Void"
    | "Undefined";
  isLiteral: boolean;
}

export interface ListType {
  type: "List";
  /** Note: passed through from the wire shape untyped. */
  innerType?: unknown;
}

export interface DictType {
  type: "Dict";
  /** Note: passed through from the wire shape untyped. */
  keyType?: unknown;
  /** Note: passed through from the wire shape untyped. */
  valueType?: unknown;
}

export interface SchemaRefType {
  type: "SchemaRef";
  schemaName?: string;
  pkgpath?: string;
}

export interface LiteralType {
  type: "Literal";
  /** Note: passed through from the wire shape untyped. */
  value?: unknown;
}

export interface FunctionType {
  type: "Function";
  /** Note: passed through from the wire shape untyped. */
  params?: unknown;
  /** Note: passed through from the wire shape untyped. */
  returnTy?: unknown;
}

export interface UnionType {
  type: "Union";
  /** Note: passed through from the wire shape untyped. */
  types?: unknown[];
}

export interface KeyValueType {
  type: "KeyValue";
  /** Note: passed through from the wire shape untyped. */
  key?: unknown;
  /** Note: passed through from the wire shape untyped. */
  value?: unknown;
}

/**
 * Any KCL type annotation.
 * Note: unknown variants deserialize at runtime as `{ type: string }` (payload dropped).
 */
export type Type =
  | BasicType
  | ListType
  | DictType
  | SchemaRefType
  | LiteralType
  | FunctionType
  | UnionType
  | KeyValueType;

// ---------------------------------------------------------------------------
// Flat DTOs (payloads that have no polymorphic `type` tag of their own)
// ---------------------------------------------------------------------------

/** Flat decorator payload — `@deprecated(strict=True)`. */
export interface Decorator {
  func?: Node<Expr>;
  args: Node<Expr>[];
  keywords: Node<Keyword>[];
}

/** Inline schema instantiation payload — `ASchema(args) { ... }`. */
export interface SchemaConfig {
  name?: Node<Expr>;
  args: Node<Expr>[];
  kwargs: Node<Keyword>[];
  config?: Node<Expr>;
}

/** Config entry — `key = value` or `key: value`. */
export interface ConfigEntry {
  key?: Node<Expr>;
  value?: Node<Expr>;
  /** ConfigEntryOperation, e.g. `"Union"`. */
  operation?: string;
  isShorthand: boolean;
}

/** Keyword argument — `arg = value`. */
export interface Keyword {
  arg?: Node<Expr>;
  value?: Node<Expr>;
}

/** Lambda / schema parameter list. */
export interface Arguments {
  args: Node<Expr>[];
  defaults: Node<Expr>[];
  tyList: Node<Type>[];
}

/**
 * Member or index path segment — `a.b` or `a[0]`.
 * A `"Member"` payload yields `{ member }`, an `"Index"` payload yields `{ index }`.
 */
export interface MemberOrIndex {
  member?: Node<string>;
  index?: Node<Expr>;
}

/** `ast::Target` — `a.b.c`. */
export interface Target {
  name?: Node<string>;
  paths?: MemberOrIndex[];
  pkgpath: string;
}

// ---------------------------------------------------------------------------
// Expressions (`ast::Expr`)
// ---------------------------------------------------------------------------

export interface TargetExpr extends Target {
  type: "Target";
}

export interface IdentifierExpr {
  type: "Identifier";
  names: Node<string>[];
  pkgpath: string;
  ctx?: string;
}

export interface UnaryExpr {
  type: "Unary";
  op?: string;
  operand?: Node<Expr>;
}

export interface BinaryExpr {
  type: "Binary";
  left?: Node<Expr>;
  op?: string;
  right?: Node<Expr>;
}

export interface IfExpr {
  type: "If";
  body?: Node<Expr>;
  cond?: Node<Expr>;
  orelse?: Node<Expr>;
}

export interface SelectorExpr {
  type: "Selector";
  value?: Node<Expr>;
  attr?: Node<Expr>;
  ctx?: string;
  hasQuestion: boolean;
}

export interface CallExpr {
  type: "Call";
  func?: Node<Expr>;
  args: Node<Expr>[];
  keywords: Node<Keyword>[];
}

export interface ParenExpr {
  type: "Paren";
  expr?: Node<Expr>;
}

export interface QuantExpr {
  type: "Quant";
  target?: Node<Expr>;
  variables: Node<Expr>[];
  op?: string;
  test?: Node<Expr>;
  ifCond?: Node<Expr>;
  ctx?: string;
}

export interface ListExpr {
  type: "List";
  elts: Node<Expr>[];
  ctx?: string;
}

export interface ListIfItemExpr {
  type: "ListIfItem";
  ifCond?: Node<Expr>;
  exprs: Node<Expr>[];
  orelse?: Node<Expr>;
}

export interface ListCompExpr {
  type: "ListComp";
  elt?: Node<Expr>;
  generators: Node<Expr>[];
}

export interface StarredExpr {
  type: "Starred";
  value?: Node<Expr>;
  ctx?: string;
}

export interface DictCompExpr {
  type: "DictComp";
  entryKey?: Node<Expr>;
  key?: Node<Expr>;
  value?: Node<Expr>;
  generators: Node<Expr>[];
}

export interface ConfigIfEntryExpr {
  type: "ConfigIfEntry";
  ifCond?: Node<Expr>;
  items: Node<ConfigEntry>[];
  orelse?: Node<Expr>;
}

export interface CompClauseExpr {
  type: "CompClause";
  targets: Node<Expr>[];
  iter?: Node<Expr>;
  ifs: Node<Expr>[];
}

export interface SchemaExpr {
  type: "Schema";
  name?: Node<Expr>;
  args: Node<Expr>[];
  kwargs: Node<Keyword>[];
  config?: Node<Expr>;
}

export interface ConfigExpr {
  type: "Config";
  items: Node<ConfigEntry>[];
}

export interface LambdaExpr {
  type: "Lambda";
  args?: Node<Arguments>;
  body: Node<Expr>[];
  returnTy?: Node<Type>;
}

export interface SubscriptExpr {
  type: "Subscript";
  value?: Node<Expr>;
  index?: Node<Expr>;
  ctx?: string;
}

export interface CompareExpr {
  type: "Compare";
  left?: Node<Expr>;
  ops: string[];
  comparators: Node<Expr>[];
}

export interface NumberLitExpr {
  type: "NumberLit";
  binarySuffix?: string;
  value?: number;
}

export interface StringLitExpr {
  type: "StringLit";
  isLongString: boolean;
  rawValue: string;
  value: string;
}

export interface NameConstantLitExpr {
  type: "NameConstantLit";
  value?: boolean | null;
}

export interface JoinedStringExpr {
  type: "JoinedString";
  values: Node<Expr>[];
}

export interface FormattedValueExpr {
  type: "FormattedValue";
  value?: Node<Expr>;
  conversion?: string;
  formatSpec?: Node<Expr>;
}

export interface MissingExpr {
  type: "Missing";
}

/**
 * Any KCL expression.
 * Note: unknown variants deserialize at runtime as `{ type: string }` (payload dropped).
 */
export type Expr =
  | TargetExpr
  | IdentifierExpr
  | UnaryExpr
  | BinaryExpr
  | IfExpr
  | SelectorExpr
  | CallExpr
  | ParenExpr
  | QuantExpr
  | ListExpr
  | ListIfItemExpr
  | ListCompExpr
  | StarredExpr
  | DictCompExpr
  | ConfigIfEntryExpr
  | CompClauseExpr
  | SchemaExpr
  | ConfigExpr
  | LambdaExpr
  | SubscriptExpr
  | CompareExpr
  | NumberLitExpr
  | StringLitExpr
  | NameConstantLitExpr
  | JoinedStringExpr
  | FormattedValueExpr
  | MissingExpr;

// ---------------------------------------------------------------------------
// Statements (`ast::Stmt`)
// ---------------------------------------------------------------------------

export interface ExprStmt {
  type: "Expr";
  exprs: Node<Expr>[];
}

export interface UnificationStmt {
  type: "Unification";
  /** Note: passed through from the wire shape untyped. */
  target?: Node<unknown>;
  value?: Node<SchemaConfig>;
}

export interface AssignStmt {
  type: "Assign";
  targets: Node<Target>[];
  ty?: Node<Type>;
  value?: Node<Expr>;
}

export interface SchemaStmt {
  type: "Schema";
  doc?: Node<string>;
  name?: Node<string>;
  /** Note: passed through from the wire shape untyped. */
  parentName?: unknown;
  /** Note: passed through from the wire shape untyped. */
  forHostName?: unknown;
  isMixin: boolean;
  isProtocol: boolean;
  args?: Node<Arguments>;
  /** Note: passed through from the wire shape untyped. */
  mixins: Node<unknown>[];
  body: Node<Stmt>[];
  decorators: Node<Decorator>[];
  checks: Node<Expr>[];
  /** Note: passed through from the wire shape untyped. */
  indexSignature?: unknown;
}

export interface SchemaAttrStmt {
  type: "SchemaAttr";
  doc: string;
  name?: Node<string>;
  /** Assignment / aug-assign operator, e.g. `"="`, `"+="`. */
  op?: string;
  value?: Node<Expr>;
  isOptional: boolean;
  decorators: Node<Decorator>[];
  ty?: Node<Type>;
}

export interface RuleStmt {
  type: "Rule";
  doc?: Node<string>;
  name?: Node<string>;
  /** Note: passed through from the wire shape untyped. */
  parentRules: Node<unknown>[];
  decorators: Node<Decorator>[];
  checks: Node<Expr>[];
  args?: Node<Arguments>;
  /** Note: passed through from the wire shape untyped. */
  forHostName?: unknown;
}

export interface ImportStmt {
  type: "Import";
  path?: string;
  asName?: string;
  pkgName?: string;
  pkgRoot?: string;
}

/**
 * Any KCL statement.
 * Note: unknown variants deserialize at runtime as `{ type: string }` (payload dropped).
 */
export type Stmt =
  | ExprStmt
  | UnificationStmt
  | AssignStmt
  | SchemaStmt
  | SchemaAttrStmt
  | RuleStmt
  | ImportStmt;

// ---------------------------------------------------------------------------
// Module
// ---------------------------------------------------------------------------

/** Top-level AST node for a single KCL file — `ast::Module` in Rust. */
export interface Module {
  filename: string;
  doc?: Node<string>;
  body?: Array<Node<Stmt>>;
  comments?: Comment[];
}

// ---------------------------------------------------------------------------
// Loaders
// ---------------------------------------------------------------------------

/** Parse an `ast_json` string emitted by `parseFile` into a Module. */
export function parseModule(astJson: string): Module;

/**
 * Parse a program `ast_json` envelope (`{root, pkgs: {__main__: [...]}}`)
 * into a list of Modules.
 */
export function parseProgram(programJson: string): Module[];

/** Build a Module from its raw wire shape. */
export function moduleFromWire(w: Record<string, unknown>): Module;

/** Build a Pos from the wire-shape keys. */
export function posFromWire(w: WirePos | undefined | null): Pos | undefined;

/** Build a Node<T> from the wire shape, applying `load` to the inner `node`. */
export function nodeFromWire<T, U>(
  w: WireNode<U> | undefined | null,
  load: (inner: U) => T
): Node<T> | undefined;

export function commentFromWire(
  w: WireNode<string> | undefined | null
): Comment | undefined;

export function decoratorFromWire(
  w: Record<string, unknown> | undefined | null
): Decorator | undefined;

export function schemaConfigFromWire(
  w: Record<string, unknown> | undefined | null
): SchemaConfig | undefined;

export function configEntryFromWire(
  w: Record<string, unknown> | undefined | null
): ConfigEntry | undefined;

export function keywordFromWire(
  w: Record<string, unknown> | undefined | null
): Keyword | undefined;

export function argumentsFromWire(
  w: Record<string, unknown> | undefined | null
): Arguments | undefined;

export function memberOrIndexFromWire(
  w: Record<string, unknown> | undefined | null
): MemberOrIndex;

export function targetFromWire(
  w: Record<string, unknown> | undefined | null
): Target | undefined;

/** Polymorphic Expr loader. Returns `undefined` for missing/empty payloads. */
export function exprFromWire(
  w: Record<string, unknown> | undefined | null
): Expr | undefined;

/** Polymorphic Stmt loader. Returns `undefined` for missing/empty payloads. */
export function stmtFromWire(
  w: Record<string, unknown> | undefined | null
): Stmt | undefined;

/** Polymorphic Type loader. Returns `undefined` for missing/empty payloads. */
export function typeFromWire(
  w: Record<string, unknown> | undefined | null
): Type | undefined;

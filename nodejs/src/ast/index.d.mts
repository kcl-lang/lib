/**
 * TypeScript type definitions for the typed KCL AST package.
 *
 * This is the published type contract for `@kcl-lib/native/ast` — see the
 * `exports` map in `package.json`. It has to agree, field for field, with the
 * runtime loaders in `src/ast/*.mjs`, which convert the JSON emitted by
 * `parseFile` / `parseProgram` into camelCase objects matching Rust's AST in
 * `crates/ast/src/ast.rs`.
 *
 * ## The vocabulary is Java's
 *
 * Every type name here is the one `java/src/main/java/com/kcl/ast` uses, so the
 * two bindings can be read side by side. That is why `Compare` is not
 * `CompareExpr`, `ListComp` is not `ListCompExpr`, `SchemaAttr` is not
 * `SchemaAttrStmt`, and the untagged DTO twins are `Decorator` and
 * `SchemaConfig` exactly as they are in Java.
 *
 * Two places deliberately differ, because the runtime is the contract:
 *
 *   - `UnionType.types` is what `UnionType.typeElements` is in Java and in
 *     Rust. It is a deliberate rename, and changing it would fork the runtime
 *     from the other thirteen bindings.
 *   - `MemberOrIndex` is `{type, member}` / `{type, index}` here, where Java
 *     keeps the wire's `value` key on both branches.
 *
 * ## Three serde shapes are in play
 *
 *   1. `Stmt` and `Expr` are `#[serde(tag = "type")]`, and every variant is a
 *      newtype over a struct, so serde *flattens* the struct's fields beside
 *      the tag — `{"type": "Identifier", "names": [...]}`, with no
 *      `identifier` wrapper key. This is the single most common way a
 *      hand-written loader goes wrong, and it fails silently: the wrapper key
 *      is always absent, so every identifier comes back empty.
 *   2. `Type` is `#[serde(tag = "type", content = "value")]`, so it is
 *      *adjacently* tagged: the tag names the shape and the payload lives
 *      under `value`. `BasicType` is a fieldless enum, so a basic type arrives
 *      as `{"type": "Basic", "value": "Int"}` — the tag is `"Basic"`, not
 *      `"Int"`, and `name` is the payload.
 *   3. `MemberOrIndex` and `LiteralType` are `tag + content` again, which is
 *      why `LiteralType`'s payload is doubly nested.
 *
 * Every optional field is `undefined` rather than `null` at runtime, because
 * `nodeFromWire` returns `undefined` for an absent wrapper.
 *
 * `Node<T>` is Java's `NodeRef<T>`; Java splits the two because its `Node`
 * carries an `id` field that the Rust wire does not have.
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

/**
 * A `#` line attached to the module.
 *
 * `ast::Comment` is a plain struct with one `String` field, so the object
 * under `node` is `{"text": "…"}` and *not* the text itself. Declaring this as
 * `Node<string>` hands every caller that object where it promised a string, and
 * `startsWith` on it then throws.
 */
export interface Comment {
  text: string;
  filename?: string;
  line?: number;
  column?: number;
  endLine?: number;
  endColumn?: number;
}

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

/**
 * `ast::Identifier` — `a`, `_c`, `pkg.a`. A plain struct with no tag, so it is
 * a `NodeRef<Identifier>` and never an `Expr`.
 */
export interface Identifier {
  names: Node<string>[];
  pkgpath: string;
  ctx?: string;
}

/** `Type::Any` — the one variant with no payload. */
export interface AnyType {
  type: "Any";
}

/**
 * `Type::Basic(BasicType)`. `BasicType` is a fieldless Rust enum, so the
 * payload is a bare string rather than an object: `"Bool" | "Int" | "Float" |
 * "Str"`, spelled with the Rust variant's capitalisation.
 */
export interface BasicType {
  type: "Basic";
  name: string;
}

/**
 * `Type::Named(Identifier)`. The payload nests one level under `value` on the
 * wire and is flattened back onto the struct here.
 */
export interface NamedType {
  type: "Named";
  identifier?: Identifier;
}

/** `Type::List(ListType)`. */
export interface ListType {
  type: "List";
  innerType?: Node<Type>;
}

/** `Type::Dict(DictType)`. */
export interface DictType {
  type: "Dict";
  keyType?: Node<Type>;
  valueType?: Node<Type>;
}

/** `Type::Union(UnionType)`. Java calls the field `typeElements`; the rename to
 *  `types` is deliberate and is the one place this file parts ways with it. */
export interface UnionType {
  type: "Union";
  types: Node<Type>[];
}

/**
 * `Type::Literal(LiteralType)`. `LiteralType` is *itself* tagged, so the
 * payload is doubly nested: `{"type":"Int","value":{"value":1,"suffix":null}}`.
 */
export interface LiteralType {
  type: "Literal";
  value: unknown;
  /** The inner `LiteralType` tag, so a caller need not reach into `value`. */
  innerTag?: string;
}

/** `Type::Function(FunctionType)`. */
export interface FunctionType {
  type: "Function";
  paramsTy?: Node<Type>[];
  retTy?: Node<Type>;
}

/**
 * A tag this build does not know about — the eight variants above are the whole
 * enum. `value` is the raw payload, so a caller can still reach what a newer
 * parser emitted instead of getting `undefined` and a thrown TypeError. Java
 * has no equivalent: Jackson raises on an unregistered subtype.
 */
export interface UnknownType {
  type: "Unknown";
  tag: string;
  value: unknown;
}

/** Any KCL type annotation. */
export type Type =
  | AnyType
  | BasicType
  | NamedType
  | ListType
  | DictType
  | UnionType
  | LiteralType
  | FunctionType
  | UnknownType;

// ---------------------------------------------------------------------------
// Flat DTOs — plain structs nested in `NodeRef<T>` with no tag of their own
// ---------------------------------------------------------------------------

/** `ast::Keyword` — `arg=value`. Also the payload of `Expr::Keyword`. */
export interface Keyword {
  /** A `NodeRef<Identifier>`, not a `NodeRef<Expr>`. */
  arg: Node<Identifier>;
  value?: Node<Expr>;
}

/** `ast::Arguments` — a lambda's parameter list. Also `Expr::Arguments`. */
export interface Arguments {
  args: Node<Identifier>[];
  /** Same length as `args`; the slots for absent defaults are `undefined`. */
  defaults: (Node<Expr> | undefined)[];
  /** Same length as `args`; the slots for absent types are `undefined`. */
  tyList: (Node<Type> | undefined)[];
}

/** `ast::CheckExpr` — `len(attr) > 3 if attr, "message"`. Also `Expr::Check`. */
export interface CheckExpr {
  /** Only present on the expression; `SchemaStmt.checks` holds untagged ones. */
  type?: "Check";
  test: Node<Expr>;
  ifCond?: Node<Expr>;
  msg?: Node<Expr>;
}

/** `ast::CompClause` — one `for x in y if z` leg of a comprehension. */
export interface CompClause {
  targets: Node<Identifier>[];
  iter: Node<Expr>;
  ifs: Node<Expr>[];
}

/** `ast::ConfigEntry` — one `key = value` / `key: value` / `key += value`. */
export interface ConfigEntry {
  key?: Node<Expr>;
  value: Node<Expr>;
  /** `"Union"` | `"Override"` | `"Insert"`. */
  operation?: string;
  /**
   * The ES6 `{name}` form. `is_shorthand` carries
   * `skip_serializing_if = "is_false"`, so the key is missing rather than
   * `false` on the wire; the loader always yields a real boolean.
   */
  isShorthand: boolean;
}

/**
 * `ast::CallExpr` in its untagged form — a decorator, `@deprecated(strict=True)`.
 * `SchemaStmt.decorators` is `Vec<NodeRef<CallExpr>>` and only the *enum* is
 * tagged, so each element arrives as a bare `{func, args, keywords}`. Java
 * spells this second, field-identical class `Decorator`; the tagged twin is
 * `CallExpr` below.
 */
export interface Decorator {
  func: Node<Expr>;
  args: Node<Expr>[];
  keywords: Node<Keyword>[];
}

/**
 * `ast::SchemaExpr` in its untagged form. It is a plain struct, so when it
 * appears outside the `Expr` enum — as the right-hand side of
 * `s: Person { ... }` — it arrives with no `type` tag and cannot go through
 * `exprFromWire`. Java spells this twin `SchemaConfig`; the tagged one is
 * `SchemaExpr` below.
 */
export interface SchemaConfig {
  name: Node<Identifier>;
  args: Node<Expr>[];
  kwargs: Node<Keyword>[];
  config: Node<Expr>;
}

/**
 * `ast::SchemaIndexSignature` — the `[k: str]: int` statement in a schema
 * body. It is a *body statement* reached through `SchemaStmt.indexSignature`,
 * not part of the `schema` header: `schema Bag[k: str]` is a generic schema
 * whose `args` is an `Arguments`.
 */
export interface SchemaIndexSignature {
  keyName?: Node<string>;
  value?: Node<Expr>;
  anyOther: boolean;
  keyTy: Node<Type>;
  valueTy: Node<Type>;
}

/**
 * `ast::MemberOrIndex` — the `tag + content` enum behind a `Target`'s paths.
 * Its `value` is itself a `NodeRef`, so `Member` wraps a `NodeRef<String>` and
 * `Index` a `NodeRef<Expr>`; this binding renames those to `member` and
 * `index`, where Java keeps the wire's `value` key on both branches. A tag
 * outside the pair decodes to `{}`.
 */
export interface MemberOrIndex {
  type?: "Member" | "Index";
  member?: Node<string>;
  index?: Node<Expr>;
}

/** `ast::Target` — `a.b[0].c`. */
export interface Target {
  name: Node<string>;
  paths: MemberOrIndex[];
  pkgpath: string;
}

// ---------------------------------------------------------------------------
// Expressions (`ast::Expr`)
// ---------------------------------------------------------------------------

/**
 * `Expr::Target(Target)` — flattened, so the tag sits beside `Target`'s own
 * fields; there is no `target` wrapper key. Java models the same split as
 * `TargetExpr extends Target`.
 */
export interface TargetExpr extends Target {
  type: "Target";
}

/** `Expr::Identifier(Identifier)` — likewise flattened. */
export interface IdentifierExpr extends Identifier {
  type: "Identifier";
}

export interface UnaryExpr {
  type: "Unary";
  op?: string;
  operand: Node<Expr>;
}

export interface BinaryExpr {
  type: "Binary";
  left: Node<Expr>;
  op?: string;
  right: Node<Expr>;
}

/** The `If` *expression*. `IfStmt` shares the tag with a different shape,
 *  because the tag alone does not say which hierarchy it is in. */
export interface IfExpr {
  type: "If";
  body: Node<Expr>;
  cond: Node<Expr>;
  orelse: Node<Expr>;
}

export interface SelectorExpr {
  type: "Selector";
  value: Node<Expr>;
  /** A `NodeRef<Identifier>`, not a `NodeRef<Expr>`. */
  attr: Node<Identifier>;
  ctx?: string;
  hasQuestion: boolean;
}

/** `Expr::Call(CallExpr)` — the tagged twin of `Decorator`. */
export interface CallExpr {
  type: "Call";
  func: Node<Expr>;
  args: Node<Expr>[];
  keywords: Node<Keyword>[];
}

export interface ParenExpr {
  type: "Paren";
  expr: Node<Expr>;
}

export interface QuantExpr {
  type: "Quant";
  target: Node<Expr>;
  variables: Node<Identifier>[];
  op?: string;
  test: Node<Expr>;
  ifCond: Node<Expr>;
  ctx?: string;
}

export interface ListExpr {
  type: "List";
  elts: Node<Expr>[];
  ctx?: string;
}

export interface ListIfItemExpr {
  type: "ListIfItem";
  ifCond: Node<Expr>;
  exprs: Node<Expr>[];
  orelse: Node<Expr>;
}

export interface ListComp {
  type: "ListComp";
  elt: Node<Expr>;
  /** `Vec<NodeRef<CompClause>>`, and `CompClause` is untagged. */
  generators: Node<CompClause>[];
}

export interface StarredExpr {
  type: "Starred";
  value: Node<Expr>;
  ctx?: string;
}

/** A `DictComp` has exactly one `entry: ConfigEntry` — not separate
 *  key/value/entry_key fields. */
export interface DictComp {
  type: "DictComp";
  entry?: ConfigEntry;
  generators: Node<CompClause>[];
}

export interface ConfigIfEntryExpr {
  type: "ConfigIfEntry";
  ifCond: Node<Expr>;
  items: Node<ConfigEntry>[];
  orelse: Node<Expr>;
}

/** `Expr::CompClause(CompClause)` — the tagged twin of the untagged clauses in
 *  `ListComp.generators` and `DictComp.generators`. */
export interface CompClauseExpr extends CompClause {
  type?: "CompClause";
}

/** `Expr::Schema(SchemaExpr)` — the tagged twin of `SchemaConfig`. */
export interface SchemaExpr extends SchemaConfig {
  type?: "Schema";
}

export interface ConfigExpr {
  type: "Config";
  items: Node<ConfigEntry>[];
}

export interface LambdaExpr {
  type: "Lambda";
  args: Node<Arguments>;
  /** A lambda body is `Vec<NodeRef<Stmt>>`, not a list of expressions. */
  body: Node<Stmt>[];
  returnTy: Node<Type>;
}

export interface Subscript {
  type: "Subscript";
  value: Node<Expr>;
  /** `a[0]` sets `index`; a slice sets `lower` / `upper` / `step` instead. */
  index?: Node<Expr>;
  lower?: Node<Expr>;
  upper?: Node<Expr>;
  step?: Node<Expr>;
  ctx?: string;
  hasQuestion: boolean;
}

/** `Expr::Keyword(Keyword)` — the tagged twin of the untagged `keywords`
 *  entries on a call. */
export interface KeywordExpr extends Keyword {
  type?: "Keyword";
}

/** `Expr::Arguments(Arguments)` — the tagged twin of the untagged one. */
export interface ArgumentsExpr extends Arguments {
  type?: "Arguments";
}

export interface Compare {
  type: "Compare";
  left: Node<Expr>;
  ops: string[];
  comparators: Node<Expr>[];
}

/**
 * `NumberLitValue` is its own `tag + content` enum, so `value` is an object —
 * `{"type": "Int", "value": 0}` — and not a bare number.
 */
export interface NumberLit {
  type: "NumberLit";
  binarySuffix?: string;
  value: unknown;
}

export interface StringLit {
  type: "StringLit";
  isLongString: boolean;
  rawValue: string;
  value: string;
}

export interface NameConstantLit {
  type: "NameConstantLit";
  value?: boolean | null;
}

export interface JoinedString {
  type: "JoinedString";
  isLongString: boolean;
  values: Node<Expr>[];
  rawValue: string;
}

export interface FormattedValue {
  type: "FormattedValue";
  isLongString: boolean;
  value: Node<Expr>;
  /** `format_spec` is a plain `Option<String>`, not a `NodeRef<Expr>`. */
  formatSpec?: string;
}

/** `Expr::Missing` has no fields, and the parser only emits it during error
 *  recovery, so it never appears in a clean parse. */
export interface MissingExpr {
  type: "Missing";
}

/** A tag this build does not know about; kept rather than dropped. */
export interface UnknownExpr {
  type: string;
  unknown: true;
}

/** Any KCL expression. */
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
  | ListComp
  | StarredExpr
  | DictComp
  | ConfigIfEntryExpr
  | CompClauseExpr
  | SchemaExpr
  | ConfigExpr
  | CheckExpr
  | LambdaExpr
  | Subscript
  | KeywordExpr
  | ArgumentsExpr
  | Compare
  | NumberLit
  | StringLit
  | NameConstantLit
  | JoinedString
  | FormattedValue
  | MissingExpr
  | UnknownExpr;

// ---------------------------------------------------------------------------
// Statements (`ast::Stmt`)
// ---------------------------------------------------------------------------

export interface TypeAliasStmt {
  type: "TypeAlias";
  typeName: Node<Identifier>;
  typeValue: Node<string>;
  ty: Node<Type>;
}

export interface ExprStmt {
  type: "Expr";
  exprs: Node<Expr>[];
}

/**
 * `s: Person { ... }`. `target` is a single `NodeRef<Identifier>` — the
 * declaration name — where `AssignStmt` has a list of `Target`s.
 */
export interface UnificationStmt {
  type: "Unification";
  target: Node<Identifier>;
  /** A `SchemaExpr` is a plain struct, so it cannot be dispatched as an `Expr`. */
  value: Node<SchemaConfig>;
}

export interface AssignStmt {
  type: "Assign";
  targets: Node<Target>[];
  ty: Node<Type>;
  value: Node<Expr>;
}

/** `AugAssign` takes a singular `target` where `Assign` takes `targets`. */
export interface AugAssignStmt {
  type: "AugAssign";
  target: Node<Target>;
  value: Node<Expr>;
  op?: string;
}

export interface AssertStmt {
  type: "Assert";
  test: Node<Expr>;
  ifCond: Node<Expr>;
  msg: Node<Expr>;
}

/** `If` is both a `Stmt` and an `Expr`, so each hierarchy owns its own. */
export interface IfStmt {
  type: "If";
  body: Node<Stmt>[];
  cond: Node<Expr>;
  orelse: Node<Stmt>[];
}

/**
 * `ImportStmt` is flat: `path` is a `NodeRef<String>` and `rawpath`, `name`,
 * `asname` and `pkgName` are plain strings beside it. There is no `node`
 * wrapper object, and no `asName` / `pkgRoot` field.
 */
export interface ImportStmt {
  type: "Import";
  path: Node<string>;
  rawpath: string;
  name: string;
  asname: Node<string>;
  pkgName: string;
}

export interface SchemaStmt {
  type: "Schema";
  doc: Node<string>;
  name: Node<string>;
  parentName: Node<Identifier>;
  forHostName: Node<Identifier>;
  isMixin: boolean;
  isProtocol: boolean;
  args: Node<Arguments>;
  mixins: Node<Identifier>[];
  /** Holds `SchemaAttr` and reaches the index signature. */
  body: Node<Stmt>[];
  decorators: Node<Decorator>[];
  /** `Vec<NodeRef<CheckExpr>>` — untagged, so not a `Node<Expr>[]`. */
  checks: Node<CheckExpr>[];
  indexSignature: Node<SchemaIndexSignature>;
}

export interface SchemaAttr {
  type: "SchemaAttr";
  doc: string;
  name: Node<string>;
  op?: string;
  value: Node<Expr>;
  isOptional: boolean;
  decorators: Node<Decorator>[];
  ty: Node<Type>;
}

export interface RuleStmt {
  type: "Rule";
  doc: Node<string>;
  name: Node<string>;
  parentRules: Node<Identifier>[];
  decorators: Node<Decorator>[];
  checks: Node<CheckExpr>[];
  args: Node<Arguments>;
  forHostName: Node<Identifier>;
}

/** A tag this build does not know about; kept rather than dropped. */
export interface UnknownStmt {
  type: string;
  unknown: true;
}

/** Any KCL statement. */
export type Stmt =
  | TypeAliasStmt
  | ExprStmt
  | UnificationStmt
  | AssignStmt
  | AugAssignStmt
  | AssertStmt
  | IfStmt
  | ImportStmt
  | SchemaStmt
  | SchemaAttr
  | RuleStmt
  | UnknownStmt;

// ---------------------------------------------------------------------------
// Module
// ---------------------------------------------------------------------------

/** Top-level AST node for a single KCL file — `ast::Module` in Rust. The Rust
 *  struct has no `pkg` field, and neither does this. */
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
  w: WireNode<{ text?: string }> | undefined | null
): Comment | undefined;

export function configEntryFromWire(
  w: Record<string, unknown> | undefined | null
): ConfigEntry | undefined;

export function keywordFromWire(
  w: Record<string, unknown> | undefined | null
): Keyword | undefined;

export function argumentsFromWire(
  w: Record<string, unknown> | undefined | null
): Arguments | undefined;

export function checkExprFromWire(
  w: Record<string, unknown> | undefined | null
): CheckExpr | undefined;

export function decoratorFromWire(
  w: Record<string, unknown> | undefined | null
): Decorator | undefined;

export function compClauseFromWire(
  w: Record<string, unknown> | undefined | null
): CompClause | undefined;

export function schemaIndexSignatureFromWire(
  w: Record<string, unknown> | undefined | null
): SchemaIndexSignature | undefined;

export function schemaConfigFromWire(
  w: Record<string, unknown> | undefined | null
): SchemaConfig | undefined;

export function memberOrIndexFromWire(
  w: Record<string, unknown> | undefined | null
): MemberOrIndex;

export function targetFromWire(
  w: Record<string, unknown> | undefined | null
): Target | undefined;

export function identifierFromWire(
  w: Record<string, unknown> | undefined | null
): Identifier | undefined;

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

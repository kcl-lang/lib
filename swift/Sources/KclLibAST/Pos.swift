// Pos.swift — Typed AST model for the Swift binding.
//
// Single source of truth: `kcl-lang/kcl crates/ast/src/ast.rs`. Everything
// below mirrors one Rust declaration, and the three serde shapes are what
// decide whether a field carries a `"type"` discriminator:
//
//   * `Stmt` and `Expr` are `#[serde(tag = "type")]` — *internally* tagged,
//     with no `rename_all`, so the wire tag is the variant name verbatim
//     (`NumberLit`, `ListIfItem`, `Check`, …) and the newtype variant's
//     struct fields are **flattened into the same object** as the tag.
//     `Expr::Identifier(Identifier)` therefore arrives as
//     `{"type":"Identifier","names":[…],"pkgpath":"","ctx":"Load"}`, never
//     as `{"type":"Identifier","identifier":{…}}`.
//
//   * `Type` is `#[serde(tag = "type", content = "value")]` — *adjacently*
//     tagged, so the payload lives under `value`. The tag names the shape,
//     not the type: `BasicType` is a fieldless enum with no struct wrapper,
//     so the wire is `{"type":"Basic","value":"Int"}`. `Any` is the only
//     unit variant, so it serializes to the bare `{"type":"Any"}` with no
//     `value` key at all.
//
//   * `MemberOrIndex` and `NumberLitValue` are also adjacently tagged, and
//     `LiteralType` is a third level of the same thing nested inside
//     `Type::Literal`'s payload.
//
// A fourth rule matters as much as the three shapes: which fields are
// declared as *structs* rather than *enum variants* have no tag even when
// they sit inside a tagged node. `SchemaStmt.decorators` is
// `Vec<NodeRef<CallExpr>>`, so a decorator is a bare `{func,args,keywords}`;
// `SchemaStmt.checks` is `Vec<NodeRef<CheckExpr>>`, so a check is a bare
// `{test,if_cond,msg}`. `DictComp.entry` is a bare `ConfigEntry` with no
// `NodeRef` wrapper at all, and `Target.paths` is a bare `Vec<MemberOrIndex>`.
//
// Swift has no `serde` analogue, so `AstJson.swift` parses with
// `JSONSerialization` into `[String: Any]` and these types are built by hand
// rather than by a `Codable` decoder. That keeps the same wire surface as
// the other bindings without writing a custom polymorphic decoder.

import Foundation

// MARK: - Base primitives

/// `ast::Pos` — file, line and column of a node. On the wire these five
/// fields are flattened onto the `Node<T>` wrapper itself, not nested under
/// a `"position"` key.
public struct Pos: Sendable, Equatable {
    public let filename: String
    public let line: Int64
    public let column: Int64
    public let endLine: Int64
    public let endColumn: Int64

    public init(filename: String, line: Int64, column: Int64, endLine: Int64, endColumn: Int64) {
        self.filename = filename
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
}

/// `ast::Node<T>` — `{id, node, filename, line, column, end_line, end_column}`.
///
/// `position` is optional here because a bare `T` (as in
/// `Type::Named(Identifier)`, where the newtype payload is inlined into
/// `value`) arrives with no wrapper to read a position from.
public struct NodeRef<T: Sendable>: Sendable {
    public let node: T
    public let position: Pos?
    public let id: String?

    public init(node: T, position: Pos? = nil, id: String? = nil) {
        self.node = node
        self.position = position
        self.id = id
    }
}

/// `ast::Comment` — a plain struct with a single `text` field, so a
/// `NodeRef<Comment>` is `{node: {text}, filename, …}`, not a bare string.
public struct Comment: Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

/// `ast::Module` — one `.k` file. There is deliberately no `pkg` field:
/// the Rust struct has none either.
public struct Module: Sendable {
    public let filename: String
    public let doc: NodeRef<String>?
    public let body: [NodeRef<Stmt>]
    public let comments: [NodeRef<Comment>]

    public init(
        filename: String,
        doc: NodeRef<String>? = nil,
        body: [NodeRef<Stmt>] = [],
        comments: [NodeRef<Comment>] = []
    ) {
        self.filename = filename
        self.doc = doc
        self.body = body
        self.comments = comments
    }
}

/// The `ParseProgramResult.astJson` payload. The wire is
/// `{"root": ".", "pkgs": {"__main__": [Module, …]}}`; we surface the main
/// package's modules directly and keep the full map for callers that need
/// the imported packages too.
public struct Program: Sendable {
    public let root: String
    public let mainPackage: [Module]
    public let pkgs: [String: [Module]]

    public init(root: String, mainPackage: [Module], pkgs: [String: [Module]]) {
        self.root = root
        self.mainPackage = mainPackage
        self.pkgs = pkgs
    }
}

// MARK: - Polymorphic enums

/// `ast::Stmt` — eleven `#[serde(tag = "type")]` variants. `if` and `import`
/// are Swift keywords so the case labels are backticked; the wire tag is
/// unaffected.
public indirect enum Stmt: Sendable {
    case typeAlias(TypeAliasStmt)
    case expr(ExprStmt)
    case unification(UnificationStmt)
    case assign(AssignStmt)
    case augAssign(AugAssignStmt)
    case assert(AssertStmt)
    case `if`(IfStmt)
    case `import`(ImportStmt)
    case schemaAttr(SchemaAttr)
    case schema(SchemaStmt)
    case rule(RuleStmt)
    /// A variant this build doesn't know about. Kept verbatim so a newer
    /// parser's output survives the round trip instead of being dropped.
    case unknown(type: String)
}

/// `ast::Expr` — thirty `#[serde(tag = "type")]` variants.
///
/// Note there is no separate `IdentifierExpr` type: `Expr::Identifier` wraps
/// the `Identifier` DTO directly, so the identifier's `names`/`pkgpath`/`ctx`
/// sit next to the tag rather than under an extra key.
public indirect enum Expr: Sendable {
    case target(Target)
    case identifier(Identifier)
    case unary(UnaryExpr)
    case binary(BinaryExpr)
    case `if`(IfExpr)
    case selector(SelectorExpr)
    case call(CallExpr)
    case paren(ParenExpr)
    case quant(QuantExpr)
    case list(ListExpr)
    case listIfItem(ListIfItemExpr)
    case listComp(ListComp)
    case starred(StarredExpr)
    case dictComp(DictComp)
    case configIfEntry(ConfigIfEntryExpr)
    case compClause(CompClause)
    case schema(SchemaExpr)
    case config(ConfigExpr)
    case check(CheckExpr)
    case lambda(LambdaExpr)
    case `subscript`(Subscript)
    case keyword(Keyword)
    case arguments(Arguments)
    case compare(Compare)
    case numberLit(NumberLit)
    case stringLit(StringLit)
    case nameConstantLit(NameConstantLit)
    case joinedString(JoinedString)
    case formattedValue(FormattedValue)
    case missing(MissingExpr)
    case unknown(type: String)
}

/// `ast::Type` — eight `#[serde(tag = "type", content = "value")]` variants.
/// The name `KclTypeNode` avoids colliding with Swift's `Type` protocol
/// existential and with the protobuf `Type` in `KclLib`.
public indirect enum KclTypeNode: Sendable {
    case any(AnyType)
    case named(Identifier)
    case basic(BasicType)
    case list(ListType)
    case dict(DictType)
    case union(UnionType)
    case literal(LiteralType)
    case function(FunctionType)
    case unknown(type: String)
}

/// `ast::MemberOrIndex` — the dotted/indexed path of a `Target`.
public indirect enum MemberOrIndex: Sendable {
    case member(NodeRef<String>)
    case index(NodeRef<Expr>)
}

/// `ast::NumberLitValue` — `{type:"Int",value:1}` / `{type:"Float",value:1.5}`.
public indirect enum NumberLitValue: Sendable {
    case int(Int64)
    case float(Double)
}

/// `ast::LiteralType` — itself adjacently tagged, so `Type::Literal` nests a
/// second tagged document inside its `value`.
public indirect enum LiteralTypeValue: Sendable {
    case bool(Bool)
    case int(IntLiteralType)
    case float(Double)
    case str(String)
}

// MARK: - Stmt payloads

public struct TypeAliasStmt: Sendable {
    /// `type_name`, not `name` — the wire key is what matters and a decoder
    /// that guesses at names silently decodes null.
    public let typeName: NodeRef<Identifier>
    /// The human-readable spelling Rust carries alongside the parsed `ty`.
    public let typeValue: NodeRef<String>
    public let ty: NodeRef<KclTypeNode>
}

public struct ExprStmt: Sendable {
    /// A list even though a statement holds one expression: `a, b = 1, 2`
    /// desugars into two.
    public let exprs: [NodeRef<Expr>]
}

public struct UnificationStmt: Sendable {
    /// `data: ASchema {}` — the target is an `Identifier` and the value a
    /// `SchemaExpr`, both bare structs rather than tagged expressions.
    public let target: NodeRef<Identifier>
    public let value: NodeRef<SchemaExpr>
}

public struct AssignStmt: Sendable {
    /// `Target` is a struct, so each element has no `"type"` tag even though
    /// the statement wrapping it does.
    public let targets: [NodeRef<Target>]
    public let value: NodeRef<Expr>
    public let ty: NodeRef<KclTypeNode>?
}

public struct AugAssignStmt: Sendable {
    public let target: NodeRef<Target>
    public let value: NodeRef<Expr>
    public let op: AugOp
}

public struct AssertStmt: Sendable {
    /// Same three fields as `CheckExpr`, but it *is* a statement so it
    /// carries the tag `"Assert"`.
    public let test: NodeRef<Expr>
    public let ifCond: NodeRef<Expr>?
    public let msg: NodeRef<Expr>?
}

public struct IfStmt: Sendable {
    public let body: [NodeRef<Stmt>]
    public let cond: NodeRef<Expr>
    /// A flat list of statements, not a nested `IfStmt`: the `elif` chain is
    /// a sibling list. Modelling it as a nested if is the classic way to get
    /// `elif` wrong.
    public let orelse: [NodeRef<Stmt>]
}

public struct ImportStmt: Sendable {
    /// A flat five-field struct with no `"node"` wrapper. `path` *does* carry
    /// a position (it is a `Node<String>`), but the statement does not.
    public let path: NodeRef<String>
    public let rawpath: String
    public let name: String
    public let asname: NodeRef<String>?
    /// Not `pkg_root`: `pkg_name` is the package this import indexes into,
    /// and it is `"__main__"` for builtins, plugins and internal packages.
    public let pkgName: String
}

public struct SchemaStmt: Sendable {
    public let doc: NodeRef<String>?
    public let name: NodeRef<String>
    public let parentName: NodeRef<Identifier>?
    public let forHostName: NodeRef<Identifier>?
    public let isMixin: Bool
    public let isProtocol: Bool
    public let args: NodeRef<Arguments>?
    public let mixins: [NodeRef<Identifier>]
    public let body: [NodeRef<Stmt>]
    /// `Vec<NodeRef<CallExpr>>` — a bare `{func,args,keywords}`, untagged.
    public let decorators: [NodeRef<CallExpr>]
    /// `Vec<NodeRef<CheckExpr>>` — a bare `{test,if_cond,msg}`, untagged.
    public let checks: [NodeRef<CheckExpr>]
    public let indexSignature: NodeRef<SchemaIndexSignature>?
}

public struct SchemaAttr: Sendable {
    public let doc: String
    public let name: NodeRef<String>
    /// `Some(Assign)` for an ordinary attribute — Rust uses `op` for the
    /// augmented operator but a plain `attr: int = 1` still reports
    /// `"Assign"` here.
    public let op: AugOp?
    public let value: NodeRef<Expr>?
    public let isOptional: Bool
    public let decorators: [NodeRef<CallExpr>]
    /// Not optional: Rust declares `ty: NodeRef<Type>`.
    public let ty: NodeRef<KclTypeNode>
}

public struct RuleStmt: Sendable {
    public let doc: NodeRef<String>?
    public let name: NodeRef<String>
    public let parentRules: [NodeRef<Identifier>]
    public let decorators: [NodeRef<CallExpr>]
    public let checks: [NodeRef<CheckExpr>]
    public let args: NodeRef<Arguments>?
    public let forHostName: NodeRef<Identifier>?
}

// MARK: - Expr payloads

public struct UnaryExpr: Sendable {
    public let op: UnaryOp
    public let operand: NodeRef<Expr>
}

public struct BinaryExpr: Sendable {
    public let left: NodeRef<Expr>
    public let op: BinOp
    public let right: NodeRef<Expr>
}

public struct IfExpr: Sendable {
    public let body: NodeRef<Expr>
    public let cond: NodeRef<Expr>
    public let orelse: NodeRef<Expr>
}

public struct SelectorExpr: Sendable {
    public let value: NodeRef<Expr>
    /// `attr`, an `Identifier` — not `attr_name`, and not a bare string.
    public let attr: NodeRef<Identifier>
    public let ctx: ExprContext
    /// True for `a?.b` — the `?` is recorded, not folded into `ctx`.
    public let hasQuestion: Bool
}

public struct CallExpr: Sendable {
    public let `func`: NodeRef<Expr>
    public let args: [NodeRef<Expr>]
    public let keywords: [NodeRef<Keyword>]
}

public struct ParenExpr: Sendable {
    public let expr: NodeRef<Expr>
}

public struct QuantExpr: Sendable {
    public let target: NodeRef<Expr>
    public let variables: [NodeRef<Identifier>]
    public let op: QuantOperation
    /// The predicate is `test`, not `cond`.
    public let test: NodeRef<Expr>
    public let ifCond: NodeRef<Expr>?
    public let ctx: ExprContext
}

public struct ListExpr: Sendable {
    public let elts: [NodeRef<Expr>]
    public let ctx: ExprContext
}

public struct ListIfItemExpr: Sendable {
    public let ifCond: NodeRef<Expr>
    public let exprs: [NodeRef<Expr>]
    public let orelse: NodeRef<Expr>?
}

public struct ListComp: Sendable {
    public let elt: NodeRef<Expr>
    public let generators: [NodeRef<CompClause>]
}

public struct StarredExpr: Sendable {
    public let value: NodeRef<Expr>
    public let ctx: ExprContext
}

public struct DictComp: Sendable {
    /// A bare `ConfigEntry` — no `NodeRef` wrapper, so the entry's `key`,
    /// `value` and `operation` sit directly under `entry`.
    public let entry: ConfigEntry
    public let generators: [NodeRef<CompClause>]
}

public struct ConfigIfEntryExpr: Sendable {
    public let ifCond: NodeRef<Expr>
    public let items: [NodeRef<ConfigEntry>]
    /// The else branch is a whole `ConfigExpr`, not a second
    /// `ConfigIfEntryExpr`.
    public let orelse: NodeRef<Expr>?
}

public struct SchemaExpr: Sendable {
    /// `NodeRef<Identifier>`, not an `Expr` — `Person` in `Person {…}` is
    /// an identifier, not a `Selector` or `Identifier` expression.
    public let name: NodeRef<Identifier>
    public let args: [NodeRef<Expr>]
    public let keywords: [NodeRef<Keyword>]
    /// For `Person {name = "Alice"}` the entries land here and `keywords`
    /// stays empty; `Person(1, name = "Bob")` is a plain `Expr::Call`.
    public let config: NodeRef<Expr>
}

public struct ConfigExpr: Sendable {
    public let items: [NodeRef<ConfigEntry>]
}

public struct LambdaExpr: Sendable {
    /// Optional: `lambda { … }` has no parameter list at all, and absent is
    /// different from empty on the wire.
    public let args: NodeRef<Arguments>?
    /// Statements, not expressions — a lambda body is a `Vec<NodeRef<Stmt>>`.
    public let body: [NodeRef<Stmt>]
    public let returnTy: NodeRef<KclTypeNode>?
}

public struct Subscript: Sendable {
    public let value: NodeRef<Expr>
    /// `a[i]` sets `index`; `a[1:2:3]` sets `lower`/`upper`/`step`. The
    /// three are separate fields rather than one slice expression.
    public let index: NodeRef<Expr>?
    public let lower: NodeRef<Expr>?
    public let upper: NodeRef<Expr>?
    public let step: NodeRef<Expr>?
    public let ctx: ExprContext
    public let hasQuestion: Bool
}

public struct Compare: Sendable {
    public let left: NodeRef<Expr>
    /// Parallel arrays: `ops[i]` is the operator between `left`
    /// (or `comparators[i-1]`) and `comparators[i]`.
    public let ops: [CmpOp]
    public let comparators: [NodeRef<Expr>]
}

public struct NumberLit: Sendable {
    public let binarySuffix: NumberBinarySuffix?
    public let value: NumberLitValue
}

public struct StringLit: Sendable {
    public let isLongString: Bool
    public let rawValue: String
    public let value: String
}

public struct NameConstantLit: Sendable {
    public let value: NameConstant
}

public struct JoinedString: Sendable {
    public let isLongString: Bool
    public let values: [NodeRef<Expr>]
    public let rawValue: String
}

public struct FormattedValue: Sendable {
    public let isLongString: Bool
    public let value: NodeRef<Expr>
    /// `format_spec`, and a bare `String` — there is no node position.
    public let formatSpec: String?
}

public struct MissingExpr: Sendable {}

public struct CheckExpr: Sendable {
    public let test: NodeRef<Expr>
    public let ifCond: NodeRef<Expr>?
    public let msg: NodeRef<Expr>?
}

// MARK: - Type payloads

/// `Type::Any` — the only unit variant of `Type`, and the only one with no
/// payload: the wire is the bare `{"type":"Any"}` with no `value` key.
public struct AnyType: Sendable {}

public struct ListType: Sendable {
    public let innerType: NodeRef<KclTypeNode>?
}

public struct DictType: Sendable {
    public let keyType: NodeRef<KclTypeNode>?
    public let valueType: NodeRef<KclTypeNode>?
}

public struct UnionType: Sendable {
    /// `type_elements`, not `types`.
    public let typeElements: [NodeRef<KclTypeNode>]
}

public struct FunctionType: Sendable {
    /// Both are `Option<…>`: `(int, str) -> bool` omits the parameter list
    /// parentheses' absence, and a bare `-> bool` has no `params_ty`.
    public let paramsTy: [NodeRef<KclTypeNode>]?
    public let retTy: NodeRef<KclTypeNode>?
}

public struct LiteralType: Sendable {
    public let value: LiteralTypeValue
}

/// `IntLiteralType` — the newtype payload of `LiteralType::Int`, inlined
/// into `value` rather than nested under another key.
public struct IntLiteralType: Sendable {
    public let value: Int64
    public let suffix: NumberBinarySuffix?
}

// MARK: - Flat DTOs

/// `ast::Identifier` — a dotted name plus a package path and a load/store
/// context. Appears as a bare struct (inside `NodeRef<Identifier>` fields),
/// as the flattened payload of `Expr::Identifier`, and inlined into
/// `Type::Named`'s `value`.
public struct Identifier: Sendable {
    /// One entry per dotted segment; each carries its own position.
    public let names: [NodeRef<String>]
    public let pkgpath: String
    public let ctx: ExprContext

    public init(names: [NodeRef<String>], pkgpath: String = "", ctx: ExprContext = .load) {
        self.names = names
        self.pkgpath = pkgpath
        self.ctx = ctx
    }

    /// `foo.bar.baz` from `["foo", "bar", "baz"]`.
    public func dottedName() -> String {
        names.map { $0.node }.joined(separator: ".")
    }
}

/// `ast::Target` — an assignment target: a name plus an optional
/// member/index path. A struct, so it has no `"type"` tag even inside a
/// tagged statement, and it *is* the payload of `Expr::Target`.
public struct Target: Sendable {
    public let name: NodeRef<String>
    /// A bare `Vec<MemberOrIndex>` — each element is adjacently tagged
    /// `{"type":"Member"|"Index","value":…}`.
    public let paths: [MemberOrIndex]
    public let pkgpath: String
}

public struct ConfigEntry: Sendable {
    /// Optional: the ES6-style `{name}` shorthand has no separate key.
    public let key: NodeRef<Expr>?
    public let value: NodeRef<Expr>
    public let operation: ConfigEntryOperation
    /// `#[serde(skip_serializing_if = "is_false")]` upstream, so the key is
    /// absent unless true. We expose it as a plain `Bool`.
    public let isShorthand: Bool
}

public struct Keyword: Sendable {
    /// An `Identifier`, not an expression: `k = 3` names the parameter `k`.
    public let arg: NodeRef<Identifier>
    public let value: NodeRef<Expr>?
}

public struct Arguments: Sendable {
    public let args: [NodeRef<Identifier>]
    /// `Vec<Option<…>>`, index-aligned with `args` and `tyList` — see
    /// `OptionalNodeRefList` in `AstJson.swift` for why the nulls matter.
    public let defaults: [NodeRef<Expr>?]
    public let tyList: [NodeRef<KclTypeNode>?]
}

public struct CompClause: Sendable {
    /// Identifiers, not targets: `[i for i in xs]` binds `i`.
    public let targets: [NodeRef<Identifier>]
    public let iter: NodeRef<Expr>
    public let ifs: [NodeRef<Expr>]
}

public struct SchemaIndexSignature: Sendable {
    public let keyName: NodeRef<String>?
    public let value: NodeRef<Expr>?
    public let anyOther: Bool
    public let keyTy: NodeRef<KclTypeNode>
    public let valueTy: NodeRef<KclTypeNode>
}

// MARK: - Operator and literal enums

public enum UnaryOp: String, Sendable {
    case uAdd = "UAdd"
    case uSub = "USub"
    case invert = "Invert"
    case not = "Not"
}

public enum BinOp: String, Sendable {
    case add = "Add"
    case sub = "Sub"
    case mul = "Mul"
    case div = "Div"
    case mod = "Mod"
    case pow = "Pow"
    case floorDiv = "FloorDiv"
    case lShift = "LShift"
    case rShift = "RShift"
    case bitXor = "BitXor"
    case bitAnd = "BitAnd"
    case bitOr = "BitOr"
    case andOp = "And"
    case orOp = "Or"
    /// The type-cast operator. It lives here rather than in `CmpOp`
    /// because `a as T` parses as a binary expression.
    case asOp = "As"
}

public enum AugOp: String, Sendable {
    case assign = "Assign"
    case add = "Add"
    case sub = "Sub"
    case mul = "Mul"
    case div = "Div"
    case mod = "Mod"
    case pow = "Pow"
    case floorDiv = "FloorDiv"
    case lShift = "LShift"
    case rShift = "RShift"
    case bitXor = "BitXor"
    case bitAnd = "BitAnd"
    case bitOr = "BitOr"
}

public enum CmpOp: String, Sendable {
    case eq = "Eq"
    case notEq = "NotEq"
    case lt = "Lt"
    case ltE = "LtE"
    case gt = "Gt"
    case gtE = "GtE"
    // `is` and `in` are Swift keywords, so the case labels are backticked.
    // The raw values are the wire tags either way.
    case `is` = "Is"
    case `in` = "In"
    case notIn = "NotIn"
    case `not` = "Not"
    case isNot = "IsNot"
}

public enum QuantOperation: String, Sendable {
    case all = "All"
    case any = "Any"
    case filter = "Filter"
    case map = "Map"
}

public enum ConfigEntryOperation: String, Sendable {
    case union = "Union"
    case overrideOp = "Override"
    case insert = "Insert"
}

public enum ExprContext: String, Sendable {
    case load = "Load"
    case store = "Store"
}

public enum NameConstant: String, Sendable {
    case `true` = "True"
    case `false` = "False"
    case none = "None"
    case undefined = "Undefined"
}

/// `ast::NumberBinarySuffix` — note `K` and `k` (and `M`/`m`) are distinct
/// spellings, which is why these are explicit raw values rather than
/// lowercased.
public enum NumberBinarySuffix: String, Sendable {
    case n = "n"
    case u = "u"
    case m = "m"
    case k = "k"
    case kUpper = "K"
    case mUpper = "M"
    case g = "G"
    case t = "T"
    case p = "P"
    case ki = "Ki"
    case mi = "Mi"
    case gi = "Gi"
    case ti = "Ti"
    case pi = "Pi"
}

/// `ast::BasicType` — a fieldless enum, which is why the wire carries the
/// bare string `{"type":"Basic","value":"Int"}` and never `{"type":"Int"}`.
public enum BasicType: String, Sendable {
    case bool = "Bool"
    case int = "Int"
    case float = "Float"
    case str = "Str"
}

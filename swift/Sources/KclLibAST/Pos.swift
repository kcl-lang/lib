// Pos.swift — Typed AST package for the Swift binding.
//
// Mirrors the work already merged for Java (#322), Go, Python (#328),
// Node.js (#329), .NET (#330), WASM (#330), and Kotlin (#331). Wire
// shape follows `kcl-lang/kcl crates/ast/src/ast.rs`:
//
//   - `#[serde(tag = "type")]` polymorphic dispatch — every `Stmt` /
//     `Expr` / `Type` variant carries a `"type"` discriminator.
//   - Flat DTOs (`Decorator`, `SchemaConfig`, `ConfigEntry`, `Keyword`,
//     `Arguments`, `MemberOrIndex`, `Target`) where the `NodeRef<T>`
//     payload lacks the polymorphic tag — see AST_DRIFT.md note A.
//
// Lives in the `KclLibAST` SPM target (separate from `KclLib`) so
// the AST type names (`Decorator`, `FunctionType`, …) don't collide
// with the protobuf-generated structs of the same name in `KclLib`.
// This mirrors the .NET binding, which also puts the typed AST into
// its own assembly (`KclLib.AST`).
//
// Swift doesn't have a `serde` analogue, so we parse with
// `JSONSerialization` into `[String: Any]` and provide typed accessor
// helpers rather than `Codable` — that gives us the same wire-shape
// surface as the other bindings without writing a custom decoder.

import Foundation

// MARK: - Module & Program

/// A KCL module: a single `.k` source file's AST. Wire shape mirrors
/// `ast::Module` in `crates/ast/src/ast.rs`. The Rust struct has no `pkg`
/// field, so we omit it here too.
public struct Module: Sendable {
    public let filename: String
    public let doc: NodeRef<String>?
    public let body: [NodeRef<Stmt>]
    public let comments: [NodeRef<Comment>]

    public init(
        filename: String,
        doc: NodeRef<String>? = nil,
        body: [NodeRef<Stmt>] = [],
        comments: [NodeRef<Comment>] = [],
    ) {
        self.filename = filename
        self.doc = doc
        self.body = body
        self.comments = comments
    }
}

/// Envelope returned by `parseProgram`. Wire shape is
/// `{"root": ".", "pkgs": {"__main__": [Module, …]}}`. We only expose
/// the modules of the `__main__` package; external packages are kept
/// available via the `pkgs` map for callers that need them.
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

// MARK: - Base primitives

/// `ast::Pos` — file, line, column information attached to every AST node.
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

/// `NodeRef<T>` — the file/line/column wrapper that all AST nodes carry.
/// In Rust this is a single struct; in Swift we keep `position` optional
/// because some wire shapes omit it (e.g. when nested under a flat DTO).
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

/// `ast::Comment` — a comment attached to the source. Treated as a
/// `NodeRef<String>` in Rust.
public typealias Comment = NodeRef<String>

// MARK: - Stmt, Expr, Type (polymorphic enums)

/// `ast::Stmt` — top-level statement in a module. Mirrors the seven
/// `#[serde(tag = "type")]` variants.
public indirect enum Stmt: Sendable {
    case expr(ExprStmt)
    case unification(UnificationStmt)
    case assign(AssignStmt)
    case schema(SchemaStmt)
    case schemaAttr(SchemaAttr)
    case rule(RuleStmt)
    case `import`(ImportStmt)
    case typeAlias(TypeAliasStmt)
    case assert(AssertStmt)
    // `if` is a Swift reserved keyword — use backticks so callers can
    // still pattern-match `case .if(let s)`. Wire tag is still "If"
    // (the Rust serde discriminator) — only the Swift case label is
    // backticked.
    case `if`(IfStmt)
    case unknown(type: String)
}

public indirect enum Expr: Sendable {
    case target(TargetExpr)
    case identifier(IdentifierExpr)
    case unary(UnaryExpr)
    case binary(BinaryExpr)
    case ifExpr(IfExpr)
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
    case lambda(LambdaExpr)
    // `subscript` is a Swift reserved keyword — backtick it. Wire tag
    // is still "Subscript".
    case `subscript`(Subscript)
    case compare(Compare)
    case numberLit(NumberLit)
    case stringLit(StringLit)
    case nameConstantLit(NameConstantLit)
    case joinedString(JoinedString)
    case formattedValue(FormattedValue)
    case missing(MissingExpr)
    case check(CheckExpr)
    case unknown(type: String)
}

public indirect enum KclTypeNode: Sendable {
    case any(AnyType)
    case basic(BasicType)
    case list(ListType)
    case dict(DictType)
    case schemaRef(SchemaRefType)
    case literal(LiteralType)
    case function(FunctionType)
    case union(UnionType)
    case named(NamedType)
    case strLiteral(StrLiteralType)
    case intLiteral(IntLiteralType)
    case floatLiteral(FloatLiteralType)
    case boolLiteral(BoolLiteralType)
    case keyValue(KeyValueType)
    case unknown(type: String)
}

// MARK: - Stmt variants

public struct ExprStmt: Sendable {
    public let exprs: [NodeRef<Expr>]
}

public struct UnificationStmt: Sendable {
    public let target: NodeRef<Target>
    public let value: NodeRef<SchemaConfig>
}

public struct AssignStmt: Sendable {
    public let targets: [NodeRef<Target>]
    public let ty: NodeRef<KclTypeNode>?
    public let value: NodeRef<Expr>
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
    public let decorators: [NodeRef<Decorator>]
    public let checks: [NodeRef<CheckExpr>]
    public let indexSignature: NodeRef<SchemaIndexSignature>?
}

public struct SchemaAttr: Sendable {
    public let doc: String
    public let name: NodeRef<String>
    public let op: AugOp?
    public let value: NodeRef<Expr>?
    public let isOptional: Bool
    public let decorators: [NodeRef<Decorator>]
    public let ty: NodeRef<KclTypeNode>?
}

public struct RuleStmt: Sendable {
    public let doc: NodeRef<String>?
    public let name: NodeRef<String>
    public let parentRules: [NodeRef<Identifier>]
    public let decorators: [NodeRef<Decorator>]
    public let checks: [NodeRef<CheckExpr>]
    public let args: NodeRef<Arguments>?
    public let forHostName: NodeRef<Identifier>?
}

public struct ImportStmt: Sendable {
    public let path: String
    public let asName: String?
    public let pkgName: String?
    public let pkgRoot: String?
}

public struct TypeAliasStmt: Sendable {
    public let name: NodeRef<String>
    public let ty: NodeRef<KclTypeNode>
}

public struct AssertStmt: Sendable {
    public let source: NodeRef<Expr>
    public let assertMsg: NodeRef<String>?
}

public struct IfStmt: Sendable {
    public let cond: NodeRef<Expr>
    public let body: [NodeRef<Stmt>]
    public let orElse: NodeRef<Expr>?
}

// MARK: - Expr variants

public struct TargetExpr: Sendable {
    public let name: NodeRef<String>
}

public struct IdentifierExpr: Sendable {
    // Mirror Rust's `IdentifierExpr { names: Vec<Node<String>>, pkgpath: Vec<String> }`.
    // `names` is an array of `Node<String>` (one element per dotted
    // segment, e.g. `["foo", "bar", "baz"]` for `foo.bar.baz`). The
    // wire shape carries a full Node<String> per element so position
    // info is preserved.
    public let names: [NodeRef<String>]
    public let pkgpath: [String]
}

public struct UnaryExpr: Sendable {
    public let op: UnaryOp
    public let operand: NodeRef<Expr>
}

public struct BinaryExpr: Sendable {
    public let op: BinOp
    public let left: NodeRef<Expr>
    public let right: NodeRef<Expr>
}

public struct IfExpr: Sendable {
    public let cond: NodeRef<Expr>
    public let body: NodeRef<Expr>
    public let orElse: NodeRef<Expr>?
}

public struct SelectorExpr: Sendable {
    public let value: NodeRef<Expr>
    public let attrName: NodeRef<String>
}

public struct CallExpr: Sendable {
    // `func` is a Swift reserved keyword — backtick the property name
    // so the wire shape mirrors `CallExpr::func` in Rust's `ast.rs`.
    public let `func`: NodeRef<Expr>
    public let args: [NodeRef<Expr>]
    public let keywords: [NodeRef<Keyword>]
}

public struct ParenExpr: Sendable {
    public let expr: NodeRef<Expr>
}

public struct QuantExpr: Sendable {
    public let target: NodeRef<Target>
    public let variables: [NodeRef<QuantOperation>]
    public let op: QuantOperation
    public let cond: NodeRef<Expr>
}

public struct ListExpr: Sendable {
    public let elts: [NodeRef<Expr>]
}

public struct ListIfItemExpr: Sendable {
    public let ifExpr: NodeRef<Expr>
    public let orElse: NodeRef<Expr>?
    public var expr: NodeRef<Expr> { ifExpr }
    public var exprOrElse: NodeRef<Expr>? { orElse }
}

public struct ListComp: Sendable {
    public let elt: NodeRef<Expr>
    public let generators: [NodeRef<CompClause>]
    public let cond: NodeRef<Expr>?
}

public struct StarredExpr: Sendable {
    public let value: NodeRef<Expr>
    public let ctx: ExprContext
}

public struct DictComp: Sendable {
    public let key: NodeRef<Expr>
    public let value: NodeRef<Expr>
    public let generators: [NodeRef<CompClause>]
    public let cond: NodeRef<Expr>?
}

public struct ConfigIfEntryExpr: Sendable {
    public let ifExpr: NodeRef<Expr>
    public var expr: NodeRef<Expr> { ifExpr }
}

public struct CompClause: Sendable {
    public let targets: [NodeRef<Target>]
    public let iter: NodeRef<Expr>
    public let ifs: [NodeRef<Expr>]
}

public struct SchemaExpr: Sendable {
    public let name: NodeRef<Expr>
    public let args: [NodeRef<Expr>]
    public let kwargs: [NodeRef<Keyword>]
    public let config: NodeRef<Expr>
}

public struct ConfigExpr: Sendable {
    public let items: [NodeRef<ConfigEntry>]
}

public struct LambdaExpr: Sendable {
    public let args: NodeRef<Arguments>
    public let body: [NodeRef<Stmt>]
    public let returnTy: NodeRef<KclTypeNode>?
}

public struct Subscript: Sendable {
    public let value: NodeRef<Expr>
    public let index: NodeRef<Expr>
}

public struct Compare: Sendable {
    public let left: NodeRef<Expr>
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
    public let values: [NodeRef<Expr>]
    public let isLongString: Bool
    public let rawValue: String
}

public struct FormattedValue: Sendable {
    public let value: NodeRef<Expr>
    public let spec: String?
}

public struct MissingExpr: Sendable {}

public struct CheckExpr: Sendable {
    // Wire shape: `{test, if_cond, msg}` — see `ast::CheckExpr` in
    // `crates/ast/src/ast.rs`. The "predicate" is `test`, not `cond`;
    // `if_cond` is the optional `if <expr>` gate; `msg` is the
    // optional string-literal message.
    public let test: NodeRef<Expr>
    public let ifCond: NodeRef<Expr>?
    public let msg: NodeRef<String>?
}

// MARK: - Type variants

public struct AnyType: Sendable {}

public struct BasicType: Sendable {
    public let type: String  // literal type discriminator (always "Basic")
    public let kind: String  // e.g. "str", "int", "bool"
}

public struct ListType: Sendable {
    public let innerType: NodeRef<KclTypeNode>
}

public struct DictType: Sendable {
    public let keyType: NodeRef<KclTypeNode>
    public let valueType: NodeRef<KclTypeNode>
}

public struct SchemaRefType: Sendable {
    public let schemaName: NodeRef<String>
    public let pkgpath: [String]
}

public struct LiteralType: Sendable {
    public let value: LiteralTypeValue
}

public struct FunctionType: Sendable {
    public let params: [NodeRef<KclTypeNode>]
    public let ret: NodeRef<KclTypeNode>
}

public struct UnionType: Sendable {
    public let any: Bool
    public let types: [NodeRef<KclTypeNode>]
}

public struct NamedType: Sendable {
    public let name: NodeRef<Identifier>
}

public struct StrLiteralType: Sendable {
    public let value: String
}

public struct IntLiteralType: Sendable {
    public let value: Int64
}

public struct FloatLiteralType: Sendable {
    public let value: Double
}

public struct BoolLiteralType: Sendable {
    public let value: Bool
}

public struct KeyValueType: Sendable {
    public let key: NodeRef<KclTypeNode>
    public let value: NodeRef<KclTypeNode>
}

// MARK: - Flat DTOs (note A)

public struct Decorator: Sendable {
    // `func` is a Swift reserved keyword — backtick the property name
    // so the wire shape mirrors `Decorator::func` in Rust's `ast.rs`.
    public let `func`: NodeRef<Expr>?
    public let args: [NodeRef<Expr>]
    public let keywords: [NodeRef<Keyword>]
}

public struct SchemaConfig: Sendable {
    public let name: NodeRef<Expr>?
    public let args: [NodeRef<Expr>]
    public let kwargs: [NodeRef<Keyword>]
    public let config: NodeRef<Expr>?
}

public struct ConfigEntry: Sendable {
    public let key: NodeRef<Expr>
    public let value: NodeRef<Expr>
    public let operation: ConfigEntryOperation?
    public let isShorthand: Bool
}

public struct Keyword: Sendable {
    public let arg: NodeRef<Expr>?
    public let value: NodeRef<Expr>
}

public struct Arguments: Sendable {
    public let args: [NodeRef<Expr>]
    public let defaults: [NodeRef<Expr>]
    public let tyList: [NodeRef<KclTypeNode>]
}

public enum MemberOrIndex: Sendable {
    case member(NodeRef<String>)
    case index(NodeRef<Expr>)
}

public struct Target: Sendable {
    public let name: NodeRef<String>
    public let paths: [MemberOrIndex]
    public let pkgpath: String
}

public struct QuantOperation: Sendable {
    public let target: NodeRef<Target>
    public let op: String  // "all", "any", "filter", "map"
    public var name: NodeRef<String> { target.node.name }
}

public struct SchemaIndexSignature: Sendable {
    public let keyType: NodeRef<KclTypeNode>
    public let valueType: NodeRef<KclTypeNode>
}

public struct Identifier: Sendable {
    public let names: [String]
    public let pkgpath: [String]
}

public struct PosOnly: Sendable {}

// MARK: - Operator & literal enums

public enum BinOp: String, Sendable {
    case add = "Add"
    case sub = "Sub"
    case mul = "Mul"
    case div = "Div"
    case floorDiv = "FloorDiv"
    case mod = "Mod"
    case pow = "Pow"
    case bitOr = "BitOr"
    case bitAnd = "BitAnd"
    case bitXor = "BitXor"
    case lShift = "LShift"
    case rShift = "RShift"
    case assign = "Assign"
    case augAssign = "AugAssign"
}

public enum UnaryOp: String, Sendable {
    case uAdd = "UAdd"
    case uSub = "USub"
    case invert = "Invert"
    case not = "Not"
}

public enum CmpOp: String, Sendable {
    case eq = "Eq"
    case notEq = "NotEq"
    case lt = "Lt"
    case ltE = "LtE"
    case gt = "Gt"
    case gtE = "GtE"
    // `is` and `in` are Swift reserved keywords — backtick the case
    // labels. Raw values ("Is" / "In") still match the Rust serde
    // discriminator.
    case `is` = "Is"
    case isNot = "IsNot"
    case `in` = "In"
    case notIn = "NotIn"
}

public enum AugOp: String, Sendable {
    case assign = "Assign"
    case add = "Add"
    case sub = "Sub"
    case mul = "Mul"
    case div = "Div"
    case floorDiv = "FloorDiv"
    case mod = "Mod"
    case pow = "Pow"
    case bitOr = "BitOr"
    case bitAnd = "BitAnd"
    case bitXor = "BitXor"
    case lShift = "LShift"
    case rShift = "RShift"
}

public enum ConfigEntryOperation: String, Sendable {
    case union = "Union"
    case override = "Override"
}

public enum ExprContext: String, Sendable {
    case load = "Load"
    case store = "Store"
    case del = "Del"
}

public enum NameConstant: String, Sendable {
    case `true` = "True"
    case `false` = "False"
    case none = "None"
    case undefined = "Undefined"
}

public enum NumberBinarySuffix: String, Sendable {
    case none = ""
    case i = "I"
    case m = "M"
    case k = "K"
    case mi = "Mi"
    case g = "G"
    case gi = "Gi"
    case t = "T"
    case ti = "Ti"
}

public struct NumberLitValue: Sendable {
    public let rawValue: String
    public let value: Double
    public let binarySuffix: NumberBinarySuffix?
}

public enum LiteralTypeValue: Sendable {
    case string(String)
    case int(Int64)
    case float(Double)
    case bool(Bool)
}
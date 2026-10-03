// AstJson.swift — Parser for the typed AST JSON shape.
//
// Parses the `astJson` string returned by `ParseFileResult` /
// `ParseProgramResult` into the typed AST in `Pos.swift`. The wire contract
// and the three serde shapes it comes from are documented at the top of
// `Pos.swift`; the short version is:
//
//   * `Stmt` / `Expr` — `#[serde(tag = "type")]`. Read the tag, then hand
//     the **same object** to the variant: the newtype variant's struct
//     fields are flattened next to the tag, not nested under a key.
//   * `Type` — `#[serde(tag = "type", content = "value")]`. Read the tag,
//     then hand `dict["value"]` to the variant. `Any` is the one variant
//     with no `value` key at all.
//   * `MemberOrIndex`, `NumberLitValue` and `LiteralType` are themselves
//     adjacently tagged, the last one nested inside `Type::Literal`.
//
// We parse with `JSONSerialization` into `[String: Any]` and walk the dict
// tree by hand rather than writing a custom `Codable` polymorphic decoder —
// Rust-style internally tagged enums have no `Codable` equivalent, so any
// approach ends up hand-writing the same dispatch.
//
// An unrecognised tag decodes to `.unknown(type:)` rather than throwing.
// That is deliberate: a newer parser emitting a variant this build predates
// would otherwise fail to load the whole module. It does mean a *typo'd*
// tag fails silently, which is why `AstContractTests` walks the tree and
// asserts nothing is left unresolved.

import Foundation

public enum AstJsonError {
    case notADictionary(String)
    case missingField(field: String, container: String)
    case invalidJSON(String)
}

extension AstJsonError: Error {}

extension AstJsonError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notADictionary(let container):
            return "expected JSON object at \(container)"
        case .missingField(let field, let container):
            return "missing field `\(field)` in \(container)"
        case .invalidJSON(let message):
            return "invalid JSON: \(message)"
        }
    }
}

// MARK: - Entry points

/// Parse the `astJson` field of a `ParseFileResult` into a typed `Module`.
public func parseModule(_ astJson: String) throws -> Module {
    guard let dict = try jsonObject(astJson) as? [String: Any] else {
        throw AstJsonError.notADictionary("ast_json root")
    }
    return try parseModuleObject(dict)
}

/// Parse the `astJson` field of a `ParseProgramResult`.
///
/// The wire is `{"root": ".", "pkgs": {"__main__": [Module, …]}}`; an older
/// Rust ABI emitted a bare `[Module, …]`, so both are accepted. Only the
/// `__main__` package is returned — use `parseProgramEnvelope` to reach the
/// imported packages.
public func parseProgram(_ astJson: String) throws -> [Module] {
    try parseProgramEnvelope(astJson).mainPackage
}

/// As `parseProgram`, but keeping the package map for callers that care
/// about the imported packages.
public func parseProgramEnvelope(_ astJson: String) throws -> Program {
    let root = try jsonObject(astJson)
    if let modules = root as? [[String: Any]] {
        let parsed = try modules.map(parseModuleObject)
        return Program(root: ".", mainPackage: parsed, pkgs: ["__main__": parsed])
    }
    guard let dict = root as? [String: Any] else {
        throw AstJsonError.notADictionary("ast_json root")
    }
    guard let pkgs = dict["pkgs"] as? [String: Any] else {
        throw AstJsonError.missingField(field: "pkgs", container: "program envelope")
    }
    var parsed: [String: [Module]] = [:]
    for (name, value) in pkgs {
        guard let list = value as? [[String: Any]] else { continue }
        parsed[name] = try list.map(parseModuleObject)
    }
    return Program(
        root: dict["root"] as? String ?? ".",
        mainPackage: parsed["__main__"] ?? [],
        pkgs: parsed
    )
}

private func jsonObject(_ json: String) throws -> Any {
    do {
        return try JSONSerialization.jsonObject(with: Data(json.utf8), options: [])
    } catch {
        throw AstJsonError.invalidJSON("\(error)")
    }
}

// MARK: - Primitives

private func parseModuleObject(_ dict: [String: Any]) throws -> Module {
    let filename = try string(dict, "filename", "module")
    return Module(
        filename: filename,
        doc: dict["doc"].flatMap(stringNode),
        body: nodeRefList(dict["body"], stmt),
        comments: nodeRefList(dict["comments"], comment)
    )
}

private func string(_ dict: [String: Any], _ key: String, _ container: String) throws -> String {
    guard let value = dict[key] as? String else {
        throw AstJsonError.missingField(field: key, container: container)
    }
    return value
}

private func bool(_ value: Any?, _ fallback: Bool = false) -> Bool {
    (value as? Bool) ?? fallback
}

private func int(_ value: Any?) -> Int64? {
    if let number = value as? NSNumber { return number.int64Value }
    return nil
}

private func double(_ value: Any?) -> Double? {
    if let number = value as? NSNumber { return number.doubleValue }
    return nil
}

/// `NodeRef<T>` — a `{"node": …, filename, line, …}` wrapper.
///
/// The loader is handed the *unwrapped* `node` payload, so a polymorphic
/// payload reaches `stmt` / `expr` / `kclType` with its `"type"` tag at the
/// top level. Primitive payloads use `stringNode` below instead, because
/// there the `node` key holds a bare string rather than an object.
private func nodeRef<T>(_ any: Any?, _ load: ([String: Any]) -> T) -> NodeRef<T>? {
    guard let wrapper = any as? [String: Any],
          let payload = wrapper["node"] as? [String: Any]
    else { return nil }
    return NodeRef(node: load(payload), position: position(wrapper), id: identifier(wrapper))
}

/// `Vec<Node<String>>` — a list of string nodes, e.g. the segments of
/// `Identifier.names`. Each element still carries its own position, so this
/// cannot go through `nodeRefList`, whose loader expects a dictionary.
private func stringNodeList(_ any: Any?) -> [NodeRef<String>] {
    guard let array = any as? [Any] else { return [] }
    return array.compactMap(stringNode)
}

/// A `NodeRef<String>` — `Node<String>` holds a bare string in `node`.
private func stringNode(_ any: Any?) -> NodeRef<String>? {
    guard let wrapper = any as? [String: Any],
          let text = wrapper["node"] as? String
    else { return nil }
    return NodeRef(node: text, position: position(wrapper), id: identifier(wrapper))
}

private func nodeRefList<T>(_ any: Any?, _ load: ([String: Any]) -> T) -> [NodeRef<T>] {
    guard let array = any as? [Any] else { return [] }
    return array.compactMap { nodeRef($0, load) }
}

/// `Vec<Option<NodeRef<T>>>` — used for `Arguments.defaults` and
/// `Arguments.tyList`, both index-aligned with `Arguments.args`. Dropping a
/// positional null would shift every later annotation onto the wrong
/// parameter, so the nulls have to survive as `nil` entries.
private func optionalNodeRefList<T>(_ any: Any?, _ load: ([String: Any]) -> T) -> [NodeRef<T>?] {
    guard let array = any as? [Any] else { return [] }
    return array.map { nodeRef($0, load) }
}

/// The five `Pos` fields sit directly on the wrapper, not under a
/// `"position"` key.
private func position(_ wrapper: [String: Any]) -> Pos? {
    guard wrapper["filename"] is String else { return nil }
    return Pos(
        filename: wrapper["filename"] as? String ?? "",
        line: int(wrapper["line"]) ?? 0,
        column: int(wrapper["column"]) ?? 0,
        endLine: int(wrapper["end_line"]) ?? 0,
        endColumn: int(wrapper["end_column"]) ?? 0
    )
}

private func identifier(_ wrapper: [String: Any]) -> String? {
    if let text = wrapper["id"] as? String { return text }
    if let number = int(wrapper["id"]) { return String(number) }
    return nil
}

/// A wire string → one of the Rust enums, falling back when the key is
/// absent or carries a spelling this build doesn't know. Every operator and
/// context field on the wire is a bare variant name, so this is the single
/// place that conversion happens.
private func enumValue<T: RawRepresentable>(_ value: Any?, _ fallback: T) -> T where T.RawValue == String {
    (value as? String).flatMap(T.init(rawValue:)) ?? fallback
}

private func comment(_ dict: [String: Any]) -> Comment {
    Comment(text: dict["text"] as? String ?? "")
}

// MARK: - Shared DTOs

private func identifierFrom(_ dict: [String: Any]) -> Identifier {
    Identifier(
        names: stringNodeList(dict["names"]),
        pkgpath: dict["pkgpath"] as? String ?? "",
        ctx: enumValue(dict["ctx"], ExprContext.load)
    )
}

private func target(_ dict: [String: Any]) -> Target {
    Target(
        name: stringNode(dict["name"]) ?? NodeRef(node: ""),
        paths: (dict["paths"] as? [Any] ?? []).compactMap(memberOrIndex),
        pkgpath: dict["pkgpath"] as? String ?? ""
    )
}

private func memberOrIndex(_ any: Any) -> MemberOrIndex? {
    guard let dict = any as? [String: Any], let tag = dict["type"] as? String else { return nil }
    switch tag {
    case "Member": return .member(stringNode(dict["value"]) ?? NodeRef(node: ""))
    case "Index": return .index(nodeRef(dict["value"], expr) ?? NodeRef(node: .missing(MissingExpr())))
    default: return nil
    }
}

private func keyword(_ dict: [String: Any]) -> Keyword {
    Keyword(
        arg: nodeRef(dict["arg"], identifierFrom) ?? NodeRef(node: Identifier(names: [])),
        value: dict["value"].flatMap { nodeRef($0, expr) }
    )
}

private func arguments(_ dict: [String: Any]) -> Arguments {
    Arguments(
        args: nodeRefList(dict["args"], identifierFrom),
        defaults: optionalNodeRefList(dict["defaults"], expr),
        tyList: optionalNodeRefList(dict["ty_list"], kclType)
    )
}

private func checkExpr(_ dict: [String: Any]) -> CheckExpr {
    CheckExpr(
        test: nodeRef(dict["test"], expr) ?? NodeRef(node: .missing(MissingExpr())),
        ifCond: dict["if_cond"].flatMap { nodeRef($0, expr) },
        msg: dict["msg"].flatMap { nodeRef($0, expr) }
    )
}

private func compClause(_ dict: [String: Any]) -> CompClause {
    CompClause(
        targets: nodeRefList(dict["targets"], identifierFrom),
        iter: nodeRef(dict["iter"], expr) ?? NodeRef(node: .missing(MissingExpr())),
        ifs: nodeRefList(dict["ifs"], expr)
    )
}

private func callExpr(_ dict: [String: Any]) -> CallExpr {
    CallExpr(
        func: nodeRef(dict["func"], expr) ?? NodeRef(node: .missing(MissingExpr())),
        args: nodeRefList(dict["args"], expr),
        keywords: nodeRefList(dict["keywords"], keyword)
    )
}

private func configEntry(_ dict: [String: Any]) -> ConfigEntry {
    ConfigEntry(
        key: dict["key"].flatMap { nodeRef($0, expr) },
        value: nodeRef(dict["value"], expr) ?? NodeRef(node: .missing(MissingExpr())),
        operation: enumValue(dict["operation"], ConfigEntryOperation.union),
        isShorthand: bool(dict["is_shorthand"])
    )
}

private func schemaExpr(_ dict: [String: Any]) -> SchemaExpr {
    SchemaExpr(
        name: nodeRef(dict["name"], identifierFrom) ?? NodeRef(node: Identifier(names: [])),
        args: nodeRefList(dict["args"], expr),
        keywords: nodeRefList(dict["kwargs"], keyword),
        config: nodeRef(dict["config"], expr) ?? NodeRef(node: .config(ConfigExpr(items: [])))
    )
}

private func schemaIndexSignature(_ dict: [String: Any]) -> SchemaIndexSignature {
    SchemaIndexSignature(
        keyName: dict["key_name"].flatMap(stringNode),
        value: dict["value"].flatMap { nodeRef($0, expr) },
        anyOther: bool(dict["any_other"]),
        keyTy: nodeRef(dict["key_ty"], kclType) ?? NodeRef(node: .any(AnyType())),
        valueTy: nodeRef(dict["value_ty"], kclType) ?? NodeRef(node: .any(AnyType()))
    )
}

// MARK: - Stmt dispatch

func stmt(_ dict: [String: Any]) -> Stmt {
    guard let tag = dict["type"] as? String else { return .unknown(type: "") }
    switch tag {
    case "TypeAlias":
        return .typeAlias(TypeAliasStmt(
            typeName: nodeRef(dict["type_name"], identifierFrom) ?? NodeRef(node: Identifier(names: [])),
            typeValue: stringNode(dict["type_value"]) ?? NodeRef(node: ""),
            ty: nodeRef(dict["ty"], kclType) ?? NodeRef(node: .any(AnyType()))
        ))
    case "Expr":
        return .expr(ExprStmt(exprs: nodeRefList(dict["exprs"], expr)))
    case "Unification":
        return .unification(UnificationStmt(
            target: nodeRef(dict["target"], identifierFrom) ?? NodeRef(node: Identifier(names: [])),
            value: nodeRef(dict["value"], schemaExpr) ?? NodeRef(node: schemaExpr([:]))
        ))
    case "Assign":
        return .assign(AssignStmt(
            targets: nodeRefList(dict["targets"], target),
            value: nodeRef(dict["value"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            ty: dict["ty"].flatMap { nodeRef($0, kclType) }
        ))
    case "AugAssign":
        return .augAssign(AugAssignStmt(
            target: nodeRef(dict["target"], target) ?? NodeRef(node: target([:])),
            value: nodeRef(dict["value"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            op: enumValue(dict["op"], AugOp.assign)
        ))
    case "Assert":
        return .assert(AssertStmt(
            test: nodeRef(dict["test"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            ifCond: dict["if_cond"].flatMap { nodeRef($0, expr) },
            msg: dict["msg"].flatMap { nodeRef($0, expr) }
        ))
    case "If":
        return .if(IfStmt(
            body: nodeRefList(dict["body"], stmt),
            cond: nodeRef(dict["cond"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            orelse: nodeRefList(dict["orelse"], stmt)
        ))
    case "Import":
        return .import(ImportStmt(
            path: stringNode(dict["path"]) ?? NodeRef(node: ""),
            rawpath: dict["rawpath"] as? String ?? "",
            name: dict["name"] as? String ?? "",
            asname: dict["asname"].flatMap(stringNode),
            pkgName: dict["pkg_name"] as? String ?? ""
        ))
    case "SchemaAttr":
        return .schemaAttr(SchemaAttr(
            doc: dict["doc"] as? String ?? "",
            name: stringNode(dict["name"]) ?? NodeRef(node: ""),
            op: enumValue(dict["op"], AugOp.assign),
            value: dict["value"].flatMap { nodeRef($0, expr) },
            isOptional: bool(dict["is_optional"]),
            decorators: nodeRefList(dict["decorators"], callExpr),
            ty: nodeRef(dict["ty"], kclType) ?? NodeRef(node: .any(AnyType()))
        ))
    case "Schema":
        return .schema(SchemaStmt(
            doc: dict["doc"].flatMap(stringNode),
            name: stringNode(dict["name"]) ?? NodeRef(node: ""),
            parentName: dict["parent_name"].flatMap { nodeRef($0, identifierFrom) },
            forHostName: dict["for_host_name"].flatMap { nodeRef($0, identifierFrom) },
            isMixin: bool(dict["is_mixin"]),
            isProtocol: bool(dict["is_protocol"]),
            args: dict["args"].flatMap { nodeRef($0, arguments) },
            mixins: nodeRefList(dict["mixins"], identifierFrom),
            body: nodeRefList(dict["body"], stmt),
            decorators: nodeRefList(dict["decorators"], callExpr),
            checks: nodeRefList(dict["checks"], checkExpr),
            indexSignature: dict["index_signature"].flatMap { nodeRef($0, schemaIndexSignature) }
        ))
    case "Rule":
        return .rule(RuleStmt(
            doc: dict["doc"].flatMap(stringNode),
            name: stringNode(dict["name"]) ?? NodeRef(node: ""),
            parentRules: nodeRefList(dict["parent_rules"], identifierFrom),
            decorators: nodeRefList(dict["decorators"], callExpr),
            checks: nodeRefList(dict["checks"], checkExpr),
            args: dict["args"].flatMap { nodeRef($0, arguments) },
            forHostName: dict["for_host_name"].flatMap { nodeRef($0, identifierFrom) }
        ))
    default:
        return .unknown(type: tag)
    }
}

// MARK: - Expr dispatch

func expr(_ dict: [String: Any]) -> Expr {
    guard let tag = dict["type"] as? String else { return .unknown(type: "") }
    switch tag {
    case "Target": return .target(target(dict))
    case "Identifier": return .identifier(identifierFrom(dict))
    case "Unary":
        return .unary(UnaryExpr(
            op: enumValue(dict["op"], UnaryOp.uAdd),
            operand: nodeRef(dict["operand"], expr) ?? NodeRef(node: .missing(MissingExpr()))
        ))
    case "Binary":
        return .binary(BinaryExpr(
            left: nodeRef(dict["left"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            op: enumValue(dict["op"], BinOp.add),
            right: nodeRef(dict["right"], expr) ?? NodeRef(node: .missing(MissingExpr()))
        ))
    case "If":
        return .if(IfExpr(
            body: nodeRef(dict["body"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            cond: nodeRef(dict["cond"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            orelse: nodeRef(dict["orelse"], expr) ?? NodeRef(node: .missing(MissingExpr()))
        ))
    case "Selector":
        return .selector(SelectorExpr(
            value: nodeRef(dict["value"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            attr: nodeRef(dict["attr"], identifierFrom) ?? NodeRef(node: Identifier(names: [])),
            ctx: enumValue(dict["ctx"], ExprContext.load),
            hasQuestion: bool(dict["has_question"])
        ))
    case "Call": return .call(callExpr(dict))
    case "Paren":
        return .paren(ParenExpr(expr: nodeRef(dict["expr"], expr) ?? NodeRef(node: .missing(MissingExpr()))))
    case "Quant":
        return .quant(QuantExpr(
            target: nodeRef(dict["target"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            variables: nodeRefList(dict["variables"], identifierFrom),
            op: enumValue(dict["op"], QuantOperation.all),
            test: nodeRef(dict["test"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            ifCond: dict["if_cond"].flatMap { nodeRef($0, expr) },
            ctx: enumValue(dict["ctx"], ExprContext.load)
        ))
    case "List":
        return .list(ListExpr(
            elts: nodeRefList(dict["elts"], expr),
            ctx: enumValue(dict["ctx"], ExprContext.load)
        ))
    case "ListIfItem":
        return .listIfItem(ListIfItemExpr(
            ifCond: nodeRef(dict["if_cond"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            exprs: nodeRefList(dict["exprs"], expr),
            orelse: dict["orelse"].flatMap { nodeRef($0, expr) }
        ))
    case "ListComp":
        return .listComp(ListComp(
            elt: nodeRef(dict["elt"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            generators: nodeRefList(dict["generators"], compClause)
        ))
    case "Starred":
        return .starred(StarredExpr(
            value: nodeRef(dict["value"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            ctx: enumValue(dict["ctx"], ExprContext.load)
        ))
    case "DictComp":
        return .dictComp(DictComp(
            entry: configEntry(dict["entry"] as? [String: Any] ?? [:]),
            generators: nodeRefList(dict["generators"], compClause)
        ))
    case "ConfigIfEntry":
        return .configIfEntry(ConfigIfEntryExpr(
            ifCond: nodeRef(dict["if_cond"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            items: nodeRefList(dict["items"], configEntry),
            orelse: dict["orelse"].flatMap { nodeRef($0, expr) }
        ))
    case "CompClause": return .compClause(compClause(dict))
    case "Schema": return .schema(schemaExpr(dict))
    case "Config": return .config(ConfigExpr(items: nodeRefList(dict["items"], configEntry)))
    case "Check": return .check(checkExpr(dict))
    case "Lambda":
        return .lambda(LambdaExpr(
            args: dict["args"].flatMap { nodeRef($0, arguments) },
            body: nodeRefList(dict["body"], stmt),
            returnTy: dict["return_ty"].flatMap { nodeRef($0, kclType) }
        ))
    case "Subscript":
        return .subscript(Subscript(
            value: nodeRef(dict["value"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            index: dict["index"].flatMap { nodeRef($0, expr) },
            lower: dict["lower"].flatMap { nodeRef($0, expr) },
            upper: dict["upper"].flatMap { nodeRef($0, expr) },
            step: dict["step"].flatMap { nodeRef($0, expr) },
            ctx: enumValue(dict["ctx"], ExprContext.load),
            hasQuestion: bool(dict["has_question"])
        ))
    case "Keyword": return .keyword(keyword(dict))
    case "Arguments": return .arguments(arguments(dict))
    case "Compare":
        return .compare(Compare(
            left: nodeRef(dict["left"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            ops: (dict["ops"] as? [String] ?? []).compactMap(CmpOp.init(rawValue:)),
            comparators: nodeRefList(dict["comparators"], expr)
        ))
    case "NumberLit":
        return .numberLit(NumberLit(
            binarySuffix: (dict["binary_suffix"] as? String).flatMap(NumberBinarySuffix.init(rawValue:)),
            value: numberLitValue(dict["value"] as? [String: Any] ?? [:])
        ))
    case "StringLit":
        return .stringLit(StringLit(
            isLongString: bool(dict["is_long_string"]),
            rawValue: dict["raw_value"] as? String ?? "",
            value: dict["value"] as? String ?? ""
        ))
    case "NameConstantLit":
        return .nameConstantLit(NameConstantLit(
            value: enumValue(dict["value"], NameConstant.undefined)
        ))
    case "JoinedString":
        return .joinedString(JoinedString(
            isLongString: bool(dict["is_long_string"]),
            values: nodeRefList(dict["values"], expr),
            rawValue: dict["raw_value"] as? String ?? ""
        ))
    case "FormattedValue":
        return .formattedValue(FormattedValue(
            isLongString: bool(dict["is_long_string"]),
            value: nodeRef(dict["value"], expr) ?? NodeRef(node: .missing(MissingExpr())),
            formatSpec: dict["format_spec"] as? String
        ))
    case "Missing": return .missing(MissingExpr())
    default: return .unknown(type: tag)
    }
}

private func numberLitValue(_ dict: [String: Any]) -> NumberLitValue {
    switch dict["type"] as? String {
    case "Float": return .float(double(dict["value"]) ?? 0)
    default: return .int(int(dict["value"]) ?? 0)
    }
}

// MARK: - Type dispatch

/// `Type` is adjacently tagged, so unlike `stmt` / `expr` the payload comes
/// out of `dict["value"]` rather than off the top level. The payload is
/// deliberately kept as `Any` rather than forced to a dictionary:
/// `BasicType` is a fieldless enum, so its payload is the bare string
/// `"Int"`, and `Any` is a unit variant that has no `value` key at all.
func kclType(_ dict: [String: Any]) -> KclTypeNode {
    guard let tag = dict["type"] as? String else { return .unknown(type: "") }
    guard let raw = dict["value"] else { return .any(AnyType()) }
    let payload = raw as? [String: Any] ?? [:]
    switch tag {
    case "Named":
        // `Named(Identifier)` is a newtype, so the identifier is inlined
        // into `value` with no extra wrapper key.
        return .named(identifierFrom(payload))
    case "Basic":
        return .basic(enumValue(raw, BasicType.bool))
    case "List":
        return .list(ListType(innerType: payload["inner_type"].flatMap { nodeRef($0, kclType) }))
    case "Dict":
        return .dict(DictType(
            keyType: payload["key_type"].flatMap { nodeRef($0, kclType) },
            valueType: payload["value_type"].flatMap { nodeRef($0, kclType) }
        ))
    case "Union":
        // The Rust field is `type_elements`, not `types`.
        return .union(UnionType(typeElements: nodeRefList(payload["type_elements"], kclType)))
    case "Literal":
        return .literal(LiteralType(value: literalTypeValue(payload)))
    case "Function":
        return .function(FunctionType(
            paramsTy: payload["params_ty"].flatMap { optionalNodeRefList($0, kclType).compactMap { $0 } },
            retTy: payload["ret_ty"].flatMap { nodeRef($0, kclType) }
        ))
    default:
        return .unknown(type: tag)
    }
}

/// `LiteralType` is itself `tag + content`, so `Type::Literal`'s `value` is
/// a second tagged document. `Int` is the odd one out: its payload is a
/// newtype, so it is inlined as `{"value": 1, "suffix": null}` rather than
/// nested under another key.
private func literalTypeValue(_ dict: [String: Any]) -> LiteralTypeValue {
    switch dict["type"] as? String {
    case "Int":
        return .int(IntLiteralType(
            value: int((dict["value"] as? [String: Any])?["value"]) ?? 0,
            suffix: ((dict["value"] as? [String: Any])?["suffix"] as? String)
                .flatMap(NumberBinarySuffix.init(rawValue:))
        ))
    case "Float": return .float(double(dict["value"]) ?? 0)
    case "Bool": return .bool((dict["value"] as? NSNumber)?.boolValue ?? false)
    default: return .str(dict["value"] as? String ?? "")
    }
}

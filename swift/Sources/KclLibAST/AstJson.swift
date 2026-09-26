// AstJson.swift — Parser for the typed AST JSON shape.
//
// Parses the `ast_json` string returned by `ParseFileResult.astJson` /
// `ParseProgramResult.astJson` into the typed AST structs defined in
// `Pos.swift`. Wire shape follows `kcl-lang/kcl crates/ast/src/ast.rs`
// plus the flat DTOs (`Decorator`, `SchemaConfig`, `ConfigEntry`,
// `Keyword`, `Arguments`, `MemberOrIndex`, `Target`) where the
// `NodeRef<T>` payload lacks the polymorphic `"type"` discriminator
// (see AST_DRIFT.md note A).
//
// We parse with `JSONSerialization` into `[String: Any]` and then walk
// the dict tree, dispatching each `Stmt` / `Expr` / `Type` on its
// `"type"` discriminator. This avoids the heavyweight alternative of
// writing a custom `Codable` polymorphic decoder for Rust-style tagged
// enums — the same approach Swift's serde bridges tend to take.

import Foundation

// AstJsonError is declared as a plain enum (no raw type, no protocol
// conformances inline) because the Swift compiler interprets
// `enum X: Error` as trying to make `Error` a raw type when case
// payloads carry associated values — declaring the conformances via
// extensions below avoids the "raw type 'Error' is not expressible
// by a string, integer, or floating-point literal" error.
public enum AstJsonError {
    case notADictionary(String)
    case missingField(field: String, container: String)
    case wrongType(field: String, expected: String, got: String)
    case unknownStmtType(String)
    case unknownExprType(String)
    case unknownTypeKind(String)
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
        case .wrongType(let field, let expected, let got):
            return "field `\(field)` expected \(expected), got \(got)"
        case .unknownStmtType(let t):
            return "unknown stmt type: \(t)"
        case .unknownExprType(let t):
            return "unknown expr type: \(t)"
        case .unknownTypeKind(let t):
            return "unknown type kind: \(t)"
        case .invalidJSON(let msg):
            return "invalid JSON: \(msg)"
        }
    }
}

/// Parse the `ast_json` field of `ParseFileResult` into a typed `Module`.
public func parseModule(_ astJson: String) throws -> Module {
    let data = Data(astJson.utf8)
    let root: Any
    do {
        root = try JSONSerialization.jsonObject(with: data, options: [])
    } catch {
        throw AstJsonError.invalidJSON("\(error)")
    }
    guard let dict = root as? [String: Any] else {
        throw AstJsonError.notADictionary("ast_json root")
    }
    return try parseModule(dict)
}

/// Parse the `ast_json` field of `ParseProgramResult` into a list of
/// typed `Module`s. The wire shape is either `[Module, …]` (older
/// rustc ABI) or `{"root": ".", "pkgs": {"__main__": [Module, …]}}`.
/// We read both shapes and return the `__main__` package's modules.
public func parseProgram(_ astJson: String) throws -> [Module] {
    let data = Data(astJson.utf8)
    let root: Any
    do {
        root = try JSONSerialization.jsonObject(with: data, options: [])
    } catch {
        throw AstJsonError.invalidJSON("\(error)")
    }
    if let modules = root as? [[String: Any]] {
        return try modules.map { try parseModule($0) }
    }
    guard let dict = root as? [String: Any] else {
        throw AstJsonError.notADictionary("ast_json root")
    }
    guard let pkgs = dict["pkgs"] as? [String: [[String: Any]]] else {
        throw AstJsonError.missingField(field: "pkgs", container: "program envelope")
    }
    let mainModules = pkgs["__main__"] ?? []
    return try mainModules.map { try parseModule($0) }
}

// MARK: - Parsing helpers

/// Parse a `Module` from a `[String: Any]`. Mirror of the Python
/// `moduleFromWire`, Node.js `moduleFromWire`, .NET `Module.FromWire`,
/// WASM `moduleFromWire`.
func parseModule(_ dict: [String: Any]) throws -> Module {
    let filename = try requireString(dict, "filename", container: "module")
    let doc = dict["doc"].flatMap { parseNodeRef($0, load: parseStringNode, label: "doc") }
    let body = (dict["body"] as? [[String: Any]] ?? []).map { item in
        parseNodeRef(item, load: parseStmt, label: "body")!
    }
    let comments = (dict["comments"] as? [[String: Any]] ?? []).map { item in
        parseNodeRef(item, load: parseComment, label: "comments")!
    }
    return Module(filename: filename, doc: doc, body: body, comments: comments)
}

func parsePos(_ dict: [String: Any]) throws -> Pos {
    return Pos(
        filename: try requireString(dict, "filename", container: "Pos"),
        line: try requireInt(dict, "line", container: "Pos"),
        column: try requireInt(dict, "column", container: "Pos"),
        endLine: try requireInt(dict, "end_line", container: "Pos"),
        endColumn: try requireInt(dict, "end_column", container: "Pos")
    )
}

func parseStringNode(_ dict: [String: Any]) -> String {
    return (dict["node"] as? String) ?? ""
}

func parseComment(_ dict: [String: Any]) -> Comment {
    let text = (dict["node"] as? String) ?? ""
    let pos = (dict["filename"] as? String).flatMap { _ in try? parsePos(dict) }
    return Comment(node: text, position: pos)
}

func parseNodeRef<T>(_ any: Any, load: ([String: Any]) -> T, label: String) -> NodeRef<T>? {
    guard let dict = any as? [String: Any] else { return nil }
    // The NodeRef wrapper looks like `{node: <T>, filename, line, ...}`.
    // For polymorphic payloads (Stmt / Expr / KclTypeNode), `node` is a
    // dict carrying the `"type"` discriminator — unwrap one level so the
    // loader sees the type tag at the top. For primitive payloads
    // (String, Int, …), `node` is the value itself — pass the outer
    // dict so loaders like `parseStringNode` can pull `dict["node"]`.
    let payload: [String: Any]
    if let inner = dict["node"] as? [String: Any] {
        payload = inner
    } else {
        payload = dict
    }
    let node = load(payload)
    let pos = (dict["filename"] as? String).flatMap { _ in try? parsePos(dict) }
    let id = dict["id"] as? String
    return NodeRef(node: node, position: pos, id: id)
}

func parseNodeRefList<T>(_ any: Any, load: ([String: Any]) -> T, label: String) -> [NodeRef<T>] {
    guard let arr = any as? [[String: Any]] else { return [] }
    return arr.compactMap { parseNodeRef($0, load: load, label: label) }
}

func parseNodeRefDict<T>(_ any: Any, load: ([String: Any]) -> T, label: String) -> [String: NodeRef<T>] {
    guard let dict = any as? [String: [String: Any]] else { return [:] }
    var out: [String: NodeRef<T>] = [:]
    for (k, v) in dict {
        if let ref = parseNodeRef(v, load: load, label: label) { out[k] = ref }
    }
    return out
}

func requireString(_ dict: [String: Any], _ key: String, container: String) throws -> String {
    guard let v = dict[key] as? String else {
        throw AstJsonError.missingField(field: key, container: container)
    }
    return v
}

func requireBool(_ dict: [String: Any], _ key: String, container: String = "", default defaultValue: Bool = false) -> Bool {
    if let v = dict[key] as? Bool { return v }
    return defaultValue
}

func requireInt(_ dict: [String: Any], _ key: String, container: String) throws -> Int64 {
    if let v = dict[key] as? Int64 { return v }
    if let v = dict[key] as? Int { return Int64(v) }
    if let v = dict[key] as? Double { return Int64(v) }
    if let v = dict[key] as? NSNumber { return v.int64Value }
    throw AstJsonError.missingField(field: key, container: container)
}

func requireDouble(_ dict: [String: Any], _ key: String, container: String) throws -> Double {
    if let v = dict[key] as? Double { return v }
    if let v = dict[key] as? Int { return Double(v) }
    if let v = dict[key] as? Int64 { return Double(v) }
    if let v = dict[key] as? NSNumber { return v.doubleValue }
    throw AstJsonError.missingField(field: key, container: container)
}

func optionalInt(_ dict: [String: Any], _ key: String) -> Int64? {
    if let v = dict[key] as? Int64 { return v }
    if let v = dict[key] as? Int { return Int64(v) }
    if let v = dict[key] as? NSNumber { return v.int64Value }
    return nil
}

// MARK: - Stmt dispatch

func parseStmt(_ dict: [String: Any]) -> Stmt {
    guard let t = dict["type"] as? String else { return .unknown(type: "") }
    do {
        switch t {
        case "Expr":        return .expr(try parseExprStmt(dict))
        case "Unification": return .unification(try parseUnificationStmt(dict))
        case "Assign":      return .assign(try parseAssignStmt(dict))
        case "Schema":      return .schema(try parseSchemaStmt(dict))
        case "SchemaAttr":  return .schemaAttr(try parseSchemaAttr(dict))
        case "Rule":        return .rule(try parseRuleStmt(dict))
        case "Import":      return .import(try parseImportStmt(dict))
        case "TypeAlias":   return .typeAlias(try parseTypeAliasStmt(dict))
        case "Assert":      return .assert(try parseAssertStmt(dict))
        case "If":          return .if(try parseIfStmt(dict))
        default:            return .unknown(type: t)
        }
    } catch {
        return .unknown(type: t)
    }
}

func parseExprStmt(_ dict: [String: Any]) throws -> ExprStmt {
    return ExprStmt(exprs: parseNodeRefList(dict["exprs"], load: parseExpr, label: "ExprStmt.exprs"))
}

func parseUnificationStmt(_ dict: [String: Any]) throws -> UnificationStmt {
    let target: NodeRef<Target> = parseNodeRef(dict["target"], load: parseTarget, label: "UnificationStmt.target")!
    let value: NodeRef<SchemaConfig> = parseNodeRef(dict["value"], load: parseSchemaConfig, label: "UnificationStmt.value")!
    return UnificationStmt(target: target, value: value)
}

func parseAssignStmt(_ dict: [String: Any]) throws -> AssignStmt {
    return AssignStmt(
        targets: parseNodeRefList(dict["targets"], load: parseTarget, label: "AssignStmt.targets"),
        ty: parseNodeRef(dict["ty"], load: parseKclTypeNode, label: "AssignStmt.ty"),
        value: parseNodeRef(dict["value"], load: parseExpr, label: "AssignStmt.value")!
    )
}

func parseSchemaStmt(_ dict: [String: Any]) throws -> SchemaStmt {
    return SchemaStmt(
        doc: parseNodeRef(dict["doc"], load: parseStringNode, label: "SchemaStmt.doc"),
        name: parseNodeRef(dict["name"], load: parseStringNode, label: "SchemaStmt.name")!,
        parentName: parseNodeRef(dict["parent_name"], load: parseIdentifier, label: "SchemaStmt.parent_name"),
        forHostName: parseNodeRef(dict["for_host_name"], load: parseIdentifier, label: "SchemaStmt.for_host_name"),
        isMixin: requireBool(dict, "is_mixin"),
        isProtocol: requireBool(dict, "is_protocol"),
        args: parseNodeRef(dict["args"], load: parseArguments, label: "SchemaStmt.args"),
        mixins: parseNodeRefList(dict["mixins"], load: parseIdentifier, label: "SchemaStmt.mixins"),
        body: parseNodeRefList(dict["body"], load: parseStmt, label: "SchemaStmt.body"),
        decorators: parseNodeRefList(dict["decorators"], load: parseDecorator, label: "SchemaStmt.decorators"),
        checks: parseNodeRefList(dict["checks"], load: parseCheckExpr, label: "SchemaStmt.checks"),
        indexSignature: parseNodeRef(dict["index_signature"], load: parseSchemaIndexSignature, label: "SchemaStmt.index_signature")
    )
}

func parseSchemaAttr(_ dict: [String: Any]) throws -> SchemaAttr {
    return SchemaAttr(
        doc: (dict["doc"] as? String) ?? "",
        name: parseNodeRef(dict["name"], load: parseStringNode, label: "SchemaAttr.name")!,
        op: parseAugOp(dict["op"]),
        value: parseNodeRef(dict["value"], load: parseExpr, label: "SchemaAttr.value"),
        isOptional: requireBool(dict, "is_optional"),
        decorators: parseNodeRefList(dict["decorators"], load: parseDecorator, label: "SchemaAttr.decorators"),
        ty: parseNodeRef(dict["ty"], load: parseKclTypeNode, label: "SchemaAttr.ty")
    )
}

func parseRuleStmt(_ dict: [String: Any]) throws -> RuleStmt {
    return RuleStmt(
        doc: parseNodeRef(dict["doc"], load: parseStringNode, label: "RuleStmt.doc"),
        name: parseNodeRef(dict["name"], load: parseStringNode, label: "RuleStmt.name")!,
        parentRules: parseNodeRefList(dict["parent_rules"], load: parseIdentifier, label: "RuleStmt.parent_rules"),
        decorators: parseNodeRefList(dict["decorators"], load: parseDecorator, label: "RuleStmt.decorators"),
        checks: parseNodeRefList(dict["checks"], load: parseCheckExpr, label: "RuleStmt.checks"),
        args: parseNodeRef(dict["args"], load: parseArguments, label: "RuleStmt.args"),
        forHostName: parseNodeRef(dict["for_host_name"], load: parseIdentifier, label: "RuleStmt.for_host_name")
    )
}

func parseImportStmt(_ dict: [String: Any]) throws -> ImportStmt {
    guard let node = dict["node"] as? [String: Any] else {
        return ImportStmt(path: "", asName: nil, pkgName: nil, pkgRoot: nil)
    }
    return ImportStmt(
        path: (node["path"] as? String) ?? "",
        asName: node["as_name"] as? String,
        pkgName: node["pkg_name"] as? String,
        pkgRoot: node["pkg_root"] as? String
    )
}

func parseTypeAliasStmt(_ dict: [String: Any]) throws -> TypeAliasStmt {
    return TypeAliasStmt(
        name: parseNodeRef(dict["name"], load: parseStringNode, label: "TypeAliasStmt.name")!,
        ty: parseNodeRef(dict["ty"], load: parseKclTypeNode, label: "TypeAliasStmt.ty")!
    )
}

func parseAssertStmt(_ dict: [String: Any]) throws -> AssertStmt {
    return AssertStmt(
        source: parseNodeRef(dict["source"], load: parseExpr, label: "AssertStmt.source")!,
        assertMsg: parseNodeRef(dict["assert_msg"], load: parseStringNode, label: "AssertStmt.assert_msg")
    )
}

func parseIfStmt(_ dict: [String: Any]) throws -> IfStmt {
    return IfStmt(
        cond: parseNodeRef(dict["cond"], load: parseExpr, label: "IfStmt.cond")!,
        body: parseNodeRefList(dict["body"], load: parseStmt, label: "IfStmt.body"),
        orElse: parseNodeRef(dict["or_else"], load: parseExpr, label: "IfStmt.or_else")
    )
}

// MARK: - Expr dispatch

func parseExpr(_ dict: [String: Any]) -> Expr {
    guard let t = dict["type"] as? String else { return .unknown(type: "") }
    do {
        switch t {
        case "Target":          return .target(try parseTargetExpr(dict))
        case "Identifier":      return .identifier(try parseIdentifierExpr(dict))
        case "Unary":           return .unary(try parseUnaryExpr(dict))
        case "Binary":          return .binary(try parseBinaryExpr(dict))
        case "If":              return .ifExpr(try parseIfExpr(dict))
        case "Selector":        return .selector(try parseSelectorExpr(dict))
        case "Call":            return .call(try parseCallExpr(dict))
        case "Paren":           return .paren(try parseParenExpr(dict))
        case "Quant":           return .quant(try parseQuantExpr(dict))
        case "List":            return .list(try parseListExpr(dict))
        case "ListIfItem":      return .listIfItem(try parseListIfItemExpr(dict))
        case "ListComp":        return .listComp(try parseListComp(dict))
        case "Starred":         return .starred(try parseStarredExpr(dict))
        case "DictComp":        return .dictComp(try parseDictComp(dict))
        case "ConfigIfEntry":   return .configIfEntry(try parseConfigIfEntryExpr(dict))
        case "CompClause":      return .compClause(try parseCompClause(dict))
        case "Schema":          return .schema(try parseSchemaExpr(dict))
        case "Config":          return .config(try parseConfigExpr(dict))
        case "Lambda":          return .lambda(try parseLambdaExpr(dict))
        case "Subscript":       return .subscript(try parseSubscript(dict))
        case "Compare":         return .compare(try parseCompare(dict))
        case "NumberLit":       return .numberLit(try parseNumberLit(dict))
        case "StringLit":       return .stringLit(try parseStringLit(dict))
        case "NameConstantLit": return .nameConstantLit(try parseNameConstantLit(dict))
        case "JoinedString":    return .joinedString(try parseJoinedString(dict))
        case "FormattedValue":  return .formattedValue(try parseFormattedValue(dict))
        case "Missing":         return .missing(MissingExpr())
        case "CheckExpr":       return .check(try parseCheckExpr(dict))
        default:                return .unknown(type: t)
        }
    } catch {
        return .unknown(type: t)
    }
}

func parseTargetExpr(_ dict: [String: Any]) throws -> TargetExpr {
    return TargetExpr(name: parseNodeRef(dict["name"], load: parseStringNode, label: "TargetExpr.name")!)
}

func parseIdentifierExpr(_ dict: [String: Any]) throws -> IdentifierExpr {
    return IdentifierExpr(
        names: parseNodeRefList(dict["names"], load: parseStringNode, label: "IdentifierExpr.names"),
        pkgpath: (dict["pkgpath"] as? [String]) ?? []
    )
}

func parseUnaryExpr(_ dict: [String: Any]) throws -> UnaryExpr {
    return UnaryExpr(
        op: parseUnaryOp(dict["op"]),
        operand: parseNodeRef(dict["operand"], load: parseExpr, label: "UnaryExpr.operand")!
    )
}

func parseBinaryExpr(_ dict: [String: Any]) throws -> BinaryExpr {
    return BinaryExpr(
        op: parseBinOp(dict["op"]),
        left: parseNodeRef(dict["left"], load: parseExpr, label: "BinaryExpr.left")!,
        right: parseNodeRef(dict["right"], load: parseExpr, label: "BinaryExpr.right")!
    )
}

func parseIfExpr(_ dict: [String: Any]) throws -> IfExpr {
    return IfExpr(
        cond: parseNodeRef(dict["cond"], load: parseExpr, label: "IfExpr.cond")!,
        body: parseNodeRef(dict["body"], load: parseExpr, label: "IfExpr.body")!,
        orElse: parseNodeRef(dict["or_else"], load: parseExpr, label: "IfExpr.or_else")
    )
}

func parseSelectorExpr(_ dict: [String: Any]) throws -> SelectorExpr {
    return SelectorExpr(
        value: parseNodeRef(dict["value"], load: parseExpr, label: "SelectorExpr.value")!,
        attrName: parseNodeRef(dict["attr_name"], load: parseStringNode, label: "SelectorExpr.attr_name")!
    )
}

func parseCallExpr(_ dict: [String: Any]) throws -> CallExpr {
    return CallExpr(
        func: parseNodeRef(dict["func"], load: parseExpr, label: "CallExpr.func")!,
        args: parseNodeRefList(dict["args"], load: parseExpr, label: "CallExpr.args"),
        keywords: parseNodeRefList(dict["keywords"], load: parseKeyword, label: "CallExpr.keywords")
    )
}

func parseParenExpr(_ dict: [String: Any]) throws -> ParenExpr {
    return ParenExpr(expr: parseNodeRef(dict["expr"], load: parseExpr, label: "ParenExpr.expr")!)
}

func parseQuantExpr(_ dict: [String: Any]) throws -> QuantExpr {
    return QuantExpr(
        target: parseNodeRef(dict["target"], load: parseTarget, label: "QuantExpr.target")!,
        variables: parseNodeRefList(dict["variables"], load: parseQuantOperation, label: "QuantExpr.variables"),
        op: parseQuantOperationAny(dict["op"]),
        cond: parseNodeRef(dict["cond"], load: parseExpr, label: "QuantExpr.cond")!
    )
}

func parseListExpr(_ dict: [String: Any]) throws -> ListExpr {
    return ListExpr(elts: parseNodeRefList(dict["elts"], load: parseExpr, label: "ListExpr.elts"))
}

func parseListIfItemExpr(_ dict: [String: Any]) throws -> ListIfItemExpr {
    return ListIfItemExpr(
        ifExpr: parseNodeRef(dict["if_expr"], load: parseExpr, label: "ListIfItemExpr.if_expr")!,
        orElse: parseNodeRef(dict["or_else"], load: parseExpr, label: "ListIfItemExpr.or_else")
    )
}

func parseListComp(_ dict: [String: Any]) throws -> ListComp {
    return ListComp(
        elt: parseNodeRef(dict["elt"], load: parseExpr, label: "ListComp.elt")!,
        generators: parseNodeRefList(dict["generators"], load: parseCompClause, label: "ListComp.generators"),
        cond: parseNodeRef(dict["cond"], load: parseExpr, label: "ListComp.cond")
    )
}

func parseStarredExpr(_ dict: [String: Any]) throws -> StarredExpr {
    return StarredExpr(
        value: parseNodeRef(dict["value"], load: parseExpr, label: "StarredExpr.value")!,
        ctx: parseExprContext(dict["ctx"])
    )
}

func parseDictComp(_ dict: [String: Any]) throws -> DictComp {
    return DictComp(
        key: parseNodeRef(dict["key"], load: parseExpr, label: "DictComp.key")!,
        value: parseNodeRef(dict["value"], load: parseExpr, label: "DictComp.value")!,
        generators: parseNodeRefList(dict["generators"], load: parseCompClause, label: "DictComp.generators"),
        cond: parseNodeRef(dict["cond"], load: parseExpr, label: "DictComp.cond")
    )
}

func parseConfigIfEntryExpr(_ dict: [String: Any]) throws -> ConfigIfEntryExpr {
    return ConfigIfEntryExpr(ifExpr: parseNodeRef(dict["if_expr"], load: parseExpr, label: "ConfigIfEntryExpr.if_expr")!)
}

// Non-throwing — see `parseCheckExpr` for the same rationale.
func parseCompClause(_ dict: [String: Any]) -> CompClause {
    return CompClause(
        targets: parseNodeRefList(dict["targets"], load: parseTarget, label: "CompClause.targets"),
        iter: parseNodeRef(dict["iter"], load: parseExpr, label: "CompClause.iter")!,
        ifs: parseNodeRefList(dict["ifs"], load: parseExpr, label: "CompClause.ifs")
    )
}

func parseSchemaExpr(_ dict: [String: Any]) throws -> SchemaExpr {
    return SchemaExpr(
        name: parseNodeRef(dict["name"], load: parseExpr, label: "SchemaExpr.name")!,
        args: parseNodeRefList(dict["args"], load: parseExpr, label: "SchemaExpr.args"),
        kwargs: parseNodeRefList(dict["kwargs"], load: parseKeyword, label: "SchemaExpr.kwargs"),
        config: parseNodeRef(dict["config"], load: parseExpr, label: "SchemaExpr.config")!
    )
}

func parseConfigExpr(_ dict: [String: Any]) throws -> ConfigExpr {
    return ConfigExpr(items: parseNodeRefList(dict["items"], load: parseConfigEntry, label: "ConfigExpr.items"))
}

func parseLambdaExpr(_ dict: [String: Any]) throws -> LambdaExpr {
    return LambdaExpr(
        args: parseNodeRef(dict["args"], load: parseArguments, label: "LambdaExpr.args")!,
        body: parseNodeRefList(dict["body"], load: parseStmt, label: "LambdaExpr.body"),
        returnTy: parseNodeRef(dict["return_ty"], load: parseKclTypeNode, label: "LambdaExpr.return_ty")
    )
}

func parseSubscript(_ dict: [String: Any]) throws -> Subscript {
    return Subscript(
        value: parseNodeRef(dict["value"], load: parseExpr, label: "Subscript.value")!,
        index: parseNodeRef(dict["index"], load: parseExpr, label: "Subscript.index")!
    )
}

func parseCompare(_ dict: [String: Any]) throws -> Compare {
    let ops = (dict["ops"] as? [String])?.map { parseCmpOp($0) } ?? []
    return Compare(
        left: parseNodeRef(dict["left"], load: parseExpr, label: "Compare.left")!,
        ops: ops,
        comparators: parseNodeRefList(dict["comparators"], load: parseExpr, label: "Compare.comparators")
    )
}

func parseNumberLit(_ dict: [String: Any]) throws -> NumberLit {
    let binarySuffix: NumberBinarySuffix? = (dict["binary_suffix"] as? String).flatMap { parseBinarySuffix($0) }
    let valueDict = (dict["value"] as? [String: Any]) ?? [:]
    let rawValue = (valueDict["raw_value"] as? String) ?? ""
    let value: Double
    if let v = valueDict["value"] as? Double {
        value = v
    } else if let v = valueDict["value"] as? Int {
        value = Double(v)
    } else if let v = valueDict["value"] as? Int64 {
        value = Double(v)
    } else {
        value = 0
    }
    let valueBinarySuffix = (valueDict["binary_suffix"] as? String).flatMap { parseBinarySuffix($0) }
    return NumberLit(
        binarySuffix: binarySuffix ?? valueBinarySuffix,
        value: NumberLitValue(rawValue: rawValue, value: value, binarySuffix: valueBinarySuffix)
    )
}

func parseStringLit(_ dict: [String: Any]) throws -> StringLit {
    return StringLit(
        isLongString: requireBool(dict, "is_long_string"),
        rawValue: (dict["raw_value"] as? String) ?? "\"\"",
        value: (dict["value"] as? String) ?? ""
    )
}

func parseNameConstantLit(_ dict: [String: Any]) throws -> NameConstantLit {
    let raw = (dict["value"] as? String) ?? "Undefined"
    return NameConstantLit(value: parseNameConstant(raw))
}

func parseJoinedString(_ dict: [String: Any]) throws -> JoinedString {
    return JoinedString(
        values: parseNodeRefList(dict["values"], load: parseExpr, label: "JoinedString.values"),
        isLongString: requireBool(dict, "is_long_string"),
        rawValue: (dict["raw_value"] as? String) ?? ""
    )
}

func parseFormattedValue(_ dict: [String: Any]) throws -> FormattedValue {
    return FormattedValue(
        value: parseNodeRef(dict["value"], load: parseExpr, label: "FormattedValue.value")!,
        spec: dict["spec"] as? String
    )
}

// Non-throwing — all calls go through non-throwing `parseNodeRef`, so the
// body never actually throws. Marking it `throws` would force the
// `parseNodeRefList` call sites in `parseSchemaStmt` / `parseRuleStmt`
// to wrap each element in a do/catch (their `load:` parameter is
// non-throwing).
func parseCheckExpr(_ dict: [String: Any]) -> CheckExpr {
    return CheckExpr(
        test: parseNodeRef(dict["test"], load: parseExpr, label: "CheckExpr.test")!,
        ifCond: parseNodeRef(dict["if_cond"], load: parseExpr, label: "CheckExpr.if_cond"),
        msg: parseNodeRef(dict["msg"], load: parseStringNode, label: "CheckExpr.msg")
    )
}

// MARK: - Type dispatch

func parseKclTypeNode(_ dict: [String: Any]) -> KclTypeNode {
    guard let t = dict["type"] as? String else { return .unknown(type: "") }
    do {
        switch t {
        case "Any":         return .any(try parseAnyType(dict))
        case "Basic":       return .basic(try parseBasicType(dict))
        case "List":        return .list(try parseListType(dict))
        case "Dict":        return .dict(try parseDictType(dict))
        case "SchemaRef":   return .schemaRef(try parseSchemaRefType(dict))
        case "Literal":     return .literal(try parseLiteralType(dict))
        case "Function":    return .function(try parseFunctionType(dict))
        case "Union":       return .union(try parseUnionType(dict))
        case "Named":       return .named(try parseNamedType(dict))
        case "StrLiteral":  return .strLiteral(try parseStrLiteralType(dict))
        case "IntLiteral":  return .intLiteral(try parseIntLiteralType(dict))
        case "FloatLiteral":return .floatLiteral(try parseFloatLiteralType(dict))
        case "BoolLiteral": return .boolLiteral(try parseBoolLiteralType(dict))
        case "KeyValue":    return .keyValue(try parseKeyValueType(dict))
        default:            return .unknown(type: t)
        }
    } catch {
        return .unknown(type: t)
    }
}

func parseAnyType(_ dict: [String: Any]) throws -> AnyType { return AnyType() }

func parseBasicType(_ dict: [String: Any]) throws -> BasicType {
    return BasicType(type: "Basic", kind: (dict["kind"] as? String) ?? "")
}

func parseListType(_ dict: [String: Any]) throws -> ListType {
    return ListType(innerType: parseNodeRef(dict["inner_type"], load: parseKclTypeNode, label: "ListType.inner_type")!)
}

func parseDictType(_ dict: [String: Any]) throws -> DictType {
    return DictType(
        keyType: parseNodeRef(dict["key_type"], load: parseKclTypeNode, label: "DictType.key_type")!,
        valueType: parseNodeRef(dict["value_type"], load: parseKclTypeNode, label: "DictType.value_type")!
    )
}

func parseSchemaRefType(_ dict: [String: Any]) throws -> SchemaRefType {
    return SchemaRefType(
        schemaName: parseNodeRef(dict["schema_name"], load: parseStringNode, label: "SchemaRefType.schema_name")!,
        pkgpath: (dict["pkgpath"] as? [String]) ?? []
    )
}

func parseLiteralType(_ dict: [String: Any]) throws -> LiteralType {
    let raw = dict["value"] as? [String: Any]
    let value: LiteralTypeValue
    if let raw = raw {
        if let s = raw["string"] as? String { value = .string(s) }
        else if let i = raw["int"] as? Int64 { value = .int(i) }
        else if let i = raw["int"] as? Int { value = .int(Int64(i)) }
        else if let f = raw["float"] as? Double { value = .float(f) }
        else if let f = raw["float"] as? Int { value = .float(Double(f)) }
        else if let b = raw["bool"] as? Bool { value = .bool(b) }
        else { value = .string("") }
    } else {
        value = .string("")
    }
    return LiteralType(value: value)
}

func parseFunctionType(_ dict: [String: Any]) throws -> FunctionType {
    return FunctionType(
        params: parseNodeRefList(dict["params"], load: parseKclTypeNode, label: "FunctionType.params"),
        ret: parseNodeRef(dict["ret"], load: parseKclTypeNode, label: "FunctionType.ret")!
    )
}

func parseUnionType(_ dict: [String: Any]) throws -> UnionType {
    return UnionType(
        any: requireBool(dict, "any"),
        types: parseNodeRefList(dict["types"], load: parseKclTypeNode, label: "UnionType.types")
    )
}

func parseNamedType(_ dict: [String: Any]) throws -> NamedType {
    return NamedType(name: parseNodeRef(dict["name"], load: parseIdentifier, label: "NamedType.name")!)
}

func parseStrLiteralType(_ dict: [String: Any]) throws -> StrLiteralType {
    return StrLiteralType(value: (dict["value"] as? String) ?? "")
}

func parseIntLiteralType(_ dict: [String: Any]) throws -> IntLiteralType {
    return IntLiteralType(value: try requireInt(dict, "value", container: "IntLiteralType"))
}

func parseFloatLiteralType(_ dict: [String: Any]) throws -> FloatLiteralType {
    return FloatLiteralType(value: try requireDouble(dict, "value", container: "FloatLiteralType"))
}

func parseBoolLiteralType(_ dict: [String: Any]) throws -> BoolLiteralType {
    return BoolLiteralType(value: requireBool(dict, "value"))
}

func parseKeyValueType(_ dict: [String: Any]) throws -> KeyValueType {
    return KeyValueType(
        key: parseNodeRef(dict["key"], load: parseKclTypeNode, label: "KeyValueType.key")!,
        value: parseNodeRef(dict["value"], load: parseKclTypeNode, label: "KeyValueType.value")!
    )
}

// MARK: - Flat DTOs

func parseDecorator(_ dict: [String: Any]) -> Decorator {
    return Decorator(
        func: parseNodeRef(dict["func"], load: parseExpr, label: "Decorator.func"),
        args: parseNodeRefList(dict["args"], load: parseExpr, label: "Decorator.args"),
        keywords: parseNodeRefList(dict["keywords"], load: parseKeyword, label: "Decorator.keywords")
    )
}

func parseSchemaConfig(_ dict: [String: Any]) -> SchemaConfig {
    return SchemaConfig(
        name: parseNodeRef(dict["name"], load: parseExpr, label: "SchemaConfig.name"),
        args: parseNodeRefList(dict["args"], load: parseExpr, label: "SchemaConfig.args"),
        kwargs: parseNodeRefList(dict["kwargs"], load: parseKeyword, label: "SchemaConfig.kwargs"),
        config: parseNodeRef(dict["config"], load: parseExpr, label: "SchemaConfig.config")
    )
}

func parseConfigEntry(_ dict: [String: Any]) -> ConfigEntry {
    return ConfigEntry(
        key: parseNodeRef(dict["key"], load: parseExpr, label: "ConfigEntry.key")!,
        value: parseNodeRef(dict["value"], load: parseExpr, label: "ConfigEntry.value")!,
        operation: (dict["operation"] as? String).flatMap { parseConfigEntryOperation($0) },
        isShorthand: requireBool(dict, "is_shorthand")
    )
}

func parseKeyword(_ dict: [String: Any]) -> Keyword {
    return Keyword(
        arg: parseNodeRef(dict["arg"], load: parseExpr, label: "Keyword.arg"),
        value: parseNodeRef(dict["value"], load: parseExpr, label: "Keyword.value")!
    )
}

func parseArguments(_ dict: [String: Any]) -> Arguments {
    return Arguments(
        args: parseNodeRefList(dict["args"], load: parseExpr, label: "Arguments.args"),
        defaults: parseNodeRefList(dict["defaults"], load: parseExpr, label: "Arguments.defaults"),
        tyList: parseNodeRefList(dict["ty_list"], load: parseKclTypeNode, label: "Arguments.ty_list")
    )
}

func parseMemberOrIndex(_ dict: [String: Any]) -> MemberOrIndex {
    guard let t = dict["type"] as? String else {
        // fallback: legacy wire shape with no `type` discriminator
        if let value = dict["value"] {
            if let s = value as? String { return .member(NodeRef(node: s)) }
            return .index(parseNodeRef(value, load: parseExpr, label: "MemberOrIndex.index")!)
        }
        return .member(NodeRef(node: ""))
    }
    switch t {
    case "Member":
        return .member(parseNodeRef(dict["value"], load: parseStringNode, label: "MemberOrIndex.value")!)
    case "Index":
        return .index(parseNodeRef(dict["value"], load: parseExpr, label: "MemberOrIndex.value")!)
    default:
        return .member(NodeRef(node: ""))
    }
}

func parseTarget(_ dict: [String: Any]) -> Target {
    return Target(
        name: parseNodeRef(dict["name"], load: parseStringNode, label: "Target.name")!,
        paths: (dict["paths"] as? [[String: Any]] ?? []).map { parseMemberOrIndex($0) },
        pkgpath: (dict["pkgpath"] as? String) ?? ""
    )
}

func parseQuantOperation(_ dict: [String: Any]) -> QuantOperation {
    return QuantOperation(
        target: parseNodeRef(dict["target"], load: parseTarget, label: "QuantOperation.target")!,
        op: (dict["op"] as? String) ?? "filter"
    )
}

func parseQuantOperationAny(_ any: Any) -> QuantOperation {
    if let dict = any as? [String: Any] {
        return parseQuantOperation(dict)
    }
    // Some wire shapes encode the op as a plain string (e.g. "all", "filter").
    let op = (any as? String) ?? "filter"
    return QuantOperation(target: NodeRef(node: Target(name: NodeRef(node: ""), paths: [], pkgpath: "")), op: op)
}

func parseSchemaIndexSignature(_ dict: [String: Any]) -> SchemaIndexSignature {
    return SchemaIndexSignature(
        keyType: parseNodeRef(dict["key_type"], load: parseKclTypeNode, label: "SchemaIndexSignature.key_type")!,
        valueType: parseNodeRef(dict["value_type"], load: parseKclTypeNode, label: "SchemaIndexSignature.value_type")!
    )
}

func parseIdentifier(_ dict: [String: Any]) -> Identifier {
    return Identifier(
        names: (dict["names"] as? [String]) ?? [],
        pkgpath: (dict["pkgpath"] as? [String]) ?? []
    )
}

// MARK: - Operator & context enums

func parseBinOp(_ any: Any) -> BinOp {
    if let s = any as? String, let op = BinOp(rawValue: s) { return op }
    return .add
}

func parseUnaryOp(_ any: Any) -> UnaryOp {
    if let s = any as? String, let op = UnaryOp(rawValue: s) { return op }
    return .not
}

func parseCmpOp(_ s: String) -> CmpOp {
    return CmpOp(rawValue: s) ?? .eq
}

func parseAugOp(_ any: Any) -> AugOp? {
    if let s = any as? String { return AugOp(rawValue: s) }
    return nil
}

func parseConfigEntryOperation(_ s: String) -> ConfigEntryOperation? {
    return ConfigEntryOperation(rawValue: s)
}

func parseExprContext(_ any: Any) -> ExprContext {
    if let s = any as? String, let c = ExprContext(rawValue: s) { return c }
    return .load
}

func parseNameConstant(_ s: String) -> NameConstant {
    return NameConstant(rawValue: s) ?? .undefined
}

func parseBinarySuffix(_ s: String) -> NumberBinarySuffix? {
    return NumberBinarySuffix(rawValue: s)
}
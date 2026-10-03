// AstContractTests.swift — Decodes the shared golden AST capture and checks
// the Swift decoder against the real wire shape.
//
// The fixture is `testdata/ast/alignment.json`: a capture of what the actual
// KCL parser emits for `testdata/ast/alignment.k`, produced once and checked
// in. Decoding it here means the assertions pin the *wire contract* rather
// than this binding's own round trip — a decoder that agreed with itself
// about a wrong shape would still pass, but one that disagrees with Rust
// cannot.
//
// Nothing here touches the native library, so the test runs without a cargo
// build. That is why it lives in its own target rather than in
// `KclLibTests`.
//
// Regenerate the golden file with `testdata/ast/README.md`; the CI workflow's
// path filter includes `testdata/ast/**` so a regeneration re-runs this.

import XCTest

@testable import KclLibAST

final class AstContractTests: XCTestCase {
    private static let golden: String = {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KclLibASTTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // swift package root
            .deletingLastPathComponent()  // repo root
        return packageRoot.appendingPathComponent("testdata/ast/alignment.json").path
    }()

    private func module() throws -> Module {
        try parseModule(try String(contentsOfFile: Self.golden, encoding: .utf8))
    }

    // MARK: - The assertion the rest depends on

    /// Every `"type"` tag this build could not resolve, anywhere in the tree.
    ///
    /// A wrong tag decodes to `.unknown(type:)` and every field of the
    /// resulting value is its zero value — so a decoder that resolves
    /// *nothing* still produces a well-formed `Module` and would sail
    /// through field-by-field assertions on the handful of nodes they
    /// happen to cover. Walking the whole tree and demanding zero unknowns
    /// is what makes the field assertions below mean anything.
    func testEveryTagInTheGoldenCaptureResolves() throws {
        XCTAssertEqual(unresolvedTags(in: try module()), [])
    }

    // MARK: - Module

    func testModuleHasFilenameDoclessBodyAndCommentNodes() throws {
        let parsed = try module()
        XCTAssertTrue(parsed.filename.hasSuffix("alignment.k"))
        XCTAssertNil(parsed.doc)
        XCTAssertFalse(parsed.body.isEmpty)
        // `Comment` is a struct with a `text` field, so each element is a
        // `NodeRef` around `{text}` — not a bare string.
        XCTAssertFalse(parsed.comments.isEmpty)
        XCTAssertTrue(parsed.comments[0].node.text.hasPrefix("# Every AST node shape"))
        XCTAssertEqual(parsed.comments[0].position?.line, 1)
    }

    // MARK: - Stmt

    func testImportStmtIsTheFlatFiveFieldStruct() throws {
        let imports = try module().body.compactMap { ref -> ImportStmt? in
            if case .import(let s) = ref.node { return s } else { return nil }
        }
        XCTAssertEqual(imports.count, 2)

        let plain = imports[0]
        XCTAssertEqual(plain.path.node, "data.cloud")
        XCTAssertEqual(plain.rawpath, "data.cloud")
        XCTAssertEqual(plain.name, "cloud")
        XCTAssertNil(plain.asname)
        XCTAssertEqual(plain.pkgName, "__main__")
        // `path` is a `Node<String>`, so it has a position; the statement
        // itself does not.
        XCTAssertEqual(plain.path.position?.line, 16)

        let aliased = imports[1]
        XCTAssertEqual(aliased.asname?.node, "fb")
    }

    func testAugAssignHasItsOwnStatementVariant() throws {
        // `AugAssign` is one of the eleven `Stmt` variants. A dispatch table
        // missing it would fall through to `.unknown`, which the
        // no-unknown-tags test would catch.
        guard case .augAssign(let aug) = try statement(atLine: 63) else {
            return XCTFail("expected AugAssign at line 63")
        }
        XCTAssertEqual(aug.target.node.name.node, "a")
        XCTAssertEqual(aug.op, .add)
    }

    func testAssertCarriesTestIfCondAndMsg() throws {
        guard case .assert(let bare) = try statement(atLine: 68) else {
            return XCTFail("expected Assert at line 68")
        }
        XCTAssertNil(bare.ifCond)
        XCTAssertNil(bare.msg)

        guard case .assert(let gated) = try statement(atLine: 69) else {
            return XCTFail("expected Assert at line 69")
        }
        XCTAssertNotNil(gated.ifCond)
        XCTAssertNotNil(gated.msg)
    }

    func testIfOrelseIsAListOfStatements() throws {
        // The `else` branch is a sibling `Vec<NodeRef<Stmt>>`, not a nested
        // `IfStmt` and not an `Expr` — modelling it either other way is the
        // classic way to get `elif` wrong.
        guard case .if(let branch) = try statement(atLine: 70) else {
            return XCTFail("expected If at line 70")
        }
        XCTAssertEqual(branch.body.count, 1)
        XCTAssertEqual(branch.orelse.count, 1)
        if case .assign(let other) = branch.orelse[0].node {
            XCTAssertEqual(other.targets[0].node.name.node, "b")
        } else {
            XCTFail("the else branch should hold statements")
        }
    }

    func testUnificationTargetIsAStoreContextIdentifier() throws {
        guard case .unification(let u) = try statement(atLine: 55) else {
            return XCTFail("expected Unification at line 55")
        }
        XCTAssertEqual(u.target.node.dottedName(), "u")
        XCTAssertEqual(u.target.node.ctx, .store)
        // The value is a `SchemaExpr`, and its name is an Identifier rather
        // than an expression.
        XCTAssertEqual(u.value.node.name.node.dottedName(), "Person")
    }

    // MARK: - Schema

    func testSchemaDecoratorsAndChecksAreUntaggedDtos() throws {
        let person = try schema(named: "Person")
        // `@deprecated` / `@info` are on the `name` attribute, not the
        // schema — an easy place to look in the wrong place.
        XCTAssertTrue(person.decorators.isEmpty)
        XCTAssertEqual(person.checks.count, 2)
        // `checks` is `Vec<NodeRef<CheckExpr>>`: a bare `{test,if_cond,msg}`.
        XCTAssertNotNil(person.checks[0].node.test)
        XCTAssertNotNil(person.checks[0].node.msg)
        XCTAssertNil(person.checks[0].node.ifCond)
        XCTAssertNotNil(person.checks[1].node.ifCond)

        guard case .schemaAttr(let name) = person.body[0].node else {
            return XCTFail("expected the name attribute first")
        }
        XCTAssertEqual(name.decorators.count, 2)
        // A plain `name: str = "anonymous"` still reports `Assign` here.
        XCTAssertEqual(name.op, .assign)
        XCTAssertFalse(name.isOptional)
        XCTAssertEqual(name.name.node, "name")

        guard case .schemaAttr(let age) = person.body[1].node else {
            return XCTFail("expected the age attribute second")
        }
        XCTAssertTrue(age.isOptional)
    }

    func testSchemaAttributeTypeIsNotOptional() throws {
        // Rust declares `SchemaAttr.ty: NodeRef<Type>`, not
        // `Option<NodeRef<Type>>`, so `name: str` still has a type.
        guard case .schemaAttr(let name) = try schema(named: "Person").body[0].node else {
            return XCTFail("expected a SchemaAttr")
        }
        if case .basic(let basic) = name.ty.node {
            XCTAssertEqual(basic, .str)
        } else {
            XCTFail("expected a Basic type")
        }
    }

    func testRuleHasChecksAndNoBody() throws {
        guard case .rule(let r) = try statement(named: "R") else {
            return XCTFail("expected the R rule")
        }
        XCTAssertEqual(r.checks.count, 1)
        XCTAssertTrue(r.parentRules.isEmpty)
    }

    // MARK: - Expr

    func testSchemaExpressionVersusCall() throws {
        // `Person {name = …}` is `Expr::Schema` with the entries in
        // `config`; `Person(1, name = …)` is a plain `Expr::Call` with
        // keywords. Conflating the two is a common mistake.
        guard case .assign(let schemaAssign) = try statement(atLine: 52) else {
            return XCTFail("expected Assign at line 52")
        }
        guard case .schema(let schema) = schemaAssign.value.node else {
            return XCTFail("expected a SchemaExpr")
        }
        XCTAssertEqual(schema.name.node.dottedName(), "Person")
        XCTAssertTrue(schema.args.isEmpty)
        XCTAssertTrue(schema.keywords.isEmpty)
        if case .config(let config) = schema.config.node {
            XCTAssertEqual(config.items.count, 2)
        } else {
            XCTFail("expected a ConfigExpr")
        }

        guard case .assign(let callAssign) = try statement(atLine: 53) else {
            return XCTFail("expected Assign at line 53")
        }
        guard case .call(let call) = callAssign.value.node else {
            return XCTFail("expected a CallExpr, not a SchemaExpr")
        }
        XCTAssertEqual(call.args.count, 1)
        XCTAssertEqual(call.keywords.count, 1)
        // `Keyword.arg` is an Identifier, not an expression.
        XCTAssertEqual(call.keywords[0].node.arg.node.dottedName(), "name")
    }

    func testUnaryMinusIsUSubNotSub() throws {
        // `BinOp::Sub` exists too, which is exactly why the two spellings
        // have to be kept apart.
        guard case .assign(let assign) = try statement(named: "unary") else {
            return XCTFail("expected the unary assignment")
        }
        guard case .unary(let unary) = assign.value.node else {
            return XCTFail("expected a UnaryExpr")
        }
        XCTAssertEqual(unary.op, .uSub)
    }

    func testCompareChainKeepsParallelOperatorArrays() throws {
        guard case .assign(let assign) = try statement(named: "compare_chain") else {
            return XCTFail("expected the compare_chain assignment")
        }
        guard case .compare(let compare) = assign.value.node else {
            return XCTFail("expected a Compare")
        }
        XCTAssertEqual(compare.ops, [.lt, .ltE])
        XCTAssertEqual(compare.comparators.count, 2)
    }

    func testOptionalSelectorRecordsHasQuestion() throws {
        guard case .assign(let assign) = try statement(named: "optional") else {
            return XCTFail("expected the optional assignment")
        }
        guard case .selector(let selector) = assign.value.node else {
            return XCTFail("expected a SelectorExpr")
        }
        XCTAssertTrue(selector.hasQuestion)
        // `attr` is a NodeRef<Identifier>, not `attr_name`.
        XCTAssertEqual(selector.attr.node.dottedName(), "name")
    }

    func testSubscriptSliceUsesLowerUpperStepNotAnIndex() throws {
        guard case .assign(let assign) = try statement(named: "subscript_slice") else {
            return XCTFail("expected the subscript_slice assignment")
        }
        guard case .subscript(let slice) = assign.value.node else {
            return XCTFail("expected a Subscript")
        }
        XCTAssertNil(slice.index)
        XCTAssertNotNil(slice.lower)
        XCTAssertNotNil(slice.upper)
        XCTAssertNil(slice.step)

        guard case .assign(let stepped) = try statement(named: "subscript_step") else {
            return XCTFail("expected the subscript_step assignment")
        }
        guard case .subscript(let withStep) = stepped.value.node else {
            return XCTFail("expected a Subscript")
        }
        XCTAssertNotNil(withStep.step)
    }

    func testConfigEntryOperationsAndShorthandFlag() throws {
        guard case .assign(let assign) = try statement(named: "config") else {
            return XCTFail("expected the config assignment")
        }
        guard case .config(let config) = assign.value.node else {
            return XCTFail("expected a ConfigExpr")
        }
        // `{a = 1, b: 2}` — `=` is an override and `:` is a union.
        XCTAssertEqual(config.items.map { $0.node.operation }, [.overrideOp, .union])
        // `is_shorthand` is `skip_serializing_if = "is_false"` upstream, so
        // it is absent unless true. A decoder that reads a plain `Bool`
        // still lands on `false` here.
        XCTAssertEqual(config.items.map { $0.node.isShorthand }, [false, false])

        guard case .assign(let shorthand) = try statement(named: "config_shorthand") else {
            return XCTFail("expected the config_shorthand assignment")
        }
        guard case .config(let short) = shorthand.value.node else {
            return XCTFail("expected a ConfigExpr")
        }
        XCTAssertEqual(short.items.map { $0.node.isShorthand }, [true, true])
    }

    func testConfigIfEntryWrapsAnEntryInAConfig() throws {
        guard case .assign(let assign) = try statement(named: "config_if") else {
            return XCTFail("expected the config_if assignment")
        }
        guard case .config(let config) = assign.value.node else {
            return XCTFail("expected a ConfigExpr")
        }
        // The `if:` branch is a `ConfigEntry` whose value is the
        // `ConfigIfEntry` — so `key` is null and the shape is one level
        // deeper than it looks.
        XCTAssertEqual(config.items.count, 1)
        XCTAssertNil(config.items[0].node.key)
        guard case .configIfEntry(let entry) = config.items[0].node.value.node else {
            return XCTFail("expected a ConfigIfEntryExpr")
        }
        XCTAssertFalse(entry.items.isEmpty)
        // The `else` branch is a whole ConfigExpr, not a second
        // ConfigIfEntryExpr.
        guard case .config = entry.orelse?.node else {
            return XCTFail("expected the else branch to be a ConfigExpr")
        }
    }

    func testQuantExpressionFields() throws {
        guard case .assign(let assign) = try statement(named: "quant") else {
            return XCTFail("expected the quant assignment")
        }
        guard case .quant(let quant) = assign.value.node else {
            return XCTFail("expected a QuantExpr")
        }
        XCTAssertEqual(quant.op, .all)
        // `variables` is a list of Identifiers, not targets.
        XCTAssertEqual(quant.variables.map { $0.node.dottedName() }, ["v"])
        XCTAssertNotNil(quant.test)
    }

    func testComprehensionClauseBindsIdentifiers() throws {
        guard case .assign(let assign) = try statement(named: "list_if") else {
            return XCTFail("expected the list_if assignment")
        }
        guard case .listComp(let comp) = assign.value.node else {
            return XCTFail("expected a ListComp")
        }
        XCTAssertEqual(comp.generators.count, 1)
        // `CompClause.targets` is `Vec<NodeRef<Identifier>>`; there is no
        // separate `cond` field — the filter lives in `ifs`.
        XCTAssertEqual(comp.generators[0].node.targets.map { $0.node.dottedName() }, ["i"])
        XCTAssertEqual(comp.generators[0].node.ifs.count, 1)

        guard case .assign(let dict) = try statement(named: "dict_comp") else {
            return XCTFail("expected the dict_comp assignment")
        }
        guard case .dictComp(let dictComp) = dict.value.node else {
            return XCTFail("expected a DictComp")
        }
        // `entry` is a bare `ConfigEntry` with no NodeRef wrapper.
        XCTAssertEqual(dictComp.entry.operation, .union)
        XCTAssertNotNil(dictComp.entry.key)
        XCTAssertNotNil(dictComp.entry.value)
    }

    func testLambdaArgumentsAreIndexAlignedWithTheirNulls() throws {
        guard case .assign(let typed) = try statement(named: "lambda_expr") else {
            return XCTFail("expected the lambda_expr assignment")
        }
        guard case .lambda(let lambda) = typed.value.node else {
            return XCTFail("expected a LambdaExpr")
        }
        let args = try XCTUnwrap(lambda.args?.node)
        XCTAssertEqual(args.args.map { $0.node.dottedName() }, ["p"])
        // `lambda p: int -> int` declares a type but no default, so
        // `defaults` is `[null]` — the null is a real slot, and dropping it
        // would shift every later annotation onto the wrong parameter.
        XCTAssertEqual(args.defaults.count, 1)
        XCTAssertNil(args.defaults[0])
        XCTAssertEqual(args.tyList.count, 1)
        if case .basic(let int) = args.tyList[0]?.node {
            XCTAssertEqual(int, .int)
        } else {
            XCTFail("expected an Int annotation")
        }
        // A lambda body is a list of statements.
        XCTAssertEqual(lambda.body.count, 1)
        if case .expr = lambda.body[0].node {} else { XCTFail("expected an ExprStmt body") }

        // `lambda { a }` has no parameter list at all — absent, not empty.
        guard case .assign(let plain) = try statement(named: "lambda_plain") else {
            return XCTFail("expected the lambda_plain assignment")
        }
        guard case .lambda(let bare) = plain.value.node else {
            return XCTFail("expected a LambdaExpr")
        }
        XCTAssertNil(bare.args)
    }

    func testJoinedStringAndFormattedValue() throws {
        guard case .assign(let assign) = try statement(named: "joined") else {
            return XCTFail("expected the joined assignment")
        }
        guard case .joinedString(let joined) = assign.value.node else {
            return XCTFail("expected a JoinedString")
        }
        XCTAssertFalse(joined.values.isEmpty)
        guard case .formattedValue(let formatted) = joined.values[1].node else {
            return XCTFail("expected a FormattedValue")
        }
        // `format_spec`, and a bare string rather than a node.
        XCTAssertNil(formatted.formatSpec)
    }

    func testTargetPathsAreMemberOrIndex() throws {
        guard case .assign(let dotted) = try statement(atLine: 66) else {
            return XCTFail("expected Assign at line 66")
        }
        let paths = dotted.targets[0].node.paths
        XCTAssertEqual(paths.count, 2)
        if case .member(let first) = paths[0] {
            XCTAssertEqual(first.node, "name")
        } else {
            XCTFail("expected a Member path segment")
        }

        guard case .assign(let indexed) = try statement(atLine: 67) else {
            return XCTFail("expected Assign at line 67")
        }
        if case .index = indexed.targets[0].node.paths[0] {} else {
            XCTFail("expected an Index path segment")
        }
    }

    // MARK: - Type

    func testAnyIsTheOneUnitVariantWithNoPayload() throws {
        // serde's adjacently-tagged encoding of a unit variant is the bare
        // tag. There is no `"value"` key to read, and emitting one would not
        // survive a strict consumer.
        guard case .typeAlias(let any) = try statement(named: "TAny") else {
            return XCTFail("expected the TAny alias")
        }
        if case .any = any.ty.node {} else { XCTFail("expected the Any type") }
    }

    func testBasicTypePayloadIsTheBareString() throws {
        // The tag names the *shape*, not the type: `BasicType` is a
        // fieldless enum with no struct wrapper, so the wire is
        // `{"type":"Basic","value":"Int"}` and never `{"type":"Int"}`.
        guard case .typeAlias(let alias) = try statement(named: "TBasic") else {
            return XCTFail("expected the TBasic alias")
        }
        if case .basic(let basic) = alias.ty.node {
            XCTAssertEqual(basic, .str)
        } else {
            XCTFail("expected a Basic type")
        }
    }

    func testListDictAndUnionTypePayloads() throws {
        guard case .typeAlias(let list) = try statement(named: "TList") else {
            return XCTFail("expected the TList alias")
        }
        guard case .list(let listType) = list.ty.node, case .basic(.int) = listType.innerType?.node else {
            return XCTFail("expected [int]")
        }

        guard case .typeAlias(let dict) = try statement(named: "TDict") else {
            return XCTFail("expected the TDict alias")
        }
        guard case .dict(let dictType) = dict.ty.node else { return XCTFail("expected a Dict type") }
        if case .basic(.str) = dictType.keyType?.node {} else { XCTFail("expected a str key") }
        if case .basic(.int) = dictType.valueType?.node {} else { XCTFail("expected an int value") }

        guard case .typeAlias(let union) = try statement(named: "TUnion") else {
            return XCTFail("expected the TUnion alias")
        }
        guard case .union(let unionType) = union.ty.node else { return XCTFail("expected a Union type") }
        // The Rust field is `type_elements`, not `types`.
        XCTAssertEqual(unionType.typeElements.count, 2)
        if case .basic(.int) = unionType.typeElements[0].node {} else { XCTFail("expected int first") }
        if case .basic(.str) = unionType.typeElements[1].node {} else { XCTFail("expected str second") }
    }

    func testFunctionTypeKeepsOptionalParamsAndReturn() throws {
        guard case .typeAlias(let alias) = try statement(named: "TFunc") else {
            return XCTFail("expected the TFunc alias")
        }
        guard case .function(let function) = alias.ty.node else {
            return XCTFail("expected a Function type")
        }
        // `params_ty` / `ret_ty`, both `Option`s.
        XCTAssertEqual(function.paramsTy?.count, 2)
        if case .basic(.bool) = function.retTy?.node {} else { XCTFail("expected a bool return type") }
    }

    func testNamedTypeInlinesTheIdentifierPayload() throws {
        // `Type::Named(Identifier)` is a newtype, so the identifier sits
        // directly under `value` with no extra wrapper key.
        guard case .typeAlias(let alias) = try statement(named: "TNamed") else {
            return XCTFail("expected the TNamed alias")
        }
        guard case .named(let named) = alias.ty.node else {
            return XCTFail("expected a Named type")
        }
        XCTAssertEqual(named.dottedName(), "Cloud")
    }

    func testLiteralTypeIsASecondTaggedDocument() throws {
        // `LiteralType` is itself `tag + content`, so `Type::Literal` nests
        // one tagged document inside its `value`.
        guard case .typeAlias(let stringAlias) = try statement(named: "TLitStr") else {
            return XCTFail("expected the TLitStr alias")
        }
        guard case .literal(let str) = stringAlias.ty.node, case .str(let text) = str.value else {
            return XCTFail("expected a Str literal type")
        }
        XCTAssertEqual(text, "s")

        guard case .typeAlias(let boolAlias) = try statement(named: "TLitBool") else {
            return XCTFail("expected the TLitBool alias")
        }
        guard case .literal(let boolType) = boolAlias.ty.node, case .bool(let flag) = boolType.value else {
            return XCTFail("expected a Bool literal type")
        }
        XCTAssertTrue(flag)

        // `LiteralType::Int` carries a newtype payload, so it is inlined as
        // `{value, suffix}` rather than nested under another key.
        guard case .typeAlias(let intAlias) = try statement(named: "TLitInt") else {
            return XCTFail("expected the TLitInt alias")
        }
        guard case .literal(let intType) = intAlias.ty.node, case .int(let literal) = intType.value else {
            return XCTFail("expected an Int literal type")
        }
        XCTAssertEqual(literal.value, 1)
        XCTAssertNil(literal.suffix)
    }

    func testTypeAliasFieldsAreTypeNameTypeValueAndTy() throws {
        // The wire keys are `type_name` / `type_value` / `ty`, not `name`.
        guard case .typeAlias(let alias) = try statement(named: "TBasic") else {
            return XCTFail("expected the TBasic alias")
        }
        XCTAssertEqual(alias.typeName.node.dottedName(), "TBasic")
        XCTAssertEqual(alias.typeValue.node, "str")
    }

    // MARK: - Forward compatibility

    func testUnknownTagsAreKeptRatherThanDropped() throws {
        let json = """
            {"filename": "a.k", "doc": null, "comments": [],
             "body": [{"node": {"type": "FromTheFuture", "whatever": 1},
                       "filename": "a.k", "line": 1, "column": 0, "end_line": 1, "end_column": 1}]}
            """
        let parsed = try parseModule(json)
        guard case .unknown(let tag) = parsed.body[0].node else {
            return XCTFail("expected the tag to survive as unknown")
        }
        XCTAssertEqual(tag, "FromTheFuture")
    }

    func testProgramEnvelopeExposesTheMainPackage() throws {
        let json = """
            {"root": ".", "pkgs": {"__main__": [
              {"filename": "a.k", "doc": null, "body": [], "comments": []}]}}
            """
        let program = try parseProgramEnvelope(json)
        XCTAssertEqual(program.root, ".")
        XCTAssertEqual(program.mainPackage.count, 1)
        XCTAssertEqual(program.mainPackage[0].filename, "a.k")
        XCTAssertEqual(try parseProgram(json).count, 1)
    }

    // MARK: - Lookups

    private func statement(atLine line: Int) throws -> Stmt {
        let parsed = try module()
        let ref = try XCTUnwrap(parsed.body.first { $0.position?.line == Int64(line) }, "no statement at line \(line)")
        return ref.node
    }

    private func statement(named name: String) throws -> Stmt {
        let parsed = try module()
        // Schema and rule names are `NodeRef<String>`; everything else is
        // identified by its target name or its `type_name`.
        let found = parsed.body.first { ref in
            switch ref.node {
            case .schema(let s): return s.name.node == name
            case .rule(let s): return s.name.node == name
            case .typeAlias(let s): return s.typeName.node.dottedName() == name
            case .assign(let s): return s.targets.first?.node.name.node == name
            default: return false
            }
        }
        return try XCTUnwrap(found, "no statement named \(name)").node
    }

    private func schema(named name: String) throws -> SchemaStmt {
        guard case .schema(let s) = try statement(named: name) else {
            throw XCTSkip("\(name) is not a schema")
        }
        return s
    }
}

// MARK: - Unresolved-tag walk

/// The three child accessors below are the only thing the walk needs: each
/// returns a node's immediate children of one kind, so the traversal is a
/// plain worklist rather than a recursive descent that has to know the shape
/// of every variant.
private func exprChildren(_ expr: Expr) -> [Expr] {
    func node(_ ref: NodeRef<Expr>?) -> [Expr] { ref.map { [$0.node] } ?? [] }
    func nodes(_ refs: [NodeRef<Expr>]) -> [Expr] { refs.map { $0.node } }
    func keywords(_ refs: [NodeRef<Keyword>]) -> [Expr] { refs.compactMap { $0.node.value?.node } }
    func configEntries(_ refs: [NodeRef<ConfigEntry>]) -> [Expr] { refs.map { $0.node.value.node } }
    func checks(_ refs: [NodeRef<CheckExpr>]) -> [Expr] {
        refs.flatMap { [$0.node.test.node] } + refs.compactMap { $0.node.ifCond?.node } + refs.compactMap { $0.node.msg?.node }
    }
    func clauses(_ refs: [NodeRef<CompClause>]) -> [Expr] {
        refs.flatMap { $0.node.ifs.map(\.node) } + refs.map { $0.node.iter.node }
    }
    func identifiers(_ refs: [NodeRef<Identifier>]) -> [Expr] { refs.map { .identifier($0.node) } }

    switch expr {
    case .target, .identifier, .missing, .unknown:
        return []
    case .unary(let e): return node(e.operand)
    case .binary(let e): return node(e.left) + node(e.right)
    case .if(let e): return node(e.cond) + node(e.body) + node(e.orelse)
    case .selector(let e): return node(e.value)
    case .call(let e): return node(e.func) + nodes(e.args) + keywords(e.keywords)
    case .paren(let e): return node(e.expr)
    case .quant(let e): return node(e.target) + node(e.test) + node(e.ifCond) + identifiers(e.variables)
    case .list(let e): return nodes(e.elts)
    case .listIfItem(let e): return node(e.ifCond) + nodes(e.exprs) + node(e.orelse)
    case .listComp(let e): return node(e.elt) + clauses(e.generators)
    case .starred(let e): return node(e.value)
    case .dictComp(let e): return [e.entry.value.node] + clauses(e.generators)
    case .configIfEntry(let e): return node(e.ifCond) + configEntries(e.items) + node(e.orelse)
    case .compClause(let e): return clauses([NodeRef(node: e)])
    case .schema(let e): return nodes(e.args) + keywords(e.keywords) + node(e.config)
    case .config(let e): return configEntries(e.items)
    case .check(let e): return [e.test.node] + (e.ifCond.map { [$0.node] } ?? []) + (e.msg.map { [$0.node] } ?? [])
    case .lambda(let e): return (e.args.map { $0.node.defaults } ?? []).compactMap { $0?.node }
    case .subscript(let e): return node(e.value) + node(e.index) + node(e.lower) + node(e.upper) + node(e.step)
    case .keyword(let e): return node(e.value)
    case .arguments(let e): return e.defaults.compactMap { $0?.node }
    case .compare(let e): return node(e.left) + nodes(e.comparators)
    case .numberLit, .stringLit, .nameConstantLit: return []
    case .joinedString(let e): return nodes(e.values)
    case .formattedValue(let e): return node(e.value)
    }
}

/// A `LambdaExpr` body is a `Vec<NodeRef<Stmt>>`, the one place an
/// expression contains statements.
private func stmtChildren(_ expr: Expr) -> [Stmt] {
    if case .lambda(let lambda) = expr { return lambda.body.map { $0.node } }
    return []
}

/// The only types reachable from an expression are a lambda's parameter
/// annotations and its return type.
private func typeChildren(_ expr: Expr) -> [KclTypeNode] {
    guard case .lambda(let lambda) = expr else { return [] }
    return (lambda.args.map { $0.node.tyList.compactMap { $0?.node } } ?? [])
        + (lambda.returnTy.map { [$0.node] } ?? [])
}

private func exprChildrenOfStmt(_ stmt: Stmt) -> [Expr] {
    func node(_ ref: NodeRef<Expr>?) -> [Expr] { ref.map { [$0.node] } ?? [] }
    func nodes(_ refs: [NodeRef<Expr>]) -> [Expr] { refs.map { $0.node } }
    func checks(_ refs: [NodeRef<CheckExpr>]) -> [Expr] {
        refs.flatMap { [$0.node.test.node] } + refs.compactMap { $0.node.ifCond?.node } + refs.compactMap { $0.node.msg?.node }
    }
    func decorators(_ refs: [NodeRef<CallExpr>]) -> [Expr] {
        refs.flatMap { [$0.node.func.node] } + refs.flatMap { $0.node.args.map(\.node) }
    }
    func schemaExpr(_ ref: NodeRef<SchemaExpr>?) -> [Expr] {
        guard let schema = ref?.node else { return [] }
        return schema.args.map { $0.node } + [schema.config.node]
            + schema.keywords.compactMap { $0.node.value?.node }
    }

    switch stmt {
    case .unknown, .import:
        return []
    case .expr(let s): return s.exprs.map { $0.node }
    case .typeAlias: return []
    case .unification(let s): return schemaExpr(s.value)
    case .assign(let s): return node(s.value)
    case .augAssign(let s): return node(s.value)
    case .assert(let s): return [s.test.node] + (s.ifCond.map { [$0.node] } ?? []) + (s.msg.map { [$0.node] } ?? [])
    case .if(let s): return [s.cond.node]
    case .schemaAttr(let s): return node(s.value) + decorators(s.decorators)
    case .schema(let s): return decorators(s.decorators) + checks(s.checks)
    case .rule(let s): return decorators(s.decorators) + checks(s.checks)
    }
}

private func typeChildrenOfStmt(_ stmt: Stmt) -> [KclTypeNode] {
    switch stmt {
    case .typeAlias(let s): return [s.ty.node]
    case .schemaAttr(let s): return [s.ty.node]
    case .schema(let s): return s.indexSignature.map { [$0.node.keyTy.node, $0.node.valueTy.node] } ?? []
    case .unknown, .expr, .unification, .assign, .augAssign, .assert, .if, .import, .rule:
        return []
    }
}

private func unresolvedTags(in module: Module) -> [String] {
    var unresolved: [String] = []
    var stmts = module.body.map { $0.node }
    var exprs: [Expr] = []
    var types: [KclTypeNode] = []

    while !stmts.isEmpty || !exprs.isEmpty || !types.isEmpty {
        while let stmt = stmts.popLast() {
            if case .unknown(let tag) = stmt { unresolved.append("Stmt.\(tag)"); continue }
            exprs += exprChildrenOfStmt(stmt)
            types += typeChildrenOfStmt(stmt)
        }
        while let expr = exprs.popLast() {
            if case .unknown(let tag) = expr { unresolved.append("Expr.\(tag)"); continue }
            stmts += stmtChildren(expr)
            exprs += exprChildren(expr)
            types += typeChildren(expr)
        }
        while let type = types.popLast() {
            if case .unknown(let tag) = type { unresolved.append("Type.\(tag)") }
        }
    }
    return unresolved.sorted()
}

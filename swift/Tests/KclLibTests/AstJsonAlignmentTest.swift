// AstJsonAlignmentTest.swift — Round-trip AST alignment tests for the Swift binding.
//
// Parses a real KCL fixture through the native FFI (`API.parseFile` /
// `API.parseProgram`) and checks the resulting `astJson` deserializes into
// the typed AST in `KclLibAST`.
//
// The wire *contract* itself — which tags exist, which payloads are
// flattened — is pinned by `KclLibASTTests` against the shared golden
// capture. What this file adds is the other half: that the parser we ship
// actually produces that contract.

import XCTest

@testable import KclLib
@testable import KclLibAST

final class AstJsonAlignmentTest: XCTestCase {
    func fixturePath() -> String {
        let swiftDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KclLibTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // swift package root
        return swiftDir.appendingPathComponent("Tests/KclLibTests/test_data/ast_alignment/main.k").path
    }

    private func parsedModule() throws -> Module {
        var args = ParseFileArgs()
        args.path = fixturePath()
        let result = try API().parseFile(args)
        XCTAssertEqual(result.errors.count, 0)
        return try parseModule(result.astJson)
    }

    func testModuleFilenameAndNoPkg() throws {
        let module = try parsedModule()
        XCTAssertTrue(module.filename.hasSuffix("main.k"))
        // The Rust `Module` struct has no `pkg` field, so neither does ours.
        for child in Mirror(reflecting: module).children {
            XCTAssertNotEqual(child.label, "pkg", "Module should not have a pkg field")
        }
    }

    func testSchemaAttrDefaultIsAStringLit() throws {
        // The tag is the serde variant name, not the longer
        // `StringLiteralExpression` that `get_expr_name()` returns for
        // diagnostics.
        let module = try parsedModule()
        var foundStringLit = false
        for stmtRef in module.body {
            guard case .schema(let schema) = stmtRef.node else { continue }
            for attrRef in schema.body {
                guard case .schemaAttr(let attr) = attrRef.node,
                      case .stringLit = attr.value?.node
                else { continue }
                foundStringLit = true
            }
        }
        XCTAssertTrue(foundStringLit, "expected at least one StringLit in the fixture body")
    }

    func testSchemaAttrDecoratorsAreFlatCallExpressions() throws {
        // `decorators` is `Vec<NodeRef<CallExpr>>`, so each element is a bare
        // `{func,args,keywords}` with no `"type":"Call"` tag.
        guard case .schema(let person) = try schema(named: "Person") else {
            return XCTFail("expected the Person schema")
        }
        guard case .schemaAttr(let name) = person.body[0].node else {
            return XCTFail("expected the name attribute first")
        }
        XCTAssertEqual(name.decorators.count, 1)
        // `@deprecated` has no call parentheses, so it decodes as a
        // `CallExpr` with an empty argument list.
        XCTAssertEqual(name.decorators[0].node.args.count, 0)
        XCTAssertEqual(name.decorators[0].node.keywords.count, 0)
        if case .identifier(let callee) = name.decorators[0].node.func.node {
            XCTAssertEqual(callee.dottedName(), "deprecated")
        } else {
            XCTFail("expected the decorator callee to be an IdentifierExpr")
        }
    }

    func testSchemaDecoratorOnTheSchemaHeader() throws {
        guard case .schema(let article) = try schema(named: "Article") else {
            return XCTFail("expected the Article schema")
        }
        XCTAssertEqual(article.decorators.count, 1)
        // `schema Article(HasTimestamp)` — the parent is an Identifier.
        XCTAssertEqual(article.parentName?.node.dottedName(), "HasTimestamp")
        // Newer kcl runtimes also copy the parent into `mixins`; the pinned
        // runtime lists it only in `parent_name`, so there is nothing to
        // assert against until the pin moves.
        try XCTSkipIf(article.mixins.isEmpty, "the pinned kcl runtime does not copy the parent into mixins")
        XCTAssertEqual(article.mixins.map { $0.node.dottedName() }, ["HasTimestamp"])
    }

    func testCheckOnSchemaAttrHasMsgAndIfCond() throws {
        guard case .schema(let person) = try schema(named: "Person") else {
            return XCTFail("expected the Person schema")
        }
        XCTAssertEqual(person.checks.count, 1)
        XCTAssertNotNil(person.checks[0].node.test)
        XCTAssertNotNil(person.checks[0].node.ifCond)
        XCTAssertNotNil(person.checks[0].node.msg)
    }

    func testSchemaInstantiationIsASchemaExpr() throws {
        guard case .assign(let assign) = try assignment(named: "x") else {
            return XCTFail("expected the x assignment")
        }
        guard case .schema(let schema) = assign.value.node else {
            return XCTFail("expected a SchemaExpr on the right-hand side of `x =`")
        }
        XCTAssertEqual(schema.name.node.dottedName(), "Person")
        // `Person {…}` puts its entries in `config`, not `keywords`.
        XCTAssertTrue(schema.keywords.isEmpty)
        if case .config(let config) = schema.config.node {
            XCTAssertEqual(config.items.count, 2)
        } else {
            XCTFail("expected a ConfigExpr")
        }
    }

    func testLambdaArgumentsCarryTypesAndPositionalNullDefaults() throws {
        guard case .assign(let assign) = try assignment(named: "adder") else {
            return XCTFail("expected the adder assignment")
        }
        guard case .lambda(let lambda) = assign.value.node else {
            return XCTFail("expected a LambdaExpr on the right-hand side of `adder =`")
        }
        let args = try XCTUnwrap(lambda.args?.node)
        XCTAssertEqual(args.args.map { $0.node.dottedName() }, ["x", "y"])
        // Neither parameter has a default, but the slots are still there —
        // they are index-aligned with `args` and `tyList`.
        XCTAssertEqual(args.defaults.count, 2)
        XCTAssertNil(args.defaults[0])
        XCTAssertNil(args.defaults[1])
        XCTAssertEqual(args.tyList.count, 2)
        // The body is statements, not expressions.
        XCTAssertEqual(lambda.body.count, 1)
        if case .expr = lambda.body[0].node {} else { XCTFail("expected an ExprStmt body") }
    }

    func testParseProgramReturnsTheMainPackage() throws {
        var args = ParseProgramArgs()
        args.paths.append(fixturePath())
        let result = try API().parseProgram(args)
        XCTAssertEqual(result.errors.count, 0)
        let modules = try parseProgram(result.astJson)
        XCTAssertFalse(modules.isEmpty)
        XCTAssertTrue(modules[0].filename.hasSuffix(".k"))
    }

    // MARK: - Lookups

    private func schema(named name: String) throws -> Stmt {
        let module = try parsedModule()
        return try XCTUnwrap(
            module.body.first { if case .schema(let s) = $0.node, s.name.node == name { return true } else { return false } },
            "no schema named \(name)"
        ).node
    }

    private func assignment(named name: String) throws -> Stmt {
        let module = try parsedModule()
        return try XCTUnwrap(
            module.body.first {
                if case .assign(let a) = $0.node, a.targets.first?.node.name.node == name { return true }
                return false
            },
            "no assignment named \(name)"
        ).node
    }
}

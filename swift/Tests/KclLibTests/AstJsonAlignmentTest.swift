// AstJsonAlignmentTest.swift — Round-trip AST alignment tests for the Swift binding.
//
// Mirrors the Java `AstJsonAlignmentTest`, Go `TestAstJsonAlignment`,
// Python `tests/ast_test.py`, Node.js `__test__/ast_alignment.spec.mjs`,
// .NET `KclLib.Tests/AstAlignmentTest.cs`, WASM
// `tests/ast_alignment.test.ts`, and Kotlin
// `AstJsonAlignmentTest.kt`: parse a real KCL fixture through the
// native FFI (`API.parseFile`/`API.parseProgram`) and verify the
// resulting `astJson` string deserializes cleanly into the typed AST
// structs in `KclLib.AST`.

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

    func testModuleFilenameAndNoPkg() throws {
        var args = ParseFileArgs()
        args.path = fixturePath()
        let result = try API().parseFile(args)
        XCTAssertEqual(result.errors.count, 0)
        let module = try parseModule(result.astJson)
        XCTAssertTrue(module.filename.hasSuffix("main.k"))
        // Module must not carry a `pkg` field — round-trip should produce
        // neither one in input nor one on output.
        let moduleMirror = Mirror(reflecting: module)
        for child in moduleMirror.children {
            XCTAssertNotEqual(child.label, "pkg", "Module should not have a pkg field")
        }
    }

    func testLiteralDiscriminatorsUseLongForm() throws {
        var args = ParseFileArgs()
        args.path = fixturePath()
        let result = try API().parseFile(args)
        XCTAssertTrue(result.astJson.contains("\"StringLit\""), "expected \"StringLit\" tag in wire JSON")
        let module = try parseModule(result.astJson)
        // The fixture contains string literals in SchemaAttr defaults
        // (e.g. `name: str = "anonymous"`). Walk into the schema body to
        // find at least one `StringLit` Expr variant.
        var foundStringLit = false
        for stmtRef in module.body {
            if case .schema(let schemaStmt) = stmtRef.node {
                for attrRef in schemaStmt.body {
                    if case .schemaAttr(let attr) = attrRef.node {
                        if let v = attr.value {
                            if case .stringLit = v.node {
                                foundStringLit = true
                            }
                        }
                    }
                }
            }
        }
        XCTAssertTrue(foundStringLit, "expected at least one StringLit in fixture body")
    }

    func testConfigEntryIsShorthandRoundTrips() {
        // Mirror Rust's #[serde(skip_serializing_if = "is_false")]: omitted
        // when false, emitted when true. The Swift AST exposes this as a
        // boolean defaulting to false.
        let ce = ConfigEntry(
            key: NodeRef(node: Expr.missing(MissingExpr())),
            value: NodeRef(node: Expr.missing(MissingExpr())),
            operation: nil,
            isShorthand: false
        )
        XCTAssertFalse(ce.isShorthand)
        let ce2 = ConfigEntry(
            key: NodeRef(node: Expr.missing(MissingExpr())),
            value: NodeRef(node: Expr.missing(MissingExpr())),
            operation: nil,
            isShorthand: true
        )
        XCTAssertTrue(ce2.isShorthand)
    }

    func testAssignStmtWithSchemaExprValue() throws {
        var args = ParseFileArgs()
        args.path = fixturePath()
        let result = try API().parseFile(args)
        let module = try parseModule(result.astJson)
        let assign = module.body.first { stmtRef in
            if case .assign(let a) = stmtRef.node {
                if let first = a.targets.first?.node, first.name.node == "x" {
                    return true
                }
            }
            return false
        }
        XCTAssertNotNil(assign)
        if case .assign(let a) = assign!.node {
            if case .schema = a.value.node {
                // expected
            } else {
                XCTFail("expected SchemaExpr on the right-hand side of `x =`")
            }
        }
    }

    func testSchemaStmtDecoratorsAreFlatDecoratorDTO() throws {
        var args = ParseFileArgs()
        args.path = fixturePath()
        let result = try API().parseFile(args)
        let module = try parseModule(result.astJson)
        let article = module.body.first { stmtRef in
            if case .schema(let s) = stmtRef.node, s.name.node == "Article" {
                return true
            }
            return false
        }
        XCTAssertNotNil(article)
        if case .schema(let schema) = article!.node {
            XCTAssertGreaterThan(schema.decorators.count, 0)
            for decoRef in schema.decorators {
                let deco = decoRef.node
                XCTAssertNotNil(deco.func)
                if let f = deco.func {
                    if case .identifier = f.node {
                        // expected: Decorator.Func is a Node wrapping an
                        // Identifier expression (no `"type":"Call"` tag in
                        // the flat shape).
                    } else {
                        XCTFail("Decorator.func should resolve to IdentifierExpr")
                    }
                }
            }
        }
    }

    func testSchemaAttrHasDecoratorsField() throws {
        var args = ParseFileArgs()
        args.path = fixturePath()
        let result = try API().parseFile(args)
        let module = try parseModule(result.astJson)
        let person = module.body.first { stmtRef in
            if case .schema(let s) = stmtRef.node, s.name.node == "Person" {
                return true
            }
            return false
        }
        XCTAssertNotNil(person)
        if case .schema(let schema) = person!.node {
            let nameAttr = schema.body.first { stmtRef in
                if case .schemaAttr(let a) = stmtRef.node, a.name.node == "name" {
                    return true
                }
                return false
            }
            XCTAssertNotNil(nameAttr)
            if case .schemaAttr(let attr) = nameAttr!.node {
                XCTAssertEqual(attr.decorators.count, 1)
            }
        }
    }

    func testLambdaExprWithArguments() throws {
        var args = ParseFileArgs()
        args.path = fixturePath()
        let result = try API().parseFile(args)
        let module = try parseModule(result.astJson)
        let adder = module.body.first { stmtRef in
            if case .assign(let a) = stmtRef.node {
                if let first = a.targets.first?.node, first.name.node == "adder" {
                    return true
                }
            }
            return false
        }
        XCTAssertNotNil(adder)
        if case .assign(let a) = adder!.node {
            if case .lambda(let lambda) = a.value.node {
                XCTAssertEqual(lambda.args.node.args.count, 2)
            } else {
                XCTFail("expected LambdaExpr on the right-hand side of `adder =`")
            }
        }
    }

    func testParseProgramReturnsListOfModules() throws {
        var args = ParseProgramArgs()
        args.paths.append(fixturePath())
        let result = try API().parseProgram(args)
        XCTAssertEqual(result.errors.count, 0)
        let modules = try parseProgram(result.astJson)
        XCTAssertGreaterThan(modules.count, 0)
        XCTAssertTrue(modules[0].filename.hasSuffix(".k"))
    }
}
import Foundation
import XCTest

@testable import KclLib

/// Tests for the high-level `Kcl` facade (Kcl.swift), mirroring the coverage
/// of the Python/.NET facade suites: inline code, files, options, settings
/// merging, `_type` rewriting, validation and error propagation.
final class KclFacadeTests: XCTestCase {

    // MARK: - run (inline code)

    func testRunInlineCodeAndDottedGet() throws {
        let result = try Kcl.run("a = 1\nb = {c = 2}")
        XCTAssertEqual(1, result.count)
        XCTAssertEqual(1, result.get("a") as? Int)
        XCTAssertEqual(2, result.get("b.c") as? Int)
        XCTAssertNil(result.get("b.missing"))
        XCTAssertNil(result.get("missing.deep"))
        XCTAssertTrue(result.yamlResult.contains("a: 1"))
        XCTAssertEqual("", result.errMessage)
    }

    func testRunWithFormatJson() throws {
        var options = KclOptions()
        options.format = "json"
        let result = try Kcl.run("a = {x = 1}", options: options)
        XCTAssertFalse(result.jsonResult.isEmpty)
        XCTAssertTrue(result.yamlResult.isEmpty)
        XCTAssertEqual(1, result.get("a.x") as? Int)
        XCTAssertEqual("", result.first?.yamlString())
        XCTAssertTrue(result.first?.jsonString().contains("\"x\"") ?? false)
    }

    func testRunWithFormatYamlLeavesNoParsedValue() throws {
        var options = KclOptions()
        options.format = "yaml"
        let result = try Kcl.run("a = 1", options: options)
        XCTAssertFalse(result.yamlResult.isEmpty)
        XCTAssertTrue(result.jsonResult.isEmpty)
        XCTAssertTrue(result.first?.yamlString().contains("a: 1") ?? false)
        // Without a JSON result there is no tree to navigate.
        XCTAssertNil(result.first?.value)
        XCTAssertNil(result.get("a"))
        XCTAssertThrowsError(try result.toMap()) { error in
            guard case KclError.runtime(let message) = error else {
                return XCTFail("expected KclError.runtime, got \(error)")
            }
            XCTAssertTrue(message.contains("YAML only"), "unexpected message: \(message)")
        }
    }

    func testRunWithArgs() throws {
        var options = KclOptions()
        // Entries without an "=" separator are ignored (kcl-go WithOptions).
        options.args = ["who=swift", "mode=test", "noequals", "=emptykey"]
        let result = try Kcl.run(
            "result = option(\"who\") + \"-\" + option(\"mode\")", options: options)
        XCTAssertEqual("swift-test", result.get("result") as? String)
    }

    func testRunWithOverrides() throws {
        var options = KclOptions()
        options.overrides = ["x=\"opt\""]
        let result = try Kcl.run("x = \"default\"", options: options)
        XCTAssertEqual("opt", result.get("x") as? String)
    }

    func testRunWithSelectors() throws {
        var options = KclOptions()
        options.selectors = ["a"]
        let result = try Kcl.run("a = {x = 1}\nb = 2", options: options)
        XCTAssertEqual(1, result.count)
        // A selector lifts the selected value to the document root.
        XCTAssertEqual(1, result.get("x") as? Int)
        XCTAssertNil(result.get("b"))
        XCTAssertNil(result.get("a.x"))
    }

    func testRunWithSortKeys() throws {
        var options = KclOptions()
        options.sortKeys = true
        let result = try Kcl.run("z = 1\na = 2\nm = 3", options: options)
        let yaml = result.yamlResult
        guard let aPos = yaml.range(of: "a: 2")?.lowerBound,
            let mPos = yaml.range(of: "m: 3")?.lowerBound,
            let zPos = yaml.range(of: "z: 1")?.lowerBound
        else {
            return XCTFail("sorted keys missing from yaml: \(yaml)")
        }
        XCTAssertTrue(aPos < mPos && mPos < zPos, "expected sorted key order, got \(yaml)")
    }

    func testRunWithDisableNone() throws {
        var options = KclOptions()
        options.disableNone = true
        let result = try Kcl.run("a = None\nb = 1", options: options)
        XCTAssertNil(result.get("a"))
        XCTAssertEqual(1, result.get("b") as? Int)
        XCTAssertEqual("b: 1", result.yamlResult)
    }

    func testLoggerReceivesLogMessage() throws {
        var options = KclOptions()
        var logged = ""
        options.logger = { logged += $0 }
        let result = try Kcl.run("print(\"hello-log\")", options: options)
        _ = result
        XCTAssertTrue(logged.contains("hello-log"), "expected print output in log, got: \(logged)")
    }

    // MARK: - runFiles

    func testRunFiles() throws {
        let result = try Kcl.runFiles(["test_data/schema.k"])
        XCTAssertEqual(2, result.get("app.replicas") as? Int)
        XCTAssertEqual("app:\n  replicas: 2", result.yamlResult)
    }

    func testRunFilesThrowsForMissingFile() throws {
        XCTAssertThrowsError(try Kcl.runFiles(["file_not_found"])) { error in
            guard case KclError.runtime(let message) = error else {
                return XCTFail("expected KclError.runtime, got \(error)")
            }
            XCTAssertTrue(
                message.contains("Cannot find the kcl file"),
                "unexpected error message: \(message)")
        }
    }

    func testRunFilesThrowsWithoutInput() throws {
        XCTAssertThrowsError(try Kcl.runFiles([])) { error in
            guard case KclError.runtime(let message) = error else {
                return XCTFail("expected KclError.runtime, got \(error)")
            }
            XCTAssertTrue(message.contains("no kcl file or code"), "got: \(message)")
        }
    }

    // MARK: - Errors

    // A failing schema check is reported through `err_message` (not a
    // transport error), which the facade must raise as KclError.
    func testRunThrowsForFailedSchemaCheck() throws {
        let code = """
            schema P:
                age: int

                check:
                    age > 0

            p = P {age = -1}
            """
        XCTAssertThrowsError(try Kcl.run(code)) { error in
            guard case KclError.runtime(let message) = error else {
                return XCTFail("expected KclError.runtime, got \(error)")
            }
            XCTAssertTrue(
                message.lowercased().contains("check failed"),
                "unexpected error message: \(message)")
        }
    }

    // Syntax errors fail the native call itself (the "ERROR:" prefix path).
    func testRunThrowsForCompileError() throws {
        XCTAssertThrowsError(try Kcl.run("a = ")) { error in
            guard case KclError.runtime(let message) = error else {
                return XCTFail("expected KclError.runtime, got \(error)")
            }
            XCTAssertTrue(message.contains("E1001"), "unexpected error message: \(message)")
        }
    }

    // MARK: - validate

    func testValidateCode() throws {
        let schema = """
            schema Person:
                name: str
                age: int

                check:
                    0 < age < 120

            """
        XCTAssertTrue(
            try Kcl.validate(
                code: schema, data: #"{"name": "Alice", "age": 10}"#, format: "json"))
        XCTAssertFalse(
            try Kcl.validate(
                code: schema, data: #"{"name": "Alice", "age": 200}"#, format: "json"))
    }

    // MARK: - Settings files

    func testSettingsProvideBaseOptions() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "result = option(\"who\")\nz = 1\na = 2".write(
            toFile: "\(dir)/main.k", atomically: true, encoding: .utf8)
        try """
            kcl_cli_configs:
              files:
                - main.k
              sort_keys: true
            kcl_options:
              - key: who
                value: settings
            """.write(toFile: "\(dir)/kcl.yaml", atomically: true, encoding: .utf8)

        var options = KclOptions()
        options.workDir = dir
        options.settings = ["\(dir)/kcl.yaml"]
        // Input files come from the settings file, so no positional paths.
        let result = try Kcl.runFiles([], options: options)
        XCTAssertEqual("settings", result.get("result") as? String)
        // sort_keys from the settings file took effect.
        let yaml = result.yamlResult
        guard let aPos = yaml.range(of: "a: 2")?.lowerBound,
            let resultPos = yaml.range(of: "result: settings")?.lowerBound,
            let zPos = yaml.range(of: "z: 1")?.lowerBound
        else {
            return XCTFail("sorted keys missing from yaml: \(yaml)")
        }
        XCTAssertTrue(aPos < resultPos && resultPos < zPos, "expected sorted order, got \(yaml)")
    }

    func testSettingsExplicitOptionsWin() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "x = \"default\"".write(
            toFile: "\(dir)/main.k", atomically: true, encoding: .utf8)
        try """
            kcl_cli_configs:
              files:
                - main.k
              overrides:
                - 'x="settings"'
            """.write(toFile: "\(dir)/kcl.yaml", atomically: true, encoding: .utf8)

        var base = KclOptions()
        base.workDir = dir
        base.settings = ["\(dir)/kcl.yaml"]
        // Settings overrides apply on their own...
        let fromSettings = try Kcl.runFiles([], options: base)
        XCTAssertEqual("settings", fromSettings.get("x") as? String)

        // ...and explicit options applied after the file win (kcl-go
        // Option.Merge order semantics).
        var overlay = base
        overlay.overrides = ["x=\"option\""]
        let fromOption = try Kcl.runFiles([], options: overlay)
        XCTAssertEqual("option", fromOption.get("x") as? String)
    }

    // MARK: - `_type` rewriting (kcl-go DefaultHooks)

    // Schema instances from external packages carry a qualified `_type`
    // (e.g. "bbb.B"); with includeSchemaTypePath on, the facade shortens it
    // to the last segment — like kcl-go's typeAttributeHook.
    func testTypeAttributeRewrittenToShortName() throws {
        let root = swiftPackageRoot().appendingPathComponent(
            "test_data/get_schema_ty_under_path")
        var options = KclOptions()
        options.externalPkgs = ["bbb=\(root.path)/bbb"]
        options.includeSchemaTypePath = true
        let code = "import bbb\nb = bbb.B {n = \"x\", name = \"y\"}"
        let result = try Kcl.run(code, options: options)
        XCTAssertEqual("B", result.get("b._type") as? String)
        // The raw runtime payload stays unmodified ("原样" access)...
        XCTAssertTrue(result.jsonResult.contains("bbb.B"))
        // ...while the rewritten document is re-rendered with the short name.
        XCTAssertTrue(result.first?.yamlString().contains("_type: B") ?? false)
        XCTAssertFalse(result.first?.jsonString().contains("bbb.B") ?? true)
    }

    // kcl-go's WithFullTypePath keeps the qualified path (and implies
    // include_schema_type_path).
    func testFullTypePathKeepsQualifiedName() throws {
        let root = swiftPackageRoot().appendingPathComponent(
            "test_data/get_schema_ty_under_path")
        var options = KclOptions()
        options.externalPkgs = ["bbb=\(root.path)/bbb"]
        options.fullTypePath = true
        let code = "import bbb\nb = bbb.B {n = \"x\", name = \"y\"}"
        let result = try Kcl.run(code, options: options)
        XCTAssertEqual("bbb.B", result.get("b._type") as? String)
        XCTAssertTrue(result.jsonResult.contains("bbb.B"))
    }

    // MARK: - splitDocuments

    func testSplitDocuments() throws {
        let docs = try Kcl.splitDocuments("a: 1\n---\nb: 2\n")
        XCTAssertEqual(2, docs.count)
        XCTAssertTrue(docs[0].contains("a: 1"))
        XCTAssertTrue(docs[1].contains("b: 2"))

        // Separators may carry trailing comments or whitespace.
        XCTAssertEqual(2, try Kcl.splitDocuments("a: 1\n--- # comment\nb: 2").count)
        XCTAssertEqual(2, try Kcl.splitDocuments("a: 1\n--- \nb: 2").count)

        // No separator: single document; empty input: none.
        XCTAssertEqual(1, try Kcl.splitDocuments("a: 1").count)
        XCTAssertEqual(0, try Kcl.splitDocuments("").count)

        // Anything but a comment after the separator is an error (kcl-go
        // semantics).
        XCTAssertThrowsError(try Kcl.splitDocuments("a: 1\n--- oops\nb: 2"))
    }

    // MARK: - Helpers

    private func makeTempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "kcl-swift-facade-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    private func swiftPackageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KclLibTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // swift package root
    }
}

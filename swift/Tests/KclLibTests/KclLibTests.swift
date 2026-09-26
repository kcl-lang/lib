import XCTest

@testable import KclLib

final class KClLibTests: XCTestCase {
    func testExecProgram() throws {
        let api = API()
        var execArgs = ExecProgramArgs()
        execArgs.kFilenameList.append("test_data/schema.k")
        do {
            let result = try api.execProgram(execArgs)
            XCTAssertEqual("app:\n  replicas: 2", result.yamlResult)
        } catch {
            XCTFail("ExecProgram failed: \(error)")
        }
    }

    // Regression test for https://github.com/kcl-lang/kcl/issues/1546:
    // schemas coming from external dependency packages must keep their own
    // pkgpath and base schema instead of being misattributed to "__main__".
    func testGetSchemaTypeMappingUnderPath() throws {
        // Absolute paths are required: the engine resolves external package
        // pkgpaths against the work dir, relative paths are not stable.
        let swiftDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KclLibTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // swift package root
        let root = swiftDir.appendingPathComponent("test_data/get_schema_ty_under_path").path
        var bbbPkg = ExternalPkg()
        bbbPkg.pkgName = "bbb"
        bbbPkg.pkgPath = "\(root)/bbb"
        var execArgs = ExecProgramArgs()
        execArgs.kFilenameList.append("\(root)/aaa")
        execArgs.externalPkgs.append(bbbPkg)

        var args = GetSchemaTypeMappingArgs()
        args.execArgs = execArgs

        let result = try API().getSchemaTypeMappingUnderPath(args)
        let bbbSchemas = Dictionary(
            uniqueKeysWithValues: (result.schemaTypeMapping["bbb"]?.schemaType ?? []).map {
                ($0.schemaName, $0)
            })

        guard let base = bbbSchemas["Base"], let b = bbbSchemas["B"] else {
            XCTFail("expected schemas Base and B in bbb, got \(bbbSchemas.keys)")
            return
        }
        XCTAssertEqual("bbb", base.pkgPath)
        XCTAssertEqual("bbb", b.pkgPath)
        XCTAssertTrue(b.hasBaseSchema, "B.baseSchema must be resolved across the package boundary")
        XCTAssertEqual("Base", b.baseSchema.schemaName)
        XCTAssertEqual("bbb", b.baseSchema.pkgPath)
        XCTAssertNotNil(result.schemaTypeMapping["__main__"])
    }

    func testPing() throws {
        var args = PingArgs()
        args.value = "hello"
        let result = try API().ping(args)
        XCTAssertEqual("hello", result.value)
    }

    func testGetVersion() throws {
        let result = try API().getVersion(GetVersionArgs())
        XCTAssertFalse(result.version.isEmpty)
        XCTAssertFalse(result.versionInfo.isEmpty)
    }

    func testFormatCode() throws {
        let source = """
            schema Person:
                name:   str
                age:    int

                check:
                    0 <   age <   120

            """
        var args = FormatCodeArgs()
        args.source = source
        let result = try API().formatCode(args)
        let formatted = String(data: result.formatted, encoding: .utf8) ?? ""
        XCTAssertEqual(
            """
            schema Person:
                name: str
                age: int

                check:
                    0 < age < 120

            """, formatted)
    }

    func testLintPath() throws {
        var args = LintPathArgs()
        args.paths.append("test_data/lint_path/test-lint.k")
        let result = try API().lintPath(args)
        XCTAssertTrue(
            result.results.contains { $0.contains("Module 'math' imported but unused") },
            "expected unused-import warning, got \(result.results)")
    }

    func testValidateCode() throws {
        var args = ValidateCodeArgs()
        args.code = """
            schema Person:
                name: str
                age: int

                check:
                    0 < age < 120

            """
        args.data = #"{"name": "Alice", "age": 10}"#
        args.format = "json"
        let result = try API().validateCode(args)
        XCTAssertTrue(result.success)
        XCTAssertEqual("", result.errMessage)
    }

    func testParseProgram() throws {
        var args = ParseProgramArgs()
        args.paths.append("test_data/schema.k")
        let result = try API().parseProgram(args)
        XCTAssertEqual(1, result.paths.count)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(result.astJson.isEmpty)
    }

    func testListOptions() throws {
        var args = ParseProgramArgs()
        args.paths.append("test_data/option/main.k")
        let result = try API().listOptions(args)
        XCTAssertEqual(3, result.options.count)
        XCTAssertEqual("key1", result.options[0].name)
        XCTAssertEqual("key2", result.options[1].name)
        XCTAssertEqual("metadata-key", result.options[2].name)
    }

    func testRenameCode() throws {
        var args = RenameCodeArgs()
        args.packageRoot = "/mock/path"
        args.symbolPath = "a"
        args.sourceCodes = ["/mock/path/main.k": "a = 1\nb = a"]
        args.newName = "a2"
        let result = try API().renameCode(args)
        XCTAssertEqual("a2 = 1\nb = a2", result.changedCodes["/mock/path/main.k"])
    }

    // Native errors must surface as catchable Swift errors, not crashes:
    // https://github.com/kcl-lang/lib regression — `callNative` used to
    // `fatalError` on the ERROR: prefix, killing the process mid-test.
    func testExecProgramErrorThrows() throws {
        var args = ExecProgramArgs()
        args.kFilenameList.append("file_not_found")
        do {
            _ = try API().execProgram(args)
            XCTFail("expected KclError for a missing kcl file")
        } catch let error as KclError {
            XCTAssertTrue(
                error.message.contains("Cannot find the kcl file"),
                "unexpected error message: \(error.message)")
        }
    }

    // Pure protobuf round-trip — does not require the native FFI to be running.
    // Covers the new `format` (20), `error_format` (19) and `sourcemap_output`
    // (22) fields on ExecProgramArgs plus `sourcemap` (5) on ExecProgramResult.
    func testExecProgramArgsFormatRoundTrip() throws {
        var args = ExecProgramArgs()
        args.format = "json"
        args.errorFormat = "sarif"
        args.sourcemapOutput = "/tmp/out.js.map"

        let wire = try args.serializedData()
        let roundTripped = try ExecProgramArgs(serializedData: wire)

        XCTAssertEqual("json", roundTripped.format)
        XCTAssertEqual("sarif", roundTripped.errorFormat)
        XCTAssertTrue(roundTripped.hasSourcemapOutput)
        XCTAssertEqual("/tmp/out.js.map", roundTripped.sourcemapOutput)
    }

    func testExecProgramResultSourcemapRoundTrip() throws {
        var result = ExecProgramResult()
        result.jsonResult = "{\"a\": 1}"
        result.yamlResult = "a: 1"
        result.sourcemap = "{\"version\":3,\"sources\":[]}"

        let wire = try result.serializedData()
        let roundTripped = try ExecProgramResult(serializedData: wire)

        XCTAssertTrue(roundTripped.hasSourcemap)
        XCTAssertEqual("{\"version\":3,\"sources\":[]}", roundTripped.sourcemap)
    }
}

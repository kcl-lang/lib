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

    // Pure protobuf round-trip — covers the new `emit_attribute_metadata` (21)
    // field on ExecProgramArgs and the coverage messages (TestArgs.coverage 5,
    // TestResult.coverage 3, TestCaseInfo.line_hits 5, FileCoverage,
    // TestCoverageReport, CoverageSummary) added in the latest spec sync.
    func testCoverageAndAttributeMetadataRoundTrip() throws {
        var args = ExecProgramArgs()
        args.emitAttributeMetadata = true

        var testArgs = TestArgs()
        testArgs.coverage = true

        var result = TestResult()
        var caseInfo = TestCaseInfo()
        caseInfo.name = "test_func_0"
        caseInfo.lineHits = ["pkg/func.k:1": 1]
        result.info.append(caseInfo)
        var fileCoverage = FileCoverage()
        fileCoverage.filename = "pkg/func.k"
        fileCoverage.coveredLines = [1, 3]
        fileCoverage.executableLines = [1, 3]
        fileCoverage.lineHits = [1: 1, 3: 2]
        var summary = CoverageSummary()
        summary.covered = 2
        summary.executable = 2
        summary.percent = 100.0
        result.coverage.files["pkg/func.k"] = fileCoverage
        result.coverage.summary = summary

        let argsWire = try args.serializedData()
        XCTAssertTrue(try ExecProgramArgs(serializedData: argsWire).emitAttributeMetadata)
        let testArgsWire = try testArgs.serializedData()
        XCTAssertTrue(try TestArgs(serializedData: testArgsWire).coverage)

        let resultWire = try result.serializedData()
        let roundTripped = try TestResult(serializedData: resultWire)
        XCTAssertTrue(roundTripped.hasCoverage)
        XCTAssertEqual(1, roundTripped.info.count)
        XCTAssertEqual(["pkg/func.k:1": 1], roundTripped.info[0].lineHits)
        let file = try XCTUnwrap(roundTripped.coverage.files["pkg/func.k"])
        XCTAssertEqual([1, 3], file.coveredLines)
        XCTAssertEqual([1: 1, 3: 2], file.lineHits)
        XCTAssertEqual(2, roundTripped.coverage.summary.covered)
        XCTAssertEqual(2, roundTripped.coverage.summary.executable)
        XCTAssertEqual(100.0, roundTripped.coverage.summary.percent)
    }

    func testLoadPackage() throws {
        var args = LoadPackageArgs()
        args.parseArgs.paths.append("test_data/schema.k")
        args.resolveAst = true

        let result = try API().loadPackage(args)
        XCTAssertTrue(result.parseErrors.isEmpty)
        XCTAssertTrue(
            result.symbols.values.contains { $0.ty.schemaName == "AppConfig" },
            "expected a symbol with schema name 'AppConfig' in \(result.symbols.values.map { $0.name })")
    }

    func testListVariables() throws {
        var args = ListVariablesArgs()
        args.files.append("test_data/schema.k")

        let result = try API().listVariables(args)
        guard let appVar = result.variables["app"] else {
            XCTFail("expected variable 'app', got \(result.variables.keys)")
            return
        }
        XCTAssertFalse(appVar.variables.isEmpty)
        XCTAssertEqual("AppConfig {\n    replicas = 2\n}", appVar.variables[0].value)
    }

    func testGetSchemaTypeMapping() throws {
        var args = GetSchemaTypeMappingArgs()
        args.execArgs.kFilenameList.append("test_data/schema.k")

        let result = try API().getSchemaTypeMapping(args)
        guard let appSchema = result.schemaTypeMapping["app"] else {
            XCTFail("expected schema 'app', got \(result.schemaTypeMapping.keys)")
            return
        }
        XCTAssertEqual("schema", appSchema.type)
        guard let replicas = appSchema.properties["replicas"] else {
            XCTFail("expected property 'replicas', got \(appSchema.properties.keys)")
            return
        }
        XCTAssertEqual("int", replicas.type)
    }

    // OverrideFile rewrites the target file in place, so operate on a copy in
    // a unique temp dir and leave the checked-in fixture untouched.
    func testOverrideFile() throws {
        let tmpFile = try copyFixtureToTemp("test_data/override_file/main.k", as: "main.k")

        var args = OverrideFileArgs()
        args.file = tmpFile.path
        args.specs.append("b.a=2")

        let result = try API().overrideFile(args)
        XCTAssertTrue(result.result)
        XCTAssertTrue(result.parseErrors.isEmpty)

        let content = try String(contentsOf: tmpFile, encoding: .utf8)
        XCTAssertEqual(
            """
            a = 1
            b = {
                "a": 2
                "b": 2
            }

            """, content)
    }

    // FormatPath mutates files in place, so operate on a copy in a unique
    // temp dir and rewrite it with unformatted source first.
    func testFormatPath() throws {
        let tmpFile = try copyFixtureToTemp("test_data/format_path/test.k", as: "test.k")
        try "a   =   1\n".write(to: tmpFile, atomically: true, encoding: .utf8)

        var args = FormatPathArgs()
        args.path = tmpFile.path

        let result = try API().formatPath(args)
        // FileManager.default.temporaryDirectory lives under /var, a symlink
        // to /private/var — the runtime may report either spelling.
        let resolved = tmpFile.resolvingSymlinksInPath().path
        XCTAssertTrue(
            result.changedPaths.contains(tmpFile.path) || result.changedPaths.contains(resolved),
            "expected changed path \(tmpFile.path), got \(result.changedPaths)")
        XCTAssertEqual("a = 1\n", try String(contentsOf: tmpFile, encoding: .utf8))

        // Once formatted, nothing is reported as changed.
        let second = try API().formatPath(args)
        XCTAssertTrue(second.changedPaths.isEmpty)
    }

    // Rename rewrites the target files in place, so operate on a copy in a
    // unique temp dir and leave the checked-in fixture untouched.
    func testRename() throws {
        let tmpFile = try copyFixtureToTemp("test_data/rename/main.bak", as: "main.k")

        var args = RenameArgs()
        args.packageRoot = tmpFile.deletingLastPathComponent().path
        args.symbolPath = "a"
        args.filePaths.append(tmpFile.path)
        args.newName = "a2"

        let result = try API().rename(args)
        // The runtime canonicalizes paths before returning them
        // (/var/... becomes /private/var/... on macOS), so match the
        // unique temp dir name rather than an exact path spelling.
        let dirName = tmpFile.deletingLastPathComponent().lastPathComponent
        XCTAssertEqual(1, result.changedFiles.count)
        XCTAssertTrue(
            result.changedFiles[0].hasSuffix("/\(dirName)/main.k"),
            "expected changed file for \(tmpFile.path), got \(result.changedFiles)")
        XCTAssertEqual("a2 = 1\nb = a2", try String(contentsOf: tmpFile, encoding: .utf8))
    }

    func testTest() throws {
        var args = TestArgs()
        args.pkgList.append("test_data/testing/...")
        args.coverage = true

        let result = try API().test(args)
        XCTAssertEqual(2, result.info.count)
        for info in result.info {
            XCTAssertTrue(info.error.isEmpty, "test case \(info.name) failed: \(info.error)")
        }

        // Line-level coverage was requested: the runtime returns the
        // aggregated report plus per-case line hits.
        XCTAssertTrue(result.hasCoverage)
        XCTAssertFalse(result.coverage.files.isEmpty)
        XCTAssertGreaterThan(result.coverage.summary.executable, 0)
        XCTAssertTrue(
            result.info.contains { !$0.lineHits.isEmpty },
            "expected per-case line hits with coverage enabled")
    }

    // Downloads the dependencies declared in the fixture kcl.mod
    // (helloworld from OCI, flask from git) — requires network access.
    func testUpdateDependencies() throws {
        var args = UpdateDependenciesArgs()
        args.manifestPath = "test_data/update_dependencies"

        let result = try API().updateDependencies(args)
        let names = result.externalPkgs.map { $0.pkgName }
        XCTAssertEqual(2, names.count)
        XCTAssertTrue(names.contains("helloworld"), "expected 'helloworld' in \(names)")
        XCTAssertTrue(names.contains("flask"), "expected 'flask' in \(names)")
    }

    func testLoadSettingsFiles() throws {
        var args = LoadSettingsFilesArgs()
        args.workDir = "test_data"
        args.files.append("test_data/settings/kcl.yaml")

        let result = try API().loadSettingsFiles(args)
        XCTAssertTrue(result.kclCliConfigs.strictRangeCheck)
        XCTAssertEqual(1, result.kclOptions.count)
        XCTAssertEqual("key", result.kclOptions[0].key)
        XCTAssertEqual("\"value\"", result.kclOptions[0].value)
    }

    /// Copies a fixture from the package's `test_data` dir into a unique
    /// temp dir so tests that rewrite files never mutate the checked-in
    /// fixtures. Returns the URL of the copy.
    private func copyFixtureToTemp(_ relativePath: String, as name: String) throws -> URL {
        let swiftDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KclLibTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // swift package root
        let source = swiftDir.appendingPathComponent(relativePath)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kcllib-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: dest)
        return dest
    }
}

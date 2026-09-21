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
}

import XCTest

@testable import KclLib

final class KClLibTests: XCTestCase {
    func testExecProgram() throws {
        let api = API()
        var execArgs = ExecProgram_Args()
        execArgs.kFilenameList.append("test_data/schema.k")
        do {
            let result = try api.execProgram(execArgs)
            XCTAssertEqual("app:\n  replicas: 2", result.yamlResult)
        } catch {
            XCTFail("ExecProgram failed: \(error)")
        }
    }
}

// ConsistencyTest.swift — Cross-language consistency runner for the Swift
// binding.
//
// Executes the hermetic cases from `tests/consistency/cases.json` (generated
// by `tests/consistency/generate_cases.py`) and asserts the same golden
// expectations as the Python, Node.js, Go, Java and .NET runners. The point
// is that all six read the *same* manifest, so a wrapper that drops a field,
// mangles an escape sequence or resolves a relative path differently fails
// here rather than drifting silently.
//
// Run from the `swift` package directory:
//
//     make test
//     swift test --filter ConsistencyTest
//
// The manifest is read through `#filePath` rather than the working directory:
// XCTest runs each case in a fresh process whose cwd is not guaranteed to be
// the package root, and `swift test --package-path` is invoked from all over
// the tree in CI.

import Foundation
import XCTest

@testable import KclLib

final class ConsistencyTest: XCTestCase {
    // MARK: - Manifest

    // `KclLib` declares a protobuf message named `Error`, which shadows
    // `Swift.Error` in any file that imports it — so every reference to the
    // error protocol below is spelled `Swift.Error` explicitly.

    /// One entry of `tests/consistency/cases.json`.
    private struct ConsistencyCase {
        let name: String
        let rpc: String
        /// `true` for RPCs that only exist on recent cores; those are skipped
        /// rather than failed when the loaded core does not list them.
        let newCore: Bool
        let args: [String: Any]
        let expect: [String: Any]
    }

    private struct ManifestError: Swift.Error, CustomStringConvertible {
        let description: String
    }

    /// The manifest, keyed by case name.
    private static var cases: [String: ConsistencyCase]?

    /// The RPC surface of the loaded core, resolved once per run.
    private static var availableMethods: Set<String>?

    private static let api = API()

    /// `<repo>/tests/consistency/cases.json`. `#filePath` is the compile-time
    /// location of *this* source file, so the path is stable no matter which
    /// directory `swift test` was launched from.
    private static let casesJSON: URL = {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KclLibTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // swift package root
            .deletingLastPathComponent()  // repo root
        return repoRoot.appendingPathComponent("tests/consistency/cases.json")
    }()

    /// Repository root — the grand-parent of the directory holding
    /// `cases.json`. `generate_cases.py` pins `parse_args.paths` as
    /// repo-relative, and the core needs them absolute or it cannot find the
    /// fixture.
    private static let repoRoot: URL = {
        let consistencyDir = casesJSON.deletingLastPathComponent()  // tests/consistency
        return consistencyDir.deletingLastPathComponent()  // tests
            .deletingLastPathComponent()  // repo root
    }()

    private static func manifest() throws -> [String: ConsistencyCase] {
        if let cases { return cases }

        let path = casesJSON.path
        guard FileManager.default.fileExists(atPath: path) else {
            let message =
                "consistency manifest not found at \(path). Run "
                + "`python tests/consistency/generate_cases.py` to generate it."
            XCTFail(message)
            throw ManifestError(description: message)
        }
        let data = try Data(contentsOf: casesJSON)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("consistency manifest at \(path) is not a JSON object")
            throw ManifestError(description: "manifest root is not an object")
        }
        guard let version = (root["version"] as? NSNumber)?.intValue, version == 1 else {
            let message =
                "unsupported consistency manifest version: "
                + "\(root["version"] ?? "missing")"
            XCTFail(message)
            throw ManifestError(description: message)
        }
        guard let rawCases = root["cases"] as? [[String: Any]] else {
            XCTFail("consistency manifest at \(path) has no `cases` array")
            throw ManifestError(description: "manifest has no cases array")
        }

        var parsed: [String: ConsistencyCase] = [:]
        for raw in rawCases {
            guard let name = raw["name"] as? String, let rpc = raw["rpc"] as? String else {
                XCTFail("consistency case without a name/rpc: \(raw)")
                continue
            }
            parsed[name] = ConsistencyCase(
                name: name,
                rpc: rpc,
                newCore: (raw["new_core"] as? NSNumber)?.boolValue ?? false,
                args: raw["args"] as? [String: Any] ?? [:],
                expect: raw["expect"] as? [String: Any] ?? [:]
            )
        }
        cases = parsed
        return parsed
    }

    private static func manifestCase(named name: String) throws -> ConsistencyCase {
        guard let found = try manifest()[name] else {
            let message = "consistency case not found in manifest: \(name)"
            XCTFail(message)
            throw ManifestError(description: message)
        }
        return found
    }

    /// The RPC surface of the loaded core, resolved once per run. Cores that
    /// predate `BuiltinService.ListMethod` answer with an empty list (or
    /// throw), in which case `new_core` cases are skipped.
    ///
    /// This gate is the load-bearing one, and it is not redundant with a
    /// try/catch around the call: the C dispatcher answers a method it does
    /// not know by panicking, then returns the `ERROR:…` string *without*
    /// writing a result length, so the caller reads zero bytes and protobuf
    /// hands back a default-valued message. An unknown RPC therefore looks
    /// like a successful call returning `""`, not like an error.
    private static func methods() -> Set<String> {
        if let availableMethods { return availableMethods }
        var names: Set<String> = []
        if let result = try? api.listMethod() {
            names = Set(result.methodNameList)
        }
        availableMethods = names
        return names
    }

    // MARK: - Driving one case

    private func runCase(_ name: String) throws {
        let testCase = try Self.manifestCase(named: name)
        let rpc = testCase.rpc

        if testCase.newCore && !Self.methods().contains(rpc) {
            throw XCTSkip(
                "core does not list \(rpc) (old core); regenerate cases.json against a new core to enable"
            )
        }

        let actual = try Self.call(rpc: rpc, args: testCase.args)

        // Compare only the fields the manifest actually pins, so a new field
        // in `expect` is picked up here rather than being silently ignored.
        for (field, expected) in testCase.expect {
            guard let got = actual[field] else {
                XCTFail("consistency case `\(name)`: result has no field `\(field)`")
                continue
            }
            assertField(name: name, field: field, expected: expected, actual: got)
        }
    }

    private func assertField(name: String, field: String, expected: Any, actual: Any) {
        if let expected = expected as? String, let actual = actual as? String {
            if expected != actual {
                XCTFail(
                    "consistency case `\(name)` field `\(field)` mismatch:\n"
                        + Self.diff(expected, actual)
                )
            }
            return
        }
        // `JSONSerialization` boxes booleans in `NSNumber`; the result side is
        // a real `Bool`. Anything else is a manifest/result shape mismatch and
        // is reported as such rather than coerced.
        if let expected = expected as? NSNumber, let actual = actual as? Bool {
            if expected.boolValue != actual {
                XCTFail(
                    "consistency case `\(name)` field `\(field)`: expected \(expected.boolValue), got \(actual)"
                )
            }
            return
        }
        XCTFail(
            "consistency case `\(name)` field `\(field)`: expected \(expected) "
                + "(\(type(of: expected))), got \(actual) (\(type(of: actual)))"
        )
    }

    /// Line-oriented diff for failure output. These payloads are multi-KB
    /// JSON/YAML/Markdown documents, so an `XCTAssertEqual` failure message
    /// alone is unreadable.
    private static func diff(_ expected: String, _ actual: String) -> String {
        let expectedLines = expected.split(separator: "\n", omittingEmptySubsequences: false).map(
            String.init
        )
        let actualLines = actual.split(separator: "\n", omittingEmptySubsequences: false).map(
            String.init
        )
        var out = "--- expected\n+++ actual\n"
        for index in 0..<max(expectedLines.count, actualLines.count) {
            let e = index < expectedLines.count ? expectedLines[index] : nil
            let a = index < actualLines.count ? actualLines[index] : nil
            if e == a {
                out += "  \(e ?? "")\n"
                continue
            }
            if let e { out += "- \(e)\n" }
            if let a { out += "+ \(a)\n" }
        }
        return out
    }

    // MARK: - Request building / dispatch

    private static func call(rpc: String, args: [String: Any]) throws -> [String: Any] {
        switch rpc {
        case "KclService.Ping":
            var request = PingArgs()
            request.value = string(args, "value")
            return ["value": try api.ping(request).value]

        case "KclService.ExecProgram":
            var request = ExecProgramArgs()
            request.kCodeList = stringList(args, "k_code_list")
            request.overrides = stringList(args, "overrides")
            let result = try api.execProgram(request)
            return ["yaml_result": result.yamlResult, "json_result": result.jsonResult]

        case "KclService.FormatCode":
            var request = FormatCodeArgs()
            request.source = string(args, "source")
            // `FormatCodeResult.formatted` is `bytes` on the wire; the manifest
            // pins it as a UTF-8 string.
            let formatted = try api.formatCode(request).formatted
            return ["formatted": String(data: formatted, encoding: .utf8) ?? ""]

        case "KclService.ValidateCode":
            var request = ValidateCodeArgs()
            request.code = string(args, "code")
            request.data = string(args, "data")
            let result = try api.validateCode(request)
            return ["success": result.success, "err_message": result.errMessage]

        case "KclService.FormatTestReport":
            var result = TestResult()
            for raw in (args["result"] as? [String: Any] ?? [:])["info"] as? [Any] ?? [] {
                guard let info = raw as? [String: Any] else { continue }
                var testCaseInfo = TestCaseInfo()
                testCaseInfo.name = string(info, "name")
                testCaseInfo.error = string(info, "error")
                testCaseInfo.duration = uint64(info["duration"])
                testCaseInfo.logMessage = string(info, "log_message")
                result.info.append(testCaseInfo)
            }
            var request = FormatTestReportArgs()
            request.result = result
            return ["report": try api.formatTestReport(request).report]

        case "KclService.GenerateToml":
            var request = GenerateTomlArgs()
            // Only the fields the manifest varies are forwarded; the rest of
            // `exec_args` is pinned to proto defaults in `cases.json`.
            request.execArgs.kCodeList = stringList(
                args["exec_args"] as? [String: Any] ?? [:],
                "k_code_list"
            )
            request.sortKeys = boolean(args, "sort_keys")
            return ["toml": try api.generateToml(request).toml]

        case "KclService.GenerateKcl":
            var request = GenerateKclArgs()
            request.source = string(args, "source")
            request.filename = string(args, "filename")
            request.format = string(args, "format")
            return ["kcl": try api.generateKcl(request).kcl]

        case "KclService.GenerateOpenAPI":
            var request = GenerateOpenAPIArgs()
            request.parseArgs = parseArgs(args["parse_args"] as? [String: Any] ?? [:])
            request.version = string(args, "version")
            return ["spec": try api.generateOpenAPI(request).spec]

        case "KclService.GenerateProto":
            var request = GenerateProtoArgs()
            request.parseArgs = parseArgs(args["parse_args"] as? [String: Any] ?? [:])
            request.package = string(args, "package")
            return ["proto": try api.generateProto(request).proto]

        case "KclService.GenerateDoc":
            var request = GenerateDocArgs()
            request.parseArgs = parseArgs(args["parse_args"] as? [String: Any] ?? [:])
            request.format = string(args, "format")
            return ["content": try api.generateDoc(request).content]

        default:
            throw ManifestError(description: "no runner support for rpc \(rpc)")
        }
    }

    /// Builds `ParseProgramArgs` for the schema-driven generation RPCs. Path
    /// entries are pinned repo-relative by `generate_cases.py`; they are
    /// resolved against the repository root while absolute entries are kept
    /// as-is.
    private static func parseArgs(_ node: [String: Any]) -> ParseProgramArgs {
        var parseArgs = ParseProgramArgs()
        for entry in stringList(node, "paths") {
            parseArgs.paths.append(URL(fileURLWithPath: entry, relativeTo: repoRoot).path)
        }
        parseArgs.sources = stringList(node, "sources")
        return parseArgs
    }

    // MARK: - Manifest accessors
    //
    // Every argument in `cases.json` is optional as far as the runner is
    // concerned — the manifest is generated, and a future case may drop a
    // field that is present today. Reading through these helpers keeps that
    // from turning into a crash.

    private static func string(_ dict: [String: Any], _ key: String) -> String {
        dict[key] as? String ?? ""
    }

    private static func stringList(_ dict: [String: Any], _ key: String) -> [String] {
        (dict[key] as? [Any])?.compactMap { $0 as? String } ?? []
    }

    private static func boolean(_ dict: [String: Any], _ key: String) -> Bool {
        (dict[key] as? NSNumber)?.boolValue ?? false
    }

    /// `TestCaseInfo.duration` is a `uint64` microsecond count. The manifest
    /// spells it as a JSON string (protobuf JSON mapping for 64-bit values),
    /// but a plain number is accepted too.
    private static func uint64(_ value: Any?) -> UInt64 {
        if let text = value as? String { return UInt64(text) ?? 0 }
        if let number = value as? NSNumber { return number.uint64Value }
        return 0
    }

    // MARK: - Cases

    func testPing() throws {
        try runCase("ping")
    }

    func testExecProgramBasic() throws {
        try runCase("exec_program_basic")
    }

    func testExecProgramOverrides() throws {
        try runCase("exec_program_overrides")
    }

    func testFormatCode() throws {
        try runCase("format_code")
    }

    func testValidateCodeOk() throws {
        try runCase("validate_code_ok")
    }

    func testValidateCodeInvalid() throws {
        try runCase("validate_code_invalid")
    }

    func testGenerateKclJson() throws {
        try runCase("generate_kcl_json")
    }

    func testGenerateKclYaml() throws {
        try runCase("generate_kcl_yaml")
    }

    func testGenerateToml() throws {
        try runCase("generate_toml")
    }

    func testFormatTestReport() throws {
        try runCase("format_test_report")
    }

    func testGenerateOpenAPIV3() throws {
        try runCase("generate_openapi_v3")
    }

    func testGenerateProto() throws {
        try runCase("generate_proto")
    }

    func testGenerateDocMd() throws {
        try runCase("generate_doc_md")
    }

    /// Guards against the failure mode the per-case methods above cannot see:
    /// a case added to `cases.json` that this runner never executes, which
    /// would look like a passing Swift suite while quietly dropping coverage.
    func testEveryManifestCaseHasARunner() throws {
        let covered: Set<String> = [
            "ping",
            "exec_program_basic",
            "exec_program_overrides",
            "format_code",
            "validate_code_ok",
            "validate_code_invalid",
            "generate_kcl_json",
            "generate_kcl_yaml",
            "generate_toml",
            "format_test_report",
            "generate_openapi_v3",
            "generate_proto",
            "generate_doc_md",
        ]
        let missing = Set(try Self.manifest().keys).subtracting(covered).sorted()
        XCTAssertEqual(
            missing,
            [],
            "cases.json has cases this runner does not execute; add a test method for each"
        )
    }
}

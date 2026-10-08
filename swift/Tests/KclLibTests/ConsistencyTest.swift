// ConsistencyTest.swift — Cross-language consistency runner for the Swift
// binding.
//
// Executes the hermetic cases from `tests/consistency/cases.json` (generated
// by `tests/consistency/generate_cases.py`) and asserts the same golden
// expectations as the Python, Node.js, Go, Java and .NET runners. The point
// is that all six read the *same* manifest, so a wrapper that drops a field,
// mangles an escape sequence or resolves a relative path differently fails
// here rather than drifting silently. Each case is projected to the fields the
// manifest pins — never to the whole RPC response, which is full of paths and
// versions that legitimately differ between machines.
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
import SwiftProtobuf
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

    /// Templates the `scratch:` paths are copied out of.
    private static let testdata = repoRoot.appendingPathComponent("tests/consistency/testdata")

    /// The marker `generate_cases.py` writes into a path that names a template
    /// rather than a file. `scratch:a/b.k` means "b.k inside a copy of
    /// `testdata/a`"; the copy is what makes the RPCs that write files safe
    /// to run, and it is also why the expectations for those cases pin the
    /// RPC's answer rather than a path.
    private static let scratchPrefix = "scratch:"

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
        // Counts, lists and the schema-mapping documents. Both sides render to
        // JSON with every object key sorted first, which is the only way the
        // two can be compared: a `KclType` holds two protobuf maps, and the
        // `Dictionary` they decode into has no defined order.
        let wantKind = Self.jsonKind(expected)
        let gotKind = Self.jsonKind(actual)
        guard wantKind == gotKind else {
            XCTFail(
                "consistency case `\(name)` field `\(field)`: expected \(expected) "
                    + "(\(wantKind)), got \(actual) (\(gotKind))"
            )
            return
        }
        let want = Self.jsonText(expected)
        let got = Self.jsonText(actual)
        if want != got {
            XCTFail(
                "consistency case `\(name)` field `\(field)` mismatch:\n"
                    + Self.diff(want, got)
            )
        }
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

    // MARK: - JSON rendering
    //
    // A count, a list and a whole schema-mapping document are all compared
    // the same way: rendered to JSON on both sides and compared as text. That
    // is what lets one assertion cover every field the manifest pins, and it
    // is only sound because the rendering is canonical.

    /// Renders a JSON-shaped value with every object key in lexicographic
    /// order, at every depth. `JSONSerialization` sorts nested objects too and
    /// pretty-prints, which is what makes a mismatch buried in a
    /// schema-mapping document readable in a failure message.
    private static func jsonText(_ value: Any) -> String {
        if value is [Any] || value is [String: Any],
            let data = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.prettyPrinted, .sortedKeys]
            )
        {
            return String(decoding: data, as: UTF8.self)
        }
        // A scalar goes through the same encoder wrapped in an array, which is
        // the only top-level shape it accepts, and then has the brackets
        // trimmed off. Doing the rendering here rather than by hand is what
        // keeps a `Bool` a `true`: `JSONSerialization` boxes both a manifest
        // boolean and a count in `NSNumber`, so the two are the same class and
        // no cast in Swift can tell them apart.
        guard let data = try? JSONSerialization.data(withJSONObject: [value]) else {
            return String(describing: value)
        }
        let text = String(decoding: data, as: UTF8.self)
        return String(text.dropFirst().dropLast())
    }

    /// The JSON shape of a value, so a projection that returns `""` where the
    /// manifest pins `0` is a mismatch rather than an accidental pass. A
    /// boolean is not separated from a number here: `jsonText` renders them
    /// differently anyway, so a `true` where the manifest pins `0` is caught
    /// by the comparison with the better message.
    private static func jsonKind(_ value: Any) -> String {
        switch value {
        case is [Any]: return "array"
        case is [String: Any]: return "object"
        case is String: return "string"
        default: return "scalar"
        }
    }

    // MARK: - Request building / dispatch

    private static func call(rpc: String, args: [String: Any]) throws -> [String: Any] {
        switch rpc {
        case "KclService.Ping":
            var request = PingArgs()
            request.value = string(args, "value")
            return ["value": try api.ping(request).value]

        case "KclService.ExecProgram":
            let result = try api.execProgram(try execArgs(args))
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
            request.format = string(args, "format")
            let result = try api.validateCode(request)
            // `err_message` carries ANSI colour escapes, a random temp path and
            // a temp filename, so the diagnostic itself is not pinnable but
            // its presence is. Both spellings are projected: `validate_code_ok`
            // pins the empty string and `validate_code_invalid` pins the
            // boolean.
            return [
                "success": result.success,
                "err_message": result.errMessage,
                "has_error_message": !result.errMessage.isEmpty,
            ]

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
            request.execArgs = try execArgs(args["exec_args"] as? [String: Any] ?? [:])
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
            request.parseArgs = try parseArgs(args["parse_args"] as? [String: Any] ?? [:])
            request.version = string(args, "version")
            return ["spec": try api.generateOpenAPI(request).spec]

        case "KclService.GenerateProto":
            var request = GenerateProtoArgs()
            request.parseArgs = try parseArgs(args["parse_args"] as? [String: Any] ?? [:])
            request.package = string(args, "package")
            return ["proto": try api.generateProto(request).proto]

        case "KclService.GenerateDoc":
            var request = GenerateDocArgs()
            request.parseArgs = try parseArgs(args["parse_args"] as? [String: Any] ?? [:])
            request.format = string(args, "format")
            return ["content": try api.generateDoc(request).content]

        case "KclService.ParseFile":
            var request = ParseFileArgs()
            request.path = string(args, "path")
            request.source = string(args, "source")
            request.externalPkgs = externalPkgs(args["external_pkgs"])
            let result = try api.parseFile(request)
            // A bare `Module` document, so its statements are at `body` and
            // its dependencies are a flat list.
            let module = try astDocument(result.astJson)
            return [
                "body_count": (module["body"] as? [Any])?.count ?? 0,
                "error_count": result.errors.count,
                "deps": result.deps,
            ]

        case "KclService.ParseProgram":
            let result = try api.parseProgram(try parseArgs(args))
            // A `pkgs` document rather than a module: one Module per file,
            // keyed by package path.
            let pkgs = try astDocument(result.astJson)["pkgs"] as? [String: Any] ?? [:]
            return [
                "module_count": (pkgs["__main__"] as? [Any])?.count ?? 0,
                "error_count": result.errors.count,
                "paths": result.paths.map(basename),
            ]

        case "KclService.ListOptions":
            let result = try api.listOptions(try parseArgs(args))
            return [
                "option_count": result.options.count,
                // Sorted: the core makes no promise about the order it reports
                // the program's options in, and the manifest pins one.
                "options": result.options.map { [$0.name, $0.required] as [Any] }
                    .sorted { ($0[0] as? String ?? "") < ($1[0] as? String ?? "") },
            ]

        case "KclService.ListVariables":
            var request = ListVariablesArgs()
            request.files = try resolvePaths(args["files"])
            request.specs = stringList(args, "specs")
            request.options.mergeProgram = boolean(
                args["options"] as? [String: Any] ?? [:],
                "merge_program"
            )
            let result = try api.listVariables(request)
            var values: [String: Any] = [:]
            for spec in result.variables.keys.sorted() {
                values[spec] = result.variables[spec]?.variables.map(\.value) ?? []
            }
            return [
                "values": values,
                "unsupported_codes": result.unsupportedCodes,
                "parse_error_count": result.parseErrors.count,
            ]

        case "KclService.LoadPackage":
            var request = LoadPackageArgs()
            request.parseArgs = try parseArgs(args["parse_args"] as? [String: Any] ?? [:])
            request.resolveAst = boolean(args, "resolve_ast")
            request.loadBuiltin = boolean(args, "load_builtin")
            request.withAstIndex = boolean(args, "with_ast_index")
            let result = try api.loadPackage(request)
            return [
                "path_count": result.paths.count,
                "type_error_count": result.typeErrors.count,
                "parse_error_count": result.parseErrors.count,
                "symbol_count": result.symbols.count,
                "scope_count": result.scopes.count,
                "has_kcl_mod": result.hasKclMod,
                "kcl_mod_name": result.hasKclMod ? result.kclMod.package.name : "",
                "app_count": result.apps.count,
                "import_count": result.imports.count,
            ]

        case "KclService.GetSchemaTypeMapping":
            let result = try api.getSchemaTypeMapping(try schemaTypeMappingArgs(args))
            return ["type_mapping": try kclTypes(result.schemaTypeMapping)]

        case "KclService.GetSchemaTypeMappingUnderPath":
            let result = try api.getSchemaTypeMappingUnderPath(try schemaTypeMappingArgs(args))
            return ["type_mapping": try kclTypes(result.schemaTypeMapping)]

        case "KclService.GetVersion":
            let result = try api.getVersion(GetVersionArgs())
            return [
                "version": majorMinor(result.version),
                "has_checksum": !result.checksum.isEmpty,
                "has_git_sha": !result.gitSha.isEmpty,
                "has_version_info": !result.versionInfo.isEmpty,
            ]

        case "BuiltinService.ListMethod":
            let names = try api.listMethod().methodNameList
            return [
                "has_kclservice_ping": names.contains("KclService.Ping"),
                "has_kclservice_parse_program": names.contains("KclService.ParseProgram"),
                "has_builtinservice_list_method": names.contains("BuiltinService.ListMethod"),
                "method_count": names.count,
                "has_empty_name": names.contains(where: \.isEmpty),
            ]

        case "KclService.LintPath":
            var request = LintPathArgs()
            request.paths = try resolvePaths(args["paths"])
            let results = try api.lintPath(request).results
            return ["result_count": results.count, "has_result": !results.isEmpty]

        case "KclService.FormatPath":
            var request = FormatPathArgs()
            request.path = try resolvePath(string(args, "path"))
            request.dryRun = boolean(args, "dry_run")
            let changed = try api.formatPath(request).changedPaths
            // Basenames, because the paths run through a temporary or
            // repository directory that differs on every machine.
            return [
                "changed_count": changed.count,
                "changed": changed.map(basename).sorted(),
            ]

        case "KclService.Test":
            var request = TestArgs()
            request.execArgs = try execArgs(args["exec_args"] as? [String: Any] ?? [:])
            request.pkgList = try resolvePaths(args["pkg_list"])
            request.runRegexp = string(args, "run_regexp")
            request.failFast = boolean(args, "fail_fast")
            request.coverage = boolean(args, "coverage")
            let info = try api.test(request).info
            return [
                "names": info.map(\.name).sorted(),
                "failed": info.filter { !$0.error.isEmpty }.map(\.name).sorted(),
            ]

        case "KclService.OverrideFile":
            var request = OverrideFileArgs()
            request.file = try resolvePath(string(args, "file"))
            request.specs = stringList(args, "specs")
            request.importPaths = try resolvePaths(args["import_paths"])
            let result = try api.overrideFile(request)
            return ["result": result.result, "parse_error_count": result.parseErrors.count]

        case "KclService.LoadSettingsFiles":
            var request = LoadSettingsFilesArgs()
            request.workDir = try resolvePath(string(args, "work_dir"))
            request.files = try resolvePaths(args["files"])
            let result = try api.loadSettingsFiles(request)
            return [
                // Sorted by key, for the reason `list_options` sorts.
                "options": result.kclOptions.map { [$0.key, $0.value] as [Any] }
                    .sorted { ($0[0] as? String ?? "") < ($1[0] as? String ?? "") },
                "output": result.kclCliConfigs.output,
                "overrides": result.kclCliConfigs.overrides,
                "strict_range_check": result.kclCliConfigs.strictRangeCheck,
                "verbose": result.kclCliConfigs.verbose,
            ]

        case "KclService.UpdateDependencies":
            var request = UpdateDependenciesArgs()
            request.manifestPath = try resolvePath(string(args, "manifest_path"))
            request.vendor = boolean(args, "vendor")
            let result = try api.updateDependencies(request)
            return ["external_pkg_count": result.externalPkgs.count]

        default:
            throw ManifestError(description: "no runner support for rpc \(rpc)")
        }
    }

    // MARK: - Request builders

    /// Builds `ParseProgramArgs` for the schema-driven RPCs.
    private static func parseArgs(_ node: [String: Any]) throws -> ParseProgramArgs {
        var parseArgs = ParseProgramArgs()
        parseArgs.paths = try resolvePaths(node["paths"])
        parseArgs.sources = stringList(node, "sources")
        parseArgs.externalPkgs = externalPkgs(node["external_pkgs"])
        return parseArgs
    }

    /// Builds `ExecProgramArgs` from the manifest. `k_filename_list` is
    /// resolved by the core against the process working directory rather than
    /// against `work_dir`, so a relative entry has to be made absolute here
    /// or it will not survive being run from another directory.
    private static func execArgs(_ node: [String: Any]) throws -> ExecProgramArgs {
        var request = ExecProgramArgs()
        request.kCodeList = stringList(node, "k_code_list")
        let workDir = try resolvePath(string(node, "work_dir", default: "."))
        for entry in stringList(node, "k_filename_list") {
            let base = URL(fileURLWithPath: workDir, isDirectory: true)
            request.kFilenameList.append(
                URL(fileURLWithPath: entry, relativeTo: base).path
            )
        }
        request.workDir = workDir
        request.overrides = stringList(node, "overrides")
        return request
    }

    /// The two schema-mapping RPCs take the same arguments and return
    /// different maps: `GetSchemaTypeMapping` maps a schema name to one
    /// `KclType`, while `GetSchemaTypeMappingUnderPath` maps a *package* name
    /// to a `SchemaTypes` wrapper holding a list. The two share a builder and
    /// a projection, not a result type.
    private static func schemaTypeMappingArgs(_ args: [String: Any]) throws
        -> GetSchemaTypeMappingArgs
    {
        var request = GetSchemaTypeMappingArgs()
        request.execArgs = try execArgs(args["exec_args"] as? [String: Any] ?? [:])
        request.schemaName = string(args, "schema_name")
        return request
    }

    private static func externalPkgs(_ raw: Any?) -> [ExternalPkg] {
        ((raw as? [Any]) ?? []).compactMap { entry in
            guard let node = entry as? [String: Any] else { return nil }
            var pkg = ExternalPkg()
            pkg.pkgName = string(node, "pkg_name")
            pkg.pkgPath = string(node, "pkg_path")
            return pkg
        }
    }

    // MARK: - Paths
    //
    // The core resolves a path against its own working directory, so every
    // path the manifest pins repo-relative has to be made absolute here — and
    // an RPC that writes must never be handed a path inside the repository.

    private static func resolvePath(_ path: String) throws -> String {
        if path.hasPrefix(scratchPrefix) {
            return try scratch(String(path.dropFirst(scratchPrefix.count)))
        }
        return URL(fileURLWithPath: path, relativeTo: repoRoot).path
    }

    private static func resolvePaths(_ raw: Any?) throws -> [String] {
        let entries = ((raw as? [Any]) ?? []).compactMap { $0 as? String }
        return try entries.map { try resolvePath($0) }
    }

    /// Copy a scratch template and return the path inside the copy. Each case
    /// gets its own temporary directory, so two cases — and two runs — never
    /// observe each other's writes and the repository is never the target of
    /// an RPC that rewrites files.
    private static func scratch(_ rest: String) throws -> String {
        let parts = rest.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard let template = parts.first, !template.isEmpty else {
            throw ManifestError(description: "\(scratchPrefix) path names no template: \(rest)")
        }
        let source = testdata.appendingPathComponent(String(template), isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw ManifestError(description: "scratch template is not a directory: \(source.path)")
        }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kcl-consistency-\(UUID().uuidString)", isDirectory: true)
        let destination = root.appendingPathComponent(String(template), isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: destination)
        let tail = parts.count > 1 ? String(parts[1]) : ""
        return tail.isEmpty ? destination.path : destination.appendingPathComponent(tail).path
    }

    // MARK: - Result projections

    /// An RPC that parsed nothing returns an empty `ast_json` rather than
    /// `null`, and the manifest pins a count of zero for it.
    private static func astDocument(_ astJSON: String) throws -> [String: Any] {
        guard !astJSON.isEmpty else { return [:] }
        guard
            let document = try JSONSerialization.jsonObject(with: Data(astJSON.utf8))
                as? [String: Any]
        else {
            throw ManifestError(description: "ast_json is not a JSON object")
        }
        return document
    }

    /// The last component of a path, for the cases whose expectation is a
    /// file name rather than the machine-specific path it arrived as.
    private static func basename(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    /// The first two dot-components of a version string: the patch level moves
    /// with every core release, so the manifest pins the series only.
    private static func majorMinor(_ version: String) -> String {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return "" }
        return "\(parts[0]).\(parts[1])"
    }

    /// The schema-mapping documents, in the form every binding can produce.
    ///
    /// Canonical protobuf JSON — the default dialect, so a field the core left
    /// unset is absent rather than rendered as an empty value — with the proto
    /// field names kept, minus `filename` (an absolute path, so it differs on
    /// every machine). `KclType` is 18 fields and recursive through
    /// `union_types`, `properties`, `key`, `item` and `base_schema`, so a
    /// per-field projection would be a recursive walk written once per
    /// language; the protobuf runtime already emits the form the manifest is
    /// pinned to.
    ///
    /// Key order is left to `assertField`, which sorts both sides before
    /// comparing: two of `KclType`'s fields are protobuf maps, and a Swift
    /// `Dictionary` has no defined iteration order, so an unsorted comparison
    /// fails at random and a golden file that churns is a golden file
    /// contributors learn to ignore. All that is left here is the recursion
    /// that drops `filename`.
    private static func kclTypes<M: SwiftProtobuf.Message>(_ mapping: [String: M]) throws
        -> [String: Any]
    {
        var options = JSONEncodingOptions()
        options.preserveProtoFieldNames = true
        var document: [String: Any] = [:]
        for (name, value) in mapping {
            guard let data = try? value.jsonString(options: options).data(using: .utf8),
                let node = try? JSONSerialization.jsonObject(with: data)
            else {
                throw ManifestError(
                    description: "could not render the schema type `\(name)` as JSON"
                )
            }
            document[name] = withoutFilenames(node)
        }
        return document
    }

    private static func withoutFilenames(_ node: Any) -> Any {
        if let object = node as? [String: Any] {
            var out: [String: Any] = [:]
            for (key, value) in object where key != "filename" {
                out[key] = withoutFilenames(value)
            }
            return out
        }
        if let list = node as? [Any] {
            return list.map { withoutFilenames($0) }
        }
        return node
    }

    // MARK: - Manifest accessors
    //
    // Every argument in `cases.json` is optional as far as the runner is
    // concerned — the manifest is generated, and a future case may drop a
    // field that is present today. Reading through these helpers keeps that
    // from turning into a crash.

    private static func string(_ dict: [String: Any], _ key: String, default fallback: String = "")
        -> String
    {
        dict[key] as? String ?? fallback
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

    func testParseFile() throws {
        try runCase("parse_file")
    }

    func testParseProgram() throws {
        try runCase("parse_program")
    }

    func testListOptions() throws {
        try runCase("list_options")
    }

    func testListVariables() throws {
        try runCase("list_variables")
    }

    func testLoadPackage() throws {
        try runCase("load_package")
    }

    func testGetSchemaTypeMapping() throws {
        try runCase("get_schema_type_mapping")
    }

    func testGetSchemaTypeMappingUnderPath() throws {
        try runCase("get_schema_type_mapping_under_path")
    }

    func testGetVersion() throws {
        try runCase("get_version")
    }

    func testListMethod() throws {
        try runCase("list_method")
    }

    func testLintPathClean() throws {
        try runCase("lint_path_clean")
    }

    func testLintPathWithErrors() throws {
        try runCase("lint_path_with_errors")
    }

    func testFormatPathDryRun() throws {
        try runCase("format_path_dry_run")
    }

    func testTestRun() throws {
        try runCase("test_run")
    }

    func testOverrideFile() throws {
        try runCase("override_file")
    }

    func testLoadSettingsFiles() throws {
        try runCase("load_settings_files")
    }

    func testUpdateDependenciesNoDeps() throws {
        try runCase("update_dependencies_no_deps")
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
            "parse_file",
            "parse_program",
            "list_options",
            "list_variables",
            "load_package",
            "get_schema_type_mapping",
            "get_schema_type_mapping_under_path",
            "get_version",
            "list_method",
            "lint_path_clean",
            "lint_path_with_errors",
            "format_path_dry_run",
            "test_run",
            "override_file",
            "load_settings_files",
            "update_dependencies_no_deps",
        ]
        let missing = Set(try Self.manifest().keys).subtracting(covered).sorted()
        XCTAssertEqual(
            missing,
            [],
            "cases.json has cases this runner does not execute; add a test method for each"
        )
    }
}

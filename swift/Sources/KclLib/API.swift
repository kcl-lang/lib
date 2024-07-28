import Foundation
import SwiftProtobuf
import CKclLib

public class API: Service {
    private static let ERROR_PREFIX = "ERROR:"

    public init() {}

    // Parses a single KCL file and returns its Abstract Syntax Tree (AST) as a JSON string.
    public func parseFile(_ args: ParseFile_Args) throws -> ParseFile_Result {
        return try ParseFile_Result(serializedBytes: callNative(name: "KclvmService.ParseFile", args: try args.serializedBytes()))
    }

    // Parses a KCL program and returns the Abstract Syntax Tree (AST) in JSON format.
    public func parseProgram(_ args: ParseProgram_Args) throws -> ParseProgram_Result {
        return try ParseProgram_Result(serializedBytes: callNative(name: "KclvmService.ParseProgram", args: try args.serializedBytes()))
    }

    // Loads a KCL package and retrieves AST, symbol, type, and definition information.
    public func loadPackage(_ args: LoadPackage_Args) throws -> LoadPackage_Result {
        return try LoadPackage_Result(serializedBytes: callNative(name: "KclvmService.LoadPackage", args: try args.serializedBytes()))
    }

    // Executes a KCL file with provided arguments.
    public func execProgram(_ args: ExecProgram_Args) throws -> ExecProgram_Result {
        return try ExecProgram_Result(serializedBytes: callNative(name: "KclvmService.ExecProgram", args: try args.serializedBytes()))
    }

    // Overrides specified elements in a KCL file according to given arguments.
    public func overrideFile(_ args: OverrideFile_Args) throws -> OverrideFile_Result {
        return try OverrideFile_Result(serializedBytes: callNative(name: "KclvmService.OverrideFile", args: try args.serializedBytes()))
    }

    // Lists all variables declared in a KCL file.
    public func listVariables(_ args: ListVariables_Args) throws -> ListVariables_Result {
        return try ListVariables_Result(serializedBytes: callNative(name: "KclvmService.ListVariables", args: try args.serializedBytes()))
    }

    // Lists all options defined in a KCL program.
    public func listOptions(_ args: ParseProgram_Args) throws -> ListOptions_Result {
        return try ListOptions_Result(serializedBytes: callNative(name: "KclvmService.ListOptions", args: try args.serializedBytes()))
    }

    // Retrieves the full schema type mapping for a KCL program.
    public func getSchemaTypeMapping(_ args: GetSchemaTypeMapping_Args) throws -> GetSchemaTypeMapping_Result {
        return try GetSchemaTypeMapping_Result(serializedBytes: callNative(name: "KclvmService.GetSchemaTypeMapping", args: try args.serializedBytes()))
    }

    // Formats source code according to KCL style guidelines.
    public func formatCode(_ args: FormatCode_Args) throws -> FormatCode_Result {
        return try FormatCode_Result(serializedBytes: callNative(name: "KclvmService.FormatCode", args: try args.serializedBytes()))
    }

    // Formats KCL files or directories to conform to style guidelines.
    public func formatPath(_ args: FormatPath_Args) throws -> FormatPath_Result {
        return try FormatPath_Result(serializedBytes: callNative(name: "KclvmService.FormatPath", args: try args.serializedBytes()))
    }

    // Runs linting checks on KCL files and reports errors and warnings.
    public func lintPath(_ args: LintPath_Args) throws -> LintPath_Result {
        return try LintPath_Result(serializedBytes: callNative(name: "KclvmService.LintPath", args: try args.serializedBytes()))
    }

    // Validates a data string against a schema defined in a KCL code string.
    public func validateCode(_ args: ValidateCode_Args) throws -> ValidateCode_Result {
        return try ValidateCode_Result(serializedBytes: callNative(name: "KclvmService.ValidateCode", args: try args.serializedBytes()))
    }

    // Builds configuration from settings files.
    public func loadSettingsFiles(_ args: LoadSettingsFiles_Args) throws -> LoadSettingsFiles_Result {
        return try LoadSettingsFiles_Result(serializedBytes: callNative(name: "KclvmService.LoadSettingsFiles", args: try args.serializedBytes()))
    }

    // Renames symbols across files within a KCL package.
    public func rename(_ args: Rename_Args) throws -> Rename_Result {
        return try Rename_Result(serializedBytes: callNative(name: "KclvmService.Rename", args: try args.serializedBytes()))
    }

    // Renames symbols in source code without modifying files directly.
    public func renameCode(_ args: RenameCode_Args) throws -> RenameCode_Result {
        return try RenameCode_Result(serializedBytes: callNative(name: "KclvmService.RenameCode", args: try args.serializedBytes()))
    }

    // Executes tests on KCL packages using specified test arguments.
    public func test(_ args: Test_Args) throws -> Test_Result  {
        return try Test_Result(serializedBytes: callNative(name: "KclvmService.Test", args: try args.serializedBytes()))
    }

    // Updates dependencies for a KCL project based on defined specifications.
    public func updateDependencies(_ args: UpdateDependencies_Args) throws -> UpdateDependencies_Result {
        return try UpdateDependencies_Result(serializedBytes: callNative(name: "KclvmService.UpdateDependencies", args: try args.serializedBytes()))
    }

    // Retrieves version information about the KCL service.
    public func getVersion(_ args: GetVersion_Args) throws -> GetVersion_Result {
        return try GetVersion_Result(serializedBytes: callNative(name: "KclvmService.GetVersion", args: try args.serializedBytes()))
    }

    private func callNative(name: String, args: Data) -> Data {
        // Convert name to byte array
        let nameBytes = [UInt8](name.utf8)
        var resultBuf = [UInt8](repeating: 0, count: 2048 * 2048)
        let resultLength = CKclLib.callNative(nameBytes, UInt(nameBytes.count), [UInt8](args), UInt(args.count), &resultBuf)
        let result = Data(bytes: resultBuf, count: Int(resultLength))
        let resultString = String(bytes: result, encoding: .utf8) ?? ""
        if resultString.isEmpty || !resultString.hasPrefix(API.ERROR_PREFIX) {
            return result
        }
        fatalError(String(resultString.dropFirst(API.ERROR_PREFIX.count)))
    }
}

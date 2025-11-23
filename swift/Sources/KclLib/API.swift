import CKclLib
import Foundation
import SwiftProtobuf

public class API: Service {
  private static let ERROR_PREFIX = "ERROR:"

  public init() {}

  // Parses a single KCL file and returns its Abstract Syntax Tree (AST) as a JSON string.
  public func parseFile(_ args: ParseFileArgs) throws -> ParseFileResult {
    return try ParseFileResult(
      serializedBytes: callNative(name: "KclService.ParseFile", args: try args.serializedBytes()))
  }

  // Parses a KCL program and returns the Abstract Syntax Tree (AST) in JSON format.
  public func parseProgram(_ args: ParseProgramArgs) throws -> ParseProgramResult {
    return try ParseProgramResult(
      serializedBytes: callNative(
        name: "KclService.ParseProgram", args: try args.serializedBytes()))
  }

  // Loads a KCL package and retrieves AST, symbol, type, and definition information.
  public func loadPackage(_ args: LoadPackageArgs) throws -> LoadPackageResult {
    return try LoadPackageResult(
      serializedBytes: callNative(
        name: "KclService.LoadPackage", args: try args.serializedBytes()))
  }

  // Executes a KCL file with provided arguments.
  public func execProgram(_ args: ExecProgramArgs) throws -> ExecProgramResult {
    return try ExecProgramResult(
      serializedBytes: callNative(
        name: "KclService.ExecProgram", args: try args.serializedBytes()))
  }

  // Overrides specified elements in a KCL file according to given arguments.
  public func overrideFile(_ args: OverrideFileArgs) throws -> OverrideFileResult {
    return try OverrideFileResult(
      serializedBytes: callNative(
        name: "KclService.OverrideFile", args: try args.serializedBytes()))
  }

  // Lists all variables declared in a KCL file.
  public func listVariables(_ args: ListVariablesArgs) throws -> ListVariablesResult {
    return try ListVariablesResult(
      serializedBytes: callNative(
        name: "KclService.ListVariables", args: try args.serializedBytes()))
  }

  // Lists all options defined in a KCL program.
  public func listOptions(_ args: ParseProgramArgs) throws -> ListOptionsResult {
    return try ListOptionsResult(
      serializedBytes: callNative(
        name: "KclService.ListOptions", args: try args.serializedBytes()))
  }

  // Retrieves the full schema type mapping for a KCL program.
  public func getSchemaTypeMapping(_ args: GetSchemaTypeMappingArgs) throws
    -> GetSchemaTypeMappingResult
  {
    return try GetSchemaTypeMappingResult(
      serializedBytes: callNative(
        name: "KclService.GetSchemaTypeMapping", args: try args.serializedBytes()))
  }

  // Formats source code according to KCL style guidelines.
  public func formatCode(_ args: FormatCodeArgs) throws -> FormatCodeResult {
    return try FormatCodeResult(
      serializedBytes: callNative(name: "KclService.FormatCode", args: try args.serializedBytes())
    )
  }

  // Formats KCL files or directories to conform to style guidelines.
  public func formatPath(_ args: FormatPathArgs) throws -> FormatPathResult {
    return try FormatPathResult(
      serializedBytes: callNative(name: "KclService.FormatPath", args: try args.serializedBytes())
    )
  }

  // Runs linting checks on KCL files and reports errors and warnings.
  public func lintPath(_ args: LintPathArgs) throws -> LintPathResult {
    return try LintPathResult(
      serializedBytes: callNative(name: "KclService.LintPath", args: try args.serializedBytes()))
  }

  // Validates a data string against a schema defined in a KCL code string.
  public func validateCode(_ args: ValidateCodeArgs) throws -> ValidateCodeResult {
    return try ValidateCodeResult(
      serializedBytes: callNative(
        name: "KclService.ValidateCode", args: try args.serializedBytes()))
  }

  // Builds configuration from settings files.
  public func loadSettingsFiles(_ args: LoadSettingsFilesArgs) throws -> LoadSettingsFilesResult {
    return try LoadSettingsFilesResult(
      serializedBytes: callNative(
        name: "KclService.LoadSettingsFiles", args: try args.serializedBytes()))
  }

  // Renames symbols across files within a KCL package.
  public func rename(_ args: RenameArgs) throws -> RenameResult {
    return try RenameResult(
      serializedBytes: callNative(name: "KclService.Rename", args: try args.serializedBytes()))
  }

  // Renames symbols in source code without modifying files directly.
  public func renameCode(_ args: RenameCodeArgs) throws -> RenameCodeResult {
    return try RenameCodeResult(
      serializedBytes: callNative(name: "KclService.RenameCode", args: try args.serializedBytes())
    )
  }

  // Executes tests on KCL packages using specified test arguments.
  public func test(_ args: TestArgs) throws -> TestResult {
    return try TestResult(
      serializedBytes: callNative(name: "KclService.Test", args: try args.serializedBytes()))
  }

  // Updates dependencies for a KCL project based on defined specifications.
  public func updateDependencies(_ args: UpdateDependenciesArgs) throws
    -> UpdateDependenciesResult
  {
    return try UpdateDependenciesResult(
      serializedBytes: callNative(
        name: "KclService.UpdateDependencies", args: try args.serializedBytes()))
  }

  // Retrieves version information about the KCL service.
  public func getVersion(_ args: GetVersionArgs) throws -> GetVersionResult {
    return try GetVersionResult(
      serializedBytes: callNative(name: "KclService.GetVersion", args: try args.serializedBytes())
    )
  }

  private func callNative(name: String, args: Data) -> Data {
    // Convert name to byte array
    let nameBytes = [UInt8](name.utf8)
    var resultBuf = [UInt8](repeating: 0, count: 2048 * 2048)
    let resultLength = CKclLib.callNative(
      nameBytes, UInt(nameBytes.count), [UInt8](args), UInt(args.count), &resultBuf)
    let result = Data(bytes: resultBuf, count: Int(resultLength))
    let resultString = String(bytes: result, encoding: .utf8) ?? ""
    if resultString.isEmpty || !resultString.hasPrefix(API.ERROR_PREFIX) {
      return result
    }
    fatalError(String(resultString.dropFirst(API.ERROR_PREFIX.count)))
  }
}

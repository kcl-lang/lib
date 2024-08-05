import Foundation

// Define the protocol for services that manage various operations on KCL programs.
public protocol Service {
  // Parses a single KCL file and returns its Abstract Syntax Tree (AST) as a JSON string.
  func parseFile(_ args: ParseFile_Args) throws -> ParseFile_Result

  // Parses a KCL program and returns the Abstract Syntax Tree (AST) in JSON format.
  func parseProgram(_ args: ParseProgram_Args) throws -> ParseProgram_Result

  // Loads a KCL package and retrieves AST, symbol, type, and definition information.
  func loadPackage(_ args: LoadPackage_Args) throws -> LoadPackage_Result

  // Executes a KCL file with provided arguments.
  func execProgram(_ args: ExecProgram_Args) throws -> ExecProgram_Result

  // Overrides specified elements in a KCL file according to given arguments.
  func overrideFile(_ args: OverrideFile_Args) throws -> OverrideFile_Result

  // Lists all variables declared in a KCL file.
  func listVariables(_ args: ListVariables_Args) throws -> ListVariables_Result

  // Lists all options defined in a KCL program.
  func listOptions(_ args: ParseProgram_Args) throws -> ListOptions_Result

  // Retrieves the full schema type mapping for a KCL program.
  func getSchemaTypeMapping(_ args: GetSchemaTypeMapping_Args) throws -> GetSchemaTypeMapping_Result

  // Formats source code according to KCL style guidelines.
  func formatCode(_ args: FormatCode_Args) throws -> FormatCode_Result

  // Formats KCL files or directories to conform to style guidelines.
  func formatPath(_ args: FormatPath_Args) throws -> FormatPath_Result

  // Runs linting checks on KCL files and reports errors and warnings.
  func lintPath(_ args: LintPath_Args) throws -> LintPath_Result

  // Validates a data string against a schema defined in a KCL code string.
  func validateCode(_ args: ValidateCode_Args) throws -> ValidateCode_Result

  // Builds configuration from settings files.
  func loadSettingsFiles(_ args: LoadSettingsFiles_Args) throws -> LoadSettingsFiles_Result

  // Renames symbols across files within a KCL package.
  func rename(_ args: Rename_Args) throws -> Rename_Result

  // Renames symbols in source code without modifying files directly.
  func renameCode(_ args: RenameCode_Args) throws -> RenameCode_Result

  // Executes tests on KCL packages using specified test arguments.
  func test(_ args: Test_Args) throws -> Test_Result

  // Updates dependencies for a KCL project based on defined specifications.
  func updateDependencies(_ args: UpdateDependencies_Args) throws -> UpdateDependencies_Result

  // Retrieves version information about the KCL service.
  func getVersion(_ args: GetVersion_Args) throws -> GetVersion_Result
}

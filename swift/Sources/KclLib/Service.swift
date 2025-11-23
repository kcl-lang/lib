import Foundation

// Define the protocol for services that manage various operations on KCL programs.
public protocol Service {
  // Parses a single KCL file and returns its Abstract Syntax Tree (AST) as a JSON string.
  func parseFile(_ args: ParseFileArgs) throws -> ParseFileResult

  // Parses a KCL program and returns the Abstract Syntax Tree (AST) in JSON format.
  func parseProgram(_ args: ParseProgramArgs) throws -> ParseProgramResult

  // Loads a KCL package and retrieves AST, symbol, type, and definition information.
  func loadPackage(_ args: LoadPackageArgs) throws -> LoadPackageResult

  // Executes a KCL file with provided arguments.
  func execProgram(_ args: ExecProgramArgs) throws -> ExecProgramResult

  // Overrides specified elements in a KCL file according to given arguments.
  func overrideFile(_ args: OverrideFileArgs) throws -> OverrideFileResult

  // Lists all variables declared in a KCL file.
  func listVariables(_ args: ListVariablesArgs) throws -> ListVariablesResult

  // Lists all options defined in a KCL program.
  func listOptions(_ args: ParseProgramArgs) throws -> ListOptionsResult

  // Retrieves the full schema type mapping for a KCL program.
  func getSchemaTypeMapping(_ args: GetSchemaTypeMappingArgs) throws -> GetSchemaTypeMappingResult

  // Formats source code according to KCL style guidelines.
  func formatCode(_ args: FormatCodeArgs) throws -> FormatCodeResult

  // Formats KCL files or directories to conform to style guidelines.
  func formatPath(_ args: FormatPathArgs) throws -> FormatPathResult

  // Runs linting checks on KCL files and reports errors and warnings.
  func lintPath(_ args: LintPathArgs) throws -> LintPathResult

  // Validates a data string against a schema defined in a KCL code string.
  func validateCode(_ args: ValidateCodeArgs) throws -> ValidateCodeResult

  // Builds configuration from settings files.
  func loadSettingsFiles(_ args: LoadSettingsFilesArgs) throws -> LoadSettingsFilesResult

  // Renames symbols across files within a KCL package.
  func rename(_ args: RenameArgs) throws -> RenameResult

  // Renames symbols in source code without modifying files directly.
  func renameCode(_ args: RenameCodeArgs) throws -> RenameCodeResult

  // Executes tests on KCL packages using specified test arguments.
  func test(_ args: TestArgs) throws -> TestResult

  // Updates dependencies for a KCL project based on defined specifications.
  func updateDependencies(_ args: UpdateDependenciesArgs) throws -> UpdateDependenciesResult

  // Retrieves version information about the KCL service.
  func getVersion(_ args: GetVersionArgs) throws -> GetVersionResult
}

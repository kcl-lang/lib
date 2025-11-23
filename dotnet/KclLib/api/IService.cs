namespace KclLib.API;

/// <summary>
/// Defines the contract for services that handle various operations on KCL programs.
/// </summary>
public interface IService
{
    /// <summary>
    /// Parses a single KCL file and returns its Abstract Syntax Tree (AST) as a JSON string.
    /// </summary>
    /// <param name="args">Arguments containing the file to parse.</param>
    /// <returns>The result of parsing the file.</returns>
    ParseFileResult ParseFile(ParseFileArgs args);

    /// <summary>
    /// Parses a KCL program and returns the Abstract Syntax Tree (AST) in JSON format.
    /// </summary>
    /// <param name="args">Arguments specifying the program's entry points.</param>
    /// <returns>The result of parsing the program.</returns>
    ParseProgramResult ParseProgram(ParseProgramArgs args);

    /// <summary>
    /// Loads a KCL package and retrieves AST, symbol, type, and definition information.
    /// </summary>
    /// <param name="args">Arguments for loading the package.</param>
    /// <returns>The loaded package information.</returns>
    LoadPackageResult LoadPackage(LoadPackageArgs args);

    /// <summary>
    /// Executes a KCL file with provided arguments.
    /// </summary>
    /// <param name="args">Execution arguments including the file to execute.</param>
    /// <returns>The result of the execution.</returns>
    ExecProgramResult ExecProgram(ExecProgramArgs args);

    /// <summary>
    /// Overrides specified elements in a KCL file according to given arguments.
    /// </summary>
    /// <param name="args">Arguments detailing the overrides.</param>
    /// <returns>The result of the file override operation.</returns>
    OverrideFileResult OverrideFile(OverrideFileArgs args);

    /// <summary>
    /// Lists all variables declared in a KCL file.
    /// </summary>
    /// <param name="args">Arguments specifying the file to analyze.</param>
    /// <returns>A result containing listed variables.</returns>
    ListVariablesResult ListVariables(ListVariablesArgs args);

    /// <summary>
    /// Lists all options defined in a KCL program.
    /// </summary>
    /// <param name="args">Arguments for parsing the program.</param>
    /// <returns>The result containing listed options.</returns>
    ListOptionsResult ListOptions(ParseProgramArgs args);

    /// <summary>
    /// Retrieves the full schema type mapping for a KCL program.
    /// </summary>
    /// <param name="args">Arguments for schema type mapping retrieval.</param>
    /// <returns>The schema type mapping result.</returns>
    GetSchemaTypeMappingResult GetSchemaTypeMapping(GetSchemaTypeMappingArgs args);

    /// <summary>
    /// Formats source code according to KCL style guidelines.
    /// </summary>
    /// <param name="args">Arguments specifying the code to format.</param>
    /// <returns>The result of the code formatting operation.</returns>
    FormatCodeResult FormatCode(FormatCodeArgs args);

    /// <summary>
    /// Formats KCL files or directories to conform to style guidelines.
    /// </summary>
    /// <param name="args">Arguments specifying files or directories to format.</param>
    /// <returns>The result of the formatting operation.</returns>
    FormatPathResult FormatPath(FormatPathArgs args);

    /// <summary>
    /// Runs linting checks on KCL files and reports errors and warnings.
    /// </summary>
    /// <param name="args">Arguments defining which files to lint.</param>
    /// <returns>The linting result.</returns>
    LintPathResult LintPath(LintPathArgs args);

    /// <summary>
    /// Validates a data string against a schema defined in a KCL code string.
    /// </summary>
    /// <param name="args">Validation arguments including code and data.</param>
    /// <returns>The validation result.</returns>
    ValidateCodeResult ValidateCode(ValidateCodeArgs args);

    /// <summary>
    /// Builds configuration from settings files.
    /// </summary>
    /// <param name="args">Arguments for loading settings files.</param>
    /// <returns>The loaded settings configuration.</returns>
    LoadSettingsFilesResult LoadSettingsFiles(LoadSettingsFilesArgs args);

    /// <summary>
    /// Renames symbols across files within a KCL package.
    /// </summary>
    /// <param name="args">Arguments specifying renaming details.</param>
    /// <returns>The result of the renaming operation.</returns>
    RenameResult Rename(RenameArgs args);

    /// <summary>
    /// Renames symbols in source code without modifying files directly.
    /// </summary>
    /// <param name="args">Arguments for symbol renaming in code.</param>
    /// <returns>The result with renamed code.</returns>
    RenameCodeResult RenameCode(RenameCodeArgs args);

    /// <summary>
    /// Executes tests on KCL packages using specified test arguments.
    /// </summary>
    /// <param name="args">Arguments for running tests.</param>
    /// <returns>The test execution result.</returns>
    TestResult Test(TestArgs args);

    /// <summary>
    /// Updates dependencies for a KCL project based on defined specifications.
    /// </summary>
    /// <param name="args">Arguments for dependency updating.</param>
    /// <returns>The result of the dependency update process.</returns>
    UpdateDependenciesResult UpdateDependencies(UpdateDependenciesArgs args);

    /// <summary>
    /// Retrieves version information about the KCL service.
    /// </summary>
    /// <param name="args">Arguments for version retrieval.</param>
    /// <returns>The version information result.</returns>
    GetVersionResult GetVersion(GetVersionArgs args);
}

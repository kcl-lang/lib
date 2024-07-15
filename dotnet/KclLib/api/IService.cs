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
    ParseFile_Result ParseFile(ParseFile_Args args);

    /// <summary>
    /// Parses a KCL program and returns the Abstract Syntax Tree (AST) in JSON format.
    /// </summary>
    /// <param name="args">Arguments specifying the program's entry points.</param>
    /// <returns>The result of parsing the program.</returns>
    ParseProgram_Result ParseProgram(ParseProgram_Args args);

    /// <summary>
    /// Loads a KCL package and retrieves AST, symbol, type, and definition information.
    /// </summary>
    /// <param name="args">Arguments for loading the package.</param>
    /// <returns>The loaded package information.</returns>
    LoadPackage_Result LoadPackage(LoadPackage_Args args);

    /// <summary>
    /// Executes a KCL file with provided arguments.
    /// </summary>
    /// <param name="args">Execution arguments including the file to execute.</param>
    /// <returns>The result of the execution.</returns>
    ExecProgram_Result ExecProgram(ExecProgram_Args args);

    /// <summary>
    /// Overrides specified elements in a KCL file according to given arguments.
    /// </summary>
    /// <param name="args">Arguments detailing the overrides.</param>
    /// <returns>The result of the file override operation.</returns>
    OverrideFile_Result OverrideFile(OverrideFile_Args args);

    /// <summary>
    /// Lists all variables declared in a KCL file.
    /// </summary>
    /// <param name="args">Arguments specifying the file to analyze.</param>
    /// <returns>A result containing listed variables.</returns>
    ListVariables_Result ListVariables(ListVariables_Args args);

    /// <summary>
    /// Lists all options defined in a KCL program.
    /// </summary>
    /// <param name="args">Arguments for parsing the program.</param>
    /// <returns>The result containing listed options.</returns>
    ListOptions_Result ListOptions(ParseProgram_Args args);

    /// <summary>
    /// Retrieves the full schema type mapping for a KCL program.
    /// </summary>
    /// <param name="args">Arguments for schema type mapping retrieval.</param>
    /// <returns>The schema type mapping result.</returns>
    GetSchemaTypeMapping_Result GetSchemaTypeMapping(GetSchemaTypeMapping_Args args);

    /// <summary>
    /// Formats source code according to KCL style guidelines.
    /// </summary>
    /// <param name="args">Arguments specifying the code to format.</param>
    /// <returns>The result of the code formatting operation.</returns>
    FormatCode_Result FormatCode(FormatCode_Args args);

    /// <summary>
    /// Formats KCL files or directories to conform to style guidelines.
    /// </summary>
    /// <param name="args">Arguments specifying files or directories to format.</param>
    /// <returns>The result of the formatting operation.</returns>
    FormatPath_Result FormatPath(FormatPath_Args args);

    /// <summary>
    /// Runs linting checks on KCL files and reports errors and warnings.
    /// </summary>
    /// <param name="args">Arguments defining which files to lint.</param>
    /// <returns>The linting result.</returns>
    LintPath_Result LintPath(LintPath_Args args);

    /// <summary>
    /// Validates a data string against a schema defined in a KCL code string.
    /// </summary>
    /// <param name="args">Validation arguments including code and data.</param>
    /// <returns>The validation result.</returns>
    ValidateCode_Result ValidateCode(ValidateCode_Args args);

    /// <summary>
    /// Builds configuration from settings files.
    /// </summary>
    /// <param name="args">Arguments for loading settings files.</param>
    /// <returns>The loaded settings configuration.</returns>
    LoadSettingsFiles_Result LoadSettingsFiles(LoadSettingsFiles_Args args);

    /// <summary>
    /// Renames symbols across files within a KCL package.
    /// </summary>
    /// <param name="args">Arguments specifying renaming details.</param>
    /// <returns>The result of the renaming operation.</returns>
    Rename_Result Rename(Rename_Args args);

    /// <summary>
    /// Renames symbols in source code without modifying files directly.
    /// </summary>
    /// <param name="args">Arguments for symbol renaming in code.</param>
    /// <returns>The result with renamed code.</returns>
    RenameCode_Result RenameCode(RenameCode_Args args);

    /// <summary>
    /// Executes tests on KCL packages using specified test arguments.
    /// </summary>
    /// <param name="args">Arguments for running tests.</param>
    /// <returns>The test execution result.</returns>
    Test_Result Test(Test_Args args);

    /// <summary>
    /// Updates dependencies for a KCL project based on defined specifications.
    /// </summary>
    /// <param name="args">Arguments for dependency updating.</param>
    /// <returns>The result of the dependency update process.</returns>
    UpdateDependencies_Result UpdateDependencies(UpdateDependencies_Args args);

    /// <summary>
    /// Retrieves version information about the KCL service.
    /// </summary>
    /// <param name="args">Arguments for version retrieval.</param>
    /// <returns>The version information result.</returns>
    GetVersion_Result GetVersion(GetVersion_Args args);
}

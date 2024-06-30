namespace KclLib.API;

public interface IService
{
    // Parse KCL single file AST JSON string
    ParseFile_Result ParseFile(ParseFile_Args args);

    // Parse KCL program AST JSON string
    ParseProgram_Result ParseProgram(ParseProgram_Args args);

    // Loads KCL package and returns the AST, symbol, type, definition information.
    LoadPackage_Result LoadPackage(LoadPackage_Args args);

    // Execute KCL file with args
    ExecProgram_Result ExecProgram(ExecProgram_Args args);

    // Override KCL file with args
    OverrideFile_Result OverrideFile(OverrideFile_Args args);

    // List all the variables in the KCL file
    ListVariables_Result ListVariables(ListVariables_Args args);

    // Service for getting the full schema type list
    GetSchemaTypeMapping_Result GetSchemaTypeMapping(GetSchemaTypeMapping_Args args);

    // Service for formatting a code source
    FormatCode_Result FormatCode(FormatCode_Args args);

    // Service for formatting KCL file or directory path
    FormatPath_Result FormatPath(FormatPath_Args args);

    // Service for KCL Lint API
    LintPath_Result LintPath(LintPath_Args args);

    // Service for validating the data string using the schema code string
    ValidateCode_Result ValidateCode(ValidateCode_Args args);

    // Service for building setting file config from args
    LoadSettingsFiles_Result LoadSettingsFiles(LoadSettingsFiles_Args args);

    // Service for renaming all the occurrences of the target symbol in the files
    Rename_Result Rename(Rename_Args args);

    // Service for renaming all the occurrences of the target symbol and rename them
    RenameCode_Result RenameCode(RenameCode_Args args);

    // Service for the testing tool
    Test_Result Test(Test_Args args);

    // Service for the dependency updating
    UpdateDependencies_Result UpdateDependencies(UpdateDependencies_Args args);
}

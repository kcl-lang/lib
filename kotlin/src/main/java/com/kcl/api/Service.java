package com.kcl.api;

import com.kcl.api.Spec.*;

public interface Service {
    // Parse KCL single file AST JSON string
    ParseFileResult parseFile(ParseFileArgs args) throws Exception;

    // Parse KCL program AST JSON string
    ParseProgramResult parseProgram(ParseProgramArgs args) throws Exception;

    // Loads KCL package and returns the AST, symbol, type, definition information.
    LoadPackageResult loadPackage(LoadPackageArgs args) throws Exception;

    // Loads KCL package and returns the AST, symbol, type, definition information.
    LoadPackageResult loadPackageWithCache(LoadPackageArgs args) throws Exception;

    // Execute KCL file with args
    ExecProgramResult execProgram(ExecProgramArgs args) throws Exception;

    // Override KCL file with args
    OverrideFileResult overrideFile(OverrideFileArgs args) throws Exception;

    // List all the variables in the KCL file
    ListVariablesResult listVariables(ListVariablesArgs args) throws Exception;

    // List all the option functions in the KCL file
    ListOptionsResult listOptions(ParseProgramArgs args) throws Exception;

    // Service for getting the full schema type list
    GetSchemaTypeMappingResult getSchemaTypeMapping(GetSchemaTypeMappingArgs args) throws Exception;

    // Service for formatting a code source
    FormatCodeResult formatCode(FormatCodeArgs args) throws Exception;

    // Service for formatting KCL file or directory path
    FormatPathResult formatPath(FormatPathArgs args) throws Exception;

    // Service for KCL Lint API
    LintPathResult lintPath(LintPathArgs args) throws Exception;

    // Service for validating the data string using the schema code string
    ValidateCodeResult validateCode(ValidateCodeArgs args) throws Exception;

    // Service for building setting file config from args
    LoadSettingsFilesResult loadSettingsFiles(LoadSettingsFilesArgs args) throws Exception;

    // Service for renaming all the occurrences of the target symbol in the files
    RenameResult rename(RenameArgs args) throws Exception;

    // Service for renaming all the occurrences of the target symbol and rename them
    RenameCodeResult renameCode(RenameCodeArgs args) throws Exception;

    // Service for the testing tool
    TestResult test(TestArgs args) throws Exception;

    // Service for the dependency updating
    UpdateDependenciesResult updateDependencies(UpdateDependenciesArgs args) throws Exception;

    // Service for the KCL service version information.
    GetVersionResult getVersion(GetVersionArgs args) throws Exception;
}

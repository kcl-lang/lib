package com.kcl.api;

import com.kcl.api.Spec.*;

public interface Service {
    // Parse KCL single file AST JSON string
    ParseFile_Result parseFile(ParseFile_Args args) throws Exception;

    // Parse KCL program AST JSON string
    ParseProgram_Result parseProgram(ParseProgram_Args args) throws Exception;

    // Loads KCL package and returns the AST, symbol, type, definition information.
    LoadPackage_Result loadPackage(LoadPackage_Args args) throws Exception;

    // Loads KCL package and returns the AST, symbol, type, definition information.
    LoadPackage_Result loadPackageWithCache(LoadPackage_Args args) throws Exception;

    // Execute KCL file with args
    ExecProgram_Result execProgram(ExecProgram_Args args) throws Exception;

    // Override KCL file with args
    OverrideFile_Result overrideFile(OverrideFile_Args args) throws Exception;

    // List all the variables in the KCL file
    ListVariables_Result listVariables(ListVariables_Args args) throws Exception;

    // Service for getting the full schema type list
    GetSchemaType_Result getFullSchemaType(GetFullSchemaType_Args args) throws Exception;

    // Service for formatting a code source
    FormatCode_Result formatCode(FormatCode_Args args) throws Exception;

    // Service for formatting KCL file or directory path
    FormatPath_Result formatPath(FormatPath_Args args) throws Exception;

    // Service for KCL Lint API
    LintPath_Result lintPath(LintPath_Args args) throws Exception;

    // Service for validating the data string using the schema code string
    ValidateCode_Result validateCode(ValidateCode_Args args) throws Exception;

    // Service for building setting file config from args
    LoadSettingsFiles_Result loadSettingsFiles(LoadSettingsFiles_Args args) throws Exception;

    // Service for renaming all the occurrences of the target symbol in the files
    Rename_Result rename(Rename_Args args) throws Exception;

    // Service for renaming all the occurrences of the target symbol and rename them
    RenameCode_Result renameCode(RenameCode_Args args) throws Exception;

    // Service for the testing tool
    Test_Result test(Test_Args args) throws Exception;
}

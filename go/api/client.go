package api

// KCL service client interface.
type ServiceClient interface {
	// Ping KclvmService, return the same value as the parameter
	Ping(in *Ping_Args) (out *Ping_Result, err error)
	// Execute KCL file with arguments and return the JSON/YAML result.
	ExecProgram(in *ExecProgram_Args) (out *ExecProgram_Result, err error)
	// Depreciated: Please use the env.EnableFastEvalMode() and c.ExecutProgram method and will be removed in v0.11.1.
	BuildProgram(in *BuildProgram_Args) (out *BuildProgram_Result, err error)
	// Depreciated: Please use the env.EnableFastEvalMode() and c.ExecutProgram method and will be removed in v0.11.1.
	ExecArtifact(in *ExecArtifact_Args) (out *ExecProgram_Result, err error)
	// Parse KCL single file to Module AST JSON string with import dependencies and parse errors.
	ParseFile(in *ParseFile_Args) (out *ParseFile_Result, err error)
	// Parse KCL program with entry files and return the AST JSON string.
	ParseProgram(in *ParseProgram_Args) (out *ParseProgram_Result, err error)
	// ListOptions provides users with the ability to parse KCL program and get all option information.
	ListOptions(in *ParseProgram_Args) (out *ListOptions_Result, err error)
	// ListVariables provides users with the ability to parse KCL program and get all variables by specs.
	ListVariables(in *ListVariables_Args) (out *ListVariables_Result, err error)
	// LoadPackage provides users with the ability to parse KCL program and semantic model information including symbols, types, definitions, etc.
	LoadPackage(in *LoadPackage_Args) (out *LoadPackage_Result, err error)
	// Format the code source.
	FormatCode(in *FormatCode_Args) (out *FormatCode_Result, err error)
	// Format KCL file or directory path contains KCL files and returns the changed file paths.
	FormatPath(in *FormatPath_Args) (out *FormatPath_Result, err error)
	// Lint files and return error messages including errors and warnings.
	LintPath(in *LintPath_Args) (out *LintPath_Result, err error)
	// Override KCL file with arguments. See [https://www.kcl-lang.io/docs/user_docs/guides/automation](https://www.kcl-lang.io/docs/user_docs/guides/automation) for more override spec guide.
	OverrideFile(in *OverrideFile_Args) (out *OverrideFile_Result, err error)
	// Get schema type mapping defined in the program.
	GetSchemaTypeMapping(in *GetSchemaTypeMapping_Args) (out *GetSchemaTypeMapping_Result, err error)
	// Validate code using schema and JSON/YAML data strings.
	ValidateCode(in *ValidateCode_Args) (out *ValidateCode_Result, err error)
	// List dependencies files of input paths.
	ListDepFiles(in *ListDepFiles_Args) (out *ListDepFiles_Result, err error)
	// Load the setting file config defined in `kcl.yaml`.
	LoadSettingsFiles(in *LoadSettingsFiles_Args) (out *LoadSettingsFiles_Result, err error)
	// Rename all the occurrences of the target symbol in the files. This API will rewrite files if they contain symbols to be renamed. Return the file paths that got changed.
	Rename(in *Rename_Args) (out *Rename_Result, err error)
	// Rename all the occurrences of the target symbol and return the modified code if any code has been changed. This API won't rewrite files but return the changed code.
	RenameCode(in *RenameCode_Args) (out *RenameCode_Result, err error)
	// Test KCL packages with test arguments.
	Test(in *Test_Args) (out *Test_Result, err error)
	// Download and update dependencies defined in the `kcl.mod` file and return the external package name and location list.
	UpdateDependencies(in *UpdateDependencies_Args) (out *UpdateDependencies_Result, err error)
	// GetVersion KclvmService, return the kclvm service version information
	GetVersion(in *GetVersion_Args) (out *GetVersion_Result, err error)
}

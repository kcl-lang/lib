package api

// KCL service client interface.
type ServiceClient interface {
	// Ping KclService, return the same value as the parameter
	Ping(in *PingArgs) (out *PingResult, err error)
	// Execute KCL file with arguments and return the JSON/YAML result.
	ExecProgram(in *ExecProgramArgs) (out *ExecProgramResult, err error)
	// Depreciated: Please use the env.EnableFastEvalMode() and c.ExecutProgram method and will be removed in v0.12.0.
	BuildProgram(in *BuildProgramArgs) (out *BuildProgramResult, err error)
	// Depreciated: Please use the env.EnableFastEvalMode() and c.ExecutProgram method and will be removed in v0.12.0.
	ExecArtifact(in *ExecArtifactArgs) (out *ExecProgramResult, err error)
	// Parse KCL single file to Module AST JSON string with import dependencies and parse errors.
	ParseFile(in *ParseFileArgs) (out *ParseFileResult, err error)
	// Parse KCL program with entry files and return the AST JSON string.
	ParseProgram(in *ParseProgramArgs) (out *ParseProgramResult, err error)
	// ListOptions provides users with the ability to parse KCL program and get all option information.
	ListOptions(in *ParseProgramArgs) (out *ListOptionsResult, err error)
	// ListVariables provides users with the ability to parse KCL program and get all variables by specs.
	ListVariables(in *ListVariablesArgs) (out *ListVariablesResult, err error)
	// LoadPackage provides users with the ability to parse KCL program and semantic model information including symbols, types, definitions, etc.
	LoadPackage(in *LoadPackageArgs) (out *LoadPackageResult, err error)
	// Format the code source.
	FormatCode(in *FormatCodeArgs) (out *FormatCodeResult, err error)
	// Format KCL file or directory path contains KCL files and returns the changed file paths.
	FormatPath(in *FormatPathArgs) (out *FormatPathResult, err error)
	// Lint files and return error messages including errors and warnings.
	LintPath(in *LintPathArgs) (out *LintPathResult, err error)
	// Override KCL file with arguments. See [https://www.kcl-lang.io/docs/user_docs/guides/automation](https://www.kcl-lang.io/docs/user_docs/guides/automation) for more override spec guide.
	OverrideFile(in *OverrideFileArgs) (out *OverrideFileResult, err error)
	// Get schema type mapping defined in the program.
	GetSchemaTypeMapping(in *GetSchemaTypeMappingArgs) (out *GetSchemaTypeMappingResult, err error)
	// Validate code using schema and JSON/YAML data strings.
	ValidateCode(in *ValidateCodeArgs) (out *ValidateCodeResult, err error)
	// List dependencies files of input paths.
	ListDepFiles(in *ListDepFilesArgs) (out *ListDepFilesResult, err error)
	// Load the setting file config defined in `kcl.yaml`.
	LoadSettingsFiles(in *LoadSettingsFilesArgs) (out *LoadSettingsFilesResult, err error)
	// Rename all the occurrences of the target symbol in the files. This API will rewrite files if they contain symbols to be renamed. Return the file paths that got changed.
	Rename(in *RenameArgs) (out *RenameResult, err error)
	// Rename all the occurrences of the target symbol and return the modified code if any code has been changed. This API won't rewrite files but return the changed code.
	RenameCode(in *RenameCodeArgs) (out *RenameCodeResult, err error)
	// Test KCL packages with test arguments.
	Test(in *TestArgs) (out *TestResult, err error)
	// Download and update dependencies defined in the `kcl.mod` file and return the external package name and location list.
	UpdateDependencies(in *UpdateDependenciesArgs) (out *UpdateDependenciesResult, err error)
	// GetVersion KclService, return the kcl service version information
	GetVersion(in *GetVersionArgs) (out *GetVersionResult, err error)
}

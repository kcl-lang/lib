extern crate kclvm_api;

use anyhow::Result;

#[cxx::bridge(namespace = "kcl_lib")]
mod ffi {
    /// Message for execute program request arguments.
    #[derive(Debug, Default)]
    pub struct ExecProgramArgs {
        /// Working directory.
        pub work_dir: String,
        /// List of KCL filenames.
        pub k_filename_list: Vec<String>,
        /// List of KCL codes.
        pub k_code_list: Vec<String>,
        /// Arguments for the program.
        pub args: Vec<Argument>,
        /// Override configurations.
        pub overrides: Vec<String>,
        /// Flag to disable YAML result.
        pub disable_yaml_result: bool,
        /// Flag to print override AST.
        pub print_override_ast: bool,
        /// -r --strict-range-check
        pub strict_range_check: bool,
        /// -n --disable-none
        pub disable_none: bool,
        /// -v --verbose
        pub verbose: i32,
        /// -d --debug
        pub debug: i32,
        /// yaml/json: sort keys
        pub sort_keys: bool,
        /// -E --external : external packages path
        pub external_pkgs: Vec<ExternalPkg>,
        /// Whether including schema type in JSON/YAML result
        pub include_schema_type_path: bool,
        /// Whether only compiling the program
        pub compile_only: bool,
        /// Show hidden attributes
        pub show_hidden: bool,
        /// -S --path_selector
        pub path_selector: Vec<String>,
        /// -K --fast_eval
        pub fast_eval: bool,
    }

    /// kcl main.k -E name=path
    #[derive(Debug, Default)]
    pub struct ExternalPkg {
        pub pkg_name: String,
        pub pkg_path: String,
    }

    /// kcl main.k -D name=value
    #[derive(Debug, Default)]
    pub struct Argument {
        /// Name of the argument.
        pub name: String,
        /// Value of the argument.
        pub value: String,
    }

    /// Message representing an error.
    #[derive(Debug, Default)]
    pub struct Error {
        /// Level of the error (e.g., "Error", "Warning").
        pub level: String,
        /// Error code. (e.g., "E1001")
        pub code: String,
        /// List of error messages.
        pub messages: Vec<Message>,
    }

    /// Message representing a detailed error message with a position.
    #[derive(Debug, Default)]
    pub struct Message {
        /// The error message text.
        pub msg: String,
        /// The position in the source code where the error occurred.
        pub pos: Position,
    }

    /// Message representing a position in the source code.
    #[derive(Debug, Default)]
    pub struct Position {
        /// Line number.
        pub line: i64,
        /// Column number.
        pub column: i64,
        /// Filename the position refers to.
        pub filename: String,
    }

    /// Message for execute program response.
    #[derive(Debug, Default)]
    pub struct ExecProgramResult {
        /// Result in JSON format.
        json_result: String,
        /// Result in YAML format.
        yaml_result: String,
        /// Log message from execution.
        log_message: String,
        /// Error message from execution.
        err_message: String,
    }

    /// Message for version response.
    #[derive(Debug, Default)]
    pub struct GetVersionResult {
        /// KCL version.
        pub version: String,
        /// Checksum of the KCL version.
        pub checksum: String,
        /// Git Git SHA of the KCL code repo.
        pub git_sha: String,
        /// Detailed version information as a string.
        pub version_info: String,
    }

    /// Message for parse file request arguments.
    #[derive(Debug, Default)]
    pub struct ParseFileArgs {
        /// Path of the file to be parsed.
        pub path: String,
        /// Source code to be parsed.
        pub source: String,
        /// External packages path.
        pub external_pkgs: Vec<ExternalPkg>,
    }

    /// Message for parse file response.
    #[derive(Debug, Default)]
    pub struct ParseFileResult {
        /// Abstract Syntax Tree (AST) in JSON format.
        pub ast_json: String,
        /// File dependency paths.
        pub deps: Vec<String>,
        /// List of parse errors.
        pub errors: Vec<Error>,
    }

    /// Message for parse program request arguments.
    #[derive(Debug, Default)]
    pub struct ParseProgramArgs {
        /// Paths of the program files to be parsed.
        pub paths: Vec<String>,
        /// Source codes to be parsed.
        pub sources: Vec<String>,
        /// External packages path.
        pub external_pkgs: Vec<ExternalPkg>,
    }

    /// Message for parse program response.
    #[derive(Debug, Default)]
    pub struct ParseProgramResult {
        /// Abstract Syntax Tree (AST) in JSON format.
        pub ast_json: String,
        /// Returns the files in the order they should be compiled.
        pub paths: Vec<String>,
        /// List of parse errors.
        pub errors: Vec<Error>,
    }

    /// Message for load package request arguments.
    #[derive(Debug, Default)]
    pub struct LoadPackageArgs {
        /// Arguments for parsing the program.
        pub parse_args: OptionalParseProgramArgs,
        /// Flag indicating whether to resolve AST.
        pub resolve_ast: bool,
        /// Flag indicating whether to load built-in modules.
        pub load_builtin: bool,
        /// Flag indicating whether to include AST index.
        pub with_ast_index: bool,
    }

    #[derive(Debug, Default)]
    struct OptionalParseProgramArgs {
        has_value: bool,
        value: ParseProgramArgs,
    }

    /// Message for load package response.
    pub struct LoadPackageResult {
        /// Program Abstract Syntax Tree (AST) in JSON format.
        pub program: String,
        /// Returns the files in the order they should be compiled.
        pub paths: Vec<String>,
        /// List of parse errors.
        pub parse_errors: Vec<Error>,
        /// List of type errors.
        pub type_errors: Vec<Error>,
        /// Map of scopes with scope index as key.
        pub scopes: Vec<HashMapScopeValue>,
        /// Map of symbols with symbol index as key.
        pub symbols: Vec<HashMapSymbolValue>,
        /// Map of node-symbol associations with AST index UUID as key.
        pub node_symbol_map: Vec<HashMapSymbolIndexValue>,
        /// Map of symbol-node associations with symbol index as key.
        pub symbol_node_map: Vec<HashMapStringValue>,
        /// Map of fully qualified names with symbol index as key.
        pub fully_qualified_name_map: Vec<HashMapSymbolIndexValue>,
        /// Map of package scope with package path as key.
        pub pkg_scope_map: Vec<HashMapScopeIndexValue>,
    }

    #[derive(Debug, Default)]
    struct HashMapScopeValue {
        key: String,
        value: Scope,
    }

    #[derive(Debug, Default)]
    struct HashMapSymbolValue {
        key: String,
        value: Symbol,
    }

    #[derive(Debug, Default)]
    struct HashMapSymbolIndexValue {
        key: String,
        value: SymbolIndex,
    }

    #[derive(Debug, Default)]
    struct HashMapScopeIndexValue {
        key: String,
        value: ScopeIndex,
    }

    #[derive(Debug, Default)]
    struct HashMapStringValue {
        key: String,
        value: String,
    }

    /// Message for list options response.
    #[derive(Debug, Default)]
    pub struct ListOptionsResult {
        /// List of available options.
        pub options: Vec<OptionHelp>,
    }

    /// Message representing a help option.
    #[derive(Debug, Default)]
    pub struct OptionHelp {
        /// Name of the option.
        pub name: String,
        /// Type of the option.
        pub ty: String,
        /// Flag indicating if the option is required.
        pub required: bool,
        /// Default value of the option.
        pub default_value: String,
        /// Help text for the option.
        pub help: String,
    }

    /// Message representing a symbol in KCL.
    #[derive(Debug, Default)]
    pub struct Symbol {
        /// Type of the symbol.
        pub ty: OptionalKclType,
        /// Name of the symbol.
        pub name: String,
        /// Owner of the symbol.
        pub owner: OptionalSymbolIndex,
        /// Definition of the symbol.
        pub def: OptionalSymbolIndex,
        /// Attributes of the symbol.
        pub attrs: Vec<SymbolIndex>,
        /// Flag indicating if the symbol is global.
        pub is_global: bool,
    }

    /// Message representing a scope in KCL.
    #[derive(Debug, Default)]
    pub struct Scope {
        /// Type of the scope.
        pub kind: String,
        /// Parent scope.
        pub parent: OptionalScopeIndex,
        /// Owner of the scope.
        pub owner: OptionalSymbolIndex,
        /// Children of the scope.
        pub children: Vec<ScopeIndex>,
        /// Definitions in the scope.
        pub defs: Vec<SymbolIndex>,
    }

    #[derive(Debug, Default)]
    struct OptionalScopeIndex {
        has_value: bool,
        value: ScopeIndex,
    }

    #[derive(Debug, Default)]
    struct OptionalSymbolIndex {
        has_value: bool,
        value: SymbolIndex,
    }

    /// Message representing a symbol index.
    #[derive(Debug, Default)]
    pub struct SymbolIndex {
        /// Index identifier.
        pub i: u64,
        /// Global identifier.
        pub g: u64,
        /// Type of the symbol or scope.
        pub kind: String,
    }

    /// Message representing a scope index.
    #[derive(Debug, Default)]
    pub struct ScopeIndex {
        /// Index identifier.
        pub i: u64,
        /// Global identifier.
        pub g: u64,
        /// Type of the scope.
        pub kind: String,
    }

    /// Message for format code request arguments.
    pub struct FormatCodeArgs {
        /// Source code to be formatted.
        pub source: String,
    }
    /// Message for format code response.
    pub struct FormatCodeResult {
        /// Formatted code as bytes.
        pub formatted: String,
    }

    /// Message for format file path request arguments.
    pub struct FormatPathArgs {
        /// Path of the file to format.
        pub path: String,
    }

    /// Message for format file path response.
    pub struct FormatPathResult {
        /// List of changed file paths.
        pub changed_paths: Vec<String>,
    }

    /// Message for lint file path request arguments.
    pub struct LintPathArgs {
        /// Paths of the files to lint.
        pub paths: Vec<String>,
    }

    /// Message for lint file path response.
    pub struct LintPathResult {
        /// List of lint results.
        pub results: Vec<String>,
    }

    /// Message for validate code request arguments.
    pub struct ValidateCodeArgs {
        /// Path to the data file.
        datafile: String,
        /// Data content.
        data: String,
        /// Path to the code file.
        file: String,
        /// Source code content.
        code: String,
        /// Name of the schema.
        schema: String,
        /// Name of the attribute.
        attribute_name: String,
        /// Format of the validation (e.g., "json", "yaml").
        format: String,
    }

    /// Message for validate code response.
    pub struct ValidateCodeResult {
        /// Flag indicating if validation was successful.
        success: bool,
        /// Error message from validation.
        err_message: String,
    }

    /// Message for override file request arguments.
    pub struct OverrideFileArgs {
        /// Path of the file to override.
        file: String,
        /// List of override specifications.
        specs: Vec<String>,
        /// List of import paths.
        import_paths: Vec<String>,
    }

    /// Message for override file response.
    pub struct OverrideFileResult {
        /// Result of the override operation.
        pub result: bool,
        // List of parse errors encountered.
        pub parse_errors: Vec<Error>,
    }

    /// Message for list variables options.
    #[derive(Debug, Default)]
    pub struct ListVariablesOptions {
        /// Flag to merge program configuration.
        pub merge_program: bool,
    }

    /// Message for list variables request arguments.
    #[derive(Debug, Default)]
    pub struct ListVariablesArgs {
        /// Files to be processed.
        pub files: Vec<String>,
        /// Specifications for variables.
        pub specs: Vec<String>,
        /// Options for listing variables.
        pub options: OptionalListVariablesOptions,
    }

    #[derive(Debug, Default)]
    struct OptionalListVariablesOptions {
        has_value: bool,
        value: ListVariablesOptions,
    }

    /// Message for list variables response.
    pub struct ListVariablesResult {
        /// Map of variable lists by file.
        pub variables: Vec<HashMapVariableListValue>,
        /// List of unsupported codes.
        pub unsupported_codes: Vec<String>,
        /// List of parse errors encountered.
        pub parse_errors: Vec<Error>,
    }

    struct HashMapVariableListValue {
        key: String,
        value: Vec<Variable>,
    }

    /// Message representing a variable.
    #[derive(Debug, Default)]
    pub struct Variable {
        /// Value of the variable.
        pub value: String,
        /// Type name of the variable.
        pub type_name: String,
        /// Operation symbol associated with the variable.
        pub op_sym: String,
        /// List items if the variable is a list.
        pub list_items: Vec<Variable>,
        /// Dictionary entries if the variable is a dictionary.
        pub dict_entries: Vec<MapEntry>,
    }
    /// Message representing a map entry.
    #[derive(Debug, Default)]
    pub struct MapEntry {
        /// Key of the map entry.
        pub key: String,
        /// Value of the map entry.
        pub value: OptionalVariable,
    }

    #[derive(Debug, Default)]
    struct OptionalVariable {
        has_value: bool,
        value: Variable,
    }

    #[derive(Debug, Default)]
    /// Message for get schema type mapping request arguments.
    pub struct GetSchemaTypeMappingArgs {
        /// Arguments for executing the program.
        pub exec_args: OptionalExecProgramArgs,
        /// Name of the schema.
        pub schema_name: String,
    }

    #[derive(Debug, Default)]
    struct OptionalExecProgramArgs {
        has_value: bool,
        value: ExecProgramArgs,
    }

    #[derive(Debug, Default)]
    /// Message for get schema type mapping response.
    pub struct GetSchemaTypeMappingResult {
        /// Map of schema type mappings.
        pub schema_type_mapping: Vec<HashMapKclTypeValue>,
    }

    #[derive(Debug, Default)]
    struct HashMapKclTypeValue {
        key: String,
        value: KclType,
    }

    #[derive(Debug, Default)]
    /// Message for load settings files request arguments.
    pub struct LoadSettingsFilesArgs {
        /// Working directory.
        pub work_dir: String,
        /// Setting files to load.
        pub files: Vec<String>,
    }

    #[derive(Debug, Default)]
    /// Message for load settings files response.
    pub struct LoadSettingsFilesResult {
        /// KCL CLI configuration.
        pub kcl_cli_configs: OptionalCliConfig,
        /// List of KCL options as key-value pairs.
        pub kcl_options: Vec<KeyValuePair>,
    }

    #[derive(Debug, Default)]
    struct OptionalCliConfig {
        has_value: bool,
        value: CliConfig,
    }

    #[derive(Debug, Default)]
    /// Message representing KCL CLI configuration.
    pub struct CliConfig {
        /// List of files.
        pub files: Vec<String>,
        /// Output path.
        pub output: String,
        /// List of overrides.
        pub overrides: Vec<String>,
        /// Path selectors.
        pub path_selector: Vec<String>,
        /// Flag for strict range check.
        pub strict_range_check: bool,
        /// Flag to disable none values.
        pub disable_none: bool,
        /// Verbose level.
        pub verbose: i64,
        /// Debug flag.
        pub debug: bool,
        /// Flag to sort keys in YAML/JSON results.
        pub sort_keys: bool,
        /// Flag to show hidden attributes.
        pub show_hidden: bool,
        /// Flag to include schema type path in results.
        pub include_schema_type_path: bool,
        /// Flag for fast evaluation.
        pub fast_eval: bool,
    }

    /// Message representing a key-value pair.
    #[derive(Debug, Default)]
    pub struct KeyValuePair {
        /// Key of the pair.
        pub key: String,
        /// Value of the pair.
        pub value: String,
    }

    /// Message for rename request arguments.
    #[derive(Debug, Default)]
    pub struct RenameArgs {
        /// File path to the package root.
        pub package_root: String,
        /// Path to the target symbol to be renamed.
        pub symbol_path: String,
        /// Paths to the source code files.
        pub file_paths: Vec<String>,
        /// New name of the symbol.
        pub new_name: String,
    }
    /// Message for rename response.
    #[derive(Debug, Default)]
    pub struct RenameResult {
        /// List of file paths that got changed.
        pub changed_files: Vec<String>,
    }
    /// Message for rename code request arguments.
    pub struct RenameCodeArgs {
        /// File path to the package root.
        pub package_root: String,
        /// Path to the target symbol to be renamed.
        pub symbol_path: String,
        /// Map of source code with filename as key and code as value.
        pub source_codes: Vec<HashMapStringValue>,
        /// New name of the symbol.
        pub new_name: String,
    }
    /// Message for rename code response.
    pub struct RenameCodeResult {
        /// Map of changed code with filename as key and modified code as value.
        pub changed_codes: Vec<HashMapStringValue>,
    }

    /// Message for test request arguments.
    pub struct TestArgs {
        /// Execution program arguments.
        pub exec_args: OptionalExecProgramArgs,
        /// List of KCL package paths to be tested.
        pub pkg_list: Vec<String>,
        /// Regular expression for filtering tests to run.
        pub run_regexp: String,
        /// Flag to stop the test run on the first failure.
        pub fail_fast: bool,
    }
    /// Message for test response.
    pub struct TestResult {
        /// List of test case information.
        pub info: Vec<TestCaseInfo>,
    }
    /// Message representing information about a single test case.
    pub struct TestCaseInfo {
        /// Name of the test case.
        pub name: String,
        /// Error message if any.
        pub error: String,
        /// Duration of the test case in microseconds.
        pub duration: u64,
        /// Log message from the test case.
        pub log_message: String,
    }

    /// Message representing a KCL type.
    #[derive(Debug, Default)]
    pub struct KclType {
        /// Type name (e.g., schema, dict, list, str, int, float, bool, any, union, number_multiplier).
        pub ty: String,
        /// Union types if applicable.
        pub union_types: Vec<KclType>,
        /// Default value of the type.
        pub default_value: String,
        /// Name of the schema if applicable.
        pub schema_name: String,
        /// Documentation for the schema.
        pub schema_doc: String,
        /// Properties of the schema as a map with property name as key.
        pub properties: Vec<HashMapKclTypeValue>,
        /// List of required schema properties.
        pub required: Vec<String>,
        /// Key type if the KclType is a dictionary.
        pub key: OptionalKclType,
        /// Item type if the KclType is a list or dictionary.
        pub item: OptionalKclType,
        /// Line number where the type is defined.
        pub line: i32,
        /// List of decorators for the schema.
        pub decorators: Vec<Decorator>,
        /// Absolute path of the file where the attribute is located.
        pub filename: String,
        /// Path of the package where the attribute is located.
        pub pkg_path: String,
        /// Documentation for the attribute.
        pub description: String,
        /// Map of examples with example name as key.
        pub examples: Vec<HashMapExampleValue>,
        /// Base schema if applicable.
        pub base_schema: OptionalKclType,
    }

    #[derive(Debug, Default)]
    struct HashMapExampleValue {
        key: String,
        value: Example,
    }

    #[derive(Debug, Default)]
    struct OptionalKclType {
        has_value: bool,
        value: String,
    }

    #[derive(Debug, Default)]
    /// Message representing a decorator in KCL.
    pub struct Decorator {
        /// Name of the decorator.
        pub name: String,
        /// Arguments for the decorator.
        pub arguments: Vec<String>,
        /// Keyword arguments for the decorator as a map with keyword name as key.
        pub keywords: Vec<HashMapStringValue>,
    }

    #[derive(Debug, Default)]
    struct HashMapValue {
        key: String,
        value: String,
    }

    #[derive(Debug, Default)]
    /// Message representing an example in KCL.
    pub struct Example {
        /// Short description for the example.
        pub summary: String,
        /// Long description for the example.
        pub description: String,
        /// Embedded literal example.
        pub value: String,
    }

    #[derive(Debug, Default)]
    /// Message for update dependencies request arguments.
    pub struct UpdateDependenciesArgs {
        /// Path to the manifest file.
        pub manifest_path: String,
        /// Flag to vendor dependencies locally.
        pub vendor: bool,
    }

    #[derive(Debug, Default)]
    /// Message for update dependencies response.
    pub struct UpdateDependenciesResult {
        /// List of external packages updated.
        pub external_pkgs: Vec<ExternalPkg>,
    }

    extern "Rust" {
        /// Execute KCL file with arguments and return the JSON/YAML result.
        fn exec_program(args: &ExecProgramArgs) -> Result<ExecProgramResult>;
        /// Validate code using schema and JSON/YAML data strings.
        fn validate_code(args: &ValidateCodeArgs) -> Result<ValidateCodeResult>;
        /// Override KCL file with arguments.
        /// See [https://www.kcl-lang.io/docs/user_docs/guides/automation](https://www.kcl-lang.io/docs/user_docs/guides/automation)
        /// for more override spec guide.
        fn override_file(args: &OverrideFileArgs) -> Result<OverrideFileResult>;
        /// Download and update dependencies defined in the `kcl.mod` file and return the
        /// external package name and location list.
        fn update_dependencies(args: &UpdateDependenciesArgs) -> Result<UpdateDependenciesResult>;
        /// Provides users with the ability to parse KCL program and semantic
        /// model information including symbols, types, definitions, etc.
        fn load_package(args: &LoadPackageArgs) -> Result<LoadPackageResult>;
        /// Parse KCL program with entry files.
        fn parse_program(args: &ParseProgramArgs) -> Result<ParseProgramResult>;
        /// Parse KCL single file to Module AST JSON string with import dependencies
        /// and parse errors.
        fn parse_file(args: &ParseFileArgs) -> Result<ParseFileResult>;
        /// Provides users with the ability to parse kcl program and get all option information.
        fn list_options(args: &ParseProgramArgs) -> Result<ListOptionsResult>;
        /// Provides users with the ability to parse KCL program and get
        /// all variables by specs.
        fn list_variables(args: &ListVariablesArgs) -> Result<ListVariablesResult>;
        /// Get schema type mapping.
        fn get_schema_type_mapping(
            args: &GetSchemaTypeMappingArgs,
        ) -> Result<GetSchemaTypeMappingResult>;
        /// Format KCL file or directory path contains KCL files and returns the changed file paths.
        fn format_code(args: &FormatCodeArgs) -> Result<FormatCodeResult>;
        /// Format KCL file or directory path contains KCL files and returns the changed file paths.
        fn format_path(args: &FormatPathArgs) -> Result<FormatPathResult>;
        /// Lint files and return error messages including errors and warnings.
        fn lint_path(args: &LintPathArgs) -> Result<LintPathResult>;
        /// Load the setting file config defined in `kcl.yaml`
        fn load_settings_files(args: &LoadSettingsFilesArgs) -> Result<LoadSettingsFilesResult>;
        /// Rename all the occurrences of the target symbol in the files. This API will rewrite files if they contain symbols to be renamed.
        /// Return the file paths that got changed.
        fn rename(args: &RenameArgs) -> Result<RenameResult>;
        /// Rename all the occurrences of the target symbol and return the modified code if any code has been changed. This API won't
        /// rewrite files but return the changed code.
        fn rename_code(args: &RenameCodeArgs) -> Result<RenameCodeResult>;
        /// Test KCL packages with test arguments.
        fn test(args: &TestArgs) -> Result<TestResult>;
        /// Return the KCL service version information.
        fn get_version() -> Result<GetVersionResult>;
    }
}

use ffi::*;

impl crate::ffi::Error {
    #[inline]
    fn new(e: &kclvm_api::Error) -> Self {
        Self {
            level: e.level.clone(),
            code: e.code.clone(),
            messages: e
                .messages
                .iter()
                .map(|m| Message {
                    msg: m.msg.clone(),
                    pos: m
                        .pos
                        .as_ref()
                        .map(|p| Position {
                            line: p.line,
                            column: p.column,
                            filename: p.filename.clone(),
                        })
                        .unwrap_or_default(),
                })
                .collect(),
        }
    }
}

impl UpdateDependenciesResult {
    #[inline]
    fn new(r: kclvm_api::UpdateDependenciesResult) -> Self {
        Self {
            external_pkgs: r
                .external_pkgs
                .iter()
                .map(|p| ExternalPkg {
                    pkg_name: p.pkg_name.clone(),
                    pkg_path: p.pkg_path.clone(),
                })
                .collect(),
        }
    }
}

#[inline]
fn build_exec_program_args(args: &ExecProgramArgs) -> kclvm_api::ExecProgramArgs {
    kclvm_api::ExecProgramArgs {
        work_dir: args.work_dir.clone(),
        k_filename_list: args.k_filename_list.clone(),
        k_code_list: args.k_code_list.clone(),
        args: args
            .args
            .iter()
            .map(|a| kclvm_api::Argument {
                name: a.name.clone(),
                value: a.value.clone(),
            })
            .collect::<Vec<kclvm_api::Argument>>(),
        external_pkgs: args
            .external_pkgs
            .iter()
            .map(|e| kclvm_api::ExternalPkg {
                pkg_name: e.pkg_name.clone(),
                pkg_path: e.pkg_path.clone(),
            })
            .collect::<Vec<kclvm_api::ExternalPkg>>(),
        overrides: args.overrides.clone(),
        strict_range_check: args.strict_range_check,
        disable_none: args.disable_none,
        verbose: args.verbose,
        debug: args.debug,
        sort_keys: args.sort_keys,
        show_hidden: args.show_hidden,
        compile_only: args.compile_only,
        path_selector: args.path_selector.clone(),
        fast_eval: args.fast_eval,
        disable_yaml_result: args.disable_yaml_result,
        include_schema_type_path: args.include_schema_type_path,
        print_override_ast: args.print_override_ast,
    }
}

#[inline]
fn build_optional_exec_program_args(
    args: &OptionalExecProgramArgs,
) -> Option<kclvm_api::ExecProgramArgs> {
    if args.has_value {
        Some(build_exec_program_args(&args.value))
    } else {
        None
    }
}

/// Execute KCL file with arguments and return the JSON/YAML result.
fn exec_program(args: &ExecProgramArgs) -> Result<ExecProgramResult> {
    let api = kclvm_api::API::default();
    let result = api.exec_program(&build_exec_program_args(args))?;
    Ok(ExecProgramResult {
        yaml_result: result.yaml_result,
        json_result: result.json_result,
        log_message: result.log_message,
        err_message: result.err_message,
    })
}

/// Validate code using schema and JSON/YAML data strings.
fn validate_code(args: &ValidateCodeArgs) -> Result<ValidateCodeResult> {
    let api = kclvm_api::API::default();
    let result = api.validate_code(&kclvm_api::ValidateCodeArgs {
        datafile: args.datafile.clone(),
        data: args.data.clone(),
        file: args.file.clone(),
        code: args.code.clone(),
        schema: args.schema.clone(),
        attribute_name: args.attribute_name.clone(),
        format: args.format.clone(),
    })?;
    Ok(ValidateCodeResult {
        success: result.success,
        err_message: result.err_message,
    })
}

/// Override KCL file with arguments.
/// See [https://www.kcl-lang.io/docs/user_docs/guides/automation](https://www.kcl-lang.io/docs/user_docs/guides/automation)
/// for more override spec guide.
fn override_file(args: &OverrideFileArgs) -> Result<OverrideFileResult> {
    let api = kclvm_api::API::default();
    let result = api.override_file(&kclvm_api::OverrideFileArgs {
        file: args.file.clone(),
        specs: args.specs.clone(),
        import_paths: args.import_paths.clone(),
    })?;
    Ok(OverrideFileResult {
        result: result.result,
        parse_errors: result
            .parse_errors
            .iter()
            .map(crate::ffi::Error::new)
            .collect(),
    })
}

/// Download and update dependencies defined in the `kcl.mod` file and return the
/// external package name and location list.
fn update_dependencies(args: &UpdateDependenciesArgs) -> Result<UpdateDependenciesResult> {
    let api = kclvm_api::API::default();
    let result = api.update_dependencies(&kclvm_api::UpdateDependenciesArgs {
        manifest_path: args.manifest_path.clone(),
        vendor: args.vendor,
    })?;
    Ok(UpdateDependenciesResult::new(result))
}

#[inline]
fn build_load_package_args(args: &LoadPackageArgs) -> kclvm_api::LoadPackageArgs {
    kclvm_api::LoadPackageArgs {
        parse_args: build_optional_parse_program_args(&args.parse_args),
        resolve_ast: args.resolve_ast,
        load_builtin: args.load_builtin,
        with_ast_index: args.with_ast_index,
    }
}

impl LoadPackageResult {
    #[inline]
    fn new(r: kclvm_api::LoadPackageResult) -> Self {
        Self {
            program: r.program,
            paths: r.paths,
            parse_errors: r.parse_errors.iter().map(crate::ffi::Error::new).collect(),
            type_errors: r.type_errors.iter().map(crate::ffi::Error::new).collect(),
            scopes: r
                .scopes
                .iter()
                .map(|(k, v)| HashMapScopeValue {
                    key: k.to_string(),
                    value: Scope {
                        kind: v.kind.clone(),
                        parent: OptionalScopeIndex::new(&v.parent),
                        owner: OptionalSymbolIndex::new(&v.owner),
                        children: v.children.iter().map(ScopeIndex::new).collect(),
                        defs: v.defs.iter().map(SymbolIndex::new).collect(),
                    },
                })
                .collect(),
            symbols: r
                .symbols
                .iter()
                .map(|(k, v)| HashMapSymbolValue {
                    key: k.to_string(),
                    value: Symbol::new(v),
                })
                .collect(),
            node_symbol_map: r
                .node_symbol_map
                .iter()
                .map(|(k, v)| HashMapSymbolIndexValue {
                    key: k.to_string(),
                    value: SymbolIndex::new(v),
                })
                .collect(),
            symbol_node_map: r
                .symbol_node_map
                .iter()
                .map(|(k, v)| HashMapStringValue {
                    key: k.to_string(),
                    value: v.to_string(),
                })
                .collect(),
            fully_qualified_name_map: r
                .fully_qualified_name_map
                .iter()
                .map(|(k, v)| HashMapSymbolIndexValue {
                    key: k.to_string(),
                    value: SymbolIndex::new(v),
                })
                .collect(),
            pkg_scope_map: r
                .pkg_scope_map
                .iter()
                .map(|(k, v)| HashMapScopeIndexValue {
                    key: k.to_string(),
                    value: ScopeIndex::new(v),
                })
                .collect(),
        }
    }
}

impl ScopeIndex {
    #[inline]
    pub fn new(v: &kclvm_api::ScopeIndex) -> Self {
        ScopeIndex {
            i: v.i,
            g: v.g,
            kind: v.kind.clone(),
        }
    }
}

impl OptionalScopeIndex {
    #[inline]
    fn new(v: &Option<kclvm_api::ScopeIndex>) -> Self {
        match v {
            Some(v) => Self {
                has_value: true,
                value: ScopeIndex::new(v),
            },
            None => Self {
                has_value: false,
                value: ScopeIndex::default(),
            },
        }
    }
}

impl SymbolIndex {
    #[inline]
    fn new(v: &kclvm_api::SymbolIndex) -> Self {
        Self {
            i: v.i,
            g: v.g,
            kind: v.kind.clone(),
        }
    }
}

impl OptionalSymbolIndex {
    #[inline]
    fn new(v: &Option<kclvm_api::SymbolIndex>) -> Self {
        match v {
            Some(v) => Self {
                has_value: true,
                value: SymbolIndex::new(v),
            },
            None => Self {
                has_value: false,
                value: SymbolIndex::default(),
            },
        }
    }
}

impl Symbol {
    #[inline]
    pub fn new(v: &kclvm_api::Symbol) -> Self {
        Self {
            ty: OptionalKclType::new(&v.ty),
            name: v.name.clone(),
            owner: OptionalSymbolIndex::new(&v.owner),
            def: OptionalSymbolIndex::new(&v.def),
            attrs: v.attrs.iter().map(SymbolIndex::new).collect(),
            is_global: v.is_global,
        }
    }
}

/// Provides users with the ability to parse KCL program and semantic
/// model information including symbols, types, definitions, etc.
fn load_package(args: &LoadPackageArgs) -> Result<LoadPackageResult> {
    let api = kclvm_api::API::default();
    let result = api.load_package(&build_load_package_args(args))?;
    Ok(LoadPackageResult::new(result))
}

fn build_parse_program_args(args: &ParseProgramArgs) -> kclvm_api::ParseProgramArgs {
    kclvm_api::ParseProgramArgs {
        paths: args.paths.clone(),
        sources: args.sources.clone(),
        external_pkgs: args
            .external_pkgs
            .iter()
            .map(|e| kclvm_api::ExternalPkg {
                pkg_name: e.pkg_name.clone(),
                pkg_path: e.pkg_path.clone(),
            })
            .collect::<Vec<kclvm_api::ExternalPkg>>(),
    }
}

fn build_optional_parse_program_args(
    args: &OptionalParseProgramArgs,
) -> Option<kclvm_api::ParseProgramArgs> {
    if args.has_value {
        let args = &args.value;
        Some(kclvm_api::ParseProgramArgs {
            paths: args.paths.clone(),
            sources: args.sources.clone(),
            external_pkgs: args
                .external_pkgs
                .iter()
                .map(|e| kclvm_api::ExternalPkg {
                    pkg_name: e.pkg_name.clone(),
                    pkg_path: e.pkg_path.clone(),
                })
                .collect::<Vec<kclvm_api::ExternalPkg>>(),
        })
    } else {
        None
    }
}

impl ParseProgramResult {
    #[inline]
    fn new(r: kclvm_api::ParseProgramResult) -> Self {
        Self {
            ast_json: r.ast_json,
            paths: r.paths,
            errors: r.errors.iter().map(crate::ffi::Error::new).collect(),
        }
    }
}

/// Parse KCL program with entry files.
fn parse_program(args: &ParseProgramArgs) -> Result<ParseProgramResult> {
    let api = kclvm_api::API::default();
    let result = api.parse_program(&build_parse_program_args(args))?;
    Ok(ParseProgramResult::new(result))
}

fn build_parse_file_args(args: &ParseFileArgs) -> kclvm_api::ParseFileArgs {
    kclvm_api::ParseFileArgs {
        path: args.path.clone(),
        source: args.source.clone(),
        external_pkgs: args
            .external_pkgs
            .iter()
            .map(|e| kclvm_api::ExternalPkg {
                pkg_name: e.pkg_name.clone(),
                pkg_path: e.pkg_path.clone(),
            })
            .collect::<Vec<kclvm_api::ExternalPkg>>(),
    }
}

impl ParseFileResult {
    #[inline]
    fn new(r: kclvm_api::ParseFileResult) -> Self {
        Self {
            ast_json: r.ast_json,
            deps: r.deps,
            errors: r.errors.iter().map(crate::ffi::Error::new).collect(),
        }
    }
}

/// Parse KCL single file to Module AST JSON string with import dependencies
/// and parse errors.
fn parse_file(args: &ParseFileArgs) -> Result<ParseFileResult> {
    let api = kclvm_api::API::default();
    let result = api.parse_file(&build_parse_file_args(args))?;
    Ok(ParseFileResult::new(result))
}

impl ListOptionsResult {
    #[inline]
    fn new(r: kclvm_api::ListOptionsResult) -> Self {
        Self {
            options: r
                .options
                .iter()
                .map(|r| OptionHelp {
                    name: r.name.clone(),
                    ty: r.r#type.clone(),
                    required: r.required,
                    default_value: r.default_value.clone(),
                    help: r.help.clone(),
                })
                .collect(),
        }
    }
}

/// Provides users with the ability to parse kcl program and get all option information.
fn list_options(args: &ParseProgramArgs) -> Result<ListOptionsResult> {
    let api = kclvm_api::API::default();
    let result = api.list_options(&build_parse_program_args(args))?;
    Ok(ListOptionsResult::new(result))
}

fn build_list_variables_args(args: &ListVariablesArgs) -> kclvm_api::ListVariablesArgs {
    kclvm_api::ListVariablesArgs {
        files: args.files.clone(),
        specs: args.specs.clone(),
        options: match args.options.has_value {
            true => Some(kclvm_api::ListVariablesOptions {
                merge_program: args.options.value.merge_program,
            }),
            false => None,
        },
    }
}

impl Variable {
    pub fn new(v: &kclvm_api::Variable) -> Self {
        Self {
            value: v.value.to_string(),
            type_name: v.type_name.to_string(),
            op_sym: v.op_sym.to_string(),
            list_items: v.list_items.iter().map(Variable::new).collect(),
            dict_entries: v
                .dict_entries
                .iter()
                .map(|e| MapEntry {
                    key: e.key.to_string(),
                    value: match &e.value {
                        Some(value) => OptionalVariable {
                            has_value: true,
                            value: Variable::new(value),
                        },
                        None => OptionalVariable {
                            has_value: false,
                            value: Variable::default(),
                        },
                    },
                })
                .collect(),
        }
    }
}

impl ListVariablesResult {
    #[inline]
    fn new(r: kclvm_api::ListVariablesResult) -> Self {
        Self {
            variables: r
                .variables
                .iter()
                .map(|(k, v)| HashMapVariableListValue {
                    key: k.to_string(),
                    value: v.variables.iter().map(Variable::new).collect(),
                })
                .collect(),
            unsupported_codes: r.unsupported_codes,
            parse_errors: r.parse_errors.iter().map(crate::ffi::Error::new).collect(),
        }
    }
}

/// Provides users with the ability to parse KCL program and get
/// all variables by specs.
fn list_variables(args: &ListVariablesArgs) -> Result<ListVariablesResult> {
    let api = kclvm_api::API::default();
    let result = api.list_variables(&build_list_variables_args(args))?;
    Ok(ListVariablesResult::new(result))
}

fn build_get_schema_type_mapping_args(
    args: &GetSchemaTypeMappingArgs,
) -> kclvm_api::GetSchemaTypeMappingArgs {
    kclvm_api::GetSchemaTypeMappingArgs {
        exec_args: if args.exec_args.has_value {
            Some(build_exec_program_args(&args.exec_args.value))
        } else {
            None
        },
        schema_name: args.schema_name.clone(),
    }
}

impl GetSchemaTypeMappingResult {
    #[inline]
    fn new(r: kclvm_api::GetSchemaTypeMappingResult) -> Self {
        Self {
            schema_type_mapping: r
                .schema_type_mapping
                .iter()
                .map(|(k, v)| HashMapKclTypeValue {
                    key: k.to_string(),
                    value: KclType::new(v),
                })
                .collect(),
        }
    }
}

impl KclType {
    #[inline]
    fn new(r: &kclvm_api::KclType) -> Self {
        Self {
            ty: r.r#type.clone(),
            union_types: r.union_types.iter().map(|r| KclType::new(r)).collect(),
            default_value: r.default.clone(),
            schema_name: r.schema_name.clone(),
            schema_doc: r.schema_doc.clone(),
            properties: r
                .properties
                .iter()
                .map(|(k, v)| HashMapKclTypeValue {
                    key: k.to_string(),
                    value: KclType::new(v),
                })
                .collect(),
            required: r.required.clone(),
            key: OptionalKclType::new_from_box(&r.key),
            base_schema: OptionalKclType::new_from_box(&r.base_schema),
            decorators: r
                .decorators
                .iter()
                .map(|d| Decorator {
                    name: d.name.clone(),
                    arguments: d.arguments.clone(),
                    keywords: d
                        .keywords
                        .iter()
                        .map(|(k, v)| HashMapStringValue {
                            key: k.to_string(),
                            value: v.to_string(),
                        })
                        .collect(),
                })
                .collect(),
            description: r.description.clone(),
            examples: r
                .examples
                .iter()
                .map(|(k, e)| HashMapExampleValue {
                    key: k.to_string(),
                    value: Example {
                        summary: e.summary.clone(),
                        description: e.description.clone(),
                        value: e.value.clone(),
                    },
                })
                .collect(),
            filename: r.filename.clone(),
            pkg_path: r.pkg_path.clone(),
            line: r.line,
            item: OptionalKclType::new_from_box(&r.item),
        }
    }
}

impl OptionalKclType {
    #[inline]
    fn new(r: &Option<kclvm_api::KclType>) -> Self {
        match r.as_ref() {
            None => Self {
                has_value: false,
                value: Default::default(),
            },
            Some(r) => Self {
                has_value: true,
                value: r.r#type.clone(),
            },
        }
    }

    #[inline]
    fn new_from_box(r: &Option<Box<kclvm_api::KclType>>) -> Self {
        match r.as_ref() {
            None => Self {
                has_value: false,
                value: Default::default(),
            },
            Some(r) => Self {
                has_value: true,
                value: r.r#type.clone(),
            },
        }
    }
}

/// Get schema type mapping.
fn get_schema_type_mapping(args: &GetSchemaTypeMappingArgs) -> Result<GetSchemaTypeMappingResult> {
    let api = kclvm_api::API::default();
    let result = api.get_schema_type_mapping(&build_get_schema_type_mapping_args(args))?;
    Ok(GetSchemaTypeMappingResult::new(result))
}

fn build_format_code_args(args: &FormatCodeArgs) -> kclvm_api::FormatCodeArgs {
    kclvm_api::FormatCodeArgs {
        source: args.source.clone(),
    }
}

impl FormatCodeResult {
    #[inline]
    fn new(r: kclvm_api::FormatCodeResult) -> Self {
        Self {
            formatted: String::from_utf8(r.formatted).unwrap(),
        }
    }
}

/// Format KCL file or directory path contains KCL files and returns the changed file paths.
fn format_code(args: &FormatCodeArgs) -> Result<FormatCodeResult> {
    let api = kclvm_api::API::default();
    let result = api.format_code(&build_format_code_args(args))?;
    Ok(FormatCodeResult::new(result))
}

fn build_format_path_args(args: &FormatPathArgs) -> kclvm_api::FormatPathArgs {
    kclvm_api::FormatPathArgs {
        path: args.path.clone(),
    }
}

impl FormatPathResult {
    #[inline]
    fn new(r: kclvm_api::FormatPathResult) -> Self {
        Self {
            changed_paths: r.changed_paths,
        }
    }
}

/// Format KCL file or directory path contains KCL files and returns the changed file paths.
fn format_path(args: &FormatPathArgs) -> Result<FormatPathResult> {
    let api = kclvm_api::API::default();
    let result = api.format_path(&build_format_path_args(args))?;
    Ok(FormatPathResult::new(result))
}

fn build_lint_path_args(args: &LintPathArgs) -> kclvm_api::LintPathArgs {
    kclvm_api::LintPathArgs {
        paths: args.paths.clone(),
    }
}

impl LintPathResult {
    #[inline]
    fn new(r: kclvm_api::LintPathResult) -> Self {
        Self { results: r.results }
    }
}

/// Lint files and return error messages including errors and warnings.
fn lint_path(args: &LintPathArgs) -> Result<LintPathResult> {
    let api = kclvm_api::API::default();
    let result = api.lint_path(&build_lint_path_args(args))?;
    Ok(LintPathResult::new(result))
}

fn build_load_settings_files_args(
    args: &LoadSettingsFilesArgs,
) -> kclvm_api::LoadSettingsFilesArgs {
    kclvm_api::LoadSettingsFilesArgs {
        work_dir: args.work_dir.clone(),
        files: args.files.clone(),
    }
}

impl LoadSettingsFilesResult {
    #[inline]
    fn new(r: kclvm_api::LoadSettingsFilesResult) -> Self {
        Self {
            kcl_cli_configs: OptionalCliConfig::new(r.kcl_cli_configs),
            kcl_options: r
                .kcl_options
                .iter()
                .map(|v| KeyValuePair {
                    key: v.key.clone(),
                    value: v.value.clone(),
                })
                .collect(),
        }
    }
}

impl OptionalCliConfig {
    fn new(r: Option<kclvm_api::CliConfig>) -> Self {
        match r {
            Some(r) => Self {
                has_value: true,
                value: CliConfig {
                    files: r.files,
                    output: r.output,
                    overrides: r.overrides,
                    path_selector: r.path_selector,
                    strict_range_check: r.strict_range_check,
                    disable_none: r.disable_none,
                    verbose: r.verbose,
                    debug: r.debug,
                    sort_keys: r.sort_keys,
                    show_hidden: r.show_hidden,
                    include_schema_type_path: r.include_schema_type_path,
                    fast_eval: r.fast_eval,
                },
            },
            None => Self {
                has_value: false,
                value: CliConfig::default(),
            },
        }
    }
}

/// Load the setting file config defined in `kcl.yaml`
fn load_settings_files(args: &LoadSettingsFilesArgs) -> Result<LoadSettingsFilesResult> {
    let api = kclvm_api::API::default();
    let result = api.load_settings_files(&build_load_settings_files_args(args))?;
    Ok(LoadSettingsFilesResult::new(result))
}

fn build_rename_args(args: &RenameArgs) -> kclvm_api::RenameArgs {
    kclvm_api::RenameArgs {
        package_root: args.package_root.clone(),
        symbol_path: args.symbol_path.clone(),
        file_paths: args.file_paths.clone(),
        new_name: args.new_name.clone(),
    }
}

impl RenameResult {
    #[inline]
    fn new(r: kclvm_api::RenameResult) -> Self {
        Self {
            changed_files: r.changed_files,
        }
    }
}

/// Rename all the occurrences of the target symbol in the files. This API will rewrite files if they contain symbols to be renamed.
/// Return the file paths that got changed.
fn rename(args: &RenameArgs) -> Result<RenameResult> {
    let api = kclvm_api::API::default();
    let result = api.rename(&build_rename_args(args))?;
    Ok(RenameResult::new(result))
}

fn build_rename_code_args(args: &RenameCodeArgs) -> kclvm_api::RenameCodeArgs {
    kclvm_api::RenameCodeArgs {
        package_root: args.package_root.clone(),
        symbol_path: args.symbol_path.clone(),
        source_codes: args
            .source_codes
            .iter()
            .map(|v| (v.key.clone(), v.value.clone()))
            .collect(),
        new_name: args.new_name.clone(),
    }
}

impl RenameCodeResult {
    #[inline]
    fn new(r: kclvm_api::RenameCodeResult) -> Self {
        Self {
            changed_codes: r
                .changed_codes
                .iter()
                .map(|(k, v)| HashMapStringValue {
                    key: k.to_string(),
                    value: v.to_string(),
                })
                .collect(),
        }
    }
}

/// Rename all the occurrences of the target symbol and return the modified code if any code has been changed. This API won't
/// rewrite files but return the changed code.
fn rename_code(args: &RenameCodeArgs) -> Result<RenameCodeResult> {
    let api = kclvm_api::API::default();
    let result = api.rename_code(&build_rename_code_args(args))?;
    Ok(RenameCodeResult::new(result))
}

fn build_test_args(args: &TestArgs) -> kclvm_api::TestArgs {
    kclvm_api::TestArgs {
        exec_args: build_optional_exec_program_args(&args.exec_args),
        pkg_list: args.pkg_list.clone(),
        run_regexp: args.run_regexp.clone(),
        fail_fast: args.fail_fast,
    }
}

impl TestResult {
    #[inline]
    fn new(r: kclvm_api::TestResult) -> Self {
        Self {
            info: r
                .info
                .iter()
                .map(|t| TestCaseInfo {
                    name: t.name.clone(),
                    error: t.error.clone(),
                    duration: t.duration,
                    log_message: t.log_message.clone(),
                })
                .collect(),
        }
    }
}

/// Test KCL packages with test arguments.
fn test(args: &TestArgs) -> Result<TestResult> {
    let api = kclvm_api::API::default();
    let result = api.test(&build_test_args(args))?;
    Ok(TestResult::new(result))
}

/// Return the KCL service version information.
fn get_version() -> Result<GetVersionResult> {
    let api = kclvm_api::API::default();
    let result = api.get_version(&kclvm_api::GetVersionArgs {})?;
    Ok(GetVersionResult {
        version: result.version,
        checksum: result.checksum,
        git_sha: result.git_sha,
        version_info: result.version_info,
    })
}

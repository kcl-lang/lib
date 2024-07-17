extern crate kclvm_api;

use anyhow::Result;

#[cxx::bridge(namespace = "kcl_lib")]
mod ffi {
    /// Message for execute program request arguments.
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
    #[derive(Clone)]
    pub struct ExternalPkg {
        pub pkg_name: String,
        pub pkg_path: String,
    }

    /// kcl main.k -D name=value
    #[derive(Clone)]
    pub struct Argument {
        /// Name of the argument.
        pub name: String,
        /// Value of the argument.
        pub value: String,
    }

    /// Message representing an error.
    pub struct Error {
        /// Level of the error (e.g., "Error", "Warning").
        pub level: String,
        /// Error code. (e.g., "E1001")
        pub code: String,
        /// List of error messages.
        pub messages: Vec<Message>,
    }

    /// Message representing a detailed error message with a position.
    pub struct Message {
        /// The error message text.
        pub msg: String,
        /// The position in the source code where the error occurred.
        pub pos: Position,
    }

    /// Message representing a position in the source code.
    #[derive(Default)]
    pub struct Position {
        /// Line number.
        pub line: i64,
        /// Column number.
        pub column: i64,
        /// Filename the position refers to.
        pub filename: String,
    }

    /// Message for execute program response.
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

    /// Message for update dependencies request arguments.
    pub struct UpdateDependenciesArgs {
        /// Path to the manifest file.
        pub manifest_path: String,
        /// Flag to vendor dependencies locally.
        pub vendor: bool,
    }

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
    }
}

use ffi::*;

impl crate::ffi::Error {
    pub fn new(e: &kclvm_api::Error) -> Self {
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
    pub fn new(r: kclvm_api::UpdateDependenciesResult) -> Self {
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

/// Execute KCL file with arguments and return the JSON/YAML result.
fn exec_program(args: &ExecProgramArgs) -> Result<ExecProgramResult> {
    let api = kclvm_api::API::default();
    let result = api.exec_program(&kclvm_api::ExecProgramArgs {
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
    })?;
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

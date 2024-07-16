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
    pub struct ExternalPkg {
        pub pkg_name: String,
        pub pkg_path: String,
    }

    /// kcl main.k -D name=value
    pub struct Argument {
        pub name: String,
        pub value: String,
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

    extern "Rust" {
        fn exec_program(args: &ExecProgramArgs) -> Result<ExecProgramResult>;
        fn validate_code(args: &ValidateCodeArgs) -> Result<ValidateCodeResult>;
    }
}

use ffi::*;

/// Execute KCL file with arguments and return the JSON/YAML result.
fn exec_program(args: &ExecProgramArgs) -> Result<ExecProgramResult> {
    let api = kclvm_api::API::default();
    let result = api.exec_program(&kclvm_api::ExecProgramArgs {
        work_dir: args.work_dir.clone(),
        k_filename_list: args.k_filename_list.clone(),
        k_code_list: args.k_code_list.clone(),
        // TODO: other arguments.
        ..Default::default()
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

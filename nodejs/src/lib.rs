#![deny(clippy::all)]

#[macro_use]
extern crate napi_derive;

mod spec;

use crate::spec::*;
use napi::bindgen_prelude::*;
use std::collections::HashMap;

/*
* LoadPackage API
*/

/// Message for load package request arguments.
/// - paths: List of KCL files.
/// - sources: List of KCL codes.
/// - resolve_ast: Flag indicating whether to resolve AST.
/// - load_builtin: Flag indicating whether to load built-in modules.
/// - with_ast_index: Flag indicating whether to include AST index.
#[napi]
pub struct LoadPackageArgs(kclvm_api::LoadPackageArgs);

#[napi]
impl LoadPackageArgs {
    #[napi(constructor)]
    pub fn new(
        paths: Vec<String>,
        sources: Vec<String>,
        resolve_ast: Option<bool>,
        load_builtin: Option<bool>,
        with_ast_index: Option<bool>,
    ) -> Result<Self> {
        Ok(Self(kclvm_api::LoadPackageArgs {
            parse_args: Some(kclvm_api::ParseProgramArgs {
                paths,
                sources,
                ..Default::default()
            }),
            resolve_ast: resolve_ast.unwrap_or_default(),
            load_builtin: load_builtin.unwrap_or_default(),
            with_ast_index: with_ast_index.unwrap_or_default(),
        }))
    }
}

/// Provides users with the ability to parse KCL program and semantic
/// model information including symbols, types, definitions, etc.
#[napi]
pub fn load_package(args: &LoadPackageArgs) -> Result<LoadPackageResult> {
    let api = kclvm_api::API::default();
    api.load_package(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(LoadPackageResult::new)
}

/*
* ExecProgram API
*/

/// Message for execute program request arguments.
#[napi]
pub struct ExecProgramArgs(kclvm_api::ExecProgramArgs);

#[napi]
impl ExecProgramArgs {
    #[napi(constructor)]
    pub fn new(
        paths: Vec<String>,
        sources: Option<Vec<String>>,
        work_dir: Option<String>,
        args: Option<Vec<Argument>>,
        overrides: Option<Vec<String>>,
        strict_range_check: Option<bool>,
        disable_none: Option<bool>,
        verbose: Option<i32>,
        debug: Option<i32>,
        sort_keys: Option<bool>,
        external_pkgs: Option<Vec<ExternalPkg>>,
        compile_only: Option<bool>,
        path_selector: Option<Vec<String>>,
        fast_eval: Option<bool>,
    ) -> Result<Self> {
        Ok(Self(kclvm_api::ExecProgramArgs {
            k_filename_list: paths,
            k_code_list: sources.unwrap_or_default(),
            work_dir: work_dir.unwrap_or_default(),
            args: args
                .into_iter()
                .flat_map(|vec| {
                    vec.into_iter()
                        .map(|a| kclvm_api::Argument {
                            name: a.name.clone(),
                            value: a.value.clone(),
                        })
                        .collect::<Vec<kclvm_api::Argument>>()
                })
                .collect(),
            external_pkgs: external_pkgs
                .into_iter()
                .flat_map(|vec| {
                    vec.into_iter()
                        .map(|e| kclvm_api::ExternalPkg {
                            pkg_name: e.pkg_name.clone(),
                            pkg_path: e.pkg_path.clone(),
                        })
                        .collect::<Vec<kclvm_api::ExternalPkg>>()
                })
                .collect(),
            overrides: overrides.unwrap_or_default(),
            strict_range_check: strict_range_check.unwrap_or_default(),
            disable_none: disable_none.unwrap_or_default(),
            verbose: verbose.unwrap_or_default(),
            debug: debug.unwrap_or_default(),
            sort_keys: sort_keys.unwrap_or_default(),
            compile_only: compile_only.unwrap_or_default(),
            path_selector: path_selector.unwrap_or_default(),
            fast_eval: fast_eval.unwrap_or_default(),
            ..Default::default()
        }))
    }
}

/// Execute KCL file with arguments and return the JSON/YAML result.
#[napi]
pub fn exec_program(args: &ExecProgramArgs) -> Result<ExecProgramResult> {
    let api = kclvm_api::API::default();
    api.exec_program(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ExecProgramResult::new)
}

/*
* ParseProgram API
*/

#[napi]
pub struct ParseProgramArgs(kclvm_api::ParseProgramArgs);

#[napi]
impl ParseProgramArgs {
    #[napi(constructor)]
    pub fn new(
        paths: Vec<String>,
        sources: Option<Vec<String>>,
        external_pkgs: Option<Vec<ExternalPkg>>,
    ) -> Result<Self> {
        Ok(Self(kclvm_api::ParseProgramArgs {
            paths,
            sources: sources.unwrap_or_default(),
            external_pkgs: external_pkgs
                .into_iter()
                .flat_map(|vec| {
                    vec.into_iter()
                        .map(|e| kclvm_api::ExternalPkg {
                            pkg_name: e.pkg_name.clone(),
                            pkg_path: e.pkg_path.clone(),
                        })
                        .collect::<Vec<kclvm_api::ExternalPkg>>()
                })
                .collect(),
        }))
    }
}

/// Parse KCL program with entry files.
#[napi]
pub fn parse_program(args: &ParseProgramArgs) -> Result<ParseProgramResult> {
    let api = kclvm_api::API::default();
    api.parse_program(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ParseProgramResult::new)
}

/*
* ParseFile API
*/

#[napi]
pub struct ParseFileArgs(kclvm_api::ParseFileArgs);

#[napi]
impl ParseFileArgs {
    #[napi(constructor)]
    pub fn new(
        path: String,
        source: Option<String>,
        external_pkgs: Option<Vec<ExternalPkg>>,
    ) -> Result<Self> {
        Ok(Self(kclvm_api::ParseFileArgs {
            path,
            source: source.unwrap_or_default(),
            external_pkgs: external_pkgs
                .into_iter()
                .flat_map(|vec| {
                    vec.into_iter()
                        .map(|e| kclvm_api::ExternalPkg {
                            pkg_name: e.pkg_name.clone(),
                            pkg_path: e.pkg_path.clone(),
                        })
                        .collect::<Vec<kclvm_api::ExternalPkg>>()
                })
                .collect(),
        }))
    }
}

/// Parse KCL single file to Module AST JSON string with import dependencies
/// and parse errors.
#[napi]
pub fn parse_file(args: &ParseFileArgs) -> Result<ParseFileResult> {
    let api = kclvm_api::API::default();
    api.parse_file(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ParseFileResult::new)
}

/*
* ListOptions API
*/

#[napi]
pub struct ListOptionsArgs(kclvm_api::ParseProgramArgs);

#[napi]
impl ListOptionsArgs {
    #[napi(constructor)]
    pub fn new(paths: Vec<String>, sources: Option<Vec<String>>) -> Result<Self> {
        Ok(Self(kclvm_api::ParseProgramArgs {
            paths,
            sources: sources.unwrap_or_default(),
            ..Default::default()
        }))
    }
}

/// Provides users with the ability to parse kcl program and get all option information.
#[napi]
pub fn list_options(args: &ListOptionsArgs) -> Result<ListOptionsResult> {
    let api = kclvm_api::API::default();
    api.list_options(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ListOptionsResult::new)
}

/*
* ListVariables API
*/

#[napi]
pub struct ListVariablesArgs(kclvm_api::ListVariablesArgs);

#[napi]
impl ListVariablesArgs {
    #[napi(constructor)]
    pub fn new(
        files: Vec<String>,
        specs: Vec<String>,
        opts: Option<ListVariablesOptions>,
    ) -> Result<Self> {
        Ok(Self(kclvm_api::ListVariablesArgs {
            files,
            specs,
            options: opts.map(|o| kclvm_api::ListVariablesOptions {
                merge_program: o.merge_program,
            }),
        }))
    }
}

/// Provides users with the ability to parse KCL program and get
/// all variables by specs.
#[napi]
pub fn list_variables(args: &ListVariablesArgs) -> Result<ListVariablesResult> {
    let api = kclvm_api::API::default();
    api.list_variables(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ListVariablesResult::new)
}

/*
* OverrideFile API
*/

#[napi]
pub struct OverrideFileArgs(kclvm_api::OverrideFileArgs);

#[napi]
impl OverrideFileArgs {
    #[napi(constructor)]
    pub fn new(file: String, specs: Vec<String>, import_paths: Vec<String>) -> Result<Self> {
        Ok(Self(kclvm_api::OverrideFileArgs {
            file,
            specs,
            import_paths,
        }))
    }
}

/// Override KCL file with arguments.
/// See [https://www.kcl-lang.io/docs/user_docs/guides/automation](https://www.kcl-lang.io/docs/user_docs/guides/automation)
/// for more override spec guide.
#[napi]
pub fn override_file(args: &OverrideFileArgs) -> Result<OverrideFileResult> {
    let api = kclvm_api::API::default();
    api.override_file(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(OverrideFileResult::new)
}

/*
* GetSchemaTypeMapping API
*/

#[napi]
pub struct GetSchemaTypeMappingArgs(kclvm_api::GetSchemaTypeMappingArgs);

#[napi]
impl GetSchemaTypeMappingArgs {
    #[napi(constructor)]
    pub fn new(
        paths: Vec<String>,
        work_dir: Option<String>,
        schema_name: Option<String>,
    ) -> Result<Self> {
        Ok(Self(kclvm_api::GetSchemaTypeMappingArgs {
            exec_args: Some(kclvm_api::ExecProgramArgs {
                work_dir: work_dir.unwrap_or_default(),
                k_filename_list: paths,
                ..Default::default()
            }),
            schema_name: schema_name.unwrap_or_default(),
        }))
    }
}

/// Get schema type mapping.
#[napi]
pub fn get_schema_type_mapping(
    args: &GetSchemaTypeMappingArgs,
) -> Result<GetSchemaTypeMappingResult> {
    let api = kclvm_api::API::default();
    api.get_schema_type_mapping(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(GetSchemaTypeMappingResult::new)
}

/*
* FormatCode API
*/

#[napi]
pub struct FormatCodeArgs(kclvm_api::FormatCodeArgs);

#[napi]
impl FormatCodeArgs {
    #[napi(constructor)]
    pub fn new(source: String) -> Result<Self> {
        Ok(Self(kclvm_api::FormatCodeArgs { source }))
    }
}

/// Format KCL file or directory path contains KCL files and returns the changed file paths.
#[napi]
pub fn format_code(args: &FormatCodeArgs) -> Result<FormatCodeResult> {
    let api = kclvm_api::API::default();
    api.format_code(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(FormatCodeResult::new)
}

/*
* FormatPath API
*/

#[napi]
pub struct FormatPathArgs(kclvm_api::FormatPathArgs);

#[napi]
impl FormatPathArgs {
    #[napi(constructor)]
    pub fn new(path: String) -> Result<Self> {
        Ok(Self(kclvm_api::FormatPathArgs { path }))
    }
}

/// Format KCL file or directory path contains KCL files and returns the changed file paths.
#[napi]
pub fn format_path(args: &FormatPathArgs) -> Result<FormatPathResult> {
    let api = kclvm_api::API::default();
    api.format_path(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(FormatPathResult::new)
}

/*
* LintPath API
*/

#[napi]
pub struct LintPathArgs(kclvm_api::LintPathArgs);

#[napi]
impl LintPathArgs {
    #[napi(constructor)]
    pub fn new(paths: Vec<String>) -> Result<Self> {
        Ok(Self(kclvm_api::LintPathArgs { paths }))
    }
}

/// Lint files and return error messages including errors and warnings.
#[napi]
pub fn lint_path(args: &LintPathArgs) -> Result<LintPathResult> {
    let api = kclvm_api::API::default();
    api.lint_path(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(LintPathResult::new)
}

/*
* ValidateCode API
*/

#[napi]
pub struct ValidateCodeArgs(kclvm_api::ValidateCodeArgs);

#[napi]
impl ValidateCodeArgs {
    #[napi(constructor)]
    pub fn new(
        datafile: Option<String>,
        data: Option<String>,
        file: Option<String>,
        code: Option<String>,
        schema: Option<String>,
        attribute_name: Option<String>,
        format: Option<String>,
    ) -> Result<Self> {
        Ok(Self(kclvm_api::ValidateCodeArgs {
            datafile: datafile.unwrap_or_default(),
            data: data.unwrap_or_default(),
            file: file.unwrap_or_default(),
            code: code.unwrap_or_default(),
            schema: schema.unwrap_or_default(),
            attribute_name: attribute_name.unwrap_or_default(),
            format: format.unwrap_or_default(),
        }))
    }
}

/// Validate code using schema and data strings.
#[napi]
pub fn validate_code(args: &ValidateCodeArgs) -> Result<ValidateCodeResult> {
    let api = kclvm_api::API::default();
    api.validate_code(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ValidateCodeResult::new)
}

/*
* LoadSettingsFiles API
*/

#[napi]
pub struct LoadSettingsFilesArgs(kclvm_api::LoadSettingsFilesArgs);

#[napi]
impl LoadSettingsFilesArgs {
    #[napi(constructor)]
    pub fn new(work_dir: String, files: Vec<String>) -> Result<Self> {
        Ok(Self(kclvm_api::LoadSettingsFilesArgs { work_dir, files }))
    }
}

/// Load the setting file config defined in `kcl.yaml`
#[napi]
pub fn load_settings_files(args: &LoadSettingsFilesArgs) -> Result<LoadSettingsFilesResult> {
    let api = kclvm_api::API::default();
    api.load_settings_files(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(LoadSettingsFilesResult::new)
}

/*
* Rename API
*/

#[napi]
pub struct RenameArgs(kclvm_api::RenameArgs);

#[napi]
impl RenameArgs {
    #[napi(constructor)]
    pub fn new(
        package_root: String,
        symbol_path: String,
        file_paths: Vec<String>,
        new_name: String,
    ) -> Result<Self> {
        Ok(Self(kclvm_api::RenameArgs {
            package_root,
            symbol_path,
            file_paths,
            new_name,
        }))
    }
}

/// Rename all the occurrences of the target symbol in the files. This API will rewrite files if they contain symbols to be renamed.
/// Return the file paths that got changed.
#[napi]
pub fn rename(args: &RenameArgs) -> Result<RenameResult> {
    let api = kclvm_api::API::default();
    api.rename(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(RenameResult::new)
}

/*
* RenameCode API
*/

#[napi]
pub struct RenameCodeArgs(kclvm_api::RenameCodeArgs);

#[napi]
impl RenameCodeArgs {
    #[napi(constructor)]
    pub fn new(
        package_root: String,
        symbol_path: String,
        source_codes: HashMap<String, String>,
        new_name: String,
    ) -> Result<Self> {
        Ok(Self(kclvm_api::RenameCodeArgs {
            package_root,
            symbol_path,
            source_codes,
            new_name,
        }))
    }
}

/// Rename all the occurrences of the target symbol and return the modified code if any code has been changed. This API won't
/// rewrite files but return the changed code.
#[napi]
pub fn rename_code(args: &RenameCodeArgs) -> Result<RenameCodeResult> {
    let api = kclvm_api::API::default();
    api.rename_code(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(RenameCodeResult::new)
}

/*
* Test API
*/

#[napi]
pub struct TestArgs(kclvm_api::TestArgs);

#[napi]
impl TestArgs {
    #[napi(constructor)]
    pub fn new(
        pkg_list: Vec<String>,
        fail_fast: Option<bool>,
        run_regexp: Option<String>,
        work_dir: Option<String>,
        paths: Option<Vec<String>>,
    ) -> Result<Self> {
        Ok(Self(kclvm_api::TestArgs {
            exec_args: Some(kclvm_api::ExecProgramArgs {
                work_dir: work_dir.unwrap_or_default(),
                k_filename_list: paths.unwrap_or_default(),
                ..Default::default()
            }),
            pkg_list,
            fail_fast: fail_fast.unwrap_or_default(),
            run_regexp: run_regexp.unwrap_or_default(),
        }))
    }
}

/// Test KCL packages with test arguments.
#[napi]
pub fn test(args: &TestArgs) -> Result<TestResult> {
    let api = kclvm_api::API::default();
    api.test(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(TestResult::new)
}

/*
* UpdateDependencies API
*/

#[napi]
pub struct UpdateDependenciesArgs(kclvm_api::UpdateDependenciesArgs);

#[napi]
impl UpdateDependenciesArgs {
    #[napi(constructor)]
    pub fn new(manifest_path: String, vendor: bool) -> Result<Self> {
        Ok(Self(kclvm_api::UpdateDependenciesArgs {
            manifest_path,
            vendor,
        }))
    }
}

/// Download and update dependencies defined in the `kcl.mod` file and return the
/// external package name and location list.
#[napi]
pub fn update_dependencies(args: &UpdateDependenciesArgs) -> Result<UpdateDependenciesResult> {
    let api = kclvm_api::API::default();
    api.update_dependencies(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(UpdateDependenciesResult::new)
}

/*
* GetVersion API
*/

/// Return the KCL service version information.
#[napi]
pub fn get_version() -> Result<GetVersionResult> {
    let api = kclvm_api::API::default();
    api.get_version(&kclvm_api::GetVersionArgs {})
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(GetVersionResult::new)
}

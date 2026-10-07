#![deny(clippy::all)]

#[macro_use]
extern crate napi_derive;

mod plugin;
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
pub struct LoadPackageArgs(kcl_api::LoadPackageArgs);

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
        Ok(Self(kcl_api::LoadPackageArgs {
            parse_args: Some(kcl_api::ParseProgramArgs {
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
    let api = kcl_api::API::default();
    api.load_package(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(LoadPackageResult::new)
}

/*
* ExecProgram API
*/

/// Message for execute program request arguments.
#[napi]
pub struct ExecProgramArgs(kcl_api::ExecProgramArgs);

#[napi]
impl ExecProgramArgs {
    #[napi(constructor)]
    pub fn new(
        paths: Vec<String>,
        sources: Option<Vec<String>>,
        work_dir: Option<String>,
        args: Option<Vec<Argument>>,
        overrides: Option<Vec<String>>,
        disable_yaml_result: Option<bool>,
        print_override_ast: Option<bool>,
        strict_range_check: Option<bool>,
        disable_none: Option<bool>,
        verbose: Option<i32>,
        debug: Option<i32>,
        sort_keys: Option<bool>,
        external_pkgs: Option<Vec<ExternalPkg>>,
        include_schema_type_path: Option<bool>,
        compile_only: Option<bool>,
        show_hidden: Option<bool>,
        path_selector: Option<Vec<String>>,
        fast_eval: Option<bool>,
        error_format: Option<String>,
        format: Option<String>,
        sourcemap_output: Option<String>,
        emit_attribute_metadata: Option<bool>,
    ) -> Result<Self> {
        Ok(Self(kcl_api::ExecProgramArgs {
            k_filename_list: paths,
            k_code_list: sources.unwrap_or_default(),
            work_dir: work_dir.unwrap_or_default(),
            args: args
                .into_iter()
                .flat_map(|vec| {
                    vec.into_iter()
                        .map(|a| kcl_api::Argument {
                            name: a.name.clone(),
                            value: a.value.clone(),
                        })
                        .collect::<Vec<kcl_api::Argument>>()
                })
                .collect(),
            external_pkgs: external_pkgs
                .into_iter()
                .flat_map(|vec| {
                    vec.into_iter()
                        .map(|e| kcl_api::ExternalPkg {
                            pkg_name: e.pkg_name.clone(),
                            pkg_path: e.pkg_path.clone(),
                        })
                        .collect::<Vec<kcl_api::ExternalPkg>>()
                })
                .collect(),
            overrides: overrides.unwrap_or_default(),
            disable_yaml_result: disable_yaml_result.unwrap_or_default(),
            print_override_ast: print_override_ast.unwrap_or_default(),
            strict_range_check: strict_range_check.unwrap_or_default(),
            disable_none: disable_none.unwrap_or_default(),
            verbose: verbose.unwrap_or_default(),
            debug: debug.unwrap_or_default(),
            sort_keys: sort_keys.unwrap_or_default(),
            include_schema_type_path: include_schema_type_path.unwrap_or_default(),
            compile_only: compile_only.unwrap_or_default(),
            show_hidden: show_hidden.unwrap_or_default(),
            path_selector: path_selector.unwrap_or_default(),
            fast_eval: fast_eval.unwrap_or_default(),
            error_format: error_format.unwrap_or_default(),
            format: format.unwrap_or_default(),
            sourcemap_output,
            emit_attribute_metadata: emit_attribute_metadata.unwrap_or_default(),
            ..Default::default()
        }))
    }
}

/// Execute KCL file with arguments and return the JSON/YAML result.
#[napi]
pub fn exec_program(args: &ExecProgramArgs) -> Result<ExecProgramResult> {
    let plugin_agent = plugin::plugin_agent_ptr();
    if plugin_agent > 0 {
        return exec_program_with_plugin_agent(&args.0, plugin_agent);
    }
    let api = kcl_api::API::default();
    api.exec_program(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ExecProgramResult::new)
}

fn exec_program_with_plugin_agent(
    args: &kcl_api::ExecProgramArgs,
    plugin_agent: u64,
) -> Result<ExecProgramResult> {
    use ::prost::Message;
    let encoded = args.encode_to_vec();
    let raw = kcl_api::call_with_plugin_agent(b"KclService.ExecProgram", &encoded, plugin_agent)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))?;
    let parsed = kcl_api::ExecProgramResult::decode(raw.as_slice()).map_err(|e| {
        napi::bindgen_prelude::Error::from_reason(format!("decode ExecProgramResult: {e}"))
    })?;
    Ok(ExecProgramResult::new(parsed))
}

/*
* ParseProgram API
*/

#[napi]
pub struct ParseProgramArgs(kcl_api::ParseProgramArgs);

#[napi]
impl ParseProgramArgs {
    #[napi(constructor)]
    pub fn new(
        paths: Vec<String>,
        sources: Option<Vec<String>>,
        external_pkgs: Option<Vec<ExternalPkg>>,
    ) -> Result<Self> {
        Ok(Self(kcl_api::ParseProgramArgs {
            paths,
            sources: sources.unwrap_or_default(),
            external_pkgs: external_pkgs
                .into_iter()
                .flat_map(|vec| {
                    vec.into_iter()
                        .map(|e| kcl_api::ExternalPkg {
                            pkg_name: e.pkg_name.clone(),
                            pkg_path: e.pkg_path.clone(),
                        })
                        .collect::<Vec<kcl_api::ExternalPkg>>()
                })
                .collect(),
        }))
    }
}

/// Parse KCL program with entry files.
#[napi]
pub fn parse_program(args: &ParseProgramArgs) -> Result<ParseProgramResult> {
    let api = kcl_api::API::default();
    api.parse_program(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ParseProgramResult::new)
}

/*
* ParseFile API
*/

#[napi]
pub struct ParseFileArgs(kcl_api::ParseFileArgs);

#[napi]
impl ParseFileArgs {
    #[napi(constructor)]
    pub fn new(
        path: String,
        source: Option<String>,
        external_pkgs: Option<Vec<ExternalPkg>>,
    ) -> Result<Self> {
        Ok(Self(kcl_api::ParseFileArgs {
            path,
            source: source.unwrap_or_default(),
            external_pkgs: external_pkgs
                .into_iter()
                .flat_map(|vec| {
                    vec.into_iter()
                        .map(|e| kcl_api::ExternalPkg {
                            pkg_name: e.pkg_name.clone(),
                            pkg_path: e.pkg_path.clone(),
                        })
                        .collect::<Vec<kcl_api::ExternalPkg>>()
                })
                .collect(),
        }))
    }
}

/// Parse KCL single file to Module AST JSON string with import dependencies
/// and parse errors.
#[napi]
pub fn parse_file(args: &ParseFileArgs) -> Result<ParseFileResult> {
    let api = kcl_api::API::default();
    api.parse_file(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ParseFileResult::new)
}

/*
* ListOptions API
*/

#[napi]
pub struct ListOptionsArgs(kcl_api::ParseProgramArgs);

#[napi]
impl ListOptionsArgs {
    #[napi(constructor)]
    pub fn new(paths: Vec<String>, sources: Option<Vec<String>>) -> Result<Self> {
        Ok(Self(kcl_api::ParseProgramArgs {
            paths,
            sources: sources.unwrap_or_default(),
            ..Default::default()
        }))
    }
}

/// Provides users with the ability to parse kcl program and get all option information.
#[napi]
pub fn list_options(args: &ListOptionsArgs) -> Result<ListOptionsResult> {
    let api = kcl_api::API::default();
    api.list_options(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ListOptionsResult::new)
}

/*
* ListVariables API
*/

#[napi]
pub struct ListVariablesArgs(kcl_api::ListVariablesArgs);

#[napi]
impl ListVariablesArgs {
    #[napi(constructor)]
    pub fn new(
        files: Vec<String>,
        specs: Vec<String>,
        opts: Option<ListVariablesOptions>,
    ) -> Result<Self> {
        Ok(Self(kcl_api::ListVariablesArgs {
            files,
            specs,
            options: opts.map(|o| kcl_api::ListVariablesOptions {
                merge_program: o.merge_program,
            }),
        }))
    }
}

/// Provides users with the ability to parse KCL program and get
/// all variables by specs.
#[napi]
pub fn list_variables(args: &ListVariablesArgs) -> Result<ListVariablesResult> {
    let api = kcl_api::API::default();
    api.list_variables(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ListVariablesResult::new)
}

/*
* OverrideFile API
*/

#[napi]
pub struct OverrideFileArgs(kcl_api::OverrideFileArgs);

#[napi]
impl OverrideFileArgs {
    #[napi(constructor)]
    pub fn new(file: String, specs: Vec<String>, import_paths: Vec<String>) -> Result<Self> {
        Ok(Self(kcl_api::OverrideFileArgs {
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
    let api = kcl_api::API::default();
    api.override_file(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(OverrideFileResult::new)
}

/*
* GetSchemaTypeMapping API
*/

#[napi]
pub struct GetSchemaTypeMappingArgs(kcl_api::GetSchemaTypeMappingArgs);

#[napi]
impl GetSchemaTypeMappingArgs {
    #[napi(constructor)]
    pub fn new(
        paths: Vec<String>,
        work_dir: Option<String>,
        schema_name: Option<String>,
        external_pkgs: Option<Vec<ExternalPkg>>,
        sources: Option<Vec<String>>,
    ) -> Result<Self> {
        Ok(Self(kcl_api::GetSchemaTypeMappingArgs {
            exec_args: Some(kcl_api::ExecProgramArgs {
                work_dir: work_dir.unwrap_or_default(),
                k_filename_list: paths,
                k_code_list: sources.unwrap_or_default(),
                external_pkgs: external_pkgs
                    .unwrap_or_default()
                    .into_iter()
                    .map(|e| kcl_api::ExternalPkg {
                        pkg_name: e.pkg_name,
                        pkg_path: e.pkg_path,
                    })
                    .collect(),
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
    let api = kcl_api::API::default();
    api.get_schema_type_mapping(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(GetSchemaTypeMappingResult::new)
}

/// Get schema type mapping under the input paths, including all external
/// dependency packages. The result is keyed by package name.
/// See https://github.com/kcl-lang/kcl/issues/1546.
#[napi]
pub fn get_schema_type_mapping_under_path(
    args: &GetSchemaTypeMappingArgs,
) -> Result<GetSchemaTypeMappingUnderPathResult> {
    let api = kcl_api::API::default();
    api.get_schema_type_mapping_under_path(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(GetSchemaTypeMappingUnderPathResult::new)
}

/*
* FormatCode API
*/

#[napi]
pub struct FormatCodeArgs(kcl_api::FormatCodeArgs);

#[napi]
impl FormatCodeArgs {
    #[napi(constructor)]
    pub fn new(source: String) -> Result<Self> {
        Ok(Self(kcl_api::FormatCodeArgs { source }))
    }
}

/// Format KCL file or directory path contains KCL files and returns the changed file paths.
#[napi]
pub fn format_code(args: &FormatCodeArgs) -> Result<FormatCodeResult> {
    let api = kcl_api::API::default();
    api.format_code(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(FormatCodeResult::new)
}

/*
* FormatPath API
*/

#[napi]
pub struct FormatPathArgs(kcl_api::FormatPathArgs);

#[napi]
impl FormatPathArgs {
    #[napi(constructor)]
    pub fn new(path: String, dry_run: Option<bool>) -> Result<Self> {
        Ok(Self(kcl_api::FormatPathArgs {
            path,
            dry_run: dry_run.unwrap_or_default(),
        }))
    }
}

/// Format KCL file or directory path contains KCL files and returns the changed file paths.
#[napi]
pub fn format_path(args: &FormatPathArgs) -> Result<FormatPathResult> {
    let api = kcl_api::API::default();
    api.format_path(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(FormatPathResult::new)
}

/*
* LintPath API
*/

#[napi]
pub struct LintPathArgs(kcl_api::LintPathArgs);

#[napi]
impl LintPathArgs {
    #[napi(constructor)]
    pub fn new(paths: Vec<String>) -> Result<Self> {
        Ok(Self(kcl_api::LintPathArgs { paths }))
    }
}

/// Lint files and return error messages including errors and warnings.
#[napi]
pub fn lint_path(args: &LintPathArgs) -> Result<LintPathResult> {
    let api = kcl_api::API::default();
    api.lint_path(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(LintPathResult::new)
}

/*
* ValidateCode API
*/

#[napi]
pub struct ValidateCodeArgs(kcl_api::ValidateCodeArgs);

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
        external_pkgs: Option<Vec<ExternalPkg>>,
    ) -> Result<Self> {
        Ok(Self(kcl_api::ValidateCodeArgs {
            datafile: datafile.unwrap_or_default(),
            data: data.unwrap_or_default(),
            file: file.unwrap_or_default(),
            code: code.unwrap_or_default(),
            schema: schema.unwrap_or_default(),
            attribute_name: attribute_name.unwrap_or_default(),
            format: format.unwrap_or_default(),
            external_pkgs: external_pkgs
                .into_iter()
                .flat_map(|vec| {
                    vec.into_iter()
                        .map(|e| kcl_api::ExternalPkg {
                            pkg_name: e.pkg_name.clone(),
                            pkg_path: e.pkg_path.clone(),
                        })
                        .collect::<Vec<kcl_api::ExternalPkg>>()
                })
                .collect(),
        }))
    }
}

/// Validate code using schema and data strings.
#[napi]
pub fn validate_code(args: &ValidateCodeArgs) -> Result<ValidateCodeResult> {
    let api = kcl_api::API::default();
    api.validate_code(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(ValidateCodeResult::new)
}

/*
* LoadSettingsFiles API
*/

#[napi]
pub struct LoadSettingsFilesArgs(kcl_api::LoadSettingsFilesArgs);

#[napi]
impl LoadSettingsFilesArgs {
    #[napi(constructor)]
    pub fn new(work_dir: String, files: Vec<String>) -> Result<Self> {
        Ok(Self(kcl_api::LoadSettingsFilesArgs { work_dir, files }))
    }
}

/// Load the setting file config defined in `kcl.yaml`
#[napi]
pub fn load_settings_files(args: &LoadSettingsFilesArgs) -> Result<LoadSettingsFilesResult> {
    let api = kcl_api::API::default();
    api.load_settings_files(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(LoadSettingsFilesResult::new)
}

/*
* Rename API
*/

#[napi]
pub struct RenameArgs(kcl_api::RenameArgs);

#[napi]
impl RenameArgs {
    #[napi(constructor)]
    pub fn new(
        package_root: String,
        symbol_path: String,
        file_paths: Vec<String>,
        new_name: String,
    ) -> Result<Self> {
        Ok(Self(kcl_api::RenameArgs {
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
    let api = kcl_api::API::default();
    api.rename(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(RenameResult::new)
}

/*
* RenameCode API
*/

#[napi]
pub struct RenameCodeArgs(kcl_api::RenameCodeArgs);

#[napi]
impl RenameCodeArgs {
    #[napi(constructor)]
    pub fn new(
        package_root: String,
        symbol_path: String,
        source_codes: HashMap<String, String>,
        new_name: String,
    ) -> Result<Self> {
        Ok(Self(kcl_api::RenameCodeArgs {
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
    let api = kcl_api::API::default();
    api.rename_code(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(RenameCodeResult::new)
}

/*
* Test API
*/

#[napi]
pub struct TestArgs(kcl_api::TestArgs);

#[napi]
impl TestArgs {
    #[napi(constructor)]
    pub fn new(
        pkg_list: Vec<String>,
        fail_fast: Option<bool>,
        run_regexp: Option<String>,
        work_dir: Option<String>,
        paths: Option<Vec<String>>,
        coverage: Option<bool>,
    ) -> Result<Self> {
        Ok(Self(kcl_api::TestArgs {
            exec_args: Some(kcl_api::ExecProgramArgs {
                work_dir: work_dir.unwrap_or_default(),
                k_filename_list: paths.unwrap_or_default(),
                ..Default::default()
            }),
            pkg_list,
            fail_fast: fail_fast.unwrap_or_default(),
            run_regexp: run_regexp.unwrap_or_default(),
            coverage: coverage.unwrap_or_default(),
        }))
    }
}

/// Test KCL packages with test arguments.
#[napi]
pub fn test(args: &TestArgs) -> Result<TestResult> {
    let api = kcl_api::API::default();
    api.test(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(TestResult::new)
}

/*
* UpdateDependencies API
*/

#[napi]
pub struct UpdateDependenciesArgs(kcl_api::UpdateDependenciesArgs);

#[napi]
impl UpdateDependenciesArgs {
    #[napi(constructor)]
    pub fn new(manifest_path: String, vendor: bool) -> Result<Self> {
        Ok(Self(kcl_api::UpdateDependenciesArgs {
            manifest_path,
            vendor,
        }))
    }
}

/// Download and update dependencies defined in the `kcl.mod` file and return the
/// external package name and location list.
#[napi]
pub fn update_dependencies(args: &UpdateDependenciesArgs) -> Result<UpdateDependenciesResult> {
    let api = kcl_api::API::default();
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
    let api = kcl_api::API::default();
    api.get_version(&kcl_api::GetVersionArgs {})
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(GetVersionResult::new)
}

/*
* Ping API
*/

/// Message for ping request arguments.
#[napi]
pub struct PingArgs(kcl_api::PingArgs);

#[napi]
impl PingArgs {
    /// Create a new `PingArgs` with the value to send to the KCL service.
    #[napi(constructor)]
    pub fn new(value: String) -> Result<Self> {
        Ok(Self(kcl_api::PingArgs { value }))
    }
}

/// Ping the KCL service and echo back the value.
#[napi]
pub fn ping(args: &PingArgs) -> Result<PingResult> {
    let api = kcl_api::API::default();
    api.ping(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| PingResult { value: r.value })
}

/*
* ListMethod API
*
* `KclServiceImpl` does not expose a typed `list_method` wrapper, so this
* routes through the universal `kcl_api::call` dispatcher against the
* `BuiltinService.ListMethod` RPC and decodes the protobuf result by hand.
*/

/// Return the list of method names supported by the KCL service.
#[napi]
pub fn list_method() -> Result<ListMethodResult> {
    use ::prost::Message;
    let args = kcl_api::ListMethodArgs {}.encode_to_vec();
    let raw = kcl_api::call(b"BuiltinService.ListMethod", &args)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))?;
    let parsed = kcl_api::ListMethodResult::decode(raw.as_slice()).map_err(|e| {
        napi::bindgen_prelude::Error::from_reason(format!("decode ListMethodResult: {e}"))
    })?;
    Ok(ListMethodResult {
        method_name_list: parsed.method_name_list,
    })
}

/*
* FormatTestReport API
*
* Like `list_method` above, this routes through the universal `kcl_api::call`
* dispatcher rather than a typed `KclServiceImpl` wrapper. It was written when
* the pinned `kcl-api` revision predated `KclService.FormatTestReport`. The pin
* is now 0.13.1, which has both the typed wrapper and the generated messages;
* the hand-rolled encoding is kept because it is already covered by tests, and
* it collapses to the typed call wherever that is tidier. `FormatTestReportArgs`
* is a single length-delimited field 1 carrying a `TestResult`, and
* `FormatTestReportResult` a single length-delimited field 1 carrying a `string`.
*/

/// Format a test result into a human-readable report.
#[napi]
pub fn format_test_report(args: FormatTestReportArgs) -> Result<FormatTestReportResult> {
    use ::prost::Message;
    use ::prost::encoding::{
        WireType, decode_key, decode_varint, encode_key, encode_length_delimiter,
    };

    let mut inner = Vec::new();
    args.result.to_wire().encode(&mut inner).map_err(|e| {
        napi::bindgen_prelude::Error::from_reason(format!("encode TestResult: {e}"))
    })?;
    let mut request = Vec::new();
    encode_key(1, WireType::LengthDelimited, &mut request);
    encode_length_delimiter(inner.len(), &mut request).map_err(|e| {
        napi::bindgen_prelude::Error::from_reason(format!("encode FormatTestReportArgs: {e}"))
    })?;
    request.extend_from_slice(&inner);

    let raw = kcl_api::call(b"KclService.FormatTestReport", &request)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))?;
    // The dispatcher reports a service-level failure as an `ERROR:`-prefixed
    // payload rather than through the `Result`, so translate it here instead of
    // handing the bytes to a decoder that would read them as a report.
    if let Some(message) = raw.strip_prefix(b"ERROR:") {
        return Err(napi::bindgen_prelude::Error::from_reason(format!(
            "{}",
            String::from_utf8_lossy(message)
        )));
    }

    // The key and the length are both varints, and the length is the one that
    // bites: a 139-byte report is `8b 01`, two bytes, so reading a single byte
    // for it truncates the length to 11 and then walks off into the middle of
    // the text. prost's own readers get both right.
    let mut buf = raw.as_slice();
    let mut report = String::new();
    while !buf.is_empty() {
        let (field, wire) = decode_key(&mut buf)
            .map_err(|e| napi::bindgen_prelude::Error::from_reason(format!("decode key: {e}")))?;
        if field != 1 || wire != WireType::LengthDelimited {
            // The response has exactly one field; anything else means we are
            // not reading what we think we are, and reporting a partial read
            // as a whole one is worse than saying so.
            return Err(napi::bindgen_prelude::Error::from_reason(format!(
                "unexpected field {field}/{wire:?} in FormatTestReportResult"
            )));
        }
        let len = decode_varint(&mut buf)
            .map_err(|e| napi::bindgen_prelude::Error::from_reason(format!("decode length: {e}")))?
            as usize;
        if buf.len() < len {
            return Err(napi::bindgen_prelude::Error::from_reason(format!(
                "FormatTestReportResult report is truncated: {len} bytes claimed, {} left",
                buf.len()
            )));
        }
        report = String::from_utf8_lossy(&buf[..len]).into_owned();
        buf = &buf[len..];
    }
    Ok(FormatTestReportResult { report })
}

/*
* GenerateToml / GenerateKcl / GenerateOpenAPI / GenerateProto / GenerateDoc APIs
*
* Like `format_test_report` above, these route through the universal
* `kcl_api::call` dispatcher. They were written when the pinned `kcl-api`
* revision predated these RPCs; the pin is now 0.13.1, which has the typed
* `KclServiceImpl` wrappers and the generated messages, and the hand-rolled
* envelopes are kept for the same reason. A leading length-delimited field
* carries the nested message for the args that embed one, plain string/bool
* fields otherwise, and each response is a single length-delimited string at
* field 1, decoded with the same strict key/length/truncation checks as
* `format_test_report`.
*/

use ::prost::encoding::{
    WireType, decode_key, decode_varint, encode_key, encode_length_delimiter,
};

fn check_dispatcher_error(raw: &[u8]) -> Result<()> {
    // The dispatcher reports a service-level failure as an `ERROR:`-prefixed
    // payload rather than through the `Result`, so translate it here instead
    // of handing the bytes to a decoder that would read them as a result.
    if let Some(message) = raw.strip_prefix(b"ERROR:") {
        return Err(napi::bindgen_prelude::Error::from_reason(format!(
            "{}",
            String::from_utf8_lossy(message)
        )));
    }
    Ok(())
}

/// Decode a response message whose only field is a string at field 1, with
/// the same strictness as the hand-decoded `FormatTestReportResult` above.
fn decode_single_string_field(raw: &[u8], result_name: &str) -> Result<String> {
    let mut buf = raw;
    let mut value = String::new();
    while !buf.is_empty() {
        let (field, wire) = decode_key(&mut buf)
            .map_err(|e| napi::bindgen_prelude::Error::from_reason(format!("decode key: {e}")))?;
        if field != 1 || wire != WireType::LengthDelimited {
            // The response has exactly one field; anything else means we are
            // not reading what we think we are, and reporting a partial read
            // as a whole one is worse than saying so.
            return Err(napi::bindgen_prelude::Error::from_reason(format!(
                "unexpected field {field}/{wire:?} in {result_name}"
            )));
        }
        let len = decode_varint(&mut buf)
            .map_err(|e| napi::bindgen_prelude::Error::from_reason(format!("decode length: {e}")))?
            as usize;
        if buf.len() < len {
            return Err(napi::bindgen_prelude::Error::from_reason(format!(
                "{result_name} value is truncated: {len} bytes claimed, {} left",
                buf.len()
            )));
        }
        value = String::from_utf8_lossy(&buf[..len]).into_owned();
        buf = &buf[len..];
    }
    Ok(value)
}

fn encode_nested_message_field(buf: &mut Vec<u8>, field: u32, payload: &[u8]) {
    encode_key(field, WireType::LengthDelimited, buf);
    encode_length_delimiter(payload.len(), buf).expect("length delimiter");
    buf.extend_from_slice(payload);
}

fn encode_optional_string_field(buf: &mut Vec<u8>, field: u32, value: &str) {
    if !value.is_empty() {
        encode_nested_message_field(buf, field, value.as_bytes());
    }
}

/// Message for generate TOML request arguments.
#[napi]
pub struct GenerateTomlArgs {
    exec_args: Option<kcl_api::ExecProgramArgs>,
    sort_keys: bool,
}

#[napi]
impl GenerateTomlArgs {
    #[napi(constructor)]
    pub fn new(exec_args: Option<&ExecProgramArgs>, sort_keys: Option<bool>) -> Result<Self> {
        Ok(Self {
            exec_args: exec_args.map(|e| e.0.clone()),
            sort_keys: sort_keys.unwrap_or_default(),
        })
    }
}

/// Message for generate TOML response.
#[napi(object)]
pub struct GenerateTomlResult {
    /// The evaluated result serialized as TOML.
    pub toml: String,
}

/// Serialize the evaluated result of a KCL program to TOML.
#[napi]
pub fn generate_toml(args: &GenerateTomlArgs) -> Result<GenerateTomlResult> {
    use ::prost::Message;
    let mut exec_bytes = Vec::new();
    if let Some(exec_args) = &args.exec_args {
        exec_args.encode(&mut exec_bytes).map_err(|e| {
            napi::bindgen_prelude::Error::from_reason(format!("encode ExecProgramArgs: {e}"))
        })?;
    }
    let mut request = Vec::new();
    encode_nested_message_field(&mut request, 1, &exec_bytes);
    if args.sort_keys {
        encode_key(2, WireType::Varint, &mut request);
        ::prost::encoding::encode_varint(1, &mut request);
    }
    let raw = kcl_api::call(b"KclService.GenerateToml", &request)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))?;
    check_dispatcher_error(&raw)?;
    Ok(GenerateTomlResult {
        toml: decode_single_string_field(&raw, "GenerateTomlResult")?,
    })
}

/// Message for generate KCL request arguments.
#[napi]
pub struct GenerateKclArgs {
    source: String,
    filename: String,
    format: String,
}

#[napi]
impl GenerateKclArgs {
    #[napi(constructor)]
    pub fn new(source: String, filename: Option<String>, format: Option<String>) -> Result<Self> {
        Ok(Self {
            source,
            filename: filename.unwrap_or_default(),
            format: format.unwrap_or_default(),
        })
    }
}

/// Message for generate KCL response.
#[napi(object)]
pub struct GenerateKclResult {
    /// The generated KCL source.
    pub kcl: String,
}

/// Generate KCL source from data content (JSON, YAML or TOML).
#[napi]
pub fn generate_kcl(args: &GenerateKclArgs) -> Result<GenerateKclResult> {
    let mut request = Vec::new();
    encode_nested_message_field(&mut request, 1, args.source.as_bytes());
    encode_optional_string_field(&mut request, 2, &args.filename);
    encode_optional_string_field(&mut request, 3, &args.format);
    let raw = kcl_api::call(b"KclService.GenerateKcl", &request)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))?;
    check_dispatcher_error(&raw)?;
    Ok(GenerateKclResult {
        kcl: decode_single_string_field(&raw, "GenerateKclResult")?,
    })
}

fn parse_program_args_to_wire(parse_args: &Option<kcl_api::ParseProgramArgs>) -> Vec<u8> {
    use ::prost::Message;
    parse_args
        .as_ref()
        .map(|p| p.encode_to_vec())
        .unwrap_or_default()
}

/// Message for generate OpenAPI request arguments.
#[napi(js_name = "GenerateOpenAPIArgs")]
pub struct GenerateOpenAPIArgs {
    parse_args: Option<kcl_api::ParseProgramArgs>,
    version: String,
}

#[napi]
impl GenerateOpenAPIArgs {
    #[napi(constructor)]
    pub fn new(parse_args: Option<&ParseProgramArgs>, version: Option<String>) -> Result<Self> {
        Ok(Self {
            parse_args: parse_args.map(|p| p.0.clone()),
            version: version.unwrap_or_default(),
        })
    }
}

/// Message for generate OpenAPI response.
#[napi(object)]
pub struct GenerateOpenAPIResult {
    /// The generated OpenAPI spec.
    pub spec: String,
}

/// Generate an OpenAPI spec from the schemas of a KCL package.
#[napi(js_name = "generateOpenAPI")]
pub fn generate_openapi(args: &GenerateOpenAPIArgs) -> Result<GenerateOpenAPIResult> {
    let mut request = Vec::new();
    encode_nested_message_field(&mut request, 1, &parse_program_args_to_wire(&args.parse_args));
    encode_optional_string_field(&mut request, 2, &args.version);
    let raw = kcl_api::call(b"KclService.GenerateOpenAPI", &request)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))?;
    check_dispatcher_error(&raw)?;
    Ok(GenerateOpenAPIResult {
        spec: decode_single_string_field(&raw, "GenerateOpenAPIResult")?,
    })
}

/// Message for generate proto request arguments.
#[napi]
pub struct GenerateProtoArgs {
    parse_args: Option<kcl_api::ParseProgramArgs>,
    package: String,
}

#[napi]
impl GenerateProtoArgs {
    #[napi(constructor)]
    pub fn new(parse_args: Option<&ParseProgramArgs>, package_name: Option<String>) -> Result<Self> {
        Ok(Self {
            parse_args: parse_args.map(|p| p.0.clone()),
            package: package_name.unwrap_or_default(),
        })
    }
}

/// Message for generate proto response.
#[napi(object)]
pub struct GenerateProtoResult {
    /// The generated proto3 definitions.
    pub proto: String,
}

/// Generate proto3 definitions from the schemas of a KCL package.
#[napi]
pub fn generate_proto(args: &GenerateProtoArgs) -> Result<GenerateProtoResult> {
    let mut request = Vec::new();
    encode_nested_message_field(&mut request, 1, &parse_program_args_to_wire(&args.parse_args));
    encode_optional_string_field(&mut request, 2, &args.package);
    let raw = kcl_api::call(b"KclService.GenerateProto", &request)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))?;
    check_dispatcher_error(&raw)?;
    Ok(GenerateProtoResult {
        proto: decode_single_string_field(&raw, "GenerateProtoResult")?,
    })
}

/// Message for generate doc request arguments.
#[napi]
pub struct GenerateDocArgs {
    parse_args: Option<kcl_api::ParseProgramArgs>,
    format: String,
}

#[napi]
impl GenerateDocArgs {
    #[napi(constructor)]
    pub fn new(parse_args: Option<&ParseProgramArgs>, format: Option<String>) -> Result<Self> {
        Ok(Self {
            parse_args: parse_args.map(|p| p.0.clone()),
            format: format.unwrap_or_default(),
        })
    }
}

/// Message for generate doc response.
#[napi(object)]
pub struct GenerateDocResult {
    /// The generated documentation.
    pub content: String,
}

/// Generate documentation from the schemas of a KCL package.
#[napi]
pub fn generate_doc(args: &GenerateDocArgs) -> Result<GenerateDocResult> {
    let mut request = Vec::new();
    encode_nested_message_field(&mut request, 1, &parse_program_args_to_wire(&args.parse_args));
    encode_optional_string_field(&mut request, 2, &args.format);
    let raw = kcl_api::call(b"KclService.GenerateDoc", &request)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))?;
    check_dispatcher_error(&raw)?;
    Ok(GenerateDocResult {
        content: decode_single_string_field(&raw, "GenerateDocResult")?,
    })
}

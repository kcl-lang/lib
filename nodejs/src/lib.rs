#![deny(clippy::all)]

#[macro_use]
extern crate napi_derive;

mod spec;

use crate::spec::*;
use napi::bindgen_prelude::*;

/*
* LoadPackage API
*/

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

#[napi]
pub fn load_package(args: &LoadPackageArgs) -> Result<LoadPackageResult> {
    let api = kclvm_api::API::default();
    api.load_package(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| LoadPackageResult::new(r))
}

/*
* ExecProgram API
*/

#[napi]
pub struct ExecProgramArgs(kclvm_api::ExecProgramArgs);

#[napi]
impl ExecProgramArgs {
    #[napi(constructor)]
    pub fn new(paths: Vec<String>, work_dir: Option<String>) -> Result<Self> {
        Ok(Self(kclvm_api::ExecProgramArgs {
            k_filename_list: paths,
            work_dir: work_dir.unwrap_or_default(),
            ..Default::default()
        }))
    }
}

#[napi]
pub fn exec_program(args: &ExecProgramArgs) -> Result<ExecProgramResult> {
    let api = kclvm_api::API::default();
    api.exec_program(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| ExecProgramResult::new(r))
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

#[napi]
pub fn list_variables(args: &ListVariablesArgs) -> Result<ListVariablesResult> {
    let api = kclvm_api::API::default();
    api.list_variables(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| ListVariablesResult::new(r))
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

#[napi]
pub fn override_file(args: &OverrideFileArgs) -> Result<OverrideFileResult> {
    let api = kclvm_api::API::default();
    api.override_file(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| OverrideFileResult::new(r))
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

#[napi]
pub fn update_dependencies(args: &UpdateDependenciesArgs) -> Result<UpdateDependenciesResult> {
    let api = kclvm_api::API::default();
    api.update_dependencies(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| UpdateDependenciesResult::new(r))
}

/*
* GetVersion API
*/

#[napi]
pub fn get_version() -> Result<GetVersionResult> {
    let api = kclvm_api::API::default();
    api.get_version(&kclvm_api::GetVersionArgs {})
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| GetVersionResult::new(r))
}

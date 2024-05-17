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
pub struct LoadPackageArgs(kcl_lang::LoadPackageArgs);

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
        Ok(Self(kcl_lang::LoadPackageArgs {
            parse_args: Some(kcl_lang::ParseProgramArgs {
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
    let api = kcl_lang::API::default();
    api.load_package(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| LoadPackageResult::new(r))
}

/*
* ExecProgram API
*/

#[napi]
pub struct ExecProgramArgs(kcl_lang::ExecProgramArgs);

#[napi]
impl ExecProgramArgs {
    #[napi(constructor)]
    pub fn new(paths: Vec<String>, work_dir: Option<String>) -> Result<Self> {
        Ok(Self(kcl_lang::ExecProgramArgs {
            k_filename_list: paths,
            work_dir: work_dir.unwrap_or_default(),
            ..Default::default()
        }))
    }
}

#[napi]
pub fn exec_program(args: &ExecProgramArgs) -> Result<ExecProgramResult> {
    let api = kcl_lang::API::default();
    api.exec_program(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| ExecProgramResult::new(r))
}

/*
* ListVariables API
*/

#[napi]
pub struct ListVariablesArgs(kcl_lang::ListVariablesArgs);

#[napi]
impl ListVariablesArgs {
    #[napi(constructor)]
    pub fn new(file: String, specs: Vec<String>) -> Result<Self> {
        Ok(Self(kcl_lang::ListVariablesArgs { file, specs }))
    }
}

#[napi]
pub fn list_variables(args: &ListVariablesArgs) -> Result<ListVariablesResult> {
    let api = kcl_lang::API::default();
    api.list_variables(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| ListVariablesResult::new(r))
}

/*
* OverrideFile API
*/

#[napi]
pub struct OverrideFileArgs(kcl_lang::OverrideFileArgs);

#[napi]
impl OverrideFileArgs {
    #[napi(constructor)]
    pub fn new(file: String, specs: Vec<String>, import_paths: Vec<String>) -> Result<Self> {
        Ok(Self(kcl_lang::OverrideFileArgs {
            file,
            specs,
            import_paths,
        }))
    }
}

#[napi]
pub fn override_file(args: &OverrideFileArgs) -> Result<OverrideFileResult> {
    let api = kcl_lang::API::default();
    api.override_file(&args.0)
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| OverrideFileResult::new(r))
}

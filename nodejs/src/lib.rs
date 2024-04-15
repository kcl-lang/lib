#![deny(clippy::all)]

#[macro_use]
extern crate napi_derive;

use napi::bindgen_prelude::*;
use std::collections::HashMap;

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

#[napi(object)]
pub struct ExecProgramResult {
    pub json_result: String,
    pub yaml_result: String,
    pub log_message: String,
    pub err_message: String,
}

impl ExecProgramResult {
    pub fn new(r: kcl_lang::ExecProgramResult) -> Self {
        Self {
            json_result: r.json_result,
            yaml_result: r.yaml_result,
            log_message: r.log_message,
            err_message: r.err_message,
        }
    }
}

#[napi]
pub fn exec_program(args: &ExecProgramArgs) -> Result<ExecProgramResult> {
    let api = kcl_lang::API::default();
    api.exec_program(&args.0)
        .map_err(|e| Error::from_reason(e.to_string()))
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

#[napi(object)]
pub struct ListVariablesResult {
    pub variables: HashMap<String, Variable>,
    pub unsupported_codes: Vec<String>,
}

#[napi(object)]
pub struct Variable {
    pub value: String,
}

impl ListVariablesResult {
    pub fn new(r: kcl_lang::ListVariablesResult) -> Self {
        Self {
            variables: r
                .variables
                .iter()
                .map(|(k, v)| {
                    (
                        k.to_string(),
                        Variable {
                            value: v.value.to_string(),
                        },
                    )
                })
                .collect(),
            unsupported_codes: r.unsupported_codes,
        }
    }
}

#[napi]
pub fn list_variables(args: &ListVariablesArgs) -> Result<ListVariablesResult> {
    let api = kcl_lang::API::default();
    api.list_variables(&args.0)
        .map_err(|e| Error::from_reason(e.to_string()))
        .map(|r| ListVariablesResult::new(r))
}

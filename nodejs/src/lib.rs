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

impl crate::spec::Error {
    pub fn new(e: &kcl_lang::Error) -> Self {
        Self {
            level: e.level.clone(),
            code: e.code.clone(),
            messages: e
                .messages
                .iter()
                .map(|m| Message {
                    msg: m.msg.clone(),
                    pos: m.pos.as_ref().map(|p| Position {
                        line: p.line,
                        column: p.column,
                        filename: p.filename.clone(),
                    }),
                })
                .collect(),
        }
    }
}

impl ScopeIndex {
    pub fn new(v: &kcl_lang::ScopeIndex) -> Self {
        ScopeIndex {
            i: v.i as u32,
            g: v.g as u32,
            kind: v.kind.clone(),
        }
    }
}

impl SymbolIndex {
    pub fn new(v: &kcl_lang::SymbolIndex) -> Self {
        SymbolIndex {
            i: v.i as u32,
            g: v.g as u32,
            kind: v.kind.clone(),
        }
    }
}

impl crate::spec::Symbol {
    pub fn new(v: &kcl_lang::Symbol) -> Self {
        crate::spec::Symbol {
            ty: v.ty.as_ref().map(|ty| ty.r#type.clone()),
            name: v.name.clone(),
            owner: v.owner.as_ref().map(|v| SymbolIndex::new(v)),
            def: v.def.as_ref().map(|v| SymbolIndex::new(v)),
            attrs: v.attrs.iter().map(|v| SymbolIndex::new(v)).collect(),
            is_global: v.is_global,
        }
    }
}

impl LoadPackageResult {
    pub fn new(r: kcl_lang::LoadPackageResult) -> Self {
        Self {
            program: r.program,
            paths: r.paths,
            parse_errors: r
                .parse_errors
                .iter()
                .map(|e| crate::spec::Error::new(e))
                .collect(),
            type_errors: r
                .type_errors
                .iter()
                .map(|e| crate::spec::Error::new(e))
                .collect(),
            scopes: r
                .scopes
                .iter()
                .map(|(k, v)| {
                    (
                        k.to_string(),
                        Scope {
                            kind: v.kind.clone(),
                            parent: v.parent.as_ref().map(|v| ScopeIndex::new(&v)),
                            owner: v.owner.as_ref().map(|v| SymbolIndex::new(&v)),
                            children: v.children.iter().map(|v| ScopeIndex::new(v)).collect(),
                            defs: v.defs.iter().map(|v| SymbolIndex::new(v)).collect(),
                        },
                    )
                })
                .collect(),
            symbols: r
                .symbols
                .iter()
                .map(|(k, v)| (k.clone(), crate::spec::Symbol::new(v)))
                .collect(),
            node_symbol_map: r
                .node_symbol_map
                .iter()
                .map(|(k, v)| (k.clone(), SymbolIndex::new(v)))
                .collect(),
            symbol_node_map: r.symbol_node_map,
            fully_qualified_name_map: r
                .fully_qualified_name_map
                .iter()
                .map(|(k, v)| (k.to_string(), SymbolIndex::new(v)))
                .collect(),
            pkg_scope_map: r
                .pkg_scope_map
                .iter()
                .map(|(k, v)| (k.to_string(), ScopeIndex::new(v)))
                .collect(),
        }
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
        .map_err(|e| napi::bindgen_prelude::Error::from_reason(e.to_string()))
        .map(|r| ListVariablesResult::new(r))
}

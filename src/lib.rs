//! # KCL Rust SDK
//!
//! ## How to Use
//!
//! ```no_check,no_run
//! cargo add --git https://github.com/kcl-lang/lib --branch main
//! ```
//!
//! Write the Code
//!
//! ```rust
//! use kcl_lang::*;
//! use std::path::Path;
//! use anyhow::Result;
//!
//! fn main() -> Result<()> {
//!     let api = API::default();
//!     let args = &ExecProgramArgs {
//!         work_dir: Path::new(".").join("testdata").canonicalize().unwrap().display().to_string(),
//!         k_filename_list: vec!["test.k".to_string()],
//!         ..Default::default()
//!     };
//!     let exec_result = api.exec_program(args)?;
//!     assert_eq!(exec_result.yaml_result, "alice:\n  age: 18");
//!     Ok(())
//! }
//! ```

pub use kclvm_api::gpyrpc::*;
use kclvm_api::service::service_impl::KclvmServiceImpl;

use anyhow::Result;

pub type API = KclvmServiceImpl;

#[cfg(test)]
mod tests;

/// Call KCL API with the API name and argument protobuf bytes.
#[inline]
pub fn call<'a>(name: &'a [u8], args: &'a [u8]) -> Result<Vec<u8>> {
    call_with_plugin_agent(name, args, 0)
}

/// Call KCL API with the API name, argument protobuf bytes and the plugin agent pointer address.
pub fn call_with_plugin_agent<'a>(
    name: &'a [u8],
    args: &'a [u8],
    plugin_agent: u64,
) -> Result<Vec<u8>> {
    kclvm_api::call_with_plugin_agent(name, args, plugin_agent)
}

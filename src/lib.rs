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
//!     let api = API::new()?;
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
pub mod api;
pub mod bootstrap;

pub use api::*;

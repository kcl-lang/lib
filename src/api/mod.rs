mod service;
mod spec;
use crate::bootstrap::{install_kclvm, lib_full_name};
use anyhow::Result;
use prost::Message;
use serde::de::DeserializeOwned;
pub use service::Service;
use service::ServiceHandler;
pub use spec::*;
use std::{
    ffi::{c_char, CStr, CString},
    sync::Mutex,
};
use tempfile::TempDir;

#[derive(Debug)]
pub struct API {
    caller: Caller,
}

#[derive(Debug)]
struct Caller {
    _dir: TempDir,
    lib: libloading::Library,
    mutex: Mutex<i32>,
    handler: *mut ServiceHandler,
}

unsafe impl Send for Caller {}
unsafe impl Sync for Caller {}

impl Caller {
    fn new() -> Result<Self> {
        unsafe {
            let root = tempfile::tempdir()?;
            install_kclvm(&root)?;
            let lib = libloading::Library::new(&root.path().join("bin").join(lib_full_name()))?;
            let service_new: libloading::Symbol<
                unsafe extern "C" fn(plugin_agent: u64) -> *mut ServiceHandler,
            > = lib.get(b"kclvm_service_new")?;
            let handler = service_new(0);
            Ok(Self {
                _dir: root,
                mutex: Mutex::new(0i32),
                lib,
                handler,
            })
        }
    }

    fn call_native(&self, name: &[u8], args: &[u8]) -> Result<&[u8]> {
        let _lock = self.mutex.lock().unwrap();
        let result_ptr = unsafe {
            let args = CString::new(args)?;
            let call = CString::new(name)?;
            let service_call: libloading::Symbol<
                unsafe extern "C" fn(
                    serv: *mut ServiceHandler,
                    call: *const c_char,
                    args: *const c_char,
                ) -> *const c_char,
            > = self.lib.get(b"kclvm_service_call")?;

            service_call(self.handler, call.as_ptr(), args.as_ptr()) as *mut i8
        };
        let result = unsafe { CStr::from_ptr(result_ptr) };
        Ok(result.to_bytes())
    }

    fn call<A, R>(&self, name: &str, args: &A) -> Result<R>
    where
        A: Message + DeserializeOwned,
        R: Message + Default + PartialEq + DeserializeOwned + serde::Serialize,
    {
        let _lock = self.mutex.lock().unwrap();
        let result_ptr = unsafe {
            let args = CString::from_vec_unchecked(args.encode_to_vec());
            let call = CString::new(name)?;
            let service_call: libloading::Symbol<
                unsafe extern "C" fn(
                    serv: *mut ServiceHandler,
                    call: *const c_char,
                    args: *const c_char,
                ) -> *const c_char,
            > = self.lib.get(b"kclvm_service_call")?;

            service_call(self.handler, call.as_ptr(), args.as_ptr()) as *mut i8
        };
        let result = unsafe { CStr::from_ptr(result_ptr) };
        match R::decode(result.to_bytes()) {
            Ok(result) => Ok(result),
            Err(_) => Err(anyhow::anyhow!(result.to_str()?.to_owned())),
        }
    }
}

impl Drop for Caller {
    fn drop(&mut self) {
        unsafe {
            let delete: libloading::Symbol<unsafe extern "C" fn(*mut ServiceHandler)> =
                self.lib.get(b"kclvm_service_delete").unwrap();
            delete(self.handler);
        }
    }
}

impl API {
    pub fn new() -> Result<Self> {
        let caller = Caller::new()?;
        Ok(Self { caller })
    }

    pub fn call_native(&self, name: &[u8], args: &[u8]) -> Result<&[u8]> {
        self.caller.call_native(name, args)
    }
}

impl Service for API {
    fn exec_program(&self, args: &ExecProgramArgs) -> anyhow::Result<ExecProgramResult> {
        self.caller.call("KclvmService.ExecProgram", args)
    }

    fn override_file(&self, args: &OverrideFileArgs) -> anyhow::Result<OverrideFileResult> {
        self.caller.call("KclvmService.OverrideFile", args)
    }

    fn get_full_schema_type(
        &self,
        args: &GetFullSchemaTypeArgs,
    ) -> anyhow::Result<GetSchemaTypeResult> {
        self.caller.call("KclvmService.GetFullSchemaType", args)
    }

    fn format_code(&self, args: &FormatCodeArgs) -> anyhow::Result<FormatCodeResult> {
        self.caller.call("KclvmService.FormatCode", args)
    }

    fn format_path(&self, args: &FormatPathArgs) -> anyhow::Result<FormatPathResult> {
        self.caller.call("KclvmService.FormatPath", args)
    }

    fn lint_path(&self, args: &LintPathArgs) -> anyhow::Result<LintPathResult> {
        self.caller.call("KclvmService.LintPath", args)
    }

    fn validate_code(&self, args: &ValidateCodeArgs) -> anyhow::Result<ValidateCodeResult> {
        self.caller.call("KclvmService.ValidateCode", args)
    }

    fn load_settings_files(
        &self,
        args: &LoadSettingsFilesArgs,
    ) -> anyhow::Result<LoadSettingsFilesResult> {
        self.caller.call("KclvmService.LoadSettingsFiles", args)
    }

    fn rename(&self, args: &RenameArgs) -> anyhow::Result<RenameResult> {
        self.caller.call("KclvmService.Rename", args)
    }

    fn rename_code(&self, args: &RenameCodeArgs) -> anyhow::Result<RenameCodeResult> {
        self.caller.call("KclvmService.RenameCode", args)
    }

    fn test(&self, args: &TestArgs) -> anyhow::Result<TestResult> {
        self.caller.call("KclvmService.Test", args)
    }
}

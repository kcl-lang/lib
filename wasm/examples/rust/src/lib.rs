#[cfg(test)]
mod tests;

use anyhow::Result;
use std::path::Path;
use wasmtime::*;
use wasmtime_wasi::p1::WasiP1Ctx;
use wasmtime_wasi::{WasiCtx, p1};

#[derive(Debug)]
pub struct RunOptions {
    pub filename: String,
    pub source: String,
}

#[derive(Debug)]
pub struct FmtOptions {
    pub source: String,
}

pub struct KCLModule {
    pub instance: Instance,
    store: Store<WasiP1Ctx>,
    memory: Memory,
    malloc: TypedFunc<i32, i32>,
    free: TypedFunc<(i32, i32), ()>,
    run: TypedFunc<(i32, i32), i32>,
    fmt: TypedFunc<i32, i32>,
    runtime_err: TypedFunc<(i32, i32), i32>,
}

impl KCLModule {
    /// Construct a KCL wasm module from the path.
    pub fn from_path<P: AsRef<Path>>(path: P) -> Result<KCLModule> {
        let engine = Engine::default();
        let wasi = WasiCtx::builder().inherit_stdio().inherit_args().build_p1();
        let mut store = Store::new(&engine, wasi);
        let binary_data = std::fs::read(path)?;
        let module = Module::new(&engine, &binary_data)?;
        let mut linker = Linker::new(&engine);
        linker.func_wrap(
            "env",
            "kclvm_plugin_invoke_json_wasm",
            |_name: i32, _args: i32, _kwargs: i32| 0,
        )?;
        p1::add_to_linker_sync(&mut linker, |s| s)?;
        let instance = linker.instantiate(&mut store, &module)?;
        let memory = instance
            .get_memory(&mut store, "memory")
            .ok_or(anyhow::anyhow!("failed to find `memory` export"))?;
        let malloc = instance.get_typed_func::<i32, i32>(&mut store, "kcl_malloc")?;
        let free = instance.get_typed_func::<(i32, i32), ()>(&mut store, "kcl_free")?;
        let run = instance.get_typed_func::<(i32, i32), i32>(&mut store, "kcl_run")?;
        let fmt = instance.get_typed_func::<i32, i32>(&mut store, "kcl_fmt")?;
        let runtime_err =
            instance.get_typed_func::<(i32, i32), i32>(&mut store, "kcl_runtime_err")?;
        Ok(KCLModule {
            instance,
            store,
            memory,
            malloc,
            free,
            run,
            fmt,
            runtime_err,
        })
    }

    /// Run with the wasm module and options.
    pub fn run(&mut self, opts: &RunOptions) -> Result<String> {
        let (filename_ptr, filename_len) =
            copy_string_to_wasm_memory(&mut self.store, &self.malloc, self.memory, &opts.filename)?;
        let (source_ptr, source_len) =
            copy_string_to_wasm_memory(&mut self.store, &self.malloc, self.memory, &opts.source)?;
        let runtime_err_len = 1024;
        let (runtime_err_ptr, _) =
            malloc_bytes_from_wasm_memory(&mut self.store, &self.malloc, runtime_err_len)?;
        let result_str = match self.run.call(&mut self.store, (filename_ptr, source_ptr)) {
            Ok(result_ptr) => {
                let (result_str, result_len) =
                    copy_cstr_from_wasm_memory(&mut self.store, self.memory, result_ptr as usize)?;
                free_memory(&mut self.store, &self.free, result_ptr, result_len)?;
                result_str
            }
            Err(err) => {
                self.runtime_err
                    .call(&mut self.store, (runtime_err_ptr, runtime_err_len))?;
                let (runtime_err_str, runtime_err_len) = copy_cstr_from_wasm_memory(
                    &mut self.store,
                    self.memory,
                    runtime_err_ptr as usize,
                )?;
                free_memory(
                    &mut self.store,
                    &self.free,
                    runtime_err_ptr,
                    runtime_err_len,
                )?;
                if runtime_err_str.is_empty() {
                    return Err(err);
                } else {
                    runtime_err_str
                }
            }
        };
        free_memory(&mut self.store, &self.free, filename_ptr, filename_len)?;
        free_memory(&mut self.store, &self.free, source_ptr, source_len)?;
        Ok(result_str)
    }

    /// Run with the wasm module and options.
    pub fn fmt(&mut self, opts: &FmtOptions) -> Result<String> {
        let (source_ptr, source_len) =
            copy_string_to_wasm_memory(&mut self.store, &self.malloc, self.memory, &opts.source)?;
        let result_ptr = self.fmt.call(&mut self.store, source_ptr)?;
        let (result_str, result_len) =
            copy_cstr_from_wasm_memory(&mut self.store, self.memory, result_ptr as usize)?;
        free_memory(&mut self.store, &self.free, source_ptr, source_len)?;
        free_memory(&mut self.store, &self.free, result_ptr, result_len)?;

        Ok(result_str)
    }
}

fn copy_string_to_wasm_memory<T>(
    store: &mut Store<T>,
    malloc: &TypedFunc<i32, i32>,
    memory: Memory,
    string: &str,
) -> Result<(i32, usize)> {
    let bytes = string.as_bytes();
    let length = bytes.len();

    // C str '\0'
    let ptr = malloc.call(&mut *store, length as i32 + 1)?;

    let data = memory.data_mut(&mut *store);
    data[ptr as usize..(ptr as usize + length as usize)].copy_from_slice(bytes);
    // C str '\0'
    data[ptr as usize + length] = 0;

    Ok((ptr, length as usize + 1))
}

fn malloc_bytes_from_wasm_memory<T>(
    store: &mut Store<T>,
    malloc: &TypedFunc<i32, i32>,
    length: i32,
) -> Result<(i32, usize)> {
    // C str '\0'
    let ptr = malloc.call(&mut *store, length + 1)?;
    Ok((ptr, length as usize + 1))
}

fn copy_cstr_from_wasm_memory<T>(
    store: &mut Store<T>,
    memory: Memory,
    ptr: usize,
) -> Result<(String, usize)> {
    let mut end = ptr;
    let data = memory.data(store);
    while data[end] != 0 {
        end += 1;
    }
    let result = std::str::from_utf8(&data[ptr..end])?.to_string();

    Ok((result, end + 1 - ptr))
}

fn free_memory<T>(
    store: &mut Store<T>,
    free: &TypedFunc<(i32, i32), ()>,
    ptr: i32,
    length: usize,
) -> Result<()> {
    free.call(store, (ptr, length as i32))?;
    Ok(())
}

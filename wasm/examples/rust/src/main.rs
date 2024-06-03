use anyhow::Result;
use wasmtime::*;
use wasmtime_wasi::{
    preview1::{self, WasiP1Ctx},
    WasiCtxBuilder,
};

const KCL_WASM_LIB_PATH: &str = "../../kcl.wasm";

struct State {
    pub wasi: WasiP1Ctx,
}

impl State {
    fn new() -> State {
        State {
            wasi: WasiCtxBuilder::new().build_p1(),
        }
    }
}

pub struct RunOptions {
    pub filename: String,
    pub source: String,
}

pub fn invoke_kcl_run(opts: &RunOptions) -> Result<String> {
    let engine = Engine::default();
    let mut store = Store::new(&engine, State::new());
    let binary_data = std::fs::read(KCL_WASM_LIB_PATH)?;
    let module = Module::new(&engine, &binary_data)?;
    let mut linker: Linker<State> = Linker::new(&engine);
    linker.func_wrap(
        "env",
        "kclvm_plugin_invoke_json_wasm",
        |_caller: Caller<'_, State>, _name: i32, _args: i32, _kwargs: i32| 0,
    )?;
    preview1::add_to_linker_sync(&mut linker, |my_state| &mut my_state.wasi)?;
    let instance = linker.instantiate(&mut store, &module)?;
    let memory = instance
        .get_memory(&mut store, "memory")
        .ok_or(anyhow::anyhow!("failed to find `memory` export"))?;

    let kcl_malloc = instance.get_typed_func::<i32, i32>(&mut store, "kcl_malloc")?;
    let kcl_free = instance.get_typed_func::<(i32, i32), ()>(&mut store, "kcl_free")?;
    let kcl_run = instance.get_typed_func::<(i32, i32), i32>(&mut store, "kcl_run")?;

    let (filename_ptr, filename_len) =
        copy_string_to_wasm_memory(&mut store, &kcl_malloc, memory, &opts.filename)?;
    let (source_ptr, source_len) =
        copy_string_to_wasm_memory(&mut store, &kcl_malloc, memory, &opts.source)?;
    let result_ptr = kcl_run.call(&mut store, (filename_ptr, source_ptr))?;

    let (result_str, result_len) =
        copy_cstr_from_wasm_memory(&mut store, memory, result_ptr as usize)?;

    free_memory(&mut store, &kcl_free, filename_ptr, filename_len)?;
    free_memory(&mut store, &kcl_free, source_ptr, source_len)?;
    free_memory(&mut store, &kcl_free, result_ptr, result_len)?;

    Ok(result_str)
}

pub fn copy_string_to_wasm_memory<T>(
    store: &mut Store<T>,
    malloc: &TypedFunc<i32, i32>,
    memory: Memory,
    string: &str,
) -> Result<(i32, usize)> {
    let bytes = string.as_bytes();
    let length = bytes.len();

    let ptr = malloc.call(&mut *store, length as i32)?;

    let data = memory.data_mut(&mut *store);
    data[ptr as usize..(ptr as usize + length as usize)].copy_from_slice(bytes);

    Ok((ptr, length as usize))
}

pub fn copy_cstr_from_wasm_memory<T>(
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

pub fn free_memory<T>(
    store: &mut Store<T>,
    free: &TypedFunc<(i32, i32), ()>,
    ptr: i32,
    length: usize,
) -> Result<()> {
    free.call(store, (ptr, length as i32))?;
    Ok(())
}

fn main() -> Result<()> {
    let opts = RunOptions {
        filename: "test.k".to_string(),
        source: "a = 1".to_string(),
    };
    let result = invoke_kcl_run(&opts)?;
    println!("{}", result);
    Ok(())
}

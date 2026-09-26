extern crate kcl_api;

#[unsafe(no_mangle)]
pub extern "C" fn callNative(
    name_ptr: *const u8,
    name_len: usize,
    args_ptr: *const u8,
    args_len: usize,
    result_ptr: *mut u8,
) -> usize {
    unsafe { kcl_api::call_native(name_ptr, name_len, args_ptr, args_len, result_ptr) }
}

#[unsafe(no_mangle)]
pub extern "C" fn call_native_with_plugin_agent(
    name_ptr: *const u8,
    name_len: usize,
    args_ptr: *const u8,
    args_len: usize,
    result_ptr: *mut u8,
    plugin_agent: u64,
) -> usize {
    let name = unsafe { std::slice::from_raw_parts(name_ptr, name_len) };
    let args = unsafe { std::slice::from_raw_parts(args_ptr, args_len) };
    let result = match kcl_api::call_with_plugin_agent(name, args, plugin_agent) {
        Ok(result) => result,
        Err(err) => format!("ERROR:{err}").into_bytes(),
    };
    unsafe {
        std::ptr::copy_nonoverlapping(result.as_ptr(), result_ptr, result.len());
    }
    result.len()
}

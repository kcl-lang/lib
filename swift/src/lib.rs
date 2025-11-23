extern crate kcl_api;

#[no_mangle]
pub extern "C" fn callNative(
    name_ptr: *const u8,
    name_len: usize,
    args_ptr: *const u8,
    args_len: usize,
    result_ptr: *mut u8,
) -> usize {
    kcl_api::call_native(name_ptr, name_len, args_ptr, args_len, result_ptr)
}

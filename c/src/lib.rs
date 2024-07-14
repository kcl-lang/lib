extern crate kclvm_api;

#[no_mangle]
pub extern "C" fn call_native(
    name_ptr: *const u8,
    name_len: usize,
    args_ptr: *const u8,
    args_len: usize,
    result_ptr: *mut u8,
) -> usize {
    kclvm_api::call_native(name_ptr, name_len, args_ptr, args_len, result_ptr)
}

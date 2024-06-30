extern crate kclvm_api;

use std::panic;
use std::any::Any;

#[no_mangle]
pub extern "C" fn callNative(
    name_ptr: *const u8,
    name_len: usize,
    args_ptr: *const u8,
    args_len: usize,
    result_ptr: *mut u8,
) -> usize {
    let result = panic::catch_unwind(|| {
        let name = unsafe { std::slice::from_raw_parts(name_ptr, name_len) };
        let args = unsafe { std::slice::from_raw_parts(args_ptr, args_len) };
        kclvm_api::call(name, args)
    });
    let result = match result {
        Ok(res) => match res {
            Ok(res) => res,
            Err(err) => err.to_string().into_bytes(),
        },
        Err(panic_err) => err_to_str(panic_err).into_bytes(),
    };
    unsafe {
        std::ptr::copy_nonoverlapping(result.as_ptr(), result_ptr, result.len());
    }
    result.len()
}

fn err_to_str(err: Box<dyn Any + Send>) -> String {
    if let Some(s) = err.downcast_ref::<&str>() {
        s.to_string()
    } else if let Some(s) = err.downcast_ref::<&String>() {
        (*s).clone()
    } else if let Some(s) = err.downcast_ref::<String>() {
        (*s).clone()
    } else {
        "".to_string()
    }
}

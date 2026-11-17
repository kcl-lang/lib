extern crate kcl_api;

// `call_native` is re-exported by kcl_api's own `#[no_mangle]`, but the
// service-handle dispatch that carries a plugin agent (docs/abi.md §6) is
// only reachable through `kcl_api::service::capi`, and the linker drops its
// `#[no_mangle]` symbols unless this crate actually references them.
// `kcl_lib_plugin.h` calls them when a plugin method is registered, so
// re-export them here to keep them in the cdylib.
pub use kcl_api::service::capi::{
    kcl_service_call_with_length, kcl_service_delete, kcl_service_free_string, kcl_service_new,
};

/// Release a buffer returned to the Go loader.
///
/// `go/native/native_nonmusl.go` resolves `kcl_free` from `libkcl.so`. The
/// published cdylib (`kcl-lib` in kcl-lang/kcl, `crates/lib/src/capi.rs`)
/// defines that symbol. This crate is what `hack/build-freebsd-lib.sh` and
/// the Android workflow stage under that filename, so it has to define it
/// too, or the loader panics on the next symbol after `kcl_service_new`.
///
/// The body matches `kcl-lib`: a zero length is a no-op, and otherwise the
/// pointer is handed to the global allocator. On Unix that allocator calls
/// `free`, which pairs with the `CString` returned by
/// `kcl_service_call_with_length`.
///
/// # Safety
///
/// `ptr` must be a buffer previously returned by this cdylib, or `size` must
/// be 0. Calling this twice on the same pointer is undefined.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn kcl_free(ptr: *mut u8, size: usize) {
    if size == 0 {
        return;
    }
    let align = std::mem::align_of::<usize>();
    let layout = unsafe { std::alloc::Layout::from_size_align_unchecked(size, align) };
    unsafe { std::alloc::dealloc(ptr, layout) };
}

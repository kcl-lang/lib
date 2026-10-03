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

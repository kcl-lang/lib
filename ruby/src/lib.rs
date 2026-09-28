//! Ruby bindings for the KCL language core via the `kcl-api` crate.
//!
//! This crate is a thin FFI layer: every KCL RPC is dispatched by name with
//! protobuf-encoded request/response bytes, mirroring the other language
//! bindings in this repository (see `python/src/lib.rs` for the reference
//! implementation). All the API surface lives in the Ruby layer
//! (`lib/kcl_lib/api.rb`).

use magnus::{Error, RString, Ruby};

/// Call KCL API with the API name and argument protobuf bytes.
fn call(ruby: &Ruby, name: RString, args: RString) -> Result<RString, Error> {
    let result = kcl_api::call(&rstring_bytes(name), &rstring_bytes(args)).map_err(map_err)?;
    Ok(ruby.str_from_slice(&result))
}

/// Call KCL API with the API name, plugin agent address and argument
/// protobuf bytes.
fn call_with_plugin_agent(
    ruby: &Ruby,
    name: RString,
    args: RString,
    plugin_agent: u64,
) -> Result<RString, Error> {
    let result =
        kcl_api::call_with_plugin_agent(&rstring_bytes(name), &rstring_bytes(args), plugin_agent)
            .map_err(map_err)?;
    Ok(ruby.str_from_slice(&result))
}

/// Copy the bytes out of a Ruby string. `RString::as_slice` is unsafe
/// because Ruby code could mutate or compact the string while the borrowed
/// slice is alive; this function only holds the borrow for the copy, and no
/// other Ruby thread can run in between because the caller holds the GVL.
fn rstring_bytes(s: RString) -> Vec<u8> {
    unsafe { s.as_slice() }.to_vec()
}

fn map_err(e: anyhow::Error) -> Error {
    Error::new(magnus::exception::runtime_error(), e.to_string())
}

#[magnus::init(name = "kcl_ruby")]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("KclLib")?;
    module.define_module_function("call", magnus::function!(call, 2))?;
    module.define_module_function(
        "call_with_plugin_agent",
        magnus::function!(call_with_plugin_agent, 3),
    )?;
    Ok(())
}

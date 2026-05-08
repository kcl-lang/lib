extern crate kcl_api;

use mlua::prelude::*;

mod client;

pub use client::NativeServiceClient;

/// Create a new NativeServiceClient instance
fn new_client<'a>(_lua: &'a Lua, _args: ()) -> LuaResult<NativeServiceClient> {
    Ok(NativeServiceClient::default())
}

#[mlua::lua_module]
fn kcl_lib(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    let module = lua.create_table()?;
    module.set("new_client", lua.create_function(new_client)?)?;
    Ok(module)
}

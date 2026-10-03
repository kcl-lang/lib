extern crate kcl_api;

use mlua::prelude::*;

mod client;
mod plugin;

pub use client::NativeServiceClient;
pub use plugin::{agent, disable, has_methods, register};

/// Create a new NativeServiceClient instance
fn new_client<'a>(_lua: &'a Lua, _args: ()) -> LuaResult<NativeServiceClient> {
    Ok(NativeServiceClient::default())
}

#[mlua::lua_module]
fn kcl_lib(lua: &Lua) -> LuaResult<LuaTable> {
    let module = lua.create_table()?;
    module.set("new_client", lua.create_function(new_client)?)?;
    // Plugin registry. A KCL program reaches a method by importing the
    // plugin module and calling it unqualified (`import kcl_plugin.strings`
    // then `strings.join(...)`); the runtime resolves that to the
    // `kcl_plugin.strings.join` name stored here.
    module.set(
        "register_plugin",
        lua.create_function(
            |lua, (plugin, method, func): (mlua::LuaString, mlua::LuaString, mlua::Function)| {
                register(lua, &plugin.to_str()?, &method.to_str()?, func)
            },
        )?,
    )?;
    module.set(
        "disable_plugins",
        lua.create_function(|_, ()| {
            disable();
            Ok(())
        })?,
    )?;
    Ok(module)
}

extern crate kcl_api;

use mlua::{Error, LuaString, MetaMethod, UserData, UserDataMethods};

use crate::plugin;

#[derive(Default)]
pub struct NativeServiceClient;

impl UserData for NativeServiceClient {
    fn add_methods<M: UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method(
            "call",
            |lua, _this, (name, args): (LuaString, LuaString)| {
                // `kcl_api::call` is the stateless dispatcher. Once a plugin
                // method is registered the agent has to travel with the call,
                // so route through `call_with_plugin_agent` instead; both
                // decode the same protobuf payloads.
                let result = if plugin::has_methods() {
                    kcl_api::call_with_plugin_agent(
                        name.as_bytes().as_ref(),
                        args.as_bytes().as_ref(),
                        plugin::agent as *const () as usize as u64,
                    )
                } else {
                    kcl_api::call(name.as_bytes().as_ref(), args.as_bytes().as_ref())
                };
                result
                    .map(|v| lua.create_string(v))
                    .map_err(|e| Error::runtime(e.to_string()))
            },
        );
        methods.add_meta_function(MetaMethod::Call, |_, ()| Ok(NativeServiceClient::default()));
    }
}

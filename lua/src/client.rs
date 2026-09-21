extern crate kcl_api;

use mlua::{Error, MetaMethod, String as LuaString, UserData, UserDataMethods};

#[derive(Default)]
pub struct NativeServiceClient;

impl UserData for NativeServiceClient {
    fn add_methods<'a, M: UserDataMethods<'a, Self>>(methods: &mut M) {
        methods.add_method(
            "call",
            |lua, _this, (name, args): (LuaString, LuaString)| {
                kcl_api::call(name.as_bytes(), args.as_bytes())
                    .map(|v| lua.create_string(v))
                    .map_err(|e| Error::runtime(e.to_string()))
            },
        );
        methods.add_meta_function(MetaMethod::Call, |_, ()| Ok(NativeServiceClient::default()));
    }
}

extern crate kclvm_api;

use mlua::prelude::*;

/// Execute KCL file with arguments and return the JSON/YAML result.
fn exec_program<'a>(lua: &'a Lua, args: LuaTable<'a>) -> LuaResult<LuaTable<'a>> {
    let api = kclvm_api::API::default();
    let work_dir: String = args.get("work_dir")?;
    let k_filename_list: Vec<String> = args.get("k_filename_list")?;
    let k_code_list: Vec<String> = args.get("k_code_list")?;

    let result = match api.exec_program(&kclvm_api::ExecProgramArgs {
        work_dir,
        k_filename_list,
        k_code_list,
        ..Default::default()
    }) {
        Ok(r) => r,
        Err(e) => return Err(LuaError::external(e)),
    };

    let t = lua.create_table()?;
    t.set("json_result", lua.create_string(result.json_result)?)?;
    t.set("yaml_result", lua.create_string(result.yaml_result)?)?;
    t.set("log_message", lua.create_string(result.log_message)?)?;
    t.set("err_message", lua.create_string(result.err_message)?)?;
    Ok(t)
}

#[mlua::lua_module]
fn kcl_lib(lua: &Lua) -> LuaResult<LuaTable> {
    let module = lua.create_table()?;
    module.set("exec_program", lua.create_function(exec_program)?)?;
    Ok(module)
}

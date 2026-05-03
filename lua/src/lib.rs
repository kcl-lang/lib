extern crate kcl_api;

use mlua::prelude::*;

/// Execute KCL code and return the JSON/YAML result.
fn run<'a>(lua: &'a Lua, path: LuaValue) -> LuaResult<LuaTable<'a>> {
    let api = kcl_api::API::default();
    let k_filename_list = match path {
        LuaValue::String(s) => Ok(vec![s.to_str()?.to_owned()]),
        LuaValue::Table(t) => t
            .sequence_values::<String>()
            .collect::<Result<Vec<String>, LuaError>>(),
        _ => {
            return Err(LuaError::runtime(
                "invalid argument type for function `run`, expecting string or table",
            ));
        }
    }?;

    let result = match api.exec_program(&kcl_api::ExecProgramArgs {
        k_filename_list,
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

/// Format KCL code from a file.
fn format<'a>(lua: &'a Lua, path: String) -> LuaResult<LuaTable<'a>> {
    let api = kcl_api::API::default();

    let result = match api.format_path(&kcl_api::FormatPathArgs {
        path,
        ..Default::default()
    }) {
        Ok(r) => r,
        Err(e) => return Err(LuaError::external(e)),
    };

    let t = lua.create_table()?;
    for changed_path in result.changed_paths.iter() {
        t.push(lua.create_string(changed_path)?)?;
    }
    Ok(t)
}

#[mlua::lua_module]
fn kcl_lib(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    let module = lua.create_table()?;
    module.set("run", lua.create_function(run)?)?;
    module.set("format", lua.create_function(format)?)?;
    Ok(module)
}

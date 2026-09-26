use napi::bindgen_prelude::*;
use napi::{Env, JsFunction, JsObject, JsUnknown, Ref, ValueType};
use std::cell::RefCell;
use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::panic::{AssertUnwindSafe, catch_unwind};

type MethodMap = HashMap<String, Ref<()>>;

thread_local! {
    static PLUGIN_ENV: RefCell<Option<Env>> = const { RefCell::new(None) };
    static PLUGIN_REGISTRY: RefCell<HashMap<String, MethodMap>> = RefCell::new(HashMap::new());
    static PLUGIN_RESULT: RefCell<Option<CString>> = const { RefCell::new(None) };
}

/// Register a KCL plugin with the given name and method map. Each method is
/// called as `method(args, kwargs)` from KCL code importing
/// `kcl_plugin.<name>` while `execProgram` runs, and its return value is
/// serialized to JSON as the plugin result.
#[napi]
pub fn register_plugin(env: Env, name: String, methods: HashMap<String, JsFunction>) -> Result<()> {
    let mut method_map = HashMap::with_capacity(methods.len());
    for (method_name, func) in methods {
        method_map.insert(method_name, env.create_reference(func)?);
    }
    PLUGIN_ENV.with(|e| *e.borrow_mut() = Some(env));
    PLUGIN_REGISTRY.with(|r| r.borrow_mut().insert(name, method_map));
    Ok(())
}

pub fn plugin_agent_ptr() -> u64 {
    PLUGIN_REGISTRY.with(|r| {
        if r.borrow().is_empty() {
            0
        } else {
            plugin_method_agent as *const () as u64
        }
    })
}

extern "C-unwind" fn plugin_method_agent(
    method: *const c_char,
    args_json: *const c_char,
    kwargs_json: *const c_char,
) -> *const c_char {
    let json = match catch_unwind(AssertUnwindSafe(|| {
        invoke_method(method, args_json, kwargs_json)
    })) {
        Ok(json) => json,
        Err(_) => "{\"__kcl_PanicInfo__\":\"plugin agent panic\"}".to_string(),
    };
    PLUGIN_RESULT.with(|cell| {
        let mut slot = cell.borrow_mut();
        *slot = Some(CString::new(json).unwrap_or_else(|_| CString::new("null").unwrap()));
        slot.as_ref()
            .map(|s| s.as_ptr())
            .unwrap_or(std::ptr::null())
    })
}

fn invoke_method(
    method_ptr: *const c_char,
    args_ptr: *const c_char,
    kwargs_ptr: *const c_char,
) -> String {
    let method = c_str_to_string(method_ptr);
    let dot_idx = match method.rfind('.') {
        Some(idx) => idx,
        None => return String::new(),
    };
    let plugin_name = method[..dot_idx].rsplit('.').next().unwrap_or("");
    let method_name = &method[dot_idx + 1..];
    let env = match PLUGIN_ENV.with(|e| *e.borrow()) {
        Some(env) => env,
        None => return String::new(),
    };
    let func = PLUGIN_REGISTRY.with(|r| {
        r.borrow()
            .get(plugin_name)
            .and_then(|methods| methods.get(method_name))
            .and_then(|reference| env.get_reference_value::<JsFunction>(reference).ok())
    });
    let func = match func {
        Some(func) => func,
        None => return "null".to_string(),
    };
    let args_json = c_str_to_string(args_ptr);
    let kwargs_json = c_str_to_string(kwargs_ptr);
    match call_plugin_method(&env, &func, &args_json, &kwargs_json) {
        Ok(json) => json,
        Err(err) => json_panic_info(&err.reason),
    }
}

fn call_plugin_method(
    env: &Env,
    func: &JsFunction,
    args_json: &str,
    kwargs_json: &str,
) -> Result<String> {
    let args = json_parse(
        env,
        if args_json.is_empty() {
            "[]"
        } else {
            args_json
        },
    )?;
    let kwargs = json_parse(
        env,
        if kwargs_json.is_empty() {
            "{}"
        } else {
            kwargs_json
        },
    )?;
    let result = func.call(None, &[args, kwargs])?;
    json_stringify(env, &result)
}

fn json_parse(env: &Env, json: &str) -> Result<JsUnknown> {
    let json_obj = json_object(env)?;
    let parse: JsFunction = json_obj.get_named_property("parse")?;
    let input = env.create_string(json)?;
    parse.call(Some(&json_obj), &[input])
}

fn json_stringify(env: &Env, value: &JsUnknown) -> Result<String> {
    match value.get_type()? {
        ValueType::Undefined | ValueType::Null | ValueType::Function | ValueType::Symbol => {
            Ok("null".to_string())
        }
        _ => {
            let json_obj = json_object(env)?;
            let stringify: JsFunction = json_obj.get_named_property("stringify")?;
            let out = stringify.call(Some(&json_obj), &[value])?;
            out.coerce_to_string()?.into_utf8()?.into_owned()
        }
    }
}

fn json_object(env: &Env) -> Result<JsObject> {
    env.get_global()?.get_named_property("JSON")
}

fn json_panic_info(message: &str) -> String {
    let mut escaped = String::with_capacity(message.len());
    for ch in message.chars() {
        match ch {
            '"' => escaped.push_str("\\\""),
            '\\' => escaped.push_str("\\\\"),
            '\n' => escaped.push_str("\\n"),
            '\r' => escaped.push_str("\\r"),
            '\t' => escaped.push_str("\\t"),
            c if (c as u32) < 0x20 => escaped.push_str(&format!("\\u{:04x}", c as u32)),
            c => escaped.push(c),
        }
    }
    format!("{{\"__kcl_PanicInfo__\":\"{escaped}\"}}")
}

fn c_str_to_string(ptr: *const c_char) -> String {
    if ptr.is_null() {
        return String::new();
    }
    unsafe { CStr::from_ptr(ptr) }
        .to_string_lossy()
        .into_owned()
}

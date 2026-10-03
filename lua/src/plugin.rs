//! KCL plugin support: Lua functions callable from KCL source.
//!
//! A KCL program reaches a plugin by importing the plugin module and calling
//! the method unqualified:
//!
//! ```kcl
//! import kcl_plugin.strings
//! result = strings.join("KCL", "KCL", 123)
//! ```
//!
//! The runtime resolves that to a `kcl_plugin.strings.join` call into the
//! host, so [`register`] only ever sees the two halves (`"strings"`,
//! `"join"`). The Lua-visible wrapper is `kcl_lib.plugin`.
//!
//! Two properties are worth calling out:
//!
//! * **No JSON dependency.** Arguments arrive as raw JSON and the result
//!   must be JSON-encoded, so a method that ignores its arguments needs no
//!   parser at all. One that inspects them can use `dkjson`, which the
//!   binding already depends on.
//! * **Errors are data, not crashes.** Invoking a method that was never
//!   registered yields a `{"__kcl_PanicInfo__": "..."}` object, matching
//!   what Go's `plugin.JSONError` and Python's `_call_py_method` return, so
//!   an unknown method surfaces as a KCL-level diagnostic.

use std::ffi::c_char;
use std::sync::Mutex;
use std::sync::atomic::{AtomicUsize, Ordering};

use mlua::{Error, Function, Lua, LuaString, Result, Table, lua_State};

const PLUGIN_PREFIX: &str = "kcl_plugin.";

/// Named-registry slot holding the `{ ["kcl_plugin.<p>.<m>"] = fn }` table.
/// The Lua registry is GC-rooted, so a registered method stays alive for as
/// long as the `Lua` does, without the plugin module having to keep a
/// reference of its own.
const REGISTRY_KEY: &str = "kcl_lib.plugins";

/// The interpreter the registered methods live in, as a raw `lua_State`
/// pointer. The agent is a bare C callback with no user data, so this is how
/// it gets back to the interpreter; `Lua::get_or_init_from_ptr` turns it into
/// a `&Lua` again. An `AtomicUsize` rather than a `*mut lua_State` because a
/// `static` needs `Sync`, and `disable` has to be able to clear it.
static LUA_STATE: AtomicUsize = AtomicUsize::new(0);

/// Reused for every reply handed back to the runtime. The runtime parses it
/// on return from the agent, so a single buffer is enough — and a plugin
/// method must not hold on to the previous result.
static REPLY: Mutex<Vec<u8>> = Mutex::new(Vec::new());

/// Add or replace `plugin`.`method`. Register methods at start-up: nothing
/// evaluated before the first registration can reach the plugin.
pub fn register(lua: &Lua, plugin: &str, method: &str, func: Function) -> Result<()> {
    if plugin.is_empty() || method.is_empty() {
        return Err(Error::runtime("plugin and method names must not be empty"));
    }
    let table = registry_table(lua)?;
    table.set(format!("{PLUGIN_PREFIX}{plugin}.{method}"), func)?;

    // Remember the interpreter the methods live in, so the agent can reach
    // them. The host interpreter outlives every call, which is what makes the
    // `'static` borrow in `agent` sound.
    LUA_STATE.store(lua.state() as usize, Ordering::Release);
    Ok(())
}

/// Whether any plugin method is currently registered.
pub fn has_methods() -> bool {
    LUA_STATE.load(Ordering::Acquire) != 0
}

/// Forget every registered method and return the client to the stateless
/// `kcl_api::call` path. The methods themselves live in the Lua registry, so
/// clearing the pointer is enough to make them unreachable.
pub fn disable() {
    LUA_STATE.store(0, Ordering::Release);
}

fn registry_table(lua: &Lua) -> Result<Table> {
    match lua.named_registry_value::<Table>(REGISTRY_KEY) {
        Ok(table) => Ok(table),
        Err(_) => {
            let table = lua.create_table()?;
            lua.set_named_registry_value(REGISTRY_KEY, table.clone())?;
            Ok(table)
        }
    }
}

/// The C entry point the KCL runtime calls. `method` is the fully-qualified
/// plugin name; `args_json` / `kwargs_json` are the JSON arguments.
pub extern "C" fn agent(
    method: *const c_char,
    args_json: *const c_char,
    kwargs_json: *const c_char,
) -> *const c_char {
    let method = cstr(method);
    let args = cstr(args_json);
    let kwargs = cstr(kwargs_json);
    set_reply(invoke(method, args, kwargs))
}

fn invoke(method: &str, args: &str, kwargs: &str) -> String {
    let state = LUA_STATE.load(Ordering::Acquire);
    if state == 0 {
        return panic_info("plugin handler is not registered");
    }
    // SAFETY: `register` only stores a state the host interpreter owns, and
    // the host keeps it alive for the process lifetime (it is the state our
    // own `client:call` method was entered on). `get_or_init_from_ptr`
    // returns the already-initialised instance, so nothing is adopted here.
    let lua = unsafe { Lua::get_or_init_from_ptr(state as *mut lua_State) };
    let Ok(table) = registry_table(lua) else {
        return panic_info("plugin handler is not registered");
    };
    // The runtime sends the fully-qualified `kcl_plugin.<plugin>.<method>`
    // name, which is exactly the key `register` stored.
    let entry: mlua::Value = match table.get(method) {
        Ok(value) => value,
        Err(_) => return panic_info(&format!("invalid method: {method} is not found")),
    };
    let func: Function = match entry.as_function() {
        Some(func) => func.clone(),
        None => return panic_info(&format!("invalid method: {method} is not a function")),
    };
    match func.call::<LuaString>((args, kwargs)) {
        Ok(result) => result.to_string_lossy().to_owned(),
        // A method that raised is reported the same way an unregistered one
        // is, so the failure stays a KCL-level diagnostic.
        Err(err) => panic_info(&err.to_string()),
    }
}

fn cstr<'a>(ptr: *const c_char) -> &'a str {
    if ptr.is_null() {
        return "";
    }
    unsafe { std::ffi::CStr::from_ptr(ptr) }
        .to_str()
        .unwrap_or("")
}

/// A valid empty C string, returned when the reply buffer is unreachable.
static EMPTY: &[u8] = b"";

/// Copy `text` into the shared reply buffer and hand back a pointer to it.
/// The buffer is only overwritten by the next call, by which point the
/// runtime has already parsed the JSON.
fn set_reply(text: String) -> *const c_char {
    let Ok(mut reply) = REPLY.lock() else {
        return EMPTY.as_ptr() as *const c_char;
    };
    reply.clear();
    reply.extend_from_slice(text.as_bytes());
    reply.push(0);
    reply.as_ptr() as *const c_char
}

/// Build `{"__kcl_PanicInfo__":"<message>"}`, the same shape Go's
/// `plugin.JSONError` and Python's `_call_py_method` produce.
fn panic_info(message: &str) -> String {
    let mut escaped = String::with_capacity(message.len() + 2);
    escaped.push('"');
    for ch in message.chars() {
        match ch {
            '"' | '\\' => {
                escaped.push('\\');
                escaped.push(ch);
            }
            '\n' => escaped.push_str("\\n"),
            '\r' => escaped.push_str("\\r"),
            '\t' => escaped.push_str("\\t"),
            // `\u{...}` needs braces; the control characters a Lua error can
            // realistically carry are all below 0x20, so the fixed-width
            // form below is both sufficient and what Go emits.
            c if (c as u32) < 0x20 => escaped.push_str(&format!("\\u{:04x}", c as u32)),
            c => escaped.push(c),
        }
    }
    escaped.push('"');
    format!("{{\"__kcl_PanicInfo__\":{escaped}}}")
}

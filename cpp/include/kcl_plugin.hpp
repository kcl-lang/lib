#pragma once

// KCL plugin support for the C++ binding.
//
// KCL source can call host functions as `kcl_plugin.<plugin>.<method>(...)`.
// The runtime resolves those names by invoking a plugin-agent callback with
// the method name plus JSON-encoded args/kwargs, and reads back a
// JSON-encoded result (docs/abi.md §7). Python, .NET, Go, Node.js, Java,
// Kotlin, Ruby, Swift, C and Zig all ship such an agent; this header brings
// the same capability to C++.
//
// ```cpp
// #include "kcl_facade.hpp"
// #include "kcl_plugin.hpp"
//
// kcl_lib::register_plugin("strings", "join", [](const std::string& args, const std::string&) {
//     // args is `["KCL", "KCL", 123]`; return a JSON-encoded result.
//     return std::string("\"KCL.KCL.123\"");
// });
//
// kcl_lib::Options options;
// std::cout << kcl_lib::Kcl::run(R"(import kcl_plugin.strings
// result = strings.join("KCL", "KCL", 123))", options).to_json_string();
// ```
//
// Registering the first method binds the runtime to the agent, after which
// every RPC reaches the plugin. With nothing registered the binding keeps
// building a stateless service, so programs that do not use plugins are
// unaffected.
//
// Two properties are worth calling out:
//
// + **No JSON dependency.** Arguments arrive as raw JSON strings and the
//   result must be JSON-encoded, so a method that ignores its arguments needs
//   no parser at all. One that inspects them can use `kcl_lib::Json`, which
//   the facade already provides.
// + **Errors are data, not crashes.** Calling a method that was never
//   registered — or one that threw — yields a
//   `{"__kcl_PanicInfo__": "..."}` object, matching what Go's
//   `plugin.JSONError` and Python's `_call_py_method` return, so it surfaces
//   through the normal `err_message` path rather than as a native crash.
//
// Threading: the registry is process-wide and the reply buffer is per-thread.
// Register methods during start-up, before any KCL evaluation runs, the same
// way Go registers them from `init()`.

#include "kcl_lib.hpp"

#include <cstdint>
#include <exception>
#include <functional>
#include <map>
#include <stdexcept>
#include <string>

namespace kcl_lib {

/// A plugin method. Receives the JSON-encoded positional arguments and the
/// JSON-encoded keyword arguments (either may be empty), and returns a
/// JSON-encoded result. Throwing is allowed — the exception is reported to
/// the runtime as a `__kcl_PanicInfo__` object.
using PluginMethod = std::function<std::string(const std::string& args, const std::string& kwargs)>;

namespace plugin_detail {

/// The `kcl_plugin.<plugin>.<method>` name a registration is stored under.
inline std::string absolute_name(const std::string& plugin, const std::string& method)
{
    return "kcl_plugin." + plugin + "." + method;
}

inline std::map<std::string, PluginMethod>& registry()
{
    static std::map<std::string, PluginMethod> methods;
    return methods;
}

/// The reply handed back to the runtime. The runtime parses it as soon as the
/// agent returns and never frees it, so one buffer per thread is enough — and
/// a plugin method must not hold on to the previous result.
inline std::string& reply()
{
    static thread_local std::string buffer;
    return buffer;
}

/// Build `{"__kcl_PanicInfo__":"<message>"}`, the same shape Go's
/// `plugin.JSONError` and Python's `_call_py_method` produce.
inline std::string panic_info(const std::string& message)
{
    std::string escaped = "\"";
    escaped.reserve(message.size() + 2);
    for (const char ch : message) {
        switch (ch) {
        case '"':
            escaped += "\\\"";
            break;
        case '\\':
            escaped += "\\\\";
            break;
        case '\n':
            escaped += "\\n";
            break;
        case '\r':
            escaped += "\\r";
            break;
        case '\t':
            escaped += "\\t";
            break;
        default:
            // `\u` needs four hex digits; the control characters a C++
            // exception message can realistically carry are all below 0x20.
            if (static_cast<unsigned char>(ch) < 0x20) {
                static const char* const digits = "0123456789abcdef";
                const unsigned char code = static_cast<unsigned char>(ch);
                escaped += "\\u00";
                escaped += digits[(code >> 4) & 0xF];
                escaped += digits[code & 0xF];
            } else {
                escaped += ch;
            }
            break;
        }
    }
    escaped += '"';
    return "{\"__kcl_PanicInfo__\":" + escaped + "}";
}

/// The C entry point the KCL runtime calls. `method` is the fully-qualified
/// plugin name; `args` / `kwargs` are the JSON arguments. `extern "C"` because
/// the runtime holds it as a bare function pointer, and noexcept because a C++
/// exception must never unwind into the Rust frames underneath — everything
/// that can fail is reported as a `__kcl_PanicInfo__` object instead.
extern "C" inline const char* agent(const char* method, const char* args, const char* kwargs) noexcept
{
    std::string& buffer = reply();
    if (method == nullptr) {
        buffer = panic_info("invalid method: not found");
        return buffer.c_str();
    }
    const auto found = registry().find(method);
    if (found == registry().end()) {
        buffer = panic_info(std::string("invalid method: ") + method + " is not found");
        return buffer.c_str();
    }
    try {
        buffer = found->second(args == nullptr ? "" : args, kwargs == nullptr ? "" : kwargs);
    } catch (const std::exception& err) {
        buffer = panic_info(err.what());
    } catch (...) {
        buffer = panic_info("plugin method raised an unknown error");
    }
    return buffer.c_str();
}

inline std::uint64_t agent_address()
{
    return static_cast<std::uint64_t>(reinterpret_cast<std::uintptr_t>(&agent));
}

} // namespace plugin_detail

/// Add or replace `kcl_plugin.<plugin>.<method>`, binding the runtime to the
/// agent on the first registration. Register methods at start-up: nothing
/// evaluated before the first registration can reach the plugin.
inline void register_plugin(const std::string& plugin, const std::string& method, PluginMethod fn)
{
    if (plugin.empty() || method.empty() || !fn) {
        throw std::invalid_argument("kcl_lib::register_plugin: plugin and method names must not be empty");
    }
    plugin_detail::registry()[plugin_detail::absolute_name(plugin, method)] = std::move(fn);
    set_plugin_agent(plugin_detail::agent_address());
}

/// Whether `kcl_plugin.<plugin>.<method>` resolves to a registered function.
inline bool plugin_registered(const std::string& plugin, const std::string& method)
{
    return plugin_detail::registry().count(plugin_detail::absolute_name(plugin, method)) != 0;
}

/// Drop every registered method and unbind the runtime, returning the binding
/// to the stateless dispatch.
inline void disable_plugins()
{
    plugin_detail::registry().clear();
    set_plugin_agent(0);
}

/// Whether any plugin method is currently registered.
inline bool has_plugins()
{
    return !plugin_detail::registry().empty();
}

} // namespace kcl_lib

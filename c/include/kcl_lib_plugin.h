#ifndef _KCL_LIB_PLUGIN_H
#define _KCL_LIB_PLUGIN_H

// KCL plugin support for the C binding.
//
// KCL source can call host functions as `kcl_plugin.<plugin>.<method>(...)`.
// The runtime resolves those names by invoking a plugin-agent callback with
// the method name plus JSON-encoded args/kwargs, and reads back a
// JSON-encoded result (docs/abi.md §7). Python, .NET, Go, Node.js, Java,
// Kotlin, Ruby and Swift all ship such an agent; this header brings the same
// capability to C, with the arguments left as raw JSON for the plugin author
// to decode — the C binding has no JSON dependency and does not add one.
//
// ```c
// static const char* strings_join(const char* method, const char* args_json, const char* kwargs_json)
// {
//     /* args_json is `["KCL", "KCL", 123]`; return a JSON-encoded result. */
//     return "\"KCL.KCL.123\"";
// }
//
// kcl_plugin_register("strings", "join", strings_join);   // binds the runtime
// kcl_exec_program(&args, &result);                       // plugin now reachable
// ```
//
// Registering the first method binds the runtime, after which every RPC
// dispatches through a service handle carrying the agent. With nothing
// registered the binding keeps using the stateless `call_native` path, so
// programs that do not use plugins are unaffected.
//
// Threading: registration and the enable/disable calls are not synchronized.
// Register methods during start-up, before any KCL evaluation runs, the same
// way Go registers them from `init()`.

#include "kcl_lib.h"

#ifdef __cplusplus
extern "C" {
#endif

/// A plugin method. Receives the absolute method name, the JSON-encoded
/// positional arguments (or an empty string) and the JSON-encoded keyword
/// arguments (or an empty string). Must return a JSON-encoded result, or NULL
/// to report "no result" — the runtime then sees an empty string. The returned
/// pointer only has to stay alive until the next plugin invocation.
typedef const char* (*KclPluginMethod)(const char* method, const char* args_json, const char* kwargs_json);

/// Register `fn` as `kcl_plugin.<plugin_name>.<method_name>`, binding the
/// runtime to the agent on the first registration. Re-registering the same
/// absolute name replaces the previous function. Returns false when the
/// registry is full or an argument is invalid.
bool kcl_plugin_register(const char* plugin_name, const char* method_name, KclPluginMethod fn);

/// Whether `kcl_plugin.<plugin>.<method>` resolves to a registered function.
bool kcl_plugin_registered(const char* plugin_name, const char* method_name);

/// Unbind the runtime and drop every registered method, restoring the
/// stateless `call_native` dispatch.
void kcl_plugin_disable(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif /* _KCL_LIB_PLUGIN_H */

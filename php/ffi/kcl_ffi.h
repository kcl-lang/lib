#ifndef _KCL_FFI_H
#define _KCL_FFI_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

uintptr_t call_native(const uint8_t *name_ptr,
                      uintptr_t name_len,
                      const uint8_t *args_ptr,
                      uintptr_t args_len,
                      uint8_t *result_ptr);

// Service-handle dispatch (docs/abi.md §6). `call_native` is stateless, so it
// cannot carry a plugin-agent callback; a handle created with
// `kcl_service_new(plugin_agent)` can, which is how the plugin support in
// `kcl_lib_plugin.h` reaches the runtime. Both entry points decode the same
// protobuf payloads, so a program may mix them freely.
typedef uintptr_t KclServiceHandle;

KclServiceHandle kcl_service_new(uint64_t plugin_agent);
void kcl_service_delete(KclServiceHandle svc);
const uint8_t* kcl_service_call_with_length(KclServiceHandle svc,
                                           const char* method,
                                           const char* args,
                                           size_t args_len,
                                           size_t* out_len);
void kcl_service_free_string(const uint8_t* ptr);

// Implemented by `kcl_lib_plugin.c`; returns the handle bound to the
// registered plugin methods, or 0 when no plugin is bound. Declared weak so
// that builds which do not compile the plugin shim still link — the symbol
// then resolves to NULL and `kcl_call` keeps using `call_native`.
#if defined(__GNUC__) || defined(__clang__)
__attribute__((weak)) KclServiceHandle kcl_plugin_service_handle(void);
#else
// No weak-symbol support here, so the shim has to be linked in.
KclServiceHandle kcl_plugin_service_handle(void);
#endif

#ifdef __cplusplus
} // extern "C"
#endif // __cplusplus

#endif /* _KCL_FFI_H */

#ifndef _KCL_FFI_H
#define _KCL_FFI_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

uintptr_t callNative(const uint8_t *name_ptr,
                      uintptr_t name_len,
                      const uint8_t *args_ptr,
                      uintptr_t args_len,
                      uint8_t *result_ptr);

// Instance-oriented C API exported by kcl-api's capi module (crates/api/src/
// service/capi.rs). Unlike the one-shot `callNative` above, a service created
// with `kcl_service_new` carries a plugin agent — the address of a host
// callback the runtime invokes for `kcl_plugin.<name>.<method>` calls. Pass 0
// to disable plugins. The kcl_service_* symbols ship in the same
// libkcl_lib_c.a as callNative; the swift shim does not re-export them.
typedef struct kcl_service kcl_service_t;

// plugin_agent is the address of a C function with signature
// const char *(*)(const char *method, const char *args_json, const char *kwargs_json)
// returning a NUL-terminated JSON result string.
kcl_service_t *kcl_service_new(uint64_t plugin_agent);

void kcl_service_delete(kcl_service_t *serv);

// `name` is a NUL-terminated "KclService.<Method>" string; `args` is the
// protobuf request byte sequence. The returned pointer is Rust-owned and must
// be released with `kcl_service_free_string`.
const char *kcl_service_call_with_length(kcl_service_t *serv,
                                         const char *name,
                                         const char *args,
                                         uintptr_t args_len,
                                         uintptr_t *result_len);

void kcl_service_free_string(char *res);

#ifdef __cplusplus
} // extern "C"
#endif // __cplusplus

#endif /* _KCL_FFI_H */

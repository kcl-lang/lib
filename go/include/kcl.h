#ifndef _KCL_H
#define _KCL_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

typedef uintptr_t KclServiceHandle;

KclServiceHandle kcl_service_new(uint64_t plugin_agent);
void kcl_service_delete(KclServiceHandle svc);
uint8_t* kcl_service_call_with_length(
    KclServiceHandle svc,
    const char* method,
    const char* args,
    uint32_t args_len,
    uint32_t* out_len
);
void kcl_free(uint8_t* ptr, uint32_t len);

#ifdef __cplusplus
} // extern "C"
#endif // __cplusplus

#endif /* _KCL_H */

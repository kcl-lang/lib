#ifndef KCL_LIB_H
#define KCL_LIB_H

#include <stdint.h>
#include <stdlib.h>

#ifndef KCL_API_EXTERN
#if defined(_WIN32) && !defined(__MINGW32__) && !defined(LIBKCL_STATIC)
#define KCL_API_EXTERN __declspec(dllimport)
#else
#define KCL_API_EXTERN
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct kclvm_service kclvm_service;

KCL_API_EXTERN kclvm_service *kclvm_service_new(uint64_t plugin_agent);

KCL_API_EXTERN void kclvm_service_delete(kclvm_service *c);

KCL_API_EXTERN void kclvm_service_free_string(const char *res);

KCL_API_EXTERN const char *kclvm_service_call_with_length(kclvm_service *c,
                                                          const char *method,
                                                          const char *args,
                                                          size_t args_len,
                                                          size_t *result_len);

#ifdef __cplusplus
} // extern "C"
#endif

#endif

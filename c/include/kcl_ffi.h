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

#ifdef __cplusplus
} // extern "C"
#endif // __cplusplus

#endif /* _KCL_FFI_H */

#include <stdint.h>
#include <stdlib.h>

extern char *kcl_go_plugin_proxy_func(char *method, char *args_json,
                                      char *kwargs_json);

uint64_t kcl_go_plugin_get_proxy_func_ptr() {
  return (uint64_t)(kcl_go_plugin_proxy_func);
}

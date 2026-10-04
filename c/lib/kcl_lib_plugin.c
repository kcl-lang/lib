/*
 * kcl_lib_plugin.c — KCL plugin agent for the C binding.
 *
 * Registers host functions under `kcl_plugin.<plugin>.<method>` and binds
 * them to the runtime through a service handle (see docs/abi.md §6/§7). See
 * `include/kcl_lib_plugin.h` for the user-facing API.
 */

// Only `kcl_ffi.h` — this file is linked into `libkcl_lib_c.a` alongside the
// other `lib/*.c` translation units, and `kcl_lib_plugin.h` pulls in
// `kcl_lib.h`, whose non-static inline helpers would then be defined twice
// (once here, once in every example object). Same reason `kcl_lib_ast.c` and
// `kcl_lib_msgs.c` include their own headers directly.
#include "kcl_ffi.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// The public declarations from kcl_lib_plugin.h, minus the kcl_lib.h include.
typedef const char* (*KclPluginMethod)(const char* method, const char* args_json, const char* kwargs_json);

bool kcl_plugin_register(const char* plugin_name, const char* method_name, KclPluginMethod fn);
bool kcl_plugin_registered(const char* plugin_name, const char* method_name);
void kcl_plugin_disable(void);

#define KCL_PLUGIN_PREFIX "kcl_plugin."
#define KCL_PLUGIN_MAX_METHODS 128
#define KCL_PLUGIN_NAME_MAX 128

struct KclPluginEntry {
    char name[KCL_PLUGIN_NAME_MAX];
    KclPluginMethod fn;
};

static struct KclPluginEntry kcl_plugin_registry[KCL_PLUGIN_MAX_METHODS];
static size_t kcl_plugin_registry_len = 0;
static KclServiceHandle kcl_plugin_service = 0;

/* Reply buffer handed back to the runtime. Replaced on every invocation, so a
 * plugin method must not hold on to the previous result. */
static char* kcl_plugin_reply = NULL;
static size_t kcl_plugin_reply_cap = 0;

static const char* kcl_plugin_panic_info(const char* message);

/* The runtime calls this with the method name and JSON args, and reads a
 * JSON-encoded result back. Errors are reported the way every other binding
 * reports them: a `__kcl_PanicInfo__` object rather than a native panic. */
const char* kcl_plugin_method_agent(const char* method, const char* args_json, const char* kwargs_json)
{
    struct KclPluginEntry* entry = NULL;
    const char* result;
    size_t i;

    if (method == NULL) {
        return "";
    }
    for (i = 0; i < kcl_plugin_registry_len; i++) {
        if (strcmp(kcl_plugin_registry[i].name, method) == 0) {
            entry = &kcl_plugin_registry[i];
            break;
        }
    }
    if (entry == NULL) {
        return kcl_plugin_panic_info("invalid method: not found");
    }

    result = entry->fn(method, args_json == NULL ? "" : args_json, kwargs_json == NULL ? "" : kwargs_json);
    if (result == NULL) {
        return "";
    }

    {
        size_t len = strlen(result);
        if (len + 1 > kcl_plugin_reply_cap) {
            char* grown = (char*)realloc(kcl_plugin_reply, len + 1);
            if (grown == NULL) {
                return kcl_plugin_panic_info("out of memory building the plugin reply");
            }
            kcl_plugin_reply = grown;
            kcl_plugin_reply_cap = len + 1;
        }
        memcpy(kcl_plugin_reply, result, len + 1);
    }
    return kcl_plugin_reply;
}

/* Build `{"__kcl_PanicInfo__":"<message>"}` in the shared reply buffer, the
 * same shape Go's `plugin.JSONError` and Python's `_call_py_method` produce. */
static const char* kcl_plugin_panic_info(const char* message)
{
    size_t escaped_len = 0;
    size_t i;
    size_t need;
    char* out;

    for (i = 0; message[i] != '\0'; i++) {
        unsigned char ch = (unsigned char)message[i];
        if (ch == '"' || ch == '\\') {
            escaped_len += 2;
        } else if (ch < 0x20) {
            escaped_len += 6; /* \u00XX */
        } else {
            escaped_len += 1;
        }
    }
    need = sizeof("{\"__kcl_PanicInfo__\":\"\"}") - 1 + escaped_len;
    if (need + 1 > kcl_plugin_reply_cap) {
        char* grown = (char*)realloc(kcl_plugin_reply, need + 1);
        if (grown == NULL) {
            return "";
        }
        kcl_plugin_reply = grown;
        kcl_plugin_reply_cap = need + 1;
    }

    out = kcl_plugin_reply;
    memcpy(out, "{\"__kcl_PanicInfo__\":\"", sizeof("{\"__kcl_PanicInfo__\":\"") - 1);
    out += sizeof("{\"__kcl_PanicInfo__\":\"") - 1;
    for (i = 0; message[i] != '\0'; i++) {
        unsigned char ch = (unsigned char)message[i];
        switch (ch) {
        case '"':
            *out++ = '\\';
            *out++ = '"';
            break;
        case '\\':
            *out++ = '\\';
            *out++ = '\\';
            break;
        case '\n':
            *out++ = '\\';
            *out++ = 'n';
            break;
        case '\r':
            *out++ = '\\';
            *out++ = 'r';
            break;
        case '\t':
            *out++ = '\\';
            *out++ = 't';
            break;
        default:
            if (ch < 0x20) {
                sprintf(out, "\\u%04x", ch);
                out += 6;
            } else {
                *out++ = (char)ch;
            }
            break;
        }
    }
    *out++ = '"';
    *out++ = '}';
    *out = '\0';
    return kcl_plugin_reply;
}

static struct KclPluginEntry* kcl_plugin_find(const char* absolute_name)
{
    size_t i;
    for (i = 0; i < kcl_plugin_registry_len; i++) {
        if (strcmp(kcl_plugin_registry[i].name, absolute_name) == 0) {
            return &kcl_plugin_registry[i];
        }
    }
    return NULL;
}

bool kcl_plugin_register(const char* plugin_name, const char* method_name, KclPluginMethod fn)
{
    char absolute[KCL_PLUGIN_NAME_MAX];
    struct KclPluginEntry* entry;
    int written;

    if (plugin_name == NULL || method_name == NULL || fn == NULL) {
        return false;
    }
    if (plugin_name[0] == '\0' || method_name[0] == '\0') {
        return false;
    }
    written = snprintf(absolute, sizeof(absolute), KCL_PLUGIN_PREFIX "%s.%s", plugin_name, method_name);
    if (written < 0 || (size_t)written >= sizeof(absolute)) {
        return false;
    }

    entry = kcl_plugin_find(absolute);
    if (entry == NULL) {
        if (kcl_plugin_registry_len >= KCL_PLUGIN_MAX_METHODS) {
            return false;
        }
        entry = &kcl_plugin_registry[kcl_plugin_registry_len++];
        strcpy(entry->name, absolute);
    }
    entry->fn = fn;

    /* Bind on first registration, mirroring the other bindings where the
     * plugin agent is forwarded on every call by default. */
    if (kcl_plugin_service == 0) {
        kcl_plugin_service = kcl_service_new((uint64_t)(uintptr_t)kcl_plugin_method_agent);
    }
    return kcl_plugin_service != 0;
}

bool kcl_plugin_registered(const char* plugin_name, const char* method_name)
{
    char absolute[KCL_PLUGIN_NAME_MAX];
    int written;

    if (plugin_name == NULL || method_name == NULL) {
        return false;
    }
    written = snprintf(absolute, sizeof(absolute), KCL_PLUGIN_PREFIX "%s.%s", plugin_name, method_name);
    if (written < 0 || (size_t)written >= sizeof(absolute)) {
        return false;
    }
    return kcl_plugin_find(absolute) != NULL;
}

void kcl_plugin_disable(void)
{
    if (kcl_plugin_service != 0) {
        kcl_service_delete(kcl_plugin_service);
        kcl_plugin_service = 0;
    }
    kcl_plugin_registry_len = 0;
    free(kcl_plugin_reply);
    kcl_plugin_reply = NULL;
    kcl_plugin_reply_cap = 0;
}

/* Looked up weakly by `kcl_call` in kcl_lib.h; resolves to NULL when the
 * plugin shim is not linked in, which keeps the stateless path in place. */
KclServiceHandle kcl_plugin_service_handle(void)
{
    return kcl_plugin_service;
}

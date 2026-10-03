/*
 * plugin_api.c — KCL plugin support for the C binding.
 *
 * Registers host functions under `kcl_plugin.<plugin>.<method>`, runs KCL
 * that calls them, and checks the round trip. Mirrors the plugin tests in the
 * other bindings (Go `go/plugin`, Python `tests/plugin_test.py`, .NET
 * `KclLib.Tests/PluginTest.cs`, Node.js `__test__/plugin.spec.mjs`).
 *
 * Build:
 *   $ make examples
 *   $ ./examples/plugin_api
 */

#include <stdio.h>
#include <string.h>

#include "kcl_lib.h"
#include "kcl_lib_plugin.h"

static uint8_t g_exec_buffer[BUFFER_SIZE];
static uint8_t g_exec_result_buffer[BUFFER_SIZE];
static uint8_t g_exec_yaml_buffer[BUFFER_SIZE] = { 0 };
static uint8_t g_exec_err_buffer[BUFFER_SIZE] = { 0 };

/* The plugin author receives the arguments as raw JSON and returns a
 * JSON-encoded result. No JSON helper is needed for a method that ignores its
 * arguments, which is the case here. */
static const char* strings_join(const char* method, const char* args_json, const char* kwargs_json)
{
    (void)method;
    (void)args_json;
    (void)kwargs_json;
    return "\"KCL.KCL.123\"";
}

/* Echoes its arguments back, so the test can see exactly what the runtime
 * hands a plugin method. */
static const char* strings_args(const char* method, const char* args_json, const char* kwargs_json)
{
    static char reply[4096];
    (void)method;
    snprintf(reply, sizeof(reply), "{\"args\":%s,\"kwargs\":%s}", args_json[0] ? args_json : "null",
             kwargs_json[0] ? kwargs_json : "null");
    return reply;
}

static int failures = 0;

static void check(bool cond, const char* what)
{
    if (!cond) {
        fprintf(stderr, "FAIL: %s\n", what);
        failures++;
    } else {
        printf("ok: %s\n", what);
    }
}

/* Evaluate `code` and return its YAML output, or NULL on failure. Goes through
 * `kcl_call`, so it takes the plugin-bound handle once a method is
 * registered. */
static const char* exec(const char* code)
{
    ExecProgramArgs args = ExecProgramArgs_init_zero;
    ExecProgramResult result = ExecProgramResult_init_default;
    struct Buffer code_buf = { .buffer = code, .len = strlen(code) };
    struct Buffer* codes[] = { &code_buf };
    struct RepeatedString strs = { .repeated = &codes[0], .index = 0, .max_size = 1 };
    pb_ostream_t ostream;
    pb_istream_t istream;
    size_t message_length;
    size_t result_length;

    g_exec_yaml_buffer[0] = '\0';
    g_exec_err_buffer[0] = '\0';

    args.k_code_list.funcs.encode = encode_str_list;
    args.k_code_list.arg = &strs;

    ostream = pb_ostream_from_buffer(g_exec_buffer, sizeof(g_exec_buffer));
    if (!pb_encode(&ostream, ExecProgramArgs_fields, &args)) {
        fprintf(stderr, "encoding ExecProgramArgs failed: %s\n", PB_GET_ERROR(&ostream));
        return NULL;
    }
    message_length = ostream.bytes_written;

    result_length = kcl_call("KclService.ExecProgram", g_exec_buffer, message_length, g_exec_result_buffer);
    if (check_error_prefix(g_exec_result_buffer)) {
        fprintf(stderr, "exec failed: %s\n", (const char*)g_exec_result_buffer);
        return NULL;
    }

    istream = pb_istream_from_buffer(g_exec_result_buffer, result_length);
    result.yaml_result.funcs.decode = decode_string;
    result.yaml_result.arg = g_exec_yaml_buffer;
    if (!pb_decode(&istream, ExecProgramResult_fields, &result)) {
        fprintf(stderr, "decoding ExecProgramResult failed: %s\n", PB_GET_ERROR(&istream));
        return NULL;
    }
    return (const char*)g_exec_yaml_buffer;
}

int main()
{
    const char* yaml;

    /* Before registering anything the binding takes the stateless
     * call_native path and no plugin is reachable. */
    check(!kcl_plugin_registered("strings", "join"),
        "nothing is registered before kcl_plugin_register");

    check(kcl_plugin_register("strings", "join", strings_join),
        "kcl_plugin_register(strings.join)");
    check(kcl_plugin_register("strings", "args", strings_args),
        "kcl_plugin_register(strings.args)");
    check(kcl_plugin_registered("strings", "join"), "strings.join is registered");
    check(!kcl_plugin_registered("strings", "missing"), "unregistered method reports false");

    /* KCL code calling into the host. The runtime resolves `strings.join` to
     * the agent as `kcl_plugin.strings.join`, which is what the registry
     * stores. */
    yaml = exec("import kcl_plugin.strings\n"
                "result = strings.join(\"KCL\", \"KCL\", 123)\n");
    if (yaml != NULL) {
        printf("join ->\n%s", yaml);
        check(strstr(yaml, "KCL.KCL.123") != NULL, "plugin result reaches the KCL program");
    } else {
        check(false, "join evaluation");
    }

    /* Positional and keyword arguments arrive as JSON. The runtime parses the
     * plugin's reply, so the JSON array/object shows up in the YAML output as
     * a list item and a mapping entry respectively. */
    yaml = exec("import kcl_plugin.strings\n"
                "result = strings.args(\"a\", b = 2)\n");
    if (yaml != NULL) {
        printf("args ->\n%s", yaml);
        check(strstr(yaml, "- a") != NULL, "positional args arrive as a JSON array");
        check(strstr(yaml, "b: 2") != NULL, "keyword args arrive as a JSON object");
    } else {
        check(false, "args evaluation");
    }

    /* An unknown method is reported the way the other bindings report it: a
     * PanicInfo object rather than a native crash. */
    yaml = exec("import kcl_plugin.strings\n"
                "result = strings.nope()\n");
    check(yaml != NULL, "unknown plugin method does not crash the runtime");
    if (yaml != NULL) {
        printf("unknown ->\n%s", yaml);
    }

    /* Disabling restores the stateless path and empties the registry. */
    kcl_plugin_disable();
    check(!kcl_plugin_registered("strings", "join"), "kcl_plugin_disable clears the registry");
    yaml = exec("a = 1\n");
    check(yaml != NULL && strstr(yaml, "a: 1") != NULL, "evaluation still works after disabling");

    if (failures == 0) {
        printf("OK: C plugin example passed\n");
    }
    return failures == 0 ? 0 : 1;
}

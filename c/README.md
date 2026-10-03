# KCL Artifact Library for C

The C binding for the [KCL](https://kcl-lang.io/) artifact library. It
links against the same shared library (`libkcl_lib_c.so`) as the other
language bindings and exposes every KCL service method either as a raw
protobuf encode/decode pair or through the typed wrappers in `kcl_lib.h`.

## Developing

**Prerequisites**

+ `make`
+ A C11-capable C compiler (`cc` / `gcc` / `clang`)
+ `cargo` (release build of the Rust dispatcher)

Build the static archive + shared library and the bundled example
binaries:

```shell
make           # builds cargo release + lib/libkcl_lib_c.a
make examples  # builds every example/*.c into ./examples/
make clean     # removes build artefacts
```

Run a single example from the `c/` directory so the relative
`./test_data/...` paths resolve:

```shell
./examples/exec_api
```

## Formatting

```shell
make fmt   # cargo fmt + clang-format (WebKit) across .c/.cpp/.h
```

## Examples

Every example under `examples/` is a self-contained C program that
calls one wrapper from `kcl_lib.h`. Run `make examples` and then invoke
the matching binary from the `c/` directory.

| Binary                          | Wrapper                  | Fixture                      |
|---------------------------------|--------------------------|------------------------------|
| `ast_alignment`                 | raw protobuf             | `test_data/ast_alignment/`   |
| `ast_contract`                  | `kcl_ast_parse_module`   | `../testdata/ast/alignment.json` |
| `exec_api`                      | `kcl_exec_program`       | `test_data/schema.k`         |
| `exec_api_format`               | `kcl_exec_program`       | (round-trip format/sourcemap)|
| `exec_api_format_runtime`       | `kcl_exec_program`       | (runtime sourcemap)          |
| `format_path_api`               | `kcl_format_path`        | `test_data/format_api_tmp.k` |
| `format_test_report_api`        | `kcl_test` / `kcl_format_test_report` | `test_data/testing_report/` |
| `get_schema_type_mapping_api`   | `kcl_get_schema_type_mapping` | `test_data/schema_ty/` |
| `get_schema_type_mapping_under_path_api` | `kcl_get_schema_type_mapping_under_path` | `test_data/schema_ty/` |
| `list_method_api`               | `kcl_list_method`        | —                            |
| `list_options_api`              | `kcl_list_options`       | `test_data/options.k`        |
| `list_variables_api`            | `kcl_list_variables`     | `test_data/variables.k`      |
| `load_package_api`              | `kcl_load_package`       | `test_data/schema.k`         |
| `load_settings_files_api`       | `kcl_load_settings_files`| `test_data/settings/`        |
| `override_file_api`             | `kcl_override_file`      | (in-place temp file)         |
| `ping_api`                      | `kcl_ping`               | —                            |
| `rename_api`                    | `kcl_rename`             | `test_data/rename/`          |
| `rename_code_api`               | `kcl_rename_code`        | —                            |
| `run_once`                      | `kcl_run_code` / `kcl_validate_code` | (inline snippets) |
| `test_api`                      | `kcl_test`               | `test_data/testing/`         |
| `update_dependencies_api`       | `kcl_update_dependencies`| —                            |
| `validate_api`                  | `kcl_validate_code`      | (inline schema snippet)      |

### Quick recipes

+ ExecProgram

```c
#include <kcl_lib.h>

int main()
{
    static char yaml[BUFFER_SIZE];
    static char exec_err[BUFFER_SIZE];
    const char* files[] = { "./test_data/schema.k" };
    if (kcl_exec_program(files, 1, yaml, sizeof(yaml),
                         exec_err, sizeof(exec_err))) {
        printf("%s\n", yaml);
    }
    return 0;
}
```

```shell
./examples/exec_api
```

+ ValidateCode

```c
#include <kcl_lib.h>

int main()
{
    char validate_err[BUFFER_SIZE] = { 0 };
    const char* code = "schema Person:\n"
                       "    name: str\n"
                       "    age: int\n"
                       "    check:\n"
                       "        0 < age < 120\n";
    if (kcl_validate_code(code, "{\"name\": \"Alice\", \"age\": 10}",
                          validate_err, sizeof(validate_err))) {
        printf("Data is valid\n");
    } else {
        printf("Data is invalid: %s\n", validate_err);
    }
    return 0;
}
```

```shell
./examples/validate_api
```

## Typed API

`kcl_lib.h` exposes one wrapper per KCL service method. Wrappers that
return a single scalar / string take an output buffer plus its size;
wrappers that return a typed list take a fixed-size array plus a count
out-parameter. All wrappers return `true` on success and `false` on
failure — on failure a diagnostic is copied into `err_out` when one is
supplied.

| Wrapper                              | Purpose                                                                 |
|--------------------------------------|-------------------------------------------------------------------------|
| `kcl_ping`                           | Round-trip a string through `KclService.Ping`                          |
| `kcl_get_version`                    | Fill a `struct KclVersion` from `KclService.GetVersion`                 |
| `kcl_exec_program`                   | Compile + evaluate files into YAML/JSON                                |
| `kcl_run_code`                       | Compile + evaluate a single in-memory code snippet into YAML           |
| `kcl_validate_code`                  | Validate a code snippet against optional data                           |
| `kcl_format_code`                    | Format an in-memory KCL snippet                                         |
| `kcl_format_path`                    | Format files on disk (`dry_run` available)                              |
| `kcl_lint_path`                      | Lint a list of files                                                    |
| `kcl_parse_file` / `kcl_parse_program` | Render a file or set of files to AST JSON                             |
| `kcl_list_method`                    | Enumerate every method on `KclService`                                  |
| `kcl_list_options`                   | Inspect the `option(...)` declarations in files                         |
| `kcl_list_variables`                 | Extract every declared variable (with op symbol & parse errors)         |
| `kcl_load_package`                   | Parse a package into program / paths / scopes / symbol / fqn maps       |
| `kcl_load_settings_files`            | Merge `kcl.yaml` settings + CLI options into a `KclLoadSettingsFilesResult` |
| `kcl_override_file`                  | Apply a CLI-style override spec to a file on disk                       |
| `kcl_get_schema_type_mapping`        | Schema → KCL type map for an entire work dir                            |
| `kcl_get_schema_type_mapping_under_path` | Schema → KCL type map scoped to a sub-path                          |
| `kcl_rename`                         | Rename a symbol across files on disk                                    |
| `kcl_rename_code`                    | Rename a symbol inside an in-memory code snippet                        |
| `kcl_test`                           | Run the `*_test.k` test cases under a work dir                          |
| `kcl_format_test_report`             | Render a test case list as a `PrettyReporter`-style report              |
| `kcl_update_dependencies`            | Refresh an external-package manifest (`vendor` mode supported)         |

### Example: wiring multiple wrappers

```c
#include <kcl_lib.h>

int main()
{
    // Ping
    char ping_value[128] = { 0 };
    if (kcl_ping("hello", ping_value, sizeof(ping_value))) {
        printf("%s\n", ping_value);
    }

    // GetVersion
    struct KclVersion version = { 0 };
    if (kcl_get_version(&version)) {
        printf("%s\n", version.version);
    }

    // ExecProgram
    static char yaml[BUFFER_SIZE];
    static char exec_err[BUFFER_SIZE];
    const char* files[] = { "./test_data/schema.k" };
    if (kcl_exec_program(files, 1, yaml, sizeof(yaml),
                         exec_err, sizeof(exec_err))) {
        printf("%s\n", yaml);
    }

    // ValidateCode
    char validate_err[BUFFER_SIZE] = { 0 };
    const char* code = "schema Person:\n    name: str\n    age: int\n    check:\n        0 < age < 120\n";
    if (kcl_validate_code(code, "{\"name\": \"Alice\", \"age\": 10}",
                          validate_err, sizeof(validate_err))) {
        printf("Data is valid\n");
    }

    // FormatCode
    static char formatted[BUFFER_SIZE];
    if (kcl_format_code("a = 1", formatted, sizeof(formatted))) {
        printf("%s\n", formatted);
    }

    // LintPath
    static char lint_results[BUFFER_SIZE];
    const char* lint_paths[] = { "./test_data/schema.k" };
    if (kcl_lint_path(lint_paths, 1, lint_results, sizeof(lint_results))) {
        printf("%s\n", lint_results);
    }

    // ListOptions
    static struct KclOptionHelp options[16] = { 0 };
    size_t option_count = 0;
    char list_err[BUFFER_SIZE] = { 0 };
    const char* opt_files[] = { "./test_data/options.k" };
    if (kcl_list_options(opt_files, 1, options, 16, &option_count,
                         list_err, sizeof(list_err))) {
        for (size_t i = 0; i < option_count; ++i) {
            printf("  %s = %s\n", options[i].name, options[i].default_value);
        }
    }

    return 0;
}
```

## Plugins

A plugin exposes host functions to KCL code. The program imports the plugin
module and then calls the method unqualified:

```kcl
import kcl_plugin.strings

result = strings.join("KCL", "KCL", 123)
```

The runtime resolves that to a `kcl_plugin.strings.join` call into the host,
so a plugin author only has to register `("strings", "join")`.

```c
#include "kcl_lib.h"
#include "kcl_lib_plugin.h"

/* Arguments arrive as raw JSON and the result is JSON-encoded. Returning NULL
 * (or "") yields an empty result. */
static const char* strings_join(const char* method,
                                const char* args_json,
                                const char* kwargs_json)
{
    return "\"KCL.KCL.123\"";
}

int main(void)
{
    kcl_plugin_register("strings", "join", strings_join);
    /* ... run KCL here ... */
    kcl_plugin_disable();
    return 0;
}
```

| Function | Purpose |
| --- | --- |
| `kcl_plugin_register(plugin, method, fn)` | Adds or replaces one method. Binds the plugin agent on the first call. |
| `kcl_plugin_registered(plugin, method)` | Whether the method is currently in the registry. |
| `kcl_plugin_disable()` | Unbinds the agent, empties the registry, and returns the binding to the stateless `call_native` path. |

Register methods at start-up — like Go's `init()` — before evaluating any
KCL. Registering later is harmless, but nothing before the first
registration can reach the plugin.

Two properties are worth calling out:

* **No JSON dependency.** Arguments and results are plain JSON strings, so a
  method that ignores its arguments needs no parser. A method that inspects
  them can add whichever library it already uses.
* **Errors are data, not crashes.** Calling a method that was never
  registered yields a `{"__kcl_PanicInfo__": "..."}` object, matching what
  Go's `plugin.JSONError` and Python's `_call_py_method` return, so an
  unknown method surfaces as a KCL-level diagnostic.

Under the hood, registration creates a service handle
(`kcl_service_new(agent)`) and `kcl_call` dispatches through it. The
`kcl_plugin_service_handle()` symbol is declared weak in `kcl_ffi.h`, so
builds that leave `kcl_lib_plugin.c` out still link and keep using the
stateless `call_native` entry point.

See `examples/plugin_api.c` for the round trip, including positional vs.
keyword arguments and the unknown-method path.

## Raw protobuf API

If a service method is not wrapped yet (or you need to bypass the typed
helpers), you can encode the `*Args` message yourself, dispatch it via
`call_native`, and decode the matching `*Result`. The `ExecProgram` and
`ValidateCode` snippets under [Quick recipes](#quick-recipes) show this
shape.

All KCL service replies are prefixed with `ERROR:` on failure — the
helper `check_error_prefix(result_buffer)` in `kcl_lib.h` tests for
that prefix so the caller can print the diagnostic verbatim.

## Linking from your own project

The build produces two artefacts under `c/`:

* `lib/libkcl_lib_c.a` — the static archive containing the protobuf
  runtime (`pb_*`), the generated `spec.pb.c` bindings, the typed
  wrappers in `kcl_lib_msgs.c`, and the plugin registry in
  `kcl_lib_plugin.c`.
* `target/release/libkcl_lib_c.so` — the Rust dispatcher that the
  typed wrappers ultimately call into via `kcl_ffi.h`'s `call_native`.

When compiling your own program, link both:

```shell
cc -I c/include   your_program.c   \
    -L c/target/release -Wl,-rpath,$PWD/c/target/release -lkcl_lib_c \
    c/lib/libkcl_lib_c.a
```

The `target/release` directory is rebuilt by `make cargo` whenever the
Rust source changes; `make examples` regenerates `lib/libkcl_lib_c.a`
and every example binary.
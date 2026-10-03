# KCL Artifact Library for C++

This repo is under development, PRs welcome!

## How to Use

### CMake

You can use FetchContent to add KCL C++ Lib to your project.

```shell
FetchContent_Declare(
  kcl-lib
  GIT_REPOSITORY https://github.com/kcl-lang/lib.git
  GIT_TAG        v0.13.0
  SOURCE_SUBDIR  cpp
)
FetchContent_MakeAvailable(kcl-lib)
```

Or you can download the source code and add it to your project.

```shell
mkdir third_party
cd third_party
git clone https://github.com/kcl-lang/lib.git
git checkout v0.13.0
```

```shell
add_subdirectory(third_party/lib/cpp)
```

```shell
target_link_libraries(your_target kcl-lib-cpp)
```

## Developing

**Prerequisites**

+ CMake >= 3.10
+ C++ Compiler with C++17 Support
+ Cargo

If you build on macos, you can set the environment to prevent link errors.

```shell
# Set cargo build target on macos
export MACOSX_DEPLOYMENT_TARGET='10.13'
```

Use cmake to build the whole project.

```shell
mkdir -p build
cd build
cmake ..
make -j8
```

### Running the tests

The assertion-based test suites in `tests/test_api.cpp` and `tests/test_ast.cpp`
(plain `CHECK` macro, no external dependencies) are built and registered with
ctest only when `KCL_LIB_ENABLE_TESTING` is on:

```shell
cmake -B build -DKCL_LIB_ENABLE_TESTING=ON
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

`test_api.cpp` covers the core RPCs (get_version, ping, exec_program,
parse_file, parse_program, format_code, lint_path, validate_code, list_options)
plus the Test RPC with line coverage enabled. `test_ast.cpp` is the contract
suite for the typed AST in [`kcl_ast.hpp`](#kcl_asthpp--a-typed-ast-in-c): it
decodes the shared golden capture at `../testdata/ast/alignment.json`, walks
every tag in it against the typed tree, and parses a live fixture through the
cxx bridge.

ctest also runs the `facade` example twice — once with the default JSON backend
and once against `facade_bundled_json`, which forces the header's bundled parser
via `-DKCL_LIB_NO_NLOHMANN` — so both backends stay covered.

## Examples

### facade

High-level facade (`kcl_facade.hpp`) mirroring kcl-go's `pkg/kcl`: `Kcl::run` /
`Kcl::run_files` take code/files plus an `Options` bag, throw `kcl_lib::KclError`
on failures, and return a `KclResult` with raw `yaml_result`/`json_result` access
plus dotted-path `get("a.b.c")` navigation. Options include overrides, selectors,
external packages, settings files, `-D` args and the `_type` rewriting hook
(`include_schema_type_path` shortens `_type` to the schema name unless
`full_type_path` is set).

`KclResult::get` returns a `kcl_lib::JsonValue`, which is
`nlohmann::ordered_json` when the header is available and a bundled parser
otherwise. CMake picks nlohmann/json up through `find_package(nlohmann_json)`
when it is installed, and the header falls back to its own parser when it is
not, so the build never requires the dependency. Code that must build either
way should use the portable accessors — `getInt` / `getString` / `getFloat` /
`getBool` / `getArray` / `getObject` — rather than the raw `get` value.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_facade.hpp"
#include <iostream>

int main()
{
    // In-memory code + dotted-path access.
    auto result = kcl_lib::Kcl::run(
        "name = \"kcl\"\n"
        "server = {host = \"localhost\", port = 8080}\n");
    std::cout << result.getInt("server.port") << std::endl; // 8080

    // Files + overrides.
    auto files = kcl_lib::Kcl::run_files({ "../test_data/schema.k" },
        kcl_lib::Options {
            .overrides = { "app.replicas=5" },
        });

    // Schema type paths: `_type` is rewritten to "AppConfig" by default;
    // pass full_type_path = true to keep "pkg.path.AppConfig".
    auto typed = kcl_lib::Kcl::run_files({ "../test_data/schema.k" },
        kcl_lib::Options {
            .include_schema_type_path = true,
        });

    // Validation.
    bool ok = kcl_lib::Kcl::validate(
        "schema Person:\n    name: str\n    age: int\n",
        "{\"name\": \"Alice\", \"age\": 10}",
        "json");
    return 0;
}
```

Run the facade example.

```shell
./facade
```

To check the bundled JSON parser instead of nlohmann/json:

```shell
./facade_bundled_json
```

</p>
</details>

### exec_program

Execute KCL file with arguments and return the JSON/YAML result.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ExecProgramArgs {
        .k_filename_list = { "../test_data/schema.k" },
    };
    auto result = kcl_lib::exec_program(args);
    std::cout << result.yaml_result.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### parse_file

Parse KCL single file to Module AST JSON string with import dependencies and parse errors.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ParseFileArgs {
        .path = "../test_data/schema.k",
    };
    auto result = kcl_lib::parse_file(args);
    std::cout << result.deps.size() << std::endl;
    std::cout << result.errors.size() << std::endl;
    std::cout << result.ast_json.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### parse_program

Parse KCL program with entry files and return the AST JSON string.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ParseProgramArgs {
        .paths = { "../test_data/schema.k" },
    };
    auto result = kcl_lib::parse_program(args);
    std::cout << result.paths[0].c_str() << std::endl;
    std::cout << result.errors.size() << std::endl;
    std::cout << result.ast_json.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### ast

`kcl_lib_ast.hpp` is a thin RAII wrapper over the typed AST declared in
the C binding's `c/include/kcl_lib_ast.h` — that header is the single
source of truth for both bindings. `kcl::ast::parse_module` and
`kcl::ast::parse_program` return a `unique_ptr` carrying the matching
`kcl_module_free` / `kcl_program_free` deleter, so the whole arena is
released when the pointer goes out of scope; `.get()` hands back the
underlying C struct for callers who want to walk the AST directly.

The wire shape follows `kcl-lang/kcl crates/ast/src/ast.rs`:
`Stmt` and `Expr` are `#[serde(tag = "type")]` with the newtype payload
*flattened into the same object*, `Type` is `#[serde(tag = "type",
content = "value")]` (so `Any` is a bare `{"type":"Any"}` with no
`value`), and fields declared as plain structs upstream —
`SchemaStmt.decorators`, `DictComp.entry`, `Target.paths` — carry no
tag even inside a tagged node.

Two examples cover it, and they check different things:

- `ast_alignment` parses a live fixture through `parse_file`, proving
  the parser emits something the loader accepts.
- `ast_contract` decodes the shared golden capture at
  `testdata/ast/alignment.json` and asserts that no tag anywhere in the
  document falls through as unknown. A tag the decoder does not
  recognise becomes a zero-valued struct rather than an error, so
  field-by-field assertions on a handful of nodes would sail through a
  decoder that resolves nothing at all.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include "kcl_lib_ast.hpp"
#include <iostream>

int main()
{
    auto parsed = kcl_lib::parse_file({ .path = "../test_data/schema.k" });
    auto module = kcl::ast::parse_module(parsed.ast_json.c_str());
    for (size_t i = 0; i < module->body.count; i++) {
        auto* stmt = static_cast<kcl_stmt_t*>(module->body.items[i].node);
        if (stmt->kind == KCL_STMT_KIND_SCHEMA)
            std::cout << stmt->u.schema_stmt.name.node << "\n";
    }
    // `module` owns the whole arena; nothing else to free.
}
```

</p>
</details>

#### `kcl_ast.hpp` — a typed AST in C++

`kcl_lib_ast.hpp` above is a C-struct wrapper, useful when you want the `c/`
binding's arena and nothing else. `kcl_ast.hpp` is a second, independent front
end over the *same* wire format, and it is the one to reach for when a caller
wants typed objects rather than tagged unions.

```cpp
#include "kcl_ast.hpp"

kcl::ast::Module m = kcl::ast::Module::from_json(ast_json, "main.k");
for (const kcl::ast::SchemaStmt* s : m.schemas()) {
    std::cout << s->name->node << "\n";
}
```

It is header-only, needs nothing but a C++17 toolchain, and does not pull in
the cxx bridge — `kcl_ast_json.hpp`, a small recursive-descent JSON reader, is
the whole of its dependency list. (`kcl_facade.hpp` has its own
nlohmann-aware DOM, but reusing that would drag the bridge in behind it.)

The class names are the Java binding's
(`java/src/main/java/com/kcl/ast/`), so a table read from one binding is
readable in the next: `Compare`, `ListComp`, `DictComp`, `NumberLit`,
`StringLit`, `NameConstantLit`, `JoinedString`, `FormattedValue`, `Subscript`,
`SchemaExpr`, `CallExpr`, `CheckExpr`, `SchemaConfig`, `Decorator`,
`SchemaAttr`, `AnyType`, `BasicType`, `NamedType`, `ListType`, `DictType`,
`UnionType`, `LiteralType`, `FunctionType`, `Module`, `Pos`, `Node`.
`CheckExpr` and `CompClause` are `Expr` subclasses *and* plain payloads, so
one class serves the tagged variant and the untagged list it also appears in.
`CallExpr`/`Decorator` and `SchemaExpr`/`SchemaConfig` are four distinct
classes for two wire shapes, the same split Java draws.

An unknown `type` tag **raises** `kcl::ast::AstError` rather than degrading, so
a mistyped tag is a loud failure instead of a zero-valued node. That is a
deliberate divergence from the Ruby binding, which degrades to `Unknown*` for
forward compatibility with a newer parser.

Narrow with the free templates:

```cpp
if (auto* cmp = kcl::ast::as<kcl::ast::Compare>(expr_node)) { /* ... */ }
if (kcl::ast::is<kcl::ast::Compare>(expr_node)) { /* ... */ }
```

`tests/test_ast.cpp` (ctest target `kcl_ast_tests`) is the contract suite: it
decodes the shared golden capture, walks every tag in it against the typed
tree, and parses a live fixture through the bridge.

### load_package

load_package provides users with the ability to parse KCL program and semantic model information including symbols, types, definitions, etc.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto parse_args = kcl_lib::ParseProgramArgs {
        .paths = { "../test_data/schema.k" },
    };
    auto args = kcl_lib::LoadPackageArgs {
        .resolve_ast = true,
    };
    args.parse_args = kcl_lib::OptionalParseProgramArgs {
        .has_value = true,
        .value = parse_args,
    };
    auto result = kcl_lib::load_package(args);
    std::cout << result.symbols[0].value.ty.value.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### list_variables

list_variables provides users with the ability to parse KCL program and get all variables by specs.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ListVariablesArgs {
        .files = { "../test_data/schema.k" },
    };
    auto result = kcl_lib::list_variables(args);
    std::cout << result.variables[0].value[0].value.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### list_options

list_options provides users with the ability to parse KCL program and get all option information.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ParseProgramArgs {
        .paths = { "../test_data/option/main.k" },
    };
    auto result = kcl_lib::list_options(args);
    std::cout << result.options[0].name.c_str() << std::endl;
    std::cout << result.options[1].name.c_str() << std::endl;
    std::cout << result.options[2].name.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### get_schema_type_mapping

Get schema type mapping defined in the program.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto exec_args = kcl_lib::ExecProgramArgs {
        .k_filename_list = { "../test_data/schema.k" },
    };
    auto args = kcl_lib::GetSchemaTypeMappingArgs();
    args.exec_args = kcl_lib::OptionalExecProgramArgs {
        .has_value = true,
        .value = exec_args,
    };
    auto result = kcl_lib::get_schema_type_mapping(args);
    std::cout << result.schema_type_mapping[0].key.c_str() << std::endl;
    std::cout << result.schema_type_mapping[0].value.properties[0].key.c_str() << std::endl;
    std::cout << result.schema_type_mapping[0].value.properties[0].value.ty.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### override_file

Override KCL file with arguments. See [https://www.kcl-lang.io/docs/user_docs/guides/automation](https://www.kcl-lang.io/docs/user_docs/guides/automation) for more override spec guide.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::OverrideFileArgs {
        .file = { "../test_data/override_file/main.k" },
        .specs = { "b.a=2" },
    };
    auto result = kcl_lib::override_file(args);
    std::cout << result.result << std::endl;
    std::cout << result.parse_errors.size() << std::endl;
    return 0;
}
```

</p>
</details>

### format_code

Format the code source.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::FormatCodeArgs {
        .source = "schema Person:\n"
                  "    name:     str\n"
                  "    age:     int\n"
                  "    check:\n"
                  "        0 <     age <     120\n",
    };
    auto result = kcl_lib::format_code(args);
    std::cout << result.formatted.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### format_path

Format KCL file or directory path contains KCL files and returns the changed file paths.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::FormatPathArgs {
        .path = "../test_data/format_path/test.k",
    };
    auto result = kcl_lib::format_path(args);
    std::cout << result.changed_paths.size() << std::endl;
    return 0;
}
```

</p>
</details>

### lint_path

Lint files and return error messages including errors and warnings.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::LintPathArgs {
        .paths = { "../test_data/lint_path/test-lint.k" }
    };
    auto result = kcl_lib::lint_path(args);
    std::cout << result.results[0].c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### validate_code

Validate code using schema and JSON/YAML data strings.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int validate(const char* code_str, const char* data_str)
{
    auto args = kcl_lib::ValidateCodeArgs {
        .code = code_str,
        .data = data_str,
    };
    auto result = kcl_lib::validate_code(args);
    std::cout << result.success << std::endl;
    std::cout << result.err_message.c_str() << std::endl;
    return 0;
}

int main()
{
    const char* code_str = "schema Person:\n"
                           "    name: str\n"
                           "    age: int\n"
                           "    check:\n"
                           "        0 < age < 120\n";
    const char* data_str = "{\"name\": \"Alice\", \"age\": 10}";
    const char* error_data_str = "{\"name\": \"Alice\", \"age\": 1110}";
    validate(code_str, data_str);
    validate(code_str, error_data_str);
    return 0;
}
```

Run the ValidateAPI example.

```shell
./validate_api
```

</p>
</details>

### rename

Rename all the occurrences of the target symbol in the files. This API will rewrite files if they contain symbols to be renamed. Return the file paths that got changed.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::RenameArgs {
        .package_root = "../test_data/rename",
        .symbol_path = "a",
        .file_paths = { "../test_data/rename/main.k" },
        .new_name = "a",
    };
    auto result = kcl_lib::rename(args);
    std::cout << result.changed_files[0].c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### rename_code

Rename all the occurrences of the target symbol and return the modified code if any code has been changed. This API won't rewrite files but return the changed code.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::RenameCodeArgs {
        .package_root = "/mock/path",
        .symbol_path = "a",
        .source_codes = { {
            .key = "/mock/path/main.k",
            .value = "a = 1\nb = a\nc = a",
        } },
        .new_name = "a2",
    };
    auto result = kcl_lib::rename_code(args);
    std::cout << result.changed_codes[0].value.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### test

Test KCL packages with test arguments.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::TestArgs {
        .pkg_list = { "../test_data/testing/..." },
    };
    auto result = kcl_lib::test(args);
    std::cout << result.info[0].name.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### load_settings_files

Load the setting file config defined in `kcl.yaml`

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::LoadSettingsFilesArgs {
        .work_dir = "../test_data/settings",
        .files = { "../test_data/settings/kcl.yaml" },
    };
    auto result = kcl_lib::load_settings_files(args);
    std::cout << result.kcl_cli_configs.value.files.size() << std::endl;
    std::cout << result.kcl_cli_configs.value.strict_range_check << std::endl;
    std::cout << result.kcl_options[0].key.c_str() << std::endl;
    std::cout << result.kcl_options[0].value.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### update_dependencies

Download and update dependencies defined in the `kcl.mod` file and return the external package name and location list.

<details><summary>Example</summary>
<p>

The content of `module/kcl.mod` is

```yaml
[package]
name = "mod_update"
edition = "0.0.1"
version = "0.0.1"

[dependencies]
helloworld = { oci = "oci://ghcr.io/kcl-lang/helloworld", tag = "0.1.0" }
flask = { git = "https://github.com/kcl-lang/flask-demo-kcl-manifests", commit = "ade147b" }
```

C++ Code

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::UpdateDependenciesArgs {
        .manifest_path = "../test_data/update_dependencies",
    };
    auto result = kcl_lib::update_dependencies(args);
    std::cout << result.external_pkgs[0].pkg_name.c_str() << std::endl;
    std::cout << result.external_pkgs[1].pkg_name.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

Call `exec_program` with external dependencies

<details><summary>Example</summary>
<p>

The content of `module/kcl.mod` is

```yaml
[package]
name = "mod_update"
edition = "0.0.1"
version = "0.0.1"

[dependencies]
helloworld = { oci = "oci://ghcr.io/kcl-lang/helloworld", tag = "0.1.0" }
flask = { git = "https://github.com/kcl-lang/flask-demo-kcl-manifests", commit = "ade147b" }
```

The content of `module/main.k` is

```cpp
import helloworld
import flask

a = helloworld.The_first_kcl_program
```

C++ Code

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::UpdateDependenciesArgs {
        .manifest_path = "../test_data/update_dependencies",
    };
    auto result = kcl_lib::update_dependencies(args);
    auto exec_args = kcl_lib::ExecProgramArgs {
        .k_filename_list = { "../test_data/update_dependencies/main.k" },
        .external_pkgs = result.external_pkgs,
    };
    auto exec_result = kcl_lib::exec_program(exec_args);
    std::cout << exec_result.yaml_result.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### get_version

Return the KCL service version information.

<details><summary>Example</summary>
<p>

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto result = kcl_lib::get_version();
    std::cout << result.checksum.c_str() << std::endl;
    std::cout << result.git_sha.c_str() << std::endl;
    std::cout << result.version.c_str() << std::endl;
    std::cout << result.version_info.c_str() << std::endl;
    return 0;
}
```

</p>
</details>

### Plugins

A plugin exposes C++ functions to KCL code. The program imports the plugin
module and then calls the method unqualified:

```kcl
import kcl_plugin.strings

result = strings.join("KCL", "KCL", 123)
```

The runtime resolves that to a `kcl_plugin.strings.join` call into the host,
so `register_plugin` only ever sees the two halves.

```cpp
#include "kcl_facade.hpp"
#include "kcl_plugin.hpp"
#include <iostream>

int main()
{
    kcl_lib::register_plugin("strings", "join",
        [](const std::string& args, const std::string& kwargs) {
            // args is `["KCL", "KCL", 123]`, kwargs is `{}`; return JSON.
            return std::string("\"KCL.KCL.123\"");
        });

    auto result = kcl_lib::Kcl::run(
        "import kcl_plugin.strings\n"
        "result = strings.join(\"KCL\", \"KCL\", 123)\n");
    std::cout << result.getString("result") << std::endl;  // KCL.KCL.123
    return 0;
}
```

| Function | Purpose |
| --- | --- |
| `kcl_lib::register_plugin(plugin, method, fn)` | Adds or replaces one method. |
| `kcl_lib::plugin_registered(plugin, method)` | Whether a name resolves. |
| `kcl_lib::disable_plugins()` | Empties the registry and unbinds the runtime. |
| `kcl_lib::has_plugins()` | Whether anything is registered. |

Register methods at start-up — nothing evaluated before the first
registration can reach the plugin. A method may throw: the exception is
caught at the agent boundary and reported to the runtime, so it never
unwinds into the Rust frames underneath.

Two properties are worth calling out:

+ **No JSON dependency.** Arguments arrive as raw JSON strings and the result
  must be JSON-encoded, so a method that ignores its arguments needs no
  parser at all. One that inspects them can use `kcl_lib::detail::parse_json_stream`.
+ **Errors are data, not crashes.** Calling a method that was never
  registered — or one that threw — yields a
  `{"__kcl_PanicInfo__": "..."}` object, matching what Go's
  `plugin.JSONError` and Python's `_call_py_method` return, so it surfaces
  through the normal `err_message` path rather than as a native crash.

Under the hood, `register_plugin` hands the agent to the Rust shim via
`kcl_lib::set_plugin_agent`, which stores it in the `KclServiceImpl` that
every RPC builds. With nothing registered that field is `0`, which is exactly
the stateless service the binding used before.

The example is in [`examples/plugin_api.cpp`](examples/plugin_api.cpp):

```console
$ ./plugin_api
join -> result=KCL.KCL.123
args -> result:
  args:
  - a
  kwargs:
    b: 2
unknown method -> EvaluationError
---> File ./__main__.k:2: invalid method: kcl_plugin.strings.nope is not found
OK: C++ plugin example passed
```

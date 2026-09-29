# KCL Artifact Library for Julia

> [!WARNING]
> This repo is under development, PRs welcome!

A Julia library for interacting with KCL (Kusion Configuration Language)
artifacts: run KCL programs, query schemas and options, format, lint, validate,
rename symbols, run KCL unit tests and manage module dependencies.

**Initial release:** this is the first version of the Julia binding (`0.13.0`,
matching the vendored `libkcl` ABI version). APIs follow the other KCL language
bindings; breaking changes will be noted in future releases.

Unlike most bindings in this repository, the Julia binding does **not** build
any Rust code. It `ccall`s the same prebuilt `libkcl` shared libraries that the
Go binding ships under [`go/lib`](../go/lib/), and talks to the native runtime
through the universal protobuf dispatcher (see [`c/include/kcl_ffi.h`](../c/include/kcl_ffi.h)).

## Installation

From the Julia REPL, add this repository (the package lives in the `julia/`
subdirectory):

```julia
using Pkg
Pkg.add(url="https://github.com/kcl-lang/lib.git", subdir="julia")
```

Requirements:

- **Julia** 1.6 or later (developed and tested on 1.13).
- **libkcl** prebuilt binary for your platform. Out of the box the package
  locates it in the repository layout (`go/lib/<platform>/libkcl.{dylib,so,dll}`).
  If you use the package outside this repository layout, point the
  `KCL_JL_LIB` environment variable at the shared library (or at a directory
  containing the platform subdirectory):

  ```julia
  ENV["KCL_JL_LIB"] = "/path/to/libkcl.dylib"
  ```

### Platforms

| OS      | Arch    | Directory          | Library       |
|---------|---------|--------------------|---------------|
| macOS   | arm64   | `darwin-arm64`     | `libkcl.dylib`|
| macOS   | x86_64  | `darwin-amd64`     | `libkcl.dylib`|
| Linux   | x86_64  | `linux-amd64`      | `libkcl.so`   |
| Linux   | arm64   | `linux-arm64`      | `libkcl.so`   |
| Windows | x86_64  | `windows-amd64`    | `libkcl.dll`  |
| Windows | arm64   | `windows-arm64`    | `libkcl.dll`  |

## Quickstart

```julia
using KclLib

# Execute a KCL file
result = exec_program(ExecProgramArgs(k_filename_list=["test_data/schema.k"]))
println(result.yaml_result)

# Execute inline KCL code
inline = exec_program(ExecProgramArgs(k_code_list=["alice = {age = 18}"]))
println(inline.json_result)
```

Message types such as `ExecProgramArgs` are protobuf structs generated from
[`spec/spec.proto`](../spec/spec.proto) and are exported directly from
`KclLib`; all fields are keyword arguments with proto3 defaults. They are also
available under the `KclLib.pb` module alias (e.g. `KclLib.pb.Symbol`, which
is not re-exported because it clashes with `Base.Symbol`).

Two proto field names are Julia keywords and are generated with a trailing
underscore: `KclType.type_` (the type name, e.g. `"int"`) and
`KclType.function_` (the optional function signature).

## Error Semantics

The native dispatcher prefixes every error reply with `ERROR:`; the binding
strips the prefix and raises a `KclError`:

```julia
try
    exec_program(ExecProgramArgs(k_filename_list=["file_not_found"]))
catch err
    @assert err isa KclError
    println(err.message)  # "Cannot find the kcl file, please check ..."
end
```

`exec_program` and `validate_code` are **not thread safe**, mirroring the spec.

## API Reference

Every wrapper below is a plain function (no object to instantiate) and is
equivalent to `call("KclService.<Method>", encoded_args)`. The raw escape
hatch `KclLib.call(name, bytes)` reaches any RPC — including future ones — by
name.

### ping

```julia
result = ping(PingArgs(value="Hello, KCL!"))
@assert result.value == "Hello, KCL!"
```

### get_version

```julia
result = get_version()
println(result.version_info)  # "Version: 0.13.0-...\nPlatform: ...\nGitCommit: ..."
```

### exec_program

```julia
result = exec_program(ExecProgramArgs(
    k_filename_list=["test_data/schema.k"],
    # k_code_list=["a = 1"],          # inline code instead of files
    # args=[Argument(name="env", value="prod")],
    # overrides=["app.replicas=3"],
    # sort_keys=true,
    # format="json",                   # or "yaml"; empty emits both
))
println(result.yaml_result)
```

### parse_program

```julia
result = parse_program(ParseProgramArgs(paths=["test_data/schema.k"]))
@assert isempty(result.errors)
println(result.ast_json)
```

### parse_file

```julia
result = parse_file(ParseFileArgs(path="test_data/schema.k"))
@assert isempty(result.deps) && isempty(result.errors)
```

### load_package

```julia
result = load_package(LoadPackageArgs(
    parse_args=ParseProgramArgs(paths=["test_data/schema.k"]),
    resolve_ast=true,
))
syms = collect(values(result.symbols))
@assert any(s -> s.ty.schema_name == "AppConfig", syms)
```

### list_options

```julia
result = list_options(ParseProgramArgs(paths=["test_data/option/main.k"]))
println([o.name for o in result.options])  # ["key1", "key2", "metadata-key"]
```

### list_variables

```julia
result = list_variables(ListVariablesArgs(files=["test_data/schema.k"]))
println(result.variables["app"].variables[1].value)  # "AppConfig {\n    replicas: 2\n}"
```

### override_file

```julia
result = override_file(OverrideFileArgs(
    file="main.k",
    specs=["b.a=2"],
))
@assert result.result && isempty(result.parse_errors)  # main.k rewritten in place
```

### get_schema_type_mapping

```julia
result = get_schema_type_mapping(GetSchemaTypeMappingArgs(
    exec_args=ExecProgramArgs(k_filename_list=["test_data/schema.k"]),
))
println(result.schema_type_mapping["app"].properties["replicas"].type_)  # "int"
```

### get_schema_type_mapping_under_path

```julia
result = get_schema_type_mapping_under_path(GetSchemaTypeMappingArgs(
    exec_args=ExecProgramArgs(k_filename_list=["."]),
))
for (pkg, schemas) in result.schema_type_mapping   # keyed by package name
    println(pkg, [s.schema_name for s in schemas.schema_type])
end
```

### format_code

```julia
result = format_code(FormatCodeArgs(source="a   =   1"))
println(String(result.formatted))  # "a = 1" — the field is proto `bytes`
```

### format_path

```julia
result = format_path(FormatPathArgs(path="test_data/format_path/test.k"))
println(result.changed_paths)
```

### lint_path

```julia
result = lint_path(LintPathArgs(paths=["test_data/lint_path/test-lint.k"]))
println(result.results)  # ["Module 'math' imported but unused"]
```

### validate_code

```julia
code = "schema Person:\n    name: str\n    age: int\n    check:\n        0 < age < 120\n"
result = validate_code(ValidateCodeArgs(
    code=code,
    data="{\"name\": \"Alice\", \"age\": 10}",
    format="json",
))
@assert result.success
```

### load_settings_files

```julia
result = load_settings_files(LoadSettingsFilesArgs(
    work_dir=".",
    files=["test_data/settings/kcl.yaml"],
))
@assert result.kcl_cli_configs.strict_range_check
```

### rename

```julia
result = rename(RenameArgs(
    package_root=".",
    symbol_path="a",
    file_paths=["main.k"],
    new_name="a2",
))
println(result.changed_files)  # [".../main.k"] — rewritten on disk
```

### rename_code

```julia
result = rename_code(RenameCodeArgs(
    package_root="/mock/path",
    symbol_path="a",
    source_codes=Dict("/mock/path/main.k" => "a = 1\nb = a"),
    new_name="a2",
))
println(result.changed_codes["/mock/path/main.k"])  # "a2 = 1\nb = a2"
```

### test

```julia
result = test(TestArgs(pkg_list=["test_data/testing/module/..."]))
@assert length(result.info) == 2
```

### update_dependencies

```julia
result = update_dependencies(UpdateDependenciesArgs(manifest_path="module"))
println([pkg.pkg_name for pkg in result.external_pkgs])
```

Note: pulling OCI dependencies (`oci://ghcr.io/...`) can be rate-limited on
CI; callers that need resilience should catch `KclError` and treat registry
errors as skippable, as the test suite does.

### list_method

```julia
result = list_method()
println(result.method_name_list)
```

Note: the prebuilt `libkcl` v0.13.0 binary predates the `BuiltinService`
registration and answers with an **empty** payload; the wrapper returns an
empty `method_name_list` in that case instead of raising.

### Raw call

```julia
bytes = KclLib.call("KclService.Ping", encoded_ping_args)
```

## Development

### Running Tests

```bash
make test
```

This activates the project environment, instantiates dependencies (ProtoBuf.jl)
and runs the test suite in [`test/runtests.jl`](test/runtests.jl) against the
prebuilt `libkcl` in `../go/lib`.

### Regenerating the protobuf bindings

The protobuf message code in [`src/pb`](src/pb) is generated from
[`spec/spec.proto`](../spec/spec.proto) and checked in, following the
repository convention. To regenerate after a spec change:

```bash
make proto
```

(Uses ProtoBuf.jl's `protojl` generator; it strips the `service` blocks first
because ProtoBuf.jl does not implement proto services — they are unused here,
as the native dispatcher routes by RPC name string.)

### Layout

- `src/KclLib.jl` — the whole binding: `LibKcl` FFI module (dlopen + `ccall`),
  `call` escape hatch, the 20 typed wrappers and `list_method`.
- `src/pb/` — generated protobuf structs (vendored).
- `test/runtests.jl` — end-to-end tests covering all 20 RPCs.
- `test_data/` — fixtures copied from `python/tests/test_data`.

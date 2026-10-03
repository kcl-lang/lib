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

### Typed AST

`parse_file` and `parse_program` return the AST as a JSON string. `parse_module`
and `parse_program_ast` decode it into typed structs mirroring Rust's AST in
`../kcl/crates/ast/src/ast.rs`.

```julia
using KclLib

m = parse_module(parse_file(ParseFileArgs(
    path="main.k",
    source="""
    schema Person:
        name: str = "anonymous"
        age: int = 0
    """)).ast_json)

for ref in m.body
    s = ref.node
    s isa SchemaStmt || continue
    println(s.name.node, " on line ", s.pos.line)
    for attr in s.body
        a = attr.node
        a isa SchemaAttr && println("  ", a.name.node, ": ", a.ty.node)
    end
end
```

`Node{T}` pairs a value with the `Pos` it was parsed at, mirroring Rust's
`NodeRef<T>`. `node_type(x)` returns the `type` tag the parser emitted, which is
the same discriminator the other bindings key their dispatch on.

Three serde shapes are worth knowing, because they are the details most easily
guessed wrong:

- `Stmt` and `Expr` are `#[serde(tag = "type")]` — every node carries a `type`.
- `Type` is `#[serde(tag = "type", content = "value")]` — a basic type reads
  back as `{"type": "Basic", "value": "Int"}`, **not** `{"type": "Int"}`. Use
  `BasicType` / `UnionType` / `DictType` / … and read the payload off
  the struct.
- The plain structs nested inside `NodeRef<T>` — `Identifier`, `Target`,
  `Keyword`, `Arguments`, `ConfigEntry`, `CheckExpr`, `CallExpr`, `CompClause`,
  `SchemaExpr` — carry no tag. That is why `SchemaStmt.decorators` decodes to a
  `Decorator` rather than a tagged variant, and why `SchemaExpr.name` is a
  `Node{Identifier}` rather than a `Node{KclExpr}`.

Type names match the Java binding's (`com.kcl.ast`), so a name from `ast.rs` or
from `java/src/main/java/com/kcl/ast/` is the name here: `Compare`, `ListComp`,
`DictComp`, `NumberLit`, `StringLit`, `NameConstantLit`, `JoinedString`,
`FormattedValue`, `Subscript`, `Module`, `Pos`, `Node`. Two spellings are kept
alongside the Java ones for compatibility with code written against the older
Julia vocabulary: `KclModule` is an alias of `Module`, and
`expr_from_wire`/`stmt_from_wire` are unchanged.

Two payloads reach this package untagged, and Java gives each of them a second
class for Jackson's sake — it cannot reuse a class the `Expr` subtype table
owns. Julia's dispatch is a plain `if`/`elseif` on the tag, so there is nothing
to disambiguate and each is one object under two names:

| Java | here | the same object as |
| --- | --- | --- |
| `Decorator` | `struct Decorator` plus `CallExpr(::Decorator)` | `SchemaAttr.decorators` is `Vector{NodeRef{CallExpr}}` |
| `SchemaConfig` | `const SchemaConfig = SchemaExpr` | `UnificationStmt.value` is `NodeRef{SchemaExpr}` |

A third, `CheckExpr`, needs no second name at all: the tagged `Expr::Check` and
the untagged `SchemaStmt.checks` are the same struct, so there is one class,
`struct CheckExpr <: KclExpr`, and `stmt.checks[1].node.test` is one hop.

Note that `Expr` is `Base.Expr` in Julia, so the sealed-ish expression base is
`KclExpr` here while the type hierarchy keeps the plain name `AstType`.

An unrecognised tag decodes to `UnknownStmt` / `UnknownExpr` / `UnknownType`
with the raw payload attached, so a newer parser degrades instead of throwing.
**This is a deliberate divergence from Java**, which raises
`InvalidTypeIdException` on a tag missing from its `@JsonSubTypes` list; Julia
has no such mechanism, and keeping the payload means a file using syntax a
newer `libkcl` adds is still traversable.

`parse_program_ast` accepts both program encodings: a bare array of modules and
the `{"root": …, "pkgs": {"__main__": […]}}` envelope.

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

### format_test_report

```julia
result = test(TestArgs(pkg_list=["test_data/testing/module/..."]))
print(format_test_report(FormatTestReportArgs(result)).report)
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

### Plugins

A plugin exposes Julia functions to KCL code. The program imports the plugin
module and then calls the method unqualified:

```kcl
import kcl_plugin.strings

result = strings.join("KCL", "KCL", 123)
```

The runtime resolves that to a `kcl_plugin.strings.join` call into the host,
so `register_plugin` only ever sees the two halves.

```julia
using KclLib

KclLib.register_plugin("strings", "join", (args, kwargs) -> "\"KCL.KCL.123\"")

result = KclLib.run(code = "import kcl_plugin.strings\nresult = strings.join(\"KCL\", \"KCL\", 123)\n")
println(KclLib.get(result, "result"))  # KCL.KCL.123
```

| Function | Purpose |
| --- | --- |
| `KclLib.register_plugin(plugin, method, fn)` | Adds or replaces one method. |
| `KclLib.plugin_registered(plugin, method)` | Whether a name resolves. |
| `KclLib.disable_plugins()` | Empties the registry and releases the service handle. |
| `KclLib.has_plugins()` | Whether anything is registered. |

A method is called as `fn(args::String, kwargs::String) -> String`, where both
arguments are the raw JSON the runtime sends and the return value must be
JSON-encoded. Register methods at start-up — nothing evaluated before the
first registration can reach the plugin. Throwing is allowed: the exception is
caught at the agent boundary and reported to the runtime, so it never unwinds
into the native frames underneath.

Two properties are worth calling out:

+ **No JSON dependency.** Arguments arrive as raw JSON strings and the result
  must be JSON-encoded, so a method that ignores its arguments needs no parser
  at all. One that inspects them can use `JSON3.jl` or `JSON.jl`.
+ **Errors are data, not crashes.** Calling a method that was never
  registered — or one that threw — yields a
  `{"__kcl_PanicInfo__": "..."}` object, matching what Go's
  `plugin.JSONError` and Python's `_call_py_method` return, so it surfaces
  through the normal `err_message` path rather than as a native crash.

`call_native` is the stateless universal dispatcher and cannot carry a plugin
agent, so the first `register_plugin` binds a `kcl_service_new` handle and
every subsequent call routes through `kcl_service_call_with_length`. With
nothing registered the binding keeps using `call_native` unchanged, so
programs that do not use plugins are unaffected.

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
- `src/plugin.jl` — the plugin registry and the `@cfunction` agent, included
  from inside `LibKcl`.
- `src/ast.jl` — the typed AST: `Pos` / `Node{T}` plus the `AstType`, `KclExpr`,
  `KclStmt` and DTO hierarchies, decoded with the binding's own JSON reader.
- `src/pb/` — generated protobuf structs (vendored).
- `test/runtests.jl` — end-to-end tests covering all 20 RPCs and the AST.
- `test/ast_alignment.jl` — the AST wire contract, asserted against the shared
  golden capture at `../testdata/ast/alignment.json`: every tag in the tree
  resolves to a declared variant, `Comment` reads `text` off the struct under
  `node` rather than off the wrapper, and a `Type` is tagged `type` with its
  payload in `value`. `runtests.jl` includes it. The Dart package has the
  mirror-image file, `test/ast_contract_test.dart`.
- `test_data/` — fixtures copied from `python/tests/test_data`.

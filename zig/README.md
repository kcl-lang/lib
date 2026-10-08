# KCL Artifact Library for Zig

Zig bindings for the [KCL](https://kcl-lang.io) artifact library. The bindings
call the prebuilt native `libkcl` through the universal C FFI dispatcher
(`call_native`, see `../c/include/kcl_ffi.h`) and decode the protobuf payloads
with typed wrappers generated from `../spec/spec.proto`.

## Prerequisites

+ Zig 0.16.0+
+ `protoc` on `PATH` (the protobuf code generator used to derive the typed
  bindings from `../spec/spec.proto` on every build)

## Build and Test

```shell
zig build test
```

The native library is linked from `../go/lib/<platform>/` (no Rust build).

## API

Every wrapper takes an allocator as the first argument, sends the protobuf
request through the native dispatcher, and returns the decoded response
(error set: `error{KclRpc, MalformedResponse, OutOfMemory, ...}`). Call
`deinit(allocator)` on the returned message when done.

| Wrapper | RPC | Purpose |
| --- | --- | --- |
| `ping` | `KclService.Ping` | Liveness check, echoes the value |
| `getVersion` | `KclService.GetVersion` | KCL version information |
| `execProgram` | `KclService.ExecProgram` | Execute KCL files / inline code |
| `parseProgram` | `KclService.ParseProgram` | Parse entry files to AST JSON |
| `parseFile` | `KclService.ParseFile` | Parse one file to module AST JSON |
| `loadPackage` | `KclService.LoadPackage` | Parse + semantic model (symbols, scopes) |
| `listOptions` | `KclService.ListOptions` | List `option()` calls |
| `listVariables` | `KclService.ListVariables` | List variables by specs |
| `overrideFile` | `KclService.OverrideFile` | Override specs, rewriting the file |
| `getSchemaTypeMapping` | `KclService.GetSchemaTypeMapping` | Schema types of a program |
| `getSchemaTypeMappingUnderPath` | `KclService.GetSchemaTypeMappingUnderPath` | Schema types keyed by package |
| `formatCode` | `KclService.FormatCode` | Format a source string |
| `formatPath` | `KclService.FormatPath` | Format files in place |
| `lintPath` | `KclService.LintPath` | Lint files |
| `validateCode` | `KclService.ValidateCode` | Validate data against a schema |
| `loadSettingsFiles` | `KclService.LoadSettingsFiles` | Merge `kcl.yaml` settings |
| `rename` | `KclService.Rename` | Rename a symbol across files on disk |
| `renameCode` | `KclService.RenameCode` | Rename a symbol in source strings |
| `@"test"` | `KclService.Test` | Run KCL unit tests (`test` is a Zig keyword) |
| `formatTestReport` | `KclService.FormatTestReport` | Render a `TestResult` as a text report |
| `updateDependencies` | `KclService.UpdateDependencies` | Resolve `kcl.mod` dependencies |
| `listMethod` | `BuiltinService.ListMethod` | List dispatcher RPCs |

The generic escape hatch remains available for anything else:

```zig
pub fn call(allocator: std.mem.Allocator, name: []const u8, args: []const u8) ![]u8
```

It accepts the fully-qualified RPC name (e.g. `"KclService.ExecProgram"`) and
raw protobuf request bytes, returning the raw response bytes.

## High-level `kcl` API

`src/kcl.zig` mirrors the Go SDK's `pkg/kcl` on top of the wrappers above:

```zig
const kcl = @import("kcl.zig");

var options = kcl.Options.init(allocator);
defer options.deinit();
_ = options.withOverrides(&.{ "alice.age=18" });

var result = try kcl.runCode(allocator, "alice = {age = 18}", &options);
defer result.deinit(allocator);

// Dot-path navigation over the result document ("a.b.c", integer
// segments index arrays). JSON is preferred; YAML results fall back to
// a built-in minimal YAML reader.
const age = try result.get(allocator, "alice.age");
```

+ `run` (single file), `runFiles` (multiple paths), `runCode` (inline
  source) all take `*Options` and return `kcl.Result`
  (`json_result` / `yaml_result` / `log_message` / `err_message`).
+ `Options` covers the `kcl-go` `With*` set: `args` (`-D`), `overrides`
  (`-O`), `selectors` (`-S`), `settings` (`kcl.yaml`, merged through
  `loadSettingsFiles` with explicit options winning), `external_pkgs`
  (`-E`), `format`, `error_format`, `disable_none`, `sort_keys`,
  `show_hidden`, `include_schema_type_path` (with the `_type` short-name
  rewriting hook, disabled by `full_type_path`), `strict_range_check`,
  `verbose` / `debug`, `compile_only`, `fast_eval`, `print_override_ast`
  and `disable_yaml_result`.
+ A non-empty `err_message` fails the call with `error.KclError`; the
  message is retrieved via `kcl.lastErrorMessage()`.

## Typed AST

`src/ast.zig` parses the `ast_json` returned by `parseProgram` /
`parseFile` into typed AST nodes (mirroring the Rust `ast` crate, same
coverage as the Python/Lua/... AST packages):

```zig
const ast = @import("ast.zig");

// An arena is the intended allocation strategy: parsed nodes live and
// die with the arena.
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

const program = try ast.parseProgram(arena.allocator(), parse_result.ast_json);
```

`Module`, `Stmt`/`StmtNode`, `Expr`/`ExprNode`, `Type`/`TypeNode` and the
DTO types (`Pos`, `Decorator`, `Identifier`, ...) are re-exported from
`ast.zig`; every node carries a `pos`. `src/ast_alignment_test.zig`
round-trips `test_data/ast_alignment/main.k` through the typed AST and
compares it against the runtime-emitted JSON, matching the
`AstJsonAlignmentTest` suites of the other bindings.

## Plugins

A plugin exposes host functions to KCL code. The program imports the
plugin module and then calls the method unqualified:

```kcl
import kcl_plugin.strings

result = strings.join("KCL", "KCL", 123)
```

The runtime resolves that to a `kcl_plugin.strings.join` call into the
host, so `register` only ever sees the two halves (`"strings"`,
`"join"`).

```zig
const plugin = @import("plugin.zig");

fn stringsJoin(method: []const u8, args: []const u8, kwargs: []const u8) []const u8 {
    _ = method;
    _ = args;
    _ = kwargs;
    return "\"KCL.KCL.123\"";
}

try plugin.register(gpa, "strings", "join", stringsJoin);
defer plugin.disable(gpa);
// ... evaluate KCL here ...
```

| Function | Purpose |
| --- | --- |
| `register(gpa, plugin, method, fn_ptr)` | Adds or replaces one method. Binds the KCL service handle on the first call. |
| `registered(plugin, method)` | Whether the method is currently in the registry. |
| `disable(gpa)` | Unbinds the handle, empties the registry, and returns the binding to the stateless `call_native` path. |
| `serviceHandle()` | The bound handle, or `null` when nothing is registered. |

Register methods at start-up — nothing evaluated before the first
registration can reach the plugin. `disable` takes the allocator rather
than relying on the one passed to `register`, so it is symmetric with
every other explicit-allocator API here.

Two properties are worth calling out:

* **No JSON dependency.** Arguments arrive as raw JSON and the result
  must be JSON-encoded, so a method that ignores its arguments needs no
  parser at all. One that inspects them can use `std.json`.
* **Errors are data, not crashes.** Calling a method that was never
  registered yields a `{"__kcl_PanicInfo__": "..."}` object, matching
  what Go's `plugin.JSONError` and Python's `_call_py_method` return, so
  an unknown method surfaces as a KCL-level diagnostic.

Under the hood, registration creates a service handle
(`kcl_service_new(agent)`) and `root.call` dispatches through it, because
`call_native` is stateless and cannot carry the plugin agent
(docs/abi.md §6). Both entry points decode the same protobuf payloads,
so the reply is identical either way.

### Notes

+ The bindings cover the full 26-RPC `KclService` surface from
  `../spec/spec.proto` plus the two `BuiltinService` methods, with the
  high-level facade and the typed AST package built on top.
+ `listMethod` dispatches to `BuiltinService.ListMethod` and `ping` to
  `KclService.Ping`. The core registers exactly two RPCs under the
  `BuiltinService` name `spec.proto` gives them — `Ping` and `ListMethod` —
  and every other RPC under `KclService`. There is no `KclService.ListMethod`
  alias, so that wrapper cannot fall back to it; `listMethod` returns all 28
  registered names.
+ `execProgram`, `validateCode`, and the `KclService.Test` wrapper
  (`@"test"`) are not thread safe, mirroring the spec. The plugin
  registry is process-wide for the same reason; the runtime releases its
  own dispatch lock before calling a handler, so a plugin method may
  still trigger nested KCL evaluation.

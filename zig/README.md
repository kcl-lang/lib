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

### Notes

+ The bindings cover the full 20-RPC `KclService` surface from
  `../spec/spec.proto` plus `BuiltinService.ListMethod`, with the
  high-level facade and the typed AST package built on top.
+ The prebuilt libkcl v0.13.0 binary predates the `BuiltinService.*`
  registration: `listMethod` returns an empty result on it (the corresponding
  unit test therefore tolerates both the empty and the populated result).
+ `execProgram`, `validateCode`, and the `KclService.Test` wrapper
  (`@"test"`) are not thread safe, mirroring the spec.

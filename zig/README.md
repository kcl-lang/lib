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

### Notes

+ The bindings cover the full 20-RPC `KclService` surface from
  `../spec/spec.proto` plus `BuiltinService.ListMethod`.
+ The prebuilt libkcl v0.13.0 binary predates the `BuiltinService.*`
  registration: `listMethod` returns an empty result on it (the corresponding
  unit test therefore tolerates both the empty and the populated result).
+ `execProgram`, `validateCode`, and the `KclService.Test` wrapper
  (`@"test"`) are not thread safe, mirroring the spec.

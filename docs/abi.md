# KCL Language-Binding FFI ABI

This document describes the binary interface shared by every KCL language
binding in this repository (C, C++, Go, Python, .NET, Node.js, Swift, Ruby,
Lua, Java, Kotlin, Zig, wasm, ...). It is the single reference behind the
dispatched RPC convention that each binding's comments point to.

The native side is implemented in the `kcl-lang/kcl` repository by the
`kcl-api` crate (`crates/api/src/service/capi.rs`) and shipped either as the
`kcl-lib-c` cdylib built from `c/src/lib.rs` or as the prebuilt shared
libraries vendored under `go/lib/<platform>/` (see §8).

## 1. Design overview

All language bindings talk to one universal dispatcher exported from the
native library. A single function, `call_native`, serves every RPC: the RPC
name and the protobuf-encoded request are passed in, and the
protobuf-encoded reply is written into a caller-allocated result buffer.
There is no per-RPC symbol and no dynamic registration; adding an RPC to
`spec/spec.proto` never changes the ABI.

## 2. The universal dispatcher `call_native`

C declaration (see `c/include/kcl_ffi.h`):

```c
uintptr_t call_native(const uint8_t *name_ptr,
                      uintptr_t name_len,
                      const uint8_t *args_ptr,
                      uintptr_t args_len,
                      uint8_t *result_ptr);
```

Parameter semantics:

| Parameter    | Meaning                                                                 |
|--------------|-------------------------------------------------------------------------|
| `name_ptr`   | Pointer to the RPC name bytes (UTF-8, **not** NUL-terminated).          |
| `name_len`   | Length of the RPC name in bytes.                                        |
| `args_ptr`   | Pointer to the protobuf-encoded request message (see §3).               |
| `args_len`   | Length of the request in bytes (may be 0 for empty requests).           |
| `result_ptr` | Caller-allocated buffer that receives the protobuf-encoded response.    |

Return value: the number of bytes written to `result_ptr`. The native side
copies the whole response into `result_ptr` unconditionally; it does **not**
append a NUL terminator — bindings that treat the payload as a C string must
terminate it themselves using the returned length.

## 3. RPC names and protobuf messages

The RPC name selects the service method and is formed as
`"<Service>.<Method>"`, for example `"KclService.ExecProgram"` or
`"BuiltinService.ListMethod"`. The two services defined by
`spec/spec.proto` (package `com.kcl.api`) are:

- `BuiltinService` — `Ping`, `ListMethod`.
- `KclService` — the 20 language-facing RPCs: `Ping`, `GetVersion`,
  `ParseProgram`, `ParseFile`, `LoadPackage`, `ListOptions`,
  `ListVariables`, `ExecProgram`, `OverrideFile`, `GetSchemaTypeMapping`,
  `GetSchemaTypeMappingUnderPath`, `FormatCode`, `FormatPath`, `LintPath`,
  `ValidateCode`, `LoadSettingsFiles`, `Rename`, `RenameCode`, `Test`,
  `UpdateDependencies`.

The request and response payloads are protobuf messages defined in
`spec/spec.proto` (the single source of truth for message shapes), generated
per language by the usual protobuf toolchains — e.g. nanopb in
`c/lib/spec.pb.c`, prost in the Rust `kcl-api` crate, purego-registered
wrappers in Go. The request message type must match the named RPC, and the
response decodes as the RPC's result message — unless the error convention
of §4 applies.

## 4. Error contract: the `ERROR:` prefix

Every failure — an unknown RPC name, malformed request bytes, or an error
raised while executing the KCL program — is reported **in-band**: the native
dispatcher writes an ASCII payload starting with the literal prefix
`"ERROR:"` into `result_ptr` and returns its length. The prefix is defined
once in `kcl_lib.h` as `ERROR_PREFIX`/`ERROR_PREFIX_LEN` and mirrored by
every other binding (e.g. `ERROR_PREFIX` in `zig/src/root.zig`); all must
stay in lockstep with the `format!("ERROR:{}", ...)` literals in
`crates/api/src/service/capi.rs` (both the `call!` macro and the panic
branch of `kcl_service_call_with_length`).

Bindings must therefore inspect the first 6 bytes of the reply before
attempting to decode it: a reply beginning with `ERROR:` is an error string
(the prefix may be stripped for display), not a protobuf message. Success
replies never start with these bytes, because a protobuf-encoded response
message begins with a field tag, not ASCII `E`.

## 5. Result-buffer conventions

- The result buffer is **allocated by the caller** and passed as
  `result_ptr`. The required size cannot be queried up front; the convention
  across bindings is **4 MiB** (C: `BUFFER_SIZE` in `kcl_lib.h`; Zig:
  `call_buffer_size`; .NET uses the same scratch size).
- The returned length is authoritative: the response is
  `result_ptr[0..returned_length]`. Anything beyond it is uninitialized and
  must not be read (in particular, do not call `strlen` on the buffer
  without terminating it first — see the comment on `kcl_call` in
  `kcl_lib.h`).
- The error payload of §4 follows the same rule: it is the first
  `returned_length` bytes of the same buffer.
- Bindings that copy payloads into user buffers should do so with
  truncation-safe copies (`kcl_copy_string` in C).

## 6. Go-specific service-handle symbols

In addition to `call_native`, the shared library exports a small
handle-based API consumed **only by the Go binding** (registered with
purego in `go/native/native_nonmusl.go`, and by the musl cgo variants):

| Symbol                        | Role                                                        |
|-------------------------------|-------------------------------------------------------------|
| `kcl_service_new`             | Create a service handle; takes the plugin-agent pointer (§7). |
| `kcl_service_call_with_length`| Invoke an RPC on the handle (name, args, args length, out length). |
| `kcl_service_delete`          | Destroy the handle.                                          |
| `kcl_free`                    | Free a buffer returned by the native side.                   |

Other bindings do not use these symbols; they call `call_native` (or the
plugin-agent variant in §7) directly.

## 7. Plugin-agent entry point

Bindings that host KCL plugins (Python, .NET, ...) use a second dispatcher
exported from their own native shim (e.g. `dotnet/src/lib.rs`):

```c
uintptr_t call_native_with_plugin_agent(const uint8_t *name_ptr,
                                        uintptr_t name_len,
                                        const uint8_t *args_ptr,
                                        uintptr_t args_len,
                                        uint8_t *result_ptr,
                                        uint64_t plugin_agent);
```

It behaves exactly like `call_native` (including the §4 error contract) but
takes one extra argument: the address of a **host callback** that the native
side invokes whenever executed KCL code calls a plugin method
(`kcl_plugin.<module>.<method>`). The callback has the C signature:

```c
const char *(*plugin_agent_fn)(const char *method,
                               const char *args_json,
                               const char *kwargs_json);
```

It receives the method name and JSON-encoded arguments and returns a
JSON-encoded result. The host registers it by passing a function pointer
cast to `u64`:

- Python creates it with `ctypes.CFUNCTYPE(c_char_p, c_char_p, c_char_p,
  c_char_p)` and passes `cast(fn, c_void_p).value`
  (`python/kcl_lib/plugin/plugin.py`); every API call forwards
  `plugin_agent_addr` by default.
- .NET marshals a delegate the same way into `call_native_with_plugin_agent`.
- Go passes `plugin.GetInvokeJsonProxyPtr()` once to `kcl_service_new` (§6).

## 8. Prebuilt shared libraries

Precompiled native libraries are vendored in this repository under
`go/lib/<platform>/` and are what most bindings load at run time:

| Directory                    | Artifact       | Platform             |
|------------------------------|----------------|----------------------|
| `go/lib/darwin-arm64/`       | `libkcl.dylib` | macOS, Apple Silicon |
| `go/lib/darwin-amd64/`       | `libkcl.dylib` | macOS, x86-64        |
| `go/lib/linux-arm64/`        | `libkcl.so`    | Linux, arm64 (glibc) |
| `go/lib/linux-amd64/`        | `libkcl.so`    | Linux, x86-64 (glibc)|
| `go/lib/linux-musl-arm64/`   | `libkcl.a`     | Linux, arm64 (musl)  |
| `go/lib/linux-musl-amd64/`   | `libkcl.a`     | Linux, x86-64 (musl) |
| `go/lib/windows-arm64/`      | `kcl.dll`      | Windows, arm64       |
| `go/lib/windows-amd64/`      | `kcl.dll`      | Windows, x86-64      |

The C/C++ bindings instead build the cdylib from `c/` (`cargo build -r`
produces `target/release/libkcl_lib_c.{so,dylib}`), which re-exports the
same symbols through `kcl-api`.

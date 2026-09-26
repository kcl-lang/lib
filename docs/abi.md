# KCL Library FFI ABI

This document describes the cross-language FFI contract implemented by every
binding in this monorepo. It is the single source of truth for the universal
RPC dispatcher, the plugin agent convention, and the buffer / error
conventions that every language binding relies on.

> Status note: the FFI is implemented by the `kcl-api` crate in
> <https://github.com/kcl-lang/kcl>. This repository (`kcl-lang/lib`)
> consumes that crate and ships one binding per language. Anything that
> changes the wire shape described here must change in `kcl-lang/kcl` first
> and be re-released as a new `kcl-api` version before the bindings can
> adopt it.

## 1. Universal entry point: `call_native`

Every binding ends up calling into one of two symbols exported by the
`kcl-api` crate:

- `call_native(name_ptr, name_len, args_ptr, args_len, result_ptr) -> usize`
  — universal dispatcher, length-prefixed in both directions.
- `kcl_service_call_with_length(serv, name, args, args_len, &result_len)`
  — equivalent entry point exposed by the C ABI crate used by C/C++/Lua.

The semantics are identical:

| Direction | Buffer       | Length field               |
| --------- | ------------ | -------------------------- |
| Request   | `name_ptr`   | `name_len` (UTF-8 bytes)   |
| Request   | `args_ptr`   | `args_len` (protobuf)      |
| Response  | `result_ptr` | returned `usize` (bytes)   |

The service name is a fully qualified RPC name such as
`"KclService.ExecProgram"` or `"BuiltinService.ListMethod"` and matches a
service declared in `spec/spec.proto`. The dispatcher parses the name, looks
up the typed handler, decodes the protobuf `args` buffer into the matching
`<Method>Args` struct, runs the handler, and writes the protobuf-encoded
`<Method>Result` into the caller-supplied `result_ptr`. The returned `usize`
is the number of bytes written; the caller owns the buffer.

On failure the dispatcher writes a UTF-8 string beginning with the
`"ERROR:"` prefix (see §4) into `result_ptr` and returns the byte length
of that string.

Implementations by binding:

- C: `c/include/kcl_lib.h::kcl_call` wraps `call_native` from
  `c/include/kcl_ffi.h`.
- C++: `cpp/src/...` mirrors the C wrapper.
- Go: `go/kcl.go::Call`.
- Java / Kotlin: `.../api/API.java::call`.
- Lua: `lua/src/client.rs` uses `kcl_api::call` directly.
- .NET: `dotnet/KclLib/api/API.cs::Call` wraps P/Invoke
  `callNative`/`callNativeWithPluginAgent`.
- Node.js: `nodejs/src/lib.rs::list_method` and the plugin-agent path in
  `exec_program` use `kcl_api::call` / `kcl_api::call_with_plugin_agent`.
- Python: `python/kcl_lib/api/service.py::call` calls
  `kcl_lib.call_with_plugin_agent`.
- Swift: `swift/Sources/KclLib/API.swift::callNative` wraps the
  `CKclLib.callNative` symbol.
- WASM (browser/Node.js): `wasm/src/index.ts::invokeKCLCallNative` wraps the
  `call_native` export.
- Zig: `zig/src/root.zig::call` wraps the `call_native` symbol.

## 2. Plugin-agent variant

To invoke a KCL program that calls into plugin code (e.g.
`import kcl_plugin.foo as foo` and `foo.add(1, 2)`), the binding must pass
a function pointer to a "plugin agent" alongside the dispatcher call. The
plugin agent has the C ABI:

```c
const char* plugin_method_agent(const char* method,
                                const char* args_json,
                                const char* kwargs_json);
```

The dispatcher calls the plugin agent whenever the running KCL program
invokes a method on a `kcl_plugin.*` import. `method` is the
fully-qualified call site (e.g. `"kcl_plugin.foo.add"`), `args_json` and
`kwargs_json` are the JSON-encoded argument list and keyword-argument
dictionary, and the returned `*c_char` is a JSON-encoded result.

Memory ownership: the `*c_char` returned by the plugin agent must remain
valid at least until the dispatcher copies it. The convention in this repo
is that the binding owns the buffer and keeps it alive for the duration of
the call (see §3 for the .NET fix).

Bindings that implement the plugin agent:

- C / C++: no plugin-agent wrapper today.
- .NET: `dotnet/KclLib/api/API.cs::PluginAgentCallback`. Fixed in this PR
  to allocate a fresh buffer per call instead of reusing the static
  `pluginAgentBuffer`.
- Java / Kotlin: `.../plugin/...` (see per-binding source for the latest
  path; each wraps the C ABI with JNI / `FunctionPointer`).
- Node.js: `nodejs/src/plugin.rs::plugin_method_agent`. The pointer is
  cached in a `thread_local!` and passed via `plugin_agent_ptr()`.
- Python: `python/kcl_lib/plugin/plugin.py::plugin_method_agent`. Allocates
  a fresh `create_string_buffer` per call.
- Swift: not currently exposed.
- WASM: `wasm/src/index.ts::load` accepts an `imports` callback named
  `kcl_plugin_invoke_json_wasm` from the host.
- Zig / Lua: not currently exposed.

## 3. .NET plugin-agent race fix

The previous `dotnet/KclLib/api/API.cs::PluginAgentCallback` reused a single
`pluginAgentBuffer` allocated with `Marshal.AllocHGlobal` and resized
whenever the next result was larger. That is unsound under concurrent
plugin invocations: thread A could fill the buffer, release the lock, and
the dispatcher might still be reading from it while thread B reallocates or
frees it.

The fix in this PR:

- The callback now allocates a fresh `IntPtr` (via `Marshal.AllocHGlobal`)
  sized exactly for the current result.
- Every allocated buffer is appended to a process-wide list that is freed
  in one batch once the surrounding `Call()` returns (the Rust dispatcher
  is documented as not thread-safe, so plugin-agent invocations always
  happen on the same thread as the surrounding `callNativeWithPluginAgent`
  call, which means no extra synchronization is required for the buffer
  list).
- The `try/finally` in `Call()` ensures the buffers are freed even if the
  native dispatcher throws.
- The old `pluginAgentBuffer` / `pluginAgentBufferSize` fields are removed.

A stress test in `dotnet/KclLib.Tests/PluginTest.cs` invokes the plugin
agent concurrently from N=8 threads × 100 calls and asserts no exceptions
and the expected result.

## 4. The `"ERROR:"` prefix

When the Rust dispatcher returns a result that is an error (either an
explicit `Err(anyhow::Error)` from a service handler, or a panic caught by
the `catch_unwind` wrapper in `kcl_api::service::capi::kcl_service_call_with_length`),
it writes a UTF-8 string of the form `"ERROR:<message>"` into the result
buffer and returns the byte length. The Rust source of truth is:

- `crates/api/src/service/capi.rs` — `format!("ERROR:{}", ...)` in the
  `call!` macro and in the panic branch of
  `kcl_service_call_with_length`.

Each binding must define a single named constant for the prefix and use it
everywhere a `"ERROR:"` string appears:

| Binding   | Constant                | File                                                                  |
| --------- | ----------------------- | --------------------------------------------------------------------- |
| C         | `ERROR_PREFIX`          | `c/include/kcl_lib.h`                                                 |
| .NET      | `ERROR_PREFIX`          | `dotnet/KclLib/api/API.cs`                                            |
| Lua       | not used (Rust typed)   | `lua/kcl_lib/raw_api.lua` (errors flow through Rust `Result`)         |
| Node.js   | not used (Rust typed)   | `nodejs/src/lib.rs` (errors flow through Rust `Result` / `napi::Error`) |
| Python    | `_ERROR_PREFIX`         | `python/kcl_lib/api/service.py`                                       |
| Swift     | `ERROR_PREFIX`          | `swift/Sources/KclLib/API.swift`                                      |
| WASM      | `"ERROR:"` (literal)    | `wasm/src/index.ts` (consider promoting to a module constant)         |
| Zig       | `ERROR_PREFIX`          | `zig/src/root.zig`                                                    |

If the prefix ever changes in the Rust source (it has been stable since
v0.13.0), all bindings must be updated in the same release.

## 5. Buffer size convention

Two buffer sizes appear repeatedly across bindings:

- **Default result buffer** — 4 MiB (`4 * 1024 * 1024`). Used for the
  caller-supplied `result_ptr` passed to `call_native`. The dispatcher
  copies the response into this buffer unconditionally, so the buffer
  must be at least as large as the largest `<Method>Result` you expect to
  receive. The Zig (`call_buffer_size`), C/C++/Node.js/Swift/.NET bindings
  all allocate 4 MiB. The WASM binding defaults to 16 MiB
  (`DEFAULT_CALL_NATIVE_RESULT_BUFFER_SIZE`) because WASM callers tend to
  decode larger `LoadPackage` payloads with the full AST index.
- **WASM runtime error buffer** — 4 KiB (`4 * 1024`). When the WASM module
  traps (panic=abort), the JS wrapper allocates a buffer of this size and
  asks the wasm guest to write the panic message into it via the
  `kcl_runtime_err` export. 1024 bytes was insufficient for any KCL
  program whose error message exceeded that size, causing silent
  truncation. Bumped to 4096 in this PR; see `wasm/src/index.ts`.

Negotiation: there is currently no negotiation protocol. Bindings pick a
fixed buffer size and the caller is expected to allocate a larger buffer
if they need to (e.g. `invokeKCLCallNative`'s `resultBufferSize` option).

## 6. Loading and environment

Bindings that load a native shared library honour the `KCL_LIB_HOME`
environment variable as an override for the platform-specific lookup
location. Implementations:

- C / C++: standard `dlopen`/`LoadLibrary` lookup; bindings can prepend
  `getenv("KCL_LIB_HOME")` to the search path.
- Node.js: uses `process.platform` / `process.arch` to pick the matching
  `kcl-lib.<platform>-<arch>.node` prebuilt; `KCL_LIB_HOME` is not
  currently honoured.
- Python: looks for `kcl_lib._kcl_lib` (the `cdylib` produced by
  `python/Cargo.toml`); `KCL_LIB_HOME` is not currently honoured.
- .NET: P/Invoke on `kcl_lib_dotnet`; the NuGet package deploys the
  `cdylib` next to the managed assembly. `KCL_LIB_HOME` is not currently
  honoured.
- Swift: depends on `CKclLib` (SwiftPM); the underlying `kcl_lib` shared
  library is loaded by the C target. `KCL_LIB_HOME` is not currently
  honoured.
- Zig: links against `libkcl_lib` via `build.zig`. `KCL_LIB_HOME` is not
  currently honoured.
- Lua: `lua/kcl_lib/raw_api.lua` calls `require("kcl_lib")`; the C module
  resolves `libkcl_lib` via standard Lua loader semantics.
- WASM: `wasm/src/index.ts::load` reads `kcl.wasm` from disk relative to
  the package or from `options.data` if supplied.

## 7. Exported Rust symbols

Symbols exported by the `kcl-api` crate's `cdylib` (generated via `cbindgen`
and the `#[unsafe(no_mangle)]` `extern "C-unwind"` functions in
`crates/api/src/service/capi.rs` and `crates/api/src/lib.rs`):

- `call_native(name_ptr, name_len, args_ptr, args_len, result_ptr) -> usize`
  — universal dispatcher (§1).
- `kcl_service_new(plugin_agent: u64) -> *mut kcl_service` — constructs a
  service handle that remembers the plugin-agent pointer.
- `kcl_service_delete(serv: *mut kcl_service)` — frees the service handle.
- `kcl_service_call(serv, name, args, args_len) -> *const c_char` —
  string-returning service call.
- `kcl_service_call_with_length(serv, name, args, args_len, &result_len)`
  — service call that returns the length alongside the pointer.
- `kcl_service_free_string(res: *mut c_char)` — frees a string previously
  returned by `kcl_service_call`.

WASM-specific exports (defined in the `kcl` crate's wasm bindings, not in
`kcl-api`):

- `kcl_run`, `kcl_run_with_log_message`, `kcl_fmt`, `kcl_version`,
  `kcl_call`, `call_native`, `kcl_runtime_err` — high-level entry points
  consumed by `wasm/src/index.ts`.
- `kcl_malloc`, `kcl_free` — bump allocator wrappers used to ferry
  strings into and out of WASM linear memory.

## 8. Adding new symbols

When you add a new symbol to `kcl-api`, follow these steps:

1. Add the `extern "C-unwind"` function to `crates/api/src/...` and the
   matching `cbindgen` entry in `crates/api/cbindgen.toml` if the binding
   is consumed from C.
2. Run `cargo build -p kcl-api` and inspect the resulting `kcl_ffi.h` /
   `kcl_lib.h` to confirm the symbol is exported.
3. Update each binding that needs the symbol (see §1 for the canonical
   list).
4. Update this document with the new symbol, its signature, and the
   bindings that consume it.

ABI compatibility rules:

- Adding new symbols is allowed in any release.
- Renaming, removing, or changing the signature of an existing symbol
  requires a major version bump of `kcl-api` and a coordinated update of
  every binding in this monorepo.

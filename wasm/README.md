# KCL WASM Library for Node.js and Browser

## Quick Start

### Node.js

```shell
npm install @kcl-lib/wasm
```

```typescript
import { load, invokeKCLRun } from "@kcl-lib/wasm";

async function main() {
  const inst = await load();
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  console.log(result);
}

main();
```

### Universal RPC entry point

Beyond the convenience wrappers `invokeKCLRun` / `invokeKCLRunWithLogMessage`
/ `invokeKCLFmt`, the underlying WASM module also exposes a `kcl_call` entry
point that dispatches to **any** KCL service method (the full set declared
in `spec/spec.proto`):

```typescript
import { load, invokeKCLCall, invokeKCLVersion } from "@kcl-lib/wasm";

const inst = await load();

// Read the KCL version baked into the artifact.
console.log(invokeKCLVersion(inst)); // -> "0.13.0"

// Dispatch any KclService.* RPC by name. The `args` field must be the
// protobuf-encoded `<Method>Args` message, and the returned string is
// the protobuf-encoded `<Method>Result` message (or an "ERROR:..."
// string on failure).
const args = ""; // empty bytes encode a default PingArgs
const pingResult = invokeKCLCall(inst, {
  methodName: "KclService.Ping",
  args,
});
console.log(pingResult);
```

### Typed API

For all KCL service methods the package ships typed TypeScript wrappers that
handle the protobuf encoding/decoding for you:

`ping`, `getVersion`, `parseProgram`, `parseFile`, `loadPackage`,
`listOptions`, `listVariables`, `overrideFile`, `execProgram`,
`getSchemaTypeMapping`, `getSchemaTypeMappingUnderPath`, `formatCode`,
`formatPath`, `lintPath`, `validateCode`, `loadSettingsFiles`, `rename`,
`renameCode`, `test`, `formatTestReport`, `updateDependencies`,
`generateToml`, `generateKcl`, `generateOpenAPI`, `generateProto` and
`generateDoc`, plus the `BuiltinService` wrappers `builtinPing` and
`listMethod`.

```typescript
import { load, ping, lintPath, getVersion } from "@kcl-lib/wasm";

const inst = await load();

console.log(ping(inst, { value: "hello" }).value); // -> "hello"
console.log(getVersion(inst).version); // -> "0.13.0"

// File-based methods operate on the WASI sandbox filesystem.
const result = lintPath(inst, { paths: ["/test.k"] });
console.log(result.results);
```

These wrappers call the byte-oriented `call_native` WASM export through
`invokeKCLCallNative` (also exported), because the string-based `kcl_call`
round-trip corrupts protobuf messages larger than ~127 bytes. On success
they return the decoded `<Method>Result` object; on failure they throw an
`Error` whose message is the KCL error text.

### Plugins

KCL code can call host functions through the `kcl_plugin.<name>.<method>`
name space. Register the methods once, before loading an instance, and the
typed API switches itself to the service-handle entry point that can carry
the plugin agent:

```typescript
import { load, registerPlugin, execProgram } from "@kcl-lib/wasm";

registerPlugin({
  name: "strings",
  version: "1.0.0",
  methods: {
    // Receives `args.args` (positional) and `args.kwargs` (keyword) and
    // returns a JSON-encodable value.
    join: { body: (args) => args.args.join(".") },
  },
});

const inst = await load();
execProgram(inst, {
  kCodeList: ['import kcl_plugin.strings\n\nresult = strings.join("KCL", 1)\n'],
}); // -> "result: KCL.1"
```

Arguments and results cross the boundary as JSON, so a method that ignores
its arguments needs no parsing at all. The `methodSpec.type` field
(`argsType` / `kwArgsType` / `resultType`) is an optional declaration the
host can validate against; the runtime does not read it.

Also exported: `getPlugin`, `getMethodSpec`, `pluginRegistered`,
`pluginMethodNames`, `hasPlugin`, `resetPlugin`, `jsonError`,
`parseMethodArgs`, `invokePluginJson`, plus the `MethodArgs` accessors
(`arg`, `kwArg`, `getCallArg`, `strArg`, `intArg`, `floatArg`, `boolArg`,
`listArg`, `mapArg` and their `*KwArg` counterparts). The module is
re-exported from the package root, so `import { registerPlugin } from
"@kcl-lib/wasm"` is enough.

Two things differ from the other bindings:

- **Unknown or failing methods abort the instance.** The KCL runtime turns
  the `{"__kcl_PanicInfo__": ...}` reply into an evaluator `panic!`, and
  this module is built with `panic=abort`, so the diagnostic arrives as a
  thrown `KCL WASM trap` rather than in `errMessage`. Check
  `pluginRegistered` before calling from KCL if that matters. A host-side
  error inside the method body is likewise unrecoverable, so keep plugin
  methods total.
- **Plugin errors are still data inside the registry.**
  `invokePluginJson` never throws: an unknown method, malformed JSON or a
  throwing body all come back as the `jsonError` envelope, which is the
  same contract the C binding and Go's `plugin.JSONError` offer.

### Facade (high-level API)

For the common "run some KCL and read the result" flow, the package ships a
kcl-go-style facade — the same surface as the Python/.NET/Node.js bindings
of this repo — on top of the typed wrappers:

```typescript
import { load, run, runFiles, validate, Kcl, KclError } from "@kcl-lib/wasm";

const inst = await load();

// Inline code; options are a single plain object.
const result = run(inst, "a = {replicas = 2}", { selectors: ["a"] });
console.log(result.get("a.replicas")); // 2
console.log(result.yamlResult); // raw runtime output, untouched

// Files from the WASI sandbox filesystem, with kcl.yaml settings as the
// base and explicit options winning.
const fromFiles = runFiles(inst, ["/work/main.k"], {
  settings: "/work/kcl.yaml",
  overrides: ["replicas = 3"],
});

// Validate data against a schema (mirrors the Python facade's validate_code).
validate(inst, "schema Person:\n  name: str", '{"name": "Alice"}', "json"); // -> true

// Instance-scoped variant of the same entry points.
const kcl = new Kcl(inst);
kcl.run("a = 1");
```

`run` / `runFiles` are synchronous and throw `KclError` on any failure
(`error.code` carries the runtime diagnostic code, e.g. `"E1001"`).
`KclResult` exposes the raw `yamlResult` / `jsonResult` / `logMessage` /
`errMessage` strings plus `get("a.b.c")` dotted-path access (integer
segments index into lists, e.g. `"a.0.b"`) and `toObject()`. Settings files
are resolved by the `LoadSettingsFiles` RPC against the sandbox filesystem —
no YAML parser is bundled.

Differences from the Node.js facade, imposed by the WASM sandbox:

- Every facade entry point takes the WASM instance first: the WASM binding
  is not a process-wide singleton, and each instance carries its own WASI
  sandbox. `new Kcl(instance)` binds it once for all method calls.
- Execution goes through the typed `ExecProgram` RPC (the method is
  registered in the WASM artifact), which is what makes `format`,
  selectors and settings merging work end to end. `invokeKCLRun` remains
  the leanest path for a single file with no options.
- File paths in `runFiles` / `settings` must live inside the sandbox
  (preopened directories or the `MemFS` passed to `load()`). Prefer
  sandbox-absolute paths: relative paths resolve against the sandbox root,
  not against `workDir`.
- `get` / `toObject` navigate the JSON result, so `format: "yaml"` (JSON
  suppressed) leaves value access unavailable — read `yamlResult` instead.
- Subpackage imports (`import pkg` of a sibling directory, or paths given
  via `externalPkgs`) are not resolved inside the WASM sandbox.

## WASI sandbox limitations

The WASM artifact runs as a sandboxed WASI command, which imposes
restrictions that differ from the native KCL libraries:

- **Filesystem access is limited to WASI preopens.** File-based methods —
  `FormatPath`, `LintPath`, `LoadPackage`, `LoadSettingsFiles`, `Rename`,
  as well as `ParseProgram` / `ParseFile` (and
  `ExecProgram`) when they are given file paths instead of inline sources —
  can only reach paths that are mapped into the sandbox. With the default
  in-memory `MemFS` filesystem, paths outside the preopened directories do
  not exist; the wasm module can never access the host filesystem directly.
  Pass `preopens` (guest path -> filesystem path) and/or an `fs: new
MemFS()` instance to `load()` to set up the sandbox filesystem.
- **`KclService.UpdateDependencies` is not supported.** Resolving module
  dependencies requires network access and git subprocesses, which the
  WASI sandbox does not provide. The call returns a graceful
  `"ERROR:updating dependencies is not supported in the WASM build: ..."`
  string (the typed API turns it into a thrown `Error`) instead of
  downloading anything.
- **`KclService.ValidateCode`** validates inline `data` by writing a
  temporary file into the sandbox working directory (WASI has no temp
  directory); the file is removed automatically after the call.
- **`KclService.Rename`** works on sandbox files, but paths are normalized
  lexically: WASI preview1 has no `canonicalize`, so `.`/`..` segments are
  resolved without symlink resolution.
- **Errors are returned, not thrown, at the ABI level.** The low-level
  entry points report failures as strings starting with an `"ERROR:"`
  prefix (e.g. `invokeKCLRun`, `invokeKCLCall`); the typed API layer turns
  them into thrown `Error`s.
- **`panic = abort` destroys the whole instance.** The module is built
  single-threaded with `panic=abort`, so a Rust panic aborts the instance
  instead of unwinding: every subsequent call traps with
  `unreachable`. Panics can still occur where the native libraries return
  an error — notably unknown method names and KCL runtime errors raised as
  panics in the evaluator (e.g. a failing `check` block during
  `ExecProgram`). The typed API surfaces the trap as a thrown `Error`;
  discard the instance and create a fresh one with `load()`.
- **Plugins work, but a plugin failure kills the instance.** See
  [Plugins](#plugins) above: the callout path is fully implemented, and the
  `panic=abort` caveat above applies to plugin errors specifically, because
  the runtime reports them by panicking.
- **`Generate*` and `FormatTestReport` are implemented but not yet
  available from the bundled artifact.** The prebuilt `kcl.wasm` in this
  package registers 24 RPC methods (see `listMethod`) and none of them is
  `KclService.GenerateToml` / `GenerateKcl` / `GenerateOpenAPI` /
  `GenerateProto` / `GenerateDoc` / `FormatTestReport`; it predates them.
  The wrappers are complete and their request encoding is covered by
  `tests/generate_api.test.ts`, but calling one against this artifact traps
  the instance rather than returning an error. The cross-language
  consistency runner reports those cases as skipped for the same reason.

### Rust

```shell
cargo add kcl-wasm-lib --git https://github.com/kcl-lang/lib
cargo add anyhow
```

```rust
use anyhow::Result;
use kcl_wasm_lib::{KCLModule, RunOptions};

fn main() -> Result<()> {
    let opts = RunOptions {
        filename: "test.k".to_string(),
        source: "a = 1".to_string(),
    };
    let mut module = KCLModule::from_path("path/to/kcl.wasm")?;
    let result = module.run(&opts)?;
    println!("{}", result);
    Ok(())
}
```

### Go

```go
package main

import (
	"fmt"

	"github.com/kcl-lang/wasm-lib/pkg/module"
)

func main() {
	m, err := module.New("../../kcl.wasm")
	if err != nil {
		panic(err)
	}
	result, err := m.Run(&module.RunOptions{
		Filename: "test.k",
		Source:   "a = 1",
	})
	if err != nil {
		panic(err)
	}
	fmt.Println(result)
}
```

## Developing

- Install `node.js`
- Install dependencies

```shell
npm install
```

### Building

```shell
npm run build
```

### Testing

```shell
npm run test
```

### Format

```shell
npm run format
```

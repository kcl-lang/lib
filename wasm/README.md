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

For all KCL service methods except `ExecProgram` and `FormatCode` (already
covered by `invokeKCLRun` / `invokeKCLFmt`), the package ships typed
TypeScript wrappers that handle the protobuf encoding/decoding for you:

`ping`, `getVersion`, `parseProgram`, `parseFile`, `loadPackage`,
`listOptions`, `listVariables`, `overrideFile`, `getSchemaTypeMapping`,
`getSchemaTypeMappingUnderPath`, `formatPath`, `lintPath`, `validateCode`,
`loadSettingsFiles`, `rename`, `renameCode`, `test` and
`updateDependencies`.

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
- **No plugin agent.** `kcl_plugin_invoke_json_wasm` is a stub that always
  returns `0`, so KCL plugins and the plugin-agent entry point
  (`call_with_plugin_agent`) are not supported by the WASM binding.

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

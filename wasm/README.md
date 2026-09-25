# KCL WASM Library for Node.js and Browser

## Quick Start

### Node.js

```shell
npm install @kcl-lang/wasm-lib
```

```typescript
import { load, invokeKCLRun } from "@kcl-lang/wasm-lib";

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
import { load, invokeKCLCall, invokeKCLVersion } from "@kcl-lang/wasm-lib";

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

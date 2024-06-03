# KCL WASM Library for Node.js and Browser

## Quick Start

### Node.js

```shell
npm install @kcl-lang/wasm-lib
```

```typescript
import { load, invokeKCLRun } from '@kcl-lang/wasm-lib'

async function main() {
  const inst = await load();
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  console.log(result)
}

main()
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

## Developing

- Install `node.js`
- Install dependencies

```shell
npm install
```

### Building

```shell
npm run compile
```

### Testing

```shell
npm run test
```

### Format

```shell
npm run format
```

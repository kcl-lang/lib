# KCL WASM Library for Node.js and Browser

## Installation

```shell
npm install @kcl-lang/wasm-lib
```

## Quick Start

### Node.js

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

See [here](./examples/rust/src/main.rs)

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

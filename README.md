# KCL Artifact for SDKs

## Rust

### How to Use

```shell
cargo add kcl-lang
```

Write the Code

```rust
use kcl_lang::*;
use anyhow::Result;

fn main() -> Result<()> {
    let api = API::new()?;
    let args = &ExecProgramArgs {
        k_filename_list: vec!["main.k".to_string()],
        k_code_list: vec!["a = 1".to_string()],
        ..Default::default()
    };
    let exec_result = api.exec_program(args)?;
    println!("{}", exec_result.yaml_result);
    Ok(())
}
```

## Go

### How to Use

```shell
go get kcl-lang.io/kcl-artifact-go
```

Write the Code

```go
package main

import (
	artifact "kcl-lang.io/kcl-artifact-go"
)

func main() {
    path = "path/to/install"
    _ := artifact.InstallKclvm(path)
}
```

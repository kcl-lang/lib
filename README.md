# KCL Artifact for SDKs

## Rust

### How to Use

```shell
cargo add --git https://github.com/kcl-lang/lib --branch main
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
go get kcl-lang.io/lib
```

Write the Code

```go
package main

import (
	artifact "kcl-lang.io/lib"
)

func main() {
    path = "path/to/install"
    _ := artifact.InstallKclvm(path)
}
```

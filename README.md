# KCL Artifact for SDKs

## Rust

### How to Use

```shell
cargo add kcl
```

Write the Code

```rust
use kcl_lang::*;
use std::path::Path;
use anyhow::Result;

fn main() -> Result<()> {
    let api = API::new()?;
    let args = &ExecProgramArgs {
        work_dir: Path::new(".").join("src").join("testdata").canonicalize().unwrap().display().to_string(),
        k_filename_list: vec!["test.k".to_string()],
        ..Default::default()
    };
    let exec_result = api.exec_program(args)?;
    assert_eq!(exec_result.yaml_result, "alice:\n  age: 18");
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

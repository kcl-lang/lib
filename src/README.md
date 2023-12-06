# KCL Rust SDK

KCL Rust SDK

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
    // File case
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

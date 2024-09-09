use crate::{FmtOptions, KCLModule, RunOptions};
use anyhow::Result;

const WASM_PATH: &str = "../../kcl.wasm";
const BENCH_COUNT: usize = 20;

#[test]
fn test_run() -> Result<()> {
    let opts = RunOptions {
        filename: "test.k".to_string(),
        source: "a = 1".to_string(),
    };
    let mut module = KCLModule::from_path(WASM_PATH)?;
    for _ in 0..BENCH_COUNT {
        let result = module.run(&opts)?;
        println!("{}", result);
    }
    Ok(())
}

#[test]
fn test_run_parse_error() -> Result<()> {
    let opts = RunOptions {
        filename: "test.k".to_string(),
        source: "a = ".to_string(),
    };
    let mut module = KCLModule::from_path(WASM_PATH)?;
    let result = module.run(&opts)?;
    println!("{}", result);
    Ok(())
}

#[test]
fn test_run_type_error() -> Result<()> {
    let opts = RunOptions {
        filename: "test.k".to_string(),
        source: "a: str = 1".to_string(),
    };
    let mut module = KCLModule::from_path(WASM_PATH)?;
    let result = module.run(&opts)?;
    println!("{}", result);
    Ok(())
}

#[test]
fn test_run_runtime_error() -> Result<()> {
    let opts = RunOptions {
        filename: "test.k".to_string(),
        source: "a = [][0]".to_string(),
    };
    let mut module = KCLModule::from_path(WASM_PATH)?;
    let result = module.run(&opts)?;
    println!("{}", result);
    Ok(())
}

#[test]
fn test_fmt() -> Result<()> {
    let opts = FmtOptions {
        source: "a = 1".to_string(),
    };
    let mut module = KCLModule::from_path(WASM_PATH)?;
    for _ in 0..BENCH_COUNT {
        let result = module.fmt(&opts)?;
        println!("{}", result);
    }
    Ok(())
}

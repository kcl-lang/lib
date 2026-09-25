use anyhow::Result;
use kcl_wasm_lib::{CallOptions, FmtOptions, KCLModule, RunOptions, RunWithLogMessageOptions};

const SOURCE: &str = r#"
schema Person:
  name: str

p = Person {name = "Alice"}"#;

fn main() -> Result<()> {
    let mut module = KCLModule::from_path("../../kcl.wasm")?;

    println!("--- run ---");
    let result = module.run(&RunOptions {
        filename: "test.k".to_string(),
        source: SOURCE.to_string(),
    })?;
    println!("{}", result);

    println!("--- fmt ---");
    let result = module.fmt(&FmtOptions {
        source: SOURCE.to_string(),
    })?;
    println!("{}", result);

    println!("--- run with log message ---");
    let result = module.run_with_log_message(&RunWithLogMessageOptions {
        filename: "test.k".to_string(),
        source: SOURCE.to_string(),
    })?;
    println!("{}", result);

    println!("--- version ---");
    println!("{}", module.version()?);

    println!("--- call KclService.Ping ---");
    // PingArgs{value: "hello-kcl"}: field 1 (string) tag 0x0a, length 9.
    let mut ping_args = vec![0x0a, 0x09];
    ping_args.extend_from_slice(b"hello-kcl");
    let result = module.call(&CallOptions {
        method_name: "KclService.Ping".to_string(),
        args: ping_args,
    })?;
    println!("{:?}", result);

    Ok(())
}

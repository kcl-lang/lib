use anyhow::{anyhow, Result};
use kclvm_evaluator::Evaluator;
use kclvm_loader::{load_packages, LoadPackageOptions};
use kclvm_parser::LoadProgramOptions;
use kclvm_runtime::{Context, IndexMap, PluginFunction, ValueRef};
use std::{cell::RefCell, rc::Rc, sync::Arc};

fn my_plugin_sum(_: &Context, args: &ValueRef, _: &ValueRef) -> Result<ValueRef> {
    let a = args
        .arg_i_int(0, Some(0))
        .ok_or(anyhow!("expect int value for the first param"))?;
    let b = args
        .arg_i_int(1, Some(0))
        .ok_or(anyhow!("expect int value for the second param"))?;
    Ok((a + b).into())
}

fn context_with_plugin() -> Rc<RefCell<Context>> {
    let mut plugin_functions: IndexMap<String, PluginFunction> = Default::default();
    let func = Arc::new(my_plugin_sum);
    plugin_functions.insert("my_plugin.add".to_string(), func);
    let mut ctx = Context::new();
    ctx.plugin_functions = plugin_functions;
    Rc::new(RefCell::new(ctx))
}

#[test]
fn test_exec_with_plugin() -> Result<()> {
    let src = r#"
import kcl_plugin.my_plugin

sum = my_plugin.add(1, 1)
"#;
    let p = load_packages(&LoadPackageOptions {
        paths: vec!["test.k".to_string()],
        load_opts: Some(LoadProgramOptions {
            load_plugins: true,
            k_code_list: vec![src.to_string()],
            ..Default::default()
        }),
        load_builtin: false,
        ..Default::default()
    })?;
    let evaluator = Evaluator::new_with_runtime_ctx(&p.program, context_with_plugin());
    let result = evaluator.run()?;
    println!("yaml result {}", result.1);
    Ok(())
}

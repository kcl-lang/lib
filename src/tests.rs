use crate::*;
use anyhow::{Result, anyhow};
use kcl_evaluator::Evaluator;
use kcl_loader::{LoadPackageOptions, load_packages};
use kcl_parser::LoadProgramOptions;
use kcl_primitives::IndexMap;
use kcl_runtime::{Context, PluginFunction, ValueRef};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
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

fn testdata() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("testdata")
}

fn temp_workspace(name: &str) -> Result<PathBuf> {
    let dir = std::env::temp_dir().join(format!("kcl_lang_{name}_{}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir)?;
    Ok(dir)
}

fn copy_dir(src: &std::path::Path, dst: &std::path::Path) -> Result<()> {
    fs::create_dir_all(dst)?;
    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let to = dst.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            copy_dir(&entry.path(), &to)?;
        } else {
            fs::copy(entry.path(), &to)?;
        }
    }
    Ok(())
}

#[test]
fn test_ping() -> Result<()> {
    let api = API::default();
    let result = api.ping(&PingArgs {
        value: "hello".to_string(),
    })?;
    assert_eq!(result.value, "hello");
    Ok(())
}

#[test]
fn test_get_version() -> Result<()> {
    let api = API::default();
    let result = api.get_version(&GetVersionArgs {})?;
    assert!(!result.version.is_empty());
    assert!(result.version_info.contains("Version"));
    assert!(result.version_info.contains("GitCommit"));
    Ok(())
}

#[test]
fn test_parse_program() -> Result<()> {
    let api = API::default();
    let result = api.parse_program(&ParseProgramArgs {
        paths: vec![testdata().join("test.k").display().to_string()],
        ..Default::default()
    })?;
    assert_eq!(result.paths.len(), 1);
    assert!(result.errors.is_empty());
    assert!(result.ast_json.contains("Person"));
    Ok(())
}

#[test]
fn test_parse_file() -> Result<()> {
    let api = API::default();
    let result = api.parse_file(&ParseFileArgs {
        path: testdata().join("test.k").display().to_string(),
        ..Default::default()
    })?;
    assert!(result.deps.is_empty());
    assert!(result.errors.is_empty());
    assert!(result.ast_json.contains("Person"));
    Ok(())
}

#[test]
fn test_load_package() -> Result<()> {
    let api = API::default();
    let result = api.load_package(&LoadPackageArgs {
        parse_args: Some(ParseProgramArgs {
            paths: vec![testdata().join("test.k").display().to_string()],
            ..Default::default()
        }),
        resolve_ast: true,
        ..Default::default()
    })?;
    assert!(result.parse_errors.is_empty());
    assert!(result.symbols.values().any(|s| {
        s.ty.as_ref()
            .map(|t| t.schema_name == "Person")
            .unwrap_or(false)
    }));
    Ok(())
}

#[test]
fn test_list_options() -> Result<()> {
    let api = API::default();
    let result = api.list_options(&ParseProgramArgs {
        sources: vec![
            r#"
a = option("key1")
b = option("key2", required=True)
c = {
    metadata.key = option("metadata-key")
}
"#
            .to_string(),
        ],
        ..Default::default()
    })?;
    assert_eq!(result.options.len(), 3);
    assert_eq!(result.options[0].name, "key1");
    assert_eq!(result.options[1].name, "key2");
    assert_eq!(result.options[2].name, "metadata-key");
    assert!(result.options[1].required);
    Ok(())
}

#[test]
fn test_list_variables() -> Result<()> {
    let api = API::default();
    let result = api.list_variables(&ListVariablesArgs {
        files: vec![testdata().join("test.k").display().to_string()],
        ..Default::default()
    })?;
    assert!(result.parse_errors.is_empty());
    let variables = result
        .variables
        .get("alice")
        .ok_or(anyhow!("expect the variable `alice`"))?;
    assert!(variables.variables[0].value.contains("Person"));
    Ok(())
}

#[test]
fn test_exec_program() -> Result<()> {
    let api = API::default();
    let result = api.exec_program(&ExecProgramArgs {
        work_dir: testdata().display().to_string(),
        k_filename_list: vec!["test.k".to_string()],
        ..Default::default()
    })?;
    assert_eq!(result.yaml_result, "alice:\n  age: 18");
    assert_eq!(result.json_result, "{\"alice\": {\"age\": 18}}");
    Ok(())
}

#[test]
fn test_exec_program_failed() -> Result<()> {
    let api = API::default();
    let result = api.exec_program(&ExecProgramArgs {
        k_filename_list: vec!["invalid_file.k".to_string()],
        ..Default::default()
    });
    assert!(result.is_err());
    assert!(
        result
            .unwrap_err()
            .to_string()
            .contains("Cannot find the kcl file")
    );
    Ok(())
}

#[test]
fn test_exec_program_with_print() -> Result<()> {
    let api = API::default();
    let result = api.exec_program(&ExecProgramArgs {
        work_dir: testdata().display().to_string(),
        k_filename_list: vec!["hello_with_print.k".to_string()],
        ..Default::default()
    })?;
    assert_eq!(result.yaml_result, "a: 1");
    assert!(result.log_message.contains("Hello world"));
    Ok(())
}

#[test]
fn test_exec_program_sourcemap_output() -> Result<()> {
    let api = API::default();
    let dir = temp_workspace("sourcemap")?;
    let map_path = dir.join("out.yaml.map");
    let result = api.exec_program(&ExecProgramArgs {
        work_dir: testdata().display().to_string(),
        k_filename_list: vec!["test.k".to_string()],
        sourcemap_output: Some(map_path.display().to_string()),
        ..Default::default()
    })?;
    let sourcemap = result
        .sourcemap
        .as_ref()
        .ok_or(anyhow!("expect a sourcemap when sourcemap_output is set"))?;
    let map: serde_json::Value = serde_json::from_str(sourcemap)?;
    assert_eq!(map["version"], 3);
    assert_eq!(map["file"], map_path.display().to_string());
    assert!(map["sources"][0].as_str().unwrap().ends_with("test.k"));
    assert!(
        map["names"]
            .as_array()
            .unwrap()
            .iter()
            .any(|n| n.as_str() == Some("alice"))
    );
    Ok(())
}

#[test]
fn test_exec_program_emit_attribute_metadata() -> Result<()> {
    let api = API::default();
    let result = api.exec_program(&ExecProgramArgs {
        work_dir: testdata().display().to_string(),
        k_filename_list: vec!["test.k".to_string()],
        emit_attribute_metadata: true,
        ..Default::default()
    })?;
    assert_eq!(result.yaml_result, "alice:\n  age: 18");
    Ok(())
}

#[test]
fn test_override_file() -> Result<()> {
    let api = API::default();
    let dir = temp_workspace("override_file")?;
    let file = dir.join("test.k");
    fs::copy(testdata().join("test.k"), &file)?;
    let result = api.override_file(&OverrideFileArgs {
        file: file.display().to_string(),
        specs: vec!["alice.age=20".to_string()],
        ..Default::default()
    })?;
    assert!(result.result);
    assert!(result.parse_errors.is_empty());
    assert!(fs::read_to_string(&file)?.contains("20"));
    Ok(())
}

#[test]
fn test_get_schema_type_mapping() -> Result<()> {
    let api = API::default();
    let result = api.get_schema_type_mapping(&GetSchemaTypeMappingArgs {
        exec_args: Some(ExecProgramArgs {
            work_dir: testdata().display().to_string(),
            k_filename_list: vec!["test.k".to_string()],
            ..Default::default()
        }),
        ..Default::default()
    })?;
    let alice = result
        .schema_type_mapping
        .get("alice")
        .ok_or(anyhow!("expect the schema type of `alice`"))?;
    assert_eq!(alice.schema_name, "Person");
    assert_eq!(
        alice.properties.get("age").map(|t| t.r#type.as_str()),
        Some("int")
    );
    Ok(())
}

#[test]
fn test_get_schema_type_mapping_under_path() -> Result<()> {
    let api = API::default();
    let root = testdata().join("get_schema_ty");
    let result = api.get_schema_type_mapping_under_path(&GetSchemaTypeMappingArgs {
        exec_args: Some(ExecProgramArgs {
            k_filename_list: vec![root.join("aaa").display().to_string()],
            external_pkgs: vec![
                ExternalPkg {
                    pkg_name: "bbb".to_string(),
                    pkg_path: root.join("bbb").display().to_string(),
                },
                ExternalPkg {
                    pkg_name: "ccc".to_string(),
                    pkg_path: root.join("ccc").display().to_string(),
                },
            ],
            ..Default::default()
        }),
        ..Default::default()
    })?;
    let bbb = result
        .schema_type_mapping
        .get("bbb")
        .ok_or(anyhow!("expect the schemas of the package `bbb`"))?;
    let b = bbb
        .schema_type
        .iter()
        .find(|t| t.schema_name == "B")
        .ok_or(anyhow!("expect the schema `B` in the package `bbb`"))?;
    assert_eq!(b.pkg_path, "bbb");
    assert!(result.schema_type_mapping.contains_key("ccc"));
    Ok(())
}

#[test]
fn test_format_code() -> Result<()> {
    let api = API::default();
    let result = api.format_code(&FormatCodeArgs {
        source: "schema Person:\n    name:   str\n    age:    int\n\n    check:\n        0 <   age <   120\n"
            .to_string(),
        ..Default::default()
    })?;
    assert_eq!(
        String::from_utf8(result.formatted)?,
        "schema Person:\n    name: str\n    age: int\n\n    check:\n        0 < age < 120\n"
    );
    Ok(())
}

#[test]
fn test_format_path() -> Result<()> {
    let api = API::default();
    let dir = temp_workspace("format_path")?;
    let file = dir.join("test.k");
    fs::write(&file, "a=1\n")?;
    let result = api.format_path(&FormatPathArgs {
        path: file.display().to_string(),
        ..Default::default()
    })?;
    assert_eq!(result.changed_paths.len(), 1);
    assert!(result.changed_paths[0].ends_with("test.k"));
    assert_eq!(fs::read_to_string(&file)?, "a = 1\n");
    Ok(())
}

#[test]
fn test_lint_path() -> Result<()> {
    let api = API::default();
    let result = api.lint_path(&LintPathArgs {
        paths: vec![testdata().join("test-lint.k").display().to_string()],
        ..Default::default()
    })?;
    assert!(
        result
            .results
            .iter()
            .any(|r| r.contains("Module 'math' imported but unused"))
    );
    Ok(())
}

#[test]
fn test_validate_code() -> Result<()> {
    let api = API::default();
    let result = api.validate_code(&ValidateCodeArgs {
        code: "schema Person:\n    name: str\n    age: int\n\n    check:\n        0 < age < 120\n"
            .to_string(),
        data: "{\"name\": \"Alice\", \"age\": 10}".to_string(),
        format: "json".to_string(),
        ..Default::default()
    })?;
    assert!(result.success);
    assert_eq!(result.err_message, "");
    Ok(())
}

#[test]
fn test_load_settings_files() -> Result<()> {
    let api = API::default();
    let result = api.load_settings_files(&LoadSettingsFilesArgs {
        work_dir: testdata().display().to_string(),
        files: vec![
            testdata()
                .join("settings")
                .join("kcl.yaml")
                .display()
                .to_string(),
        ],
    })?;
    let kcl_cli_configs = result
        .kcl_cli_configs
        .ok_or(anyhow!("expect kcl_cli_configs"))?;
    assert!(kcl_cli_configs.files.is_empty());
    assert!(kcl_cli_configs.strict_range_check);
    assert_eq!(result.kcl_options.len(), 1);
    assert_eq!(result.kcl_options[0].key, "key");
    assert_eq!(result.kcl_options[0].value, "\"value\"");
    Ok(())
}

#[test]
fn test_rename() -> Result<()> {
    let api = API::default();
    let dir = temp_workspace("rename")?;
    let file = dir.join("main.k");
    fs::copy(testdata().join("rename").join("main.bak"), &file)?;
    let result = api.rename(&RenameArgs {
        package_root: dir.display().to_string(),
        symbol_path: "a".to_string(),
        file_paths: vec![file.display().to_string()],
        new_name: "a2".to_string(),
    })?;
    assert_eq!(result.changed_files.len(), 1);
    assert!(
        result.changed_files[0]
            .replace('\\', "/")
            .ends_with("main.k")
    );
    let content = fs::read_to_string(&file)?;
    assert!(content.contains("a2 = 1"));
    assert!(content.contains("b = a2"));
    Ok(())
}

#[test]
fn test_rename_code() -> Result<()> {
    let api = API::default();
    let result = api.rename_code(&RenameCodeArgs {
        package_root: "/mock/path".to_string(),
        symbol_path: "a".to_string(),
        source_codes: HashMap::from([(
            "/mock/path/main.k".to_string(),
            "a = 1\nb = a".to_string(),
        )]),
        new_name: "a2".to_string(),
    })?;
    assert_eq!(
        result
            .changed_codes
            .get("/mock/path/main.k")
            .map(String::as_str),
        Some("a2 = 1\nb = a2")
    );
    Ok(())
}

#[test]
fn test_testing() -> Result<()> {
    let api = API::default();
    // The test runner writes a `_kcl_test_<pid>.k` shim into the package
    // directory, so run against a private copy to stay parallel-safe.
    let module = temp_workspace("testing")?.join("testing");
    copy_dir(&testdata().join("testing"), &module)?;
    let result = api.test(&TestArgs {
        pkg_list: vec![format!("{}/...", module.display())],
        ..Default::default()
    })?;
    assert_eq!(result.info.len(), 2);
    assert!(result.info.iter().all(|i| i.error.is_empty()));
    if let Some(coverage) = &result.coverage {
        assert!(coverage.files.is_empty());
    }
    Ok(())
}

#[test]
fn test_testing_coverage() -> Result<()> {
    let api = API::default();
    let module = temp_workspace("testing_coverage")?.join("testing");
    copy_dir(&testdata().join("testing"), &module)?;
    let result = api.test(&TestArgs {
        pkg_list: vec![format!("{}/...", module.display())],
        coverage: true,
        ..Default::default()
    })?;
    assert_eq!(result.info.len(), 2);
    assert!(result.info.iter().all(|i| !i.line_hits.is_empty()));
    let coverage = result
        .coverage
        .as_ref()
        .ok_or(anyhow!("expect coverage report"))?;
    assert!(!coverage.files.is_empty());
    let summary = coverage
        .summary
        .as_ref()
        .ok_or(anyhow!("expect coverage summary"))?;
    assert!(summary.covered > 0);
    assert!(summary.percent > 0.0);
    Ok(())
}

#[test]
fn test_update_dependencies() -> Result<()> {
    let api = API::default();
    let dir = temp_workspace("update_dependencies")?;
    fs::write(
        dir.join("kcl.mod"),
        "[package]\nname = \"test_deps\"\nversion = \"0.0.1\"\n",
    )?;
    let result = api.update_dependencies(&UpdateDependenciesArgs {
        manifest_path: dir.display().to_string(),
        ..Default::default()
    })?;
    assert!(result.external_pkgs.is_empty());
    Ok(())
}

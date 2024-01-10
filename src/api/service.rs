use anyhow::Result;

use super::spec::*;

pub trait Service {
    /// Execute KCL file with args. **Note that it is not thread safe.**
    ///
    /// # Examples
    ///
    /// ```
    /// use kcl_lang::*;
    /// use std::path::Path;
    /// // File case
    /// let api = API::new().unwrap();
    /// let args = &ExecProgramArgs {
    ///     work_dir: Path::new(".").join("testdata").canonicalize().unwrap().display().to_string(),
    ///     k_filename_list: vec!["test.k".to_string()],
    ///     ..Default::default()
    /// };
    /// let exec_result = api.exec_program(args).unwrap();
    /// assert_eq!(exec_result.yaml_result, "alice:\n  age: 18");
    ///
    /// // Code case
    /// let args = &ExecProgramArgs {
    ///     k_filename_list: vec!["file.k".to_string()],
    ///     k_code_list: vec!["alice = {age = 18}".to_string()],
    ///     ..Default::default()
    /// };
    /// let exec_result = api.exec_program(args).unwrap();
    /// assert_eq!(exec_result.yaml_result, "alice:\n  age: 18");
    ///
    /// // Error case
    /// let args = &ExecProgramArgs {
    ///     k_filename_list: vec!["invalid_file.k".to_string()],
    ///     ..Default::default()
    /// };
    /// let error = api.exec_program(args).unwrap_err();
    /// assert!(error.to_string().contains("Cannot find the kcl file"), "{error}");
    ///
    /// let args = &ExecProgramArgs {
    ///     k_filename_list: vec![],
    ///     ..Default::default()
    /// };
    /// let error = api.exec_program(args).unwrap_err();
    /// assert!(error.to_string().contains("No input KCL files or paths"), "{error}");
    /// ```
    fn exec_program(&self, args: &ExecProgramArgs) -> Result<ExecProgramResult>;

    /// Override KCL file with args
    ///
    /// # Examples
    ///
    /// ```
    /// use kcl_lang::*;
    ///
    /// let api = API::new().unwrap();
    /// let args = &OverrideFileArgs {
    ///     file: "./testdata/test.k".to_string(),
    ///     specs: vec!["alice.age=18".to_string()],
    ///     import_paths: vec![],
    ///     ..Default::default()
    /// };
    /// let override_result = api.override_file(args).unwrap();
    /// assert!(override_result.result);
    /// ```
    ///
    ///  - test.k (after override)
    ///
    /// ```kcl
    /// schema Person:
    ///     age: int
    ///
    /// alice = Person {
    ///     age = 18
    /// }
    /// ```
    fn override_file(&self, args: &OverrideFileArgs) -> Result<OverrideFileResult>;
    /// Service for getting the full schema type list.
    ///
    /// # Examples
    ///
    /// ```
    /// use kcl_lang::*;
    /// use std::path::Path;
    ///
    /// let api = API::new().unwrap();
    /// let work_dir_parent = Path::new(".").join("testdata").join("get_schema_ty");
    /// let args = ExecProgramArgs {
    ///     work_dir: work_dir_parent.join("aaa").canonicalize().unwrap().display().to_string(),
    ///     k_filename_list: vec![
    ///         work_dir_parent.join("aaa").join("main.k").canonicalize().unwrap().display().to_string()
    ///     ],
    ///     external_pkgs: vec![
    ///         CmdExternalPkgSpec{
    ///             pkg_name:"bbb".to_string(),
    ///             pkg_path: work_dir_parent.join("bbb").canonicalize().unwrap().display().to_string()
    ///         }
    ///     ],
    ///     ..Default::default()
    /// };
    ///
    /// let result = api.get_full_schema_type(&GetFullSchemaTypeArgs {
    ///     exec_args: Some(args),
    ///     schema_name: "a".to_string()
    /// }).unwrap();
    /// assert_eq!(result.schema_type_list.len(), 1);
    /// ```
    fn get_full_schema_type(&self, args: &GetFullSchemaTypeArgs) -> Result<GetSchemaTypeResult>;

    /// Service for formatting a code source and returns the formatted source and
    /// whether the source is changed.
    ///
    /// # Examples
    ///
    /// ```
    /// use kcl_lang::*;
    ///
    /// let api = API::new().unwrap();
    /// let source = r#"schema Person:
    ///     name: str
    ///     age: int
    ///
    /// person = Person {
    ///     name = "Alice"
    ///     age = 18
    /// }
    ///
    /// "#.to_string();
    /// let result = api.format_code(&FormatCodeArgs {
    ///     source: source.clone(),
    ///     ..Default::default()
    /// }).unwrap();
    /// assert_eq!(result.formatted, source.as_bytes().to_vec());
    /// ```
    fn format_code(&self, args: &FormatCodeArgs) -> Result<FormatCodeResult>;

    /// Service for formatting kcl file or directory path contains kcl files and
    /// returns the changed file paths.
    ///
    /// # Examples
    ///
    /// ```
    /// use kcl_lang::*;
    ///
    /// let api = API::new().unwrap();
    /// let result = api.format_path(&FormatPathArgs {
    ///     path: "./testdata/test.k".to_string(),
    ///     ..Default::default()
    /// }).unwrap();
    /// ```
    fn format_path(&self, args: &FormatPathArgs) -> Result<FormatPathResult>;

    /// Service for KCL Lint API, check a set of files, skips execute,
    /// returns error message including errors and warnings.
    ///
    /// # Examples
    ///
    /// ```
    /// use kcl_lang::*;
    ///
    /// let api = API::new().unwrap();
    /// let result = api.lint_path(&LintPathArgs {
    ///     paths: vec!["./testdata/test-lint.k".to_string()],
    ///     ..Default::default()
    /// }).unwrap();
    /// assert_eq!(result.results, vec!["Module 'math' imported but unused".to_string()]);
    /// ```
    fn lint_path(&self, args: &LintPathArgs) -> Result<LintPathResult>;

    /// Service for validating the data string using the schema code string, when the parameter
    /// `schema` is omitted, use the first schema appeared in the kcl code.
    ///
    /// **Note that it is not thread safe.**
    ///
    /// # Examples
    ///
    /// ```no_run
    /// use kcl_lang::*;
    ///
    /// let api = API::new().unwrap();
    /// let code = r#"
    /// schema Person:
    ///     name: str
    ///     age: int
    ///
    ///     check:
    ///         0 < age < 120
    /// "#.to_string();
    /// let data = r#"
    /// {
    ///     "name": "Alice",
    ///     "age": 10
    /// }
    /// "#.to_string();
    /// let err_data = r#"
    /// {
    ///     "name": "Alice",
    ///     "age": 130
    /// }
    /// "#.to_string();
    /// let result = api.validate_code(&ValidateCodeArgs {
    ///     code: code.clone(),
    ///     data,
    ///     ..Default::default()
    /// }).unwrap();
    /// assert_eq!(result.success, true);
    /// let result = api.validate_code(&ValidateCodeArgs {
    ///     code,
    ///     data: err_data,
    ///     ..Default::default()
    /// }).unwrap();
    /// assert_eq!(result.success, false);
    /// ```
    fn validate_code(&self, args: &ValidateCodeArgs) -> Result<ValidateCodeResult>;

    /// Service for building setting file config from args.
    ///
    /// # Examples
    ///
    /// ```
    /// use kcl_lang::*;
    ///
    /// let api = API::new().unwrap();
    /// let result = api.load_settings_files(&LoadSettingsFilesArgs {
    ///     files: vec!["./testdata/settings/kcl.yaml".to_string()],
    ///     work_dir: "./testdata/settings".to_string(),
    ///     ..Default::default()
    /// }).unwrap();
    /// assert_eq!(result.kcl_options.len(), 1);
    /// ```
    fn load_settings_files(&self, args: &LoadSettingsFilesArgs) -> Result<LoadSettingsFilesResult>;

    /// Service for renaming all the occurrences of the target symbol in the files. This API will rewrite files if they contain symbols to be renamed.
    /// return the file paths got changed.
    ///
    /// # Examples
    ///
    /// ```
    /// use kcl_lang::*;
    /// # use std::path::PathBuf;
    /// # use std::fs;
    /// #
    /// # let api = API::new().unwrap();
    /// # // before test, load template from .bak
    /// # let path = PathBuf::from(".").join("testdata").join("rename_doc").join("main.k");
    /// # let backup_path = path.with_extension("bak");
    /// # let content = fs::read_to_string(backup_path.clone()).unwrap();
    /// # fs::write(path.clone(), content).unwrap();
    ///
    /// let result = api.rename(&RenameArgs {
    ///     package_root: "./testdata/rename_doc".to_string(),
    ///     symbol_path: "a".to_string(),
    ///     file_paths: vec!["./testdata/rename_doc/main.k".to_string()],
    ///     new_name: "a2".to_string(),
    /// }).unwrap();
    /// assert_eq!(result.changed_files.len(), 1);
    ///
    /// # // after test, restore template from .bak
    /// # fs::remove_file(path.clone()).unwrap();
    /// ```
    fn rename(&self, args: &RenameArgs) -> Result<RenameResult>;

    /// Service for renaming all the occurrences of the target symbol and rename them. This API won't rewrite files but return the modified code if any code has been changed.
    /// return the changed code.
    ///
    /// # Examples
    ///
    /// ```
    /// use kcl_lang::*;
    ///
    /// let api = API::new().unwrap();
    /// let result = api.rename_code(&RenameCodeArgs {
    ///     package_root: "./testdata/rename".to_string(),
    ///     symbol_path: "a".to_string(),
    ///     source_codes: vec![("main.k".to_string(), "a = 1\nb = a".to_string())].into_iter().collect(),
    ///     new_name: "a2".to_string(),
    /// }).unwrap();
    /// assert_eq!(result.changed_codes.len(), 1);
    /// ```
    fn rename_code(&self, args: &RenameCodeArgs) -> Result<RenameCodeResult>;

    /// Service for the testing tool.
    ///
    /// # Examples
    ///
    /// ```
    /// use kcl_lang::*;
    ///
    /// let api = API::new().unwrap();
    /// let result = api.test(&TestArgs {
    ///     pkg_list: vec!["./testdata/testing/module/...".to_string()],
    ///     ..TestArgs::default()
    /// }).unwrap();
    /// assert_eq!(result.info.len(), 2);
    /// // Passed case
    /// assert!(result.info[0].error.is_empty());
    /// // Failed case
    /// assert!(result.info[1].error.is_empty());
    /// ```
    fn test(&self, args: &TestArgs) -> Result<TestResult>;
}

/// Specific implementation of calling service
#[derive(Debug, Clone, Default)]
pub(crate) struct ServiceHandler {
    _agent: u64,
}

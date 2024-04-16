use std::collections::HashMap;

use napi::bindgen_prelude::Reference;

#[napi(object)]
pub struct CmdExternalPkgSpec {
    pub pkg_name: String,
    pub pkg_path: String,
}

/// kcl main.k -D name=value
#[napi(object)]
pub struct CmdArgSpec {
    pub name: String,
    pub value: String,
}

#[napi(object)]
pub struct CmdOverrideSpec {
    pub pkgpath: String,
    pub field_path: String,
    pub field_value: String,
    pub action: String,
}

#[napi(object)]
pub struct Error {
    pub level: String,
    pub code: String,
    pub messages: Vec<Message>,
}

#[napi(object)]
pub struct Message {
    pub msg: String,
    pub pos: Option<Position>,
}

#[napi(object)]
pub struct PingArgs {
    pub value: String,
}

#[napi(object)]
pub struct PingResult {
    pub value: String,
}

/// empty
#[napi(object)]
pub struct ListMethodArgs {}

#[napi(object)]
pub struct ListMethodResult {
    pub method_name_list: Vec<String>,
}

#[napi(object)]
pub struct ParseFileArgs {
    pub path: String,
    pub source: String,
    pub external_pkgs: Vec<CmdExternalPkgSpec>,
}

#[napi(object)]
pub struct ParseFileResult {
    /// JSON string value
    pub ast_json: String,
    /// file dependency paths
    pub deps: Vec<String>,
    /// Parse errors
    pub errors: Vec<Error>,
}

#[napi(object)]
pub struct ParseProgramArgs {
    pub paths: Vec<String>,
    pub sources: Vec<String>,
    /// External packages path
    pub external_pkgs: Vec<CmdExternalPkgSpec>,
}

#[napi(object)]
pub struct ParseProgramResult {
    /// JSON string value
    pub ast_json: String,
    /// Returns the files in the order they should be compiled
    pub paths: Vec<String>,
    /// Parse errors
    pub errors: Vec<Error>,
}

#[napi(object)]
pub struct LoadPackageResult {
    /// JSON string value
    pub program: String,
    /// Returns the files in the order they should be compiled
    pub paths: Vec<String>,
    /// Parse errors
    pub parse_errors: Vec<Error>,
    /// Type errors
    pub type_errors: Vec<Error>,
    /// Map key is the ScopeIndex json string.
    pub scopes: HashMap<String, Scope>,
    /// Map key is the SymbolIndex json string.
    pub symbols: HashMap<String, Symbol>,
    /// Map key is the AST index UUID string.
    pub node_symbol_map: HashMap<String, SymbolIndex>,
    /// Map key is the SymbolIndex json string.
    pub symbol_node_map: HashMap<String, String>,
    /// Map key is the fully_qualified_name e.g. `pkg.Name`
    pub fully_qualified_name_map: HashMap<String, SymbolIndex>,
    /// Map key is the package path.
    pub pkg_scope_map: HashMap<String, ScopeIndex>,
}

#[napi(object)]
pub struct ListOptionsResult {
    /// Returns the files in the order they should be compiled
    pub options: Vec<OptionHelp>,
}

#[napi(object)]
pub struct OptionHelp {
    pub name: String,
    pub r#type: String,
    pub required: bool,
    pub default_value: String,
    pub help: String,
}

#[napi(object)]
pub struct Symbol {
    pub ty: Option<String>,
    pub name: String,
    pub owner: Option<SymbolIndex>,
    pub def: Option<SymbolIndex>,
    pub attrs: Vec<SymbolIndex>,
    pub is_global: bool,
}

#[napi(object)]
pub struct Scope {
    pub kind: String,
    pub parent: Option<ScopeIndex>,
    pub owner: Option<SymbolIndex>,
    pub children: Vec<ScopeIndex>,
    pub defs: Vec<SymbolIndex>,
}

#[napi(object)]
pub struct SymbolIndex {
    pub i: u32,
    pub g: u32,
    pub kind: String,
}

#[napi(object)]
pub struct ScopeIndex {
    pub i: u32,
    pub g: u32,
    pub kind: String,
}

#[napi(object)]
pub struct ExecProgramResult {
    pub json_result: String,
    pub yaml_result: String,
    pub log_message: String,
    pub err_message: String,
}

#[napi(object)]
pub struct BuildProgramResult {
    pub path: String,
}

#[napi(object)]
pub struct ResetPluginArgs {
    pub plugin_root: String,
}

/// empty
#[napi(object)]
pub struct ResetPluginResult {}

#[napi(object)]
pub struct FormatCodeArgs {
    pub source: String,
}

#[napi(object)]
pub struct FormatCodeResult {
    pub formatted: Vec<u8>,
}

#[napi(object)]
pub struct FormatPathArgs {
    pub path: String,
}

#[napi(object)]
pub struct FormatPathResult {
    pub changed_paths: Vec<String>,
}

#[napi(object)]
pub struct LintPathArgs {
    pub paths: Vec<String>,
}

#[napi(object)]
pub struct LintPathResult {
    pub results: Vec<String>,
}

#[napi(object)]
pub struct OverrideFileArgs {
    pub file: String,
    pub specs: Vec<String>,
    pub import_paths: Vec<String>,
}

#[napi(object)]
pub struct OverrideFileResult {
    pub result: bool,
}

#[napi(object)]
pub struct ListVariablesResult {
    pub variables: HashMap<String, Variable>,
    pub unsupported_codes: Vec<String>,
}

#[napi(object)]
pub struct Variable {
    pub value: String,
}

#[napi(object)]
pub struct GetSchemaTypeResult {
    pub schema_type_list: Vec<KclType>,
}

#[napi(object)]
pub struct GetSchemaTypeMappingArgs {
    pub file: String,
    pub code: String,
    pub schema_name: String,
}

#[napi(object)]
pub struct GetSchemaTypeMappingResult {
    pub schema_type_mapping: HashMap<String, KclType>,
}

#[napi(object)]
pub struct ValidateCodeArgs {
    pub datafile: String,
    pub data: String,
    pub file: String,
    pub code: String,
    pub schema: String,
    pub attribute_name: String,
    pub format: String,
}

#[napi(object)]
pub struct ValidateCodeResult {
    pub success: bool,
    pub err_message: String,
}

#[napi(object)]
pub struct Position {
    pub line: i64,
    pub column: i64,
    pub filename: String,
}

#[napi(object)]
pub struct ListDepFilesArgs {
    pub work_dir: String,
    pub use_abs_path: bool,
    pub include_all: bool,
    pub use_fast_parser: bool,
}

#[napi(object)]
pub struct ListDepFilesResult {
    pub pkgroot: String,
    pub pkgpath: String,
    pub files: Vec<String>,
}

#[napi(object)]
pub struct LoadSettingsFilesArgs {
    pub work_dir: String,
    pub files: Vec<String>,
}

#[napi(object)]
pub struct LoadSettingsFilesResult {
    pub kcl_cli_configs: Option<CliConfig>,
    pub kcl_options: Vec<KeyValuePair>,
}

#[napi(object)]
pub struct CliConfig {
    pub files: Vec<String>,
    pub output: String,
    pub overrides: Vec<String>,
    pub path_selector: Vec<String>,
    pub strict_range_check: bool,
    pub disable_none: bool,
    pub verbose: i64,
    pub debug: bool,
    pub sort_keys: bool,
    pub show_hidden: bool,
    pub include_schema_type_path: bool,
    pub fast_eval: bool,
}

#[napi(object)]
pub struct KeyValuePair {
    pub key: String,
    pub value: String,
}

#[napi(object)]
pub struct RenameArgs {
    /// the file path to the package root
    pub package_root: String,
    /// the path to the target symbol to be renamed. The symbol path should conform to format: `<pkgpath>:<field_path>` When the pkgpath is '__main__', `<pkgpath>:` can be omitted.
    pub symbol_path: String,
    /// the paths to the source code files
    pub file_paths: Vec<String>,
    /// the new name of the symbol
    pub new_name: String,
}

#[napi(object)]
pub struct RenameResult {
    /// the file paths got changed
    pub changed_files: Vec<String>,
}

#[napi(object)]
pub struct RenameCodeArgs {
    /// the file path to the package root
    pub package_root: String,
    /// the path to the target symbol to be renamed. The symbol path should conform to format: `<pkgpath>:<field_path>` When the pkgpath is '__main__', `<pkgpath>:` can be omitted.
    pub symbol_path: String,
    /// the source code. a <filename>:<code> map
    pub source_codes: HashMap<String, String>,
    /// the new name of the symbol
    pub new_name: String,
}

#[napi(object)]
pub struct RenameCodeResult {
    /// the changed code. a <filename>:<code> map
    pub changed_codes: HashMap<String, String>,
}

#[napi(object)]
pub struct TestResult {
    pub info: Vec<TestCaseInfo>,
}

#[napi(object)]
pub struct TestCaseInfo {
    /// Test case name
    pub name: String,
    pub error: String,
    pub log_message: String,
}

#[napi(object)]
pub struct KclType {
    /// schema, dict, list, str, int, float, bool, any, union, number_multiplier
    pub r#type: String,
    /// union types
    pub union_types: Vec<KclType>,
    /// default value
    pub default: String,
    /// schema name
    pub schema_name: String,
    /// schema doc
    pub schema_doc: String,
    /// schema properties
    pub properties: HashMap<String, KclType>,
    /// required schema properties, [property_name1, property_name2]
    pub required: Vec<String>,
    /// dict key type
    pub key: Reference<KclType>,
    /// dict/list item type
    pub item: Reference<KclType>,
    pub line: i32,
    /// schema decorators
    pub decorators: Vec<Decorator>,
    /// `filename` represents the absolute path of the file name where the attribute is located.
    pub filename: String,
    /// `pkg_path` represents the path name of the package where the attribute is located.
    pub pkg_path: String,
    /// `description` represents the document of the attribute.
    pub description: String,
    /// A map object to hold examples, the key is the example name.
    pub examples: HashMap<String, Example>,
}

#[napi(object)]
pub struct Decorator {
    pub name: String,
    pub arguments: Vec<String>,
    pub keywords: HashMap<String, String>,
}

#[napi(object)]
pub struct Example {
    pub summary: String,
    pub description: String,
    pub value: String,
}

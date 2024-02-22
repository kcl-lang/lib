/// kcl main.k -E pkg_name=pkg_path
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CmdExternalPkgSpec {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub pkg_name: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub pkg_path: ::prost::alloc::string::String,
}
/// kcl main.k -D name=value
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CmdArgSpec {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub name: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub value: ::prost::alloc::string::String,
}
/// kcl main.k -O pkgpath:path.to.field=field_value
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CmdOverrideSpec {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub pkgpath: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub field_path: ::prost::alloc::string::String,
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub field_value: ::prost::alloc::string::String,
    #[prost(string, tag = "4")]
    #[serde(default)]
    pub action: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Error {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub level: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub code: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "3")]
    #[serde(default)]
    pub messages: ::prost::alloc::vec::Vec<Message>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Message {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub msg: ::prost::alloc::string::String,
    #[prost(message, optional, tag = "2")]
    #[serde(default)]
    pub pos: ::core::option::Option<Position>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct PingArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub value: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct PingResult {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub value: ::prost::alloc::string::String,
}
/// empty
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ListMethodArgs {}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ListMethodResult {
    #[prost(string, repeated, tag = "1")]
    #[serde(default)]
    pub method_name_list: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ParseFileArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub path: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub source: ::prost::alloc::string::String,
    /// External packages path
    #[prost(message, repeated, tag = "3")]
    #[serde(default)]
    pub external_pkgs: ::prost::alloc::vec::Vec<CmdExternalPkgSpec>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ParseFileResult {
    /// JSON string value
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub ast_json: ::prost::alloc::string::String,
    /// file dependency paths
    #[prost(string, repeated, tag = "2")]
    #[serde(default)]
    pub deps: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    /// Parse errors
    #[prost(message, repeated, tag = "3")]
    #[serde(default)]
    pub errors: ::prost::alloc::vec::Vec<Error>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ParseProgramArgs {
    #[prost(string, repeated, tag = "1")]
    #[serde(default)]
    pub paths: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    #[prost(string, repeated, tag = "2")]
    #[serde(default)]
    pub sources: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    /// External packages path
    #[prost(message, repeated, tag = "3")]
    #[serde(default)]
    pub external_pkgs: ::prost::alloc::vec::Vec<CmdExternalPkgSpec>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ParseProgramResult {
    /// JSON string value
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub ast_json: ::prost::alloc::string::String,
    /// Returns the files in the order they should be compiled
    #[prost(string, repeated, tag = "2")]
    #[serde(default)]
    pub paths: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    /// Parse errors
    #[prost(message, repeated, tag = "3")]
    #[serde(default)]
    pub errors: ::prost::alloc::vec::Vec<Error>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LoadPackageArgs {
    #[prost(message, optional, tag = "1")]
    #[serde(default)]
    pub parse_args: ::core::option::Option<ParseProgramArgs>,
    #[prost(bool, tag = "2")]
    #[serde(default)]
    pub resolve_ast: bool,
    #[prost(bool, tag = "3")]
    #[serde(default)]
    pub load_builtin: bool,
    #[prost(bool, tag = "4")]
    #[serde(default)]
    pub with_ast_index: bool,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LoadPackageResult {
    /// JSON string value
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub program: ::prost::alloc::string::String,
    /// Returns the files in the order they should be compiled
    #[prost(string, repeated, tag = "2")]
    #[serde(default)]
    pub paths: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    /// Parse errors
    #[prost(message, repeated, tag = "3")]
    #[serde(default)]
    pub parse_errors: ::prost::alloc::vec::Vec<Error>,
    /// Type errors
    #[prost(message, repeated, tag = "4")]
    #[serde(default)]
    pub type_errors: ::prost::alloc::vec::Vec<Error>,
    /// Map key is the ScopeIndex json string.
    #[prost(map = "string, message", tag = "5")]
    #[serde(default)]
    pub scopes: ::std::collections::HashMap<::prost::alloc::string::String, Scope>,
    /// Map key is the SymbolIndex json string.
    #[prost(map = "string, message", tag = "6")]
    #[serde(default)]
    pub symbols: ::std::collections::HashMap<::prost::alloc::string::String, Symbol>,
    /// Map key is the AST index UUID string.
    #[prost(map = "string, message", tag = "7")]
    #[serde(default)]
    pub node_symbol_map: ::std::collections::HashMap<::prost::alloc::string::String, SymbolIndex>,
    /// Map key is the SymbolIndex json string.
    #[prost(map = "string, string", tag = "8")]
    #[serde(default)]
    pub symbol_node_map:
        ::std::collections::HashMap<::prost::alloc::string::String, ::prost::alloc::string::String>,
    /// Map key is the fully_qualified_name e.g. `pkg.Name`
    #[prost(map = "string, message", tag = "9")]
    #[serde(default)]
    pub fully_qualified_name_map:
        ::std::collections::HashMap<::prost::alloc::string::String, SymbolIndex>,
    /// Map key is the package path.
    #[prost(map = "string, message", tag = "10")]
    #[serde(default)]
    pub pkg_scope_map: ::std::collections::HashMap<::prost::alloc::string::String, ScopeIndex>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Symbol {
    #[prost(message, optional, tag = "1")]
    #[serde(default)]
    pub ty: ::core::option::Option<KclType>,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub name: ::prost::alloc::string::String,
    #[prost(message, optional, tag = "3")]
    #[serde(default)]
    pub owner: ::core::option::Option<SymbolIndex>,
    #[prost(message, optional, tag = "4")]
    #[serde(default)]
    pub def: ::core::option::Option<SymbolIndex>,
    #[prost(message, repeated, tag = "5")]
    #[serde(default)]
    pub attrs: ::prost::alloc::vec::Vec<SymbolIndex>,
    #[prost(bool, tag = "6")]
    #[serde(default)]
    pub is_global: bool,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Scope {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub kind: ::prost::alloc::string::String,
    #[prost(message, optional, tag = "2")]
    #[serde(default)]
    pub parent: ::core::option::Option<ScopeIndex>,
    #[prost(message, optional, tag = "3")]
    #[serde(default)]
    pub owner: ::core::option::Option<SymbolIndex>,
    #[prost(message, repeated, tag = "4")]
    #[serde(default)]
    pub children: ::prost::alloc::vec::Vec<ScopeIndex>,
    #[prost(message, repeated, tag = "5")]
    #[serde(default)]
    pub defs: ::prost::alloc::vec::Vec<SymbolIndex>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct SymbolIndex {
    #[prost(uint64, tag = "1")]
    #[serde(default)]
    pub i: u64,
    #[prost(uint64, tag = "2")]
    #[serde(default)]
    pub g: u64,
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub kind: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ScopeIndex {
    #[prost(uint64, tag = "1")]
    #[serde(default)]
    pub i: u64,
    #[prost(uint64, tag = "2")]
    #[serde(default)]
    pub g: u64,
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub kind: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ExecProgramArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub work_dir: ::prost::alloc::string::String,
    #[prost(string, repeated, tag = "2")]
    #[serde(default)]
    pub k_filename_list: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    #[prost(string, repeated, tag = "3")]
    #[serde(default)]
    pub k_code_list: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    #[prost(message, repeated, tag = "4")]
    #[serde(default)]
    pub args: ::prost::alloc::vec::Vec<CmdArgSpec>,
    #[prost(message, repeated, tag = "5")]
    #[serde(default)]
    pub overrides: ::prost::alloc::vec::Vec<CmdOverrideSpec>,
    #[prost(bool, tag = "6")]
    #[serde(default)]
    pub disable_yaml_result: bool,
    #[prost(bool, tag = "7")]
    #[serde(default)]
    pub print_override_ast: bool,
    /// -r --strict-range-check
    #[prost(bool, tag = "8")]
    #[serde(default)]
    pub strict_range_check: bool,
    /// -n --disable-none
    #[prost(bool, tag = "9")]
    #[serde(default)]
    pub disable_none: bool,
    /// -v --verbose
    #[prost(int32, tag = "10")]
    #[serde(default)]
    pub verbose: i32,
    /// -d --debug
    #[prost(int32, tag = "11")]
    #[serde(default)]
    pub debug: i32,
    /// yaml/json: sort keys
    #[prost(bool, tag = "12")]
    #[serde(default)]
    pub sort_keys: bool,
    /// -E --external : external packages path
    #[prost(message, repeated, tag = "13")]
    #[serde(default)]
    pub external_pkgs: ::prost::alloc::vec::Vec<CmdExternalPkgSpec>,
    /// Whether including schema type in JSON/YAML result
    #[prost(bool, tag = "14")]
    #[serde(default)]
    pub include_schema_type_path: bool,
    /// Whether only compiling the program
    #[prost(bool, tag = "15")]
    #[serde(default)]
    pub compile_only: bool,
    /// Show hidden attributes
    #[prost(bool, tag = "16")]
    #[serde(default)]
    pub show_hidden: bool,
    /// -S --path_selector
    #[prost(string, repeated, tag = "17")]
    #[serde(default)]
    pub path_selector: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ExecProgramResult {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub json_result: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub yaml_result: ::prost::alloc::string::String,
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub log_message: ::prost::alloc::string::String,
    #[prost(string, tag = "4")]
    #[serde(default)]
    pub err_message: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct BuildProgramArgs {
    #[prost(message, optional, tag = "1")]
    #[serde(default)]
    pub exec_args: ::core::option::Option<ExecProgramArgs>,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub output: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct BuildProgramResult {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub path: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ExecArtifactArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub path: ::prost::alloc::string::String,
    #[prost(message, optional, tag = "2")]
    #[serde(default)]
    pub exec_args: ::core::option::Option<ExecProgramArgs>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ResetPluginArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub plugin_root: ::prost::alloc::string::String,
}
/// empty
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ResetPluginResult {}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FormatCodeArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub source: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FormatCodeResult {
    #[prost(bytes = "vec", tag = "1")]
    #[serde(default)]
    pub formatted: ::prost::alloc::vec::Vec<u8>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FormatPathArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub path: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FormatPathResult {
    #[prost(string, repeated, tag = "1")]
    #[serde(default)]
    pub changed_paths: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LintPathArgs {
    #[prost(string, repeated, tag = "1")]
    #[serde(default)]
    pub paths: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LintPathResult {
    #[prost(string, repeated, tag = "1")]
    #[serde(default)]
    pub results: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct OverrideFileArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub file: ::prost::alloc::string::String,
    #[prost(string, repeated, tag = "2")]
    #[serde(default)]
    pub specs: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    #[prost(string, repeated, tag = "3")]
    #[serde(default)]
    pub import_paths: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct OverrideFileResult {
    #[prost(bool, tag = "1")]
    #[serde(default)]
    pub result: bool,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GetFullSchemaTypeArgs {
    #[prost(message, optional, tag = "1")]
    #[serde(default)]
    pub exec_args: ::core::option::Option<ExecProgramArgs>,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub schema_name: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GetSchemaTypeArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub file: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub code: ::prost::alloc::string::String,
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub schema_name: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GetSchemaTypeResult {
    #[prost(message, repeated, tag = "1")]
    #[serde(default)]
    pub schema_type_list: ::prost::alloc::vec::Vec<KclType>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GetSchemaTypeMappingArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub file: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub code: ::prost::alloc::string::String,
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub schema_name: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GetSchemaTypeMappingResult {
    #[prost(map = "string, message", tag = "1")]
    #[serde(default)]
    pub schema_type_mapping: ::std::collections::HashMap<::prost::alloc::string::String, KclType>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ValidateCodeArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub data: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub file: ::prost::alloc::string::String,
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub code: ::prost::alloc::string::String,
    #[prost(string, tag = "4")]
    #[serde(default)]
    pub schema: ::prost::alloc::string::String,
    #[prost(string, tag = "5")]
    #[serde(default)]
    pub attribute_name: ::prost::alloc::string::String,
    #[prost(string, tag = "6")]
    #[serde(default)]
    pub format: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ValidateCodeResult {
    #[prost(bool, tag = "1")]
    #[serde(default)]
    pub success: bool,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub err_message: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Position {
    #[prost(int64, tag = "1")]
    #[serde(default)]
    pub line: i64,
    #[prost(int64, tag = "2")]
    #[serde(default)]
    pub column: i64,
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub filename: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ListDepFilesArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub work_dir: ::prost::alloc::string::String,
    #[prost(bool, tag = "2")]
    #[serde(default)]
    pub use_abs_path: bool,
    #[prost(bool, tag = "3")]
    #[serde(default)]
    pub include_all: bool,
    #[prost(bool, tag = "4")]
    #[serde(default)]
    pub use_fast_parser: bool,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ListDepFilesResult {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub pkgroot: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub pkgpath: ::prost::alloc::string::String,
    #[prost(string, repeated, tag = "3")]
    #[serde(default)]
    pub files: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LoadSettingsFilesArgs {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub work_dir: ::prost::alloc::string::String,
    #[prost(string, repeated, tag = "2")]
    #[serde(default)]
    pub files: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LoadSettingsFilesResult {
    #[prost(message, optional, tag = "1")]
    #[serde(default)]
    pub kcl_cli_configs: ::core::option::Option<CliConfig>,
    #[prost(message, repeated, tag = "2")]
    #[serde(default)]
    pub kcl_options: ::prost::alloc::vec::Vec<KeyValuePair>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CliConfig {
    #[prost(string, repeated, tag = "1")]
    #[serde(default)]
    pub files: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub output: ::prost::alloc::string::String,
    #[prost(string, repeated, tag = "3")]
    #[serde(default)]
    pub overrides: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    #[prost(string, repeated, tag = "4")]
    #[serde(default)]
    pub path_selector: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    #[prost(bool, tag = "5")]
    #[serde(default)]
    pub strict_range_check: bool,
    #[prost(bool, tag = "6")]
    #[serde(default)]
    pub disable_none: bool,
    #[prost(int64, tag = "7")]
    #[serde(default)]
    pub verbose: i64,
    #[prost(bool, tag = "8")]
    #[serde(default)]
    pub debug: bool,
    #[prost(bool, tag = "9")]
    #[serde(default)]
    pub sort_keys: bool,
    #[prost(bool, tag = "10")]
    #[serde(default)]
    pub show_hidden: bool,
    #[prost(bool, tag = "11")]
    #[serde(default)]
    pub include_schema_type_path: bool,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct KeyValuePair {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub key: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub value: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct RenameArgs {
    /// the file path to the package root
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub package_root: ::prost::alloc::string::String,
    /// the path to the target symbol to be renamed. The symbol path should conform to format: `<pkgpath>:<field_path>` When the pkgpath is '__main__', `<pkgpath>:` can be omitted.
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub symbol_path: ::prost::alloc::string::String,
    /// the paths to the source code files
    #[prost(string, repeated, tag = "3")]
    #[serde(default)]
    pub file_paths: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    /// the new name of the symbol
    #[prost(string, tag = "4")]
    #[serde(default)]
    pub new_name: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct RenameResult {
    /// the file paths got changed
    #[prost(string, repeated, tag = "1")]
    #[serde(default)]
    pub changed_files: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct RenameCodeArgs {
    /// the file path to the package root
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub package_root: ::prost::alloc::string::String,
    /// the path to the target symbol to be renamed. The symbol path should conform to format: `<pkgpath>:<field_path>` When the pkgpath is '__main__', `<pkgpath>:` can be omitted.
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub symbol_path: ::prost::alloc::string::String,
    /// the source code. a <filename>:<code> map
    #[prost(map = "string, string", tag = "3")]
    #[serde(default)]
    pub source_codes:
        ::std::collections::HashMap<::prost::alloc::string::String, ::prost::alloc::string::String>,
    /// the new name of the symbol
    #[prost(string, tag = "4")]
    #[serde(default)]
    pub new_name: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct RenameCodeResult {
    /// the changed code. a <filename>:<code> map
    #[prost(map = "string, string", tag = "1")]
    #[serde(default)]
    pub changed_codes:
        ::std::collections::HashMap<::prost::alloc::string::String, ::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TestArgs {
    /// This field stores the execution program arguments.
    #[prost(message, optional, tag = "1")]
    #[serde(default)]
    pub exec_args: ::core::option::Option<ExecProgramArgs>,
    /// The package path list to be tested e.g., "./...", "/path/to/package/", "/path/to/package/..."
    #[prost(string, repeated, tag = "2")]
    #[serde(default)]
    pub pkg_list: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    /// This field stores a regular expression for filtering tests to run.
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub run_regexp: ::prost::alloc::string::String,
    /// This field determines whether the test run should stop on the first failure.
    #[prost(bool, tag = "4")]
    #[serde(default)]
    pub fail_fast: bool,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TestResult {
    #[prost(message, repeated, tag = "2")]
    #[serde(default)]
    pub info: ::prost::alloc::vec::Vec<TestCaseInfo>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TestCaseInfo {
    /// Test case name
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub name: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub error: ::prost::alloc::string::String,
    /// Number of whole microseconds in the duration.
    #[prost(uint64, tag = "3")]
    #[serde(default)]
    pub duration: u64,
    #[prost(string, tag = "4")]
    #[serde(default)]
    pub log_message: ::prost::alloc::string::String,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct KclType {
    /// schema, dict, list, str, int, float, bool, any, union, number_multiplier
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub r#type: ::prost::alloc::string::String,
    /// union types
    #[prost(message, repeated, tag = "2")]
    #[serde(default)]
    pub union_types: ::prost::alloc::vec::Vec<KclType>,
    /// default value
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub default: ::prost::alloc::string::String,
    /// schema name
    #[prost(string, tag = "4")]
    #[serde(default)]
    pub schema_name: ::prost::alloc::string::String,
    /// schema doc
    #[prost(string, tag = "5")]
    #[serde(default)]
    pub schema_doc: ::prost::alloc::string::String,
    /// schema properties
    #[prost(map = "string, message", tag = "6")]
    #[serde(default)]
    pub properties: ::std::collections::HashMap<::prost::alloc::string::String, KclType>,
    /// required schema properties, [property_name1, property_name2]
    #[prost(string, repeated, tag = "7")]
    #[serde(default)]
    pub required: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    /// dict key type
    #[prost(message, optional, boxed, tag = "8")]
    #[serde(default)]
    pub key: ::core::option::Option<::prost::alloc::boxed::Box<KclType>>,
    /// dict/list item type
    #[prost(message, optional, boxed, tag = "9")]
    #[serde(default)]
    pub item: ::core::option::Option<::prost::alloc::boxed::Box<KclType>>,
    #[prost(int32, tag = "10")]
    #[serde(default)]
    pub line: i32,
    /// schema decorators
    #[prost(message, repeated, tag = "11")]
    #[serde(default)]
    pub decorators: ::prost::alloc::vec::Vec<Decorator>,
    /// `filename` represents the absolute path of the file name where the attribute is located.
    #[prost(string, tag = "12")]
    #[serde(default)]
    pub filename: ::prost::alloc::string::String,
    /// `pkg_path` represents the path name of the package where the attribute is located.
    #[prost(string, tag = "13")]
    #[serde(default)]
    pub pkg_path: ::prost::alloc::string::String,
    /// `description` represents the document of the attribute.
    #[prost(string, tag = "14")]
    #[serde(default)]
    pub description: ::prost::alloc::string::String,
    /// A map object to hold examples, the key is the example name.
    #[prost(map = "string, message", tag = "15")]
    #[serde(default)]
    pub examples: ::std::collections::HashMap<::prost::alloc::string::String, Example>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Decorator {
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub name: ::prost::alloc::string::String,
    #[prost(string, repeated, tag = "2")]
    #[serde(default)]
    pub arguments: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    #[prost(map = "string, string", tag = "3")]
    #[serde(default)]
    pub keywords:
        ::std::collections::HashMap<::prost::alloc::string::String, ::prost::alloc::string::String>,
}
#[derive(serde::Serialize, serde::Deserialize)]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Example {
    /// Short description for the example.
    #[prost(string, tag = "1")]
    #[serde(default)]
    pub summary: ::prost::alloc::string::String,
    /// Long description for the example.
    #[prost(string, tag = "2")]
    #[serde(default)]
    pub description: ::prost::alloc::string::String,
    /// Embedded literal example.
    #[prost(string, tag = "3")]
    #[serde(default)]
    pub value: ::prost::alloc::string::String,
}

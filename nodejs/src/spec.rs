use napi::bindgen_prelude::*;
use std::collections::HashMap;

/// Message representing an external package for KCL.
/// kcl main.k -E pkg_name=pkg_path
#[napi(object)]
pub struct ExternalPkg {
    /// Name of the package.
    pub pkg_name: String,
    /// Path of the package.
    pub pkg_path: String,
}

/// Message representing a key-value argument for KCL.
/// kcl main.k -D name=value
#[napi(object)]
pub struct Argument {
    /// Name of the argument.
    pub name: String,
    /// Value of the argument.
    pub value: String,
}

/// Message representing an error.
#[napi(object)]
pub struct Error {
    /// Level of the error (e.g., "Error", "Warning").
    pub level: String,
    /// Error code. (e.g., "E1001")
    pub code: String,
    /// List of error messages.
    pub messages: Vec<Message>,
}

/// Message representing a detailed error message with a position.
#[napi(object)]
pub struct Message {
    /// The error message text.
    pub msg: String,
    /// The position in the source code where the error occurred.
    pub pos: Option<Position>,
}

/// Message for ping response.
#[napi(object)]
pub struct PingResult {
    /// Value received in the ping response.
    pub value: String,
}

/// Message for list method response.
#[napi(object)]
pub struct ListMethodResult {
    /// List of available method names.
    pub method_name_list: Vec<String>,
}

/// Message for parse file response.
#[napi(object)]
pub struct ParseFileResult {
    /// Abstract Syntax Tree (AST) in JSON format.
    pub ast_json: String,
    /// File dependency paths.
    pub deps: Vec<String>,
    /// List of parse errors.
    pub errors: Vec<Error>,
}

impl ParseFileResult {
    pub fn new(r: kcl_api::ParseFileResult) -> Self {
        Self {
            ast_json: r.ast_json,
            deps: r.deps,
            errors: r.errors.iter().map(crate::spec::Error::new).collect(),
        }
    }
}

/// Message for parse program response.
#[napi(object)]
pub struct ParseProgramResult {
    /// Abstract Syntax Tree (AST) in JSON format.
    pub ast_json: String,
    /// Returns the files in the order they should be compiled.
    pub paths: Vec<String>,
    /// List of parse errors.
    pub errors: Vec<Error>,
}

impl ParseProgramResult {
    pub fn new(r: kcl_api::ParseProgramResult) -> Self {
        Self {
            ast_json: r.ast_json,
            paths: r.paths,
            errors: r.errors.iter().map(crate::spec::Error::new).collect(),
        }
    }
}

impl crate::spec::Error {
    pub fn new(e: &kcl_api::Error) -> Self {
        Self {
            level: e.level.clone(),
            code: e.code.clone(),
            messages: e
                .messages
                .iter()
                .map(|m| Message {
                    msg: m.msg.clone(),
                    pos: m.pos.as_ref().map(|p| Position {
                        line: p.line,
                        column: p.column,
                        filename: p.filename.clone(),
                    }),
                })
                .collect(),
        }
    }
}

impl ScopeIndex {
    pub fn new(v: &kcl_api::ScopeIndex) -> Self {
        ScopeIndex {
            i: v.i as u32,
            g: v.g as u32,
            kind: v.kind.clone(),
        }
    }
}

impl SymbolIndex {
    pub fn new(v: &kcl_api::SymbolIndex) -> Self {
        SymbolIndex {
            i: v.i as u32,
            g: v.g as u32,
            kind: v.kind.clone(),
        }
    }
}

impl crate::spec::Symbol {
    pub fn new(v: &kcl_api::Symbol) -> Self {
        crate::spec::Symbol {
            ty: v.ty.as_ref().map(|ty| ty.r#type.clone()),
            name: v.name.clone(),
            owner: v.owner.as_ref().map(SymbolIndex::new),
            def: v.def.as_ref().map(SymbolIndex::new),
            attrs: v.attrs.iter().map(SymbolIndex::new).collect(),
            is_global: v.is_global,
        }
    }
}

impl LoadPackageResult {
    pub fn new(r: kcl_api::LoadPackageResult) -> Self {
        Self {
            program: r.program,
            paths: r.paths,
            parse_errors: r.parse_errors.iter().map(crate::spec::Error::new).collect(),
            type_errors: r.type_errors.iter().map(crate::spec::Error::new).collect(),
            scopes: r
                .scopes
                .iter()
                .map(|(k, v)| {
                    (
                        k.to_string(),
                        Scope {
                            kind: v.kind.clone(),
                            parent: v.parent.as_ref().map(ScopeIndex::new),
                            owner: v.owner.as_ref().map(SymbolIndex::new),
                            children: v.children.iter().map(ScopeIndex::new).collect(),
                            defs: v.defs.iter().map(SymbolIndex::new).collect(),
                        },
                    )
                })
                .collect(),
            symbols: r
                .symbols
                .iter()
                .map(|(k, v)| (k.clone(), crate::spec::Symbol::new(v)))
                .collect(),
            node_symbol_map: r
                .node_symbol_map
                .iter()
                .map(|(k, v)| (k.clone(), SymbolIndex::new(v)))
                .collect(),
            symbol_node_map: r.symbol_node_map,
            fully_qualified_name_map: r
                .fully_qualified_name_map
                .iter()
                .map(|(k, v)| (k.to_string(), SymbolIndex::new(v)))
                .collect(),
            pkg_scope_map: r
                .pkg_scope_map
                .iter()
                .map(|(k, v)| (k.to_string(), ScopeIndex::new(v)))
                .collect(),
            imports: r
                .imports
                .iter()
                .map(|(k, v)| {
                    (
                        k.clone(),
                        FileImports {
                            imports: v
                                .imports
                                .iter()
                                .map(|i| ImportInfo {
                                    path: i.path.clone(),
                                    resolved: i.resolved.clone(),
                                })
                                .collect(),
                        },
                    )
                })
                .collect(),
            kcl_mod: r.kcl_mod.as_ref().map(|m| KclMod {
                package: m.package.as_ref().map(|p| KclModPackage {
                    name: p.name.clone(),
                    edition: p.edition.clone(),
                    version: p.version.clone(),
                    description: p.description.clone(),
                    include: p.include.clone(),
                    exclude: p.exclude.clone(),
                }),
            }),
            apps: r
                .apps
                .iter()
                .map(|a| AppInfo {
                    path: a.path.clone(),
                    has_kcl_mod: a.has_kcl_mod,
                })
                .collect(),
        }
    }
}

/// Message representing the direct imports of a single file.
#[napi(object)]
pub struct FileImports {
    /// List of direct imports of the file.
    pub imports: Vec<ImportInfo>,
}

/// Message representing a single direct import of a file.
#[napi(object)]
pub struct ImportInfo {
    /// Import specifier as written in the source.
    pub path: String,
    /// Resolved absolute file path of the import.
    pub resolved: String,
}

/// Message representing the package section of a `kcl.mod` manifest.
#[napi(object)]
pub struct KclModPackage {
    /// Name of the package.
    pub name: String,
    /// KCL compiler edition of the package.
    pub edition: String,
    /// Version of the package.
    pub version: String,
    /// Description of the package.
    pub description: String,
    /// Files to include when publishing.
    pub include: Vec<String>,
    /// Files to exclude when publishing.
    pub exclude: Vec<String>,
}

/// Message representing a parsed `kcl.mod` manifest.
///
/// Only the package section is carried across. The profile and dependency
/// sections are not part of this mirror, the same way the napi `Symbol` and
/// `Scope` mirrors carry indexes rather than the whole `kcl_api` document.
#[napi(object)]
pub struct KclMod {
    /// Package section of the manifest.
    pub package: Option<KclModPackage>,
}

/// Message representing an application directory discovered under the root.
#[napi(object)]
pub struct AppInfo {
    /// Absolute path of the application directory.
    pub path: String,
    /// True when the directory contains a `kcl.mod` manifest.
    pub has_kcl_mod: bool,
}

/// Message for load package response.
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
    /// Map of direct imports, keyed by the importing file's absolute path.
    pub imports: HashMap<String, FileImports>,
    /// Parsed `kcl.mod` manifest of the package root, absent when the root has
    /// no `kcl.mod`.
    pub kcl_mod: Option<KclMod>,
    /// Application directories discovered under the package root.
    pub apps: Vec<AppInfo>,
}

/// Message for list options response.
#[napi(object)]
pub struct ListOptionsResult {
    /// Returns the files in the order they should be compiled
    pub options: Vec<OptionHelp>,
}

impl ListOptionsResult {
    pub fn new(r: kcl_api::ListOptionsResult) -> Self {
        Self {
            options: r
                .options
                .iter()
                .map(|r| OptionHelp {
                    name: r.name.clone(),
                    r#type: r.r#type.clone(),
                    required: r.required,
                    default_value: r.default_value.clone(),
                    help: r.help.clone(),
                })
                .collect(),
        }
    }
}

/// Message representing a help option.
#[napi(object)]
pub struct OptionHelp {
    /// Name of the option.
    pub name: String,
    /// Type of the option.
    pub r#type: String,
    /// Flag indicating if the option is required.
    pub required: bool,
    /// Default value of the option.
    pub default_value: String,
    /// Help text for the option.
    pub help: String,
}

/// Message representing a symbol in KCL.
#[napi(object)]
pub struct Symbol {
    /// Type of the symbol.
    pub ty: Option<String>,
    /// Name of the symbol.
    pub name: String,
    /// Owner of the symbol.
    pub owner: Option<SymbolIndex>,
    /// Definition of the symbol.
    pub def: Option<SymbolIndex>,
    /// Attributes of the symbol.
    pub attrs: Vec<SymbolIndex>,
    /// Flag indicating if the symbol is global.
    pub is_global: bool,
}

/// Message representing a scope in KCL.
#[napi(object)]
pub struct Scope {
    /// Type of the scope.
    pub kind: String,
    /// Parent scope.
    pub parent: Option<ScopeIndex>,
    /// Owner of the scope.
    pub owner: Option<SymbolIndex>,
    /// Children of the scope.
    pub children: Vec<ScopeIndex>,
    /// Definitions in the scope.
    pub defs: Vec<SymbolIndex>,
}

/// Message representing a symbol index.
#[napi(object)]
pub struct SymbolIndex {
    pub i: u32,
    pub g: u32,
    pub kind: String,
}

/// Message representing a scope index.
#[napi(object)]
pub struct ScopeIndex {
    pub i: u32,
    pub g: u32,
    pub kind: String,
}

/// Message for execute program response.
#[napi(object)]
pub struct ExecProgramResult {
    /// Result in JSON format.
    pub json_result: String,
    /// Result in YAML format.
    pub yaml_result: String,
    /// Log message from execution.
    pub log_message: String,
    /// Error message from execution.
    pub err_message: String,
    /// Source Map v3 JSON mapping the generated YAML back to the originating
    /// KCL source. Populated only when a source map is requested.
    pub sourcemap: Option<String>,
}

impl ExecProgramResult {
    pub fn new(r: kcl_api::ExecProgramResult) -> Self {
        Self {
            json_result: r.json_result,
            yaml_result: r.yaml_result,
            log_message: r.log_message,
            err_message: r.err_message,
            sourcemap: r.sourcemap,
        }
    }
}

/// Message for format code response.
#[napi(object)]
pub struct FormatCodeResult {
    /// Formatted code as bytes.
    pub formatted: String,
}

impl FormatCodeResult {
    pub fn new(r: kcl_api::FormatCodeResult) -> Self {
        Self {
            formatted: String::from_utf8(r.formatted).unwrap(),
        }
    }
}

/// Message for format file path response.
#[napi(object)]
pub struct FormatPathResult {
    /// List of changed file paths.
    pub changed_paths: Vec<String>,
}

impl FormatPathResult {
    pub fn new(r: kcl_api::FormatPathResult) -> Self {
        Self {
            changed_paths: r.changed_paths,
        }
    }
}

/// Message for lint file path response.
#[napi(object)]
pub struct LintPathResult {
    /// List of lint results.
    pub results: Vec<String>,
}

impl LintPathResult {
    pub fn new(r: kcl_api::LintPathResult) -> Self {
        Self { results: r.results }
    }
}

/// Message for override file response.
#[napi(object)]
pub struct OverrideFileResult {
    /// Result of the override operation.
    pub result: bool,
    // List of parse errors encountered.
    pub parse_errors: Vec<Error>,
}

impl OverrideFileResult {
    pub fn new(r: kcl_api::OverrideFileResult) -> Self {
        Self {
            result: r.result,
            parse_errors: r.parse_errors.iter().map(crate::spec::Error::new).collect(),
        }
    }
}

/// Message for list variables options.
#[napi(object)]
pub struct ListVariablesOptions {
    /// Flag to merge program configuration.
    pub merge_program: bool,
}

/// Message for list variables response.
#[napi(object)]
pub struct ListVariablesResult {
    /// Map of variable lists by file.
    pub variables: HashMap<String, Vec<Variable>>,
    /// List of unsupported codes.
    pub unsupported_codes: Vec<String>,
    /// List of parse errors encountered.
    pub parse_errors: Vec<Error>,
}

/// Message representing a variable.
#[napi(object)]
#[derive(Default, Debug)]
pub struct Variable {
    /// Value of the variable.
    pub value: String,
    /// Type name of the variable.
    pub type_name: String,
    /// Operation symbol associated with the variable.
    pub op_sym: String,
    /// List items if the variable is a list.
    pub list_items: Vec<Variable>,
    /// Dictionary entries if the variable is a dictionary.
    pub dict_entries: HashMap<String, Variable>,
}

impl Variable {
    pub fn new(v: &kcl_api::Variable) -> Self {
        Self {
            value: v.value.to_string(),
            type_name: v.type_name.to_string(),
            op_sym: v.op_sym.to_string(),
            list_items: v.list_items.iter().map(Variable::new).collect(),
            dict_entries: v
                .dict_entries
                .iter()
                .map(|e| {
                    (
                        e.key.to_string(),
                        Variable::new(&e.value.clone().unwrap_or_default()),
                    )
                })
                .collect(),
        }
    }
}

impl ListVariablesResult {
    pub fn new(r: kcl_api::ListVariablesResult) -> Self {
        Self {
            variables: r
                .variables
                .iter()
                .map(|(k, v)| {
                    (
                        k.to_string(),
                        v.variables.iter().map(Variable::new).collect(),
                    )
                })
                .collect(),
            unsupported_codes: r.unsupported_codes,
            parse_errors: r.parse_errors.iter().map(crate::spec::Error::new).collect(),
        }
    }
}

// Message for get schema type mapping response.
#[napi(object)]
pub struct GetSchemaTypeMappingResult {
    /// Map of schema type mappings.
    pub schema_type_mapping: HashMap<String, String>,
    /// The same map in canonical protobuf JSON: proto field names, and a field
    /// the core left unset absent rather than rendered as `""`/`0`/`[]`/`{}`.
    /// The summary above drops everything but the type name, and `KclType`
    /// recurses through plain message fields (`key`, `item`, `base_schema`,
    /// `function`), which a napi object cannot express, so the whole document
    /// travels as JSON instead.
    pub schema_type_mapping_json: String,
}

impl GetSchemaTypeMappingResult {
    pub fn new(r: kcl_api::GetSchemaTypeMappingResult) -> Self {
        Self {
            schema_type_mapping: r
                .schema_type_mapping
                .iter()
                .map(|(k, v)| (k.to_string(), v.r#type.clone()))
                .collect(),
            schema_type_mapping_json: schema_type_mapping_json(&r.schema_type_mapping),
        }
    }
}

// Message for get schema type mapping under path response. Different from
// `GetSchemaTypeMappingResult`, the map is keyed by package name (e.g.
// "__main__", "mymod.v1") and each value holds the schema names of that
// package, so schemas from kcl.mod dependencies keep their own pkgpath.
// See https://github.com/kcl-lang/kcl/issues/1546.
#[napi(object)]
pub struct GetSchemaTypeMappingUnderPathResult {
    /// Map of package name to the schema names defined in that package.
    pub schema_type_mapping: HashMap<String, Vec<String>>,
    /// The same map in canonical protobuf JSON, keyed by package name as
    /// above. See `GetSchemaTypeMappingResult::schema_type_mapping_json`.
    pub schema_type_mapping_json: String,
}

impl GetSchemaTypeMappingUnderPathResult {
    pub fn new(r: kcl_api::GetSchemaTypeMappingUnderPathResult) -> Self {
        Self {
            schema_type_mapping: r
                .schema_type_mapping
                .iter()
                .map(|(k, v)| {
                    (
                        k.to_string(),
                        v.schema_type.iter().map(|s| s.schema_name.clone()).collect(),
                    )
                })
                .collect(),
            schema_type_mapping_json: schema_types_under_path_json(&r.schema_type_mapping),
        }
    }
}

/// Insert `value` under `key` unless it is the proto default, which canonical
/// protobuf JSON spells by leaving the field out entirely.
fn set_if_set(object: &mut serde_json::Map<String, serde_json::Value>, key: &str, value: serde_json::Value) {
    let unset = match &value {
        serde_json::Value::String(s) => s.is_empty(),
        serde_json::Value::Number(n) => n.as_f64() == Some(0.0),
        serde_json::Value::Bool(b) => !*b,
        serde_json::Value::Array(a) => a.is_empty(),
        serde_json::Value::Object(o) => o.is_empty(),
        _ => false,
    };
    if !unset {
        object.insert(key.to_string(), value);
    }
}

/// Canonical protobuf JSON for a `KclType`. Every field the core set is spelled
/// with its proto name; every field it left unset is absent, which is the
/// dialect the cross-language consistency manifest pins.
fn kcl_type_json(ty: &kcl_api::KclType) -> serde_json::Value {
    let mut out = serde_json::Map::new();
    set_if_set(&mut out, "type", ty.r#type.clone().into());
    set_if_set(
        &mut out,
        "union_types",
        serde_json::Value::Array(ty.union_types.iter().map(kcl_type_json).collect()),
    );
    set_if_set(&mut out, "default", ty.default.clone().into());
    set_if_set(&mut out, "schema_name", ty.schema_name.clone().into());
    set_if_set(&mut out, "schema_doc", ty.schema_doc.clone().into());
    set_if_set(
        &mut out,
        "properties",
        serde_json::Value::Object(
            ty.properties
                .iter()
                .map(|(k, v)| (k.clone(), kcl_type_json(v)))
                .collect(),
        ),
    );
    set_if_set(
        &mut out,
        "required",
        serde_json::Value::Array(
            ty.required
                .iter()
                .map(|r| serde_json::Value::String(r.clone()))
                .collect(),
        ),
    );
    if let Some(key) = &ty.key {
        out.insert("key".to_string(), kcl_type_json(key));
    }
    if let Some(item) = &ty.item {
        out.insert("item".to_string(), kcl_type_json(item));
    }
    set_if_set(&mut out, "line", ty.line.into());
    set_if_set(
        &mut out,
        "decorators",
        serde_json::Value::Array(
            ty.decorators
                .iter()
                .map(|d| {
                    let mut decorator = serde_json::Map::new();
                    set_if_set(&mut decorator, "name", d.name.clone().into());
                    set_if_set(
                        &mut decorator,
                        "arguments",
                        serde_json::Value::Array(
                            d.arguments
                                .iter()
                                .map(|a| serde_json::Value::String(a.clone()))
                                .collect(),
                        ),
                    );
                    set_if_set(
                        &mut decorator,
                        "keywords",
                        serde_json::Value::Object(
                            d.keywords
                                .iter()
                                .map(|(k, v)| (k.clone(), serde_json::Value::String(v.clone())))
                                .collect(),
                        ),
                    );
                    serde_json::Value::Object(decorator)
                })
                .collect(),
        ),
    );
    set_if_set(&mut out, "filename", ty.filename.clone().into());
    set_if_set(&mut out, "pkg_path", ty.pkg_path.clone().into());
    set_if_set(&mut out, "description", ty.description.clone().into());
    set_if_set(
        &mut out,
        "examples",
        serde_json::Value::Object(
            ty.examples
                .iter()
                .map(|(k, v)| {
                    let mut example = serde_json::Map::new();
                    set_if_set(&mut example, "summary", v.summary.clone().into());
                    set_if_set(&mut example, "description", v.description.clone().into());
                    set_if_set(&mut example, "value", v.value.clone().into());
                    (k.clone(), serde_json::Value::Object(example))
                })
                .collect(),
        ),
    );
    if let Some(base_schema) = &ty.base_schema {
        out.insert("base_schema".to_string(), kcl_type_json(base_schema));
    }
    if let Some(function) = &ty.function {
        let mut function_json = serde_json::Map::new();
        set_if_set(
            &mut function_json,
            "params",
            serde_json::Value::Array(
                function
                    .params
                    .iter()
                    .map(|p| {
                        let mut param = serde_json::Map::new();
                        set_if_set(&mut param, "name", p.name.clone().into());
                        if let Some(ty) = &p.ty {
                            param.insert("ty".to_string(), kcl_type_json(ty));
                        }
                        serde_json::Value::Object(param)
                    })
                    .collect(),
            ),
        );
        if let Some(return_ty) = &function.return_ty {
            function_json.insert("return_ty".to_string(), kcl_type_json(return_ty));
        }
        out.insert("function".to_string(), serde_json::Value::Object(function_json));
    }
    if let Some(index_signature) = &ty.index_signature {
        let mut signature = serde_json::Map::new();
        if let Some(key_name) = &index_signature.key_name {
            signature.insert("key_name".to_string(), serde_json::Value::String(key_name.clone()));
        }
        if let Some(key) = &index_signature.key {
            signature.insert("key".to_string(), kcl_type_json(key));
        }
        if let Some(val) = &index_signature.val {
            signature.insert("val".to_string(), kcl_type_json(val));
        }
        set_if_set(&mut signature, "any_other", index_signature.any_other.into());
        out.insert("index_signature".to_string(), serde_json::Value::Object(signature));
    }
    serde_json::Value::Object(out)
}

/// Canonical protobuf JSON for `map<string, KclType>`. `serde_json`'s object is
/// key-sorted by default, so the document does not depend on the order the core
/// built its map in.
fn schema_type_mapping_json(mapping: &HashMap<String, kcl_api::KclType>) -> String {
    serde_json::Value::Object(
        mapping
            .iter()
            .map(|(k, v)| (k.clone(), kcl_type_json(v)))
            .collect(),
    )
    .to_string()
}

/// Canonical protobuf JSON for `map<string, SchemaTypes>` -- the same document
/// shape the other bindings pin, `{"<pkg>": {"schema_type": [...]}}`.
fn schema_types_under_path_json(mapping: &HashMap<String, kcl_api::SchemaTypes>) -> String {
    serde_json::Value::Object(
        mapping
            .iter()
            .map(|(k, v)| {
                let mut schemas = serde_json::Map::new();
                set_if_set(
                    &mut schemas,
                    "schema_type",
                    serde_json::Value::Array(v.schema_type.iter().map(kcl_type_json).collect()),
                );
                (k.clone(), serde_json::Value::Object(schemas))
            })
            .collect(),
    )
    .to_string()
}

/// Message for validate code response.
#[napi(object)]
pub struct ValidateCodeResult {
    /// Flag indicating if validation was successful.
    pub success: bool,
    /// Error message from validation.
    pub err_message: String,
}

impl ValidateCodeResult {
    pub fn new(r: kcl_api::ValidateCodeResult) -> Self {
        Self {
            success: r.success,
            err_message: r.err_message,
        }
    }
}

/// Message representing a position in the source code.
#[napi(object)]
pub struct Position {
    /// Line number.
    pub line: i64,
    /// Column number.
    pub column: i64,
    /// Filename the position refers to.
    pub filename: String,
}

/// Message for load settings files response.
#[napi(object)]
pub struct LoadSettingsFilesResult {
    /// KCL CLI configuration.
    pub kcl_cli_configs: Option<CliConfig>,
    /// List of KCL options as key-value pairs.
    pub kcl_options: Vec<KeyValuePair>,
}

impl LoadSettingsFilesResult {
    pub fn new(r: kcl_api::LoadSettingsFilesResult) -> Self {
        Self {
            kcl_cli_configs: r.kcl_cli_configs.map(|r| CliConfig {
                files: r.files.clone(),
                output: r.output.clone(),
                overrides: r.overrides.clone(),
                path_selector: r.path_selector.clone(),
                strict_range_check: r.strict_range_check,
                disable_none: r.disable_none,
                verbose: r.verbose,
                debug: r.debug,
                sort_keys: r.sort_keys,
                show_hidden: r.show_hidden,
                include_schema_type_path: r.include_schema_type_path,
                fast_eval: r.fast_eval,
            }),
            kcl_options: r
                .kcl_options
                .iter()
                .map(|r| KeyValuePair {
                    key: r.key.clone(),
                    value: r.value.clone(),
                })
                .collect(),
        }
    }
}

/// Message representing KCL CLI configuration.
#[napi(object)]
pub struct CliConfig {
    /// List of files.
    pub files: Vec<String>,
    /// Output path.
    pub output: String,
    /// List of overrides.
    pub overrides: Vec<String>,
    /// Path selectors.
    pub path_selector: Vec<String>,
    /// Flag for strict range check.
    pub strict_range_check: bool,
    /// Flag to disable none values.
    pub disable_none: bool,
    /// Verbose level.
    pub verbose: i64,
    /// Debug flag.
    pub debug: bool,
    /// Flag to sort keys in YAML/JSON results.
    pub sort_keys: bool,
    /// Flag to show hidden attributes.
    pub show_hidden: bool,
    /// Flag to include schema type path in results.
    pub include_schema_type_path: bool,
    /// Flag for fast evaluation.
    pub fast_eval: bool,
}

/// Message representing a key-value pair.
#[napi(object)]
pub struct KeyValuePair {
    /// Key of the pair.
    pub key: String,
    /// Value of the pair.
    pub value: String,
}

#[napi(object)]
pub struct RenameResult {
    /// the file paths got changed
    pub changed_files: Vec<String>,
}

impl RenameResult {
    pub fn new(r: kcl_api::RenameResult) -> Self {
        Self {
            changed_files: r.changed_files,
        }
    }
}

// Message for rename response.
#[napi(object)]
pub struct RenameCodeResult {
    /// the changed code. a <filename>:<code> map
    pub changed_codes: HashMap<String, String>,
}

impl RenameCodeResult {
    pub fn new(r: kcl_api::RenameCodeResult) -> Self {
        Self {
            changed_codes: r.changed_codes,
        }
    }
}

/// Message for test response.
#[napi(object)]
pub struct TestResult {
    /// List of test case information.
    pub info: Vec<TestCaseInfo>,
}

impl TestResult {
    pub fn new(r: kcl_api::TestResult) -> Self {
        Self {
            info: r
                .info
                .iter()
                .map(|r| TestCaseInfo {
                    name: r.name.clone(),
                    error: r.error.clone(),
                    duration: r.duration as i64,
                    log_message: r.log_message.clone(),
                })
                .collect(),
        }
    }

    /// The `kcl_api` message this mirrors, for the RPCs that take a test
    /// result back as a *request* — `KclService.FormatTestReport` is the one
    /// today. `coverage` is not carried across: the napi `TestResult` has no
    /// such field to carry it in, so a result that went through JavaScript is
    /// a per-case result and nothing more.
    pub fn to_wire(&self) -> kcl_api::TestResult {
        kcl_api::TestResult {
            info: self
                .info
                .iter()
                .map(|r| kcl_api::TestCaseInfo {
                    name: r.name.clone(),
                    error: r.error.clone(),
                    duration: r.duration as u64,
                    log_message: r.log_message.clone(),
                    ..Default::default()
                })
                .collect(),
            coverage: None,
        }
    }
}

/// Message for format test report request arguments.
#[napi(object)]
pub struct FormatTestReportArgs {
    /// The test result to format, as returned by the `test` API.
    pub result: TestResult,
}

/// Message for format test report response.
#[napi(object)]
pub struct FormatTestReportResult {
    /// The pretty-printed report.
    pub report: String,
}

/// Message representing information about a single test case.
#[napi(object)]
pub struct TestCaseInfo {
    /// Name of the test case.
    pub name: String,
    /// Error message if any.
    pub error: String,
    /// Duration of the test case in microseconds.
    pub duration: i64,
    /// Log message from the test case.
    pub log_message: String,
}

/// Message representing a KCL type.
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
    /// Base schema if applicable.
    pub base_schema: Reference<KclType>,
    /// Function type if the KclType is a function.
    pub function: FunctionType,
    /// Optional schema index signature
    pub index_signature: Option<IndexSignature>,
}

#[napi(object)]
pub struct FunctionType {
    pub params: Vec<Parameter>,
    pub return_ty: Reference<KclType>,
}

#[napi(object)]
pub struct Parameter {
    pub name: String,
    pub ty: Reference<KclType>,
}

#[napi(object)]
pub struct IndexSignature {
    pub key_name: Option<String>,
    pub key: Reference<KclType>,
    pub val: Reference<KclType>,
    pub any_other: bool,
}

/// Message representing a decorator in KCL.
#[napi(object)]
pub struct Decorator {
    /// Name of the decorator.
    pub name: String,
    /// Arguments for the decorator.
    pub arguments: Vec<String>,
    /// Keyword arguments for the decorator as a map with keyword name as key.
    pub keywords: HashMap<String, String>,
}

/// Message representing an example in KCL.
#[napi(object)]
pub struct Example {
    /// Short description for the example.
    pub summary: String,
    /// Long description for the example.
    pub description: String,
    /// Embedded literal example.
    pub value: String,
}

/// Message for update dependencies response.
#[napi(object)]
pub struct UpdateDependenciesResult {
    /// List of external packages updated.
    pub external_pkgs: Vec<ExternalPkg>,
}

impl UpdateDependenciesResult {
    pub fn new(r: kcl_api::UpdateDependenciesResult) -> Self {
        Self {
            external_pkgs: r
                .external_pkgs
                .iter()
                .map(|p| ExternalPkg {
                    pkg_name: p.pkg_name.clone(),
                    pkg_path: p.pkg_path.clone(),
                })
                .collect(),
        }
    }
}

#[napi(object)]
pub struct GetVersionResult {
    pub version: String,
    pub checksum: String,
    pub git_sha: String,
    pub version_info: String,
}

impl GetVersionResult {
    pub fn new(r: kcl_api::GetVersionResult) -> Self {
        Self {
            version: r.version.clone(),
            checksum: r.checksum.clone(),
            git_sha: r.git_sha.clone(),
            version_info: r.version_info.clone(),
        }
    }
}

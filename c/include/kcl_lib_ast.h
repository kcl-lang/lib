/*
 * kcl_lib_ast.h — Typed AST package for the C binding.
 *
 * Mirrors the Java `AstJsonAlignmentTest`, Go `TestAstJsonAlignment`,
 * Python `tests/ast_test.py`, Node.js `__test__/ast_alignment.spec.mjs`,
 * .NET `KclLib.Tests/AstAlignmentTest.cs`, WASM
 * `tests/ast_alignment.test.ts`, Lua `spec/kcl_lib_ast_spec.lua`,
 * Swift `Tests/KclLibTests/AstJsonAlignmentTest.swift`, and Kotlin
 * `AstJsonAlignmentTest.kt`: parse a real KCL fixture through the
 * native FFI (`kcl_parse_file` / `kcl_parse_program`) and verify the
 * resulting `ast_json` string deserializes cleanly into the typed AST
 * structures declared here.
 *
 * Wire shape follows `kcl-lang/kcl crates/ast/src/ast.rs`:
 *
 *   - `#[serde(tag = "type")]` polymorphic dispatch — every `Stmt` /
 *     `Expr` / `Type` variant carries a `"type"` discriminator and is
 *     represented as a tagged-union struct in C (`<kind>_t` with a
 *     `kcl_<thing>_kind_t` enum + payload union).
 *   - Flat DTOs (`Decorator`, `SchemaConfig`, `ConfigEntry`, `Keyword`,
 *     `Arguments`, `MemberOrIndex`, `Target`) — see AST_DRIFT.md note A.
 *
 * The header embeds a minimal recursive-descent JSON parser so the
 * binding stays self-contained (no extra vendored dependency). It is
 * deliberately small — it accepts exactly the AST shapes emitted by
 * the Rust `ast::Module` serializer and rejects anything else.
 */

#ifndef KCL_LIB_AST_H
#define KCL_LIB_AST_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---------------------------------------------------------------- *
 * Position
 * ---------------------------------------------------------------- */

typedef struct kcl_pos {
    char* filename;
    int64_t line;
    int64_t column;
    int64_t end_line;
    int64_t end_column;
} kcl_pos_t;

/* ---------------------------------------------------------------- *
 * Minimal JSON parser (private — exposed only via the helpers below)
 * ---------------------------------------------------------------- */

typedef enum {
    KCL_JSON_NULL,
    KCL_JSON_BOOL,
    KCL_JSON_NUMBER,
    KCL_JSON_STRING,
    KCL_JSON_ARRAY,
    KCL_JSON_OBJECT,
} kcl_json_type_t;

typedef struct kcl_json_value kcl_json_value_t;

struct kcl_json_value {
    kcl_json_type_t type;
    union {
        bool boolean;
        double number;
        struct {
            char* data;
            size_t length;
        } string;
        struct {
            kcl_json_value_t** items;
            size_t count;
        } array;
        struct {
            char** keys;
            kcl_json_value_t** values;
            size_t count;
        } object;
    } u;
};

/* ---------------------------------------------------------------- *
 * Identifier (flat DTO used inside `NodeRef<Identifier>`).
 * ---------------------------------------------------------------- */

typedef struct kcl_identifier {
    /* `names` carries the dotted segments, e.g. ["foo", "bar", "baz"]
     * for `foo.bar.baz`. The wire shape carries full `Node<String>`
     * entries, so we strip the per-element position wrappers and keep
     * just the strings here — see AST_DRIFT.md note A. */
    char** names;
    size_t names_count;
    char** pkgpath;
    size_t pkgpath_count;
} kcl_identifier_t;

/* ---------------------------------------------------------------- *
 * `NodeRef<T>` helpers.
 *
 * The Rust `NodeRef` is a single struct wrapping `node`, `pos`, `id`.
 * The `node` payload has two wire shapes:
 *
 *   1. Polymorphic variants (`Stmt`/`Expr`/`KclTypeNode`) — `node` is a
 *      dict carrying the `"type"` discriminator and variant payload.
 *   2. Primitive wrappers (`Node<String>`, `Node<i64>`) — `node` is the
 *      raw value.
 *
 * We expose one `*_node_t` per variant kind so callers get typed access
 * without `void*` casts.
 * ---------------------------------------------------------------- */

typedef struct kcl_string_node {
    char* node;
    kcl_pos_t* pos;
    char* id;
} kcl_string_node_t;

typedef struct kcl_stmt_node {
    void* node; /* points at a kcl_stmt_t */
    kcl_pos_t* pos;
    char* id;
} kcl_stmt_node_t;

typedef struct kcl_expr_node {
    void* node; /* points at a kcl_expr_t */
    kcl_pos_t* pos;
    char* id;
} kcl_expr_node_t;

typedef struct kcl_type_node_node {
    void* node; /* points at a kcl_type_node_t */
    kcl_pos_t* pos;
    char* id;
} kcl_type_node_node_t;

typedef struct kcl_target_node {
    void* node; /* points at a kcl_target_t */
    kcl_pos_t* pos;
    char* id;
} kcl_target_node_t;

typedef struct kcl_arguments_node {
    void* node; /* points at a kcl_arguments_t */
    kcl_pos_t* pos;
    char* id;
} kcl_arguments_node_t;

typedef struct kcl_identifier_node {
    void* node; /* points at a kcl_identifier_t */
    kcl_pos_t* pos;
    char* id;
} kcl_identifier_node_t;

typedef struct kcl_schema_index_signature_node {
    void* node; /* points at a kcl_schema_index_signature_t */
    kcl_pos_t* pos;
    char* id;
} kcl_schema_index_signature_node_t;

/* Generic list-of-nodes helpers. Each variant has its own list type so
 * callers can iterate without casts. */
typedef struct kcl_stmt_node_list {
    kcl_stmt_node_t* items;
    size_t count;
} kcl_stmt_node_list_t;
typedef struct kcl_expr_node_list {
    kcl_expr_node_t* items;
    size_t count;
} kcl_expr_node_list_t;
typedef struct kcl_type_node_node_list {
    kcl_type_node_node_t* items;
    size_t count;
} kcl_type_node_node_list_t;
typedef struct kcl_target_node_list {
    kcl_target_node_t* items;
    size_t count;
} kcl_target_node_list_t;
typedef struct kcl_string_node_list {
    kcl_string_node_t* items;
    size_t count;
} kcl_string_node_list_t;
typedef struct kcl_identifier_node_list {
    kcl_identifier_node_t* items;
    size_t count;
} kcl_identifier_node_list_t;
typedef struct kcl_arguments_node_list {
    kcl_arguments_node_t* items;
    size_t count;
} kcl_arguments_node_list_t;

/* ---------------------------------------------------------------- *
 * Stmt enum + variants
 * ---------------------------------------------------------------- */

typedef enum {
    KCL_STMT_KIND_UNKNOWN = 0,
    KCL_STMT_KIND_EXPR,
    KCL_STMT_KIND_UNIFICATION,
    KCL_STMT_KIND_ASSIGN,
    KCL_STMT_KIND_SCHEMA,
    KCL_STMT_KIND_SCHEMA_ATTR,
    KCL_STMT_KIND_RULE,
    KCL_STMT_KIND_IMPORT,
    KCL_STMT_KIND_TYPE_ALIAS,
    KCL_STMT_KIND_ASSERT,
    KCL_STMT_KIND_IF,
} kcl_stmt_kind_t;

typedef struct kcl_expr_stmt {
    kcl_expr_node_list_t exprs;
} kcl_expr_stmt_t;

typedef struct kcl_unification_stmt {
    kcl_target_node_t target;
    void* value; /* kcl_schema_config_t* */
} kcl_unification_stmt_t;

typedef struct kcl_assign_stmt {
    kcl_target_node_list_t targets;
    kcl_type_node_node_t* ty; /* may be NULL */
    kcl_expr_node_t value;
} kcl_assign_stmt_t;

typedef struct kcl_schema_stmt {
    kcl_string_node_t* doc; /* may be NULL */
    kcl_string_node_t name;
    kcl_identifier_node_t* parent_name; /* may be NULL */
    kcl_identifier_node_t* for_host_name; /* may be NULL */
    bool is_mixin;
    bool is_protocol;
    kcl_arguments_node_t* args; /* may be NULL */
    kcl_identifier_node_list_t mixins;
    kcl_stmt_node_list_t body;
    /* Decorators carry a flat DTO payload (no polymorphic tag) — see
     * AST_DRIFT.md note A. We store them as a flat list of
     * `kcl_decorator_t` structs. */
    void* decorators; /* kcl_decorator_list_t* — see forward decl below */
    /* Check expressions are nested in their own NodeRef list — we
     * store them as `kcl_check_expr_node_list_t`. */
    void* checks;
    kcl_schema_index_signature_node_t* index_signature;
} kcl_schema_stmt_t;

typedef struct kcl_schema_attr {
    char* doc;
    kcl_string_node_t name;
    /* `op` is the wire enum string ("Assign", "Add", "Sub", ...). May
     * be NULL if the attribute has no augmented assignment. */
    char* op;
    kcl_expr_node_t* value;
    bool is_optional;
    void* decorators; /* kcl_decorator_list_t* */
    kcl_type_node_node_t* ty;
} kcl_schema_attr_t;

typedef struct kcl_rule_stmt {
    kcl_string_node_t* doc;
    kcl_string_node_t name;
    kcl_identifier_node_list_t parent_rules;
    void* decorators;
    void* checks;
    kcl_arguments_node_t* args;
    kcl_identifier_node_t* for_host_name;
} kcl_rule_stmt_t;

typedef struct kcl_import_stmt {
    char* path;
    char* as_name; /* may be NULL */
    char* pkg_name; /* may be NULL */
    char* pkg_root; /* may be NULL */
} kcl_import_stmt_t;

typedef struct kcl_type_alias_stmt {
    kcl_string_node_t name;
    kcl_type_node_node_t ty;
} kcl_type_alias_stmt_t;

typedef struct kcl_assert_stmt {
    kcl_expr_node_t source;
    kcl_string_node_t* assert_msg;
} kcl_assert_stmt_t;

typedef struct kcl_if_stmt {
    kcl_expr_node_t cond;
    kcl_stmt_node_list_t body;
    kcl_expr_node_t* or_else;
} kcl_if_stmt_t;

typedef struct kcl_stmt {
    kcl_stmt_kind_t kind;
    char* type_tag; /* raw `"type"` string — useful for unknown variants */
    union {
        kcl_expr_stmt_t expr_stmt;
        kcl_unification_stmt_t unification_stmt;
        kcl_assign_stmt_t assign_stmt;
        kcl_schema_stmt_t schema_stmt;
        kcl_schema_attr_t schema_attr;
        kcl_rule_stmt_t rule_stmt;
        kcl_import_stmt_t import_stmt;
        kcl_type_alias_stmt_t type_alias_stmt;
        kcl_assert_stmt_t assert_stmt;
        kcl_if_stmt_t if_stmt;
    } u;
} kcl_stmt_t;

/* ---------------------------------------------------------------- *
 * Expr enum + variants
 * ---------------------------------------------------------------- */

typedef enum {
    KCL_EXPR_KIND_UNKNOWN = 0,
    KCL_EXPR_KIND_TARGET,
    KCL_EXPR_KIND_IDENTIFIER,
    KCL_EXPR_KIND_UNARY,
    KCL_EXPR_KIND_BINARY,
    KCL_EXPR_KIND_IF,
    KCL_EXPR_KIND_SELECTOR,
    KCL_EXPR_KIND_CALL,
    KCL_EXPR_KIND_PAREN,
    KCL_EXPR_KIND_QUANT,
    KCL_EXPR_KIND_LIST,
    KCL_EXPR_KIND_LIST_IF_ITEM,
    KCL_EXPR_KIND_LIST_COMP,
    KCL_EXPR_KIND_STARRED,
    KCL_EXPR_KIND_DICT_COMP,
    KCL_EXPR_KIND_CONFIG_IF_ENTRY,
    KCL_EXPR_KIND_COMP_CLAUSE,
    KCL_EXPR_KIND_SCHEMA,
    KCL_EXPR_KIND_CONFIG,
    KCL_EXPR_KIND_LAMBDA,
    KCL_EXPR_KIND_SUBSCRIPT,
    KCL_EXPR_KIND_COMPARE,
    KCL_EXPR_KIND_NUMBER_LIT,
    KCL_EXPR_KIND_STRING_LIT,
    KCL_EXPR_KIND_NAME_CONSTANT_LIT,
    KCL_EXPR_KIND_JOINED_STRING,
    KCL_EXPR_KIND_FORMATTED_VALUE,
    KCL_EXPR_KIND_MISSING,
    KCL_EXPR_KIND_CHECK,
} kcl_expr_kind_t;

typedef struct kcl_target_expr {
    kcl_string_node_t name;
} kcl_target_expr_t;

typedef struct kcl_identifier_expr {
    /* Mirror Rust's `IdentifierExpr { names: Vec<Node<String>>, ... }` —
     * `names` is an array of `Node<String>` (one element per dotted
     * segment, e.g. `["foo", "bar", "baz"]` for `foo.bar.baz`). */
    kcl_string_node_list_t names;
    char** pkgpath;
    size_t pkgpath_count;
} kcl_identifier_expr_t;

typedef struct kcl_unary_expr {
    char* op; /* "UAdd", "USub", "Invert", "Not" */
    kcl_expr_node_t operand;
} kcl_unary_expr_t;

typedef struct kcl_binary_expr {
    char* op;
    kcl_expr_node_t left;
    kcl_expr_node_t right;
} kcl_binary_expr_t;

typedef struct kcl_if_expr {
    kcl_expr_node_t cond;
    kcl_expr_node_t body;
    kcl_expr_node_t* or_else;
} kcl_if_expr_t;

typedef struct kcl_selector_expr {
    kcl_expr_node_t value;
    kcl_string_node_t attr_name;
} kcl_selector_expr_t;

typedef struct kcl_call_expr {
    kcl_expr_node_t func;
    kcl_expr_node_list_t args;
    void* keywords; /* kcl_keyword_node_list_t* */
} kcl_call_expr_t;

typedef struct kcl_paren_expr {
    kcl_expr_node_t expr;
} kcl_paren_expr_t;

typedef struct kcl_quant_expr {
    kcl_target_node_t target;
    /* `variables` is a list of `NodeRef<QuantOperation>` — flat DTOs. */
    void* variables; /* kcl_quant_operation_node_list_t* */
    void* op;       /* kcl_quant_operation_t* (single top-level op) */
    kcl_expr_node_t cond;
} kcl_quant_expr_t;

typedef struct kcl_list_expr {
    kcl_expr_node_list_t elts;
} kcl_list_expr_t;

typedef struct kcl_list_if_item_expr {
    kcl_expr_node_t if_expr; /* also exposed as `expr` */
    kcl_expr_node_t* or_else;
} kcl_list_if_item_expr_t;

typedef struct kcl_list_comp {
    kcl_expr_node_t elt;
    void* generators; /* kcl_comp_clause_node_list_t* */
    kcl_expr_node_t* cond;
} kcl_list_comp_t;

typedef struct kcl_starred_expr {
    kcl_expr_node_t value;
    char* ctx; /* "Load" | "Store" | "Del" */
} kcl_starred_expr_t;

typedef struct kcl_dict_comp {
    kcl_expr_node_t key;
    kcl_expr_node_t value;
    void* generators;
    kcl_expr_node_t* cond;
} kcl_dict_comp_t;

typedef struct kcl_config_if_entry_expr {
    kcl_expr_node_t if_expr; /* also exposed as `expr` */
} kcl_config_if_entry_expr_t;

typedef struct kcl_comp_clause {
    kcl_target_node_list_t targets;
    kcl_expr_node_t iter;
    kcl_expr_node_list_t ifs;
} kcl_comp_clause_t;

typedef struct kcl_comp_clause_node {
    void* node; /* kcl_comp_clause_t* */
    kcl_pos_t* pos;
    char* id;
} kcl_comp_clause_node_t;

typedef struct kcl_comp_clause_node_list {
    kcl_comp_clause_node_t* items;
    size_t count;
} kcl_comp_clause_node_list_t;

typedef struct kcl_schema_expr {
    kcl_expr_node_t name;
    kcl_expr_node_list_t args;
    void* kwargs;
    kcl_expr_node_t config;
} kcl_schema_expr_t;

typedef struct kcl_config_expr {
    void* items; /* kcl_config_entry_node_list_t* */
} kcl_config_expr_t;

typedef struct kcl_lambda_expr {
    kcl_arguments_node_t args;
    kcl_stmt_node_list_t body;
    kcl_type_node_node_t* return_ty;
} kcl_lambda_expr_t;

typedef struct kcl_subscript_expr {
    kcl_expr_node_t value;
    kcl_expr_node_t index;
} kcl_subscript_expr_t;

typedef struct kcl_compare_expr {
    kcl_expr_node_t left;
    char** ops; /* e.g. ["Lt", "LtE"] */
    size_t ops_count;
    kcl_expr_node_list_t comparators;
} kcl_compare_expr_t;

typedef struct kcl_number_lit_value {
    char* raw_value;
    double value;
    char* binary_suffix; /* "" | "I" | "M" | "K" | "Mi" | ... */
} kcl_number_lit_value_t;

typedef struct kcl_number_lit {
    char* binary_suffix; /* kept for the deprecated top-level field */
    kcl_number_lit_value_t value;
} kcl_number_lit_t;

typedef struct kcl_string_lit {
    bool is_long_string;
    char* raw_value;
    char* value;
} kcl_string_lit_t;

typedef struct kcl_name_constant_lit {
    char* value; /* "True" | "False" | "None" | "Undefined" */
} kcl_name_constant_lit_t;

typedef struct kcl_joined_string {
    kcl_expr_node_list_t values;
    bool is_long_string;
    char* raw_value;
} kcl_joined_string_t;

typedef struct kcl_formatted_value {
    kcl_expr_node_t value;
    char* spec; /* may be NULL */
} kcl_formatted_value_t;

typedef struct kcl_missing_expr {
    int placeholder; /* empty struct */
} kcl_missing_expr_t;

typedef struct kcl_check_expr {
    /* Wire shape: {test, if_cond, msg} — see `ast::CheckExpr` in
     * `crates/ast/src/ast.rs`. The "predicate" is `test`, not `cond`;
     * `if_cond` is the optional `if <expr>` gate. */
    kcl_expr_node_t test;
    kcl_expr_node_t* if_cond;
    kcl_string_node_t* msg;
} kcl_check_expr_t;

typedef struct kcl_check_expr_node {
    void* node; /* kcl_check_expr_t* */
    kcl_pos_t* pos;
    char* id;
} kcl_check_expr_node_t;

typedef struct kcl_check_expr_node_list {
    kcl_check_expr_node_t* items;
    size_t count;
} kcl_check_expr_node_list_t;

typedef struct kcl_expr {
    kcl_expr_kind_t kind;
    char* type_tag;
    union {
        kcl_target_expr_t target_expr;
        kcl_identifier_expr_t identifier_expr;
        kcl_unary_expr_t unary_expr;
        kcl_binary_expr_t binary_expr;
        kcl_if_expr_t if_expr;
        kcl_selector_expr_t selector_expr;
        kcl_call_expr_t call_expr;
        kcl_paren_expr_t paren_expr;
        kcl_quant_expr_t quant_expr;
        kcl_list_expr_t list_expr;
        kcl_list_if_item_expr_t list_if_item_expr;
        kcl_list_comp_t list_comp;
        kcl_starred_expr_t starred_expr;
        kcl_dict_comp_t dict_comp;
        kcl_config_if_entry_expr_t config_if_entry_expr;
        kcl_comp_clause_t comp_clause;
        kcl_schema_expr_t schema_expr;
        kcl_config_expr_t config_expr;
        kcl_lambda_expr_t lambda_expr;
        kcl_subscript_expr_t subscript_expr;
        kcl_compare_expr_t compare_expr;
        kcl_number_lit_t number_lit;
        kcl_string_lit_t string_lit;
        kcl_name_constant_lit_t name_constant_lit;
        kcl_joined_string_t joined_string;
        kcl_formatted_value_t formatted_value;
        kcl_missing_expr_t missing_expr;
        kcl_check_expr_t check_expr;
    } u;
} kcl_expr_t;

/* ---------------------------------------------------------------- *
 * KclTypeNode enum + variants
 * ---------------------------------------------------------------- */

typedef enum {
    KCL_TYPE_KIND_UNKNOWN = 0,
    KCL_TYPE_KIND_ANY,
    KCL_TYPE_KIND_BASIC,
    KCL_TYPE_KIND_LIST,
    KCL_TYPE_KIND_DICT,
    KCL_TYPE_KIND_SCHEMA_REF,
    KCL_TYPE_KIND_LITERAL,
    KCL_TYPE_KIND_FUNCTION,
    KCL_TYPE_KIND_UNION,
    KCL_TYPE_KIND_NAMED,
    KCL_TYPE_KIND_STR_LITERAL,
    KCL_TYPE_KIND_INT_LITERAL,
    KCL_TYPE_KIND_FLOAT_LITERAL,
    KCL_TYPE_KIND_BOOL_LITERAL,
    KCL_TYPE_KIND_KEY_VALUE,
} kcl_type_kind_t;

typedef struct kcl_any_type {
    int placeholder;
} kcl_any_type_t;

typedef struct kcl_basic_type {
    char* type_disc; /* always "Basic" */
    char* kind; /* e.g. "str", "int", "bool" */
} kcl_basic_type_t;

typedef struct kcl_list_type {
    kcl_type_node_node_t inner_type;
} kcl_list_type_t;

typedef struct kcl_dict_type {
    kcl_type_node_node_t key_type;
    kcl_type_node_node_t value_type;
} kcl_dict_type_t;

typedef struct kcl_schema_ref_type {
    kcl_string_node_t schema_name;
    char** pkgpath;
    size_t pkgpath_count;
} kcl_schema_ref_type_t;

typedef struct kcl_literal_type {
    /* The wire shape is `{"type":"Literal","value":<primitive>}`. The
     * `value` is a tagged union: {String, Int, Float, Bool}. We store
     * the raw JSON value plus a discriminator. */
    char* value_kind; /* "String" | "Int" | "Float" | "Bool" */
    char* string_value; /* may be NULL */
    int64_t int_value;
    bool has_int_value;
    double float_value;
    bool has_float_value;
    bool bool_value;
    bool has_bool_value;
} kcl_literal_type_t;

typedef struct kcl_function_type {
    kcl_type_node_node_list_t params;
    kcl_type_node_node_t ret;
} kcl_function_type_t;

typedef struct kcl_union_type {
    bool any;
    kcl_type_node_node_list_t types;
} kcl_union_type_t;

typedef struct kcl_named_type {
    kcl_identifier_node_t name;
} kcl_named_type_t;

typedef struct kcl_str_literal_type {
    char* value;
} kcl_str_literal_type_t;

typedef struct kcl_int_literal_type {
    int64_t value;
} kcl_int_literal_type_t;

typedef struct kcl_float_literal_type {
    double value;
} kcl_float_literal_type_t;

typedef struct kcl_bool_literal_type {
    bool value;
} kcl_bool_literal_type_t;

typedef struct kcl_key_value_type {
    kcl_type_node_node_t key;
    kcl_type_node_node_t value;
} kcl_key_value_type_t;

typedef struct kcl_type_node {
    kcl_type_kind_t kind;
    char* type_tag;
    union {
        kcl_any_type_t any_type;
        kcl_basic_type_t basic_type;
        kcl_list_type_t list_type;
        kcl_dict_type_t dict_type;
        kcl_schema_ref_type_t schema_ref_type;
        kcl_literal_type_t literal_type;
        kcl_function_type_t function_type;
        kcl_union_type_t union_type;
        kcl_named_type_t named_type;
        kcl_str_literal_type_t str_literal_type;
        kcl_int_literal_type_t int_literal_type;
        kcl_float_literal_type_t float_literal_type;
        kcl_bool_literal_type_t bool_literal_type;
        kcl_key_value_type_t key_value_type;
    } u;
} kcl_type_node_t;

/* ---------------------------------------------------------------- *
 * Flat DTOs (note A)
 * ---------------------------------------------------------------- */

typedef struct kcl_decorator {
    /* `func` is a `NodeRef<Expr>` that — in the flat shape — lacks the
     * polymorphic `"type":"Call"` tag. We keep it as `kcl_expr_node_t`
     * so callers can recursively parse the inner expression. */
    kcl_expr_node_t* func;
    kcl_expr_node_list_t args;
    void* keywords;
} kcl_decorator_t;

typedef struct kcl_decorator_node {
    void* node; /* kcl_decorator_t* */
    kcl_pos_t* pos;
    char* id;
} kcl_decorator_node_t;

typedef struct kcl_decorator_node_list {
    kcl_decorator_node_t* items;
    size_t count;
} kcl_decorator_node_list_t;

typedef struct kcl_schema_config {
    kcl_expr_node_t* name;
    kcl_expr_node_list_t args;
    void* kwargs;
    kcl_expr_node_t* config;
} kcl_schema_config_t;

typedef struct kcl_config_entry {
    kcl_expr_node_t key;
    kcl_expr_node_t value;
    char* operation; /* "Union" | "Override" — may be NULL */
    bool is_shorthand;
} kcl_config_entry_t;

typedef struct kcl_config_entry_node {
    void* node;
    kcl_pos_t* pos;
    char* id;
} kcl_config_entry_node_t;

typedef struct kcl_config_entry_node_list {
    kcl_config_entry_node_t* items;
    size_t count;
} kcl_config_entry_node_list_t;

typedef struct kcl_keyword {
    kcl_expr_node_t* arg; /* may be NULL */
    kcl_expr_node_t value;
} kcl_keyword_t;

typedef struct kcl_keyword_node {
    void* node; /* kcl_keyword_t* */
    kcl_pos_t* pos;
    char* id;
} kcl_keyword_node_t;

typedef struct kcl_keyword_node_list {
    kcl_keyword_node_t* items;
    size_t count;
} kcl_keyword_node_list_t;

typedef struct kcl_arguments {
    kcl_expr_node_list_t args;
    kcl_expr_node_list_t defaults;
    kcl_type_node_node_list_t ty_list;
} kcl_arguments_t;

typedef enum {
    KCL_MEMBER_OR_INDEX_MEMBER,
    KCL_MEMBER_OR_INDEX_INDEX,
} kcl_member_or_index_kind_t;

typedef struct kcl_member_or_index {
    kcl_member_or_index_kind_t kind;
    kcl_string_node_t member; /* used when kind == MEMBER */
    kcl_expr_node_t index;     /* used when kind == INDEX */
} kcl_member_or_index_t;

typedef struct kcl_target {
    kcl_string_node_t name;
    kcl_member_or_index_t* paths;
    size_t paths_count;
    char* pkgpath;
} kcl_target_t;

typedef struct kcl_quant_operation {
    kcl_target_node_t target;
    char* op; /* "all" | "any" | "filter" | "map" */
} kcl_quant_operation_t;

typedef struct kcl_quant_operation_node {
    void* node; /* kcl_quant_operation_t* */
    kcl_pos_t* pos;
    char* id;
} kcl_quant_operation_node_t;

typedef struct kcl_quant_operation_node_list {
    kcl_quant_operation_node_t* items;
    size_t count;
} kcl_quant_operation_node_list_t;

typedef struct kcl_schema_index_signature {
    kcl_type_node_node_t key_type;
    kcl_type_node_node_t value_type;
} kcl_schema_index_signature_t;

/* ---------------------------------------------------------------- *
 * Module & Program
 * ---------------------------------------------------------------- */

typedef struct kcl_module {
    char* filename;
    kcl_string_node_t* doc; /* may be NULL */
    kcl_stmt_node_list_t body;
    kcl_string_node_list_t comments;
} kcl_module_t;

typedef struct kcl_program {
    char* root;
    kcl_module_t** main_package;
    size_t main_package_count;
    /* The wire shape also carries a `pkgs` map of package name →
     * module list; we only expose the `__main__` package modules
     * here, matching the Lua / Swift / Kotlin bindings. */
} kcl_program_t;

/* ---------------------------------------------------------------- *
 * Public API
 * ---------------------------------------------------------------- */

/**
 * Parse the `ast_json` string emitted by `kcl_parse_file` into a typed
 * `kcl_module_t`. The caller must release the result with
 * `kcl_module_free` when done. Returns NULL on parse failure.
 */
kcl_module_t* kcl_ast_parse_module(const char* ast_json);

/**
 * Parse the `ast_json` string emitted by `kcl_parse_program` into a
 * typed `kcl_program_t`. The caller must release the result with
 * `kcl_program_free` when done. Returns NULL on parse failure.
 */
kcl_program_t* kcl_ast_parse_program(const char* ast_json);

/** Free a module returned by `kcl_ast_parse_module`. */
void kcl_module_free(kcl_module_t* module);

/** Free a program returned by `kcl_ast_parse_program`. */
void kcl_program_free(kcl_program_t* program);

/* Internal — exposed for testing only. */
const kcl_json_value_t* kcl_json_object_get(const kcl_json_value_t* obj, const char* key);
size_t kcl_json_array_length(const kcl_json_value_t* arr);
const kcl_json_value_t* kcl_json_array_get(const kcl_json_value_t* arr, size_t i);
kcl_json_value_t* kcl_json_parse(const char* text);
void kcl_json_free(kcl_json_value_t* v);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* KCL_LIB_AST_H */
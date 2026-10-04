/*
 * kcl_lib_ast.h — Typed AST package for the C binding.
 *
 * Deserializes the `ast_json` string produced by `kcl_parse_file` /
 * `kcl_parse_program` into typed C structures. The contract is
 * `kcl-lang/kcl crates/ast/src/ast.rs`, and three serde shapes decide
 * everything below:
 *
 *   1. `Stmt` and `Expr` are `#[serde(tag = "type")]` — internally
 *      tagged with no `rename_all`, so the wire tag is the variant
 *      name verbatim (`NumberLit`, `ListIfItem`, `ConfigIfEntry`).
 *      Newtype variants over structs are *flattened* into the same
 *      object: `{"type":"Identifier","names":[…],"pkgpath":"","ctx":"Load"}`
 *      — never `{"type":"Identifier","identifier":{…}}`.
 *
 *   2. `Type` is `#[serde(tag = "type", content = "value")]` —
 *      adjacently tagged, so the tag names the *shape* and the
 *      payload sits under `value`: `{"type":"Basic","value":"Int"}`.
 *      Newtype payloads are inlined into `value`. `Any` is the only
 *      unit variant, so it is the bare `{"type":"Any"}` with no
 *      `value` key at all. `MemberOrIndex`, `NumberLitValue` and
 *      `LiteralType` use the same shape.
 *
 *   3. Plain structs carry no discriminator even inside a tagged
 *      node. `Identifier`, `Target`, `Keyword`, `Arguments`,
 *      `ConfigEntry`, `CheckExpr`, `CallExpr`, `CompClause`,
 *      `SchemaExpr`, `SchemaIndexSignature` and `Comment` are all
 *      declared as structs rather than enum variants, so
 *      `SchemaStmt.decorators` is a bare `{func,args,keywords}` per
 *      element and `SchemaStmt.checks` a bare `{test,if_cond,msg}`.
 *
 * One more rule matters as much as the shapes: `Node<T>` is flat. The
 * position fields sit directly on the wrapper — `id`, `node`,
 * `filename`, `line`, `column`, `end_line`, `end_column` — with no
 * nested `pos` object.
 *
 * `Vec<Option<NodeRef<T>>>` (only `Arguments.defaults` and
 * `Arguments.ty_list`) is index-aligned, so those are modelled with an
 * explicit `present` flag: dropping a positional null would shift every
 * later annotation onto the wrong parameter.
 *
 * The header embeds a minimal recursive-descent JSON parser (exposed
 * via the `kcl_json_*` helpers below) so the binding stays
 * self-contained with no vendored dependency.
 *
 * The declaration order below follows the type graph, not the Rust
 * source order: `Identifier` and `Type` are declared ahead of the DTOs
 * that embed them by value.
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
 * Scalar enums
 *
 * These mirror the Rust enums one-for-one. They are plain C enums
 * rather than strings so a mismatch shows up as a compile error in a
 * `switch`, and every value is meaningful — there is no "unknown"
 * case hiding a typo behind a fallback.
 * ---------------------------------------------------------------- */

typedef enum {
    KCL_EXPR_CONTEXT_LOAD = 0,
    KCL_EXPR_CONTEXT_STORE = 1,
} kcl_expr_context_t;

typedef enum {
    KCL_UNARY_OP_UADD = 0,
    KCL_UNARY_OP_USUB = 1,
    KCL_UNARY_OP_INVERT = 2,
    KCL_UNARY_OP_NOT = 3,
} kcl_unary_op_t;

typedef enum {
    KCL_BIN_OP_ADD = 0,
    KCL_BIN_OP_SUB = 1,
    KCL_BIN_OP_MUL = 2,
    KCL_BIN_OP_DIV = 3,
    KCL_BIN_OP_MOD = 4,
    KCL_BIN_OP_POW = 5,
    KCL_BIN_OP_FLOOR_DIV = 6,
    KCL_BIN_OP_LSHIFT = 7,
    KCL_BIN_OP_RSHIFT = 8,
    KCL_BIN_OP_BIT_XOR = 9,
    KCL_BIN_OP_BIT_AND = 10,
    KCL_BIN_OP_BIT_OR = 11,
    KCL_BIN_OP_AND = 12,
    KCL_BIN_OP_OR = 13,
    KCL_BIN_OP_AS = 14,
} kcl_bin_op_t;

typedef enum {
    KCL_CMP_OP_EQ = 0,
    KCL_CMP_OP_NOT_EQ = 1,
    KCL_CMP_OP_LT = 2,
    KCL_CMP_OP_LT_E = 3,
    KCL_CMP_OP_GT = 4,
    KCL_CMP_OP_GT_E = 5,
    KCL_CMP_OP_IS = 6,
    KCL_CMP_OP_IN = 7,
    KCL_CMP_OP_NOT_IN = 8,
    KCL_CMP_OP_NOT = 9,
    KCL_CMP_OP_IS_NOT = 10,
} kcl_cmp_op_t;

typedef enum {
    KCL_AUG_OP_ASSIGN = 0,
    KCL_AUG_OP_ADD = 1,
    KCL_AUG_OP_SUB = 2,
    KCL_AUG_OP_MUL = 3,
    KCL_AUG_OP_DIV = 4,
    KCL_AUG_OP_MOD = 5,
    KCL_AUG_OP_POW = 6,
    KCL_AUG_OP_FLOOR_DIV = 7,
    KCL_AUG_OP_LSHIFT = 8,
    KCL_AUG_OP_RSHIFT = 9,
    KCL_AUG_OP_BIT_XOR = 10,
    KCL_AUG_OP_BIT_AND = 11,
    KCL_AUG_OP_BIT_OR = 12,
} kcl_aug_op_t;

typedef enum {
    KCL_QUANT_OPERATION_ALL = 0,
    KCL_QUANT_OPERATION_ANY = 1,
    KCL_QUANT_OPERATION_FILTER = 2,
    KCL_QUANT_OPERATION_MAP = 3,
} kcl_quant_operation_t;

typedef enum {
    KCL_CONFIG_ENTRY_OPERATION_UNION = 0,
    KCL_CONFIG_ENTRY_OPERATION_OVERRIDE = 1,
    KCL_CONFIG_ENTRY_OPERATION_INSERT = 2,
} kcl_config_entry_operation_t;

typedef enum {
    KCL_BASIC_TYPE_BOOL = 0,
    KCL_BASIC_TYPE_INT = 1,
    KCL_BASIC_TYPE_FLOAT = 2,
    KCL_BASIC_TYPE_STR = 3,
} kcl_basic_type_t;

typedef enum {
    KCL_NAME_CONSTANT_TRUE = 0,
    KCL_NAME_CONSTANT_FALSE = 1,
    KCL_NAME_CONSTANT_NONE = 2,
    KCL_NAME_CONSTANT_UNDEFINED = 3,
} kcl_name_constant_t;

/* `k` and `K` (and `m`/`M`) are distinct variants. */
typedef enum {
    KCL_NUMBER_BINARY_SUFFIX_N = 0,
    KCL_NUMBER_BINARY_SUFFIX_U = 1,
    KCL_NUMBER_BINARY_SUFFIX_M = 2,
    KCL_NUMBER_BINARY_SUFFIX_K = 3,
    KCL_NUMBER_BINARY_SUFFIX_K_UPPER = 4,
    KCL_NUMBER_BINARY_SUFFIX_M_UPPER = 5,
    KCL_NUMBER_BINARY_SUFFIX_G = 6,
    KCL_NUMBER_BINARY_SUFFIX_T = 7,
    KCL_NUMBER_BINARY_SUFFIX_P = 8,
    KCL_NUMBER_BINARY_SUFFIX_KI = 9,
    KCL_NUMBER_BINARY_SUFFIX_MI = 10,
    KCL_NUMBER_BINARY_SUFFIX_GI = 11,
    KCL_NUMBER_BINARY_SUFFIX_TI = 12,
    KCL_NUMBER_BINARY_SUFFIX_PI = 13,
} kcl_number_binary_suffix_t;

typedef enum {
    KCL_MEMBER_OR_INDEX_MEMBER = 0,
    KCL_MEMBER_OR_INDEX_INDEX = 1,
} kcl_member_or_index_kind_t;

typedef enum {
    KCL_NUMBER_LIT_VALUE_INT = 0,
    KCL_NUMBER_LIT_VALUE_FLOAT = 1,
} kcl_number_lit_value_kind_t;

typedef enum {
    KCL_LITERAL_TYPE_BOOL = 0,
    KCL_LITERAL_TYPE_INT = 1,
    KCL_LITERAL_TYPE_FLOAT = 2,
    KCL_LITERAL_TYPE_STR = 3,
} kcl_literal_type_kind_t;

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
 * Minimal JSON parser
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
 * `NodeRef<T>` wrappers
 *
 * The wire wrapper is flat — `{id, node, filename, line, column,
 * end_line, end_column}` — so `pos` and `id` are read straight off the
 * same object as `node`. `node` is a `void*` pointing at the decoded
 * payload; each payload kind gets its own wrapper struct so callers get
 * a type to cast to without ambiguity about which list it came from.
 *
 * `Node<String>` is special-cased: its payload is a bare string, so
 * `kcl_string_node_t` carries it inline instead of behind a pointer.
 * ---------------------------------------------------------------- */

typedef struct kcl_string_node {
    char* node;
    kcl_pos_t* pos;
    char* id;
} kcl_string_node_t;

#define KCL_DECLARE_NODE(name)                                              \
    typedef struct name {                                                    \
        void* node;                                                         \
        kcl_pos_t* pos;                                                     \
        char* id;                                                           \
    } name##_t

KCL_DECLARE_NODE(kcl_stmt_node);
KCL_DECLARE_NODE(kcl_expr_node);
KCL_DECLARE_NODE(kcl_type_ref_node);
KCL_DECLARE_NODE(kcl_target_node);
KCL_DECLARE_NODE(kcl_identifier_node);
KCL_DECLARE_NODE(kcl_arguments_node);
KCL_DECLARE_NODE(kcl_check_expr_node);
KCL_DECLARE_NODE(kcl_call_expr_node);
KCL_DECLARE_NODE(kcl_comp_clause_node);
KCL_DECLARE_NODE(kcl_config_entry_node);
KCL_DECLARE_NODE(kcl_keyword_node);
KCL_DECLARE_NODE(kcl_schema_expr_node);
KCL_DECLARE_NODE(kcl_schema_index_signature_node);
KCL_DECLARE_NODE(kcl_comment_node);

#define KCL_DECLARE_NODE_LIST(name)                                         \
    typedef struct name##_node_list {                                       \
        name##_node_t* items;                                               \
        size_t count;                                                       \
    } name##_node_list_t

KCL_DECLARE_NODE_LIST(kcl_string);
KCL_DECLARE_NODE_LIST(kcl_stmt);
KCL_DECLARE_NODE_LIST(kcl_expr);
KCL_DECLARE_NODE_LIST(kcl_type_ref);
KCL_DECLARE_NODE_LIST(kcl_target);
KCL_DECLARE_NODE_LIST(kcl_identifier);
KCL_DECLARE_NODE_LIST(kcl_arguments);
KCL_DECLARE_NODE_LIST(kcl_check_expr);
KCL_DECLARE_NODE_LIST(kcl_call_expr);
KCL_DECLARE_NODE_LIST(kcl_comp_clause);
KCL_DECLARE_NODE_LIST(kcl_config_entry);
KCL_DECLARE_NODE_LIST(kcl_keyword);
KCL_DECLARE_NODE_LIST(kcl_comment);

/*
 * `Vec<Option<NodeRef<Expr>>>` — `Arguments.defaults`. The `present`
 * flag is load-bearing: the vec is index-aligned with
 * `Arguments.args`, so collapsing a positional null to a missing
 * element would shift every later annotation onto the wrong parameter.
 */
typedef struct kcl_opt_expr_node {
    bool present;
    kcl_expr_node_t value;
} kcl_opt_expr_node_t;

typedef struct kcl_opt_expr_node_list {
    kcl_opt_expr_node_t* items;
    size_t count;
} kcl_opt_expr_node_list_t;

/* ---------------------------------------------------------------- *
 * `Identifier` — declared ahead of `Type` and the DTOs that embed it
 * by value. No `"type"` tag: it is a struct, not an enum variant, and
 * it is *flattened* into the object of the `Expr::Identifier` that
 * carries it.
 * ---------------------------------------------------------------- */

typedef struct kcl_identifier {
    /* `names` is `Vec<Node<String>>`: one positioned string per dotted
     * segment, e.g. `a.b.c` yields three entries. */
    kcl_string_node_list_t names;
    char* pkgpath; /* a single string, not a list */
    kcl_expr_context_t ctx;
} kcl_identifier_t;

/* ---------------------------------------------------------------- *
 * `Type` (`#[serde(tag = "type", content = "value")]`)
 *
 * The tag names the *shape*, not the variant payload class, and the
 * payload is inlined under `value`. `Any` is the only unit variant, so
 * the wire is the bare `{"type":"Any"}` with no `value` key at all.
 * ---------------------------------------------------------------- */

typedef enum {
    KCL_TYPE_KIND_UNKNOWN = 0,
    KCL_TYPE_KIND_ANY = 1,
    KCL_TYPE_KIND_NAMED = 2,
    KCL_TYPE_KIND_BASIC = 3,
    KCL_TYPE_KIND_LIST = 4,
    KCL_TYPE_KIND_DICT = 5,
    KCL_TYPE_KIND_UNION = 6,
    KCL_TYPE_KIND_LITERAL = 7,
    KCL_TYPE_KIND_FUNCTION = 8,
} kcl_type_kind_t;

typedef struct kcl_type_node_data {
    kcl_type_kind_t kind;
    char* type_tag; /* the raw `"type"` string, kept for unknown variants */
    union {
        struct {
            /* `Named(Identifier)` inlines the newtype, so this is a
             * bare `{names, pkgpath, ctx}` object, not a wrapper. */
            kcl_identifier_t name;
        } named_type;
        struct {
            kcl_basic_type_t basic;
        } basic_type;
        struct {
            kcl_type_ref_node_t* inner_type; /* `Option<NodeRef<Type>>` */
        } list_type;
        struct {
            kcl_type_ref_node_t* key_type;   /* `Option<NodeRef<Type>>` */
            kcl_type_ref_node_t* value_type; /* `Option<NodeRef<Type>>` */
        } dict_type;
        struct {
            kcl_type_ref_node_list_t type_elements;
        } union_type;
        struct {
            /* `LiteralType` is itself tag+content, so `value` here is a
             * second tagged document: `{"type":"Int","value":{"value":1}}`. */
            kcl_literal_type_kind_t kind;
            bool bool_value;
            struct {
                int64_t value;
                kcl_number_binary_suffix_t suffix;
                bool has_suffix;
            } int_value;
            double float_value;
            char* str_value;
        } literal_type;
        struct {
            kcl_type_ref_node_list_t* params_ty; /* `Option<Vec<NodeRef<Type>>>` */
            kcl_type_ref_node_t* ret_ty;          /* `Option<NodeRef<Type>>` */
        } function_type;
    } u;
} kcl_type_node_t;

/* `Vec<Option<NodeRef<Type>>>` — `Arguments.ty_list`. */
typedef struct kcl_opt_type_node {
    bool present;
    kcl_type_ref_node_t value;
} kcl_opt_type_node_t;

typedef struct kcl_opt_type_node_list {
    kcl_opt_type_node_t* items;
    size_t count;
} kcl_opt_type_node_list_t;

/* ---------------------------------------------------------------- *
 * Flat DTOs — declared as structs upstream, so no `"type"` tag
 * ---------------------------------------------------------------- */

typedef struct kcl_member_or_index {
    kcl_member_or_index_kind_t kind;
    kcl_string_node_t member;      /* when kind == MEMBER */
    kcl_expr_node_t* index;        /* when kind == INDEX */
} kcl_member_or_index_t;

typedef struct kcl_target {
    kcl_string_node_t name;
    /* `Vec<MemberOrIndex>`, bare — no `NodeRef` wrapper. */
    kcl_member_or_index_t* paths;
    size_t paths_count;
    char* pkgpath;
} kcl_target_t;

typedef struct kcl_keyword {
    kcl_identifier_node_t arg; /* `NodeRef<Identifier>`, not an `Expr` */
    kcl_expr_node_t* value;   /* `Option<NodeRef<Expr>>` */
} kcl_keyword_t;

typedef struct kcl_arguments {
    kcl_identifier_node_list_t args;
    kcl_opt_expr_node_list_t defaults;
    kcl_opt_type_node_list_t ty_list;
} kcl_arguments_t;

typedef struct kcl_call_expr {
    kcl_expr_node_t func;
    kcl_expr_node_list_t args;
    kcl_keyword_node_list_t keywords;
} kcl_call_expr_t;

typedef struct kcl_check_expr {
    kcl_expr_node_t test;
    kcl_expr_node_t* if_cond;
    kcl_expr_node_t* msg; /* `NodeRef<Expr>` — the wire has no bare-string msg */
} kcl_check_expr_t;

typedef struct kcl_config_entry {
    kcl_expr_node_t* key; /* `Option<NodeRef<Expr>>` — null in `config_if` */
    kcl_expr_node_t value;
    kcl_config_entry_operation_t operation;
    /* Rust marks this `skip_serializing_if = "is_false"`, so it is
     * *absent* rather than `false` on the wire. A missing key decodes
     * to `false` here. */
    bool is_shorthand;
} kcl_config_entry_t;

typedef struct kcl_comp_clause {
    kcl_identifier_node_list_t targets; /* Identifiers, not Targets */
    kcl_expr_node_t iter;
    kcl_expr_node_list_t ifs;
} kcl_comp_clause_t;

typedef struct kcl_schema_expr {
    kcl_identifier_node_t name;
    kcl_expr_node_list_t args;
    kcl_keyword_node_list_t kwargs;
    kcl_expr_node_t config;
} kcl_schema_expr_t;

typedef struct kcl_schema_index_signature {
    kcl_string_node_t* key_name; /* `Option<NodeRef<String>>` */
    kcl_expr_node_t* value;      /* `Option<NodeRef<Expr>>` */
    bool any_other;
    kcl_type_ref_node_t key_ty;  /* `NodeRef<Type>`, not optional upstream */
    kcl_type_ref_node_t value_ty;
} kcl_schema_index_signature_t;

typedef struct kcl_comment {
    char* text;
} kcl_comment_t;

/* ---------------------------------------------------------------- *
 * `Expr` (`#[serde(tag = "type")]`)
 * ---------------------------------------------------------------- */

typedef enum {
    KCL_EXPR_KIND_UNKNOWN = 0,
    KCL_EXPR_KIND_TARGET = 1,
    KCL_EXPR_KIND_IDENTIFIER = 2,
    KCL_EXPR_KIND_UNARY = 3,
    KCL_EXPR_KIND_BINARY = 4,
    KCL_EXPR_KIND_IF = 5,
    KCL_EXPR_KIND_SELECTOR = 6,
    KCL_EXPR_KIND_CALL = 7,
    KCL_EXPR_KIND_PAREN = 8,
    KCL_EXPR_KIND_QUANT = 9,
    KCL_EXPR_KIND_LIST = 10,
    KCL_EXPR_KIND_LIST_IF_ITEM = 11,
    KCL_EXPR_KIND_LIST_COMP = 12,
    KCL_EXPR_KIND_STARRED = 13,
    KCL_EXPR_KIND_DICT_COMP = 14,
    KCL_EXPR_KIND_CONFIG_IF_ENTRY = 15,
    KCL_EXPR_KIND_COMP_CLAUSE = 16,
    KCL_EXPR_KIND_SCHEMA = 17,
    KCL_EXPR_KIND_CONFIG = 18,
    KCL_EXPR_KIND_CHECK = 19,
    KCL_EXPR_KIND_LAMBDA = 20,
    KCL_EXPR_KIND_SUBSCRIPT = 21,
    KCL_EXPR_KIND_KEYWORD = 22,
    KCL_EXPR_KIND_ARGUMENTS = 23,
    KCL_EXPR_KIND_COMPARE = 24,
    KCL_EXPR_KIND_NUMBER_LIT = 25,
    KCL_EXPR_KIND_STRING_LIT = 26,
    KCL_EXPR_KIND_NAME_CONSTANT_LIT = 27,
    KCL_EXPR_KIND_JOINED_STRING = 28,
    KCL_EXPR_KIND_FORMATTED_VALUE = 29,
    KCL_EXPR_KIND_MISSING = 30,
} kcl_expr_kind_t;

typedef struct kcl_expr_data {
    kcl_expr_kind_t kind;
    char* type_tag;
    union {
        kcl_target_t target;
        kcl_identifier_t identifier;
        struct {
            kcl_unary_op_t op;
            kcl_expr_node_t operand;
        } unary_expr;
        struct {
            kcl_expr_node_t left;
            kcl_bin_op_t op;
            kcl_expr_node_t right;
        } binary_expr;
        struct {
            kcl_expr_node_t body;
            kcl_expr_node_t cond;
            kcl_expr_node_t orelse; /* not optional upstream */
        } if_expr;
        struct {
            kcl_expr_node_t value;
            kcl_identifier_node_t attr;
            kcl_expr_context_t ctx;
            bool has_question;
        } selector_expr;
        kcl_call_expr_t call_expr;
        struct {
            kcl_expr_node_t expr;
        } paren_expr;
        struct {
            kcl_expr_node_t target;
            kcl_identifier_node_list_t variables;
            kcl_quant_operation_t op;
            kcl_expr_node_t test;
            kcl_expr_node_t* if_cond;
            kcl_expr_context_t ctx;
        } quant_expr;
        struct {
            kcl_expr_node_list_t elts;
            kcl_expr_context_t ctx;
        } list_expr;
        struct {
            kcl_expr_node_t if_cond;
            kcl_expr_node_list_t exprs;
            kcl_expr_node_t* orelse;
        } list_if_item_expr;
        struct {
            kcl_expr_node_t elt;
            kcl_comp_clause_node_list_t generators;
        } list_comp;
        struct {
            kcl_expr_node_t value;
            kcl_expr_context_t ctx;
        } starred_expr;
        struct {
            /* `DictComp.entry` is a bare `ConfigEntry` — no `NodeRef`
             * wrapper, hence no position of its own. */
            kcl_config_entry_t entry;
            kcl_comp_clause_node_list_t generators;
        } dict_comp;
        struct {
            kcl_expr_node_t if_cond;
            kcl_config_entry_node_list_t items;
            kcl_expr_node_t* orelse;
        } config_if_entry_expr;
        kcl_comp_clause_t comp_clause;
        kcl_schema_expr_t schema_expr;
        struct {
            kcl_config_entry_node_list_t items;
        } config_expr;
        kcl_check_expr_t check_expr;
        struct {
            kcl_arguments_node_t* args; /* `Option<NodeRef<Arguments>>` */
            kcl_stmt_node_list_t body;
            kcl_type_ref_node_t* return_ty; /* `Option<NodeRef<Type>>` */
        } lambda_expr;
        struct {
            kcl_expr_node_t value;
            kcl_expr_node_t* index;
            kcl_expr_node_t* lower; /* slices carry bounds, not `index` */
            kcl_expr_node_t* upper;
            kcl_expr_node_t* step;
            kcl_expr_context_t ctx;
            bool has_question;
        } subscript_expr;
        kcl_keyword_t keyword;
        kcl_arguments_t arguments;
        struct {
            kcl_expr_node_t left;
            kcl_cmp_op_t* ops;
            size_t ops_count;
            kcl_expr_node_list_t comparators;
        } compare_expr;
        struct {
            kcl_number_binary_suffix_t binary_suffix;
            bool has_binary_suffix;
            kcl_number_lit_value_kind_t value_kind;
            int64_t int_value;
            double float_value;
        } number_lit;
        struct {
            bool is_long_string;
            char* raw_value;
            char* value;
        } string_lit;
        struct {
            kcl_name_constant_t value;
        } name_constant_lit;
        struct {
            bool is_long_string;
            kcl_expr_node_list_t values;
            char* raw_value;
        } joined_string;
        struct {
            bool is_long_string;
            kcl_expr_node_t value;
            char* format_spec; /* may be NULL */
        } formatted_value;
        struct {
            int placeholder; /* `MissingExpr` is a unit struct */
        } missing_expr;
    } u;
} kcl_expr_t;

/* ---------------------------------------------------------------- *
 * `Stmt` (`#[serde(tag = "type")]`)
 * ---------------------------------------------------------------- */

typedef enum {
    KCL_STMT_KIND_UNKNOWN = 0,
    KCL_STMT_KIND_TYPE_ALIAS = 1,
    KCL_STMT_KIND_EXPR = 2,
    KCL_STMT_KIND_UNIFICATION = 3,
    KCL_STMT_KIND_ASSIGN = 4,
    KCL_STMT_KIND_AUG_ASSIGN = 5,
    KCL_STMT_KIND_ASSERT = 6,
    KCL_STMT_KIND_IF = 7,
    KCL_STMT_KIND_IMPORT = 8,
    KCL_STMT_KIND_SCHEMA_ATTR = 9,
    KCL_STMT_KIND_SCHEMA = 10,
    KCL_STMT_KIND_RULE = 11,
} kcl_stmt_kind_t;

typedef struct kcl_type_alias_stmt {
    kcl_identifier_node_t type_name;
    kcl_string_node_t type_value;
    kcl_type_ref_node_t ty;
} kcl_type_alias_stmt_t;

typedef struct kcl_expr_stmt {
    kcl_expr_node_list_t exprs;
} kcl_expr_stmt_t;

typedef struct kcl_unification_stmt {
    kcl_identifier_node_t target;
    kcl_schema_expr_node_t value;
} kcl_unification_stmt_t;

typedef struct kcl_assign_stmt {
    kcl_target_node_list_t targets;
    kcl_expr_node_t value;
    kcl_type_ref_node_t* ty; /* `Option<NodeRef<Type>>` */
} kcl_assign_stmt_t;

typedef struct kcl_aug_assign_stmt {
    kcl_target_node_t target;
    kcl_expr_node_t value;
    kcl_aug_op_t op;
} kcl_aug_assign_stmt_t;

typedef struct kcl_assert_stmt {
    kcl_expr_node_t test;
    kcl_expr_node_t* if_cond;
    kcl_expr_node_t* msg;
} kcl_assert_stmt_t;

typedef struct kcl_if_stmt {
    kcl_expr_node_t cond;
    kcl_stmt_node_list_t body;
    kcl_stmt_node_list_t orelse; /* a statement list, not an expr */
} kcl_if_stmt_t;

typedef struct kcl_import_stmt {
    kcl_string_node_t path;
    char* rawpath;
    char* name;
    kcl_string_node_t* asname; /* `Option<Node<String>>` */
    char* pkg_name;
} kcl_import_stmt_t;

typedef struct kcl_schema_attr {
    char* doc; /* a plain `String`, not a `NodeRef<String>` */
    kcl_string_node_t name;
    kcl_aug_op_t op;
    bool has_op;
    kcl_expr_node_t* value;
    bool is_optional;
    kcl_call_expr_node_list_t decorators; /* bare `CallExpr`s */
    kcl_type_ref_node_t ty;               /* not optional upstream */
} kcl_schema_attr_t;

typedef struct kcl_schema_stmt {
    kcl_string_node_t* doc; /* may be NULL */
    kcl_string_node_t name;
    kcl_identifier_node_t* parent_name;
    kcl_identifier_node_t* for_host_name;
    bool is_mixin;
    bool is_protocol;
    kcl_arguments_node_t* args;
    kcl_identifier_node_list_t mixins;
    kcl_stmt_node_list_t body;
    kcl_call_expr_node_list_t decorators;
    kcl_check_expr_node_list_t checks;
    kcl_schema_index_signature_node_t* index_signature;
} kcl_schema_stmt_t;

typedef struct kcl_rule_stmt {
    kcl_string_node_t* doc;
    kcl_string_node_t name;
    kcl_identifier_node_list_t parent_rules;
    kcl_call_expr_node_list_t decorators;
    kcl_check_expr_node_list_t checks;
    kcl_arguments_node_t* args;
    kcl_identifier_node_t* for_host_name;
} kcl_rule_stmt_t;

typedef struct kcl_stmt_data {
    kcl_stmt_kind_t kind;
    char* type_tag;
    union {
        kcl_type_alias_stmt_t type_alias_stmt;
        kcl_expr_stmt_t expr_stmt;
        kcl_unification_stmt_t unification_stmt;
        kcl_assign_stmt_t assign_stmt;
        kcl_aug_assign_stmt_t aug_assign_stmt;
        kcl_assert_stmt_t assert_stmt;
        kcl_if_stmt_t if_stmt;
        kcl_import_stmt_t import_stmt;
        kcl_schema_attr_t schema_attr;
        kcl_schema_stmt_t schema_stmt;
        kcl_rule_stmt_t rule_stmt;
    } u;
} kcl_stmt_t;

/* ---------------------------------------------------------------- *
 * Module & Program
 * ---------------------------------------------------------------- */

typedef struct kcl_module {
    char* filename;
    kcl_string_node_t* doc; /* may be NULL */
    kcl_stmt_node_list_t body;
    kcl_comment_node_list_t comments;
    /* Internal arena owning every allocation reachable from this
     * module. Opaque; do not touch. */
    void* _internals;
} kcl_module_t;

typedef struct kcl_program {
    char* root;
    /* The Rust `Program` maps package name → modules. Only the
     * `__main__` package is surfaced here; `pkgs`, `pkgs_not_imported`,
     * `modules` and `modules_not_imported` are not modelled. */
    kcl_module_t** main_package;
    size_t main_package_count;
    /* Internal arena owning every allocation reachable from this
     * program. Opaque; do not touch. */
    void* _internals;
} kcl_program_t;

/* ---------------------------------------------------------------- *
 * Public API
 * ---------------------------------------------------------------- */

/**
 * Parse the `ast_json` string emitted by `kcl_parse_file` into a typed
 * `kcl_module_t`. Release with `kcl_module_free`. Returns NULL on
 * parse failure.
 */
kcl_module_t* kcl_ast_parse_module(const char* ast_json);

/**
 * Parse the `ast_json` string emitted by `kcl_parse_program` into a
 * typed `kcl_program_t`. Release with `kcl_program_free`. Returns NULL
 * on parse failure.
 */
kcl_program_t* kcl_ast_parse_program(const char* ast_json);

/** Free a module returned by `kcl_ast_parse_module`. */
void kcl_module_free(kcl_module_t* module);

/** Free a program returned by `kcl_ast_parse_program`. */
void kcl_program_free(kcl_program_t* program);

/* The JSON parser is exposed so the AST layer — and the contract
 * tests that link against it — can walk the document. */
const kcl_json_value_t* kcl_json_object_get(const kcl_json_value_t* obj, const char* key);
size_t kcl_json_array_length(const kcl_json_value_t* arr);
const kcl_json_value_t* kcl_json_array_get(const kcl_json_value_t* arr, size_t i);
kcl_json_value_t* kcl_json_parse(const char* text);
void kcl_json_free(kcl_json_value_t* v);

/** The Rust variant name for a scalar enum value, for diagnostics. */
const char* kcl_unary_op_name(kcl_unary_op_t op);
const char* kcl_bin_op_name(kcl_bin_op_t op);
const char* kcl_cmp_op_name(kcl_cmp_op_t op);
const char* kcl_aug_op_name(kcl_aug_op_t op);
const char* kcl_expr_context_name(kcl_expr_context_t ctx);
const char* kcl_number_binary_suffix_name(kcl_number_binary_suffix_t suffix);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* KCL_LIB_AST_H */

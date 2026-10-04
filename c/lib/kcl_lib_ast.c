/*
 * kcl_lib_ast.c — Implementation of the typed AST module for the C binding.
 *
 * Companion to `kcl_lib_ast.h`. Two layers:
 *
 *   1. A minimal recursive-descent JSON parser (top of the file),
 *      exposed through the `kcl_json_*` helpers. Self-contained, so the
 *      binding needs no vendored dependency.
 *
 *   2. The AST deserializer, which walks that document against the
 *      contract in `kcl_lib_ast.h`: internally tagged `Stmt` / `Expr`,
 *      adjacently tagged `Type`, untagged DTOs, and a flat `Node<T>`
 *      wrapper. Every allocation comes from a per-root arena, so
 *      teardown is `kcl_module_free` / `kcl_program_free` and nothing
 *      more.
 *
 * The contract itself is pinned by `c/examples/ast_alignment.c` and
 * `c/examples/ast_contract.c`, the first against a live
 * `kcl_parse_file` and the second against the checked-in golden capture
 * at `testdata/ast/alignment.json`.
 */

#include "kcl_lib_ast.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---------------------------------------------------------------- *
 * JSON parser — exposed via the kcl_json_* helpers in the header.
 * ---------------------------------------------------------------- */

typedef struct {
    const char* p;
    char* error;
} json_parser_t;

static void json_skip_ws(json_parser_t* jp)
{
    while (*jp->p && isspace((unsigned char)*jp->p))
        jp->p++;
}

static int json_peek(json_parser_t* jp, char c)
{
    json_skip_ws(jp);
    return *jp->p == c;
}

static int json_consume(json_parser_t* jp, char c)
{
    json_skip_ws(jp);
    if (*jp->p != c) {
        if (jp->error == NULL) {
            char buf[64];
            snprintf(buf, sizeof(buf), "expected '%c', got '%c' at offset %zu",
                c, *jp->p, (size_t)(jp->p - (jp->p - 1) /* unused */));
            jp->error = strdup(buf);
        }
        return 0;
    }
    jp->p++;
    return 1;
}

static kcl_json_value_t* json_value(json_parser_t* jp);

static char* json_parse_string_raw(json_parser_t* jp)
{
    if (!json_consume(jp, '"'))
        return NULL;
    /* Worst case every input char needs escaping; allocate generously. */
    size_t cap = 16;
    size_t len = 0;
    char* buf = (char*)malloc(cap);
    while (*jp->p && *jp->p != '"') {
        char c = *jp->p++;
        if (c == '\\') {
            char e = *jp->p++;
            switch (e) {
            case '"': c = '"'; break;
            case '\\': c = '\\'; break;
            case '/': c = '/'; break;
            case 'b': c = '\b'; break;
            case 'f': c = '\f'; break;
            case 'n': c = '\n'; break;
            case 'r': c = '\r'; break;
            case 't': c = '\t'; break;
            case 'u': {
                /* Decode \uXXXX into UTF-8 (BMP only — sufficient for
                 * KCL identifiers / strings). */
                char hex[5] = { 0 };
                for (int i = 0; i < 4; i++)
                    hex[i] = *jp->p++;
                unsigned int cp = (unsigned)strtoul(hex, NULL, 16);
                if (cp < 0x80) {
                    if (len + 1 >= cap) {
                        cap *= 2;
                        buf = (char*)realloc(buf, cap);
                    }
                    buf[len++] = (char)cp;
                } else if (cp < 0x800) {
                    if (len + 2 >= cap) {
                        cap *= 2;
                        buf = (char*)realloc(buf, cap);
                    }
                    buf[len++] = (char)(0xC0 | (cp >> 6));
                    buf[len++] = (char)(0x80 | (cp & 0x3F));
                } else {
                    if (len + 3 >= cap) {
                        cap *= 2;
                        buf = (char*)realloc(buf, cap);
                    }
                    buf[len++] = (char)(0xE0 | (cp >> 12));
                    buf[len++] = (char)(0x80 | ((cp >> 6) & 0x3F));
                    buf[len++] = (char)(0x80 | (cp & 0x3F));
                }
                continue;
            }
            default:
                c = e;
                break;
            }
        }
        if (len + 1 >= cap) {
            cap *= 2;
            buf = (char*)realloc(buf, cap);
        }
        buf[len++] = c;
    }
    if (!json_consume(jp, '"')) {
        free(buf);
        return NULL;
    }
    buf[len] = '\0';
    return buf;
}

static kcl_json_value_t* json_parse_object(json_parser_t* jp);
static kcl_json_value_t* json_parse_array(json_parser_t* jp);

static kcl_json_value_t* json_value(json_parser_t* jp)
{
    json_skip_ws(jp);
    char c = *jp->p;
    if (c == '{')
        return json_parse_object(jp); /* forward — defined below */
    if (c == '[')
        return json_parse_array(jp);
    if (c == '"') {
        kcl_json_value_t* v = (kcl_json_value_t*)calloc(1, sizeof(*v));
        v->type = KCL_JSON_STRING;
        v->u.string.data = json_parse_string_raw(jp);
        v->u.string.length = v->u.string.data ? strlen(v->u.string.data) : 0;
        return v;
    }
    if (c == 't' || c == 'f') {
        kcl_json_value_t* v = (kcl_json_value_t*)calloc(1, sizeof(*v));
        v->type = KCL_JSON_BOOL;
        if (strncmp(jp->p, "true", 4) == 0) {
            v->u.boolean = true;
            jp->p += 4;
        } else if (strncmp(jp->p, "false", 5) == 0) {
            v->u.boolean = false;
            jp->p += 5;
        } else {
            free(v);
            return NULL;
        }
        return v;
    }
    if (c == 'n') {
        kcl_json_value_t* v = (kcl_json_value_t*)calloc(1, sizeof(*v));
        v->type = KCL_JSON_NULL;
        if (strncmp(jp->p, "null", 4) == 0)
            jp->p += 4;
        return v;
    }
    /* Number */
    {
        kcl_json_value_t* v = (kcl_json_value_t*)calloc(1, sizeof(*v));
        v->type = KCL_JSON_NUMBER;
        char* end = NULL;
        v->u.number = strtod(jp->p, &end);
        if (end == jp->p) {
            free(v);
            return NULL;
        }
        jp->p = end;
        return v;
    }
}

void kcl_json_free(kcl_json_value_t* v)
{
    if (v == NULL)
        return;
    switch (v->type) {
    case KCL_JSON_STRING:
        free(v->u.string.data);
        break;
    case KCL_JSON_ARRAY:
        for (size_t i = 0; i < v->u.array.count; i++)
            kcl_json_free(v->u.array.items[i]);
        free(v->u.array.items);
        break;
    case KCL_JSON_OBJECT:
        for (size_t i = 0; i < v->u.object.count; i++) {
            free(v->u.object.keys[i]);
            kcl_json_free(v->u.object.values[i]);
        }
        free(v->u.object.keys);
        free(v->u.object.values);
        break;
    default:
        break;
    }
    free(v);
}

kcl_json_value_t* kcl_json_parse(const char* text)
{
    json_parser_t jp = { text, NULL };
    kcl_json_value_t* v = json_value(&jp);
    if (v == NULL)
        return NULL;
    json_skip_ws(&jp);
    if (*jp.p != '\0') {
        kcl_json_free(v);
        return NULL;
    }
    return v;
}

const kcl_json_value_t* kcl_json_object_get(const kcl_json_value_t* obj, const char* key)
{
    if (obj == NULL || obj->type != KCL_JSON_OBJECT)
        return NULL;
    for (size_t i = 0; i < obj->u.object.count; i++) {
        if (strcmp(obj->u.object.keys[i], key) == 0)
            return obj->u.object.values[i];
    }
    return NULL;
}

size_t kcl_json_array_length(const kcl_json_value_t* arr)
{
    if (arr == NULL || arr->type != KCL_JSON_ARRAY)
        return 0;
    return arr->u.array.count;
}

const kcl_json_value_t* kcl_json_array_get(const kcl_json_value_t* arr, size_t i)
{
    if (arr == NULL || arr->type != KCL_JSON_ARRAY || i >= arr->u.array.count)
        return NULL;
    return arr->u.array.items[i];
}

/* Internal forward decls so json_value can recurse into objects/arrays. */
static kcl_json_value_t* json_value(json_parser_t* jp);

static kcl_json_value_t* json_parse_object(json_parser_t* jp)
{
    if (!json_consume(jp, '{'))
        return NULL;
    kcl_json_value_t* v = (kcl_json_value_t*)calloc(1, sizeof(*v));
    v->type = KCL_JSON_OBJECT;
    size_t cap = 4;
    v->u.object.keys = (char**)malloc(cap * sizeof(char*));
    v->u.object.values = (kcl_json_value_t**)malloc(cap * sizeof(kcl_json_value_t*));
    v->u.object.count = 0;
    if (json_peek(jp, '}')) {
        jp->p++;
        return v;
    }
    while (1) {
        if (v->u.object.count == cap) {
            cap *= 2;
            v->u.object.keys = (char**)realloc(v->u.object.keys, cap * sizeof(char*));
            v->u.object.values = (kcl_json_value_t**)realloc(v->u.object.values, cap * sizeof(kcl_json_value_t*));
        }
        char* k = json_parse_string_raw(jp);
        if (k == NULL)
            goto fail;
        if (!json_consume(jp, ':'))
            goto fail;
        kcl_json_value_t* val = json_value(jp);
        if (val == NULL)
            goto fail;
        v->u.object.keys[v->u.object.count] = k;
        v->u.object.values[v->u.object.count] = val;
        v->u.object.count++;
        if (json_peek(jp, ',')) {
            jp->p++;
            continue;
        }
        if (json_peek(jp, '}')) {
            jp->p++;
            return v;
        }
        goto fail;
    }
fail:
    kcl_json_free(v);
    return NULL;
}

static kcl_json_value_t* json_parse_array(json_parser_t* jp)
{
    if (!json_consume(jp, '['))
        return NULL;
    kcl_json_value_t* v = (kcl_json_value_t*)calloc(1, sizeof(*v));
    v->type = KCL_JSON_ARRAY;
    size_t cap = 4;
    v->u.array.items = (kcl_json_value_t**)malloc(cap * sizeof(kcl_json_value_t*));
    v->u.array.count = 0;
    if (json_peek(jp, ']')) {
        jp->p++;
        return v;
    }
    while (1) {
        if (v->u.array.count == cap) {
            cap *= 2;
            v->u.array.items = (kcl_json_value_t**)realloc(v->u.array.items, cap * sizeof(kcl_json_value_t*));
        }
        kcl_json_value_t* item = json_value(jp);
        if (item == NULL)
            goto fail;
        v->u.array.items[v->u.array.count++] = item;
        if (json_peek(jp, ',')) {
            jp->p++;
            continue;
        }
        if (json_peek(jp, ']')) {
            jp->p++;
            return v;
        }
        goto fail;
    }
fail:
    kcl_json_free(v);
    return NULL;
}

/* ---------------------------------------------------------------- *
 * AST arena
 *
 * The AST is a deeply cross-referential graph: an `Expr` owns `Stmt`s
 * which own `Expr`s, and nearly every node owns a list of nodes that
 * own nodes. Freeing it field-by-field needs a function per struct plus
 * a `switch` per free function, and any missed case is a leak or a
 * double free.
 *
 * Instead every allocation the AST layer makes is bump-allocated from
 * an arena hung off the root `kcl_module_t` / `kcl_program_t`, so
 * teardown is a single walk over the block list. The cost is that
 * freeing is all-or-nothing — which matches the public API, which hands
 * back a whole module and takes it back whole.
 * ---------------------------------------------------------------- */

#define KCL_ARENA_BLOCK_MIN (64u * 1024u)

typedef struct kcl_arena_block {
    struct kcl_arena_block* next;
    size_t used;
    size_t cap;
    /* Payload follows. */
} kcl_arena_block_t;

typedef struct {
    kcl_arena_block_t* head;
} kcl_arena_t;

static void* arena_alloc(kcl_arena_t* a, size_t size)
{
    size = (size + 15u) & ~(size_t)15u; /* keep every slot 16-byte aligned */
    kcl_arena_block_t* b = a->head;
    if (b == NULL || b->cap - b->used < size) {
        size_t cap = KCL_ARENA_BLOCK_MIN;
        while (cap < size)
            cap *= 2;
        b = (kcl_arena_block_t*)malloc(sizeof(kcl_arena_block_t) + cap);
        if (b == NULL)
            return NULL;
        b->next = a->head;
        b->used = 0;
        b->cap = cap;
        a->head = b;
    }
    char* p = (char*)(b + 1) + b->used;
    b->used += size;
    return p;
}

static char* arena_strdup(kcl_arena_t* a, const char* s)
{
    if (s == NULL)
        return NULL;
    size_t n = strlen(s) + 1;
    char* out = (char*)arena_alloc(a, n);
    if (out != NULL)
        memcpy(out, s, n);
    return out;
}

/* Every AST allocation is zeroed, so "absent" and "present but empty"
 * are the same representation — which is exactly what the wire's
 * absent-vs-null distinction collapses to once decoded. */
static void* arena_zalloc(kcl_arena_t* a, size_t size)
{
    void* p = arena_alloc(a, size);
    if (p != NULL)
        memset(p, 0, size);
    return p;
}

static void arena_free(kcl_arena_t* a)
{
    if (a == NULL)
        return;
    kcl_arena_block_t* b = a->head;
    while (b != NULL) {
        kcl_arena_block_t* next = b->next;
        free(b);
        b = next;
    }
    a->head = NULL;
}

/* ---------------------------------------------------------------- *
 * JSON accessors
 * ---------------------------------------------------------------- */

static bool json_is_object(const kcl_json_value_t* v)
{
    return v != NULL && v->type == KCL_JSON_OBJECT;
}

static bool json_is_array(const kcl_json_value_t* v)
{
    return v != NULL && v->type == KCL_JSON_ARRAY;
}

static bool json_is_null(const kcl_json_value_t* v)
{
    return v == NULL || v->type == KCL_JSON_NULL;
}

/* A string, or NULL. A missing key and a non-string both read as "no
 * value" — the wire never distinguishes them for a `String` field. */
static const char* json_str(const kcl_json_value_t* v)
{
    if (v == NULL || v->type != KCL_JSON_STRING)
        return NULL;
    return v->u.string.data;
}

static char* read_str(kcl_arena_t* a, const kcl_json_value_t* v)
{
    return arena_strdup(a, json_str(v));
}

static char* read_key_str(kcl_arena_t* a, const kcl_json_value_t* v, const char* key)
{
    return read_str(a, kcl_json_object_get(v, key));
}

/* serde emits `u64` for the position fields; a double round-trips them
 * exactly well past any source file size. */
static int64_t read_i64(const kcl_json_value_t* v, int64_t fallback)
{
    if (v == NULL || v->type != KCL_JSON_NUMBER)
        return fallback;
    return (int64_t)v->u.number;
}

static int64_t read_key_i64(const kcl_json_value_t* v, const char* key, int64_t fallback)
{
    return read_i64(kcl_json_object_get(v, key), fallback);
}

static double read_f64(const kcl_json_value_t* v, double fallback)
{
    if (v == NULL || v->type != KCL_JSON_NUMBER)
        return fallback;
    return v->u.number;
}

static bool read_bool(const kcl_json_value_t* v, bool fallback)
{
    if (v != NULL && v->type == KCL_JSON_BOOL)
        return v->u.boolean;
    return fallback;
}

static bool read_key_bool(const kcl_json_value_t* v, const char* key, bool fallback)
{
    return read_bool(kcl_json_object_get(v, key), fallback);
}

/* ---------------------------------------------------------------- *
 * Scalar enum decoding
 *
 * Each returns false when the wire value is absent or unrecognised, so
 * the caller decides between "keep the zero value" and "record that the
 * variant was unrecognised". Nothing silently falls back to a
 * plausible-looking value: a wrong answer here corrupts a whole
 * subtree.
 *
 * The tables are the Rust variant names in declaration order, and the C
 * enums are numbered to match, so the index *is* the value.
 * ---------------------------------------------------------------- */

#define KCL_DEFINE_ENUM_DECODER(fn_name, c_type, ...)                        \
    static bool fn_name(const char* s, c_type* out)                           \
    {                                                                         \
        static const char* names[] = { __VA_ARGS__ };                         \
        if (s == NULL)                                                        \
            return false;                                                     \
        for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++) {        \
            if (strcmp(s, names[i]) == 0) {                                   \
                *out = (c_type)i;                                             \
                return true;                                                  \
            }                                                                 \
        }                                                                     \
        return false;                                                         \
    }

KCL_DEFINE_ENUM_DECODER(decode_unary_op, kcl_unary_op_t, "UAdd", "USub", "Invert", "Not")

KCL_DEFINE_ENUM_DECODER(decode_bin_op, kcl_bin_op_t,
    "Add", "Sub", "Mul", "Div", "Mod", "Pow", "FloorDiv", "LShift", "RShift",
    "BitXor", "BitAnd", "BitOr", "And", "Or", "As")

KCL_DEFINE_ENUM_DECODER(decode_cmp_op, kcl_cmp_op_t,
    "Eq", "NotEq", "Lt", "LtE", "Gt", "GtE", "Is", "In", "NotIn", "Not", "IsNot")

/* `Assign` is the plain `=` case. */
KCL_DEFINE_ENUM_DECODER(decode_aug_op, kcl_aug_op_t,
    "Assign", "Add", "Sub", "Mul", "Div", "Mod", "Pow", "FloorDiv", "LShift",
    "RShift", "BitXor", "BitAnd", "BitOr")

KCL_DEFINE_ENUM_DECODER(decode_quant_op, kcl_quant_operation_t, "All", "Any", "Filter", "Map")

KCL_DEFINE_ENUM_DECODER(decode_config_entry_op, kcl_config_entry_operation_t,
    "Union", "Override", "Insert")

KCL_DEFINE_ENUM_DECODER(decode_basic_type, kcl_basic_type_t, "Bool", "Int", "Float", "Str")

KCL_DEFINE_ENUM_DECODER(decode_name_constant, kcl_name_constant_t,
    "True", "False", "None", "Undefined")

KCL_DEFINE_ENUM_DECODER(decode_number_binary_suffix, kcl_number_binary_suffix_t,
    "n", "u", "m", "k", "K", "M", "G", "T", "P", "Ki", "Mi", "Gi", "Ti", "Pi")

KCL_DEFINE_ENUM_DECODER(decode_expr_context, kcl_expr_context_t, "Load", "Store")

KCL_DEFINE_ENUM_DECODER(decode_literal_type_kind, kcl_literal_type_kind_t,
    "Bool", "Int", "Float", "Str")

/* `NumberLitValue` uses the same tag+content shape. serde writes an
 * `f64` as a plain JSON number, so the variant tag is the only thing
 * that tells an int payload from a float one. */
static bool decode_number_lit_value_kind(const char* s, kcl_number_lit_value_kind_t* out)
{
    if (s == NULL)
        return false;
    if (strcmp(s, "Int") == 0) {
        *out = KCL_NUMBER_LIT_VALUE_INT;
        return true;
    }
    if (strcmp(s, "Float") == 0) {
        *out = KCL_NUMBER_LIT_VALUE_FLOAT;
        return true;
    }
    return false;
}

const char* kcl_unary_op_name(kcl_unary_op_t op)
{
    static const char* names[] = { "UAdd", "USub", "Invert", "Not" };
    return (size_t)op < 4 ? names[op] : "?";
}

const char* kcl_bin_op_name(kcl_bin_op_t op)
{
    static const char* names[] = { "Add", "Sub", "Mul", "Div", "Mod", "Pow",
        "FloorDiv", "LShift", "RShift", "BitXor", "BitAnd", "BitOr", "And", "Or", "As" };
    return (size_t)op < 15 ? names[op] : "?";
}

const char* kcl_cmp_op_name(kcl_cmp_op_t op)
{
    static const char* names[] = { "Eq", "NotEq", "Lt", "LtE", "Gt", "GtE",
        "Is", "In", "NotIn", "Not", "IsNot" };
    return (size_t)op < 11 ? names[op] : "?";
}

const char* kcl_aug_op_name(kcl_aug_op_t op)
{
    static const char* names[] = { "Assign", "Add", "Sub", "Mul", "Div", "Mod",
        "Pow", "FloorDiv", "LShift", "RShift", "BitXor", "BitAnd", "BitOr" };
    return (size_t)op < 13 ? names[op] : "?";
}

const char* kcl_expr_context_name(kcl_expr_context_t ctx)
{
    return ctx == KCL_EXPR_CONTEXT_STORE ? "Store" : "Load";
}

const char* kcl_number_binary_suffix_name(kcl_number_binary_suffix_t s)
{
    static const char* names[] = { "n", "u", "m", "k", "K", "M", "G", "T", "P",
        "Ki", "Mi", "Gi", "Ti", "Pi" };
    return (size_t)s < 14 ? names[s] : "?";
}

/* ---------------------------------------------------------------- *
 * `Node<T>` — the wrapper is flat
 * ---------------------------------------------------------------- */

static kcl_pos_t* parse_pos(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_pos_t* p = (kcl_pos_t*)arena_zalloc(a, sizeof(*p));
    if (p == NULL)
        return NULL;
    p->filename = read_key_str(a, v, "filename");
    p->line = read_key_i64(v, "line", 0);
    p->column = read_key_i64(v, "column", 0);
    p->end_line = read_key_i64(v, "end_line", 0);
    p->end_column = read_key_i64(v, "end_column", 0);
    return p;
}

/* `Node<String>` — the payload is a bare string, so this struct is both
 * the wrapper and its own payload type. */
static kcl_string_node_t* parse_string_node(kcl_arena_t* a, const kcl_json_value_t* v)
{
    if (!json_is_object(v))
        return NULL;
    kcl_string_node_t* n = (kcl_string_node_t*)arena_zalloc(a, sizeof(*n));
    if (n == NULL)
        return NULL;
    n->node = read_str(a, kcl_json_object_get(v, "node"));
    n->pos = parse_pos(a, v);
    n->id = read_key_str(a, v, "id");
    return n;
}

static void copy_string_node(kcl_string_node_t* dst, kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_string_node_t* n = parse_string_node(a, v);
    if (n != NULL)
        *dst = *n;
}

/* ---------------------------------------------------------------- *
 * Forward declarations for the recursive walk
 * ---------------------------------------------------------------- */

static kcl_identifier_t* parse_identifier(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_target_t* parse_target(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_arguments_t* parse_arguments(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_call_expr_t* parse_call_expr(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_check_expr_t* parse_check_expr(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_comp_clause_t* parse_comp_clause(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_config_entry_t* parse_config_entry(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_keyword_t* parse_keyword(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_schema_expr_t* parse_schema_expr(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_schema_index_signature_t* parse_schema_index_signature(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_type_node_t* parse_type_node(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_stmt_t* parse_stmt(kcl_arena_t* a, const kcl_json_value_t* v);
static kcl_expr_t* parse_expr(kcl_arena_t* a, const kcl_json_value_t* v);

/*
 * One loader per `NodeRef<T>` payload kind, plus its `Option` form.
 * The loader is handed the *unwrapped* `node` payload, so a
 * polymorphic payload reaches `parse_stmt` / `parse_expr` /
 * `parse_type_node` with its `"type"` tag at the top level.
 */
#define KCL_DEFINE_NODE_LOADER(name, parse_fn)                               \
    static kcl_##name##_node_t* parse_##name##_node(                         \
        kcl_arena_t* a, const kcl_json_value_t* v)                           \
    {                                                                         \
        if (!json_is_object(v))                                               \
            return NULL;                                                      \
        kcl_##name##_node_t* n =                                              \
            (kcl_##name##_node_t*)arena_zalloc(a, sizeof(*n));                \
        if (n == NULL)                                                        \
            return NULL;                                                      \
        const kcl_json_value_t* payload = kcl_json_object_get(v, "node");     \
        if (json_is_object(payload))                                          \
            n->node = parse_fn(a, payload);                                   \
        n->pos = parse_pos(a, v);                                             \
        n->id = read_key_str(a, v, "id");                                     \
        return n;                                                             \
    }

/* Only the payloads that actually have an `Option<NodeRef<T>>` field get
 * the `_opt` form; for the rest the plain loader already returns NULL for
 * a null, which is the same answer. */
#define KCL_DEFINE_NODE_OPT_LOADER(name)                                      \
    static kcl_##name##_node_t* parse_##name##_node_opt(                     \
        kcl_arena_t* a, const kcl_json_value_t* v)                           \
    {                                                                         \
        if (json_is_null(v))                                                  \
            return NULL;                                                      \
        return parse_##name##_node(a, v);                                    \
    }

KCL_DEFINE_NODE_LOADER(stmt, parse_stmt)
KCL_DEFINE_NODE_LOADER(expr, parse_expr)
KCL_DEFINE_NODE_LOADER(type_ref, parse_type_node)
KCL_DEFINE_NODE_LOADER(target, parse_target)
KCL_DEFINE_NODE_LOADER(identifier, parse_identifier)
KCL_DEFINE_NODE_LOADER(arguments, parse_arguments)
KCL_DEFINE_NODE_LOADER(check_expr, parse_check_expr)
KCL_DEFINE_NODE_LOADER(call_expr, parse_call_expr)
KCL_DEFINE_NODE_LOADER(comp_clause, parse_comp_clause)
KCL_DEFINE_NODE_LOADER(config_entry, parse_config_entry)
KCL_DEFINE_NODE_LOADER(keyword, parse_keyword)
KCL_DEFINE_NODE_LOADER(schema_expr, parse_schema_expr)
KCL_DEFINE_NODE_LOADER(schema_index_signature, parse_schema_index_signature)

KCL_DEFINE_NODE_OPT_LOADER(expr)
KCL_DEFINE_NODE_OPT_LOADER(type_ref)
KCL_DEFINE_NODE_OPT_LOADER(identifier)
KCL_DEFINE_NODE_OPT_LOADER(arguments)
KCL_DEFINE_NODE_OPT_LOADER(schema_index_signature)

/* `Comment` needs the `NodeRef` wrapper but no recursive payload. */
static kcl_comment_node_t* parse_comment_node(kcl_arena_t* a, const kcl_json_value_t* v)
{
    if (!json_is_object(v))
        return NULL;
    kcl_comment_node_t* n = (kcl_comment_node_t*)arena_zalloc(a, sizeof(*n));
    if (n == NULL)
        return NULL;
    kcl_comment_t* c = (kcl_comment_t*)arena_zalloc(a, sizeof(*c));
    if (c != NULL) {
        c->text = read_key_str(a, kcl_json_object_get(v, "node"), "text");
        n->node = c;
    }
    n->pos = parse_pos(a, v);
    n->id = read_key_str(a, v, "id");
    return n;
}

/* `Vec<NodeRef<T>>` */
#define KCL_DEFINE_NODE_LIST_LOADER(name)                                     \
    static void parse_##name##_node_list(                                     \
        kcl_arena_t* a, const kcl_json_value_t* v,                            \
        kcl_##name##_node_list_t* out)                                        \
    {                                                                         \
        memset(out, 0, sizeof(*out));                                         \
        if (!json_is_array(v))                                                \
            return;                                                           \
        size_t n = kcl_json_array_length(v);                                  \
        if (n == 0)                                                           \
            return;                                                           \
        kcl_##name##_node_t* items =                                          \
            (kcl_##name##_node_t*)arena_zalloc(a, n * sizeof(*items));        \
        if (items == NULL)                                                    \
            return;                                                           \
        out->items = items;                                                   \
        out->count = n;                                                       \
        for (size_t i = 0; i < n; i++) {                                      \
            kcl_##name##_node_t* slot =                                       \
                parse_##name##_node(a, kcl_json_array_get(v, i));             \
            if (slot != NULL)                                                 \
                items[i] = *slot;                                             \
        }                                                                     \
    }

KCL_DEFINE_NODE_LIST_LOADER(stmt)
KCL_DEFINE_NODE_LIST_LOADER(expr)
KCL_DEFINE_NODE_LIST_LOADER(type_ref)
KCL_DEFINE_NODE_LIST_LOADER(target)
KCL_DEFINE_NODE_LIST_LOADER(identifier)
KCL_DEFINE_NODE_LIST_LOADER(check_expr)
KCL_DEFINE_NODE_LIST_LOADER(call_expr)
KCL_DEFINE_NODE_LIST_LOADER(comp_clause)
KCL_DEFINE_NODE_LIST_LOADER(config_entry)
KCL_DEFINE_NODE_LIST_LOADER(keyword)

/*
 * `Vec<Node<String>>` — each element still carries its own position, so
 * this cannot go through the generic list loader, whose payload loader
 * expects a dict.
 */
static void parse_string_node_list(kcl_arena_t* a, const kcl_json_value_t* v,
    kcl_string_node_list_t* out)
{
    memset(out, 0, sizeof(*out));
    if (!json_is_array(v))
        return;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return;
    kcl_string_node_t* items = (kcl_string_node_t*)arena_zalloc(a, n * sizeof(*items));
    if (items == NULL)
        return;
    out->items = items;
    out->count = n;
    for (size_t i = 0; i < n; i++) {
        kcl_string_node_t* s = parse_string_node(a, kcl_json_array_get(v, i));
        if (s != NULL)
            items[i] = *s;
    }
}

static void parse_comment_node_list(kcl_arena_t* a, const kcl_json_value_t* v,
    kcl_comment_node_list_t* out)
{
    memset(out, 0, sizeof(*out));
    if (!json_is_array(v))
        return;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return;
    kcl_comment_node_t* items = (kcl_comment_node_t*)arena_zalloc(a, n * sizeof(*items));
    if (items == NULL)
        return;
    out->items = items;
    out->count = n;
    for (size_t i = 0; i < n; i++) {
        kcl_comment_node_t* c = parse_comment_node(a, kcl_json_array_get(v, i));
        if (c != NULL)
            items[i] = *c;
    }
}

/*
 * `Vec<Option<NodeRef<T>>>` — only `Arguments.defaults` and
 * `Arguments.ty_list` use this. Both are index-aligned with
 * `Arguments.args`, so a JSON null becomes `{present: false}` rather
 * than a short list: collapsing it would shift every later annotation
 * onto the wrong parameter.
 */
#define KCL_DEFINE_OPT_NODE_LIST_LOADER(name, wrapper, node_loader)           \
    static void parse_opt_##name##_node_list(kcl_arena_t* a,                  \
        const kcl_json_value_t* v, kcl_opt_##name##_node_list_t* out)         \
    {                                                                         \
        memset(out, 0, sizeof(*out));                                         \
        if (!json_is_array(v))                                                \
            return;                                                           \
        size_t n = kcl_json_array_length(v);                                  \
        if (n == 0)                                                           \
            return;                                                           \
        kcl_opt_##name##_node_t* items =                                      \
            (kcl_opt_##name##_node_t*)arena_zalloc(a, n * sizeof(*items));    \
        if (items == NULL)                                                    \
            return;                                                           \
        out->items = items;                                                   \
        out->count = n;                                                       \
        for (size_t i = 0; i < n; i++) {                                      \
            const kcl_json_value_t* item = kcl_json_array_get(v, i);          \
            if (json_is_null(item))                                           \
                continue; /* `present` stays false — the slot is kept */      \
            wrapper##_t* slot = node_loader(a, item);                         \
            if (slot == NULL)                                                 \
                continue;                                                     \
            items[i].present = true;                                          \
            items[i].value = *slot;                                           \
        }                                                                     \
    }

KCL_DEFINE_OPT_NODE_LIST_LOADER(expr, kcl_expr_node, parse_expr_node)
KCL_DEFINE_OPT_NODE_LIST_LOADER(type, kcl_type_ref_node, parse_type_ref_node)

/* ---------------------------------------------------------------- *
 * Flat DTOs
 * ---------------------------------------------------------------- */

static kcl_identifier_t* parse_identifier(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_identifier_t* id = (kcl_identifier_t*)arena_zalloc(a, sizeof(*id));
    if (id == NULL)
        return NULL;
    if (!json_is_object(v))
        return id;
    parse_string_node_list(a, kcl_json_object_get(v, "names"), &id->names);
    id->pkgpath = read_key_str(a, v, "pkgpath");
    if (!decode_expr_context(json_str(kcl_json_object_get(v, "ctx")), &id->ctx))
        id->ctx = KCL_EXPR_CONTEXT_LOAD;
    return id;
}

static kcl_member_or_index_t* parse_member_or_index(kcl_arena_t* a, const kcl_json_value_t* v)
{
    if (!json_is_object(v))
        return NULL;
    kcl_member_or_index_t* m = (kcl_member_or_index_t*)arena_zalloc(a, sizeof(*m));
    if (m == NULL)
        return NULL;
    const char* tag = json_str(kcl_json_object_get(v, "type"));
    const kcl_json_value_t* payload = kcl_json_object_get(v, "value");
    if (tag != NULL && strcmp(tag, "Index") == 0) {
        m->kind = KCL_MEMBER_OR_INDEX_INDEX;
        m->index = parse_expr_node(a, payload);
    } else {
        m->kind = KCL_MEMBER_OR_INDEX_MEMBER;
        copy_string_node(&m->member, a, payload);
    }
    return m;
}

static kcl_target_t* parse_target(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_target_t* t = (kcl_target_t*)arena_zalloc(a, sizeof(*t));
    if (t == NULL)
        return NULL;
    if (!json_is_object(v))
        return t;
    copy_string_node(&t->name, a, kcl_json_object_get(v, "name"));
    /* `Vec<MemberOrIndex>` — bare, no NodeRef wrapper. */
    const kcl_json_value_t* paths = kcl_json_object_get(v, "paths");
    size_t n = json_is_array(paths) ? kcl_json_array_length(paths) : 0;
    if (n > 0) {
        kcl_member_or_index_t* items =
            (kcl_member_or_index_t*)arena_zalloc(a, n * sizeof(*items));
        if (items != NULL) {
            t->paths = items;
            t->paths_count = n;
            for (size_t i = 0; i < n; i++) {
                kcl_member_or_index_t* m = parse_member_or_index(a, kcl_json_array_get(paths, i));
                if (m != NULL)
                    items[i] = *m;
            }
        }
    }
    t->pkgpath = read_key_str(a, v, "pkgpath");
    return t;
}

static kcl_keyword_t* parse_keyword(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_keyword_t* kw = (kcl_keyword_t*)arena_zalloc(a, sizeof(*kw));
    if (kw == NULL)
        return NULL;
    if (!json_is_object(v))
        return kw;
    kcl_identifier_node_t* arg = parse_identifier_node(a, kcl_json_object_get(v, "arg"));
    if (arg != NULL)
        kw->arg = *arg;
    kw->value = parse_expr_node_opt(a, kcl_json_object_get(v, "value"));
    return kw;
}

static kcl_arguments_t* parse_arguments(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_arguments_t* args = (kcl_arguments_t*)arena_zalloc(a, sizeof(*args));
    if (args == NULL)
        return NULL;
    if (!json_is_object(v))
        return args;
    parse_identifier_node_list(a, kcl_json_object_get(v, "args"), &args->args);
    parse_opt_expr_node_list(a, kcl_json_object_get(v, "defaults"), &args->defaults);
    parse_opt_type_node_list(a, kcl_json_object_get(v, "ty_list"), &args->ty_list);
    return args;
}

static kcl_call_expr_t* parse_call_expr(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_call_expr_t* c = (kcl_call_expr_t*)arena_zalloc(a, sizeof(*c));
    if (c == NULL)
        return NULL;
    if (!json_is_object(v))
        return c;
    kcl_expr_node_t* func = parse_expr_node(a, kcl_json_object_get(v, "func"));
    if (func != NULL)
        c->func = *func;
    parse_expr_node_list(a, kcl_json_object_get(v, "args"), &c->args);
    parse_keyword_node_list(a, kcl_json_object_get(v, "keywords"), &c->keywords);
    return c;
}

static kcl_check_expr_t* parse_check_expr(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_check_expr_t* c = (kcl_check_expr_t*)arena_zalloc(a, sizeof(*c));
    if (c == NULL)
        return NULL;
    if (!json_is_object(v))
        return c;
    kcl_expr_node_t* test = parse_expr_node(a, kcl_json_object_get(v, "test"));
    if (test != NULL)
        c->test = *test;
    c->if_cond = parse_expr_node_opt(a, kcl_json_object_get(v, "if_cond"));
    c->msg = parse_expr_node_opt(a, kcl_json_object_get(v, "msg"));
    return c;
}

static kcl_config_entry_t* parse_config_entry(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_config_entry_t* e = (kcl_config_entry_t*)arena_zalloc(a, sizeof(*e));
    if (e == NULL)
        return NULL;
    if (!json_is_object(v))
        return e;
    e->key = parse_expr_node_opt(a, kcl_json_object_get(v, "key"));
    kcl_expr_node_t* value = parse_expr_node(a, kcl_json_object_get(v, "value"));
    if (value != NULL)
        e->value = *value;
    if (!decode_config_entry_op(json_str(kcl_json_object_get(v, "operation")), &e->operation))
        e->operation = KCL_CONFIG_ENTRY_OPERATION_UNION;
    /* `skip_serializing_if = "is_false"` — the key is simply absent when
     * false, which reads the same as an explicit false here. */
    e->is_shorthand = read_key_bool(v, "is_shorthand", false);
    return e;
}

static kcl_comp_clause_t* parse_comp_clause(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_comp_clause_t* c = (kcl_comp_clause_t*)arena_zalloc(a, sizeof(*c));
    if (c == NULL)
        return NULL;
    if (!json_is_object(v))
        return c;
    parse_identifier_node_list(a, kcl_json_object_get(v, "targets"), &c->targets);
    kcl_expr_node_t* iter = parse_expr_node(a, kcl_json_object_get(v, "iter"));
    if (iter != NULL)
        c->iter = *iter;
    parse_expr_node_list(a, kcl_json_object_get(v, "ifs"), &c->ifs);
    return c;
}

static kcl_schema_expr_t* parse_schema_expr(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_schema_expr_t* s = (kcl_schema_expr_t*)arena_zalloc(a, sizeof(*s));
    if (s == NULL)
        return NULL;
    if (!json_is_object(v))
        return s;
    kcl_identifier_node_t* name = parse_identifier_node(a, kcl_json_object_get(v, "name"));
    if (name != NULL)
        s->name = *name;
    parse_expr_node_list(a, kcl_json_object_get(v, "args"), &s->args);
    parse_keyword_node_list(a, kcl_json_object_get(v, "kwargs"), &s->kwargs);
    kcl_expr_node_t* config = parse_expr_node(a, kcl_json_object_get(v, "config"));
    if (config != NULL)
        s->config = *config;
    return s;
}

static kcl_schema_index_signature_t* parse_schema_index_signature(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_schema_index_signature_t* s =
        (kcl_schema_index_signature_t*)arena_zalloc(a, sizeof(*s));
    if (s == NULL)
        return NULL;
    if (!json_is_object(v))
        return s;
    s->key_name = parse_string_node(a, kcl_json_object_get(v, "key_name"));
    s->value = parse_expr_node_opt(a, kcl_json_object_get(v, "value"));
    s->any_other = read_key_bool(v, "any_other", false);
    kcl_type_ref_node_t* key_ty = parse_type_ref_node(a, kcl_json_object_get(v, "key_ty"));
    if (key_ty != NULL)
        s->key_ty = *key_ty;
    kcl_type_ref_node_t* value_ty = parse_type_ref_node(a, kcl_json_object_get(v, "value_ty"));
    if (value_ty != NULL)
        s->value_ty = *value_ty;
    return s;
}

/* ---------------------------------------------------------------- *
 * `Type` — `#[serde(tag = "type", content = "value")]`
 * ---------------------------------------------------------------- */

static kcl_type_node_t* parse_type_node(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_type_node_t* t = (kcl_type_node_t*)arena_zalloc(a, sizeof(*t));
    if (t == NULL)
        return NULL;
    if (!json_is_object(v))
        return t;
    const char* tag = json_str(kcl_json_object_get(v, "type"));
    t->type_tag = arena_strdup(a, tag);
    if (tag == NULL) {
        t->kind = KCL_TYPE_KIND_UNKNOWN;
        return t;
    }
    /* Newtype payloads are inlined into `value`, so `value` is either a
     * bare scalar (`Basic`) or a dict holding the payload. */
    const kcl_json_value_t* payload = kcl_json_object_get(v, "value");

    if (strcmp(tag, "Any") == 0) {
        /* The only unit variant: the wire has no `value` key at all. */
        t->kind = KCL_TYPE_KIND_ANY;
        return t;
    }
    if (strcmp(tag, "Named") == 0) {
        t->kind = KCL_TYPE_KIND_NAMED;
        kcl_identifier_t* id = parse_identifier(a, payload);
        if (id != NULL)
            t->u.named_type.name = *id;
        return t;
    }
    if (strcmp(tag, "Basic") == 0) {
        t->kind = KCL_TYPE_KIND_BASIC;
        if (!decode_basic_type(json_str(payload), &t->u.basic_type.basic))
            t->u.basic_type.basic = KCL_BASIC_TYPE_STR;
        return t;
    }
    if (strcmp(tag, "List") == 0) {
        t->kind = KCL_TYPE_KIND_LIST;
        t->u.list_type.inner_type = parse_type_ref_node_opt(a, kcl_json_object_get(payload, "inner_type"));
        return t;
    }
    if (strcmp(tag, "Dict") == 0) {
        t->kind = KCL_TYPE_KIND_DICT;
        t->u.dict_type.key_type = parse_type_ref_node_opt(a, kcl_json_object_get(payload, "key_type"));
        t->u.dict_type.value_type = parse_type_ref_node_opt(a, kcl_json_object_get(payload, "value_type"));
        return t;
    }
    if (strcmp(tag, "Union") == 0) {
        t->kind = KCL_TYPE_KIND_UNION;
        parse_type_ref_node_list(a, kcl_json_object_get(payload, "type_elements"),
            &t->u.union_type.type_elements);
        return t;
    }
    if (strcmp(tag, "Literal") == 0) {
        t->kind = KCL_TYPE_KIND_LITERAL;
        /* `LiteralType` is itself tag+content, so `value` here is a
         * second tagged document. */
        if (!decode_literal_type_kind(json_str(kcl_json_object_get(payload, "type")),
                &t->u.literal_type.kind)) {
            t->u.literal_type.kind = KCL_LITERAL_TYPE_STR;
            return t;
        }
        const kcl_json_value_t* lval = kcl_json_object_get(payload, "value");
        switch (t->u.literal_type.kind) {
        case KCL_LITERAL_TYPE_BOOL:
            t->u.literal_type.bool_value = read_bool(lval, false);
            break;
        case KCL_LITERAL_TYPE_INT:
            /* `IntLiteralType { value, suffix }` — inlined newtype. */
            t->u.literal_type.int_value.value = read_key_i64(lval, "value", 0);
            if (decode_number_binary_suffix(json_str(kcl_json_object_get(lval, "suffix")),
                    &t->u.literal_type.int_value.suffix))
                t->u.literal_type.int_value.has_suffix = true;
            break;
        case KCL_LITERAL_TYPE_FLOAT:
            t->u.literal_type.float_value = read_f64(lval, 0.0);
            break;
        case KCL_LITERAL_TYPE_STR:
            t->u.literal_type.str_value = read_str(a, lval);
            break;
        }
        return t;
    }
    if (strcmp(tag, "Function") == 0) {
        t->kind = KCL_TYPE_KIND_FUNCTION;
        /* `Option<Vec<NodeRef<Type>>>` — the whole list is optional, so
         * it gets a pointer to an arena-resident header. */
        kcl_type_ref_node_list_t* params =
            (kcl_type_ref_node_list_t*)arena_zalloc(a, sizeof(*params));
        if (params != NULL) {
            parse_type_ref_node_list(a, kcl_json_object_get(payload, "params_ty"), params);
            t->u.function_type.params_ty = params;
        }
        t->u.function_type.ret_ty = parse_type_ref_node_opt(a, kcl_json_object_get(payload, "ret_ty"));
        return t;
    }
    t->kind = KCL_TYPE_KIND_UNKNOWN;
    return t;
}

/* ---------------------------------------------------------------- *
 * `Expr` — `#[serde(tag = "type")]`
 * ---------------------------------------------------------------- */

static kcl_expr_kind_t expr_kind_from_tag(const char* tag)
{
    static const struct {
        const char* tag;
        kcl_expr_kind_t kind;
    } table[] = {
        { "Target", KCL_EXPR_KIND_TARGET },
        { "Identifier", KCL_EXPR_KIND_IDENTIFIER },
        { "Unary", KCL_EXPR_KIND_UNARY },
        { "Binary", KCL_EXPR_KIND_BINARY },
        { "If", KCL_EXPR_KIND_IF },
        { "Selector", KCL_EXPR_KIND_SELECTOR },
        { "Call", KCL_EXPR_KIND_CALL },
        { "Paren", KCL_EXPR_KIND_PAREN },
        { "Quant", KCL_EXPR_KIND_QUANT },
        { "List", KCL_EXPR_KIND_LIST },
        { "ListIfItem", KCL_EXPR_KIND_LIST_IF_ITEM },
        { "ListComp", KCL_EXPR_KIND_LIST_COMP },
        { "Starred", KCL_EXPR_KIND_STARRED },
        { "DictComp", KCL_EXPR_KIND_DICT_COMP },
        { "ConfigIfEntry", KCL_EXPR_KIND_CONFIG_IF_ENTRY },
        { "CompClause", KCL_EXPR_KIND_COMP_CLAUSE },
        { "Schema", KCL_EXPR_KIND_SCHEMA },
        { "Config", KCL_EXPR_KIND_CONFIG },
        { "Check", KCL_EXPR_KIND_CHECK },
        { "Lambda", KCL_EXPR_KIND_LAMBDA },
        { "Subscript", KCL_EXPR_KIND_SUBSCRIPT },
        { "Keyword", KCL_EXPR_KIND_KEYWORD },
        { "Arguments", KCL_EXPR_KIND_ARGUMENTS },
        { "Compare", KCL_EXPR_KIND_COMPARE },
        { "NumberLit", KCL_EXPR_KIND_NUMBER_LIT },
        { "StringLit", KCL_EXPR_KIND_STRING_LIT },
        { "NameConstantLit", KCL_EXPR_KIND_NAME_CONSTANT_LIT },
        { "JoinedString", KCL_EXPR_KIND_JOINED_STRING },
        { "FormattedValue", KCL_EXPR_KIND_FORMATTED_VALUE },
        { "Missing", KCL_EXPR_KIND_MISSING },
    };
    if (tag == NULL)
        return KCL_EXPR_KIND_UNKNOWN;
    for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++) {
        if (strcmp(tag, table[i].tag) == 0)
            return table[i].kind;
    }
    return KCL_EXPR_KIND_UNKNOWN;
}

static kcl_expr_t* parse_expr(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_expr_t* e = (kcl_expr_t*)arena_zalloc(a, sizeof(*e));
    if (e == NULL)
        return NULL;
    if (!json_is_object(v))
        return e;
    const char* tag = json_str(kcl_json_object_get(v, "type"));
    e->type_tag = arena_strdup(a, tag);
    e->kind = expr_kind_from_tag(tag);

    switch (e->kind) {
    case KCL_EXPR_KIND_TARGET: {
        kcl_target_t* t = parse_target(a, v);
        if (t != NULL)
            e->u.target = *t;
        break;
    }
    case KCL_EXPR_KIND_IDENTIFIER: {
        /* A newtype variant over a struct: the `Identifier` is flattened
         * into *this* object, so parse the same dict. */
        kcl_identifier_t* id = parse_identifier(a, v);
        if (id != NULL)
            e->u.identifier = *id;
        break;
    }
    case KCL_EXPR_KIND_UNARY: {
        if (!decode_unary_op(json_str(kcl_json_object_get(v, "op")), &e->u.unary_expr.op))
            e->u.unary_expr.op = KCL_UNARY_OP_UADD;
        kcl_expr_node_t* n = parse_expr_node(a, kcl_json_object_get(v, "operand"));
        if (n != NULL)
            e->u.unary_expr.operand = *n;
        break;
    }
    case KCL_EXPR_KIND_BINARY: {
        kcl_expr_node_t* left = parse_expr_node(a, kcl_json_object_get(v, "left"));
        if (left != NULL)
            e->u.binary_expr.left = *left;
        if (!decode_bin_op(json_str(kcl_json_object_get(v, "op")), &e->u.binary_expr.op))
            e->u.binary_expr.op = KCL_BIN_OP_ADD;
        kcl_expr_node_t* right = parse_expr_node(a, kcl_json_object_get(v, "right"));
        if (right != NULL)
            e->u.binary_expr.right = *right;
        break;
    }
    case KCL_EXPR_KIND_IF: {
        kcl_expr_node_t* body = parse_expr_node(a, kcl_json_object_get(v, "body"));
        if (body != NULL)
            e->u.if_expr.body = *body;
        kcl_expr_node_t* cond = parse_expr_node(a, kcl_json_object_get(v, "cond"));
        if (cond != NULL)
            e->u.if_expr.cond = *cond;
        /* `orelse` is `NodeRef<Expr>`, not an Option. */
        kcl_expr_node_t* orelse = parse_expr_node(a, kcl_json_object_get(v, "orelse"));
        if (orelse != NULL)
            e->u.if_expr.orelse = *orelse;
        break;
    }
    case KCL_EXPR_KIND_SELECTOR: {
        kcl_expr_node_t* value = parse_expr_node(a, kcl_json_object_get(v, "value"));
        if (value != NULL)
            e->u.selector_expr.value = *value;
        kcl_identifier_node_t* attr = parse_identifier_node(a, kcl_json_object_get(v, "attr"));
        if (attr != NULL)
            e->u.selector_expr.attr = *attr;
        if (!decode_expr_context(json_str(kcl_json_object_get(v, "ctx")), &e->u.selector_expr.ctx))
            e->u.selector_expr.ctx = KCL_EXPR_CONTEXT_LOAD;
        e->u.selector_expr.has_question = read_key_bool(v, "has_question", false);
        break;
    }
    case KCL_EXPR_KIND_CALL: {
        kcl_call_expr_t* c = parse_call_expr(a, v);
        if (c != NULL)
            e->u.call_expr = *c;
        break;
    }
    case KCL_EXPR_KIND_PAREN: {
        kcl_expr_node_t* inner = parse_expr_node(a, kcl_json_object_get(v, "expr"));
        if (inner != NULL)
            e->u.paren_expr.expr = *inner;
        break;
    }
    case KCL_EXPR_KIND_QUANT: {
        kcl_expr_node_t* target = parse_expr_node(a, kcl_json_object_get(v, "target"));
        if (target != NULL)
            e->u.quant_expr.target = *target;
        parse_identifier_node_list(a, kcl_json_object_get(v, "variables"),
            &e->u.quant_expr.variables);
        if (!decode_quant_op(json_str(kcl_json_object_get(v, "op")), &e->u.quant_expr.op))
            e->u.quant_expr.op = KCL_QUANT_OPERATION_ALL;
        kcl_expr_node_t* test = parse_expr_node(a, kcl_json_object_get(v, "test"));
        if (test != NULL)
            e->u.quant_expr.test = *test;
        e->u.quant_expr.if_cond = parse_expr_node_opt(a, kcl_json_object_get(v, "if_cond"));
        if (!decode_expr_context(json_str(kcl_json_object_get(v, "ctx")), &e->u.quant_expr.ctx))
            e->u.quant_expr.ctx = KCL_EXPR_CONTEXT_LOAD;
        break;
    }
    case KCL_EXPR_KIND_LIST: {
        parse_expr_node_list(a, kcl_json_object_get(v, "elts"), &e->u.list_expr.elts);
        if (!decode_expr_context(json_str(kcl_json_object_get(v, "ctx")), &e->u.list_expr.ctx))
            e->u.list_expr.ctx = KCL_EXPR_CONTEXT_LOAD;
        break;
    }
    case KCL_EXPR_KIND_LIST_IF_ITEM: {
        kcl_expr_node_t* if_cond = parse_expr_node(a, kcl_json_object_get(v, "if_cond"));
        if (if_cond != NULL)
            e->u.list_if_item_expr.if_cond = *if_cond;
        parse_expr_node_list(a, kcl_json_object_get(v, "exprs"), &e->u.list_if_item_expr.exprs);
        e->u.list_if_item_expr.orelse = parse_expr_node_opt(a, kcl_json_object_get(v, "orelse"));
        break;
    }
    case KCL_EXPR_KIND_LIST_COMP: {
        kcl_expr_node_t* elt = parse_expr_node(a, kcl_json_object_get(v, "elt"));
        if (elt != NULL)
            e->u.list_comp.elt = *elt;
        parse_comp_clause_node_list(a, kcl_json_object_get(v, "generators"),
            &e->u.list_comp.generators);
        break;
    }
    case KCL_EXPR_KIND_STARRED: {
        kcl_expr_node_t* value = parse_expr_node(a, kcl_json_object_get(v, "value"));
        if (value != NULL)
            e->u.starred_expr.value = *value;
        if (!decode_expr_context(json_str(kcl_json_object_get(v, "ctx")), &e->u.starred_expr.ctx))
            e->u.starred_expr.ctx = KCL_EXPR_CONTEXT_LOAD;
        break;
    }
    case KCL_EXPR_KIND_DICT_COMP: {
        /* `entry` is a bare `ConfigEntry` — no `NodeRef` wrapper, hence
         * no position of its own. */
        kcl_config_entry_t* entry = parse_config_entry(a, kcl_json_object_get(v, "entry"));
        if (entry != NULL)
            e->u.dict_comp.entry = *entry;
        parse_comp_clause_node_list(a, kcl_json_object_get(v, "generators"),
            &e->u.dict_comp.generators);
        break;
    }
    case KCL_EXPR_KIND_CONFIG_IF_ENTRY: {
        kcl_expr_node_t* if_cond = parse_expr_node(a, kcl_json_object_get(v, "if_cond"));
        if (if_cond != NULL)
            e->u.config_if_entry_expr.if_cond = *if_cond;
        parse_config_entry_node_list(a, kcl_json_object_get(v, "items"),
            &e->u.config_if_entry_expr.items);
        e->u.config_if_entry_expr.orelse = parse_expr_node_opt(a, kcl_json_object_get(v, "orelse"));
        break;
    }
    case KCL_EXPR_KIND_COMP_CLAUSE: {
        kcl_comp_clause_t* c = parse_comp_clause(a, v);
        if (c != NULL)
            e->u.comp_clause = *c;
        break;
    }
    case KCL_EXPR_KIND_SCHEMA: {
        kcl_schema_expr_t* s = parse_schema_expr(a, v);
        if (s != NULL)
            e->u.schema_expr = *s;
        break;
    }
    case KCL_EXPR_KIND_CONFIG:
        parse_config_entry_node_list(a, kcl_json_object_get(v, "items"), &e->u.config_expr.items);
        break;
    case KCL_EXPR_KIND_CHECK: {
        kcl_check_expr_t* c = parse_check_expr(a, v);
        if (c != NULL)
            e->u.check_expr = *c;
        break;
    }
    case KCL_EXPR_KIND_LAMBDA: {
        e->u.lambda_expr.args = parse_arguments_node_opt(a, kcl_json_object_get(v, "args"));
        parse_stmt_node_list(a, kcl_json_object_get(v, "body"), &e->u.lambda_expr.body);
        e->u.lambda_expr.return_ty = parse_type_ref_node_opt(a, kcl_json_object_get(v, "return_ty"));
        break;
    }
    case KCL_EXPR_KIND_SUBSCRIPT: {
        kcl_expr_node_t* value = parse_expr_node(a, kcl_json_object_get(v, "value"));
        if (value != NULL)
            e->u.subscript_expr.value = *value;
        e->u.subscript_expr.index = parse_expr_node_opt(a, kcl_json_object_get(v, "index"));
        /* A slice carries bounds and leaves `index` null. */
        e->u.subscript_expr.lower = parse_expr_node_opt(a, kcl_json_object_get(v, "lower"));
        e->u.subscript_expr.upper = parse_expr_node_opt(a, kcl_json_object_get(v, "upper"));
        e->u.subscript_expr.step = parse_expr_node_opt(a, kcl_json_object_get(v, "step"));
        if (!decode_expr_context(json_str(kcl_json_object_get(v, "ctx")), &e->u.subscript_expr.ctx))
            e->u.subscript_expr.ctx = KCL_EXPR_CONTEXT_LOAD;
        e->u.subscript_expr.has_question = read_key_bool(v, "has_question", false);
        break;
    }
    case KCL_EXPR_KIND_KEYWORD: {
        kcl_keyword_t* kw = parse_keyword(a, v);
        if (kw != NULL)
            e->u.keyword = *kw;
        break;
    }
    case KCL_EXPR_KIND_ARGUMENTS: {
        kcl_arguments_t* args = parse_arguments(a, v);
        if (args != NULL)
            e->u.arguments = *args;
        break;
    }
    case KCL_EXPR_KIND_COMPARE: {
        kcl_expr_node_t* left = parse_expr_node(a, kcl_json_object_get(v, "left"));
        if (left != NULL)
            e->u.compare_expr.left = *left;
        const kcl_json_value_t* ops = kcl_json_object_get(v, "ops");
        size_t n = json_is_array(ops) ? kcl_json_array_length(ops) : 0;
        if (n > 0) {
            kcl_cmp_op_t* items = (kcl_cmp_op_t*)arena_zalloc(a, n * sizeof(*items));
            if (items != NULL) {
                e->u.compare_expr.ops = items;
                e->u.compare_expr.ops_count = n;
                for (size_t i = 0; i < n; i++) {
                    if (!decode_cmp_op(json_str(kcl_json_array_get(ops, i)), &items[i]))
                        items[i] = KCL_CMP_OP_EQ;
                }
            }
        }
        parse_expr_node_list(a, kcl_json_object_get(v, "comparators"), &e->u.compare_expr.comparators);
        break;
    }
    case KCL_EXPR_KIND_NUMBER_LIT: {
        if (decode_number_binary_suffix(json_str(kcl_json_object_get(v, "binary_suffix")),
                &e->u.number_lit.binary_suffix))
            e->u.number_lit.has_binary_suffix = true;
        /* `NumberLitValue` is tag+content, and serde writes an `f64` as
         * a plain JSON number — so the tag is the only thing telling an
         * int payload from a float one. */
        const kcl_json_value_t* value = kcl_json_object_get(v, "value");
        if (!decode_number_lit_value_kind(json_str(kcl_json_object_get(value, "type")),
                &e->u.number_lit.value_kind))
            e->u.number_lit.value_kind = KCL_NUMBER_LIT_VALUE_INT;
        if (e->u.number_lit.value_kind == KCL_NUMBER_LIT_VALUE_FLOAT)
            e->u.number_lit.float_value = read_f64(kcl_json_object_get(value, "value"), 0.0);
        else
            e->u.number_lit.int_value = read_i64(kcl_json_object_get(value, "value"), 0);
        break;
    }
    case KCL_EXPR_KIND_STRING_LIT: {
        e->u.string_lit.is_long_string = read_key_bool(v, "is_long_string", false);
        e->u.string_lit.raw_value = read_key_str(a, v, "raw_value");
        e->u.string_lit.value = read_key_str(a, v, "value");
        break;
    }
    case KCL_EXPR_KIND_NAME_CONSTANT_LIT:
        if (!decode_name_constant(json_str(kcl_json_object_get(v, "value")),
                &e->u.name_constant_lit.value))
            e->u.name_constant_lit.value = KCL_NAME_CONSTANT_UNDEFINED;
        break;
    case KCL_EXPR_KIND_JOINED_STRING: {
        e->u.joined_string.is_long_string = read_key_bool(v, "is_long_string", false);
        parse_expr_node_list(a, kcl_json_object_get(v, "values"), &e->u.joined_string.values);
        e->u.joined_string.raw_value = read_key_str(a, v, "raw_value");
        break;
    }
    case KCL_EXPR_KIND_FORMATTED_VALUE: {
        e->u.formatted_value.is_long_string = read_key_bool(v, "is_long_string", false);
        kcl_expr_node_t* value = parse_expr_node(a, kcl_json_object_get(v, "value"));
        if (value != NULL)
            e->u.formatted_value.value = *value;
        e->u.formatted_value.format_spec = read_key_str(a, v, "format_spec");
        break;
    }
    case KCL_EXPR_KIND_MISSING:
        /* `MissingExpr` is a unit struct — nothing to read. */
        break;
    case KCL_EXPR_KIND_UNKNOWN:
    default:
        break;
    }
    return e;
}

/* ---------------------------------------------------------------- *
 * `Stmt` — `#[serde(tag = "type")]`
 * ---------------------------------------------------------------- */

static kcl_stmt_kind_t stmt_kind_from_tag(const char* tag)
{
    static const struct {
        const char* tag;
        kcl_stmt_kind_t kind;
    } table[] = {
        { "TypeAlias", KCL_STMT_KIND_TYPE_ALIAS },
        { "Expr", KCL_STMT_KIND_EXPR },
        { "Unification", KCL_STMT_KIND_UNIFICATION },
        { "Assign", KCL_STMT_KIND_ASSIGN },
        { "AugAssign", KCL_STMT_KIND_AUG_ASSIGN },
        { "Assert", KCL_STMT_KIND_ASSERT },
        { "If", KCL_STMT_KIND_IF },
        { "Import", KCL_STMT_KIND_IMPORT },
        { "SchemaAttr", KCL_STMT_KIND_SCHEMA_ATTR },
        { "Schema", KCL_STMT_KIND_SCHEMA },
        { "Rule", KCL_STMT_KIND_RULE },
    };
    if (tag == NULL)
        return KCL_STMT_KIND_UNKNOWN;
    for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++) {
        if (strcmp(tag, table[i].tag) == 0)
            return table[i].kind;
    }
    return KCL_STMT_KIND_UNKNOWN;
}

static kcl_stmt_t* parse_stmt(kcl_arena_t* a, const kcl_json_value_t* v)
{
    kcl_stmt_t* s = (kcl_stmt_t*)arena_zalloc(a, sizeof(*s));
    if (s == NULL)
        return NULL;
    if (!json_is_object(v))
        return s;
    const char* tag = json_str(kcl_json_object_get(v, "type"));
    s->type_tag = arena_strdup(a, tag);
    s->kind = stmt_kind_from_tag(tag);

    switch (s->kind) {
    case KCL_STMT_KIND_TYPE_ALIAS: {
        kcl_identifier_node_t* name = parse_identifier_node(a, kcl_json_object_get(v, "type_name"));
        if (name != NULL)
            s->u.type_alias_stmt.type_name = *name;
        copy_string_node(&s->u.type_alias_stmt.type_value, a, kcl_json_object_get(v, "type_value"));
        kcl_type_ref_node_t* ty = parse_type_ref_node(a, kcl_json_object_get(v, "ty"));
        if (ty != NULL)
            s->u.type_alias_stmt.ty = *ty;
        break;
    }
    case KCL_STMT_KIND_EXPR:
        parse_expr_node_list(a, kcl_json_object_get(v, "exprs"), &s->u.expr_stmt.exprs);
        break;
    case KCL_STMT_KIND_UNIFICATION: {
        kcl_identifier_node_t* target = parse_identifier_node(a, kcl_json_object_get(v, "target"));
        if (target != NULL)
            s->u.unification_stmt.target = *target;
        kcl_schema_expr_node_t* value = parse_schema_expr_node(a, kcl_json_object_get(v, "value"));
        if (value != NULL)
            s->u.unification_stmt.value = *value;
        break;
    }
    case KCL_STMT_KIND_ASSIGN: {
        parse_target_node_list(a, kcl_json_object_get(v, "targets"), &s->u.assign_stmt.targets);
        kcl_expr_node_t* value = parse_expr_node(a, kcl_json_object_get(v, "value"));
        if (value != NULL)
            s->u.assign_stmt.value = *value;
        s->u.assign_stmt.ty = parse_type_ref_node_opt(a, kcl_json_object_get(v, "ty"));
        break;
    }
    case KCL_STMT_KIND_AUG_ASSIGN: {
        kcl_target_node_t* target = parse_target_node(a, kcl_json_object_get(v, "target"));
        if (target != NULL)
            s->u.aug_assign_stmt.target = *target;
        kcl_expr_node_t* value = parse_expr_node(a, kcl_json_object_get(v, "value"));
        if (value != NULL)
            s->u.aug_assign_stmt.value = *value;
        if (!decode_aug_op(json_str(kcl_json_object_get(v, "op")), &s->u.aug_assign_stmt.op))
            s->u.aug_assign_stmt.op = KCL_AUG_OP_ASSIGN;
        break;
    }
    case KCL_STMT_KIND_ASSERT: {
        kcl_expr_node_t* test = parse_expr_node(a, kcl_json_object_get(v, "test"));
        if (test != NULL)
            s->u.assert_stmt.test = *test;
        s->u.assert_stmt.if_cond = parse_expr_node_opt(a, kcl_json_object_get(v, "if_cond"));
        s->u.assert_stmt.msg = parse_expr_node_opt(a, kcl_json_object_get(v, "msg"));
        break;
    }
    case KCL_STMT_KIND_IF: {
        kcl_expr_node_t* cond = parse_expr_node(a, kcl_json_object_get(v, "cond"));
        if (cond != NULL)
            s->u.if_stmt.cond = *cond;
        parse_stmt_node_list(a, kcl_json_object_get(v, "body"), &s->u.if_stmt.body);
        /* `orelse` is `Vec<NodeRef<Stmt>>`, not an expression. */
        parse_stmt_node_list(a, kcl_json_object_get(v, "orelse"), &s->u.if_stmt.orelse);
        break;
    }
    case KCL_STMT_KIND_IMPORT: {
        copy_string_node(&s->u.import_stmt.path, a, kcl_json_object_get(v, "path"));
        s->u.import_stmt.rawpath = read_key_str(a, v, "rawpath");
        s->u.import_stmt.name = read_key_str(a, v, "name");
        s->u.import_stmt.asname = parse_string_node(a, kcl_json_object_get(v, "asname"));
        s->u.import_stmt.pkg_name = read_key_str(a, v, "pkg_name");
        break;
    }
    case KCL_STMT_KIND_SCHEMA_ATTR: {
        /* `SchemaAttr.doc` is a plain `String`, not a `NodeRef<String>`. */
        s->u.schema_attr.doc = read_key_str(a, v, "doc");
        copy_string_node(&s->u.schema_attr.name, a, kcl_json_object_get(v, "name"));
        if (decode_aug_op(json_str(kcl_json_object_get(v, "op")), &s->u.schema_attr.op))
            s->u.schema_attr.has_op = true;
        s->u.schema_attr.value = parse_expr_node_opt(a, kcl_json_object_get(v, "value"));
        s->u.schema_attr.is_optional = read_key_bool(v, "is_optional", false);
        /* `Vec<NodeRef<CallExpr>>` — a bare `{func,args,keywords}` per
         * element, with no `"type":"Call"` tag. */
        parse_call_expr_node_list(a, kcl_json_object_get(v, "decorators"),
            &s->u.schema_attr.decorators);
        /* `ty` is `NodeRef<Type>`, not optional upstream. */
        kcl_type_ref_node_t* ty = parse_type_ref_node(a, kcl_json_object_get(v, "ty"));
        if (ty != NULL)
            s->u.schema_attr.ty = *ty;
        break;
    }
    case KCL_STMT_KIND_SCHEMA: {
        s->u.schema_stmt.doc = parse_string_node(a, kcl_json_object_get(v, "doc"));
        copy_string_node(&s->u.schema_stmt.name, a, kcl_json_object_get(v, "name"));
        s->u.schema_stmt.parent_name = parse_identifier_node_opt(a, kcl_json_object_get(v, "parent_name"));
        s->u.schema_stmt.for_host_name = parse_identifier_node_opt(a, kcl_json_object_get(v, "for_host_name"));
        s->u.schema_stmt.is_mixin = read_key_bool(v, "is_mixin", false);
        s->u.schema_stmt.is_protocol = read_key_bool(v, "is_protocol", false);
        s->u.schema_stmt.args = parse_arguments_node_opt(a, kcl_json_object_get(v, "args"));
        parse_identifier_node_list(a, kcl_json_object_get(v, "mixins"), &s->u.schema_stmt.mixins);
        parse_stmt_node_list(a, kcl_json_object_get(v, "body"), &s->u.schema_stmt.body);
        /* Both of these are struct payloads, so no `"type"` tag. */
        parse_call_expr_node_list(a, kcl_json_object_get(v, "decorators"), &s->u.schema_stmt.decorators);
        parse_check_expr_node_list(a, kcl_json_object_get(v, "checks"), &s->u.schema_stmt.checks);
        s->u.schema_stmt.index_signature =
            parse_schema_index_signature_node_opt(a, kcl_json_object_get(v, "index_signature"));
        break;
    }
    case KCL_STMT_KIND_RULE: {
        s->u.rule_stmt.doc = parse_string_node(a, kcl_json_object_get(v, "doc"));
        copy_string_node(&s->u.rule_stmt.name, a, kcl_json_object_get(v, "name"));
        parse_identifier_node_list(a, kcl_json_object_get(v, "parent_rules"), &s->u.rule_stmt.parent_rules);
        parse_call_expr_node_list(a, kcl_json_object_get(v, "decorators"), &s->u.rule_stmt.decorators);
        parse_check_expr_node_list(a, kcl_json_object_get(v, "checks"), &s->u.rule_stmt.checks);
        s->u.rule_stmt.args = parse_arguments_node_opt(a, kcl_json_object_get(v, "args"));
        s->u.rule_stmt.for_host_name = parse_identifier_node_opt(a, kcl_json_object_get(v, "for_host_name"));
        break;
    }
    case KCL_STMT_KIND_UNKNOWN:
    default:
        break;
    }
    return s;
}

/* ---------------------------------------------------------------- *
 * Module / Program
 * ---------------------------------------------------------------- */

static void parse_module_into(kcl_arena_t* a, kcl_module_t* m, const kcl_json_value_t* v)
{
    memset(m, 0, sizeof(*m));
    m->_internals = a;
    if (!json_is_object(v))
        return;
    m->filename = read_key_str(a, v, "filename");
    m->doc = parse_string_node(a, kcl_json_object_get(v, "doc"));
    parse_stmt_node_list(a, kcl_json_object_get(v, "body"), &m->body);
    /* `Vec<NodeRef<Comment>>` — the payload is `{text}`, not a bare
     * string. */
    parse_comment_node_list(a, kcl_json_object_get(v, "comments"), &m->comments);
}

kcl_module_t* kcl_ast_parse_module(const char* ast_json)
{
    if (ast_json == NULL)
        return NULL;
    kcl_json_value_t* root = kcl_json_parse(ast_json);
    if (root == NULL)
        return NULL;
    kcl_arena_t* a = (kcl_arena_t*)calloc(1, sizeof(*a));
    kcl_module_t* m = (kcl_module_t*)calloc(1, sizeof(*m));
    if (a == NULL || m == NULL) {
        free(a);
        free(m);
        kcl_json_free(root);
        return NULL;
    }
    parse_module_into(a, m, root);
    kcl_json_free(root);
    return m;
}

void kcl_module_free(kcl_module_t* module)
{
    if (module == NULL)
        return;
    arena_free((kcl_arena_t*)module->_internals);
    free(module->_internals);
    free(module);
}

/*
 * The wire is `{"root": ".", "pkgs": {"__main__": [Module, …]}}`; an
 * older Rust ABI emitted a bare `[Module, …]`, so both are accepted.
 * Only `__main__` is surfaced — the exported header models the main
 * package, not the imported ones.
 */
kcl_program_t* kcl_ast_parse_program(const char* ast_json)
{
    if (ast_json == NULL)
        return NULL;
    kcl_json_value_t* root = kcl_json_parse(ast_json);
    if (root == NULL)
        return NULL;
    kcl_arena_t* a = (kcl_arena_t*)calloc(1, sizeof(*a));
    kcl_program_t* p = (kcl_program_t*)calloc(1, sizeof(*p));
    if (a == NULL || p == NULL) {
        free(a);
        free(p);
        kcl_json_free(root);
        return NULL;
    }
    p->_internals = a;

    const kcl_json_value_t* main_pkg = NULL;
    if (json_is_array(root)) {
        main_pkg = root;
        p->root = arena_strdup(a, ".");
    } else {
        p->root = read_key_str(a, root, "root");
        const kcl_json_value_t* pkgs = kcl_json_object_get(root, "pkgs");
        main_pkg = kcl_json_object_get(pkgs, "__main__");
    }
    size_t n = json_is_array(main_pkg) ? kcl_json_array_length(main_pkg) : 0;
    if (n > 0) {
        /* `calloc`, not the arena: each module carries its own
         * `_internals` and is freed independently. */
        kcl_module_t** mods = (kcl_module_t**)calloc(n, sizeof(*mods));
        if (mods != NULL) {
            p->main_package = mods;
            p->main_package_count = n;
            for (size_t i = 0; i < n; i++) {
                mods[i] = (kcl_module_t*)calloc(1, sizeof(**mods));
                if (mods[i] != NULL)
                    parse_module_into(a, mods[i], kcl_json_array_get(main_pkg, i));
            }
        }
    }
    kcl_json_free(root);
    return p;
}

void kcl_program_free(kcl_program_t* program)
{
    if (program == NULL)
        return;
    /* The modules share the program's arena, so they are not freed
     * individually — only their own shells. */
    for (size_t i = 0; i < program->main_package_count; i++)
        free(program->main_package[i]);
    free(program->main_package);
    arena_free((kcl_arena_t*)program->_internals);
    free(program->_internals);
    free(program);
}

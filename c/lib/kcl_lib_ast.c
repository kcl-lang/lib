/*
 * kcl_lib_ast.c — Implementation of the typed AST module for the C binding.
 *
 * Companion to `kcl_lib_ast.h`. Implements the minimal recursive-descent
 * JSON parser and the typed AST deserializer. Mirrors the typed AST
 * packages already merged for Java, Go, Python, Node.js, .NET, WASM,
 * Lua, Swift, and Kotlin: parse a real KCL fixture through the native
 * FFI (`kcl_parse_file` / `kcl_parse_program`) and verify the resulting
 * `ast_json` string deserializes cleanly into the typed AST structures
 * declared in `kcl_lib_ast.h`.
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
 * AST deserialization
 * ---------------------------------------------------------------- */

static void free_pos(kcl_pos_t* pos)
{
    if (pos == NULL)
        return;
    free(pos->filename);
    free(pos);
}

static kcl_pos_t* parse_pos(const kcl_json_value_t* v)
{
    if (v == NULL || v->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_pos_t* pos = (kcl_pos_t*)calloc(1, sizeof(*pos));
    const kcl_json_value_t* fn = kcl_json_object_get(v, "filename");
    if (fn != NULL && fn->type == KCL_JSON_STRING)
        pos->filename = strdup(fn->u.string.data);
    const kcl_json_value_t* ln = kcl_json_object_get(v, "line");
    pos->line = (ln != NULL && ln->type == KCL_JSON_NUMBER) ? (int64_t)ln->u.number : 0;
    const kcl_json_value_t* col = kcl_json_object_get(v, "column");
    pos->column = (col != NULL && col->type == KCL_JSON_NUMBER) ? (int64_t)col->u.number : 0;
    const kcl_json_value_t* eln = kcl_json_object_get(v, "end_line");
    pos->end_line = (eln != NULL && eln->type == KCL_JSON_NUMBER) ? (int64_t)eln->u.number : 0;
    const kcl_json_value_t* ecol = kcl_json_object_get(v, "end_column");
    pos->end_column = (ecol != NULL && ecol->type == KCL_JSON_NUMBER) ? (int64_t)ecol->u.number : 0;
    return pos;
}

static char* json_to_string(const kcl_json_value_t* v)
{
    if (v == NULL)
        return NULL;
    if (v->type == KCL_JSON_STRING)
        return strdup(v->u.string.data);
    if (v->type == KCL_JSON_NULL)
        return NULL;
    /* Numbers, bools: convert to text. */
    char buf[64];
    if (v->type == KCL_JSON_NUMBER) {
        snprintf(buf, sizeof(buf), "%g", v->u.number);
        return strdup(buf);
    }
    if (v->type == KCL_JSON_BOOL)
        return strdup(v->u.boolean ? "true" : "false");
    return NULL;
}

static void free_string_list(char** list, size_t count)
{
    if (list == NULL)
        return;
    for (size_t i = 0; i < count; i++)
        free(list[i]);
    free(list);
}

static char** parse_string_list(const kcl_json_value_t* v, size_t* out_count)
{
    *out_count = 0;
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return NULL;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return NULL;
    char** list = (char**)calloc(n, sizeof(char*));
    for (size_t i = 0; i < n; i++) {
        const kcl_json_value_t* e = kcl_json_array_get(v, i);
        list[i] = json_to_string(e);
    }
    *out_count = n;
    return list;
}

/* Forward decls */
static void free_stmt(kcl_stmt_t* s);
static void free_expr(kcl_expr_t* e);
static void free_type_node(kcl_type_node_t* t);
static void free_type_node_node(kcl_type_node_node_t* n);
static void free_type_node_node_list(kcl_type_node_node_list_t* list);
static void free_identifier(kcl_identifier_t* id);
static void free_identifier_node_list(kcl_identifier_node_list_t* list);
static void free_target(kcl_target_t* t);
static void free_target_node_list(kcl_target_node_list_t* list);
static void free_arguments(kcl_arguments_t* a);
static void free_decorator(kcl_decorator_t* d);
static void free_keyword(kcl_keyword_t* kw);
static void free_keyword_node_list(kcl_keyword_node_list_t* list);
static void free_decorator_node_list(kcl_decorator_node_list_t* list);
static void free_check_expr_node_list(kcl_check_expr_node_list_t* list);
static void free_config_entry_node_list(kcl_config_entry_node_list_t* list);
static void free_comp_clause_node_list(kcl_comp_clause_node_list_t* list);
static void free_quant_operation_node_list(kcl_quant_operation_node_list_t* list);
static void free_schema_config(kcl_schema_config_t* sc);
static void free_config_entry(kcl_config_entry_t* ce);
static void free_quant_operation(kcl_quant_operation_t* q);
static void free_comp_clause(kcl_comp_clause_t* cc);
static void free_check_expr(kcl_check_expr_t* ce);
static void free_schema_index_signature(kcl_schema_index_signature_t* sis);
static void free_expr_node_list(kcl_expr_node_list_t* list);
static void free_stmt_node_list(kcl_stmt_node_list_t* list);

static kcl_stmt_t* parse_stmt(const kcl_json_value_t* node);
static kcl_expr_t* parse_expr(const kcl_json_value_t* node);
static kcl_type_node_t* parse_type_node(const kcl_json_value_t* node);
static kcl_identifier_t* parse_identifier(const kcl_json_value_t* node);
static kcl_arguments_t* parse_arguments(const kcl_json_value_t* node);
static kcl_target_t* parse_target(const kcl_json_value_t* node);
static kcl_decorator_t* parse_decorator(const kcl_json_value_t* node);
static kcl_keyword_t* parse_keyword(const kcl_json_value_t* node);
static kcl_schema_config_t* parse_schema_config(const kcl_json_value_t* node);
static kcl_config_entry_t* parse_config_entry(const kcl_json_value_t* node);
static kcl_quant_operation_t* parse_quant_operation(const kcl_json_value_t* node);
static kcl_comp_clause_t* parse_comp_clause(const kcl_json_value_t* node);
static kcl_check_expr_t* parse_check_expr(const kcl_json_value_t* node);
static kcl_schema_index_signature_t* parse_schema_index_signature(const kcl_json_value_t* node);

static kcl_string_node_t* parse_string_node(const kcl_json_value_t* v)
{
    if (v == NULL || v->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_string_node_t* n = (kcl_string_node_t*)calloc(1, sizeof(*n));
    /* Primitive NodeRef: `node` is the raw value (here, a string). */
    const kcl_json_value_t* node = kcl_json_object_get(v, "node");
    n->node = json_to_string(node);
    n->pos = parse_pos(kcl_json_object_get(v, "pos"));
    const kcl_json_value_t* id = kcl_json_object_get(v, "id");
    if (id != NULL && id->type == KCL_JSON_STRING)
        n->id = strdup(id->u.string.data);
    return n;
}

static void free_string_node(kcl_string_node_t* n)
{
    if (n == NULL)
        return;
    /* Only free the fields — `n` itself may be embedded in a parent
     * struct (e.g. `kcl_schema_stmt.name` is a value-typed member,
     * not a pointer). The caller is responsible for freeing the
     * backing storage of `n` if it was heap-allocated separately. */
    free(n->node);
    free(n->id);
    free_pos(n->pos);
}

static void free_string_node_list(kcl_string_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++)
        free_string_node(&list->items[i]);
    free(list->items);
}

/* For polymorphic `node` payloads, the wire shape is:
 *   {"node": {"type": "...", ...variant fields...}, "pos": {...}, "id": "..."}
 * The inner dict is what gets dispatched by tag. We allocate the variant
 * struct, point `node` at it, and parse `pos` / `id` separately. */
static void fill_node_ref(kcl_pos_t** pos_out, char** id_out, const kcl_json_value_t* v)
{
    *pos_out = parse_pos(kcl_json_object_get(v, "pos"));
    const kcl_json_value_t* id = kcl_json_object_get(v, "id");
    *id_out = (id != NULL && id->type == KCL_JSON_STRING) ? strdup(id->u.string.data) : NULL;
}

static kcl_stmt_node_t parse_stmt_node(const kcl_json_value_t* v)
{
    kcl_stmt_node_t n = { NULL, NULL, NULL };
    if (v == NULL || v->type != KCL_JSON_OBJECT)
        return n;
    const kcl_json_value_t* node = kcl_json_object_get(v, "node");
    n.node = parse_stmt(node);
    fill_node_ref(&n.pos, &n.id, v);
    return n;
}

static kcl_expr_node_t parse_expr_node(const kcl_json_value_t* v)
{
    kcl_expr_node_t n = { NULL, NULL, NULL };
    if (v == NULL || v->type != KCL_JSON_OBJECT)
        return n;
    n.node = parse_expr(kcl_json_object_get(v, "node"));
    fill_node_ref(&n.pos, &n.id, v);
    return n;
}

static kcl_type_node_node_t parse_type_node_node(const kcl_json_value_t* v)
{
    kcl_type_node_node_t n = { NULL, NULL, NULL };
    if (v == NULL || v->type != KCL_JSON_OBJECT)
        return n;
    n.node = parse_type_node(kcl_json_object_get(v, "node"));
    fill_node_ref(&n.pos, &n.id, v);
    return n;
}

static kcl_target_node_t parse_target_node(const kcl_json_value_t* v)
{
    kcl_target_node_t n = { NULL, NULL, NULL };
    if (v == NULL || v->type != KCL_JSON_OBJECT)
        return n;
    n.node = parse_target(kcl_json_object_get(v, "node"));
    fill_node_ref(&n.pos, &n.id, v);
    return n;
}

static kcl_arguments_node_t parse_arguments_node(const kcl_json_value_t* v)
{
    kcl_arguments_node_t n = { NULL, NULL, NULL };
    if (v == NULL || v->type != KCL_JSON_OBJECT)
        return n;
    n.node = parse_arguments(kcl_json_object_get(v, "node"));
    fill_node_ref(&n.pos, &n.id, v);
    return n;
}

static kcl_identifier_node_t parse_identifier_node(const kcl_json_value_t* v)
{
    kcl_identifier_node_t n = { NULL, NULL, NULL };
    if (v == NULL || v->type != KCL_JSON_OBJECT)
        return n;
    n.node = parse_identifier(kcl_json_object_get(v, "node"));
    fill_node_ref(&n.pos, &n.id, v);
    return n;
}

static kcl_schema_index_signature_node_t parse_schema_index_signature_node(const kcl_json_value_t* v)
{
    kcl_schema_index_signature_node_t n = { NULL, NULL, NULL };
    if (v == NULL || v->type != KCL_JSON_OBJECT)
        return n;
    n.node = parse_schema_index_signature(kcl_json_object_get(v, "node"));
    fill_node_ref(&n.pos, &n.id, v);
    return n;
}

static kcl_stmt_node_list_t parse_stmt_node_list(const kcl_json_value_t* v)
{
    kcl_stmt_node_list_t out = { NULL, 0 };
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out.items = (kcl_stmt_node_t*)calloc(n, sizeof(kcl_stmt_node_t));
    out.count = n;
    for (size_t i = 0; i < n; i++)
        out.items[i] = parse_stmt_node(kcl_json_array_get(v, i));
    return out;
}

static kcl_expr_node_list_t parse_expr_node_list(const kcl_json_value_t* v)
{
    kcl_expr_node_list_t out = { NULL, 0 };
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out.items = (kcl_expr_node_t*)calloc(n, sizeof(kcl_expr_node_t));
    out.count = n;
    for (size_t i = 0; i < n; i++)
        out.items[i] = parse_expr_node(kcl_json_array_get(v, i));
    return out;
}

static kcl_type_node_node_list_t parse_type_node_node_list(const kcl_json_value_t* v)
{
    kcl_type_node_node_list_t out = { NULL, 0 };
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out.items = (kcl_type_node_node_t*)calloc(n, sizeof(kcl_type_node_node_t));
    out.count = n;
    for (size_t i = 0; i < n; i++)
        out.items[i] = parse_type_node_node(kcl_json_array_get(v, i));
    return out;
}

static kcl_target_node_list_t parse_target_node_list(const kcl_json_value_t* v)
{
    kcl_target_node_list_t out = { NULL, 0 };
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out.items = (kcl_target_node_t*)calloc(n, sizeof(kcl_target_node_t));
    out.count = n;
    for (size_t i = 0; i < n; i++)
        out.items[i] = parse_target_node(kcl_json_array_get(v, i));
    return out;
}

static kcl_string_node_list_t parse_string_node_list(const kcl_json_value_t* v)
{
    kcl_string_node_list_t out = { NULL, 0 };
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out.items = (kcl_string_node_t*)calloc(n, sizeof(kcl_string_node_t));
    out.count = n;
    for (size_t i = 0; i < n; i++)
        out.items[i] = *parse_string_node(kcl_json_array_get(v, i));
    return out;
}

static kcl_identifier_node_list_t parse_identifier_node_list(const kcl_json_value_t* v)
{
    kcl_identifier_node_list_t out = { NULL, 0 };
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out.items = (kcl_identifier_node_t*)calloc(n, sizeof(kcl_identifier_node_t));
    out.count = n;
    for (size_t i = 0; i < n; i++)
        out.items[i] = parse_identifier_node(kcl_json_array_get(v, i));
    return out;
}

/* Keyword list (flat DTOs) */
static kcl_keyword_node_list_t* parse_keyword_node_list_alloc(const kcl_json_value_t* v)
{
    kcl_keyword_node_list_t* out = (kcl_keyword_node_list_t*)calloc(1, sizeof(*out));
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out->items = (kcl_keyword_node_t*)calloc(n, sizeof(kcl_keyword_node_t));
    out->count = n;
    for (size_t i = 0; i < n; i++) {
        const kcl_json_value_t* e = kcl_json_array_get(v, i);
        const kcl_json_value_t* node = kcl_json_object_get(e, "node");
        out->items[i].node = parse_keyword(node);
        fill_node_ref(&out->items[i].pos, &out->items[i].id, e);
    }
    return out;
}

/* Decorator list (flat DTOs) */
static kcl_decorator_node_list_t* parse_decorator_node_list_alloc(const kcl_json_value_t* v)
{
    kcl_decorator_node_list_t* out = (kcl_decorator_node_list_t*)calloc(1, sizeof(*out));
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out->items = (kcl_decorator_node_t*)calloc(n, sizeof(kcl_decorator_node_t));
    out->count = n;
    for (size_t i = 0; i < n; i++) {
        const kcl_json_value_t* e = kcl_json_array_get(v, i);
        const kcl_json_value_t* node = kcl_json_object_get(e, "node");
        out->items[i].node = parse_decorator(node);
        fill_node_ref(&out->items[i].pos, &out->items[i].id, e);
    }
    return out;
}

/* Check-expr list */
static kcl_check_expr_node_list_t* parse_check_expr_node_list_alloc(const kcl_json_value_t* v)
{
    kcl_check_expr_node_list_t* out = (kcl_check_expr_node_list_t*)calloc(1, sizeof(*out));
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out->items = (kcl_check_expr_node_t*)calloc(n, sizeof(kcl_check_expr_node_t));
    out->count = n;
    for (size_t i = 0; i < n; i++) {
        const kcl_json_value_t* e = kcl_json_array_get(v, i);
        const kcl_json_value_t* node = kcl_json_object_get(e, "node");
        out->items[i].node = parse_check_expr(node);
        fill_node_ref(&out->items[i].pos, &out->items[i].id, e);
    }
    return out;
}

/* Config entry list */
static kcl_config_entry_node_list_t* parse_config_entry_node_list_alloc(const kcl_json_value_t* v)
{
    kcl_config_entry_node_list_t* out = (kcl_config_entry_node_list_t*)calloc(1, sizeof(*out));
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out->items = (kcl_config_entry_node_t*)calloc(n, sizeof(kcl_config_entry_node_t));
    out->count = n;
    for (size_t i = 0; i < n; i++) {
        const kcl_json_value_t* e = kcl_json_array_get(v, i);
        const kcl_json_value_t* node = kcl_json_object_get(e, "node");
        out->items[i].node = parse_config_entry(node);
        fill_node_ref(&out->items[i].pos, &out->items[i].id, e);
    }
    return out;
}

/* Comp-clause list */
static kcl_comp_clause_node_list_t* parse_comp_clause_node_list_alloc(const kcl_json_value_t* v)
{
    kcl_comp_clause_node_list_t* out = (kcl_comp_clause_node_list_t*)calloc(1, sizeof(*out));
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out->items = (kcl_comp_clause_node_t*)calloc(n, sizeof(kcl_comp_clause_node_t));
    out->count = n;
    for (size_t i = 0; i < n; i++) {
        const kcl_json_value_t* e = kcl_json_array_get(v, i);
        const kcl_json_value_t* node = kcl_json_object_get(e, "node");
        out->items[i].node = parse_comp_clause(node);
        fill_node_ref(&out->items[i].pos, &out->items[i].id, e);
    }
    return out;
}

/* Quant operation list */
static kcl_quant_operation_node_list_t* parse_quant_operation_node_list_alloc(const kcl_json_value_t* v)
{
    kcl_quant_operation_node_list_t* out = (kcl_quant_operation_node_list_t*)calloc(1, sizeof(*out));
    if (v == NULL || v->type != KCL_JSON_ARRAY)
        return out;
    size_t n = kcl_json_array_length(v);
    if (n == 0)
        return out;
    out->items = (kcl_quant_operation_node_t*)calloc(n, sizeof(kcl_quant_operation_node_t));
    out->count = n;
    for (size_t i = 0; i < n; i++) {
        const kcl_json_value_t* e = kcl_json_array_get(v, i);
        const kcl_json_value_t* node = kcl_json_object_get(e, "node");
        out->items[i].node = parse_quant_operation(node);
        fill_node_ref(&out->items[i].pos, &out->items[i].id, e);
    }
    return out;
}

/* ---------------------------------------------------------------- *
 * Identifier
 * ---------------------------------------------------------------- */

static kcl_identifier_t* parse_identifier(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_identifier_t* id = (kcl_identifier_t*)calloc(1, sizeof(*id));
    const kcl_json_value_t* names = kcl_json_object_get(node, "names");
    id->names = parse_string_list(names, &id->names_count);
    const kcl_json_value_t* pp = kcl_json_object_get(node, "pkgpath");
    id->pkgpath = parse_string_list(pp, &id->pkgpath_count);
    return id;
}

static void free_identifier(kcl_identifier_t* id)
{
    if (id == NULL)
        return;
    free_string_list(id->names, id->names_count);
    free_string_list(id->pkgpath, id->pkgpath_count);
    free(id);
}

/* ---------------------------------------------------------------- *
 * Flat DTOs
 * ---------------------------------------------------------------- */

static kcl_target_t* parse_target(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_target_t* t = (kcl_target_t*)calloc(1, sizeof(*t));
    t->name = *parse_string_node(kcl_json_object_get(node, "name"));
    const kcl_json_value_t* pp = kcl_json_object_get(node, "pkgpath");
    t->pkgpath = json_to_string(pp);
    const kcl_json_value_t* paths = kcl_json_object_get(node, "paths");
    if (paths != NULL && paths->type == KCL_JSON_ARRAY) {
        size_t n = kcl_json_array_length(paths);
        if (n > 0) {
            t->paths = (kcl_member_or_index_t*)calloc(n, sizeof(kcl_member_or_index_t));
            t->paths_count = n;
            for (size_t i = 0; i < n; i++) {
                const kcl_json_value_t* p = kcl_json_array_get(paths, i);
                if (p == NULL || p->type != KCL_JSON_OBJECT)
                    continue;
                const kcl_json_value_t* inner = kcl_json_object_get(p, "node");
                const kcl_json_value_t* member = kcl_json_object_get(inner, "member");
                const kcl_json_value_t* index = kcl_json_object_get(inner, "index");
                if (member != NULL) {
                    t->paths[i].kind = KCL_MEMBER_OR_INDEX_MEMBER;
                    t->paths[i].member = *parse_string_node(member);
                } else if (index != NULL) {
                    t->paths[i].kind = KCL_MEMBER_OR_INDEX_INDEX;
                    t->paths[i].index = parse_expr_node(index);
                }
            }
        }
    }
    return t;
}

static void free_target(kcl_target_t* t)
{
    if (t == NULL)
        return;
    free_string_node(&t->name);
    free(t->pkgpath);
    for (size_t i = 0; i < t->paths_count; i++) {
        if (t->paths[i].kind == KCL_MEMBER_OR_INDEX_MEMBER)
            free_string_node(&t->paths[i].member);
        else if (t->paths[i].kind == KCL_MEMBER_OR_INDEX_INDEX) {
            free_pos(t->paths[i].index.pos);
            free(t->paths[i].index.id);
            if (t->paths[i].index.node != NULL)
                free_expr(t->paths[i].index.node);
        }
    }
    free(t->paths);
    free(t);
}

static kcl_arguments_t* parse_arguments(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_arguments_t* a = (kcl_arguments_t*)calloc(1, sizeof(*a));
    a->args = parse_expr_node_list(kcl_json_object_get(node, "args"));
    a->defaults = parse_expr_node_list(kcl_json_object_get(node, "defaults"));
    a->ty_list = parse_type_node_node_list(kcl_json_object_get(node, "ty_list"));
    return a;
}

static void free_arguments(kcl_arguments_t* a)
{
    if (a == NULL)
        return;
    free_expr_node_list(&a->args);
    free_expr_node_list(&a->defaults);
    free_type_node_node_list(&a->ty_list);
    free(a);
}

static kcl_decorator_t* parse_decorator(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_decorator_t* d = (kcl_decorator_t*)calloc(1, sizeof(*d));
    const kcl_json_value_t* func = kcl_json_object_get(node, "func");
    if (func != NULL) {
        d->func = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
        *d->func = parse_expr_node(func);
    }
    d->args = parse_expr_node_list(kcl_json_object_get(node, "args"));
    d->keywords = parse_keyword_node_list_alloc(kcl_json_object_get(node, "keywords"));
    return d;
}

static void free_decorator(kcl_decorator_t* d)
{
    if (d == NULL)
        return;
    if (d->func != NULL) {
        free_pos(d->func->pos);
        free(d->func->id);
        if (d->func->node != NULL)
            free_expr(d->func->node);
        free(d->func);
    }
    free_expr_node_list(&d->args);
    free_keyword_node_list(d->keywords);
    free(d);
}

static kcl_keyword_t* parse_keyword(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_keyword_t* kw = (kcl_keyword_t*)calloc(1, sizeof(*kw));
    const kcl_json_value_t* arg = kcl_json_object_get(node, "arg");
    if (arg != NULL) {
        kw->arg = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
        *kw->arg = parse_expr_node(arg);
    }
    kw->value = parse_expr_node(kcl_json_object_get(node, "value"));
    return kw;
}

static void free_keyword(kcl_keyword_t* kw)
{
    if (kw == NULL)
        return;
    if (kw->arg != NULL) {
        free_pos(kw->arg->pos);
        free(kw->arg->id);
        if (kw->arg->node != NULL)
            free_expr(kw->arg->node);
        free(kw->arg);
    }
    free_pos(kw->value.pos);
    free(kw->value.id);
    if (kw->value.node != NULL)
        free_expr(kw->value.node);
    free(kw);
}

static void free_keyword_node_list(kcl_keyword_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_keyword(list->items[i].node);
        free_pos(list->items[i].pos);
        free(list->items[i].id);
    }
    free(list->items);
    free(list);
}

static void free_decorator_node_list(kcl_decorator_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_decorator(list->items[i].node);
        free_pos(list->items[i].pos);
        free(list->items[i].id);
    }
    free(list->items);
    free(list);
}

static void free_check_expr_node_list(kcl_check_expr_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_check_expr(list->items[i].node);
        free_pos(list->items[i].pos);
        free(list->items[i].id);
    }
    free(list->items);
    free(list);
}

static void free_config_entry_node_list(kcl_config_entry_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_config_entry(list->items[i].node);
        free_pos(list->items[i].pos);
        free(list->items[i].id);
    }
    free(list->items);
    free(list);
}

static void free_comp_clause_node_list(kcl_comp_clause_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_comp_clause(list->items[i].node);
        free_pos(list->items[i].pos);
        free(list->items[i].id);
    }
    free(list->items);
    free(list);
}

static void free_quant_operation_node_list(kcl_quant_operation_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_quant_operation(list->items[i].node);
        free_pos(list->items[i].pos);
        free(list->items[i].id);
    }
    free(list->items);
    free(list);
}

static kcl_schema_config_t* parse_schema_config(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_schema_config_t* sc = (kcl_schema_config_t*)calloc(1, sizeof(*sc));
    const kcl_json_value_t* name = kcl_json_object_get(node, "name");
    if (name != NULL) {
        sc->name = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
        *sc->name = parse_expr_node(name);
    }
    sc->args = parse_expr_node_list(kcl_json_object_get(node, "args"));
    sc->kwargs = parse_keyword_node_list_alloc(kcl_json_object_get(node, "kwargs"));
    const kcl_json_value_t* config = kcl_json_object_get(node, "config");
    if (config != NULL) {
        sc->config = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
        *sc->config = parse_expr_node(config);
    }
    return sc;
}

static void free_schema_config(kcl_schema_config_t* sc)
{
    if (sc == NULL)
        return;
    if (sc->name != NULL) {
        free_pos(sc->name->pos);
        free(sc->name->id);
        if (sc->name->node != NULL)
            free_expr(sc->name->node);
        free(sc->name);
    }
    free_expr_node_list(&sc->args);
    free_keyword_node_list(sc->kwargs);
    if (sc->config != NULL) {
        free_pos(sc->config->pos);
        free(sc->config->id);
        if (sc->config->node != NULL)
            free_expr(sc->config->node);
        free(sc->config);
    }
    free(sc);
}

static kcl_config_entry_t* parse_config_entry(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_config_entry_t* ce = (kcl_config_entry_t*)calloc(1, sizeof(*ce));
    ce->key = parse_expr_node(kcl_json_object_get(node, "key"));
    ce->value = parse_expr_node(kcl_json_object_get(node, "value"));
    const kcl_json_value_t* op = kcl_json_object_get(node, "operation");
    ce->operation = json_to_string(op);
    const kcl_json_value_t* sh = kcl_json_object_get(node, "is_shorthand");
    ce->is_shorthand = (sh != NULL && sh->type == KCL_JSON_BOOL) ? sh->u.boolean : false;
    return ce;
}

static void free_config_entry(kcl_config_entry_t* ce)
{
    if (ce == NULL)
        return;
    free_pos(ce->key.pos);
    free(ce->key.id);
    if (ce->key.node != NULL)
        free_expr(ce->key.node);
    free_pos(ce->value.pos);
    free(ce->value.id);
    if (ce->value.node != NULL)
        free_expr(ce->value.node);
    free(ce->operation);
    free(ce);
}

static kcl_quant_operation_t* parse_quant_operation(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_quant_operation_t* q = (kcl_quant_operation_t*)calloc(1, sizeof(*q));
    q->target = parse_target_node(kcl_json_object_get(node, "target"));
    const kcl_json_value_t* op = kcl_json_object_get(node, "op");
    q->op = json_to_string(op);
    return q;
}

static void free_quant_operation(kcl_quant_operation_t* q)
{
    if (q == NULL)
        return;
    free_pos(q->target.pos);
    free(q->target.id);
    if (q->target.node != NULL)
        free_target(q->target.node);
    free(q->op);
    free(q);
}

static kcl_comp_clause_t* parse_comp_clause(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_comp_clause_t* cc = (kcl_comp_clause_t*)calloc(1, sizeof(*cc));
    cc->targets = parse_target_node_list(kcl_json_object_get(node, "targets"));
    cc->iter = parse_expr_node(kcl_json_object_get(node, "iter"));
    cc->ifs = parse_expr_node_list(kcl_json_object_get(node, "ifs"));
    return cc;
}

static void free_comp_clause(kcl_comp_clause_t* cc)
{
    if (cc == NULL)
        return;
    free_target_node_list(&cc->targets);
    free_pos(cc->iter.pos);
    free(cc->iter.id);
    if (cc->iter.node != NULL)
        free_expr(cc->iter.node);
    free_expr_node_list(&cc->ifs);
    free(cc);
}

static kcl_check_expr_t* parse_check_expr(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_check_expr_t* ce = (kcl_check_expr_t*)calloc(1, sizeof(*ce));
    ce->test = parse_expr_node(kcl_json_object_get(node, "test"));
    const kcl_json_value_t* ic = kcl_json_object_get(node, "if_cond");
    if (ic != NULL) {
        ce->if_cond = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
        *ce->if_cond = parse_expr_node(ic);
    }
    const kcl_json_value_t* msg = kcl_json_object_get(node, "msg");
    if (msg != NULL)
        ce->msg = parse_string_node(msg);
    return ce;
}

static void free_check_expr(kcl_check_expr_t* ce)
{
    if (ce == NULL)
        return;
    free_pos(ce->test.pos);
    free(ce->test.id);
    if (ce->test.node != NULL)
        free_expr(ce->test.node);
    if (ce->if_cond != NULL) {
        free_pos(ce->if_cond->pos);
        free(ce->if_cond->id);
        if (ce->if_cond->node != NULL)
            free_expr(ce->if_cond->node);
        free(ce->if_cond);
    }
    free_string_node(ce->msg);
    free(ce);
}

static kcl_schema_index_signature_t* parse_schema_index_signature(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    kcl_schema_index_signature_t* sis = (kcl_schema_index_signature_t*)calloc(1, sizeof(*sis));
    sis->key_type = parse_type_node_node(kcl_json_object_get(node, "key_type"));
    sis->value_type = parse_type_node_node(kcl_json_object_get(node, "value_type"));
    return sis;
}

static void free_schema_index_signature(kcl_schema_index_signature_t* sis)
{
    if (sis == NULL)
        return;
    free_type_node_node(&sis->key_type);
    free_type_node_node(&sis->value_type);
    free(sis);
}

/* ---------------------------------------------------------------- *
 * Stmt dispatch
 * ---------------------------------------------------------------- */

static kcl_stmt_kind_t stmt_kind_from_tag(const char* tag)
{
    if (tag == NULL) return KCL_STMT_KIND_UNKNOWN;
    if (strcmp(tag, "Expr") == 0) return KCL_STMT_KIND_EXPR;
    if (strcmp(tag, "Unification") == 0) return KCL_STMT_KIND_UNIFICATION;
    if (strcmp(tag, "Assign") == 0) return KCL_STMT_KIND_ASSIGN;
    if (strcmp(tag, "Schema") == 0) return KCL_STMT_KIND_SCHEMA;
    if (strcmp(tag, "SchemaAttr") == 0) return KCL_STMT_KIND_SCHEMA_ATTR;
    if (strcmp(tag, "Rule") == 0) return KCL_STMT_KIND_RULE;
    if (strcmp(tag, "Import") == 0) return KCL_STMT_KIND_IMPORT;
    if (strcmp(tag, "TypeAlias") == 0) return KCL_STMT_KIND_TYPE_ALIAS;
    if (strcmp(tag, "Assert") == 0) return KCL_STMT_KIND_ASSERT;
    if (strcmp(tag, "If") == 0) return KCL_STMT_KIND_IF;
    return KCL_STMT_KIND_UNKNOWN;
}

static kcl_stmt_t* parse_stmt(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    const kcl_json_value_t* tag = kcl_json_object_get(node, "type");
    kcl_stmt_t* s = (kcl_stmt_t*)calloc(1, sizeof(*s));
    s->type_tag = json_to_string(tag);
    s->kind = stmt_kind_from_tag(s->type_tag);
    switch (s->kind) {
    case KCL_STMT_KIND_EXPR:
        s->u.expr_stmt.exprs = parse_expr_node_list(kcl_json_object_get(node, "exprs"));
        break;
    case KCL_STMT_KIND_UNIFICATION: {
        s->u.unification_stmt.target = parse_target_node(kcl_json_object_get(node, "target"));
        s->u.unification_stmt.value = parse_schema_config(kcl_json_object_get(node, "value"));
        break;
    }
    case KCL_STMT_KIND_ASSIGN: {
        s->u.assign_stmt.targets = parse_target_node_list(kcl_json_object_get(node, "targets"));
        const kcl_json_value_t* ty = kcl_json_object_get(node, "ty");
        if (ty != NULL) {
            s->u.assign_stmt.ty = (kcl_type_node_node_t*)calloc(1, sizeof(kcl_type_node_node_t));
            *s->u.assign_stmt.ty = parse_type_node_node(ty);
        }
        s->u.assign_stmt.value = parse_expr_node(kcl_json_object_get(node, "value"));
        break;
    }
    case KCL_STMT_KIND_SCHEMA: {
        const kcl_json_value_t* doc = kcl_json_object_get(node, "doc");
        if (doc != NULL)
            s->u.schema_stmt.doc = parse_string_node(doc);
        s->u.schema_stmt.name = *parse_string_node(kcl_json_object_get(node, "name"));
        const kcl_json_value_t* pn = kcl_json_object_get(node, "parent_name");
        if (pn != NULL) {
            s->u.schema_stmt.parent_name = (kcl_identifier_node_t*)calloc(1, sizeof(kcl_identifier_node_t));
            *s->u.schema_stmt.parent_name = parse_identifier_node(pn);
        }
        const kcl_json_value_t* fhn = kcl_json_object_get(node, "for_host_name");
        if (fhn != NULL) {
            s->u.schema_stmt.for_host_name = (kcl_identifier_node_t*)calloc(1, sizeof(kcl_identifier_node_t));
            *s->u.schema_stmt.for_host_name = parse_identifier_node(fhn);
        }
        const kcl_json_value_t* mixin = kcl_json_object_get(node, "is_mixin");
        s->u.schema_stmt.is_mixin = (mixin != NULL && mixin->type == KCL_JSON_BOOL) ? mixin->u.boolean : false;
        const kcl_json_value_t* proto = kcl_json_object_get(node, "is_protocol");
        s->u.schema_stmt.is_protocol = (proto != NULL && proto->type == KCL_JSON_BOOL) ? proto->u.boolean : false;
        const kcl_json_value_t* args = kcl_json_object_get(node, "args");
        if (args != NULL) {
            s->u.schema_stmt.args = (kcl_arguments_node_t*)calloc(1, sizeof(kcl_arguments_node_t));
            *s->u.schema_stmt.args = parse_arguments_node(args);
        }
        s->u.schema_stmt.mixins = parse_identifier_node_list(kcl_json_object_get(node, "mixins"));
        s->u.schema_stmt.body = parse_stmt_node_list(kcl_json_object_get(node, "body"));
        s->u.schema_stmt.decorators = parse_decorator_node_list_alloc(kcl_json_object_get(node, "decorators"));
        s->u.schema_stmt.checks = parse_check_expr_node_list_alloc(kcl_json_object_get(node, "checks"));
        const kcl_json_value_t* sis = kcl_json_object_get(node, "index_signature");
        if (sis != NULL) {
            s->u.schema_stmt.index_signature = (kcl_schema_index_signature_node_t*)calloc(1, sizeof(kcl_schema_index_signature_node_t));
            *s->u.schema_stmt.index_signature = parse_schema_index_signature_node(sis);
        }
        break;
    }
    case KCL_STMT_KIND_SCHEMA_ATTR: {
        const kcl_json_value_t* doc = kcl_json_object_get(node, "doc");
        s->u.schema_attr.doc = json_to_string(doc);
        s->u.schema_attr.name = *parse_string_node(kcl_json_object_get(node, "name"));
        const kcl_json_value_t* op = kcl_json_object_get(node, "op");
        s->u.schema_attr.op = json_to_string(op);
        const kcl_json_value_t* val = kcl_json_object_get(node, "value");
        if (val != NULL) {
            s->u.schema_attr.value = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
            *s->u.schema_attr.value = parse_expr_node(val);
        }
        const kcl_json_value_t* opt = kcl_json_object_get(node, "is_optional");
        s->u.schema_attr.is_optional = (opt != NULL && opt->type == KCL_JSON_BOOL) ? opt->u.boolean : false;
        s->u.schema_attr.decorators = parse_decorator_node_list_alloc(kcl_json_object_get(node, "decorators"));
        const kcl_json_value_t* ty = kcl_json_object_get(node, "ty");
        if (ty != NULL) {
            s->u.schema_attr.ty = (kcl_type_node_node_t*)calloc(1, sizeof(kcl_type_node_node_t));
            *s->u.schema_attr.ty = parse_type_node_node(ty);
        }
        break;
    }
    case KCL_STMT_KIND_RULE: {
        const kcl_json_value_t* doc = kcl_json_object_get(node, "doc");
        if (doc != NULL)
            s->u.rule_stmt.doc = parse_string_node(doc);
        s->u.rule_stmt.name = *parse_string_node(kcl_json_object_get(node, "name"));
        s->u.rule_stmt.parent_rules = parse_identifier_node_list(kcl_json_object_get(node, "parent_rules"));
        s->u.rule_stmt.decorators = parse_decorator_node_list_alloc(kcl_json_object_get(node, "decorators"));
        s->u.rule_stmt.checks = parse_check_expr_node_list_alloc(kcl_json_object_get(node, "checks"));
        const kcl_json_value_t* args = kcl_json_object_get(node, "args");
        if (args != NULL) {
            s->u.rule_stmt.args = (kcl_arguments_node_t*)calloc(1, sizeof(kcl_arguments_node_t));
            *s->u.rule_stmt.args = parse_arguments_node(args);
        }
        const kcl_json_value_t* fhn = kcl_json_object_get(node, "for_host_name");
        if (fhn != NULL) {
            s->u.rule_stmt.for_host_name = (kcl_identifier_node_t*)calloc(1, sizeof(kcl_identifier_node_t));
            *s->u.rule_stmt.for_host_name = parse_identifier_node(fhn);
        }
        break;
    }
    case KCL_STMT_KIND_IMPORT:
        s->u.import_stmt.path = json_to_string(kcl_json_object_get(node, "path"));
        s->u.import_stmt.as_name = json_to_string(kcl_json_object_get(node, "asname"));
        s->u.import_stmt.pkg_name = json_to_string(kcl_json_object_get(node, "pkg_name"));
        s->u.import_stmt.pkg_root = json_to_string(kcl_json_object_get(node, "pkg_root"));
        break;
    case KCL_STMT_KIND_TYPE_ALIAS:
        s->u.type_alias_stmt.name = *parse_string_node(kcl_json_object_get(node, "name"));
        s->u.type_alias_stmt.ty = parse_type_node_node(kcl_json_object_get(node, "ty"));
        break;
    case KCL_STMT_KIND_ASSERT:
        s->u.assert_stmt.source = parse_expr_node(kcl_json_object_get(node, "source"));
        {
            const kcl_json_value_t* m = kcl_json_object_get(node, "assert_msg");
            if (m != NULL)
                s->u.assert_stmt.assert_msg = parse_string_node(m);
        }
        break;
    case KCL_STMT_KIND_IF:
        s->u.if_stmt.cond = parse_expr_node(kcl_json_object_get(node, "cond"));
        s->u.if_stmt.body = parse_stmt_node_list(kcl_json_object_get(node, "body"));
        {
            const kcl_json_value_t* oe = kcl_json_object_get(node, "or_else");
            if (oe != NULL) {
                s->u.if_stmt.or_else = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
                *s->u.if_stmt.or_else = parse_expr_node(oe);
            }
        }
        break;
    default:
        break;
    }
    return s;
}

void free_stmt(kcl_stmt_t* s)
{
    if (s == NULL)
        return;
    free(s->type_tag);
    switch (s->kind) {
    case KCL_STMT_KIND_EXPR:
        free_expr_node_list(&s->u.expr_stmt.exprs);
        break;
    case KCL_STMT_KIND_UNIFICATION:
        free_target((kcl_target_t*)s->u.unification_stmt.target.node);
        free_pos(s->u.unification_stmt.target.pos);
        free(s->u.unification_stmt.target.id);
        free_schema_config((kcl_schema_config_t*)s->u.unification_stmt.value);
        break;
    case KCL_STMT_KIND_ASSIGN:
        free_target_node_list(&s->u.assign_stmt.targets);
        if (s->u.assign_stmt.ty != NULL) {
            free_type_node_node(s->u.assign_stmt.ty);
            free(s->u.assign_stmt.ty);
        }
        free_pos(s->u.assign_stmt.value.pos);
        free(s->u.assign_stmt.value.id);
        if (s->u.assign_stmt.value.node != NULL)
            free_expr(s->u.assign_stmt.value.node);
        break;
    case KCL_STMT_KIND_SCHEMA: {
        free_string_node(s->u.schema_stmt.doc);
        free_string_node(&s->u.schema_stmt.name);
        if (s->u.schema_stmt.parent_name != NULL) {
            free_identifier((kcl_identifier_t*)s->u.schema_stmt.parent_name->node);
            free_pos(s->u.schema_stmt.parent_name->pos);
            free(s->u.schema_stmt.parent_name->id);
            free(s->u.schema_stmt.parent_name);
        }
        if (s->u.schema_stmt.for_host_name != NULL) {
            free_identifier((kcl_identifier_t*)s->u.schema_stmt.for_host_name->node);
            free_pos(s->u.schema_stmt.for_host_name->pos);
            free(s->u.schema_stmt.for_host_name->id);
            free(s->u.schema_stmt.for_host_name);
        }
        if (s->u.schema_stmt.args != NULL) {
            free_arguments((kcl_arguments_t*)s->u.schema_stmt.args->node);
            free_pos(s->u.schema_stmt.args->pos);
            free(s->u.schema_stmt.args->id);
            free(s->u.schema_stmt.args);
        }
        free_identifier_node_list(&s->u.schema_stmt.mixins);
        free_stmt_node_list(&s->u.schema_stmt.body);
        free_decorator_node_list((kcl_decorator_node_list_t*)s->u.schema_stmt.decorators);
        free_check_expr_node_list((kcl_check_expr_node_list_t*)s->u.schema_stmt.checks);
        if (s->u.schema_stmt.index_signature != NULL) {
            free_schema_index_signature((kcl_schema_index_signature_t*)s->u.schema_stmt.index_signature->node);
            free_pos(s->u.schema_stmt.index_signature->pos);
            free(s->u.schema_stmt.index_signature->id);
            free(s->u.schema_stmt.index_signature);
        }
        break;
    }
    case KCL_STMT_KIND_SCHEMA_ATTR:
        free(s->u.schema_attr.doc);
        free_string_node(&s->u.schema_attr.name);
        free(s->u.schema_attr.op);
        if (s->u.schema_attr.value != NULL) {
            free_pos(s->u.schema_attr.value->pos);
            free(s->u.schema_attr.value->id);
            if (s->u.schema_attr.value->node != NULL)
                free_expr(s->u.schema_attr.value->node);
            free(s->u.schema_attr.value);
        }
        free_decorator_node_list((kcl_decorator_node_list_t*)s->u.schema_attr.decorators);
        if (s->u.schema_attr.ty != NULL) {
            free_type_node_node(s->u.schema_attr.ty);
            free(s->u.schema_attr.ty);
        }
        break;
    case KCL_STMT_KIND_RULE: {
        free_string_node(s->u.rule_stmt.doc);
        free_string_node(&s->u.rule_stmt.name);
        free_identifier_node_list(&s->u.rule_stmt.parent_rules);
        free_decorator_node_list((kcl_decorator_node_list_t*)s->u.rule_stmt.decorators);
        free_check_expr_node_list((kcl_check_expr_node_list_t*)s->u.rule_stmt.checks);
        if (s->u.rule_stmt.args != NULL) {
            free_arguments((kcl_arguments_t*)s->u.rule_stmt.args->node);
            free_pos(s->u.rule_stmt.args->pos);
            free(s->u.rule_stmt.args->id);
            free(s->u.rule_stmt.args);
        }
        if (s->u.rule_stmt.for_host_name != NULL) {
            free_identifier((kcl_identifier_t*)s->u.rule_stmt.for_host_name->node);
            free_pos(s->u.rule_stmt.for_host_name->pos);
            free(s->u.rule_stmt.for_host_name->id);
            free(s->u.rule_stmt.for_host_name);
        }
        break;
    }
    case KCL_STMT_KIND_IMPORT:
        free(s->u.import_stmt.path);
        free(s->u.import_stmt.as_name);
        free(s->u.import_stmt.pkg_name);
        free(s->u.import_stmt.pkg_root);
        break;
    case KCL_STMT_KIND_TYPE_ALIAS:
        free_string_node(&s->u.type_alias_stmt.name);
        free_type_node_node(&s->u.type_alias_stmt.ty);
        break;
    case KCL_STMT_KIND_ASSERT:
        free_pos(s->u.assert_stmt.source.pos);
        free(s->u.assert_stmt.source.id);
        if (s->u.assert_stmt.source.node != NULL)
            free_expr(s->u.assert_stmt.source.node);
        free_string_node(s->u.assert_stmt.assert_msg);
        break;
    case KCL_STMT_KIND_IF:
        free_pos(s->u.if_stmt.cond.pos);
        free(s->u.if_stmt.cond.id);
        if (s->u.if_stmt.cond.node != NULL)
            free_expr(s->u.if_stmt.cond.node);
        free_stmt_node_list(&s->u.if_stmt.body);
        if (s->u.if_stmt.or_else != NULL) {
            free_pos(s->u.if_stmt.or_else->pos);
            free(s->u.if_stmt.or_else->id);
            if (s->u.if_stmt.or_else->node != NULL)
                free_expr(s->u.if_stmt.or_else->node);
            free(s->u.if_stmt.or_else);
        }
        break;
    default:
        break;
    }
    free(s);
}

void free_stmt_node_list(kcl_stmt_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_stmt((kcl_stmt_t*)list->items[i].node);
        free_pos(list->items[i].pos);
        free(list->items[i].id);
    }
    free(list->items);
}

/* ---------------------------------------------------------------- *
 * Expr dispatch
 * ---------------------------------------------------------------- */

static kcl_expr_kind_t expr_kind_from_tag(const char* tag)
{
    if (tag == NULL) return KCL_EXPR_KIND_UNKNOWN;
    if (strcmp(tag, "Target") == 0) return KCL_EXPR_KIND_TARGET;
    if (strcmp(tag, "Identifier") == 0) return KCL_EXPR_KIND_IDENTIFIER;
    if (strcmp(tag, "Unary") == 0) return KCL_EXPR_KIND_UNARY;
    if (strcmp(tag, "Binary") == 0) return KCL_EXPR_KIND_BINARY;
    if (strcmp(tag, "If") == 0) return KCL_EXPR_KIND_IF;
    if (strcmp(tag, "Selector") == 0) return KCL_EXPR_KIND_SELECTOR;
    if (strcmp(tag, "Call") == 0) return KCL_EXPR_KIND_CALL;
    if (strcmp(tag, "Paren") == 0) return KCL_EXPR_KIND_PAREN;
    if (strcmp(tag, "Quant") == 0) return KCL_EXPR_KIND_QUANT;
    if (strcmp(tag, "List") == 0) return KCL_EXPR_KIND_LIST;
    if (strcmp(tag, "ListIfItem") == 0) return KCL_EXPR_KIND_LIST_IF_ITEM;
    if (strcmp(tag, "ListComp") == 0) return KCL_EXPR_KIND_LIST_COMP;
    if (strcmp(tag, "Starred") == 0) return KCL_EXPR_KIND_STARRED;
    if (strcmp(tag, "DictComp") == 0) return KCL_EXPR_KIND_DICT_COMP;
    if (strcmp(tag, "ConfigIfEntry") == 0) return KCL_EXPR_KIND_CONFIG_IF_ENTRY;
    if (strcmp(tag, "CompClause") == 0) return KCL_EXPR_KIND_COMP_CLAUSE;
    if (strcmp(tag, "Schema") == 0) return KCL_EXPR_KIND_SCHEMA;
    if (strcmp(tag, "Config") == 0) return KCL_EXPR_KIND_CONFIG;
    if (strcmp(tag, "Lambda") == 0) return KCL_EXPR_KIND_LAMBDA;
    if (strcmp(tag, "Subscript") == 0) return KCL_EXPR_KIND_SUBSCRIPT;
    if (strcmp(tag, "Compare") == 0) return KCL_EXPR_KIND_COMPARE;
    if (strcmp(tag, "NumberLit") == 0) return KCL_EXPR_KIND_NUMBER_LIT;
    if (strcmp(tag, "StringLit") == 0) return KCL_EXPR_KIND_STRING_LIT;
    if (strcmp(tag, "NameConstantLit") == 0) return KCL_EXPR_KIND_NAME_CONSTANT_LIT;
    if (strcmp(tag, "JoinedString") == 0) return KCL_EXPR_KIND_JOINED_STRING;
    if (strcmp(tag, "FormattedValue") == 0) return KCL_EXPR_KIND_FORMATTED_VALUE;
    if (strcmp(tag, "Missing") == 0) return KCL_EXPR_KIND_MISSING;
    if (strcmp(tag, "Check") == 0) return KCL_EXPR_KIND_CHECK;
    return KCL_EXPR_KIND_UNKNOWN;
}

static kcl_expr_t* parse_expr(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    const kcl_json_value_t* tag = kcl_json_object_get(node, "type");
    kcl_expr_t* e = (kcl_expr_t*)calloc(1, sizeof(*e));
    e->type_tag = json_to_string(tag);
    e->kind = expr_kind_from_tag(e->type_tag);
    switch (e->kind) {
    case KCL_EXPR_KIND_TARGET:
        e->u.target_expr.name = *parse_string_node(kcl_json_object_get(node, "name"));
        break;
    case KCL_EXPR_KIND_IDENTIFIER:
        e->u.identifier_expr.names = parse_string_node_list(kcl_json_object_get(node, "names"));
        e->u.identifier_expr.pkgpath = parse_string_list(kcl_json_object_get(node, "pkgpath"), &e->u.identifier_expr.pkgpath_count);
        break;
    case KCL_EXPR_KIND_UNARY:
        e->u.unary_expr.op = json_to_string(kcl_json_object_get(node, "op"));
        e->u.unary_expr.operand = parse_expr_node(kcl_json_object_get(node, "operand"));
        break;
    case KCL_EXPR_KIND_BINARY:
        e->u.binary_expr.op = json_to_string(kcl_json_object_get(node, "op"));
        e->u.binary_expr.left = parse_expr_node(kcl_json_object_get(node, "left"));
        e->u.binary_expr.right = parse_expr_node(kcl_json_object_get(node, "right"));
        break;
    case KCL_EXPR_KIND_IF:
        e->u.if_expr.cond = parse_expr_node(kcl_json_object_get(node, "cond"));
        e->u.if_expr.body = parse_expr_node(kcl_json_object_get(node, "body"));
        {
            const kcl_json_value_t* oe = kcl_json_object_get(node, "or_else");
            if (oe != NULL) {
                e->u.if_expr.or_else = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
                *e->u.if_expr.or_else = parse_expr_node(oe);
            }
        }
        break;
    case KCL_EXPR_KIND_SELECTOR:
        e->u.selector_expr.value = parse_expr_node(kcl_json_object_get(node, "value"));
        e->u.selector_expr.attr_name = *parse_string_node(kcl_json_object_get(node, "attr_name"));
        break;
    case KCL_EXPR_KIND_CALL:
        e->u.call_expr.func = parse_expr_node(kcl_json_object_get(node, "func"));
        e->u.call_expr.args = parse_expr_node_list(kcl_json_object_get(node, "args"));
        e->u.call_expr.keywords = parse_keyword_node_list_alloc(kcl_json_object_get(node, "keywords"));
        break;
    case KCL_EXPR_KIND_PAREN:
        e->u.paren_expr.expr = parse_expr_node(kcl_json_object_get(node, "expr"));
        break;
    case KCL_EXPR_KIND_QUANT:
        e->u.quant_expr.target = parse_target_node(kcl_json_object_get(node, "target"));
        e->u.quant_expr.variables = parse_quant_operation_node_list_alloc(kcl_json_object_get(node, "variables"));
        {
            const kcl_json_value_t* op = kcl_json_object_get(node, "op");
            if (op != NULL) {
                e->u.quant_expr.op = parse_quant_operation(op);
            }
        }
        e->u.quant_expr.cond = parse_expr_node(kcl_json_object_get(node, "cond"));
        break;
    case KCL_EXPR_KIND_LIST:
        e->u.list_expr.elts = parse_expr_node_list(kcl_json_object_get(node, "elts"));
        break;
    case KCL_EXPR_KIND_LIST_IF_ITEM: {
        const kcl_json_value_t* ife = kcl_json_object_get(node, "if_expr");
        const kcl_json_value_t* expr = kcl_json_object_get(node, "expr");
        /* Wire shape may carry either `if_expr` or `expr` — both are
         * `NodeRef<Expr>` pointing at the same conditional. */
        const kcl_json_value_t* picked = ife != NULL ? ife : expr;
        e->u.list_if_item_expr.if_expr = parse_expr_node(picked);
        const kcl_json_value_t* oe = kcl_json_object_get(node, "or_else");
        if (oe != NULL) {
            e->u.list_if_item_expr.or_else = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
            *e->u.list_if_item_expr.or_else = parse_expr_node(oe);
        }
        break;
    }
    case KCL_EXPR_KIND_LIST_COMP:
        e->u.list_comp.elt = parse_expr_node(kcl_json_object_get(node, "elt"));
        e->u.list_comp.generators = parse_comp_clause_node_list_alloc(kcl_json_object_get(node, "generators"));
        {
            const kcl_json_value_t* c = kcl_json_object_get(node, "cond");
            if (c != NULL) {
                e->u.list_comp.cond = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
                *e->u.list_comp.cond = parse_expr_node(c);
            }
        }
        break;
    case KCL_EXPR_KIND_STARRED:
        e->u.starred_expr.value = parse_expr_node(kcl_json_object_get(node, "value"));
        e->u.starred_expr.ctx = json_to_string(kcl_json_object_get(node, "ctx"));
        break;
    case KCL_EXPR_KIND_DICT_COMP:
        e->u.dict_comp.key = parse_expr_node(kcl_json_object_get(node, "key"));
        e->u.dict_comp.value = parse_expr_node(kcl_json_object_get(node, "value"));
        e->u.dict_comp.generators = parse_comp_clause_node_list_alloc(kcl_json_object_get(node, "generators"));
        {
            const kcl_json_value_t* c = kcl_json_object_get(node, "cond");
            if (c != NULL) {
                e->u.dict_comp.cond = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
                *e->u.dict_comp.cond = parse_expr_node(c);
            }
        }
        break;
    case KCL_EXPR_KIND_CONFIG_IF_ENTRY: {
        const kcl_json_value_t* ife = kcl_json_object_get(node, "if_expr");
        const kcl_json_value_t* expr = kcl_json_object_get(node, "expr");
        const kcl_json_value_t* picked = ife != NULL ? ife : expr;
        e->u.config_if_entry_expr.if_expr = parse_expr_node(picked);
        break;
    }
    case KCL_EXPR_KIND_COMP_CLAUSE:
        /* Usually nested in ListComp / DictComp, but exposed standalone. */
        e->u.comp_clause.targets = parse_target_node_list(kcl_json_object_get(node, "targets"));
        e->u.comp_clause.iter = parse_expr_node(kcl_json_object_get(node, "iter"));
        e->u.comp_clause.ifs = parse_expr_node_list(kcl_json_object_get(node, "ifs"));
        break;
    case KCL_EXPR_KIND_SCHEMA:
        e->u.schema_expr.name = parse_expr_node(kcl_json_object_get(node, "name"));
        e->u.schema_expr.args = parse_expr_node_list(kcl_json_object_get(node, "args"));
        e->u.schema_expr.kwargs = parse_keyword_node_list_alloc(kcl_json_object_get(node, "kwargs"));
        e->u.schema_expr.config = parse_expr_node(kcl_json_object_get(node, "config"));
        break;
    case KCL_EXPR_KIND_CONFIG:
        e->u.config_expr.items = parse_config_entry_node_list_alloc(kcl_json_object_get(node, "items"));
        break;
    case KCL_EXPR_KIND_LAMBDA:
        e->u.lambda_expr.args = parse_arguments_node(kcl_json_object_get(node, "args"));
        e->u.lambda_expr.body = parse_stmt_node_list(kcl_json_object_get(node, "body"));
        {
            const kcl_json_value_t* rt = kcl_json_object_get(node, "return_ty");
            if (rt != NULL) {
                e->u.lambda_expr.return_ty = (kcl_type_node_node_t*)calloc(1, sizeof(kcl_type_node_node_t));
                *e->u.lambda_expr.return_ty = parse_type_node_node(rt);
            }
        }
        break;
    case KCL_EXPR_KIND_SUBSCRIPT:
        e->u.subscript_expr.value = parse_expr_node(kcl_json_object_get(node, "value"));
        e->u.subscript_expr.index = parse_expr_node(kcl_json_object_get(node, "index"));
        break;
    case KCL_EXPR_KIND_COMPARE: {
        e->u.compare_expr.left = parse_expr_node(kcl_json_object_get(node, "left"));
        e->u.compare_expr.ops = parse_string_list(kcl_json_object_get(node, "ops"), &e->u.compare_expr.ops_count);
        e->u.compare_expr.comparators = parse_expr_node_list(kcl_json_object_get(node, "comparators"));
        break;
    }
    case KCL_EXPR_KIND_NUMBER_LIT: {
        const kcl_json_value_t* bs = kcl_json_object_get(node, "binary_suffix");
        e->u.number_lit.binary_suffix = json_to_string(bs);
        const kcl_json_value_t* val = kcl_json_object_get(node, "value");
        if (val != NULL) {
            e->u.number_lit.value.raw_value = json_to_string(kcl_json_object_get(val, "raw_value"));
            const kcl_json_value_t* nv = kcl_json_object_get(val, "value");
            e->u.number_lit.value.value = (nv != NULL && nv->type == KCL_JSON_NUMBER) ? nv->u.number : 0.0;
            e->u.number_lit.value.binary_suffix = json_to_string(kcl_json_object_get(val, "binary_suffix"));
        }
        break;
    }
    case KCL_EXPR_KIND_STRING_LIT:
        e->u.string_lit.is_long_string = false;
        {
            const kcl_json_value_t* ls = kcl_json_object_get(node, "is_long_string");
            if (ls != NULL && ls->type == KCL_JSON_BOOL)
                e->u.string_lit.is_long_string = ls->u.boolean;
        }
        e->u.string_lit.raw_value = json_to_string(kcl_json_object_get(node, "raw_value"));
        e->u.string_lit.value = json_to_string(kcl_json_object_get(node, "value"));
        break;
    case KCL_EXPR_KIND_NAME_CONSTANT_LIT:
        e->u.name_constant_lit.value = json_to_string(kcl_json_object_get(node, "value"));
        break;
    case KCL_EXPR_KIND_JOINED_STRING:
        e->u.joined_string.values = parse_expr_node_list(kcl_json_object_get(node, "values"));
        {
            const kcl_json_value_t* ls = kcl_json_object_get(node, "is_long_string");
            if (ls != NULL && ls->type == KCL_JSON_BOOL)
                e->u.joined_string.is_long_string = ls->u.boolean;
        }
        e->u.joined_string.raw_value = json_to_string(kcl_json_object_get(node, "raw_value"));
        break;
    case KCL_EXPR_KIND_FORMATTED_VALUE:
        e->u.formatted_value.value = parse_expr_node(kcl_json_object_get(node, "value"));
        e->u.formatted_value.spec = json_to_string(kcl_json_object_get(node, "spec"));
        break;
    case KCL_EXPR_KIND_MISSING:
        break;
    case KCL_EXPR_KIND_CHECK:
        e->u.check_expr.test = parse_expr_node(kcl_json_object_get(node, "test"));
        {
            const kcl_json_value_t* ic = kcl_json_object_get(node, "if_cond");
            if (ic != NULL) {
                e->u.check_expr.if_cond = (kcl_expr_node_t*)calloc(1, sizeof(kcl_expr_node_t));
                *e->u.check_expr.if_cond = parse_expr_node(ic);
            }
            const kcl_json_value_t* m = kcl_json_object_get(node, "msg");
            if (m != NULL)
                e->u.check_expr.msg = parse_string_node(m);
        }
        break;
    default:
        break;
    }
    return e;
}

void free_expr(kcl_expr_t* e)
{
    if (e == NULL)
        return;
    free(e->type_tag);
    switch (e->kind) {
    case KCL_EXPR_KIND_TARGET:
        free_string_node(&e->u.target_expr.name);
        break;
    case KCL_EXPR_KIND_IDENTIFIER:
        free_string_node_list(&e->u.identifier_expr.names);
        free_string_list(e->u.identifier_expr.pkgpath, e->u.identifier_expr.pkgpath_count);
        break;
    case KCL_EXPR_KIND_UNARY:
        free(e->u.unary_expr.op);
        free_pos(e->u.unary_expr.operand.pos);
        free(e->u.unary_expr.operand.id);
        if (e->u.unary_expr.operand.node != NULL)
            free_expr(e->u.unary_expr.operand.node);
        break;
    case KCL_EXPR_KIND_BINARY:
        free(e->u.binary_expr.op);
        free_pos(e->u.binary_expr.left.pos);
        free(e->u.binary_expr.left.id);
        if (e->u.binary_expr.left.node != NULL)
            free_expr(e->u.binary_expr.left.node);
        free_pos(e->u.binary_expr.right.pos);
        free(e->u.binary_expr.right.id);
        if (e->u.binary_expr.right.node != NULL)
            free_expr(e->u.binary_expr.right.node);
        break;
    case KCL_EXPR_KIND_IF:
        free_pos(e->u.if_expr.cond.pos);
        free(e->u.if_expr.cond.id);
        if (e->u.if_expr.cond.node != NULL)
            free_expr(e->u.if_expr.cond.node);
        free_pos(e->u.if_expr.body.pos);
        free(e->u.if_expr.body.id);
        if (e->u.if_expr.body.node != NULL)
            free_expr(e->u.if_expr.body.node);
        if (e->u.if_expr.or_else != NULL) {
            free_pos(e->u.if_expr.or_else->pos);
            free(e->u.if_expr.or_else->id);
            if (e->u.if_expr.or_else->node != NULL)
                free_expr(e->u.if_expr.or_else->node);
            free(e->u.if_expr.or_else);
        }
        break;
    case KCL_EXPR_KIND_SELECTOR:
        free_pos(e->u.selector_expr.value.pos);
        free(e->u.selector_expr.value.id);
        if (e->u.selector_expr.value.node != NULL)
            free_expr(e->u.selector_expr.value.node);
        free_string_node(&e->u.selector_expr.attr_name);
        break;
    case KCL_EXPR_KIND_CALL:
        free_pos(e->u.call_expr.func.pos);
        free(e->u.call_expr.func.id);
        if (e->u.call_expr.func.node != NULL)
            free_expr(e->u.call_expr.func.node);
        free_expr_node_list(&e->u.call_expr.args);
        free_keyword_node_list((kcl_keyword_node_list_t*)e->u.call_expr.keywords);
        break;
    case KCL_EXPR_KIND_PAREN:
        free_pos(e->u.paren_expr.expr.pos);
        free(e->u.paren_expr.expr.id);
        if (e->u.paren_expr.expr.node != NULL)
            free_expr(e->u.paren_expr.expr.node);
        break;
    case KCL_EXPR_KIND_QUANT:
        free_target((kcl_target_t*)e->u.quant_expr.target.node);
        free_pos(e->u.quant_expr.target.pos);
        free(e->u.quant_expr.target.id);
        free_quant_operation_node_list((kcl_quant_operation_node_list_t*)e->u.quant_expr.variables);
        free_quant_operation((kcl_quant_operation_t*)e->u.quant_expr.op);
        free_pos(e->u.quant_expr.cond.pos);
        free(e->u.quant_expr.cond.id);
        if (e->u.quant_expr.cond.node != NULL)
            free_expr(e->u.quant_expr.cond.node);
        break;
    case KCL_EXPR_KIND_LIST:
        free_expr_node_list(&e->u.list_expr.elts);
        break;
    case KCL_EXPR_KIND_LIST_IF_ITEM:
        free_pos(e->u.list_if_item_expr.if_expr.pos);
        free(e->u.list_if_item_expr.if_expr.id);
        if (e->u.list_if_item_expr.if_expr.node != NULL)
            free_expr(e->u.list_if_item_expr.if_expr.node);
        if (e->u.list_if_item_expr.or_else != NULL) {
            free_pos(e->u.list_if_item_expr.or_else->pos);
            free(e->u.list_if_item_expr.or_else->id);
            if (e->u.list_if_item_expr.or_else->node != NULL)
                free_expr(e->u.list_if_item_expr.or_else->node);
            free(e->u.list_if_item_expr.or_else);
        }
        break;
    case KCL_EXPR_KIND_LIST_COMP:
        free_pos(e->u.list_comp.elt.pos);
        free(e->u.list_comp.elt.id);
        if (e->u.list_comp.elt.node != NULL)
            free_expr(e->u.list_comp.elt.node);
        free_comp_clause_node_list((kcl_comp_clause_node_list_t*)e->u.list_comp.generators);
        if (e->u.list_comp.cond != NULL) {
            free_pos(e->u.list_comp.cond->pos);
            free(e->u.list_comp.cond->id);
            if (e->u.list_comp.cond->node != NULL)
                free_expr(e->u.list_comp.cond->node);
            free(e->u.list_comp.cond);
        }
        break;
    case KCL_EXPR_KIND_STARRED:
        free_pos(e->u.starred_expr.value.pos);
        free(e->u.starred_expr.value.id);
        if (e->u.starred_expr.value.node != NULL)
            free_expr(e->u.starred_expr.value.node);
        free(e->u.starred_expr.ctx);
        break;
    case KCL_EXPR_KIND_DICT_COMP:
        free_pos(e->u.dict_comp.key.pos);
        free(e->u.dict_comp.key.id);
        if (e->u.dict_comp.key.node != NULL)
            free_expr(e->u.dict_comp.key.node);
        free_pos(e->u.dict_comp.value.pos);
        free(e->u.dict_comp.value.id);
        if (e->u.dict_comp.value.node != NULL)
            free_expr(e->u.dict_comp.value.node);
        free_comp_clause_node_list((kcl_comp_clause_node_list_t*)e->u.dict_comp.generators);
        if (e->u.dict_comp.cond != NULL) {
            free_pos(e->u.dict_comp.cond->pos);
            free(e->u.dict_comp.cond->id);
            if (e->u.dict_comp.cond->node != NULL)
                free_expr(e->u.dict_comp.cond->node);
            free(e->u.dict_comp.cond);
        }
        break;
    case KCL_EXPR_KIND_CONFIG_IF_ENTRY:
        free_pos(e->u.config_if_entry_expr.if_expr.pos);
        free(e->u.config_if_entry_expr.if_expr.id);
        if (e->u.config_if_entry_expr.if_expr.node != NULL)
            free_expr(e->u.config_if_entry_expr.if_expr.node);
        break;
    case KCL_EXPR_KIND_COMP_CLAUSE:
        free_target_node_list(&e->u.comp_clause.targets);
        free_pos(e->u.comp_clause.iter.pos);
        free(e->u.comp_clause.iter.id);
        if (e->u.comp_clause.iter.node != NULL)
            free_expr(e->u.comp_clause.iter.node);
        free_expr_node_list(&e->u.comp_clause.ifs);
        break;
    case KCL_EXPR_KIND_SCHEMA:
        free_pos(e->u.schema_expr.name.pos);
        free(e->u.schema_expr.name.id);
        if (e->u.schema_expr.name.node != NULL)
            free_expr(e->u.schema_expr.name.node);
        free_expr_node_list(&e->u.schema_expr.args);
        free_keyword_node_list((kcl_keyword_node_list_t*)e->u.schema_expr.kwargs);
        free_pos(e->u.schema_expr.config.pos);
        free(e->u.schema_expr.config.id);
        if (e->u.schema_expr.config.node != NULL)
            free_expr(e->u.schema_expr.config.node);
        break;
    case KCL_EXPR_KIND_CONFIG:
        free_config_entry_node_list((kcl_config_entry_node_list_t*)e->u.config_expr.items);
        break;
    case KCL_EXPR_KIND_LAMBDA:
        free_arguments((kcl_arguments_t*)e->u.lambda_expr.args.node);
        free_pos(e->u.lambda_expr.args.pos);
        free(e->u.lambda_expr.args.id);
        free_stmt_node_list(&e->u.lambda_expr.body);
        if (e->u.lambda_expr.return_ty != NULL) {
            free_type_node_node(e->u.lambda_expr.return_ty);
            free(e->u.lambda_expr.return_ty);
        }
        break;
    case KCL_EXPR_KIND_SUBSCRIPT:
        free_pos(e->u.subscript_expr.value.pos);
        free(e->u.subscript_expr.value.id);
        if (e->u.subscript_expr.value.node != NULL)
            free_expr(e->u.subscript_expr.value.node);
        free_pos(e->u.subscript_expr.index.pos);
        free(e->u.subscript_expr.index.id);
        if (e->u.subscript_expr.index.node != NULL)
            free_expr(e->u.subscript_expr.index.node);
        break;
    case KCL_EXPR_KIND_COMPARE:
        free_pos(e->u.compare_expr.left.pos);
        free(e->u.compare_expr.left.id);
        if (e->u.compare_expr.left.node != NULL)
            free_expr(e->u.compare_expr.left.node);
        free_string_list(e->u.compare_expr.ops, e->u.compare_expr.ops_count);
        free_expr_node_list(&e->u.compare_expr.comparators);
        break;
    case KCL_EXPR_KIND_NUMBER_LIT:
        free(e->u.number_lit.binary_suffix);
        free(e->u.number_lit.value.raw_value);
        free(e->u.number_lit.value.binary_suffix);
        break;
    case KCL_EXPR_KIND_STRING_LIT:
        free(e->u.string_lit.raw_value);
        free(e->u.string_lit.value);
        break;
    case KCL_EXPR_KIND_NAME_CONSTANT_LIT:
        free(e->u.name_constant_lit.value);
        break;
    case KCL_EXPR_KIND_JOINED_STRING:
        free_expr_node_list(&e->u.joined_string.values);
        free(e->u.joined_string.raw_value);
        break;
    case KCL_EXPR_KIND_FORMATTED_VALUE:
        free_pos(e->u.formatted_value.value.pos);
        free(e->u.formatted_value.value.id);
        if (e->u.formatted_value.value.node != NULL)
            free_expr(e->u.formatted_value.value.node);
        free(e->u.formatted_value.spec);
        break;
    case KCL_EXPR_KIND_MISSING:
        break;
    case KCL_EXPR_KIND_CHECK:
        free_pos(e->u.check_expr.test.pos);
        free(e->u.check_expr.test.id);
        if (e->u.check_expr.test.node != NULL)
            free_expr(e->u.check_expr.test.node);
        if (e->u.check_expr.if_cond != NULL) {
            free_pos(e->u.check_expr.if_cond->pos);
            free(e->u.check_expr.if_cond->id);
            if (e->u.check_expr.if_cond->node != NULL)
                free_expr(e->u.check_expr.if_cond->node);
            free(e->u.check_expr.if_cond);
        }
        free_string_node(e->u.check_expr.msg);
        break;
    default:
        break;
    }
    free(e);
}

void free_expr_node_list(kcl_expr_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_expr((kcl_expr_t*)list->items[i].node);
        free_pos(list->items[i].pos);
        free(list->items[i].id);
    }
    free(list->items);
}

void free_target_node_list(kcl_target_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_target((kcl_target_t*)list->items[i].node);
        free_pos(list->items[i].pos);
        free(list->items[i].id);
    }
    free(list->items);
}

void free_type_node_node_list(kcl_type_node_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_type_node_node(&list->items[i]);
    }
    free(list->items);
}

void free_identifier_node_list(kcl_identifier_node_list_t* list)
{
    if (list == NULL || list->items == NULL)
        return;
    for (size_t i = 0; i < list->count; i++) {
        free_identifier((kcl_identifier_t*)list->items[i].node);
        free_pos(list->items[i].pos);
        free(list->items[i].id);
    }
    free(list->items);
}

/* ---------------------------------------------------------------- *
 * TypeNode dispatch
 * ---------------------------------------------------------------- */

static kcl_type_kind_t type_kind_from_tag(const char* tag)
{
    if (tag == NULL) return KCL_TYPE_KIND_UNKNOWN;
    if (strcmp(tag, "any") == 0 || strcmp(tag, "Any") == 0) return KCL_TYPE_KIND_ANY;
    if (strcmp(tag, "Basic") == 0) return KCL_TYPE_KIND_BASIC;
    if (strcmp(tag, "List") == 0) return KCL_TYPE_KIND_LIST;
    if (strcmp(tag, "Dict") == 0) return KCL_TYPE_KIND_DICT;
    if (strcmp(tag, "SchemaRef") == 0) return KCL_TYPE_KIND_SCHEMA_REF;
    if (strcmp(tag, "Literal") == 0) return KCL_TYPE_KIND_LITERAL;
    if (strcmp(tag, "Function") == 0) return KCL_TYPE_KIND_FUNCTION;
    if (strcmp(tag, "Union") == 0) return KCL_TYPE_KIND_UNION;
    if (strcmp(tag, "Named") == 0) return KCL_TYPE_KIND_NAMED;
    if (strcmp(tag, "StrLiteral") == 0) return KCL_TYPE_KIND_STR_LITERAL;
    if (strcmp(tag, "IntLiteral") == 0) return KCL_TYPE_KIND_INT_LITERAL;
    if (strcmp(tag, "FloatLiteral") == 0) return KCL_TYPE_KIND_FLOAT_LITERAL;
    if (strcmp(tag, "BoolLiteral") == 0) return KCL_TYPE_KIND_BOOL_LITERAL;
    if (strcmp(tag, "KeyValue") == 0) return KCL_TYPE_KIND_KEY_VALUE;
    return KCL_TYPE_KIND_UNKNOWN;
}

static kcl_type_node_t* parse_type_node(const kcl_json_value_t* node)
{
    if (node == NULL || node->type != KCL_JSON_OBJECT)
        return NULL;
    const kcl_json_value_t* tag = kcl_json_object_get(node, "type");
    kcl_type_node_t* t = (kcl_type_node_t*)calloc(1, sizeof(*t));
    t->type_tag = json_to_string(tag);
    t->kind = type_kind_from_tag(t->type_tag);
    switch (t->kind) {
    case KCL_TYPE_KIND_ANY:
        break;
    case KCL_TYPE_KIND_BASIC:
        t->u.basic_type.type_disc = json_to_string(kcl_json_object_get(node, "type"));
        t->u.basic_type.kind = json_to_string(kcl_json_object_get(node, "kind"));
        break;
    case KCL_TYPE_KIND_LIST:
        t->u.list_type.inner_type = parse_type_node_node(kcl_json_object_get(node, "inner_type"));
        break;
    case KCL_TYPE_KIND_DICT:
        t->u.dict_type.key_type = parse_type_node_node(kcl_json_object_get(node, "key_type"));
        t->u.dict_type.value_type = parse_type_node_node(kcl_json_object_get(node, "value_type"));
        break;
    case KCL_TYPE_KIND_SCHEMA_REF:
        t->u.schema_ref_type.schema_name = *parse_string_node(kcl_json_object_get(node, "schema_name"));
        t->u.schema_ref_type.pkgpath = parse_string_list(kcl_json_object_get(node, "pkgpath"), &t->u.schema_ref_type.pkgpath_count);
        break;
    case KCL_TYPE_KIND_LITERAL: {
        const kcl_json_value_t* val = kcl_json_object_get(node, "value");
        if (val != NULL) {
            switch (val->type) {
            case KCL_JSON_STRING:
                t->u.literal_type.value_kind = strdup("String");
                t->u.literal_type.string_value = json_to_string(val);
                break;
            case KCL_JSON_NUMBER: {
                /* Try to detect int vs float by checking for `.`/`e`/`E`. */
                char buf[64];
                snprintf(buf, sizeof(buf), "%g", val->u.number);
                if (strchr(buf, '.') || strchr(buf, 'e') || strchr(buf, 'E')) {
                    t->u.literal_type.value_kind = strdup("Float");
                    t->u.literal_type.has_float_value = true;
                    t->u.literal_type.float_value = val->u.number;
                } else {
                    t->u.literal_type.value_kind = strdup("Int");
                    t->u.literal_type.has_int_value = true;
                    t->u.literal_type.int_value = (int64_t)val->u.number;
                }
                break;
            }
            case KCL_JSON_BOOL:
                t->u.literal_type.value_kind = strdup("Bool");
                t->u.literal_type.has_bool_value = true;
                t->u.literal_type.bool_value = val->u.boolean;
                break;
            default:
                t->u.literal_type.value_kind = strdup("Unknown");
                break;
            }
        }
        break;
    }
    case KCL_TYPE_KIND_FUNCTION:
        t->u.function_type.params = parse_type_node_node_list(kcl_json_object_get(node, "params"));
        t->u.function_type.ret = parse_type_node_node(kcl_json_object_get(node, "ret"));
        break;
    case KCL_TYPE_KIND_UNION: {
        const kcl_json_value_t* any = kcl_json_object_get(node, "any");
        t->u.union_type.any = (any != NULL && any->type == KCL_JSON_BOOL) ? any->u.boolean : false;
        t->u.union_type.types = parse_type_node_node_list(kcl_json_object_get(node, "types"));
        break;
    }
    case KCL_TYPE_KIND_NAMED:
        t->u.named_type.name = parse_identifier_node(kcl_json_object_get(node, "name"));
        break;
    case KCL_TYPE_KIND_STR_LITERAL:
        t->u.str_literal_type.value = json_to_string(kcl_json_object_get(node, "value"));
        break;
    case KCL_TYPE_KIND_INT_LITERAL: {
        const kcl_json_value_t* v = kcl_json_object_get(node, "value");
        t->u.int_literal_type.value = (v != NULL && v->type == KCL_JSON_NUMBER) ? (int64_t)v->u.number : 0;
        break;
    }
    case KCL_TYPE_KIND_FLOAT_LITERAL: {
        const kcl_json_value_t* v = kcl_json_object_get(node, "value");
        t->u.float_literal_type.value = (v != NULL && v->type == KCL_JSON_NUMBER) ? v->u.number : 0.0;
        break;
    }
    case KCL_TYPE_KIND_BOOL_LITERAL: {
        const kcl_json_value_t* v = kcl_json_object_get(node, "value");
        t->u.bool_literal_type.value = (v != NULL && v->type == KCL_JSON_BOOL) ? v->u.boolean : false;
        break;
    }
    case KCL_TYPE_KIND_KEY_VALUE:
        t->u.key_value_type.key = parse_type_node_node(kcl_json_object_get(node, "key"));
        t->u.key_value_type.value = parse_type_node_node(kcl_json_object_get(node, "value"));
        break;
    default:
        break;
    }
    return t;
}

void free_type_node(kcl_type_node_t* t)
{
    if (t == NULL)
        return;
    free(t->type_tag);
    switch (t->kind) {
    case KCL_TYPE_KIND_ANY:
        break;
    case KCL_TYPE_KIND_BASIC:
        free(t->u.basic_type.type_disc);
        free(t->u.basic_type.kind);
        break;
    case KCL_TYPE_KIND_LIST:
        free_type_node_node(&t->u.list_type.inner_type);
        break;
    case KCL_TYPE_KIND_DICT:
        free_type_node_node(&t->u.dict_type.key_type);
        free_type_node_node(&t->u.dict_type.value_type);
        break;
    case KCL_TYPE_KIND_SCHEMA_REF:
        free_string_node(&t->u.schema_ref_type.schema_name);
        free_string_list(t->u.schema_ref_type.pkgpath, t->u.schema_ref_type.pkgpath_count);
        break;
    case KCL_TYPE_KIND_LITERAL:
        free(t->u.literal_type.value_kind);
        free(t->u.literal_type.string_value);
        break;
    case KCL_TYPE_KIND_FUNCTION:
        free_type_node_node_list(&t->u.function_type.params);
        free_type_node_node(&t->u.function_type.ret);
        break;
    case KCL_TYPE_KIND_UNION:
        free_type_node_node_list(&t->u.union_type.types);
        break;
    case KCL_TYPE_KIND_NAMED:
        free_identifier((kcl_identifier_t*)t->u.named_type.name.node);
        free_pos(t->u.named_type.name.pos);
        free(t->u.named_type.name.id);
        break;
    case KCL_TYPE_KIND_STR_LITERAL:
        free(t->u.str_literal_type.value);
        break;
    default:
        break;
    }
    free(t);
}

void free_type_node_node(kcl_type_node_node_t* n)
{
    if (n == NULL)
        return;
    free_type_node((kcl_type_node_t*)n->node);
    free_pos(n->pos);
    free(n->id);
}

/* ---------------------------------------------------------------- *
 * Module / Program
 * ---------------------------------------------------------------- */

kcl_module_t* kcl_ast_parse_module(const char* ast_json)
{
    kcl_json_value_t* root = kcl_json_parse(ast_json);
    if (root == NULL)
        return NULL;
    kcl_module_t* m = (kcl_module_t*)calloc(1, sizeof(*m));
    const kcl_json_value_t* fn = kcl_json_object_get(root, "filename");
    m->filename = json_to_string(fn);
    const kcl_json_value_t* doc = kcl_json_object_get(root, "doc");
    if (doc != NULL)
        m->doc = parse_string_node(doc);
    m->body = parse_stmt_node_list(kcl_json_object_get(root, "body"));
    m->comments = parse_string_node_list(kcl_json_object_get(root, "comments"));
    kcl_json_free(root);
    return m;
}

void kcl_module_free(kcl_module_t* module)
{
    if (module == NULL)
        return;
    free(module->filename);
    free_string_node(module->doc);
    free_stmt_node_list(&module->body);
    free_string_node_list(&module->comments);
    free(module);
}

kcl_program_t* kcl_ast_parse_program(const char* ast_json)
{
    kcl_json_value_t* root = kcl_json_parse(ast_json);
    if (root == NULL)
        return NULL;
    kcl_program_t* p = (kcl_program_t*)calloc(1, sizeof(*p));
    p->root = json_to_string(kcl_json_object_get(root, "root"));
    const kcl_json_value_t* pkgs = kcl_json_object_get(root, "pkgs");
    const kcl_json_value_t* main_pkg = NULL;
    if (pkgs != NULL && pkgs->type == KCL_JSON_OBJECT)
        main_pkg = kcl_json_object_get(pkgs, "__main__");
    if (main_pkg != NULL && main_pkg->type == KCL_JSON_ARRAY) {
        size_t n = kcl_json_array_length(main_pkg);
        if (n > 0) {
            p->main_package = (kcl_module_t**)calloc(n, sizeof(kcl_module_t*));
            p->main_package_count = n;
            for (size_t i = 0; i < n; i++) {
                const kcl_json_value_t* v = kcl_json_array_get(main_pkg, i);
                /* Each entry is itself a module dict. */
                kcl_module_t* m = (kcl_module_t*)calloc(1, sizeof(*m));
                const kcl_json_value_t* fn = kcl_json_object_get(v, "filename");
                m->filename = json_to_string(fn);
                const kcl_json_value_t* doc = kcl_json_object_get(v, "doc");
                if (doc != NULL)
                    m->doc = parse_string_node(doc);
                m->body = parse_stmt_node_list(kcl_json_object_get(v, "body"));
                m->comments = parse_string_node_list(kcl_json_object_get(v, "comments"));
                p->main_package[i] = m;
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
    free(program->root);
    for (size_t i = 0; i < program->main_package_count; i++)
        kcl_module_free(program->main_package[i]);
    free(program->main_package);
    free(program);
}
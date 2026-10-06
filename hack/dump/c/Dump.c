/*
 * Dump.c — the C binding's AST, in the harness's dump format.
 *
 *   c_dump <golden.json> <out.json>
 *
 * The decoder is `c/lib/kcl_lib_ast.c` and the contract is
 * `c/include/kcl_lib_ast.h`; nothing here re-reads the JSON. Every value
 * below is read out of the `kcl_module_t` that `kcl_ast_parse_module`
 * returned, so a disagreement with the golden is a disagreement in the
 * decoder.
 *
 * C has no runtime reflection, so — as in `hack/dump/cpp/Dump.cpp` — the
 * field list per class is written out here, by hand. That file is a second
 * statement of what the header declares, and the diff is what catches the
 * two drifting. The wrappers (`DEFINE_WRAPPER`, `DEFINE_LIST`) are macros
 * so the statement is made once per payload kind rather than once per
 * field.
 *
 * Three naming conventions, all of them the C binding's own:
 *
 *   * `@cls` is the C name of what was decoded. For a union arm that is a
 *     named struct, that is the struct's tag (`kcl_call_expr_t` →
 *     `CallExpr`); for one that is an anonymous struct, it is the union
 *     field (`binary_expr`). Both normalise to the same key the other
 *     bindings' class names do, so the comparator cross-checks the tag
 *     against `CLASS_TAGS` the way it does for them.
 *
 *   * `pos` is emitted only when the wrapper has one. The wire wrapper is
 *     flat (`{node, filename, line, …}`) and the C one nests it, which is
 *     R2's job to undo — not this file's.
 *
 *   * `id` is never emitted. The C decoder does read it off the wire
 *     (`kcl_lib_ast.c`, `n->id = read_key_str(...)`), but `ast.rs` gates it
 *     behind `SHOULD_SERIALIZE_ID`, which is off for the golden, so every
 *     `id` here is NULL and the wire has no counterpart for the key.
 *
 * Two places where the C decoder has no class and no field name, and so
 * carries only what it actually holds:
 *
 *   * `LiteralType`'s four arms and `NumberLitValue`'s two are an enum and
 *     a `value` field inside `kcl_type_node_t` / `kcl_expr_t`, not types.
 *     They are written as `{"@tag": …, "value": …}` with no `@cls`. For
 *     `LiteralType::Int` the payload's fields are spread rather than
 *     nested, which is R15 — the C struct groups them one level deeper
 *     than the wire does, and the spread is the shape the comparator
 *     reconciles.
 *
 *   * `MemberOrIndex` unpacks into a `kind` plus a `member` or an `index`
 *     field. Both are written under their own names; the wire's `value`
 *     has no counterpart in C, and R7 (ii) is the rule that reconciles a
 *     payload the binding kept in a single wrapper field of its own.
 */

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "kcl_lib_ast.h"

/* ------------------------------------------------------------------ *
 * Output plumbing
 *
 * The document is written straight to the file rather than built as a
 * value tree: the only thing that reads it is the Ruby comparator, which
 * compares by key, so key order is free and there is no reason to pay
 * for a second copy of the AST in memory. `counts[]` is the number of
 * members already written at each nesting level, which is all the comma
 * bookkeeping a JSON writer needs.
 * ------------------------------------------------------------------ */

#define MAX_DEPTH 128

static FILE* out;
static size_t counts[MAX_DEPTH];
static int depth;

static void sep(const char* key)
{
    if (counts[depth] > 0)
        fputc(',', out);
    counts[depth]++;
    if (key != NULL)
        fprintf(out, "\"%s\":", key);
}

static void push(void)
{
    if (depth + 1 >= MAX_DEPTH) {
        fprintf(stderr, "c dump: the tree is deeper than %d levels\n", MAX_DEPTH);
        exit(1);
    }
    depth++;
    counts[depth] = 0;
}

static void obj_begin(const char* key)
{
    sep(key);
    fputc('{', out);
    push();
}

static void obj_end(void)
{
    fputc('}', out);
    depth--;
}

static void arr_begin(const char* key)
{
    sep(key);
    fputc('[', out);
    push();
}

static void arr_end(void)
{
    fputc(']', out);
    depth--;
}

static void write_string(const char* s)
{
    fputc('"', out);
    for (const unsigned char* p = (const unsigned char*)s; *p != '\0'; p++) {
        switch (*p) {
        case '"': fputs("\\\"", out); break;
        case '\\': fputs("\\\\", out); break;
        case '\n': fputs("\\n", out); break;
        case '\r': fputs("\\r", out); break;
        case '\t': fputs("\\t", out); break;
        case '\b': fputs("\\b", out); break;
        case '\f': fputs("\\f", out); break;
        default:
            /* Control characters only; every other byte is passed through,
             * so a UTF-8 string stays UTF-8 rather than being re-escaped
             * into \u sequences the other side would have to decode. */
            if (*p < 0x20)
                fprintf(out, "\\u%04x", *p);
            else
                fputc(*p, out);
        }
    }
    fputc('"', out);
}

static void field_str(const char* key, const char* s)
{
    sep(key);
    if (s == NULL)
        fputs("null", out);
    else
        write_string(s);
}

static void field_i64(const char* key, int64_t v)
{
    sep(key);
    fprintf(out, "%lld", (long long)v);
}

static void field_bool(const char* key, bool v)
{
    sep(key);
    fputs(v ? "true" : "false", out);
}

static void field_null(const char* key)
{
    sep(key);
    fputs("null", out);
}

/* `@cls`, from the C name of what was decoded.
 *
 * A C struct's name carries the binding's decoration — a `kcl_` prefix and
 * a `_t` suffix — and that decoration is a convention rather than part of
 * the name: `kcl_schema_stmt_t` is `SchemaStmt`. The prefix and the suffix
 * come off here so that a C struct and the equivalent class in any other
 * binding land on the same key, which is what lets the comparator check
 * the tag against one independent table instead of one entry per spelling.
 * A name without the decoration — the union fields that *are* the
 * anonymous arms, `binary_expr` and `schema_attr` — goes through
 * unchanged, so the caller always passes the C name verbatim. */
static void field_cls(const char* type)
{
    char buf[128];
    const char* name = type;
    size_t len = strlen(type);

    if (strncmp(type, "kcl_", 4) == 0 && len > 6 && strcmp(type + len - 2, "_t") == 0) {
        len -= 6;
        if (len < sizeof(buf)) {
            memcpy(buf, type + 4, len);
            buf[len] = '\0';
            name = buf;
        }
    }

    sep("@cls");
    write_string(name);
}

static void field_f64(const char* key, double v)
{
    /* The shortest representation that reads back as the same double, so
     * `1.5` stays `1.5` and does not become `1.5000000000000000`. A `.0`
     * is appended when the result would otherwise look like an integer:
     * the value came out of a `double` field, and a Ruby `Integer` on the
     * other side would be a different type for the same number. */
    char buf[64];
    for (int precision = 1; precision <= 17; precision++) {
        snprintf(buf, sizeof(buf), "%.*g", precision, v);
        if (strtod(buf, NULL) == v)
            break;
    }
    if (strpbrk(buf, ".eEn") == NULL)
        strcat(buf, ".0");

    sep(key);
    fputs(buf, out);
}

/* ------------------------------------------------------------------ *
 * Enum names
 *
 * `kcl_lib_ast.h` publishes `*_name()` for the six enums the diagnostics
 * need. The other seven are decoded from the wire but never named, so the
 * tables are here: the Rust variant names in the order the C enums are
 * numbered in, which is the order `kcl_lib_ast.c`'s `KCL_DEFINE_ENUM_DECODER`
 * decodes them in, so the index *is* the value.
 * ------------------------------------------------------------------ */

static const char* const QUANT_OP_NAMES[] = { "All", "Any", "Filter", "Map" };
static const char* const CONFIG_ENTRY_OP_NAMES[] = { "Union", "Override", "Insert" };
static const char* const BASIC_TYPE_NAMES[] = { "Bool", "Int", "Float", "Str" };
static const char* const NAME_CONSTANT_NAMES[] = { "True", "False", "None", "Undefined" };
static const char* const MEMBER_OR_INDEX_NAMES[] = { "Member", "Index" };
static const char* const NUMBER_LIT_VALUE_NAMES[] = { "Int", "Float" };
static const char* const LITERAL_TYPE_NAMES[] = { "Bool", "Int", "Float", "Str" };

#define NAME_OF(table, value)                                                  \
    ((size_t)(value) < sizeof(table) / sizeof(table[0]) ? table[(size_t)(value)] : "?")

/* ------------------------------------------------------------------ *
 * Forward declarations — the graph is cyclic (`Expr` holds a list of
 * `Expr`), so every emitter has to be visible before the macros that
 * call it are expanded.
 * ------------------------------------------------------------------ */

static void dump_pos(const char* key, const kcl_pos_t* p);
static void dump_string_payload(const char* key, const char* s);

static void dump_identifier(const char* key, const kcl_identifier_t* id);
static void dump_target(const char* key, const kcl_target_t* t);
static void dump_keyword(const char* key, const kcl_keyword_t* kw);
static void dump_arguments(const char* key, const kcl_arguments_t* args);
static void dump_call_expr(const char* key, const kcl_call_expr_t* call);
static void dump_check_expr(const char* key, const kcl_check_expr_t* check);
static void dump_comp_clause(const char* key, const kcl_comp_clause_t* comp);
static void dump_config_entry(const char* key, const kcl_config_entry_t* entry);
static void dump_schema_expr(const char* key, const kcl_schema_expr_t* schema);
static void dump_schema_index_signature(const char* key,
    const kcl_schema_index_signature_t* sig);
static void dump_comment(const char* key, const kcl_comment_t* comment);

static void dump_type(const char* key, const kcl_type_node_t* t);
static void dump_expr(const char* key, const kcl_expr_t* e);
static void dump_stmt(const char* key, const kcl_stmt_t* s);

/* ------------------------------------------------------------------ *
 * `NodeRef<T>` wrappers
 *
 * The wire wrapper is flat — `{node, filename, line, …}` — and the C one
 * nests the position under `pos`, so the dump keeps C's shape and R2
 * undoes the difference. No `@cls`: the wrapper is positional, not a
 * payload class, which is the same choice `hack/dump/ruby.rb` makes for
 * `A::Node`.
 * ------------------------------------------------------------------ */

#define DEFINE_WRAPPER(name, ctype, payload, dump_payload)                    \
    static void name(const char* key, const ctype* n)                         \
    {                                                                          \
        if (n == NULL) {                                                       \
            field_null(key);                                                   \
            return;                                                            \
        }                                                                      \
        obj_begin(key);                                                        \
        dump_payload("node", (const payload*)(n)->node);                       \
        if ((n)->pos != NULL)                                                  \
            dump_pos("pos", (n)->pos);                                         \
        obj_end();                                                             \
    }

/* `Vec<NodeRef<T>>`. */
#define DEFINE_LIST(name, ctype, listtype, dump_item)                         \
    static void name(const char* key, const listtype* l)                      \
    {                                                                          \
        arr_begin(key);                                                        \
        if (l != NULL)                                                         \
            for (size_t i = 0; i < l->count; i++)                             \
                dump_item(NULL, &l->items[i]);                                 \
        arr_end();                                                             \
    }

DEFINE_WRAPPER(dump_string_node, kcl_string_node_t, char, dump_string_payload)
DEFINE_WRAPPER(dump_stmt_node, kcl_stmt_node_t, kcl_stmt_t, dump_stmt)
DEFINE_WRAPPER(dump_expr_node, kcl_expr_node_t, kcl_expr_t, dump_expr)
DEFINE_WRAPPER(dump_type_node_ref, kcl_type_ref_node_t, kcl_type_node_t, dump_type)
DEFINE_WRAPPER(dump_target_node, kcl_target_node_t, kcl_target_t, dump_target)
DEFINE_WRAPPER(dump_identifier_node, kcl_identifier_node_t, kcl_identifier_t, dump_identifier)
DEFINE_WRAPPER(dump_arguments_node, kcl_arguments_node_t, kcl_arguments_t, dump_arguments)
DEFINE_WRAPPER(dump_check_expr_node, kcl_check_expr_node_t, kcl_check_expr_t, dump_check_expr)
DEFINE_WRAPPER(dump_call_expr_node, kcl_call_expr_node_t, kcl_call_expr_t, dump_call_expr)
DEFINE_WRAPPER(dump_comp_clause_node, kcl_comp_clause_node_t, kcl_comp_clause_t, dump_comp_clause)
DEFINE_WRAPPER(dump_config_entry_node, kcl_config_entry_node_t, kcl_config_entry_t, dump_config_entry)
DEFINE_WRAPPER(dump_keyword_node, kcl_keyword_node_t, kcl_keyword_t, dump_keyword)
DEFINE_WRAPPER(dump_schema_expr_node, kcl_schema_expr_node_t, kcl_schema_expr_t, dump_schema_expr)
DEFINE_WRAPPER(dump_schema_index_signature_node, kcl_schema_index_signature_node_t,
    kcl_schema_index_signature_t, dump_schema_index_signature)
DEFINE_WRAPPER(dump_comment_node, kcl_comment_node_t, kcl_comment_t, dump_comment)

/* `Vec<Node<String>>` needs the generic list of a wrapper whose payload is
 * a bare string, which the generic loader cannot express. */
DEFINE_LIST(dump_string_node_list, kcl_string_node_t, kcl_string_node_list_t, dump_string_node)
DEFINE_LIST(dump_stmt_node_list, kcl_stmt_node_t, kcl_stmt_node_list_t, dump_stmt_node)
DEFINE_LIST(dump_expr_node_list, kcl_expr_node_t, kcl_expr_node_list_t, dump_expr_node)
DEFINE_LIST(dump_type_ref_node_list, kcl_type_ref_node_t, kcl_type_ref_node_list_t, dump_type_node_ref)
DEFINE_LIST(dump_target_node_list, kcl_target_node_t, kcl_target_node_list_t, dump_target_node)
DEFINE_LIST(dump_identifier_node_list, kcl_identifier_node_t, kcl_identifier_node_list_t, dump_identifier_node)
DEFINE_LIST(dump_check_expr_node_list, kcl_check_expr_node_t, kcl_check_expr_node_list_t, dump_check_expr_node)
DEFINE_LIST(dump_call_expr_node_list, kcl_call_expr_node_t, kcl_call_expr_node_list_t, dump_call_expr_node)
DEFINE_LIST(dump_comp_clause_node_list, kcl_comp_clause_node_t, kcl_comp_clause_node_list_t, dump_comp_clause_node)
DEFINE_LIST(dump_config_entry_node_list, kcl_config_entry_node_t, kcl_config_entry_node_list_t, dump_config_entry_node)
DEFINE_LIST(dump_keyword_node_list, kcl_keyword_node_t, kcl_keyword_node_list_t, dump_keyword_node)
DEFINE_LIST(dump_comment_node_list, kcl_comment_node_t, kcl_comment_node_list_t, dump_comment_node)

/* `Vec<Option<NodeRef<T>>>` — `Arguments.defaults` and `Arguments.ty_list`
 * only. The list is index-aligned with `args`, so a slot the decoder found
 * absent stays a slot; dropping it would shift every later annotation onto
 * the wrong parameter. The JSON `null` is the wire's own, so the
 * comparator sees the same array length on both sides. */
static void dump_opt_expr_node_list(const char* key, const kcl_opt_expr_node_list_t* l)
{
    arr_begin(key);
    if (l != NULL)
        for (size_t i = 0; i < l->count; i++)
            dump_expr_node(NULL, l->items[i].present ? &l->items[i].value : NULL);
    arr_end();
}

static void dump_opt_type_node_list(const char* key, const kcl_opt_type_node_list_t* l)
{
    arr_begin(key);
    if (l != NULL)
        for (size_t i = 0; i < l->count; i++)
            dump_type_node_ref(NULL, l->items[i].present ? &l->items[i].value : NULL);
    arr_end();
}

/* ------------------------------------------------------------------ *
 * Position and the string payload
 * ------------------------------------------------------------------ */

static void dump_pos(const char* key, const kcl_pos_t* p)
{
    obj_begin(key);
    field_str("filename", p->filename);
    field_i64("line", p->line);
    field_i64("column", p->column);
    field_i64("end_line", p->end_line);
    field_i64("end_column", p->end_column);
    obj_end();
}

/* `Node<String>` is its own payload: the wrapper struct and the string
 * are the same object, so there is nothing to wrap. */
static void dump_string_payload(const char* key, const char* s)
{
    field_str(key, s);
}

/* ------------------------------------------------------------------ *
 * Flat DTOs — structs upstream, so no `"type"` tag of their own. Each is
 * reachable both as a bare field value and as a union arm, which is why
 * several of them are `:ambiguous` in `CLASS_TAGS`: the golden decides.
 * ------------------------------------------------------------------ */

static void dump_identifier(const char* key, const kcl_identifier_t* id)
{
    if (id == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_identifier_t");
    dump_string_node_list("names", &id->names);
    field_str("pkgpath", id->pkgpath);
    field_str("ctx", kcl_expr_context_name(id->ctx));
    obj_end();
}

static void dump_target(const char* key, const kcl_target_t* t)
{
    if (t == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_target_t");
    dump_string_node("name", &t->name);
    arr_begin("paths");
    for (size_t i = 0; i < t->paths_count; i++) {
        const kcl_member_or_index_t* m = &t->paths[i];
        obj_begin(NULL);
        field_cls("kcl_member_or_index_t");
        field_str("@tag", NAME_OF(MEMBER_OR_INDEX_NAMES, m->kind));
        /* The decoder has already unpacked the tagged union into one field
         * or the other; the wire's `value` key has no counterpart here, and
         * R7 (ii) is the rule that reconciles a payload a binding kept in
         * a single wrapper field of its own. */
        if (m->kind == KCL_MEMBER_OR_INDEX_INDEX)
            dump_expr_node("index", m->index);
        else
            dump_string_node("member", &m->member);
        obj_end();
    }
    arr_end();
    field_str("pkgpath", t->pkgpath);
    obj_end();
}

static void dump_keyword(const char* key, const kcl_keyword_t* kw)
{
    if (kw == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_keyword_t");
    dump_identifier_node("arg", &kw->arg);
    dump_expr_node("value", kw->value);
    obj_end();
}

static void dump_arguments(const char* key, const kcl_arguments_t* args)
{
    if (args == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_arguments_t");
    dump_identifier_node_list("args", &args->args);
    dump_opt_expr_node_list("defaults", &args->defaults);
    dump_opt_type_node_list("ty_list", &args->ty_list);
    obj_end();
}

static void dump_call_expr(const char* key, const kcl_call_expr_t* call)
{
    if (call == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_call_expr_t");
    dump_expr_node("func", &call->func);
    dump_expr_node_list("args", &call->args);
    dump_keyword_node_list("keywords", &call->keywords);
    obj_end();
}

static void dump_check_expr(const char* key, const kcl_check_expr_t* check)
{
    if (check == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_check_expr_t");
    dump_expr_node("test", &check->test);
    dump_expr_node("if_cond", check->if_cond);
    dump_expr_node("msg", check->msg);
    obj_end();
}

static void dump_comp_clause(const char* key, const kcl_comp_clause_t* comp)
{
    if (comp == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_comp_clause_t");
    dump_identifier_node_list("targets", &comp->targets);
    dump_expr_node("iter", &comp->iter);
    dump_expr_node_list("ifs", &comp->ifs);
    obj_end();
}

static void dump_config_entry(const char* key, const kcl_config_entry_t* entry)
{
    if (entry == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_config_entry_t");
    dump_expr_node("key", entry->key);
    dump_expr_node("value", &entry->value);
    field_str("operation", NAME_OF(CONFIG_ENTRY_OP_NAMES, entry->operation));
    /* Absent on the wire when false; the comparator's R5 is what makes the
     * two spellings of the same thing one. */
    field_bool("is_shorthand", entry->is_shorthand);
    obj_end();
}

static void dump_schema_expr(const char* key, const kcl_schema_expr_t* schema)
{
    if (schema == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_schema_expr_t");
    dump_identifier_node("name", &schema->name);
    dump_expr_node_list("args", &schema->args);
    dump_keyword_node_list("kwargs", &schema->kwargs);
    dump_expr_node("config", &schema->config);
    obj_end();
}

static void dump_schema_index_signature(const char* key,
    const kcl_schema_index_signature_t* sig)
{
    if (sig == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_schema_index_signature_t");
    dump_string_node("key_name", sig->key_name);
    dump_expr_node("value", sig->value);
    field_bool("any_other", sig->any_other);
    dump_type_node_ref("key_ty", &sig->key_ty);
    dump_type_node_ref("value_ty", &sig->value_ty);
    obj_end();
}

static void dump_comment(const char* key, const kcl_comment_t* comment)
{
    if (comment == NULL) {
        field_null(key);
        return;
    }
    obj_begin(key);
    field_cls("kcl_comment_t");
    field_str("text", comment->text);
    obj_end();
}

/* ------------------------------------------------------------------ *
 * `Type` — `#[serde(tag = "type", content = "value")]`
 *
 * `@cls` is the union field name, and `@tag` is `type_tag`, the raw string
 * the decoder read off the wire. Both are kept: the field names the C
 * arm, the tag is the only thing that survives an arm the decoder did not
 * recognise, and the comparator cross-checks them against each other.
 *
 * `Any` is the one variant with no payload at all, so there is no union
 * field to name it by and the object is written under the union struct
 * itself.
 * ------------------------------------------------------------------ */

static void dump_type(const char* key, const kcl_type_node_t* t)
{
    if (t == NULL) {
        field_null(key);
        return;
    }

    const char* cls;
    switch (t->kind) {
    case KCL_TYPE_KIND_NAMED: cls = "named_type"; break;
    case KCL_TYPE_KIND_BASIC: cls = "basic_type"; break;
    case KCL_TYPE_KIND_LIST: cls = "list_type"; break;
    case KCL_TYPE_KIND_DICT: cls = "dict_type"; break;
    case KCL_TYPE_KIND_UNION: cls = "union_type"; break;
    case KCL_TYPE_KIND_LITERAL: cls = "literal_type"; break;
    case KCL_TYPE_KIND_FUNCTION: cls = "function_type"; break;
    case KCL_TYPE_KIND_UNKNOWN: cls = "unknown_type"; break;
    case KCL_TYPE_KIND_ANY:
    default: cls = "kcl_type_node_t"; break;
    }

    obj_begin(key);
    field_cls(cls);
    field_str("@tag", t->type_tag);

    switch (t->kind) {
    case KCL_TYPE_KIND_NAMED:
        dump_identifier("name", &t->u.named_type.name);
        break;
    case KCL_TYPE_KIND_BASIC:
        /* A scalar payload, in a field the C decoder named. The wire calls
         * it `value`; R7 (iii) is the rule for a scalar under a name of the
         * binding's choosing. */
        field_str("basic", NAME_OF(BASIC_TYPE_NAMES, t->u.basic_type.basic));
        break;
    case KCL_TYPE_KIND_LIST:
        dump_type_node_ref("inner_type", t->u.list_type.inner_type);
        break;
    case KCL_TYPE_KIND_DICT:
        dump_type_node_ref("key_type", t->u.dict_type.key_type);
        dump_type_node_ref("value_type", t->u.dict_type.value_type);
        break;
    case KCL_TYPE_KIND_UNION:
        dump_type_ref_node_list("type_elements", &t->u.union_type.type_elements);
        break;
    case KCL_TYPE_KIND_LITERAL: {
        /* `LiteralType` is itself tag+content, so this is a second tagged
         * document with no C class of its own — `@tag` alone, and the
         * payload's fields spread as siblings of `value` rather than
         * nested one level deeper as the struct groups them. R15. */
        obj_begin("value");
        field_str("@tag", NAME_OF(LITERAL_TYPE_NAMES, t->u.literal_type.kind));
        switch (t->u.literal_type.kind) {
        case KCL_LITERAL_TYPE_BOOL:
            field_bool("value", t->u.literal_type.bool_value);
            break;
        case KCL_LITERAL_TYPE_INT:
            field_i64("value", t->u.literal_type.int_value.value);
            if (t->u.literal_type.int_value.has_suffix)
                field_str("suffix",
                    kcl_number_binary_suffix_name(t->u.literal_type.int_value.suffix));
            break;
        case KCL_LITERAL_TYPE_FLOAT:
            field_f64("value", t->u.literal_type.float_value);
            break;
        case KCL_LITERAL_TYPE_STR:
        default:
            field_str("value", t->u.literal_type.str_value);
            break;
        }
        obj_end();
        break;
    }
    case KCL_TYPE_KIND_FUNCTION:
        /* `params_ty` is `Option<Vec<NodeRef<Type>>>`, so the whole list is
         * a pointer: absent is an empty list rather than a null, which is
         * the same information and is what R4 is signed off for. */
        dump_type_ref_node_list("params_ty", t->u.function_type.params_ty);
        dump_type_node_ref("ret_ty", t->u.function_type.ret_ty);
        break;
    case KCL_TYPE_KIND_UNKNOWN:
        /* The tag is kept but the payload is not: the union has no room
         * for a variant this build does not know, and `type_tag` is all
         * that survives. The comparator's R11 is what says so, by name,
         * the first time the golden grows a tag this build cannot read. */
        break;
    case KCL_TYPE_KIND_ANY:
    default:
        break;
    }

    obj_end();
}

/* ------------------------------------------------------------------ *
 * `Expr` — `#[serde(tag = "type")]`, internally tagged with the newtype
 * payloads flattened in, so the arm's fields sit directly on the object.
 * ------------------------------------------------------------------ */

static void dump_expr(const char* key, const kcl_expr_t* e)
{
    if (e == NULL) {
        field_null(key);
        return;
    }

    const char* cls;
    switch (e->kind) {
    case KCL_EXPR_KIND_TARGET: cls = "kcl_target_t"; break;
    case KCL_EXPR_KIND_IDENTIFIER: cls = "kcl_identifier_t"; break;
    case KCL_EXPR_KIND_CALL: cls = "kcl_call_expr_t"; break;
    case KCL_EXPR_KIND_COMP_CLAUSE: cls = "kcl_comp_clause_t"; break;
    case KCL_EXPR_KIND_SCHEMA: cls = "kcl_schema_expr_t"; break;
    case KCL_EXPR_KIND_CHECK: cls = "kcl_check_expr_t"; break;
    case KCL_EXPR_KIND_KEYWORD: cls = "kcl_keyword_t"; break;
    case KCL_EXPR_KIND_ARGUMENTS: cls = "kcl_arguments_t"; break;
    case KCL_EXPR_KIND_UNARY: cls = "unary_expr"; break;
    case KCL_EXPR_KIND_BINARY: cls = "binary_expr"; break;
    case KCL_EXPR_KIND_IF: cls = "if_expr"; break;
    case KCL_EXPR_KIND_SELECTOR: cls = "selector_expr"; break;
    case KCL_EXPR_KIND_PAREN: cls = "paren_expr"; break;
    case KCL_EXPR_KIND_QUANT: cls = "quant_expr"; break;
    case KCL_EXPR_KIND_LIST: cls = "list_expr"; break;
    case KCL_EXPR_KIND_LIST_IF_ITEM: cls = "list_if_item_expr"; break;
    case KCL_EXPR_KIND_LIST_COMP: cls = "list_comp"; break;
    case KCL_EXPR_KIND_STARRED: cls = "starred_expr"; break;
    case KCL_EXPR_KIND_DICT_COMP: cls = "dict_comp"; break;
    case KCL_EXPR_KIND_CONFIG_IF_ENTRY: cls = "config_if_entry_expr"; break;
    case KCL_EXPR_KIND_CONFIG: cls = "config_expr"; break;
    case KCL_EXPR_KIND_LAMBDA: cls = "lambda_expr"; break;
    case KCL_EXPR_KIND_SUBSCRIPT: cls = "subscript_expr"; break;
    case KCL_EXPR_KIND_COMPARE: cls = "compare_expr"; break;
    case KCL_EXPR_KIND_NUMBER_LIT: cls = "number_lit"; break;
    case KCL_EXPR_KIND_STRING_LIT: cls = "string_lit"; break;
    case KCL_EXPR_KIND_NAME_CONSTANT_LIT: cls = "name_constant_lit"; break;
    case KCL_EXPR_KIND_JOINED_STRING: cls = "joined_string"; break;
    case KCL_EXPR_KIND_FORMATTED_VALUE: cls = "formatted_value"; break;
    case KCL_EXPR_KIND_MISSING: cls = "missing_expr"; break;
    case KCL_EXPR_KIND_UNKNOWN:
    default: cls = "unknown_expr"; break;
    }

    obj_begin(key);
    field_cls(cls);
    field_str("@tag", e->type_tag);

    switch (e->kind) {
    case KCL_EXPR_KIND_TARGET:
        dump_target("target", &e->u.target);
        break;
    case KCL_EXPR_KIND_IDENTIFIER:
        dump_identifier("identifier", &e->u.identifier);
        break;
    case KCL_EXPR_KIND_UNARY:
        field_str("op", kcl_unary_op_name(e->u.unary_expr.op));
        dump_expr_node("operand", &e->u.unary_expr.operand);
        break;
    case KCL_EXPR_KIND_BINARY:
        dump_expr_node("left", &e->u.binary_expr.left);
        field_str("op", kcl_bin_op_name(e->u.binary_expr.op));
        dump_expr_node("right", &e->u.binary_expr.right);
        break;
    case KCL_EXPR_KIND_IF:
        dump_expr_node("body", &e->u.if_expr.body);
        dump_expr_node("cond", &e->u.if_expr.cond);
        dump_expr_node("orelse", &e->u.if_expr.orelse);
        break;
    case KCL_EXPR_KIND_SELECTOR:
        dump_expr_node("value", &e->u.selector_expr.value);
        dump_identifier_node("attr", &e->u.selector_expr.attr);
        field_str("ctx", kcl_expr_context_name(e->u.selector_expr.ctx));
        field_bool("has_question", e->u.selector_expr.has_question);
        break;
    case KCL_EXPR_KIND_CALL:
        dump_call_expr("call", &e->u.call_expr);
        break;
    case KCL_EXPR_KIND_PAREN:
        dump_expr_node("expr", &e->u.paren_expr.expr);
        break;
    case KCL_EXPR_KIND_QUANT:
        dump_expr_node("target", &e->u.quant_expr.target);
        dump_identifier_node_list("variables", &e->u.quant_expr.variables);
        field_str("op", NAME_OF(QUANT_OP_NAMES, e->u.quant_expr.op));
        dump_expr_node("test", &e->u.quant_expr.test);
        dump_expr_node("if_cond", e->u.quant_expr.if_cond);
        field_str("ctx", kcl_expr_context_name(e->u.quant_expr.ctx));
        break;
    case KCL_EXPR_KIND_LIST:
        dump_expr_node_list("elts", &e->u.list_expr.elts);
        field_str("ctx", kcl_expr_context_name(e->u.list_expr.ctx));
        break;
    case KCL_EXPR_KIND_LIST_IF_ITEM:
        dump_expr_node("if_cond", &e->u.list_if_item_expr.if_cond);
        dump_expr_node_list("exprs", &e->u.list_if_item_expr.exprs);
        dump_expr_node("orelse", e->u.list_if_item_expr.orelse);
        break;
    case KCL_EXPR_KIND_LIST_COMP:
        dump_expr_node("elt", &e->u.list_comp.elt);
        dump_comp_clause_node_list("generators", &e->u.list_comp.generators);
        break;
    case KCL_EXPR_KIND_STARRED:
        dump_expr_node("value", &e->u.starred_expr.value);
        field_str("ctx", kcl_expr_context_name(e->u.starred_expr.ctx));
        break;
    case KCL_EXPR_KIND_DICT_COMP:
        /* A bare `ConfigEntry` — no `NodeRef` wrapper, so no position of
         * its own upstream either. */
        dump_config_entry("entry", &e->u.dict_comp.entry);
        dump_comp_clause_node_list("generators", &e->u.dict_comp.generators);
        break;
    case KCL_EXPR_KIND_CONFIG_IF_ENTRY:
        dump_expr_node("if_cond", &e->u.config_if_entry_expr.if_cond);
        dump_config_entry_node_list("items", &e->u.config_if_entry_expr.items);
        dump_expr_node("orelse", e->u.config_if_entry_expr.orelse);
        break;
    case KCL_EXPR_KIND_COMP_CLAUSE:
        dump_comp_clause("comp_clause", &e->u.comp_clause);
        break;
    case KCL_EXPR_KIND_SCHEMA:
        dump_schema_expr("schema", &e->u.schema_expr);
        break;
    case KCL_EXPR_KIND_CONFIG:
        dump_config_entry_node_list("items", &e->u.config_expr.items);
        break;
    case KCL_EXPR_KIND_CHECK:
        dump_check_expr("check", &e->u.check_expr);
        break;
    case KCL_EXPR_KIND_LAMBDA:
        dump_arguments_node("args", e->u.lambda_expr.args);
        dump_stmt_node_list("body", &e->u.lambda_expr.body);
        dump_type_node_ref("return_ty", e->u.lambda_expr.return_ty);
        break;
    case KCL_EXPR_KIND_SUBSCRIPT:
        dump_expr_node("value", &e->u.subscript_expr.value);
        dump_expr_node("index", e->u.subscript_expr.index);
        dump_expr_node("lower", e->u.subscript_expr.lower);
        dump_expr_node("upper", e->u.subscript_expr.upper);
        dump_expr_node("step", e->u.subscript_expr.step);
        field_str("ctx", kcl_expr_context_name(e->u.subscript_expr.ctx));
        field_bool("has_question", e->u.subscript_expr.has_question);
        break;
    case KCL_EXPR_KIND_KEYWORD:
        dump_keyword("keyword", &e->u.keyword);
        break;
    case KCL_EXPR_KIND_ARGUMENTS:
        dump_arguments("arguments", &e->u.arguments);
        break;
    case KCL_EXPR_KIND_COMPARE:
        dump_expr_node("left", &e->u.compare_expr.left);
        arr_begin("ops");
        for (size_t i = 0; i < e->u.compare_expr.ops_count; i++) {
            sep(NULL);
            write_string(kcl_cmp_op_name(e->u.compare_expr.ops[i]));
        }
        arr_end();
        dump_expr_node_list("comparators", &e->u.compare_expr.comparators);
        break;
    case KCL_EXPR_KIND_NUMBER_LIT:
        field_str("binary_suffix",
            e->u.number_lit.has_binary_suffix
                ? kcl_number_binary_suffix_name(e->u.number_lit.binary_suffix)
                : NULL);
        /* `NumberLitValue` is tag+content with no C class of its own, so
         * `@tag` alone. The tag is not decoration: serde writes an `f64` as
         * a plain JSON number, so it is the only thing that tells an int
         * payload from a float one. */
        obj_begin("value");
        field_str("@tag", NAME_OF(NUMBER_LIT_VALUE_NAMES, e->u.number_lit.value_kind));
        if (e->u.number_lit.value_kind == KCL_NUMBER_LIT_VALUE_FLOAT)
            field_f64("value", e->u.number_lit.float_value);
        else
            field_i64("value", e->u.number_lit.int_value);
        obj_end();
        break;
    case KCL_EXPR_KIND_STRING_LIT:
        field_bool("is_long_string", e->u.string_lit.is_long_string);
        field_str("raw_value", e->u.string_lit.raw_value);
        field_str("value", e->u.string_lit.value);
        break;
    case KCL_EXPR_KIND_NAME_CONSTANT_LIT:
        field_str("value", NAME_OF(NAME_CONSTANT_NAMES, e->u.name_constant_lit.value));
        break;
    case KCL_EXPR_KIND_JOINED_STRING:
        field_bool("is_long_string", e->u.joined_string.is_long_string);
        dump_expr_node_list("values", &e->u.joined_string.values);
        field_str("raw_value", e->u.joined_string.raw_value);
        break;
    case KCL_EXPR_KIND_FORMATTED_VALUE:
        field_bool("is_long_string", e->u.formatted_value.is_long_string);
        dump_expr_node("value", &e->u.formatted_value.value);
        field_str("format_spec", e->u.formatted_value.format_spec);
        break;
    case KCL_EXPR_KIND_MISSING:
        /* A unit struct: the decoder keeps a placeholder field so the union
         * arm is addressable, and the wire has no key for it. */
        break;
    case KCL_EXPR_KIND_UNKNOWN:
    default:
        break;
    }

    obj_end();
}

/* ------------------------------------------------------------------ *
 * `Stmt` — `#[serde(tag = "type")]`
 * ------------------------------------------------------------------ */

static void dump_stmt(const char* key, const kcl_stmt_t* s)
{
    if (s == NULL) {
        field_null(key);
        return;
    }

    const char* cls;
    switch (s->kind) {
    case KCL_STMT_KIND_TYPE_ALIAS: cls = "kcl_type_alias_stmt_t"; break;
    case KCL_STMT_KIND_EXPR: cls = "kcl_expr_stmt_t"; break;
    case KCL_STMT_KIND_UNIFICATION: cls = "kcl_unification_stmt_t"; break;
    case KCL_STMT_KIND_ASSIGN: cls = "kcl_assign_stmt_t"; break;
    case KCL_STMT_KIND_AUG_ASSIGN: cls = "kcl_aug_assign_stmt_t"; break;
    case KCL_STMT_KIND_ASSERT: cls = "kcl_assert_stmt_t"; break;
    case KCL_STMT_KIND_IF: cls = "kcl_if_stmt_t"; break;
    case KCL_STMT_KIND_IMPORT: cls = "kcl_import_stmt_t"; break;
    case KCL_STMT_KIND_SCHEMA_ATTR: cls = "kcl_schema_attr_t"; break;
    case KCL_STMT_KIND_SCHEMA: cls = "kcl_schema_stmt_t"; break;
    case KCL_STMT_KIND_RULE: cls = "kcl_rule_stmt_t"; break;
    case KCL_STMT_KIND_UNKNOWN:
    default: cls = "unknown_stmt"; break;
    }

    obj_begin(key);
    field_cls(cls);
    field_str("@tag", s->type_tag);

    switch (s->kind) {
    case KCL_STMT_KIND_TYPE_ALIAS:
        dump_identifier_node("type_name", &s->u.type_alias_stmt.type_name);
        dump_string_node("type_value", &s->u.type_alias_stmt.type_value);
        dump_type_node_ref("ty", &s->u.type_alias_stmt.ty);
        break;
    case KCL_STMT_KIND_EXPR:
        dump_expr_node_list("exprs", &s->u.expr_stmt.exprs);
        break;
    case KCL_STMT_KIND_UNIFICATION:
        dump_identifier_node("target", &s->u.unification_stmt.target);
        dump_schema_expr_node("value", &s->u.unification_stmt.value);
        break;
    case KCL_STMT_KIND_ASSIGN:
        dump_target_node_list("targets", &s->u.assign_stmt.targets);
        dump_expr_node("value", &s->u.assign_stmt.value);
        dump_type_node_ref("ty", s->u.assign_stmt.ty);
        break;
    case KCL_STMT_KIND_AUG_ASSIGN:
        dump_target_node("target", &s->u.aug_assign_stmt.target);
        dump_expr_node("value", &s->u.aug_assign_stmt.value);
        field_str("op", kcl_aug_op_name(s->u.aug_assign_stmt.op));
        break;
    case KCL_STMT_KIND_ASSERT:
        dump_expr_node("test", &s->u.assert_stmt.test);
        dump_expr_node("if_cond", s->u.assert_stmt.if_cond);
        dump_expr_node("msg", s->u.assert_stmt.msg);
        break;
    case KCL_STMT_KIND_IF:
        dump_expr_node("cond", &s->u.if_stmt.cond);
        dump_stmt_node_list("body", &s->u.if_stmt.body);
        /* `orelse` is `Vec<NodeRef<Stmt>>` upstream too — a statement
         * list, not an expression. */
        dump_stmt_node_list("orelse", &s->u.if_stmt.orelse);
        break;
    case KCL_STMT_KIND_IMPORT:
        dump_string_node("path", &s->u.import_stmt.path);
        field_str("rawpath", s->u.import_stmt.rawpath);
        field_str("name", s->u.import_stmt.name);
        dump_string_node("asname", s->u.import_stmt.asname);
        field_str("pkg_name", s->u.import_stmt.pkg_name);
        break;
    case KCL_STMT_KIND_SCHEMA_ATTR:
        field_str("doc", s->u.schema_attr.doc);
        dump_string_node("name", &s->u.schema_attr.name);
        field_str("op",
            s->u.schema_attr.has_op ? kcl_aug_op_name(s->u.schema_attr.op) : NULL);
        dump_expr_node("value", s->u.schema_attr.value);
        field_bool("is_optional", s->u.schema_attr.is_optional);
        dump_call_expr_node_list("decorators", &s->u.schema_attr.decorators);
        dump_type_node_ref("ty", &s->u.schema_attr.ty);
        break;
    case KCL_STMT_KIND_SCHEMA:
        dump_string_node("doc", s->u.schema_stmt.doc);
        dump_string_node("name", &s->u.schema_stmt.name);
        dump_identifier_node("parent_name", s->u.schema_stmt.parent_name);
        dump_identifier_node("for_host_name", s->u.schema_stmt.for_host_name);
        field_bool("is_mixin", s->u.schema_stmt.is_mixin);
        field_bool("is_protocol", s->u.schema_stmt.is_protocol);
        dump_arguments_node("args", s->u.schema_stmt.args);
        dump_identifier_node_list("mixins", &s->u.schema_stmt.mixins);
        dump_stmt_node_list("body", &s->u.schema_stmt.body);
        /* Bare `CallExpr` and `CheckExpr` per element: structs upstream, so
         * no `"type"` tag on any of them. */
        dump_call_expr_node_list("decorators", &s->u.schema_stmt.decorators);
        dump_check_expr_node_list("checks", &s->u.schema_stmt.checks);
        dump_schema_index_signature_node("index_signature", s->u.schema_stmt.index_signature);
        break;
    case KCL_STMT_KIND_RULE:
        dump_string_node("doc", s->u.rule_stmt.doc);
        dump_string_node("name", &s->u.rule_stmt.name);
        dump_identifier_node_list("parent_rules", &s->u.rule_stmt.parent_rules);
        dump_call_expr_node_list("decorators", &s->u.rule_stmt.decorators);
        dump_check_expr_node_list("checks", &s->u.rule_stmt.checks);
        dump_arguments_node("args", s->u.rule_stmt.args);
        dump_identifier_node("for_host_name", s->u.rule_stmt.for_host_name);
        break;
    case KCL_STMT_KIND_UNKNOWN:
    default:
        break;
    }

    obj_end();
}

static void dump_module(const kcl_module_t* m)
{
    obj_begin("root");
    field_cls("kcl_module_t");
    field_str("filename", m->filename);
    dump_string_node("doc", m->doc);
    dump_stmt_node_list("body", &m->body);
    dump_comment_node_list("comments", &m->comments);
    obj_end();
}

static char* read_file(const char* path)
{
    FILE* f = fopen(path, "rb");
    if (f == NULL) {
        fprintf(stderr, "c dump: cannot read %s\n", path);
        return NULL;
    }
    if (fseek(f, 0, SEEK_END) != 0) {
        fclose(f);
        fprintf(stderr, "c dump: cannot size %s\n", path);
        return NULL;
    }
    long size = ftell(f);
    if (size < 0) {
        fclose(f);
        fprintf(stderr, "c dump: cannot size %s\n", path);
        return NULL;
    }
    rewind(f);

    char* text = (char*)malloc((size_t)size + 1);
    if (text == NULL) {
        fclose(f);
        fprintf(stderr, "c dump: out of memory\n");
        return NULL;
    }
    size_t got = fread(text, 1, (size_t)size, f);
    fclose(f);
    text[got] = '\0';
    return text;
}

int main(int argc, char** argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: c_dump <golden.json> <out.json>\n");
        return 2;
    }

    char* text = read_file(argv[1]);
    if (text == NULL)
        return 2;

    /* The binding's own decoder, unmodified. A NULL here is the decoder
     * refusing the capture, and the reason is already on stderr. */
    kcl_module_t* module = kcl_ast_parse_module(text);
    free(text);
    if (module == NULL) {
        fprintf(stderr, "c dump: kcl_ast_parse_module rejected the capture\n");
        return 1;
    }

    out = fopen(argv[2], "wb");
    if (out == NULL) {
        fprintf(stderr, "c dump: cannot write %s\n", argv[2]);
        kcl_module_free(module);
        return 2;
    }

    depth = 0;
    counts[0] = 0;
    obj_begin(NULL);
    field_str("schema", "kcl-ast-canonical/1");
    field_str("binding", "c");
    field_str("mode", "reflect");
    dump_module(module);
    obj_end();
    fputc('\n', out);

    if (fclose(out) != 0) {
        fprintf(stderr, "c dump: cannot write %s\n", argv[2]);
        kcl_module_free(module);
        return 2;
    }
    kcl_module_free(module);
    return 0;
}

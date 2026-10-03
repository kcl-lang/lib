/*
 * ast_contract.c — AST contract tests for the C binding.
 *
 * Decodes the shared golden capture at `testdata/ast/alignment.json`
 * into the typed AST and checks the *wire* contract: which tags exist,
 * which payloads are flattened, and which fields are optional.
 *
 * This is the half `ast_alignment.c` cannot cover. That one parses a
 * live fixture through `kcl_parse_file`, which proves the parser emits
 * something the loader accepts; this one proves the loader understands
 * the shapes the parser is *specified* to emit, and — the assertion
 * that matters most — that no tag anywhere in the document falls
 * through as unknown. A wrong tag decodes to a zero-valued struct
 * rather than failing, so field-by-field assertions on a handful of
 * nodes would sail through a decoder that resolves nothing at all.
 *
 * Build:
 *   $ make examples
 *   $ ./examples/ast_contract
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "kcl_lib_ast.h"

static int g_failures = 0;
static const char* g_fixture = NULL;

#define CHECK(cond, ...)                                    \
    do {                                                    \
        if (!(cond)) {                                      \
            fprintf(stderr, "    %s:%d: ", __FILE__, __LINE__); \
            fprintf(stderr, __VA_ARGS__);                   \
            fprintf(stderr, "\n");                          \
            g_failures++;                                   \
        }                                                   \
    } while (0)

/* ---------------------------------------------------------------- *
 * Fixture
 * ---------------------------------------------------------------- */

static const char* find_fixture(void)
{
    static const char* candidates[] = {
        "../testdata/ast/alignment.json",
        "testdata/ast/alignment.json",
        "../../testdata/ast/alignment.json",
        NULL,
    };
    for (size_t i = 0; candidates[i] != NULL; i++) {
        FILE* fp = fopen(candidates[i], "rb");
        if (fp != NULL) {
            fclose(fp);
            return candidates[i];
        }
    }
    fprintf(stderr, "could not locate testdata/ast/alignment.json\n");
    return NULL;
}

static char* read_file(const char* path)
{
    FILE* fp = fopen(path, "rb");
    if (fp == NULL)
        return NULL;
    fseek(fp, 0, SEEK_END);
    long n = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    if (n <= 0) {
        fclose(fp);
        return NULL;
    }
    char* buf = (char*)malloc((size_t)n + 1);
    if (buf == NULL) {
        fclose(fp);
        return NULL;
    }
    size_t got = fread(buf, 1, (size_t)n, fp);
    buf[got] = '\0';
    fclose(fp);
    return buf;
}

/* ---------------------------------------------------------------- *
 * Unresolved-tag walker
 * ---------------------------------------------------------------- */

static void walk_expr(const kcl_expr_t* e, char** unknown, size_t* unknown_count);
static void walk_stmt(const kcl_stmt_t* s, char** unknown, size_t* unknown_count);
static void walk_type(const kcl_type_node_t* t, char** unknown, size_t* unknown_count);
static void walk_expr_ref(const kcl_expr_node_t* n, char** unknown, size_t* unknown_count)
{
    if (n != NULL)
        walk_expr((const kcl_expr_t*)n->node, unknown, unknown_count);
}
static void walk_type_ref(const kcl_type_ref_node_t* n, char** unknown, size_t* unknown_count)
{
    if (n != NULL)
        walk_type((const kcl_type_node_t*)n->node, unknown, unknown_count);
}
static void walk_stmt_ref(const kcl_stmt_node_t* n, char** unknown, size_t* unknown_count)
{
    if (n != NULL)
        walk_stmt((const kcl_stmt_t*)n->node, unknown, unknown_count);
}

static void record_unknown(char** unknown, size_t* count, const char* what, const char* tag)
{
    const char* tag_text = tag != NULL ? tag : "(no tag)";
    char buf[256];
    snprintf(buf, sizeof(buf), "%s.%s", what, tag_text);
    unknown[*count] = strdup(buf);
    (*count)++;
}

static void walk_expr(const kcl_expr_t* e, char** unknown, size_t* unknown_count)
{
    if (e == NULL)
        return;
    if (e->kind == KCL_EXPR_KIND_UNKNOWN) {
        record_unknown(unknown, unknown_count, "Expr", e->type_tag);
        return;
    }
    switch (e->kind) {
    case KCL_EXPR_KIND_TARGET:
    case KCL_EXPR_KIND_IDENTIFIER:
        break; /* no children */
    case KCL_EXPR_KIND_UNARY:
        walk_expr_ref(&e->u.unary_expr.operand, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_BINARY:
        walk_expr_ref(&e->u.binary_expr.left, unknown, unknown_count);
        walk_expr_ref(&e->u.binary_expr.right, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_IF:
        walk_expr_ref(&e->u.if_expr.body, unknown, unknown_count);
        walk_expr_ref(&e->u.if_expr.cond, unknown, unknown_count);
        walk_expr_ref(&e->u.if_expr.orelse, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_SELECTOR:
        walk_expr_ref(&e->u.selector_expr.value, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_CALL:
        walk_expr_ref(&e->u.call_expr.func, unknown, unknown_count);
        for (size_t i = 0; i < e->u.call_expr.args.count; i++)
            walk_expr_ref(&e->u.call_expr.args.items[i], unknown, unknown_count);
        for (size_t i = 0; i < e->u.call_expr.keywords.count; i++) {
            const kcl_keyword_t* kw =
                (const kcl_keyword_t*)e->u.call_expr.keywords.items[i].node;
            if (kw != NULL)
                walk_expr_ref(kw->value, unknown, unknown_count);
        }
        break;
    case KCL_EXPR_KIND_PAREN:
        walk_expr_ref(&e->u.paren_expr.expr, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_QUANT:
        walk_expr_ref(&e->u.quant_expr.target, unknown, unknown_count);
        walk_expr_ref(&e->u.quant_expr.test, unknown, unknown_count);
        walk_expr_ref(e->u.quant_expr.if_cond, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_LIST:
        for (size_t i = 0; i < e->u.list_expr.elts.count; i++)
            walk_expr_ref(&e->u.list_expr.elts.items[i], unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_LIST_IF_ITEM:
        walk_expr_ref(&e->u.list_if_item_expr.if_cond, unknown, unknown_count);
        for (size_t i = 0; i < e->u.list_if_item_expr.exprs.count; i++)
            walk_expr_ref(&e->u.list_if_item_expr.exprs.items[i], unknown, unknown_count);
        walk_expr_ref(e->u.list_if_item_expr.orelse, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_LIST_COMP:
        walk_expr_ref(&e->u.list_comp.elt, unknown, unknown_count);
        for (size_t i = 0; i < e->u.list_comp.generators.count; i++) {
            const kcl_comp_clause_t* c =
                (const kcl_comp_clause_t*)e->u.list_comp.generators.items[i].node;
            if (c != NULL) {
                walk_expr_ref(&c->iter, unknown, unknown_count);
                for (size_t j = 0; j < c->ifs.count; j++)
                    walk_expr_ref(&c->ifs.items[j], unknown, unknown_count);
            }
        }
        break;
    case KCL_EXPR_KIND_STARRED:
        walk_expr_ref(&e->u.starred_expr.value, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_DICT_COMP:
        walk_expr_ref(e->u.dict_comp.entry.key, unknown, unknown_count);
        walk_expr_ref(&e->u.dict_comp.entry.value, unknown, unknown_count);
        for (size_t i = 0; i < e->u.dict_comp.generators.count; i++) {
            const kcl_comp_clause_t* c =
                (const kcl_comp_clause_t*)e->u.dict_comp.generators.items[i].node;
            if (c != NULL) {
                walk_expr_ref(&c->iter, unknown, unknown_count);
                for (size_t j = 0; j < c->ifs.count; j++)
                    walk_expr_ref(&c->ifs.items[j], unknown, unknown_count);
            }
        }
        break;
    case KCL_EXPR_KIND_CONFIG_IF_ENTRY:
        walk_expr_ref(&e->u.config_if_entry_expr.if_cond, unknown, unknown_count);
        for (size_t i = 0; i < e->u.config_if_entry_expr.items.count; i++) {
            const kcl_config_entry_t* entry =
                (const kcl_config_entry_t*)e->u.config_if_entry_expr.items.items[i].node;
            if (entry != NULL) {
                walk_expr_ref(entry->key, unknown, unknown_count);
                walk_expr_ref(&entry->value, unknown, unknown_count);
            }
        }
        walk_expr_ref(e->u.config_if_entry_expr.orelse, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_COMP_CLAUSE:
        walk_expr_ref(&e->u.comp_clause.iter, unknown, unknown_count);
        for (size_t i = 0; i < e->u.comp_clause.ifs.count; i++)
            walk_expr_ref(&e->u.comp_clause.ifs.items[i], unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_SCHEMA:
        walk_expr_ref(&e->u.schema_expr.config, unknown, unknown_count);
        for (size_t i = 0; i < e->u.schema_expr.args.count; i++)
            walk_expr_ref(&e->u.schema_expr.args.items[i], unknown, unknown_count);
        for (size_t i = 0; i < e->u.schema_expr.kwargs.count; i++) {
            const kcl_keyword_t* kw =
                (const kcl_keyword_t*)e->u.schema_expr.kwargs.items[i].node;
            if (kw != NULL)
                walk_expr_ref(kw->value, unknown, unknown_count);
        }
        break;
    case KCL_EXPR_KIND_CONFIG:
        for (size_t i = 0; i < e->u.config_expr.items.count; i++) {
            const kcl_config_entry_t* entry =
                (const kcl_config_entry_t*)e->u.config_expr.items.items[i].node;
            if (entry != NULL) {
                walk_expr_ref(entry->key, unknown, unknown_count);
                walk_expr_ref(&entry->value, unknown, unknown_count);
            }
        }
        break;
    case KCL_EXPR_KIND_CHECK:
        walk_expr_ref(&e->u.check_expr.test, unknown, unknown_count);
        walk_expr_ref(e->u.check_expr.if_cond, unknown, unknown_count);
        walk_expr_ref(e->u.check_expr.msg, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_LAMBDA:
        for (size_t i = 0; i < e->u.lambda_expr.body.count; i++)
            walk_stmt_ref(&e->u.lambda_expr.body.items[i], unknown, unknown_count);
        walk_type_ref(e->u.lambda_expr.return_ty, unknown, unknown_count);
        if (e->u.lambda_expr.args != NULL) {
            const kcl_arguments_t* args = (const kcl_arguments_t*)e->u.lambda_expr.args->node;
            if (args != NULL) {
                for (size_t i = 0; i < args->defaults.count; i++) {
                    if (args->defaults.items[i].present)
                        walk_expr_ref(&args->defaults.items[i].value, unknown, unknown_count);
                }
                for (size_t i = 0; i < args->ty_list.count; i++) {
                    if (args->ty_list.items[i].present)
                        walk_type_ref(&args->ty_list.items[i].value, unknown, unknown_count);
                }
            }
        }
        break;
    case KCL_EXPR_KIND_SUBSCRIPT:
        walk_expr_ref(&e->u.subscript_expr.value, unknown, unknown_count);
        walk_expr_ref(e->u.subscript_expr.index, unknown, unknown_count);
        walk_expr_ref(e->u.subscript_expr.lower, unknown, unknown_count);
        walk_expr_ref(e->u.subscript_expr.upper, unknown, unknown_count);
        walk_expr_ref(e->u.subscript_expr.step, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_KEYWORD:
        walk_expr_ref(e->u.keyword.value, unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_ARGUMENTS:
        for (size_t i = 0; i < e->u.arguments.defaults.count; i++) {
            if (e->u.arguments.defaults.items[i].present)
                walk_expr_ref(&e->u.arguments.defaults.items[i].value, unknown, unknown_count);
        }
        for (size_t i = 0; i < e->u.arguments.ty_list.count; i++) {
            if (e->u.arguments.ty_list.items[i].present)
                walk_type_ref(&e->u.arguments.ty_list.items[i].value, unknown, unknown_count);
        }
        break;
    case KCL_EXPR_KIND_COMPARE:
        walk_expr_ref(&e->u.compare_expr.left, unknown, unknown_count);
        for (size_t i = 0; i < e->u.compare_expr.comparators.count; i++)
            walk_expr_ref(&e->u.compare_expr.comparators.items[i], unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_JOINED_STRING:
        for (size_t i = 0; i < e->u.joined_string.values.count; i++)
            walk_expr_ref(&e->u.joined_string.values.items[i], unknown, unknown_count);
        break;
    case KCL_EXPR_KIND_FORMATTED_VALUE:
        walk_expr_ref(&e->u.formatted_value.value, unknown, unknown_count);
        break;
    default:
        break;
    }
}

static void walk_stmt(const kcl_stmt_t* s, char** unknown, size_t* unknown_count)
{
    if (s == NULL)
        return;
    if (s->kind == KCL_STMT_KIND_UNKNOWN) {
        record_unknown(unknown, unknown_count, "Stmt", s->type_tag);
        return;
    }
    switch (s->kind) {
    case KCL_STMT_KIND_TYPE_ALIAS:
        walk_type_ref(&s->u.type_alias_stmt.ty, unknown, unknown_count);
        break;
    case KCL_STMT_KIND_EXPR:
        for (size_t i = 0; i < s->u.expr_stmt.exprs.count; i++)
            walk_expr_ref(&s->u.expr_stmt.exprs.items[i], unknown, unknown_count);
        break;
    case KCL_STMT_KIND_UNIFICATION: {
        /* `value` is a `NodeRef<SchemaExpr>`, so the config is one level
         * deeper than it looks. */
        const kcl_schema_expr_t* se =
            (const kcl_schema_expr_t*)s->u.unification_stmt.value.node;
        if (se != NULL) {
            walk_expr_ref(&se->config, unknown, unknown_count);
            for (size_t i = 0; i < se->args.count; i++)
                walk_expr_ref(&se->args.items[i], unknown, unknown_count);
            for (size_t i = 0; i < se->kwargs.count; i++) {
                const kcl_keyword_t* kw =
                    (const kcl_keyword_t*)se->kwargs.items[i].node;
                if (kw != NULL)
                    walk_expr_ref(kw->value, unknown, unknown_count);
            }
        }
        break;
    }
    case KCL_STMT_KIND_ASSIGN:
        for (size_t i = 0; i < s->u.assign_stmt.targets.count; i++) {
            const kcl_target_t* t =
                (const kcl_target_t*)s->u.assign_stmt.targets.items[i].node;
            if (t != NULL) {
                for (size_t j = 0; j < t->paths_count; j++)
                    walk_expr_ref(t->paths[j].index, unknown, unknown_count);
            }
        }
        walk_expr_ref(&s->u.assign_stmt.value, unknown, unknown_count);
        walk_type_ref(s->u.assign_stmt.ty, unknown, unknown_count);
        break;
    case KCL_STMT_KIND_AUG_ASSIGN: {
        const kcl_target_t* t = (const kcl_target_t*)s->u.aug_assign_stmt.target.node;
        if (t != NULL) {
            for (size_t j = 0; j < t->paths_count; j++)
                walk_expr_ref(t->paths[j].index, unknown, unknown_count);
        }
        walk_expr_ref(&s->u.aug_assign_stmt.value, unknown, unknown_count);
        break;
    }
    case KCL_STMT_KIND_ASSERT:
        walk_expr_ref(&s->u.assert_stmt.test, unknown, unknown_count);
        walk_expr_ref(s->u.assert_stmt.if_cond, unknown, unknown_count);
        walk_expr_ref(s->u.assert_stmt.msg, unknown, unknown_count);
        break;
    case KCL_STMT_KIND_IF:
        walk_expr_ref(&s->u.if_stmt.cond, unknown, unknown_count);
        for (size_t i = 0; i < s->u.if_stmt.body.count; i++)
            walk_stmt_ref(&s->u.if_stmt.body.items[i], unknown, unknown_count);
        for (size_t i = 0; i < s->u.if_stmt.orelse.count; i++)
            walk_stmt_ref(&s->u.if_stmt.orelse.items[i], unknown, unknown_count);
        break;
    case KCL_STMT_KIND_IMPORT:
    case KCL_STMT_KIND_RULE:
        break;
    case KCL_STMT_KIND_SCHEMA_ATTR:
        walk_expr_ref(s->u.schema_attr.value, unknown, unknown_count);
        walk_type_ref(&s->u.schema_attr.ty, unknown, unknown_count);
        for (size_t i = 0; i < s->u.schema_attr.decorators.count; i++) {
            const kcl_call_expr_t* d =
                (const kcl_call_expr_t*)s->u.schema_attr.decorators.items[i].node;
            if (d != NULL) {
                walk_expr_ref(&d->func, unknown, unknown_count);
                for (size_t j = 0; j < d->args.count; j++)
                    walk_expr_ref(&d->args.items[j], unknown, unknown_count);
            }
        }
        break;
    case KCL_STMT_KIND_SCHEMA:
        for (size_t i = 0; i < s->u.schema_stmt.body.count; i++)
            walk_stmt_ref(&s->u.schema_stmt.body.items[i], unknown, unknown_count);
        for (size_t i = 0; i < s->u.schema_stmt.decorators.count; i++) {
            const kcl_call_expr_t* d =
                (const kcl_call_expr_t*)s->u.schema_stmt.decorators.items[i].node;
            if (d != NULL) {
                walk_expr_ref(&d->func, unknown, unknown_count);
                for (size_t j = 0; j < d->args.count; j++)
                    walk_expr_ref(&d->args.items[j], unknown, unknown_count);
            }
        }
        for (size_t i = 0; i < s->u.schema_stmt.checks.count; i++) {
            const kcl_check_expr_t* c =
                (const kcl_check_expr_t*)s->u.schema_stmt.checks.items[i].node;
            if (c != NULL) {
                walk_expr_ref(&c->test, unknown, unknown_count);
                walk_expr_ref(c->if_cond, unknown, unknown_count);
                walk_expr_ref(c->msg, unknown, unknown_count);
            }
        }
        if (s->u.schema_stmt.index_signature != NULL) {
            const kcl_schema_index_signature_t* sig =
                (const kcl_schema_index_signature_t*)s->u.schema_stmt.index_signature->node;
            if (sig != NULL) {
                walk_expr_ref(sig->value, unknown, unknown_count);
                walk_type_ref(&sig->key_ty, unknown, unknown_count);
                walk_type_ref(&sig->value_ty, unknown, unknown_count);
            }
        }
        break;
    default:
        break;
    }
}

static void walk_type(const kcl_type_node_t* t, char** unknown, size_t* unknown_count)
{
    if (t == NULL)
        return;
    if (t->kind == KCL_TYPE_KIND_UNKNOWN) {
        record_unknown(unknown, unknown_count, "Type", t->type_tag);
        return;
    }
    switch (t->kind) {
    case KCL_TYPE_KIND_ANY:
    case KCL_TYPE_KIND_NAMED:
    case KCL_TYPE_KIND_BASIC:
    case KCL_TYPE_KIND_LITERAL:
        break;
    case KCL_TYPE_KIND_LIST:
        walk_type_ref(t->u.list_type.inner_type, unknown, unknown_count);
        break;
    case KCL_TYPE_KIND_DICT:
        walk_type_ref(t->u.dict_type.key_type, unknown, unknown_count);
        walk_type_ref(t->u.dict_type.value_type, unknown, unknown_count);
        break;
    case KCL_TYPE_KIND_UNION:
        for (size_t i = 0; i < t->u.union_type.type_elements.count; i++)
            walk_type_ref(&t->u.union_type.type_elements.items[i], unknown, unknown_count);
        break;
    case KCL_TYPE_KIND_FUNCTION:
        if (t->u.function_type.params_ty != NULL) {
            for (size_t i = 0; i < t->u.function_type.params_ty->count; i++)
                walk_type_ref(&t->u.function_type.params_ty->items[i], unknown, unknown_count);
        }
        walk_type_ref(t->u.function_type.ret_ty, unknown, unknown_count);
        break;
    default:
        break;
    }
}

/* ---------------------------------------------------------------- *
 * Lookups
 * ---------------------------------------------------------------- */

static const kcl_stmt_t* find_schema(const kcl_module_t* m, const char* name)
{
    for (size_t i = 0; i < m->body.count; i++) {
        const kcl_stmt_t* s = (const kcl_stmt_t*)m->body.items[i].node;
        if (s == NULL || s->kind != KCL_STMT_KIND_SCHEMA)
            continue;
        if (s->u.schema_stmt.name.node != NULL
            && strcmp(s->u.schema_stmt.name.node, name) == 0)
            return s;
    }
    return NULL;
}

static const kcl_stmt_t* find_assign(const kcl_module_t* m, const char* name)
{
    for (size_t i = 0; i < m->body.count; i++) {
        const kcl_stmt_t* s = (const kcl_stmt_t*)m->body.items[i].node;
        if (s == NULL || s->kind != KCL_STMT_KIND_ASSIGN || s->u.assign_stmt.targets.count == 0)
            continue;
        const kcl_target_t* t =
            (const kcl_target_t*)s->u.assign_stmt.targets.items[0].node;
        if (t != NULL && t->name.node != NULL && strcmp(t->name.node, name) == 0)
            return s;
    }
    return NULL;
}

static const kcl_stmt_t* find_type_alias(const kcl_module_t* m, const char* name)
{
    for (size_t i = 0; i < m->body.count; i++) {
        const kcl_stmt_t* s = (const kcl_stmt_t*)m->body.items[i].node;
        if (s == NULL || s->kind != KCL_STMT_KIND_TYPE_ALIAS)
            continue;
        const kcl_identifier_t* id = (const kcl_identifier_t*)s->u.type_alias_stmt.type_name.node;
        if (id != NULL && id->names.count > 0 && id->names.items[0].node != NULL
            && strcmp(id->names.items[0].node, name) == 0)
            return s;
    }
    return NULL;
}

static const kcl_expr_t* assign_value(const kcl_module_t* m, const char* name)
{
    const kcl_stmt_t* s = find_assign(m, name);
    if (s == NULL)
        return NULL;
    return (const kcl_expr_t*)s->u.assign_stmt.value.node;
}

static const char* identifier_dotted(const kcl_identifier_t* id)
{
    static char buf[512];
    buf[0] = '\0';
    if (id == NULL)
        return buf;
    for (size_t i = 0; i < id->names.count; i++) {
        if (i > 0)
            strncat(buf, ".", sizeof(buf) - strlen(buf) - 1);
        if (id->names.items[i].node != NULL)
            strncat(buf, id->names.items[i].node, sizeof(buf) - strlen(buf) - 1);
    }
    return buf;
}

/* `NodeRef<Identifier>` wrapper — the payload is one indirection down. */
static const char* identifier_dotted_ref(const kcl_identifier_node_t* n)
{
    return identifier_dotted((const kcl_identifier_t*)(n != NULL ? n->node : NULL));
}

/* ---------------------------------------------------------------- *
 * Tests
 * ---------------------------------------------------------------- */

typedef void (*test_fn)(const kcl_module_t* m);

static void test_module_shape(const kcl_module_t* m)
{
    CHECK(m->filename != NULL, "module filename is NULL");
    if (m->filename != NULL)
        CHECK(strstr(m->filename, ".k") != NULL, "filename %s is not a .k file", m->filename);
    CHECK(m->body.count > 0, "module has no statements");
    /* `comments` is `Vec<NodeRef<Comment>>`, so the payload is `{text}`
     * rather than a bare string. */
    CHECK(m->comments.count > 0, "module has no comments");
    if (m->comments.count > 0) {
        const kcl_comment_t* c = (const kcl_comment_t*)m->comments.items[0].node;
        CHECK(c != NULL && c->text != NULL, "comment 0 has no text");
    }
    /* Positions are flat on the wrapper, so a `pos` with a line number
     * proves the loader is reading `line` and not looking for a nested
     * `pos` object. */
    CHECK(m->body.items[0].pos != NULL, "statement 0 has no position");
    if (m->body.items[0].pos != NULL) {
        CHECK(m->body.items[0].pos->line > 0, "statement 0 has line %lld",
            (long long)m->body.items[0].pos->line);
        CHECK(m->body.items[0].pos->filename != NULL, "statement 0 has no filename");
    }
}

static void test_import_is_flat(const kcl_module_t* m)
{
    const kcl_stmt_t* s = (const kcl_stmt_t*)m->body.items[0].node;
    CHECK(s != NULL && s->kind == KCL_STMT_KIND_IMPORT, "statement 0 is not an Import");
    if (s == NULL || s->kind != KCL_STMT_KIND_IMPORT)
        return;
    const kcl_import_stmt_t* imp = &s->u.import_stmt;
    /* `path` is a `Node<String>`, so it carries a position of its own. */
    CHECK(imp->path.node != NULL, "import path is NULL");
    if (imp->path.node != NULL)
        CHECK(imp->path.pos != NULL, "import path has no position");
    CHECK(imp->rawpath != NULL, "import rawpath is NULL");
    CHECK(imp->name != NULL, "import name is NULL");
    CHECK(imp->pkg_name != NULL, "import pkg_name is NULL");
    /* There is no `pkg_root` field on the wire. */
    CHECK(imp->pkg_name[0] == '_' || imp->pkg_name[0] != '\0',
        "import pkg_name is empty");
}

static void test_unification_target_is_a_store_identifier(const kcl_module_t* m)
{
    const kcl_stmt_t* found = NULL;
    for (size_t i = 0; i < m->body.count; i++) {
        const kcl_stmt_t* s = (const kcl_stmt_t*)m->body.items[i].node;
        if (s != NULL && s->kind == KCL_STMT_KIND_UNIFICATION) {
            found = s;
            break;
        }
    }
    CHECK(found != NULL, "no Unification statement in the fixture");
    if (found == NULL)
        return;
    /* `target` is an `Identifier`, not a `Target` — so it has a `ctx`. */
    const kcl_identifier_t* id =
        (const kcl_identifier_t*)found->u.unification_stmt.target.node;
    CHECK(id != NULL, "unification target is NULL");
    if (id == NULL)
        return;
    CHECK(id->ctx == KCL_EXPR_CONTEXT_STORE, "unification target ctx is %s, want Store",
        kcl_expr_context_name(id->ctx));
    /* `value` is a `SchemaExpr`, not an invented config struct. */
    const kcl_schema_expr_t* se =
        (const kcl_schema_expr_t*)found->u.unification_stmt.value.node;
    CHECK(se != NULL, "unification value is NULL");
    if (se != NULL)
        CHECK(strcmp(identifier_dotted_ref(&se->name), "Person") == 0,
            "unification schema name is %s, want Person", identifier_dotted_ref(&se->name));
}

static void test_aug_assign_and_assert(const kcl_module_t* m)
{
    int saw_aug = 0, saw_assert = 0, saw_if = 0;
    for (size_t i = 0; i < m->body.count; i++) {
        const kcl_stmt_t* s = (const kcl_stmt_t*)m->body.items[i].node;
        if (s == NULL)
            continue;
        if (s->kind == KCL_STMT_KIND_AUG_ASSIGN) {
            saw_aug = 1;
            const kcl_target_t* t =
                (const kcl_target_t*)s->u.aug_assign_stmt.target.node;
            CHECK(t != NULL, "AugAssign target is NULL");
            if (t != NULL)
                CHECK(t->name.node != NULL && strcmp(t->name.node, "a") == 0,
                    "AugAssign target is %s, want a", t->name.node);
        } else if (s->kind == KCL_STMT_KIND_ASSERT) {
            saw_assert = 1;
            /* `AssertStmt` is `{test, if_cond, msg}` — all NodeRefs. */
            CHECK(s->u.assert_stmt.test.node != NULL, "Assert has no test");
        } else if (s->kind == KCL_STMT_KIND_IF) {
            saw_if = 1;
            /* `orelse` is `Vec<NodeRef<Stmt>>`, not an expression. */
            CHECK(s->u.if_stmt.cond.node != NULL, "If has no cond");
        }
    }
    CHECK(saw_aug, "no AugAssign statement in the fixture");
    CHECK(saw_assert, "no Assert statement in the fixture");
    CHECK(saw_if, "no If statement in the fixture");
}

static void test_rule_stmt(const kcl_module_t* m)
{
    const kcl_stmt_t* found = NULL;
    for (size_t i = 0; i < m->body.count; i++) {
        const kcl_stmt_t* s = (const kcl_stmt_t*)m->body.items[i].node;
        if (s != NULL && s->kind == KCL_STMT_KIND_RULE) {
            found = s;
            break;
        }
    }
    CHECK(found != NULL, "no Rule statement in the fixture");
    if (found == NULL)
        return;
    CHECK(found->u.rule_stmt.name.node != NULL, "Rule has no name");
    /* `decorators` and `checks` are `Vec<NodeRef<…>>` over structs, so
     * neither element carries a tag. The fixture's rule is undecorated,
     * which is itself the assertion: a decoder that invented a tag
     * would not be able to produce an empty list here. */
    CHECK(found->u.rule_stmt.decorators.count == 0, "Rule has %zu decorators, want 0",
        found->u.rule_stmt.decorators.count);
    CHECK(found->u.rule_stmt.checks.count > 0, "Rule has no checks");
    if (found->u.rule_stmt.checks.count > 0) {
        const kcl_check_expr_t* c =
            (const kcl_check_expr_t*)found->u.rule_stmt.checks.items[0].node;
        CHECK(c != NULL, "Rule check is NULL");
        if (c != NULL)
            CHECK(c->test.node != NULL, "Rule check has no test");
    }
}

static void test_schema_decorators_are_flat_call_exprs(const kcl_module_t* m)
{
    const kcl_stmt_t* person = find_schema(m, "Person");
    CHECK(person != NULL, "no Person schema in the fixture");
    if (person == NULL)
        return;
    /* `@deprecated` and `@info` are on the `name` attribute, not on the
     * schema header, so the schema's own list is empty. */
    CHECK(person->u.schema_stmt.decorators.count == 0,
        "Person has %zu schema decorators, want 0", person->u.schema_stmt.decorators.count);
    CHECK(person->u.schema_stmt.checks.count > 0, "Person has no checks");
    if (person->u.schema_stmt.checks.count > 0) {
        const kcl_check_expr_t* c =
            (const kcl_check_expr_t*)person->u.schema_stmt.checks.items[0].node;
        CHECK(c != NULL && c->test.node != NULL, "Person check has no test");
        CHECK(c != NULL && c->msg != NULL, "Person check has no msg");
    }
    const kcl_stmt_t* name_attr = (const kcl_stmt_t*)person->u.schema_stmt.body.items[0].node;
    CHECK(name_attr != NULL && name_attr->kind == KCL_STMT_KIND_SCHEMA_ATTR,
        "Person's first body statement is not a SchemaAttr");
    if (name_attr == NULL)
        return;
    /* `SchemaAttr.doc` is a plain `String`, not a `NodeRef<String>`. */
    CHECK(name_attr->u.schema_attr.doc != NULL, "SchemaAttr doc is NULL");
    CHECK(name_attr->u.schema_attr.decorators.count == 2,
        "SchemaAttr has %zu decorators, want 2", name_attr->u.schema_attr.decorators.count);
    /* `ty` is `NodeRef<Type>`, not an Option. */
    CHECK(name_attr->u.schema_attr.ty.node != NULL, "SchemaAttr ty is NULL");
    if (name_attr->u.schema_attr.ty.node != NULL) {
        const kcl_type_node_t* ty =
            (const kcl_type_node_t*)name_attr->u.schema_attr.ty.node;
        CHECK(ty->kind == KCL_TYPE_KIND_BASIC, "SchemaAttr ty is not a Basic type");
        if (ty->kind == KCL_TYPE_KIND_BASIC)
            CHECK(ty->u.basic_type.basic == KCL_BASIC_TYPE_STR,
                "SchemaAttr ty is not Str");
    }
    if (name_attr->u.schema_attr.decorators.count == 2) {
        const kcl_call_expr_t* d =
            (const kcl_call_expr_t*)name_attr->u.schema_attr.decorators.items[0].node;
        CHECK(d != NULL, "SchemaAttr decorator is NULL");
        if (d != NULL) {
            /* A decorator payload is a bare `{func,args,keywords}`; the
             * `func` is a `NodeRef<Expr>` that *does* carry a tag. */
            CHECK(d->args.count == 0, "@deprecated should have no positional args");
            const kcl_expr_t* fn = (const kcl_expr_t*)d->func.node;
            CHECK(fn != NULL && fn->kind == KCL_EXPR_KIND_IDENTIFIER,
                "decorator func is not an Identifier");
            if (fn != NULL && fn->kind == KCL_EXPR_KIND_IDENTIFIER)
                CHECK(strcmp(identifier_dotted(&fn->u.identifier), "deprecated") == 0,
                    "decorator func is %s, want deprecated",
                    identifier_dotted(&fn->u.identifier));
        }
    }
}

static void test_schema_expr_is_not_a_call(const kcl_module_t* m)
{
    /* `x = Person {…}` puts its entries in `config` and leaves
     * `keywords` empty; `y = Person(1, name = "Bob")` is a plain Call. */
    const kcl_expr_t* x = assign_value(m, "x");
    CHECK(x != NULL, "no `x` assignment");
    if (x != NULL) {
        CHECK(x->kind == KCL_EXPR_KIND_SCHEMA, "`x` RHS is not a SchemaExpr");
        if (x->kind == KCL_EXPR_KIND_SCHEMA) {
            CHECK(x->u.schema_expr.kwargs.count == 0, "`x` SchemaExpr has keywords");
            const kcl_expr_t* config =
                (const kcl_expr_t*)x->u.schema_expr.config.node;
            CHECK(config != NULL && config->kind == KCL_EXPR_KIND_CONFIG,
                "`x` config is not a ConfigExpr");
        }
    }
    const kcl_expr_t* y = assign_value(m, "y");
    CHECK(y != NULL, "no `y` assignment");
    if (y != NULL) {
        CHECK(y->kind == KCL_EXPR_KIND_CALL, "`y` RHS is not a Call");
        if (y->kind == KCL_EXPR_KIND_CALL) {
            CHECK(y->u.call_expr.args.count == 1, "`y` has %zu positional args, want 1",
                y->u.call_expr.args.count);
            /* `Keyword.arg` is a `NodeRef<Identifier>`, not an Expr. */
            CHECK(y->u.call_expr.keywords.count == 1, "`y` has %zu keywords, want 1",
                y->u.call_expr.keywords.count);
            if (y->u.call_expr.keywords.count == 1) {
                const kcl_keyword_t* kw =
                    (const kcl_keyword_t*)y->u.call_expr.keywords.items[0].node;
                CHECK(kw != NULL, "`y` keyword is NULL");
                if (kw != NULL) {
                    const kcl_identifier_t* arg =
                        (const kcl_identifier_t*)kw->arg.node;
                    CHECK(strcmp(identifier_dotted(arg), "name") == 0,
                        "`y` keyword arg is %s, want name", identifier_dotted(arg));
                    CHECK(kw->value != NULL && kw->value->node != NULL,
                        "`y` keyword has no value");
                }
            }
        }
    }
}

static void test_unary_binary_compare(const kcl_module_t* m)
{
    /* `-a` is `USub`, not a generic "negate". */
    const kcl_expr_t* unary = assign_value(m, "unary");
    CHECK(unary != NULL && unary->kind == KCL_EXPR_KIND_UNARY, "no `unary` UnaryExpr");
    if (unary != NULL && unary->kind == KCL_EXPR_KIND_UNARY)
        CHECK(unary->u.unary_expr.op == KCL_UNARY_OP_USUB, "`unary` op is %s, want USub",
            kcl_unary_op_name(unary->u.unary_expr.op));
    const kcl_expr_t* unary_not = assign_value(m, "unary_not");
    CHECK(unary_not != NULL && unary_not->kind == KCL_EXPR_KIND_UNARY,
        "no `unary_not` UnaryExpr");
    if (unary_not != NULL && unary_not->kind == KCL_EXPR_KIND_UNARY)
        CHECK(unary_not->u.unary_expr.op == KCL_UNARY_OP_NOT,
            "`unary_not` op is %s, want Not", kcl_unary_op_name(unary_not->u.unary_expr.op));

    /* `ops` and `comparators` are parallel arrays. */
    const kcl_expr_t* chain = assign_value(m, "compare_chain");
    CHECK(chain != NULL && chain->kind == KCL_EXPR_KIND_COMPARE, "no `compare_chain` Compare");
    if (chain != NULL && chain->kind == KCL_EXPR_KIND_COMPARE) {
        CHECK(chain->u.compare_expr.ops_count == chain->u.compare_expr.comparators.count,
            "Compare has %zu ops but %zu comparators", chain->u.compare_expr.ops_count,
            chain->u.compare_expr.comparators.count);
        for (size_t i = 0; i < chain->u.compare_expr.ops_count; i++)
            CHECK(kcl_cmp_op_name(chain->u.compare_expr.ops[i])[0] != '?',
                "unrecognised comparison operator at %zu", i);
    }
}

static void test_selector_and_subscript(const kcl_module_t* m)
{
    /* `Selector.attr` is an `Identifier`, and `has_question` is the
     * optional-access flag — there is no `attr_name` field. */
    const kcl_expr_t* optional = assign_value(m, "optional");
    CHECK(optional != NULL && optional->kind == KCL_EXPR_KIND_SELECTOR,
        "no `optional` SelectorExpr");
    if (optional != NULL && optional->kind == KCL_EXPR_KIND_SELECTOR)
        CHECK(optional->u.selector_expr.has_question, "`optional` has_question is false");
    const kcl_expr_t* selector = assign_value(m, "selector");
    CHECK(selector != NULL && selector->kind == KCL_EXPR_KIND_SELECTOR,
        "no `selector` SelectorExpr");

    /* A slice puts its bounds in `lower`/`upper`/`step` and leaves
     * `index` null. */
    const kcl_expr_t* slice = assign_value(m, "subscript_slice");
    CHECK(slice != NULL && slice->kind == KCL_EXPR_KIND_SUBSCRIPT,
        "no `subscript_slice` Subscript");
    if (slice != NULL && slice->kind == KCL_EXPR_KIND_SUBSCRIPT) {
        CHECK(slice->u.subscript_expr.index == NULL, "slice has a non-null index");
        CHECK(slice->u.subscript_expr.lower != NULL, "slice has no lower bound");
        CHECK(slice->u.subscript_expr.upper != NULL, "slice has no upper bound");
    }
    const kcl_expr_t* step = assign_value(m, "subscript_step");
    CHECK(step != NULL && step->kind == KCL_EXPR_KIND_SUBSCRIPT,
        "no `subscript_step` Subscript");
    if (step != NULL && step->kind == KCL_EXPR_KIND_SUBSCRIPT) {
        CHECK(step->u.subscript_expr.step != NULL, "subscript_step has no step");
        CHECK(step->u.subscript_expr.lower != NULL, "subscript_step has no lower bound");
        CHECK(step->u.subscript_expr.upper != NULL, "subscript_step has no upper bound");
    }
    /* `subscript_q` is `a?.b` — an optional *Selector*, not a Subscript.
     * The two are easy to confuse, and `has_question` lives on both. */
    const kcl_expr_t* q = assign_value(m, "subscript_q");
    CHECK(q != NULL && q->kind == KCL_EXPR_KIND_SELECTOR, "no `subscript_q` Selector");
    if (q != NULL && q->kind == KCL_EXPR_KIND_SELECTOR)
        CHECK(q->u.selector_expr.has_question, "subscript_q has_question is false");
    const kcl_expr_t* plain = assign_value(m, "subscript");
    CHECK(plain != NULL && plain->kind == KCL_EXPR_KIND_SUBSCRIPT, "no `subscript` Subscript");
    if (plain != NULL && plain->kind == KCL_EXPR_KIND_SUBSCRIPT)
        CHECK(plain->u.subscript_expr.index != NULL, "subscript has no index");
}

static void test_config_entries(const kcl_module_t* m)
{
    /* `config = {a = 1, b: 2}` uses Override then Union. */
    const kcl_expr_t* config = assign_value(m, "config");
    CHECK(config != NULL && config->kind == KCL_EXPR_KIND_CONFIG, "no `config` ConfigExpr");
    if (config != NULL && config->kind == KCL_EXPR_KIND_CONFIG) {
        CHECK(config->u.config_expr.items.count == 2, "config has %zu entries, want 2",
            config->u.config_expr.items.count);
        if (config->u.config_expr.items.count == 2) {
            const kcl_config_entry_t* a =
                (const kcl_config_entry_t*)config->u.config_expr.items.items[0].node;
            const kcl_config_entry_t* b =
                (const kcl_config_entry_t*)config->u.config_expr.items.items[1].node;
            CHECK(a != NULL && a->operation == KCL_CONFIG_ENTRY_OPERATION_OVERRIDE,
                "config[0] operation is not Override");
            CHECK(b != NULL && b->operation == KCL_CONFIG_ENTRY_OPERATION_UNION,
                "config[1] operation is not Union");
            /* `skip_serializing_if = "is_false"`, so the key is absent
             * rather than explicitly false. */
            CHECK(a != NULL && !a->is_shorthand, "config[0] is_shorthand should be false");
        }
    }
    /* The ES6 shorthand sets the flag. */
    const kcl_expr_t* shorthand = assign_value(m, "config_shorthand");
    CHECK(shorthand != NULL && shorthand->kind == KCL_EXPR_KIND_CONFIG,
        "no `config_shorthand` ConfigExpr");
    if (shorthand != NULL && shorthand->kind == KCL_EXPR_KIND_CONFIG) {
        for (size_t i = 0; i < shorthand->u.config_expr.items.count; i++) {
            const kcl_config_entry_t* e =
                (const kcl_config_entry_t*)shorthand->u.config_expr.items.items[i].node;
            CHECK(e != NULL && e->is_shorthand, "config_shorthand[%zu] is_shorthand is false", i);
        }
    }
    /* `config_if` wraps the `ConfigIfEntryExpr` in a `ConfigEntry` whose
     * `key` is null. */
    const kcl_expr_t* config_if = assign_value(m, "config_if");
    CHECK(config_if != NULL && config_if->kind == KCL_EXPR_KIND_CONFIG,
        "no `config_if` ConfigExpr");
    if (config_if != NULL && config_if->kind == KCL_EXPR_KIND_CONFIG) {
        CHECK(config_if->u.config_expr.items.count == 1, "config_if has %zu entries, want 1",
            config_if->u.config_expr.items.count);
        if (config_if->u.config_expr.items.count == 1) {
            const kcl_config_entry_t* e =
                (const kcl_config_entry_t*)config_if->u.config_expr.items.items[0].node;
            CHECK(e != NULL && e->key == NULL, "config_if entry should have a null key");
            const kcl_expr_t* v = e != NULL ? (const kcl_expr_t*)e->value.node : NULL;
            CHECK(v != NULL && v->kind == KCL_EXPR_KIND_CONFIG_IF_ENTRY,
                "config_if entry value is not a ConfigIfEntryExpr");
            if (v != NULL && v->kind == KCL_EXPR_KIND_CONFIG_IF_ENTRY)
                CHECK(v->u.config_if_entry_expr.items.count > 0,
                    "ConfigIfEntryExpr has no items");
        }
    }
}

static void test_comprehensions(const kcl_module_t* m)
{
    const kcl_expr_t* quant = assign_value(m, "quant");
    CHECK(quant != NULL && quant->kind == KCL_EXPR_KIND_QUANT, "no `quant` QuantExpr");
    if (quant != NULL && quant->kind == KCL_EXPR_KIND_QUANT) {
        /* `op` is a single QuantOperation, not a list of them. */
        CHECK(quant->u.quant_expr.op == KCL_QUANT_OPERATION_ALL
                || quant->u.quant_expr.op == KCL_QUANT_OPERATION_ANY
                || quant->u.quant_expr.op == KCL_QUANT_OPERATION_FILTER
                || quant->u.quant_expr.op == KCL_QUANT_OPERATION_MAP,
            "quant op is not a known QuantOperation");
        /* `variables` is `Vec<NodeRef<Identifier>>`, not Targets. */
        CHECK(quant->u.quant_expr.variables.count > 0, "quant has no variables");
        if (quant->u.quant_expr.variables.count > 0) {
            const kcl_identifier_t* v =
                (const kcl_identifier_t*)quant->u.quant_expr.variables.items[0].node;
            CHECK(identifier_dotted(v)[0] != '\0', "quant variable has an empty name");
        }
        CHECK(quant->u.quant_expr.test.node != NULL, "quant has no test");
    }
    /* `DictComp.entry` is a bare ConfigEntry — there is no `key`/
     * `value` pair and no `cond`. */
    const kcl_expr_t* dict_comp = assign_value(m, "dict_comp");
    CHECK(dict_comp != NULL && dict_comp->kind == KCL_EXPR_KIND_DICT_COMP,
        "no `dict_comp` DictComp");
    if (dict_comp != NULL && dict_comp->kind == KCL_EXPR_KIND_DICT_COMP) {
        CHECK(dict_comp->u.dict_comp.entry.key != NULL, "DictComp entry key is NULL");
        CHECK(dict_comp->u.dict_comp.entry.value.node != NULL, "DictComp entry value is NULL");
        CHECK(dict_comp->u.dict_comp.generators.count > 0, "DictComp has no generators");
        if (dict_comp->u.dict_comp.generators.count > 0) {
            const kcl_comp_clause_t* c =
                (const kcl_comp_clause_t*)dict_comp->u.dict_comp.generators.items[0].node;
            CHECK(c != NULL, "DictComp generator is NULL");
            if (c != NULL) {
                /* `CompClause.targets` are Identifiers. */
                CHECK(c->targets.count > 0, "CompClause has no targets");
                if (c->targets.count > 0) {
                    const kcl_identifier_t* t =
                        (const kcl_identifier_t*)c->targets.items[0].node;
                    CHECK(t != NULL, "CompClause target is NULL");
                }
            }
        }
    }
    /* `ListIfItemExpr` is `{if_cond, exprs, orelse}` — there is no
     * `if_expr`. */
    const kcl_expr_t* entry_list = assign_value(m, "list_if_entry");
    CHECK(entry_list != NULL && entry_list->kind == KCL_EXPR_KIND_LIST,
        "no `list_if_entry` ListExpr");
    if (entry_list != NULL && entry_list->kind == KCL_EXPR_KIND_LIST
        && entry_list->u.list_expr.elts.count > 0) {
        const kcl_expr_t* item =
            (const kcl_expr_t*)entry_list->u.list_expr.elts.items[0].node;
        CHECK(item != NULL && item->kind == KCL_EXPR_KIND_LIST_IF_ITEM,
            "`list_if_entry` does not hold a ListIfItemExpr");
        if (item != NULL && item->kind == KCL_EXPR_KIND_LIST_IF_ITEM) {
            CHECK(item->u.list_if_item_expr.if_cond.node != NULL,
                "ListIfItemExpr has no if_cond");
            CHECK(item->u.list_if_item_expr.exprs.count > 0,
                "ListIfItemExpr has no exprs");
        }
    }
    /* The `*_if` forms are ListComp — there is no `cond` field. */
    const kcl_expr_t* comp = assign_value(m, "list_if");
    CHECK(comp != NULL && comp->kind == KCL_EXPR_KIND_LIST_COMP, "no `list_if` ListComp");
    if (comp != NULL && comp->kind == KCL_EXPR_KIND_LIST_COMP)
        CHECK(comp->u.list_comp.generators.count > 0, "list_if has no generators");
}

static void test_lambda_arguments_are_index_aligned(const kcl_module_t* m)
{
    /* `lambda_expr`'s Arguments has `args: [p]`, `defaults: [null]` and
     * `ty_list: [Int]`. Dropping the positional null would leave an
     * empty list, which is the bug this checks for. */
    const kcl_expr_t* lambda = assign_value(m, "lambda_expr");
    CHECK(lambda != NULL && lambda->kind == KCL_EXPR_KIND_LAMBDA, "no `lambda_expr` LambdaExpr");
    if (lambda == NULL || lambda->kind != KCL_EXPR_KIND_LAMBDA)
        return;
    CHECK(lambda->u.lambda_expr.args != NULL, "lambda_expr has no args");
    if (lambda->u.lambda_expr.args == NULL)
        return;
    const kcl_arguments_t* args = (const kcl_arguments_t*)lambda->u.lambda_expr.args->node;
    CHECK(args != NULL, "lambda args payload is NULL");
    if (args == NULL)
        return;
    CHECK(args->args.count == 1, "lambda has %zu args, want 1", args->args.count);
    CHECK(args->defaults.count == 1, "lambda has %zu defaults, want 1", args->defaults.count);
    if (args->defaults.count == 1)
        CHECK(!args->defaults.items[0].present, "lambda's single default should be null");
    CHECK(args->ty_list.count == 1, "lambda has %zu ty_list entries, want 1",
        args->ty_list.count);
    if (args->ty_list.count == 1) {
        CHECK(args->ty_list.items[0].present, "lambda's ty_list[0] should be present");
        if (args->ty_list.items[0].present) {
            const kcl_type_node_t* t =
                (const kcl_type_node_t*)args->ty_list.items[0].value.node;
            CHECK(t != NULL && t->kind == KCL_TYPE_KIND_BASIC, "ty_list[0] is not Basic");
            if (t != NULL && t->kind == KCL_TYPE_KIND_BASIC)
                CHECK(t->u.basic_type.basic == KCL_BASIC_TYPE_INT,
                    "ty_list[0] is not Int");
        }
    }
    /* The body is statements, not expressions. */
    CHECK(lambda->u.lambda_expr.body.count > 0, "lambda body is empty");
    if (lambda->u.lambda_expr.body.count > 0) {
        const kcl_stmt_t* body = (const kcl_stmt_t*)lambda->u.lambda_expr.body.items[0].node;
        CHECK(body != NULL && body->kind == KCL_STMT_KIND_EXPR,
            "lambda body is not an ExprStmt");
    }

    /* `lambda_plain` has `args: null` — an absent Option. */
    const kcl_expr_t* plain = assign_value(m, "lambda_plain");
    CHECK(plain != NULL && plain->kind == KCL_EXPR_KIND_LAMBDA,
        "no `lambda_plain` LambdaExpr");
    if (plain != NULL && plain->kind == KCL_EXPR_KIND_LAMBDA)
        CHECK(plain->u.lambda_expr.args == NULL, "lambda_plain should have a null args");
}

static void test_number_literals(const kcl_module_t* m)
{
    /* `NumberLitValue` is tag+content, so the tag is the only thing
     * telling an int payload from a float one. */
    const kcl_expr_t* int_lit = assign_value(m, "lit_int");
    CHECK(int_lit != NULL && int_lit->kind == KCL_EXPR_KIND_NUMBER_LIT,
        "no `lit_int` NumberLit");
    if (int_lit != NULL && int_lit->kind == KCL_EXPR_KIND_NUMBER_LIT) {
        CHECK(int_lit->u.number_lit.value_kind == KCL_NUMBER_LIT_VALUE_INT,
            "lit_int is not an Int payload");
        CHECK(!int_lit->u.number_lit.has_binary_suffix, "lit_int has a binary suffix");
    }
    const kcl_expr_t* float_lit = assign_value(m, "lit_float");
    CHECK(float_lit != NULL && float_lit->kind == KCL_EXPR_KIND_NUMBER_LIT,
        "no `lit_float` NumberLit");
    if (float_lit != NULL && float_lit->kind == KCL_EXPR_KIND_NUMBER_LIT) {
        CHECK(float_lit->u.number_lit.value_kind == KCL_NUMBER_LIT_VALUE_FLOAT,
            "lit_float is not a Float payload");
        CHECK(float_lit->u.number_lit.float_value != 0.0, "lit_float is zero");
    }
    const kcl_expr_t* name = assign_value(m, "lit_name");
    CHECK(name != NULL && name->kind == KCL_EXPR_KIND_NAME_CONSTANT_LIT,
        "no `lit_name` NameConstantLit");
}

static void test_string_and_joined(const kcl_module_t* m)
{
    const kcl_expr_t* str = assign_value(m, "lit_str");
    CHECK(str != NULL && str->kind == KCL_EXPR_KIND_STRING_LIT, "no `lit_str` StringLit");
    if (str != NULL && str->kind == KCL_EXPR_KIND_STRING_LIT) {
        CHECK(str->u.string_lit.value != NULL, "StringLit value is NULL");
        CHECK(str->u.string_lit.raw_value != NULL, "StringLit raw_value is NULL");
    }
    const kcl_expr_t* long_str = assign_value(m, "lit_long");
    CHECK(long_str != NULL && long_str->kind == KCL_EXPR_KIND_STRING_LIT,
        "no `lit_long` StringLit");
    if (long_str != NULL && long_str->kind == KCL_EXPR_KIND_STRING_LIT)
        CHECK(long_str->u.string_lit.is_long_string, "lit_long is_long_string is false");
    /* The field is `format_spec`, not `spec`. */
    const kcl_expr_t* joined = assign_value(m, "joined");
    CHECK(joined != NULL && joined->kind == KCL_EXPR_KIND_JOINED_STRING,
        "no `joined` JoinedString");
    if (joined != NULL && joined->kind == KCL_EXPR_KIND_JOINED_STRING) {
        CHECK(joined->u.joined_string.raw_value != NULL, "JoinedString raw_value is NULL");
        CHECK(joined->u.joined_string.values.count > 0, "JoinedString has no values");
    }
}

static void test_target_paths(const kcl_module_t* m)
{
    /* `Target.paths` is a bare `Vec<MemberOrIndex>` — no NodeRef, so no
     * position on the element itself. */
    int saw_member = 0, saw_index = 0, saw_paths = 0;
    for (size_t i = 0; i < m->body.count; i++) {
        const kcl_stmt_t* s = (const kcl_stmt_t*)m->body.items[i].node;
        if (s == NULL || s->kind != KCL_STMT_KIND_ASSIGN)
            continue;
        for (size_t j = 0; j < s->u.assign_stmt.targets.count; j++) {
            const kcl_target_t* t =
                (const kcl_target_t*)s->u.assign_stmt.targets.items[j].node;
            if (t == NULL || t->paths_count == 0)
                continue;
            saw_paths = 1;
            for (size_t k = 0; k < t->paths_count; k++) {
                const kcl_member_or_index_t* p = &t->paths[k];
                if (p->kind == KCL_MEMBER_OR_INDEX_MEMBER) {
                    saw_member = 1;
                    /* The payload is a `NodeRef<String>`, so it carries
                     * its own position. */
                    CHECK(p->member.node != NULL, "Member path has no name");
                    CHECK(p->member.pos != NULL, "Member path has no position");
                } else {
                    saw_index = 1;
                    CHECK(p->index != NULL && p->index->node != NULL,
                        "Index path has no expression");
                }
            }
        }
    }
    CHECK(saw_paths, "no assignment carries a path target");
    CHECK(saw_member, "no Member path in the fixture");
    CHECK(saw_index, "no Index path in the fixture");
    /* `pkgpath` is a single string, not a list. */
    for (size_t i = 0; i < m->body.count; i++) {
        const kcl_stmt_t* s = (const kcl_stmt_t*)m->body.items[i].node;
        if (s == NULL || s->kind != KCL_STMT_KIND_ASSIGN
            || s->u.assign_stmt.targets.count == 0)
            continue;
        const kcl_target_t* t =
            (const kcl_target_t*)s->u.assign_stmt.targets.items[0].node;
        if (t != NULL && t->paths_count > 0)
            CHECK(t->pkgpath != NULL, "a path target has a NULL pkgpath");
    }
}

static void test_starred_and_missing(const kcl_module_t* m)
{
    /* `StarredExpr.ctx` is `ExprContext`, which has Load and Store —
     * there is no `Del`. */
    const kcl_expr_t* starred = assign_value(m, "starred");
    CHECK(starred != NULL, "no `starred`");
    if (starred != NULL) {
        const kcl_expr_t* e = starred;
        if (e->kind == KCL_EXPR_KIND_LIST) {
            CHECK(e->u.list_expr.elts.count > 0, "`starred` list is empty");
            if (e->u.list_expr.elts.count > 0)
                e = (const kcl_expr_t*)e->u.list_expr.elts.items[0].node;
        }
        CHECK(e != NULL && e->kind == KCL_EXPR_KIND_STARRED, "`starred` is not a StarredExpr");
        if (e != NULL && e->kind == KCL_EXPR_KIND_STARRED)
            CHECK(e->u.starred_expr.ctx == KCL_EXPR_CONTEXT_LOAD
                    || e->u.starred_expr.ctx == KCL_EXPR_CONTEXT_STORE,
                "starred ctx is out of range");
    }
    /* The parser substitutes a placeholder `Identifier` for a missing
     * expression, so this decodes as an Identifier with a name rather
     * than as `Expr::Missing`. */
    const kcl_expr_t* missing = assign_value(m, "missing_expr");
    CHECK(missing != NULL && missing->kind == KCL_EXPR_KIND_IDENTIFIER,
        "no `missing_expr` placeholder");
    if (missing != NULL && missing->kind == KCL_EXPR_KIND_IDENTIFIER)
        CHECK(identifier_dotted(&missing->u.identifier)[0] != '\0',
            "the missing_expr placeholder has an empty name");
}

static void test_type_aliases_and_types(const kcl_module_t* m)
{
    /* `Type` is adjacently tagged: the tag names the shape and the
     * payload is inlined under `value`. `Any` is the only unit variant,
     * so it has no `value` at all. */
    const kcl_stmt_t* any_alias = find_type_alias(m, "TAny");
    CHECK(any_alias != NULL, "no TAny type alias");
    if (any_alias != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)any_alias->u.type_alias_stmt.ty.node;
        CHECK(t != NULL && t->kind == KCL_TYPE_KIND_ANY, "TAny is not a Type::Any");
        if (t != NULL)
            CHECK(t->type_tag != NULL && strcmp(t->type_tag, "Any") == 0,
                "TAny tag is %s, want Any", t->type_tag);
    }
    /* `Basic` carries a bare string, not an object. */
    const kcl_stmt_t* basic_alias = find_type_alias(m, "TBasic");
    CHECK(basic_alias != NULL, "no TBasic type alias");
    if (basic_alias != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)basic_alias->u.type_alias_stmt.ty.node;
        CHECK(t != NULL && t->kind == KCL_TYPE_KIND_BASIC, "TBasic is not a Type::Basic");
        if (t != NULL && t->kind == KCL_TYPE_KIND_BASIC)
            CHECK(t->u.basic_type.basic == KCL_BASIC_TYPE_BOOL
                    || t->u.basic_type.basic == KCL_BASIC_TYPE_INT
                    || t->u.basic_type.basic == KCL_BASIC_TYPE_FLOAT
                    || t->u.basic_type.basic == KCL_BASIC_TYPE_STR,
                "TBasic did not decode a BasicType");
    }
    /* `Named` inlines the Identifier newtype. */
    const kcl_stmt_t* named_alias = find_type_alias(m, "TNamed");
    CHECK(named_alias != NULL, "no TNamed type alias");
    if (named_alias != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)named_alias->u.type_alias_stmt.ty.node;
        CHECK(t != NULL && t->kind == KCL_TYPE_KIND_NAMED, "TNamed is not a Type::Named");
        if (t != NULL && t->kind == KCL_TYPE_KIND_NAMED)
            CHECK(strcmp(identifier_dotted(&t->u.named_type.name), "Cloud") == 0,
                "TNamed resolves to %s, want Cloud", identifier_dotted(&t->u.named_type.name));
    }
    /* List / Dict / Union nest under `inner_type` etc. */
    const kcl_stmt_t* list_alias = find_type_alias(m, "TList");
    CHECK(list_alias != NULL, "no TList type alias");
    if (list_alias != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)list_alias->u.type_alias_stmt.ty.node;
        CHECK(t != NULL && t->kind == KCL_TYPE_KIND_LIST, "TList is not a Type::List");
        if (t != NULL && t->kind == KCL_TYPE_KIND_LIST)
            CHECK(t->u.list_type.inner_type != NULL, "TList has no inner_type");
    }
    const kcl_stmt_t* dict_alias = find_type_alias(m, "TDict");
    CHECK(dict_alias != NULL, "no TDict type alias");
    if (dict_alias != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)dict_alias->u.type_alias_stmt.ty.node;
        CHECK(t != NULL && t->kind == KCL_TYPE_KIND_DICT, "TDict is not a Type::Dict");
        if (t != NULL && t->kind == KCL_TYPE_KIND_DICT) {
            CHECK(t->u.dict_type.key_type != NULL, "TDict has no key_type");
            CHECK(t->u.dict_type.value_type != NULL, "TDict has no value_type");
        }
    }
    const kcl_stmt_t* union_alias = find_type_alias(m, "TUnion");
    CHECK(union_alias != NULL, "no TUnion type alias");
    if (union_alias != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)union_alias->u.type_alias_stmt.ty.node;
        CHECK(t != NULL && t->kind == KCL_TYPE_KIND_UNION, "TUnion is not a Type::Union");
        if (t != NULL && t->kind == KCL_TYPE_KIND_UNION)
            CHECK(t->u.union_type.type_elements.count >= 2,
                "TUnion has %zu elements, want >= 2", t->u.union_type.type_elements.count);
    }
    /* `FunctionType` uses `params_ty` / `ret_ty`, both optional. */
    const kcl_stmt_t* func_alias = find_type_alias(m, "TFunc");
    CHECK(func_alias != NULL, "no TFunc type alias");
    if (func_alias != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)func_alias->u.type_alias_stmt.ty.node;
        CHECK(t != NULL && t->kind == KCL_TYPE_KIND_FUNCTION, "TFunc is not a Type::Function");
        if (t != NULL && t->kind == KCL_TYPE_KIND_FUNCTION) {
            CHECK(t->u.function_type.params_ty != NULL, "TFunc has no params_ty");
            if (t->u.function_type.params_ty != NULL)
                CHECK(t->u.function_type.params_ty->count > 0, "TFunc params_ty is empty");
            CHECK(t->u.function_type.ret_ty != NULL, "TFunc has no ret_ty");
        }
    }
    /* `LiteralType` is itself tag+content, so `Type::Literal`'s value
     * is a *second* tagged document. */
    const kcl_stmt_t* lit_int = find_type_alias(m, "TLitInt");
    CHECK(lit_int != NULL, "no TLitInt type alias");
    if (lit_int != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)lit_int->u.type_alias_stmt.ty.node;
        CHECK(t != NULL && t->kind == KCL_TYPE_KIND_LITERAL, "TLitInt is not a Type::Literal");
        if (t != NULL && t->kind == KCL_TYPE_KIND_LITERAL) {
            CHECK(t->u.literal_type.kind == KCL_LITERAL_TYPE_INT
                    || t->u.literal_type.kind == KCL_LITERAL_TYPE_FLOAT
                    || t->u.literal_type.kind == KCL_LITERAL_TYPE_STR
                    || t->u.literal_type.kind == KCL_LITERAL_TYPE_BOOL,
                "TLitInt has an unrecognised LiteralType tag");
        }
    }
    const kcl_stmt_t* lit_str = find_type_alias(m, "TLitStr");
    CHECK(lit_str != NULL, "no TLitStr type alias");
    if (lit_str != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)lit_str->u.type_alias_stmt.ty.node;
        if (t != NULL && t->kind == KCL_TYPE_KIND_LITERAL
            && t->u.literal_type.kind == KCL_LITERAL_TYPE_STR)
            CHECK(t->u.literal_type.str_value != NULL, "TLitStr has no string value");
    }
    const kcl_stmt_t* lit_bool = find_type_alias(m, "TLitBool");
    CHECK(lit_bool != NULL, "no TLitBool type alias");
    if (lit_bool != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)lit_bool->u.type_alias_stmt.ty.node;
        if (t != NULL && t->kind == KCL_TYPE_KIND_LITERAL
            && t->u.literal_type.kind == KCL_LITERAL_TYPE_BOOL)
            CHECK(t->u.literal_type.bool_value, "TLitBool should be true");
    }
    const kcl_stmt_t* lit_float = find_type_alias(m, "TLitFloat");
    CHECK(lit_float != NULL, "no TLitFloat type alias");
    if (lit_float != NULL) {
        const kcl_type_node_t* t =
            (const kcl_type_node_t*)lit_float->u.type_alias_stmt.ty.node;
        if (t != NULL && t->kind == KCL_TYPE_KIND_LITERAL
            && t->u.literal_type.kind == KCL_LITERAL_TYPE_FLOAT)
            CHECK(t->u.literal_type.float_value != 0.0, "TLitFloat is zero");
    }
    /* `TypeAliasStmt` names its fields `type_name` / `type_value`. */
    CHECK(any_alias != NULL && any_alias->u.type_alias_stmt.type_value.node != NULL,
        "TypeAlias type_value is NULL");
}

static void test_every_tag_resolves(const kcl_module_t* m)
{
    char* unknown[512];
    size_t count = 0;
    for (size_t i = 0; i < m->body.count && count < 512; i++) {
        walk_stmt((const kcl_stmt_t*)m->body.items[i].node, unknown, &count);
    }
    for (size_t i = 0; i < count; i++) {
        fprintf(stderr, "    unresolved tag: %s\n", unknown[i]);
        free(unknown[i]);
    }
    CHECK(count == 0, "%zu tag(s) in the golden capture failed to resolve", count);
}

int main(void)
{
    g_fixture = find_fixture();
    if (g_fixture == NULL)
        return 1;
    char* json_text = read_file(g_fixture);
    if (json_text == NULL) {
        fprintf(stderr, "could not read %s\n", g_fixture);
        return 1;
    }

    kcl_module_t* module = kcl_ast_parse_module(json_text);
    free(json_text);
    if (module == NULL) {
        fprintf(stderr, "kcl_ast_parse_module returned NULL\n");
        return 1;
    }
    printf("fixture: %s\n", g_fixture);

    struct Case {
        const char* name;
        test_fn fn;
    } cases[] = {
        { "Module and Comment shape", &test_module_shape },
        { "ImportStmt flat fields", &test_import_is_flat },
        { "UnificationStmt target is a Store Identifier", &test_unification_target_is_a_store_identifier },
        { "AugAssign, Assert and If orelse", &test_aug_assign_and_assert },
        { "RuleStmt decorators and checks", &test_rule_stmt },
        { "Schema decorators are flat CallExprs", &test_schema_decorators_are_flat_call_exprs },
        { "SchemaExpr vs Call, Keyword.arg is an Identifier", &test_schema_expr_is_not_a_call },
        { "UnaryOp, BinOp and Compare parallel arrays", &test_unary_binary_compare },
        { "Selector has_question and Subscript slices", &test_selector_and_subscript },
        { "ConfigEntry operations and is_shorthand", &test_config_entries },
        { "Quant, DictComp entry and CompClause targets", &test_comprehensions },
        { "Arguments defaults are index-aligned", &test_lambda_arguments_are_index_aligned },
        { "NumberLitValue tag+content", &test_number_literals },
        { "StringLit, JoinedString and format_spec", &test_string_and_joined },
        { "Target.paths MemberOrIndex", &test_target_paths },
        { "StarredExpr ctx and MissingExpr", &test_starred_and_missing },
        { "Type is adjacently tagged", &test_type_aliases_and_types },
        { "every tag in the golden capture resolves", &test_every_tag_resolves },
    };

    int failed_cases = 0;
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
        int before = g_failures;
        cases[i].fn(module);
        if (g_failures == before) {
            printf("ok  - %s\n", cases[i].name);
        } else {
            printf("FAIL: %s\n", cases[i].name);
            failed_cases++;
        }
    }

    kcl_module_free(module);
    if (failed_cases > 0) {
        fprintf(stderr, "%d test(s) failed\n", failed_cases);
        return 1;
    }
    printf("all tests passed\n");
    return 0;
}

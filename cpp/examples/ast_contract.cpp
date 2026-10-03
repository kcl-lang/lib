/*
 * ast_contract.cpp — AST contract tests for the C++ binding.
 *
 * Decodes the shared golden capture at `testdata/ast/alignment.json`
 * into the typed AST and checks the *wire* contract: which tags exist,
 * which payloads are flattened, and which fields are optional.
 *
 * This is the C++ half of the pair — `ast_alignment.cpp` covers the
 * other half by parsing a live fixture through `kcl_lib::parse_file`,
 * which proves the parser emits something the loader accepts. This one
 * proves the loader understands the shapes the parser is *specified* to
 * emit, and — the assertion that matters most — that no tag anywhere in
 * the document falls through as unknown. A wrong tag decodes to a
 * zero-valued struct rather than failing, so field-by-field assertions
 * on a handful of nodes would sail through a decoder that resolves
 * nothing at all.
 *
 * Where the C test in `c/examples/ast_contract.c` shares this header,
 * this one exists for what a C++ compiler and the `kcl::ast` RAII layer
 * add: the header is a C header with unions, enums and macro-generated
 * node wrappers, so compiling it cleanly as C++ and copying the wrapper
 * structs by value are not things the C test can check. Those are the
 * cases added at the bottom of the suite.
 *
 * Build:
 *   $ make cpp
 *   $ ./build/ast_contract
 */

#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "kcl_lib_ast.hpp"

namespace {

int g_failures = 0;

#define CHECK(cond, ...)                                       \
    do {                                                       \
        if (!(cond)) {                                         \
            std::fprintf(stderr, "    %s:%d: ", __FILE__, __LINE__); \
            std::fprintf(stderr, __VA_ARGS__);                \
            std::fprintf(stderr, "\n");                       \
            g_failures++;                                      \
        }                                                      \
    } while (0)

using Tags = std::vector<std::string>;

// --- Fixture ---------------------------------------------------------

const char* find_fixture()
{
    static const char* candidates[] = {
        "../../testdata/ast/alignment.json",
        "../testdata/ast/alignment.json",
        "testdata/ast/alignment.json",
        nullptr,
    };
    for (size_t i = 0; candidates[i] != nullptr; i++) {
        if (FILE* fp = std::fopen(candidates[i], "rb")) {
            std::fclose(fp);
            return candidates[i];
        }
    }
    std::fprintf(stderr, "could not locate testdata/ast/alignment.json\n");
    return nullptr;
}

std::string read_file(const char* path)
{
    FILE* fp = std::fopen(path, "rb");
    if (fp == nullptr)
        return std::string();
    std::fseek(fp, 0, SEEK_END);
    long n = std::ftell(fp);
    std::fseek(fp, 0, SEEK_SET);
    if (n <= 0) {
        std::fclose(fp);
        return std::string();
    }
    std::string buf(static_cast<size_t>(n), '\0');
    size_t got = std::fread(&buf[0], 1, static_cast<size_t>(n), fp);
    buf.resize(got);
    std::fclose(fp);
    return buf;
}

// --- Unresolved-tag walker ------------------------------------------
//
// A tag the decoder does not recognise becomes a zero-valued struct
// rather than an error, so this walk is the only thing standing between
// a stale tag table and a silently empty AST.

void walk_expr(const kcl_expr_t* e, Tags& unknown);
void walk_stmt(const kcl_stmt_t* s, Tags& unknown);
void walk_type(const kcl_type_node_t* t, Tags& unknown);

void walk_expr_ref(const kcl_expr_node_t* n, Tags& unknown)
{
    if (n != nullptr)
        walk_expr(static_cast<const kcl_expr_t*>(n->node), unknown);
}
void walk_type_ref(const kcl_type_ref_node_t* n, Tags& unknown)
{
    if (n != nullptr)
        walk_type(static_cast<const kcl_type_node_t*>(n->node), unknown);
}
void walk_stmt_ref(const kcl_stmt_node_t* n, Tags& unknown)
{
    if (n != nullptr)
        walk_stmt(static_cast<const kcl_stmt_t*>(n->node), unknown);
}

void record_unknown(Tags& unknown, const char* what, const char* tag)
{
    unknown.push_back(std::string(what) + "." + (tag != nullptr ? tag : "(no tag)"));
}

void walk_expr(const kcl_expr_t* e, Tags& unknown)
{
    if (e == nullptr)
        return;
    if (e->kind == KCL_EXPR_KIND_UNKNOWN) {
        record_unknown(unknown, "Expr", e->type_tag);
        return;
    }
    switch (e->kind) {
    case KCL_EXPR_KIND_TARGET:
    case KCL_EXPR_KIND_IDENTIFIER:
        break; /* no children */
    case KCL_EXPR_KIND_UNARY:
        walk_expr_ref(&e->u.unary_expr.operand, unknown);
        break;
    case KCL_EXPR_KIND_BINARY:
        walk_expr_ref(&e->u.binary_expr.left, unknown);
        walk_expr_ref(&e->u.binary_expr.right, unknown);
        break;
    case KCL_EXPR_KIND_IF:
        walk_expr_ref(&e->u.if_expr.body, unknown);
        walk_expr_ref(&e->u.if_expr.cond, unknown);
        walk_expr_ref(&e->u.if_expr.orelse, unknown);
        break;
    case KCL_EXPR_KIND_SELECTOR:
        walk_expr_ref(&e->u.selector_expr.value, unknown);
        break;
    case KCL_EXPR_KIND_CALL:
        walk_expr_ref(&e->u.call_expr.func, unknown);
        for (size_t i = 0; i < e->u.call_expr.args.count; i++)
            walk_expr_ref(&e->u.call_expr.args.items[i], unknown);
        for (size_t i = 0; i < e->u.call_expr.keywords.count; i++) {
            auto* kw = static_cast<const kcl_keyword_t*>(e->u.call_expr.keywords.items[i].node);
            if (kw != nullptr)
                walk_expr_ref(kw->value, unknown);
        }
        break;
    case KCL_EXPR_KIND_PAREN:
        walk_expr_ref(&e->u.paren_expr.expr, unknown);
        break;
    case KCL_EXPR_KIND_QUANT:
        walk_expr_ref(&e->u.quant_expr.target, unknown);
        walk_expr_ref(&e->u.quant_expr.test, unknown);
        walk_expr_ref(e->u.quant_expr.if_cond, unknown);
        break;
    case KCL_EXPR_KIND_LIST:
        for (size_t i = 0; i < e->u.list_expr.elts.count; i++)
            walk_expr_ref(&e->u.list_expr.elts.items[i], unknown);
        break;
    case KCL_EXPR_KIND_LIST_IF_ITEM:
        walk_expr_ref(&e->u.list_if_item_expr.if_cond, unknown);
        for (size_t i = 0; i < e->u.list_if_item_expr.exprs.count; i++)
            walk_expr_ref(&e->u.list_if_item_expr.exprs.items[i], unknown);
        walk_expr_ref(e->u.list_if_item_expr.orelse, unknown);
        break;
    case KCL_EXPR_KIND_LIST_COMP:
        walk_expr_ref(&e->u.list_comp.elt, unknown);
        for (size_t i = 0; i < e->u.list_comp.generators.count; i++) {
            auto* c = static_cast<const kcl_comp_clause_t*>(e->u.list_comp.generators.items[i].node);
            if (c != nullptr) {
                walk_expr_ref(&c->iter, unknown);
                for (size_t j = 0; j < c->ifs.count; j++)
                    walk_expr_ref(&c->ifs.items[j], unknown);
            }
        }
        break;
    case KCL_EXPR_KIND_STARRED:
        walk_expr_ref(&e->u.starred_expr.value, unknown);
        break;
    case KCL_EXPR_KIND_DICT_COMP:
        walk_expr_ref(e->u.dict_comp.entry.key, unknown);
        walk_expr_ref(&e->u.dict_comp.entry.value, unknown);
        for (size_t i = 0; i < e->u.dict_comp.generators.count; i++) {
            auto* c = static_cast<const kcl_comp_clause_t*>(e->u.dict_comp.generators.items[i].node);
            if (c != nullptr) {
                walk_expr_ref(&c->iter, unknown);
                for (size_t j = 0; j < c->ifs.count; j++)
                    walk_expr_ref(&c->ifs.items[j], unknown);
            }
        }
        break;
    case KCL_EXPR_KIND_CONFIG_IF_ENTRY:
        walk_expr_ref(&e->u.config_if_entry_expr.if_cond, unknown);
        for (size_t i = 0; i < e->u.config_if_entry_expr.items.count; i++) {
            auto* entry
                = static_cast<const kcl_config_entry_t*>(e->u.config_if_entry_expr.items.items[i].node);
            if (entry != nullptr) {
                walk_expr_ref(entry->key, unknown);
                walk_expr_ref(&entry->value, unknown);
            }
        }
        walk_expr_ref(e->u.config_if_entry_expr.orelse, unknown);
        break;
    case KCL_EXPR_KIND_COMP_CLAUSE:
        walk_expr_ref(&e->u.comp_clause.iter, unknown);
        for (size_t i = 0; i < e->u.comp_clause.ifs.count; i++)
            walk_expr_ref(&e->u.comp_clause.ifs.items[i], unknown);
        break;
    case KCL_EXPR_KIND_SCHEMA:
        walk_expr_ref(&e->u.schema_expr.config, unknown);
        for (size_t i = 0; i < e->u.schema_expr.args.count; i++)
            walk_expr_ref(&e->u.schema_expr.args.items[i], unknown);
        for (size_t i = 0; i < e->u.schema_expr.kwargs.count; i++) {
            auto* kw = static_cast<const kcl_keyword_t*>(e->u.schema_expr.kwargs.items[i].node);
            if (kw != nullptr)
                walk_expr_ref(kw->value, unknown);
        }
        break;
    case KCL_EXPR_KIND_CONFIG:
        for (size_t i = 0; i < e->u.config_expr.items.count; i++) {
            auto* entry = static_cast<const kcl_config_entry_t*>(e->u.config_expr.items.items[i].node);
            if (entry != nullptr) {
                walk_expr_ref(entry->key, unknown);
                walk_expr_ref(&entry->value, unknown);
            }
        }
        break;
    case KCL_EXPR_KIND_CHECK:
        walk_expr_ref(&e->u.check_expr.test, unknown);
        walk_expr_ref(e->u.check_expr.if_cond, unknown);
        walk_expr_ref(e->u.check_expr.msg, unknown);
        break;
    case KCL_EXPR_KIND_LAMBDA:
        for (size_t i = 0; i < e->u.lambda_expr.body.count; i++)
            walk_stmt_ref(&e->u.lambda_expr.body.items[i], unknown);
        walk_type_ref(e->u.lambda_expr.return_ty, unknown);
        if (e->u.lambda_expr.args != nullptr) {
            auto* args = static_cast<const kcl_arguments_t*>(e->u.lambda_expr.args->node);
            if (args != nullptr) {
                for (size_t i = 0; i < args->defaults.count; i++) {
                    if (args->defaults.items[i].present)
                        walk_expr_ref(&args->defaults.items[i].value, unknown);
                }
                for (size_t i = 0; i < args->ty_list.count; i++) {
                    if (args->ty_list.items[i].present)
                        walk_type_ref(&args->ty_list.items[i].value, unknown);
                }
            }
        }
        break;
    case KCL_EXPR_KIND_SUBSCRIPT:
        walk_expr_ref(&e->u.subscript_expr.value, unknown);
        walk_expr_ref(e->u.subscript_expr.index, unknown);
        walk_expr_ref(e->u.subscript_expr.lower, unknown);
        walk_expr_ref(e->u.subscript_expr.upper, unknown);
        walk_expr_ref(e->u.subscript_expr.step, unknown);
        break;
    case KCL_EXPR_KIND_KEYWORD:
        walk_expr_ref(e->u.keyword.value, unknown);
        break;
    case KCL_EXPR_KIND_ARGUMENTS:
        for (size_t i = 0; i < e->u.arguments.defaults.count; i++) {
            if (e->u.arguments.defaults.items[i].present)
                walk_expr_ref(&e->u.arguments.defaults.items[i].value, unknown);
        }
        for (size_t i = 0; i < e->u.arguments.ty_list.count; i++) {
            if (e->u.arguments.ty_list.items[i].present)
                walk_type_ref(&e->u.arguments.ty_list.items[i].value, unknown);
        }
        break;
    case KCL_EXPR_KIND_COMPARE:
        walk_expr_ref(&e->u.compare_expr.left, unknown);
        for (size_t i = 0; i < e->u.compare_expr.comparators.count; i++)
            walk_expr_ref(&e->u.compare_expr.comparators.items[i], unknown);
        break;
    case KCL_EXPR_KIND_JOINED_STRING:
        for (size_t i = 0; i < e->u.joined_string.values.count; i++)
            walk_expr_ref(&e->u.joined_string.values.items[i], unknown);
        break;
    case KCL_EXPR_KIND_FORMATTED_VALUE:
        walk_expr_ref(&e->u.formatted_value.value, unknown);
        break;
    default:
        break;
    }
}

void walk_stmt(const kcl_stmt_t* s, Tags& unknown)
{
    if (s == nullptr)
        return;
    if (s->kind == KCL_STMT_KIND_UNKNOWN) {
        record_unknown(unknown, "Stmt", s->type_tag);
        return;
    }
    switch (s->kind) {
    case KCL_STMT_KIND_TYPE_ALIAS:
        walk_type_ref(&s->u.type_alias_stmt.ty, unknown);
        break;
    case KCL_STMT_KIND_EXPR:
        for (size_t i = 0; i < s->u.expr_stmt.exprs.count; i++)
            walk_expr_ref(&s->u.expr_stmt.exprs.items[i], unknown);
        break;
    case KCL_STMT_KIND_UNIFICATION: {
        /* `value` is a `NodeRef<SchemaExpr>`, so the config is one level
         * deeper than it looks. */
        auto* se = static_cast<const kcl_schema_expr_t*>(s->u.unification_stmt.value.node);
        if (se != nullptr) {
            walk_expr_ref(&se->config, unknown);
            for (size_t i = 0; i < se->args.count; i++)
                walk_expr_ref(&se->args.items[i], unknown);
            for (size_t i = 0; i < se->kwargs.count; i++) {
                auto* kw = static_cast<const kcl_keyword_t*>(se->kwargs.items[i].node);
                if (kw != nullptr)
                    walk_expr_ref(kw->value, unknown);
            }
        }
        break;
    }
    case KCL_STMT_KIND_ASSIGN:
        for (size_t i = 0; i < s->u.assign_stmt.targets.count; i++) {
            auto* t = static_cast<const kcl_target_t*>(s->u.assign_stmt.targets.items[i].node);
            if (t != nullptr) {
                for (size_t j = 0; j < t->paths_count; j++)
                    walk_expr_ref(t->paths[j].index, unknown);
            }
        }
        walk_expr_ref(&s->u.assign_stmt.value, unknown);
        walk_type_ref(s->u.assign_stmt.ty, unknown);
        break;
    case KCL_STMT_KIND_AUG_ASSIGN: {
        auto* t = static_cast<const kcl_target_t*>(s->u.aug_assign_stmt.target.node);
        if (t != nullptr) {
            for (size_t j = 0; j < t->paths_count; j++)
                walk_expr_ref(t->paths[j].index, unknown);
        }
        walk_expr_ref(&s->u.aug_assign_stmt.value, unknown);
        break;
    }
    case KCL_STMT_KIND_ASSERT:
        walk_expr_ref(&s->u.assert_stmt.test, unknown);
        walk_expr_ref(s->u.assert_stmt.if_cond, unknown);
        walk_expr_ref(s->u.assert_stmt.msg, unknown);
        break;
    case KCL_STMT_KIND_IF:
        walk_expr_ref(&s->u.if_stmt.cond, unknown);
        for (size_t i = 0; i < s->u.if_stmt.body.count; i++)
            walk_stmt_ref(&s->u.if_stmt.body.items[i], unknown);
        /* `orelse` is `Vec<NodeRef<Stmt>>`, not an expression. */
        for (size_t i = 0; i < s->u.if_stmt.orelse.count; i++)
            walk_stmt_ref(&s->u.if_stmt.orelse.items[i], unknown);
        break;
    case KCL_STMT_KIND_IMPORT:
    case KCL_STMT_KIND_RULE:
        break;
    case KCL_STMT_KIND_SCHEMA_ATTR:
        walk_expr_ref(s->u.schema_attr.value, unknown);
        walk_type_ref(&s->u.schema_attr.ty, unknown);
        for (size_t i = 0; i < s->u.schema_attr.decorators.count; i++) {
            auto* d = static_cast<const kcl_call_expr_t*>(s->u.schema_attr.decorators.items[i].node);
            if (d != nullptr) {
                walk_expr_ref(&d->func, unknown);
                for (size_t j = 0; j < d->args.count; j++)
                    walk_expr_ref(&d->args.items[j], unknown);
            }
        }
        break;
    case KCL_STMT_KIND_SCHEMA:
        for (size_t i = 0; i < s->u.schema_stmt.body.count; i++)
            walk_stmt_ref(&s->u.schema_stmt.body.items[i], unknown);
        for (size_t i = 0; i < s->u.schema_stmt.decorators.count; i++) {
            auto* d = static_cast<const kcl_call_expr_t*>(s->u.schema_stmt.decorators.items[i].node);
            if (d != nullptr) {
                walk_expr_ref(&d->func, unknown);
                for (size_t j = 0; j < d->args.count; j++)
                    walk_expr_ref(&d->args.items[j], unknown);
            }
        }
        for (size_t i = 0; i < s->u.schema_stmt.checks.count; i++) {
            auto* c = static_cast<const kcl_check_expr_t*>(s->u.schema_stmt.checks.items[i].node);
            if (c != nullptr) {
                walk_expr_ref(&c->test, unknown);
                walk_expr_ref(c->if_cond, unknown);
                walk_expr_ref(c->msg, unknown);
            }
        }
        if (s->u.schema_stmt.index_signature != nullptr) {
            auto* sig
                = static_cast<const kcl_schema_index_signature_t*>(s->u.schema_stmt.index_signature->node);
            if (sig != nullptr) {
                walk_expr_ref(sig->value, unknown);
                walk_type_ref(&sig->key_ty, unknown);
                walk_type_ref(&sig->value_ty, unknown);
            }
        }
        break;
    default:
        break;
    }
}

void walk_type(const kcl_type_node_t* t, Tags& unknown)
{
    if (t == nullptr)
        return;
    if (t->kind == KCL_TYPE_KIND_UNKNOWN) {
        record_unknown(unknown, "Type", t->type_tag);
        return;
    }
    switch (t->kind) {
    case KCL_TYPE_KIND_ANY:
    case KCL_TYPE_KIND_NAMED:
    case KCL_TYPE_KIND_BASIC:
    case KCL_TYPE_KIND_LITERAL:
        break;
    case KCL_TYPE_KIND_LIST:
        walk_type_ref(t->u.list_type.inner_type, unknown);
        break;
    case KCL_TYPE_KIND_DICT:
        walk_type_ref(t->u.dict_type.key_type, unknown);
        walk_type_ref(t->u.dict_type.value_type, unknown);
        break;
    case KCL_TYPE_KIND_UNION:
        for (size_t i = 0; i < t->u.union_type.type_elements.count; i++)
            walk_type_ref(&t->u.union_type.type_elements.items[i], unknown);
        break;
    case KCL_TYPE_KIND_FUNCTION:
        if (t->u.function_type.params_ty != nullptr) {
            for (size_t i = 0; i < t->u.function_type.params_ty->count; i++)
                walk_type_ref(&t->u.function_type.params_ty->items[i], unknown);
        }
        walk_type_ref(t->u.function_type.ret_ty, unknown);
        break;
    default:
        break;
    }
}

// --- Lookups ---------------------------------------------------------

const kcl_stmt_t* find_schema(const kcl_module_t* m, const char* name)
{
    for (size_t i = 0; i < m->body.count; i++) {
        auto* s = static_cast<const kcl_stmt_t*>(m->body.items[i].node);
        if (s == nullptr || s->kind != KCL_STMT_KIND_SCHEMA)
            continue;
        if (s->u.schema_stmt.name.node != nullptr
            && std::strcmp(s->u.schema_stmt.name.node, name) == 0)
            return s;
    }
    return nullptr;
}

const kcl_stmt_t* find_assign(const kcl_module_t* m, const char* name)
{
    for (size_t i = 0; i < m->body.count; i++) {
        auto* s = static_cast<const kcl_stmt_t*>(m->body.items[i].node);
        if (s == nullptr || s->kind != KCL_STMT_KIND_ASSIGN || s->u.assign_stmt.targets.count == 0)
            continue;
        auto* t = static_cast<const kcl_target_t*>(s->u.assign_stmt.targets.items[0].node);
        if (t != nullptr && t->name.node != nullptr && std::strcmp(t->name.node, name) == 0)
            return s;
    }
    return nullptr;
}

const kcl_stmt_t* find_type_alias(const kcl_module_t* m, const char* name)
{
    for (size_t i = 0; i < m->body.count; i++) {
        auto* s = static_cast<const kcl_stmt_t*>(m->body.items[i].node);
        if (s == nullptr || s->kind != KCL_STMT_KIND_TYPE_ALIAS)
            continue;
        auto* id = static_cast<const kcl_identifier_t*>(s->u.type_alias_stmt.type_name.node);
        if (id != nullptr && id->names.count > 0 && id->names.items[0].node != nullptr
            && std::strcmp(id->names.items[0].node, name) == 0)
            return s;
    }
    return nullptr;
}

const kcl_expr_t* assign_value(const kcl_module_t* m, const char* name)
{
    const kcl_stmt_t* s = find_assign(m, name);
    if (s == nullptr)
        return nullptr;
    return static_cast<const kcl_expr_t*>(s->u.assign_stmt.value.node);
}

std::string identifier_dotted(const kcl_identifier_t* id)
{
    std::string out;
    if (id == nullptr)
        return out;
    for (size_t i = 0; i < id->names.count; i++) {
        if (i > 0)
            out += ".";
        if (id->names.items[i].node != nullptr)
            out += id->names.items[i].node;
    }
    return out;
}

/* `NodeRef<Identifier>` wrapper — the payload is one indirection down. */
std::string identifier_dotted_ref(const kcl_identifier_node_t* n)
{
    return identifier_dotted(static_cast<const kcl_identifier_t*>(n != nullptr ? n->node : nullptr));
}

const kcl_type_node_t* alias_type(const kcl_module_t* m, const char* name)
{
    const kcl_stmt_t* s = find_type_alias(m, name);
    if (s == nullptr)
        return nullptr;
    return static_cast<const kcl_type_node_t*>(s->u.type_alias_stmt.ty.node);
}

// --- Tests -----------------------------------------------------------

using TestFn = void (*)(const kcl_module_t*);

void test_module_shape(const kcl_module_t* m)
{
    CHECK(m->filename != nullptr, "module filename is NULL");
    if (m->filename != nullptr)
        CHECK(std::strstr(m->filename, ".k") != nullptr, "filename %s is not a .k file", m->filename);
    CHECK(m->body.count > 0, "module has no statements");
    /* `comments` is `Vec<NodeRef<Comment>>`, so the payload is `{text}`
     * rather than a bare string. */
    CHECK(m->comments.count > 0, "module has no comments");
    if (m->comments.count > 0) {
        auto* c = static_cast<const kcl_comment_t*>(m->comments.items[0].node);
        CHECK(c != nullptr && c->text != nullptr, "comment 0 has no text");
    }
    /* Positions are flat on the wrapper, so a `pos` with a line number
     * proves the loader is reading `line` and not looking for a nested
     * `pos` object. */
    CHECK(m->body.items[0].pos != nullptr, "statement 0 has no position");
    if (m->body.items[0].pos != nullptr) {
        CHECK(m->body.items[0].pos->line > 0, "statement 0 has line %lld",
            static_cast<long long>(m->body.items[0].pos->line));
        CHECK(m->body.items[0].pos->filename != nullptr, "statement 0 has no filename");
    }
}

void test_import_is_flat(const kcl_module_t* m)
{
    auto* s = static_cast<const kcl_stmt_t*>(m->body.items[0].node);
    CHECK(s != nullptr && s->kind == KCL_STMT_KIND_IMPORT, "statement 0 is not an Import");
    if (s == nullptr || s->kind != KCL_STMT_KIND_IMPORT)
        return;
    const kcl_import_stmt_t& imp = s->u.import_stmt;
    /* `path` is a `Node<String>`, so it carries a position of its own. */
    CHECK(imp.path.node != nullptr, "import path is NULL");
    if (imp.path.node != nullptr)
        CHECK(imp.path.pos != nullptr, "import path has no position");
    CHECK(imp.rawpath != nullptr, "import rawpath is NULL");
    CHECK(imp.name != nullptr, "import name is NULL");
    /* There is no `pkg_root` field on the wire. */
    CHECK(imp.pkg_name != nullptr && imp.pkg_name[0] != '\0', "import pkg_name is empty");
}

void test_unification_target_is_a_store_identifier(const kcl_module_t* m)
{
    const kcl_stmt_t* found = nullptr;
    for (size_t i = 0; i < m->body.count; i++) {
        auto* s = static_cast<const kcl_stmt_t*>(m->body.items[i].node);
        if (s != nullptr && s->kind == KCL_STMT_KIND_UNIFICATION) {
            found = s;
            break;
        }
    }
    CHECK(found != nullptr, "no Unification statement in the fixture");
    if (found == nullptr)
        return;
    /* `target` is an `Identifier`, not a `Target` — so it has a `ctx`. */
    auto* id = static_cast<const kcl_identifier_t*>(found->u.unification_stmt.target.node);
    CHECK(id != nullptr, "unification target is NULL");
    if (id == nullptr)
        return;
    CHECK(id->ctx == KCL_EXPR_CONTEXT_STORE, "unification target ctx is %s, want Store",
        kcl_expr_context_name(id->ctx));
    /* `value` is a `SchemaExpr`, not an invented config struct. */
    auto* se = static_cast<const kcl_schema_expr_t*>(found->u.unification_stmt.value.node);
    CHECK(se != nullptr, "unification value is NULL");
    if (se != nullptr)
        CHECK(identifier_dotted_ref(&se->name) == "Person",
            "unification schema name is %s, want Person", identifier_dotted_ref(&se->name).c_str());
}

void test_aug_assign_and_assert(const kcl_module_t* m)
{
    int saw_aug = 0, saw_assert = 0, saw_if = 0;
    for (size_t i = 0; i < m->body.count; i++) {
        auto* s = static_cast<const kcl_stmt_t*>(m->body.items[i].node);
        if (s == nullptr)
            continue;
        if (s->kind == KCL_STMT_KIND_AUG_ASSIGN) {
            saw_aug = 1;
            auto* t = static_cast<const kcl_target_t*>(s->u.aug_assign_stmt.target.node);
            CHECK(t != nullptr, "AugAssign target is NULL");
            if (t != nullptr)
                CHECK(t->name.node != nullptr && std::strcmp(t->name.node, "a") == 0,
                    "AugAssign target is %s, want a", t->name.node);
        } else if (s->kind == KCL_STMT_KIND_ASSERT) {
            saw_assert = 1;
            /* `AssertStmt` is `{test, if_cond, msg}` — all NodeRefs. */
            CHECK(s->u.assert_stmt.test.node != nullptr, "Assert has no test");
        } else if (s->kind == KCL_STMT_KIND_IF) {
            saw_if = 1;
            CHECK(s->u.if_stmt.cond.node != nullptr, "If has no cond");
        }
    }
    CHECK(saw_aug, "no AugAssign statement in the fixture");
    CHECK(saw_assert, "no Assert statement in the fixture");
    CHECK(saw_if, "no If statement in the fixture");
}

void test_rule_stmt(const kcl_module_t* m)
{
    const kcl_stmt_t* found = nullptr;
    for (size_t i = 0; i < m->body.count; i++) {
        auto* s = static_cast<const kcl_stmt_t*>(m->body.items[i].node);
        if (s != nullptr && s->kind == KCL_STMT_KIND_RULE) {
            found = s;
            break;
        }
    }
    CHECK(found != nullptr, "no Rule statement in the fixture");
    if (found == nullptr)
        return;
    CHECK(found->u.rule_stmt.name.node != nullptr, "Rule has no name");
    /* `decorators` and `checks` are `Vec<NodeRef<…>>` over structs, so
     * neither element carries a tag. The fixture's rule is undecorated,
     * which is itself the assertion: a decoder that invented a tag
     * would not be able to produce an empty list here. */
    CHECK(found->u.rule_stmt.decorators.count == 0, "Rule has %zu decorators, want 0",
        found->u.rule_stmt.decorators.count);
    CHECK(found->u.rule_stmt.checks.count > 0, "Rule has no checks");
    if (found->u.rule_stmt.checks.count > 0) {
        auto* c = static_cast<const kcl_check_expr_t*>(found->u.rule_stmt.checks.items[0].node);
        CHECK(c != nullptr, "Rule check is NULL");
        if (c != nullptr)
            CHECK(c->test.node != nullptr, "Rule check has no test");
    }
}

void test_schema_decorators_are_flat_call_exprs(const kcl_module_t* m)
{
    const kcl_stmt_t* person = find_schema(m, "Person");
    CHECK(person != nullptr, "no Person schema in the fixture");
    if (person == nullptr)
        return;
    /* `@deprecated` and `@info` are on the `name` attribute, not on the
     * schema header, so the schema's own list is empty. */
    CHECK(person->u.schema_stmt.decorators.count == 0,
        "Person has %zu schema decorators, want 0", person->u.schema_stmt.decorators.count);
    CHECK(person->u.schema_stmt.checks.count > 0, "Person has no checks");
    if (person->u.schema_stmt.checks.count > 0) {
        auto* c = static_cast<const kcl_check_expr_t*>(person->u.schema_stmt.checks.items[0].node);
        CHECK(c != nullptr && c->test.node != nullptr, "Person check has no test");
        CHECK(c != nullptr && c->msg != nullptr, "Person check has no msg");
    }
    auto* name_attr = static_cast<const kcl_stmt_t*>(person->u.schema_stmt.body.items[0].node);
    CHECK(name_attr != nullptr && name_attr->kind == KCL_STMT_KIND_SCHEMA_ATTR,
        "Person's first body statement is not a SchemaAttr");
    if (name_attr == nullptr)
        return;
    /* `SchemaAttr.doc` is a plain `String`, not a `NodeRef<String>`. */
    CHECK(name_attr->u.schema_attr.doc != nullptr, "SchemaAttr doc is NULL");
    CHECK(name_attr->u.schema_attr.decorators.count == 2,
        "SchemaAttr has %zu decorators, want 2", name_attr->u.schema_attr.decorators.count);
    /* `ty` is `NodeRef<Type>`, not an Option. */
    CHECK(name_attr->u.schema_attr.ty.node != nullptr, "SchemaAttr ty is NULL");
    if (name_attr->u.schema_attr.ty.node != nullptr) {
        auto* ty = static_cast<const kcl_type_node_t*>(name_attr->u.schema_attr.ty.node);
        CHECK(ty->kind == KCL_TYPE_KIND_BASIC, "SchemaAttr ty is not a Basic type");
        if (ty->kind == KCL_TYPE_KIND_BASIC)
            CHECK(ty->u.basic_type.basic == KCL_BASIC_TYPE_STR, "SchemaAttr ty is not Str");
    }
    if (name_attr->u.schema_attr.decorators.count == 2) {
        auto* d = static_cast<const kcl_call_expr_t*>(name_attr->u.schema_attr.decorators.items[0].node);
        CHECK(d != nullptr, "SchemaAttr decorator is NULL");
        if (d != nullptr) {
            /* A decorator payload is a bare `{func,args,keywords}`; the
             * `func` is a `NodeRef<Expr>` that *does* carry a tag. */
            CHECK(d->args.count == 0, "@deprecated should have no positional args");
            auto* fn = static_cast<const kcl_expr_t*>(d->func.node);
            CHECK(fn != nullptr && fn->kind == KCL_EXPR_KIND_IDENTIFIER,
                "decorator func is not an Identifier");
            if (fn != nullptr && fn->kind == KCL_EXPR_KIND_IDENTIFIER)
                CHECK(identifier_dotted(&fn->u.identifier) == "deprecated",
                    "decorator func is %s, want deprecated",
                    identifier_dotted(&fn->u.identifier).c_str());
        }
    }
}

void test_schema_expr_is_not_a_call(const kcl_module_t* m)
{
    /* `x = Person {…}` puts its entries in `config` and leaves
     * `keywords` empty; `y = Person(1, name = "Bob")` is a plain Call. */
    const kcl_expr_t* x = assign_value(m, "x");
    CHECK(x != nullptr, "no `x` assignment");
    if (x != nullptr) {
        CHECK(x->kind == KCL_EXPR_KIND_SCHEMA, "`x` RHS is not a SchemaExpr");
        if (x->kind == KCL_EXPR_KIND_SCHEMA) {
            CHECK(x->u.schema_expr.kwargs.count == 0, "`x` SchemaExpr has keywords");
            auto* config = static_cast<const kcl_expr_t*>(x->u.schema_expr.config.node);
            CHECK(config != nullptr && config->kind == KCL_EXPR_KIND_CONFIG,
                "`x` config is not a ConfigExpr");
        }
    }
    const kcl_expr_t* y = assign_value(m, "y");
    CHECK(y != nullptr, "no `y` assignment");
    if (y != nullptr) {
        CHECK(y->kind == KCL_EXPR_KIND_CALL, "`y` RHS is not a Call");
        if (y->kind == KCL_EXPR_KIND_CALL) {
            CHECK(y->u.call_expr.args.count == 1, "`y` has %zu positional args, want 1",
                y->u.call_expr.args.count);
            /* `Keyword.arg` is a `NodeRef<Identifier>`, not an Expr. */
            CHECK(y->u.call_expr.keywords.count == 1, "`y` has %zu keywords, want 1",
                y->u.call_expr.keywords.count);
            if (y->u.call_expr.keywords.count == 1) {
                auto* kw = static_cast<const kcl_keyword_t*>(y->u.call_expr.keywords.items[0].node);
                CHECK(kw != nullptr, "`y` keyword is NULL");
                if (kw != nullptr) {
                    auto* arg = static_cast<const kcl_identifier_t*>(kw->arg.node);
                    CHECK(identifier_dotted(arg) == "name",
                        "`y` keyword arg is %s, want name", identifier_dotted(arg).c_str());
                    CHECK(kw->value != nullptr && kw->value->node != nullptr,
                        "`y` keyword has no value");
                }
            }
        }
    }
}

void test_unary_binary_compare(const kcl_module_t* m)
{
    /* `-a` is `USub`, not a generic "negate". */
    const kcl_expr_t* unary = assign_value(m, "unary");
    CHECK(unary != nullptr && unary->kind == KCL_EXPR_KIND_UNARY, "no `unary` UnaryExpr");
    if (unary != nullptr && unary->kind == KCL_EXPR_KIND_UNARY)
        CHECK(unary->u.unary_expr.op == KCL_UNARY_OP_USUB, "`unary` op is %s, want USub",
            kcl_unary_op_name(unary->u.unary_expr.op));
    const kcl_expr_t* unary_not = assign_value(m, "unary_not");
    CHECK(unary_not != nullptr && unary_not->kind == KCL_EXPR_KIND_UNARY,
        "no `unary_not` UnaryExpr");
    if (unary_not != nullptr && unary_not->kind == KCL_EXPR_KIND_UNARY)
        CHECK(unary_not->u.unary_expr.op == KCL_UNARY_OP_NOT, "`unary_not` op is %s, want Not",
            kcl_unary_op_name(unary_not->u.unary_expr.op));

    /* `ops` and `comparators` are parallel arrays. */
    const kcl_expr_t* chain = assign_value(m, "compare_chain");
    CHECK(chain != nullptr && chain->kind == KCL_EXPR_KIND_COMPARE, "no `compare_chain` Compare");
    if (chain != nullptr && chain->kind == KCL_EXPR_KIND_COMPARE) {
        CHECK(chain->u.compare_expr.ops_count == chain->u.compare_expr.comparators.count,
            "Compare has %zu ops but %zu comparators", chain->u.compare_expr.ops_count,
            chain->u.compare_expr.comparators.count);
        for (size_t i = 0; i < chain->u.compare_expr.ops_count; i++)
            CHECK(kcl_cmp_op_name(chain->u.compare_expr.ops[i])[0] != '?',
                "unrecognised comparison operator at %zu", i);
    }
}

void test_selector_and_subscript(const kcl_module_t* m)
{
    /* `Selector.attr` is an `Identifier`, and `has_question` is the
     * optional-access flag — there is no `attr_name` field. */
    const kcl_expr_t* optional = assign_value(m, "optional");
    CHECK(optional != nullptr && optional->kind == KCL_EXPR_KIND_SELECTOR,
        "no `optional` SelectorExpr");
    if (optional != nullptr && optional->kind == KCL_EXPR_KIND_SELECTOR)
        CHECK(optional->u.selector_expr.has_question, "`optional` has_question is false");
    CHECK(assign_value(m, "selector") != nullptr, "no `selector` assignment");

    /* A slice puts its bounds in `lower`/`upper`/`step` and leaves
     * `index` null. */
    const kcl_expr_t* slice = assign_value(m, "subscript_slice");
    CHECK(slice != nullptr && slice->kind == KCL_EXPR_KIND_SUBSCRIPT,
        "no `subscript_slice` Subscript");
    if (slice != nullptr && slice->kind == KCL_EXPR_KIND_SUBSCRIPT) {
        CHECK(slice->u.subscript_expr.index == nullptr, "slice has a non-null index");
        CHECK(slice->u.subscript_expr.lower != nullptr, "slice has no lower bound");
        CHECK(slice->u.subscript_expr.upper != nullptr, "slice has no upper bound");
    }
    const kcl_expr_t* step = assign_value(m, "subscript_step");
    CHECK(step != nullptr && step->kind == KCL_EXPR_KIND_SUBSCRIPT,
        "no `subscript_step` Subscript");
    if (step != nullptr && step->kind == KCL_EXPR_KIND_SUBSCRIPT) {
        CHECK(step->u.subscript_expr.step != nullptr, "subscript_step has no step");
        CHECK(step->u.subscript_expr.lower != nullptr, "subscript_step has no lower bound");
        CHECK(step->u.subscript_expr.upper != nullptr, "subscript_step has no upper bound");
    }
    /* `subscript_q` is `a?.b` — an optional *Selector*, not a Subscript.
     * The two are easy to confuse, and `has_question` lives on both. */
    const kcl_expr_t* q = assign_value(m, "subscript_q");
    CHECK(q != nullptr && q->kind == KCL_EXPR_KIND_SELECTOR, "no `subscript_q` Selector");
    if (q != nullptr && q->kind == KCL_EXPR_KIND_SELECTOR)
        CHECK(q->u.selector_expr.has_question, "subscript_q has_question is false");
    const kcl_expr_t* plain = assign_value(m, "subscript");
    CHECK(plain != nullptr && plain->kind == KCL_EXPR_KIND_SUBSCRIPT, "no `subscript` Subscript");
    if (plain != nullptr && plain->kind == KCL_EXPR_KIND_SUBSCRIPT)
        CHECK(plain->u.subscript_expr.index != nullptr, "subscript has no index");
}

void test_config_entries(const kcl_module_t* m)
{
    /* `config = {a = 1, b: 2}` uses Override then Union. */
    const kcl_expr_t* config = assign_value(m, "config");
    CHECK(config != nullptr && config->kind == KCL_EXPR_KIND_CONFIG, "no `config` ConfigExpr");
    if (config != nullptr && config->kind == KCL_EXPR_KIND_CONFIG) {
        CHECK(config->u.config_expr.items.count == 2, "config has %zu entries, want 2",
            config->u.config_expr.items.count);
        if (config->u.config_expr.items.count == 2) {
            auto* a = static_cast<const kcl_config_entry_t*>(config->u.config_expr.items.items[0].node);
            auto* b = static_cast<const kcl_config_entry_t*>(config->u.config_expr.items.items[1].node);
            CHECK(a != nullptr && a->operation == KCL_CONFIG_ENTRY_OPERATION_OVERRIDE,
                "config[0] operation is not Override");
            CHECK(b != nullptr && b->operation == KCL_CONFIG_ENTRY_OPERATION_UNION,
                "config[1] operation is not Union");
            /* `skip_serializing_if = "is_false"`, so the key is absent
             * rather than explicitly false. */
            CHECK(a != nullptr && !a->is_shorthand, "config[0] is_shorthand should be false");
        }
    }
    /* The ES6 shorthand sets the flag. */
    const kcl_expr_t* shorthand = assign_value(m, "config_shorthand");
    CHECK(shorthand != nullptr && shorthand->kind == KCL_EXPR_KIND_CONFIG,
        "no `config_shorthand` ConfigExpr");
    if (shorthand != nullptr && shorthand->kind == KCL_EXPR_KIND_CONFIG) {
        for (size_t i = 0; i < shorthand->u.config_expr.items.count; i++) {
            auto* e = static_cast<const kcl_config_entry_t*>(shorthand->u.config_expr.items.items[i].node);
            CHECK(e != nullptr && e->is_shorthand, "config_shorthand[%zu] is_shorthand is false", i);
        }
    }
    /* `config_if` wraps the `ConfigIfEntryExpr` in a `ConfigEntry` whose
     * `key` is null. */
    const kcl_expr_t* config_if = assign_value(m, "config_if");
    CHECK(config_if != nullptr && config_if->kind == KCL_EXPR_KIND_CONFIG,
        "no `config_if` ConfigExpr");
    if (config_if != nullptr && config_if->kind == KCL_EXPR_KIND_CONFIG) {
        CHECK(config_if->u.config_expr.items.count == 1, "config_if has %zu entries, want 1",
            config_if->u.config_expr.items.count);
        if (config_if->u.config_expr.items.count == 1) {
            auto* e = static_cast<const kcl_config_entry_t*>(config_if->u.config_expr.items.items[0].node);
            CHECK(e != nullptr && e->key == nullptr, "config_if entry should have a null key");
            auto* v = e != nullptr ? static_cast<const kcl_expr_t*>(e->value.node) : nullptr;
            CHECK(v != nullptr && v->kind == KCL_EXPR_KIND_CONFIG_IF_ENTRY,
                "config_if entry value is not a ConfigIfEntryExpr");
            if (v != nullptr && v->kind == KCL_EXPR_KIND_CONFIG_IF_ENTRY)
                CHECK(v->u.config_if_entry_expr.items.count > 0, "ConfigIfEntryExpr has no items");
        }
    }
}

void test_comprehensions(const kcl_module_t* m)
{
    const kcl_expr_t* quant = assign_value(m, "quant");
    CHECK(quant != nullptr && quant->kind == KCL_EXPR_KIND_QUANT, "no `quant` QuantExpr");
    if (quant != nullptr && quant->kind == KCL_EXPR_KIND_QUANT) {
        /* `op` is a single QuantOperation, not a list of them. */
        CHECK(quant->u.quant_expr.op == KCL_QUANT_OPERATION_ALL
                || quant->u.quant_expr.op == KCL_QUANT_OPERATION_ANY
                || quant->u.quant_expr.op == KCL_QUANT_OPERATION_FILTER
                || quant->u.quant_expr.op == KCL_QUANT_OPERATION_MAP,
            "quant op is not a known QuantOperation");
        /* `variables` is `Vec<NodeRef<Identifier>>`, not Targets. */
        CHECK(quant->u.quant_expr.variables.count > 0, "quant has no variables");
        if (quant->u.quant_expr.variables.count > 0) {
            auto* v = static_cast<const kcl_identifier_t*>(quant->u.quant_expr.variables.items[0].node);
            CHECK(!identifier_dotted(v).empty(), "quant variable has an empty name");
        }
        CHECK(quant->u.quant_expr.test.node != nullptr, "quant has no test");
    }
    /* `DictComp.entry` is a bare ConfigEntry — there is no `key`/
     * `value` pair and no `cond`. */
    const kcl_expr_t* dict_comp = assign_value(m, "dict_comp");
    CHECK(dict_comp != nullptr && dict_comp->kind == KCL_EXPR_KIND_DICT_COMP,
        "no `dict_comp` DictComp");
    if (dict_comp != nullptr && dict_comp->kind == KCL_EXPR_KIND_DICT_COMP) {
        CHECK(dict_comp->u.dict_comp.entry.key != nullptr, "DictComp entry key is NULL");
        CHECK(dict_comp->u.dict_comp.entry.value.node != nullptr, "DictComp entry value is NULL");
        CHECK(dict_comp->u.dict_comp.generators.count > 0, "DictComp has no generators");
        if (dict_comp->u.dict_comp.generators.count > 0) {
            auto* c = static_cast<const kcl_comp_clause_t*>(dict_comp->u.dict_comp.generators.items[0].node);
            CHECK(c != nullptr, "DictComp generator is NULL");
            if (c != nullptr) {
                /* `CompClause.targets` are Identifiers. */
                CHECK(c->targets.count > 0, "CompClause has no targets");
                if (c->targets.count > 0)
                    CHECK(c->targets.items[0].node != nullptr, "CompClause target is NULL");
            }
        }
    }
    /* `ListIfItemExpr` is `{if_cond, exprs, orelse}` — there is no
     * `if_expr`. */
    const kcl_expr_t* entry_list = assign_value(m, "list_if_entry");
    CHECK(entry_list != nullptr && entry_list->kind == KCL_EXPR_KIND_LIST,
        "no `list_if_entry` ListExpr");
    if (entry_list != nullptr && entry_list->kind == KCL_EXPR_KIND_LIST
        && entry_list->u.list_expr.elts.count > 0) {
        auto* item = static_cast<const kcl_expr_t*>(entry_list->u.list_expr.elts.items[0].node);
        CHECK(item != nullptr && item->kind == KCL_EXPR_KIND_LIST_IF_ITEM,
            "`list_if_entry` does not hold a ListIfItemExpr");
        if (item != nullptr && item->kind == KCL_EXPR_KIND_LIST_IF_ITEM) {
            CHECK(item->u.list_if_item_expr.if_cond.node != nullptr, "ListIfItemExpr has no if_cond");
            CHECK(item->u.list_if_item_expr.exprs.count > 0, "ListIfItemExpr has no exprs");
        }
    }
    /* The `*_if` forms are ListComp — there is no `cond` field. */
    const kcl_expr_t* comp = assign_value(m, "list_if");
    CHECK(comp != nullptr && comp->kind == KCL_EXPR_KIND_LIST_COMP, "no `list_if` ListComp");
    if (comp != nullptr && comp->kind == KCL_EXPR_KIND_LIST_COMP)
        CHECK(comp->u.list_comp.generators.count > 0, "list_if has no generators");
}

void test_lambda_arguments_are_index_aligned(const kcl_module_t* m)
{
    /* `lambda_expr`'s Arguments has `args: [p]`, `defaults: [null]` and
     * `ty_list: [Int]`. Dropping the positional null would leave an
     * empty list, which is the bug this checks for. */
    const kcl_expr_t* lambda = assign_value(m, "lambda_expr");
    CHECK(lambda != nullptr && lambda->kind == KCL_EXPR_KIND_LAMBDA, "no `lambda_expr` LambdaExpr");
    if (lambda == nullptr || lambda->kind != KCL_EXPR_KIND_LAMBDA)
        return;
    CHECK(lambda->u.lambda_expr.args != nullptr, "lambda_expr has no args");
    if (lambda->u.lambda_expr.args == nullptr)
        return;
    auto* args = static_cast<const kcl_arguments_t*>(lambda->u.lambda_expr.args->node);
    CHECK(args != nullptr, "lambda args payload is NULL");
    if (args == nullptr)
        return;
    CHECK(args->args.count == 1, "lambda has %zu args, want 1", args->args.count);
    CHECK(args->defaults.count == 1, "lambda has %zu defaults, want 1", args->defaults.count);
    if (args->defaults.count == 1)
        CHECK(!args->defaults.items[0].present, "lambda's single default should be null");
    CHECK(args->ty_list.count == 1, "lambda has %zu ty_list entries, want 1", args->ty_list.count);
    if (args->ty_list.count == 1) {
        CHECK(args->ty_list.items[0].present, "lambda's ty_list[0] should be present");
        if (args->ty_list.items[0].present) {
            auto* t = static_cast<const kcl_type_node_t*>(args->ty_list.items[0].value.node);
            CHECK(t != nullptr && t->kind == KCL_TYPE_KIND_BASIC, "ty_list[0] is not Basic");
            if (t != nullptr && t->kind == KCL_TYPE_KIND_BASIC)
                CHECK(t->u.basic_type.basic == KCL_BASIC_TYPE_INT, "ty_list[0] is not Int");
        }
    }
    /* The body is statements, not expressions. */
    CHECK(lambda->u.lambda_expr.body.count > 0, "lambda body is empty");
    if (lambda->u.lambda_expr.body.count > 0) {
        auto* body = static_cast<const kcl_stmt_t*>(lambda->u.lambda_expr.body.items[0].node);
        CHECK(body != nullptr && body->kind == KCL_STMT_KIND_EXPR, "lambda body is not an ExprStmt");
    }

    /* `lambda_plain` has `args: null` — an absent Option. */
    const kcl_expr_t* plain = assign_value(m, "lambda_plain");
    CHECK(plain != nullptr && plain->kind == KCL_EXPR_KIND_LAMBDA,
        "no `lambda_plain` LambdaExpr");
    if (plain != nullptr && plain->kind == KCL_EXPR_KIND_LAMBDA)
        CHECK(plain->u.lambda_expr.args == nullptr, "lambda_plain should have a null args");
}

void test_number_literals(const kcl_module_t* m)
{
    /* `NumberLitValue` is tag+content, so the tag is the only thing
     * telling an int payload from a float one. */
    const kcl_expr_t* int_lit = assign_value(m, "lit_int");
    CHECK(int_lit != nullptr && int_lit->kind == KCL_EXPR_KIND_NUMBER_LIT, "no `lit_int` NumberLit");
    if (int_lit != nullptr && int_lit->kind == KCL_EXPR_KIND_NUMBER_LIT) {
        CHECK(int_lit->u.number_lit.value_kind == KCL_NUMBER_LIT_VALUE_INT, "lit_int is not an Int payload");
        CHECK(!int_lit->u.number_lit.has_binary_suffix, "lit_int has a binary suffix");
    }
    const kcl_expr_t* float_lit = assign_value(m, "lit_float");
    CHECK(float_lit != nullptr && float_lit->kind == KCL_EXPR_KIND_NUMBER_LIT,
        "no `lit_float` NumberLit");
    if (float_lit != nullptr && float_lit->kind == KCL_EXPR_KIND_NUMBER_LIT) {
        CHECK(float_lit->u.number_lit.value_kind == KCL_NUMBER_LIT_VALUE_FLOAT,
            "lit_float is not a Float payload");
        CHECK(float_lit->u.number_lit.float_value != 0.0, "lit_float is zero");
    }
    CHECK(assign_value(m, "lit_name") != nullptr, "no `lit_name` assignment");
    const kcl_expr_t* name = assign_value(m, "lit_name");
    CHECK(name != nullptr && name->kind == KCL_EXPR_KIND_NAME_CONSTANT_LIT,
        "lit_name is not a NameConstantLit");
}

void test_string_and_joined(const kcl_module_t* m)
{
    const kcl_expr_t* str = assign_value(m, "lit_str");
    CHECK(str != nullptr && str->kind == KCL_EXPR_KIND_STRING_LIT, "no `lit_str` StringLit");
    if (str != nullptr && str->kind == KCL_EXPR_KIND_STRING_LIT) {
        CHECK(str->u.string_lit.value != nullptr, "StringLit value is NULL");
        CHECK(str->u.string_lit.raw_value != nullptr, "StringLit raw_value is NULL");
    }
    const kcl_expr_t* long_str = assign_value(m, "lit_long");
    CHECK(long_str != nullptr && long_str->kind == KCL_EXPR_KIND_STRING_LIT, "no `lit_long` StringLit");
    if (long_str != nullptr && long_str->kind == KCL_EXPR_KIND_STRING_LIT)
        CHECK(long_str->u.string_lit.is_long_string, "lit_long is_long_string is false");
    /* The field is `format_spec`, not `spec`. */
    const kcl_expr_t* joined = assign_value(m, "joined");
    CHECK(joined != nullptr && joined->kind == KCL_EXPR_KIND_JOINED_STRING, "no `joined` JoinedString");
    if (joined != nullptr && joined->kind == KCL_EXPR_KIND_JOINED_STRING) {
        CHECK(joined->u.joined_string.raw_value != nullptr, "JoinedString raw_value is NULL");
        CHECK(joined->u.joined_string.values.count > 0, "JoinedString has no values");
    }
}

void test_target_paths(const kcl_module_t* m)
{
    /* `Target.paths` is a bare `Vec<MemberOrIndex>` — no NodeRef, so no
     * position on the element itself. */
    int saw_member = 0, saw_index = 0, saw_paths = 0;
    for (size_t i = 0; i < m->body.count; i++) {
        auto* s = static_cast<const kcl_stmt_t*>(m->body.items[i].node);
        if (s == nullptr || s->kind != KCL_STMT_KIND_ASSIGN)
            continue;
        for (size_t j = 0; j < s->u.assign_stmt.targets.count; j++) {
            auto* t = static_cast<const kcl_target_t*>(s->u.assign_stmt.targets.items[j].node);
            if (t == nullptr || t->paths_count == 0)
                continue;
            saw_paths = 1;
            /* `pkgpath` is a single string, not a list. */
            CHECK(t->pkgpath != nullptr, "a path target has a NULL pkgpath");
            for (size_t k = 0; k < t->paths_count; k++) {
                const kcl_member_or_index_t& p = t->paths[k];
                if (p.kind == KCL_MEMBER_OR_INDEX_MEMBER) {
                    saw_member = 1;
                    /* The payload is a `NodeRef<String>`, so it carries
                     * its own position. */
                    CHECK(p.member.node != nullptr, "Member path has no name");
                    CHECK(p.member.pos != nullptr, "Member path has no position");
                } else {
                    saw_index = 1;
                    CHECK(p.index != nullptr && p.index->node != nullptr, "Index path has no expression");
                }
            }
        }
    }
    CHECK(saw_paths, "no assignment carries a path target");
    CHECK(saw_member, "no Member path in the fixture");
    CHECK(saw_index, "no Index path in the fixture");
}

void test_starred_and_missing(const kcl_module_t* m)
{
    /* `StarredExpr.ctx` is `ExprContext`, which has Load and Store —
     * there is no `Del`. */
    const kcl_expr_t* starred = assign_value(m, "starred");
    CHECK(starred != nullptr, "no `starred`");
    if (starred != nullptr) {
        const kcl_expr_t* e = starred;
        if (e->kind == KCL_EXPR_KIND_LIST) {
            CHECK(e->u.list_expr.elts.count > 0, "`starred` list is empty");
            if (e->u.list_expr.elts.count > 0)
                e = static_cast<const kcl_expr_t*>(e->u.list_expr.elts.items[0].node);
        }
        CHECK(e != nullptr && e->kind == KCL_EXPR_KIND_STARRED, "`starred` is not a StarredExpr");
        if (e != nullptr && e->kind == KCL_EXPR_KIND_STARRED)
            CHECK(e->u.starred_expr.ctx == KCL_EXPR_CONTEXT_LOAD
                    || e->u.starred_expr.ctx == KCL_EXPR_CONTEXT_STORE,
                "starred ctx is out of range");
    }
    /* The parser substitutes a placeholder `Identifier` for a missing
     * expression, so this decodes as an Identifier with a name rather
     * than as `Expr::Missing`. */
    const kcl_expr_t* missing = assign_value(m, "missing_expr");
    CHECK(missing != nullptr && missing->kind == KCL_EXPR_KIND_IDENTIFIER,
        "no `missing_expr` placeholder");
    if (missing != nullptr && missing->kind == KCL_EXPR_KIND_IDENTIFIER)
        CHECK(!identifier_dotted(&missing->u.identifier).empty(),
            "the missing_expr placeholder has an empty name");
}

void test_type_aliases_and_types(const kcl_module_t* m)
{
    /* `Type` is adjacently tagged: the tag names the shape and the
     * payload is inlined under `value`. `Any` is the only unit variant,
     * so it has no `value` at all. */
    const kcl_type_node_t* any = alias_type(m, "TAny");
    CHECK(any != nullptr, "no TAny type alias");
    if (any != nullptr) {
        CHECK(any->kind == KCL_TYPE_KIND_ANY, "TAny is not a Type::Any");
        CHECK(any->type_tag != nullptr && std::strcmp(any->type_tag, "Any") == 0,
            "TAny tag is %s, want Any", any->type_tag);
        /* A decoder that hunted for a `value` key would land on the
         * zeroed union by accident and read the basic-type field. */
        CHECK(any->u.basic_type.basic == KCL_BASIC_TYPE_BOOL,
            "TAny should have left the payload union zero");
    }
    /* `Basic` carries a bare string, not an object. */
    const kcl_type_node_t* basic = alias_type(m, "TBasic");
    CHECK(basic != nullptr, "no TBasic type alias");
    if (basic != nullptr) {
        CHECK(basic->kind == KCL_TYPE_KIND_BASIC, "TBasic is not a Type::Basic");
        if (basic->kind == KCL_TYPE_KIND_BASIC)
            CHECK(basic->u.basic_type.basic == KCL_BASIC_TYPE_BOOL
                    || basic->u.basic_type.basic == KCL_BASIC_TYPE_INT
                    || basic->u.basic_type.basic == KCL_BASIC_TYPE_FLOAT
                    || basic->u.basic_type.basic == KCL_BASIC_TYPE_STR,
                "TBasic did not decode a BasicType");
    }
    /* `Named` inlines the Identifier newtype. */
    const kcl_type_node_t* named = alias_type(m, "TNamed");
    CHECK(named != nullptr, "no TNamed type alias");
    if (named != nullptr) {
        CHECK(named->kind == KCL_TYPE_KIND_NAMED, "TNamed is not a Type::Named");
        if (named->kind == KCL_TYPE_KIND_NAMED)
            CHECK(identifier_dotted(&named->u.named_type.name) == "Cloud",
                "TNamed resolves to %s, want Cloud", identifier_dotted(&named->u.named_type.name).c_str());
    }
    /* List / Dict / Union nest under `inner_type` etc. */
    const kcl_type_node_t* list = alias_type(m, "TList");
    CHECK(list != nullptr, "no TList type alias");
    if (list != nullptr) {
        CHECK(list->kind == KCL_TYPE_KIND_LIST, "TList is not a Type::List");
        if (list->kind == KCL_TYPE_KIND_LIST)
            CHECK(list->u.list_type.inner_type != nullptr, "TList has no inner_type");
    }
    const kcl_type_node_t* dict = alias_type(m, "TDict");
    CHECK(dict != nullptr, "no TDict type alias");
    if (dict != nullptr) {
        CHECK(dict->kind == KCL_TYPE_KIND_DICT, "TDict is not a Type::Dict");
        if (dict->kind == KCL_TYPE_KIND_DICT) {
            CHECK(dict->u.dict_type.key_type != nullptr, "TDict has no key_type");
            CHECK(dict->u.dict_type.value_type != nullptr, "TDict has no value_type");
        }
    }
    const kcl_type_node_t* uni = alias_type(m, "TUnion");
    CHECK(uni != nullptr, "no TUnion type alias");
    if (uni != nullptr) {
        CHECK(uni->kind == KCL_TYPE_KIND_UNION, "TUnion is not a Type::Union");
        if (uni->kind == KCL_TYPE_KIND_UNION)
            CHECK(uni->u.union_type.type_elements.count >= 2, "TUnion has %zu elements, want >= 2",
                uni->u.union_type.type_elements.count);
    }
    /* `FunctionType` uses `params_ty` / `ret_ty`, both optional. */
    const kcl_type_node_t* func = alias_type(m, "TFunc");
    CHECK(func != nullptr, "no TFunc type alias");
    if (func != nullptr) {
        CHECK(func->kind == KCL_TYPE_KIND_FUNCTION, "TFunc is not a Type::Function");
        if (func->kind == KCL_TYPE_KIND_FUNCTION) {
            CHECK(func->u.function_type.params_ty != nullptr, "TFunc has no params_ty");
            if (func->u.function_type.params_ty != nullptr)
                CHECK(func->u.function_type.params_ty->count > 0, "TFunc params_ty is empty");
            CHECK(func->u.function_type.ret_ty != nullptr, "TFunc has no ret_ty");
        }
    }
    /* `LiteralType` is itself tag+content, so `Type::Literal`'s value
     * is a *second* tagged document. */
    const kcl_type_node_t* lit_int = alias_type(m, "TLitInt");
    CHECK(lit_int != nullptr, "no TLitInt type alias");
    if (lit_int != nullptr) {
        CHECK(lit_int->kind == KCL_TYPE_KIND_LITERAL, "TLitInt is not a Type::Literal");
        if (lit_int->kind == KCL_TYPE_KIND_LITERAL)
            CHECK(lit_int->u.literal_type.kind == KCL_LITERAL_TYPE_INT
                    || lit_int->u.literal_type.kind == KCL_LITERAL_TYPE_FLOAT
                    || lit_int->u.literal_type.kind == KCL_LITERAL_TYPE_STR
                    || lit_int->u.literal_type.kind == KCL_LITERAL_TYPE_BOOL,
                "TLitInt has an unrecognised LiteralType tag");
    }
    const kcl_type_node_t* lit_str = alias_type(m, "TLitStr");
    CHECK(lit_str != nullptr, "no TLitStr type alias");
    if (lit_str != nullptr && lit_str->kind == KCL_TYPE_KIND_LITERAL
        && lit_str->u.literal_type.kind == KCL_LITERAL_TYPE_STR)
        CHECK(lit_str->u.literal_type.str_value != nullptr, "TLitStr has no string value");
    const kcl_type_node_t* lit_bool = alias_type(m, "TLitBool");
    CHECK(lit_bool != nullptr, "no TLitBool type alias");
    if (lit_bool != nullptr && lit_bool->kind == KCL_TYPE_KIND_LITERAL
        && lit_bool->u.literal_type.kind == KCL_LITERAL_TYPE_BOOL)
        CHECK(lit_bool->u.literal_type.bool_value, "TLitBool should be true");
    const kcl_type_node_t* lit_float = alias_type(m, "TLitFloat");
    CHECK(lit_float != nullptr, "no TLitFloat type alias");
    if (lit_float != nullptr && lit_float->kind == KCL_TYPE_KIND_LITERAL
        && lit_float->u.literal_type.kind == KCL_LITERAL_TYPE_FLOAT)
        CHECK(lit_float->u.literal_type.float_value != 0.0, "TLitFloat is zero");

    /* `TypeAliasStmt` names its fields `type_name` / `type_value`. */
    const kcl_stmt_t* alias = find_type_alias(m, "TAny");
    CHECK(alias != nullptr && alias->u.type_alias_stmt.type_value.node != nullptr,
        "TypeAlias type_value is NULL");
}

void test_every_tag_resolves(const kcl_module_t* m)
{
    Tags unknown;
    for (size_t i = 0; i < m->body.count; i++)
        walk_stmt(static_cast<const kcl_stmt_t*>(m->body.items[i].node), unknown);
    for (size_t i = 0; i < unknown.size(); i++)
        std::fprintf(stderr, "    unresolved tag: %s\n", unknown[i].c_str());
    CHECK(unknown.empty(), "%zu tag(s) in the golden capture failed to resolve", unknown.size());
}

// --- C++-specific contract cases -------------------------------------
//
// These are the ones a C compiler cannot catch. The header is C, so it
// is only the C++ build that proves the unions, the macro-generated node
// wrappers and the enum definitions survive being read by a C++ compiler
// under its stricter conversion and default-construction rules.

void test_header_is_usable_from_cxx(const kcl_module_t*)
{
    /* Every wrapper is a value type in C++ rather than a struct the
     * caller must allocate, so copy one out of a list and read it after
     * the source has gone — this is the whole point of the arena. */
    const kcl_expr_node_t empty {};
    CHECK(empty.node == nullptr && empty.pos == nullptr && empty.id == nullptr,
        "a default-constructed node wrapper is not zeroed");
    const kcl_expr_node_t copy = empty;
    CHECK(copy.node == nullptr, "copying a node wrapper disturbed it");
    /* Value-initialising a union type must zero every arm, not leave
     * whatever was on the stack. */
    const kcl_expr_t e {};
    CHECK(e.kind == KCL_EXPR_KIND_UNKNOWN, "a default-constructed Expr is not UNKNOWN");
    CHECK(e.type_tag == nullptr, "a default-constructed Expr has a type_tag");
    /* The `present` flag must be false, not garbage, for a
     * `Vec<Option<NodeRef<T>>>` slot that was never filled. */
    const kcl_opt_expr_node_t slot {};
    CHECK(!slot.present, "a default-constructed opt-node reports present");
    CHECK(slot.value.node == nullptr, "a default-constructed opt-node has a payload");
    /* Enum names are total — every value a decoder can produce has a
     * printable spelling, which is what the CHECK messages rely on. */
    for (int i = KCL_UNARY_OP_UADD; i <= KCL_UNARY_OP_NOT; i++) {
        auto op = static_cast<kcl_unary_op_t>(i);
        const char* name = kcl_unary_op_name(op);
        CHECK(name != nullptr && name[0] != '?', "UnaryOp %d has no name", i);
    }
    for (int i = KCL_BIN_OP_ADD; i <= KCL_BIN_OP_AS; i++) {
        auto op = static_cast<kcl_bin_op_t>(i);
        const char* name = kcl_bin_op_name(op);
        CHECK(name != nullptr && name[0] != '?', "BinOp %d has no name", i);
    }
    /* `k` and `K` (and `m`/`M`) are distinct suffixes — the name table
     * is case-sensitive, and getting it wrong swaps 1024 for 1000. Note
     * the enum spellings: the unsuffixed `..._K` is lowercase `k`, and
     * `..._K_UPPER` is the uppercase one. */
    CHECK(std::strcmp(kcl_number_binary_suffix_name(KCL_NUMBER_BINARY_SUFFIX_K_UPPER), "K") == 0,
        "K suffix is misnamed");
    CHECK(std::strcmp(kcl_number_binary_suffix_name(KCL_NUMBER_BINARY_SUFFIX_K), "k") == 0,
        "k suffix is misnamed");
    CHECK(std::strcmp(kcl_number_binary_suffix_name(KCL_NUMBER_BINARY_SUFFIX_M_UPPER), "M") == 0,
        "M suffix is misnamed");
    CHECK(std::strcmp(kcl_number_binary_suffix_name(KCL_NUMBER_BINARY_SUFFIX_M), "m") == 0,
        "m suffix is misnamed");
}

void test_raii_wrapper_owns_the_module(const kcl_module_t*)
{
    /* `kcl::ast::parse_module` hands the arena to a unique_ptr, so
     * letting it go out of scope must release the whole tree exactly
     * once. Run under ASan/LSan this is the leak check; without a
     * sanitizer it is at least the double-free check. */
    /* A hand-written minimal module, so this case does not depend on
     * the golden capture at all. The JSON parser skips whitespace, so
     * the document is laid out for reading rather than for compactness. */
    static const char json[] = R"({
        "filename": "x.k",
        "doc": null,
        "body": [
            {
                "id": "s1", "filename": "x.k",
                "line": 1, "column": 0, "end_line": 1, "end_column": 6,
                "node": {
                    "type": "Assign",
                    "targets": [
                        {
                            "id": "t1", "filename": "x.k",
                            "line": 1, "column": 0, "end_line": 1, "end_column": 1,
                            "node": {
                                "name": {
                                    "id": "n1", "filename": "x.k",
                                    "line": 1, "column": 0, "end_line": 1, "end_column": 1,
                                    "node": "a"
                                },
                                "paths": [],
                                "pkgpath": ""
                            }
                        }
                    ],
                    "value": {
                        "id": "v1", "filename": "x.k",
                        "line": 1, "column": 4, "end_line": 1, "end_column": 5,
                        "node": {
                            "type": "Identifier",
                            "names": [
                                {
                                    "id": "s2", "filename": "x.k",
                                    "line": 1, "column": 4, "end_line": 1, "end_column": 5,
                                    "node": "1"
                                }
                            ],
                            "pkgpath": "",
                            "ctx": "Load"
                        }
                    },
                    "ty": null
                }
            }
        ],
        "comments": []
    })";
    {
        auto module = kcl::ast::parse_module(json);
        CHECK(module != nullptr, "the RAII wrapper returned NULL for a minimal module");
        if (module != nullptr) {
            CHECK(module->body.count == 1, "minimal module did not decode one statement");
            if (module->body.count == 1) {
                auto* s = static_cast<const kcl_stmt_t*>(module->body.items[0].node);
                CHECK(s != nullptr && s->kind == KCL_STMT_KIND_ASSIGN, "minimal module is not an Assign");
                if (s != nullptr && s->kind == KCL_STMT_KIND_ASSIGN)
                    CHECK(s->u.assign_stmt.targets.count == 1, "Assign has %zu targets, want 1",
                        s->u.assign_stmt.targets.count);
            }
        }
    }
    /* A null parse result must not crash on destruction. */
    {
        auto module = kcl::ast::parse_module("not json at all");
        CHECK(module == nullptr, "garbage input should not decode");
    }
    CHECK(kcl::ast::parse_program("{\"root\":\".\",\"pkgs\":{}}") != nullptr,
        "an empty program should still decode");
    CHECK(!kcl::ast::has_string_lit_tag(json), "no StringLit tag in a numeric module");
    CHECK(!kcl::ast::has_string_lit_tag(nullptr), "a null ast_json reported a StringLit tag");
}

} // namespace

int main(int argc, char** argv)
{
    const char* fixture = (argc > 1) ? argv[1] : find_fixture();
    if (fixture == nullptr)
        return 1;
    std::string json_text = read_file(fixture);
    if (json_text.empty()) {
        std::fprintf(stderr, "could not read %s\n", fixture);
        return 1;
    }

    auto module = kcl::ast::parse_module(json_text.c_str());
    if (module == nullptr) {
        std::fprintf(stderr, "kcl_ast_parse_module returned NULL\n");
        return 1;
    }
    std::printf("fixture: %s\n", fixture);

    struct Case {
        const char* name;
        TestFn fn;
    };
    Case cases[] = {
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
        { "header is usable as C++", &test_header_is_usable_from_cxx },
        { "kcl::ast RAII owns the module", &test_raii_wrapper_owns_the_module },
    };

    int failed_cases = 0;
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
        int before = g_failures;
        cases[i].fn(module.get());
        if (g_failures == before) {
            std::printf("ok  - %s\n", cases[i].name);
        } else {
            std::printf("FAIL: %s\n", cases[i].name);
            failed_cases++;
        }
    }

    if (failed_cases > 0) {
        std::fprintf(stderr, "%d test(s) failed\n", failed_cases);
        return 1;
    }
    std::printf("all tests passed\n");
    return 0;
}

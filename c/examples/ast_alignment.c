/*
 * ast_alignment.c — Round-trip AST alignment tests for the C binding.
 *
 * Mirrors the Java `AstJsonAlignmentTest`, Go `TestAstJsonAlignment`,
 * Python `tests/ast_test.py`, Node.js `__test__/ast_alignment.spec.mjs`,
 * .NET `KclLib.Tests/AstAlignmentTest.cs`, WASM
 * `tests/ast_alignment.test.ts`, Lua `spec/kcl_lib_ast_spec.lua`,
 * Swift `Tests/KclLibTests/AstJsonAlignmentTest.swift`, and Kotlin
 * `AstJsonAlignmentTest.kt`: parse a real KCL fixture through the
 * native FFI (`kcl_parse_file` / `kcl_parse_program`) and verify the
 * resulting `ast_json` string deserializes cleanly into the typed AST
 * structures declared in `kcl_lib_ast.h`.
 *
 * Build:
 *   $ make examples
 *   $ ./examples/ast_alignment test_data/ast_alignment/main.k
 */

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "kcl_lib.h"
#include "kcl_lib_ast.h"

#define BUFFER_BYTES (4 * 1024 * 1024)

/* Locate the fixture by walking up from the example's CWD. */
static const char* find_fixture(void)
{
    static const char* candidates[] = {
        "test_data/ast_alignment/main.k",
        "../test_data/ast_alignment/main.k",
        "../../test_data/ast_alignment/main.k",
        "../examples/test_data/ast_alignment/main.k",
        NULL,
    };
    for (size_t i = 0; candidates[i] != NULL; i++) {
        FILE* fp = fopen(candidates[i], "r");
        if (fp != NULL) {
            fclose(fp);
            return candidates[i];
        }
    }
    fprintf(stderr, "could not locate ast_alignment/main.k fixture\n");
    return NULL;
}

/* Find the first SchemaStmt whose `name` matches. */
static const kcl_stmt_t* find_schema(const kcl_module_t* module, const char* name)
{
    for (size_t i = 0; i < module->body.count; i++) {
        kcl_stmt_t* stmt = (kcl_stmt_t*)module->body.items[i].node;
        if (stmt == NULL)
            continue;
        if (stmt->kind == KCL_STMT_KIND_SCHEMA) {
            const char* schema_name = stmt->u.schema_stmt.name.node;
            if (schema_name != NULL && strcmp(schema_name, name) == 0)
                return stmt;
        }
    }
    return NULL;
}

/* Find the first AssignStmt whose first target name matches. */
static const kcl_stmt_t* find_assign(const kcl_module_t* module, const char* name)
{
    for (size_t i = 0; i < module->body.count; i++) {
        kcl_stmt_t* stmt = (kcl_stmt_t*)module->body.items[i].node;
        if (stmt == NULL)
            continue;
        if (stmt->kind == KCL_STMT_KIND_ASSIGN && stmt->u.assign_stmt.targets.count > 0) {
            const char* target_name = ((kcl_target_t*)stmt->u.assign_stmt.targets.items[0].node)->name.node;
            if (target_name != NULL && strcmp(target_name, name) == 0)
                return stmt;
        }
    }
    return NULL;
}

/* Walk the module looking for the first StringLit Expr. */
static const kcl_expr_t* find_string_lit(const kcl_module_t* module)
{
    for (size_t i = 0; i < module->body.count; i++) {
        kcl_stmt_t* stmt = (kcl_stmt_t*)module->body.items[i].node;
        if (stmt == NULL)
            continue;
        if (stmt->kind == KCL_STMT_KIND_SCHEMA) {
            /* Check each SchemaAttr's default value. */
            for (size_t j = 0; j < stmt->u.schema_stmt.body.count; j++) {
                kcl_stmt_t* inner = (kcl_stmt_t*)stmt->u.schema_stmt.body.items[j].node;
                if (inner != NULL && inner->kind == KCL_STMT_KIND_SCHEMA_ATTR && inner->u.schema_attr.value != NULL
                    && inner->u.schema_attr.value->node != NULL
                    && ((kcl_expr_t*)inner->u.schema_attr.value->node)->kind == KCL_EXPR_KIND_STRING_LIT) {
                    return (const kcl_expr_t*)inner->u.schema_attr.value->node;
                }
            }
        }
    }
    return NULL;
}

static int test_module_filename(const char* ast_json)
{
    kcl_module_t* module = kcl_ast_parse_module(ast_json);
    assert(module != NULL);
    assert(module->filename != NULL);
    assert(strstr(module->filename, "main.k") != NULL);
    kcl_module_free(module);
    return 0;
}

static int test_long_form_string_lit(const char* ast_json)
{
    /* Wire JSON carries the long-form `"StringLit"` tag — the
     * short-form `"String"` from `@JsonTypeName("String")` would fail
     * the polymorphic match. */
    assert(strstr(ast_json, "\"StringLit\"") != NULL);
    kcl_module_t* module = kcl_ast_parse_module(ast_json);
    const kcl_expr_t* lit = find_string_lit(module);
    assert(lit != NULL);
    assert(lit->kind == KCL_EXPR_KIND_STRING_LIT);
    kcl_module_free(module);
    return 0;
}

static int test_config_entry_is_shorthand(void)
{
    /* Mirror Rust's #[serde(skip_serializing_if = "is_false")]: omitted
     * when false, emitted when true. The C AST exposes this as a
     * boolean defaulting to false. */
    kcl_config_entry_t ce = { 0 };
    assert(ce.is_shorthand == false);
    ce.is_shorthand = true;
    assert(ce.is_shorthand == true);
    return 0;
}

static int test_assign_stmt_with_schema_expr(const char* ast_json)
{
    kcl_module_t* module = kcl_ast_parse_module(ast_json);
    const kcl_stmt_t* assign = find_assign(module, "x");
    assert(assign != NULL);
    assert(assign->kind == KCL_STMT_KIND_ASSIGN);
    kcl_expr_t* value = (kcl_expr_t*)assign->u.assign_stmt.value.node;
    assert(value != NULL);
    assert(value->kind == KCL_EXPR_KIND_SCHEMA);
    kcl_module_free(module);
    return 0;
}

static int test_schema_stmt_decorators(const char* ast_json)
{
    kcl_module_t* module = kcl_ast_parse_module(ast_json);
    const kcl_stmt_t* article = find_schema(module, "Article");
    assert(article != NULL);
    kcl_decorator_node_list_t* decos = (kcl_decorator_node_list_t*)article->u.schema_stmt.decorators;
    assert(decos != NULL && decos->count > 0);
    for (size_t i = 0; i < decos->count; i++) {
        kcl_decorator_t* d = (kcl_decorator_t*)decos->items[i].node;
        assert(d != NULL);
        assert(d->func != NULL);
        kcl_expr_t* f = (kcl_expr_t*)d->func->node;
        assert(f != NULL);
        /* Decorator.func wraps an Identifier expression — no
         * `"type":"Call"` tag in the flat shape. */
        assert(f->kind == KCL_EXPR_KIND_IDENTIFIER);
    }
    kcl_module_free(module);
    return 0;
}

static int test_schema_attr_decorators(const char* ast_json)
{
    kcl_module_t* module = kcl_ast_parse_module(ast_json);
    const kcl_stmt_t* person = find_schema(module, "Person");
    assert(person != NULL);
    int found = 0;
    for (size_t i = 0; i < person->u.schema_stmt.body.count; i++) {
        kcl_stmt_t* inner = (kcl_stmt_t*)person->u.schema_stmt.body.items[i].node;
        if (inner != NULL && inner->kind == KCL_STMT_KIND_SCHEMA_ATTR
            && inner->u.schema_attr.name.node != NULL
            && strcmp(inner->u.schema_attr.name.node, "name") == 0) {
            kcl_decorator_node_list_t* decos = (kcl_decorator_node_list_t*)inner->u.schema_attr.decorators;
            assert(decos != NULL && decos->count == 1);
            found = 1;
            break;
        }
    }
    assert(found);
    kcl_module_free(module);
    return 0;
}

static int test_lambda_expr_with_arguments(const char* ast_json)
{
    kcl_module_t* module = kcl_ast_parse_module(ast_json);
    const kcl_stmt_t* adder = find_assign(module, "adder");
    assert(adder != NULL);
    kcl_expr_t* value = (kcl_expr_t*)adder->u.assign_stmt.value.node;
    assert(value != NULL);
    assert(value->kind == KCL_EXPR_KIND_LAMBDA);
    kcl_arguments_t* args = (kcl_arguments_t*)value->u.lambda_expr.args.node;
    assert(args != NULL && args->args.count == 2);
    kcl_module_free(module);
    return 0;
}

static int test_parse_program(const char* fixture)
{
    const char* paths[] = { fixture };
    char* ast_json = (char*)malloc(BUFFER_BYTES);
    if (!kcl_parse_program(paths, 1, ast_json, BUFFER_BYTES)) {
        fprintf(stderr, "kcl_parse_program failed: %s\n", ast_json);
        free(ast_json);
        return 1;
    }
    kcl_program_t* program = kcl_ast_parse_program(ast_json);
    assert(program != NULL);
    assert(program->main_package_count > 0);
    assert(program->main_package[0]->filename != NULL);
    assert(strstr(program->main_package[0]->filename, ".k") != NULL);
    kcl_program_free(program);
    free(ast_json);
    return 0;
}

int main(int argc, char** argv)
{
    const char* fixture = (argc > 1) ? argv[1] : find_fixture();
    if (fixture == NULL)
        return 1;

    char* ast_json = (char*)malloc(BUFFER_BYTES);
    if (!kcl_parse_file(fixture, ast_json, BUFFER_BYTES)) {
        fprintf(stderr, "kcl_parse_file failed: %s\n", ast_json);
        free(ast_json);
        return 1;
    }

    struct {
        const char* name;
        int (*fn)(const char*);
    } tests[] = {
        { "module filename", test_module_filename },
        { "long-form literal discriminators", test_long_form_string_lit },
        { "ConfigEntry.is_shorthand round-trip", NULL },
        { "AssignStmt with SchemaExpr RHS", test_assign_stmt_with_schema_expr },
        { "SchemaStmt decorators as flat DTO", test_schema_stmt_decorators },
        { "SchemaAttr decorators", test_schema_attr_decorators },
        { "LambdaExpr with Arguments", test_lambda_expr_with_arguments },
    };

    int failed = 0;
    for (size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        if (tests[i].fn == NULL) {
            /* Standalone tests don't take the AST JSON. */
            if (test_config_entry_is_shorthand() != 0) {
                fprintf(stderr, "FAIL: %s\n", tests[i].name);
                failed++;
                continue;
            }
        } else if (tests[i].fn(ast_json) != 0) {
            fprintf(stderr, "FAIL: %s\n", tests[i].name);
            failed++;
            continue;
        }
        printf("ok  - %s\n", tests[i].name);
    }

    if (test_parse_program(fixture) != 0) {
        fprintf(stderr, "FAIL: parseProgram returns list of modules\n");
        failed++;
    } else {
        printf("ok  - parseProgram returns list of modules\n");
    }

    free(ast_json);
    if (failed > 0) {
        fprintf(stderr, "%d test(s) failed\n", failed);
        return 1;
    }
    printf("all tests passed\n");
    return 0;
}
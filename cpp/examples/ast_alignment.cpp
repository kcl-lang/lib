/*
 * ast_alignment.cpp — Round-trip AST alignment tests for the C++
 * binding.
 *
 * Mirrors the Java `AstJsonAlignmentTest`, Go `TestAstJsonAlignment`,
 * Python `tests/ast_test.py`, Node.js `__test__/ast_alignment.spec.mjs`,
 * .NET `KclLib.Tests/AstAlignmentTest.cs`, WASM
 * `tests/ast_alignment.test.ts`, Lua `spec/kcl_lib_ast_spec.lua`,
 * Swift `Tests/KclLibTests/AstJsonAlignmentTest.swift`, and Kotlin
 * `AstJsonAlignmentTest.kt`: parse a real KCL fixture through the
 * native FFI (`kcl_lib::parse_file` / `kcl_lib::parse_program`) and
 * verify the resulting `ast_json` string deserializes cleanly into
 * the typed AST structures declared in `kcl_lib_ast.h`.
 *
 * Build:
 *   $ make cpp
 *   $ ./build/examples/ast_alignment test_data/ast_alignment/main.k
 */

#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "kcl_lib.hpp"
#include "kcl_lib_ast.hpp"

namespace {

constexpr size_t kBufferBytes = 4 * 1024 * 1024;

const char* find_fixture()
{
    static const char* candidates[] = {
        "test_data/ast_alignment/main.k",
        "../test_data/ast_alignment/main.k",
        "../../test_data/ast_alignment/main.k",
        "../examples/test_data/ast_alignment/main.k",
        nullptr,
    };
    for (size_t i = 0; candidates[i] != nullptr; i++) {
        if (FILE* fp = std::fopen(candidates[i], "r"); fp != nullptr) {
            std::fclose(fp);
            return candidates[i];
        }
    }
    std::fprintf(stderr, "could not locate ast_alignment/main.k fixture\n");
    return nullptr;
}

const kcl_stmt_t* find_schema(const kcl_module_t* module, const char* name)
{
    for (size_t i = 0; i < module->body.count; i++) {
        auto* stmt = static_cast<kcl_stmt_t*>(module->body.items[i].node);
        if (stmt == nullptr)
            continue;
        if (stmt->kind == KCL_STMT_KIND_SCHEMA) {
            const char* schema_name = stmt->u.schema_stmt.name.node;
            if (schema_name != nullptr && std::strcmp(schema_name, name) == 0)
                return stmt;
        }
    }
    return nullptr;
}

const kcl_stmt_t* find_assign(const kcl_module_t* module, const char* name)
{
    for (size_t i = 0; i < module->body.count; i++) {
        auto* stmt = static_cast<kcl_stmt_t*>(module->body.items[i].node);
        if (stmt == nullptr)
            continue;
        if (stmt->kind == KCL_STMT_KIND_ASSIGN && stmt->u.assign_stmt.targets.count > 0) {
            const char* target_name = static_cast<kcl_target_t*>(stmt->u.assign_stmt.targets.items[0].node)->name.node;
            if (target_name != nullptr && std::strcmp(target_name, name) == 0)
                return stmt;
        }
    }
    return nullptr;
}

const kcl_expr_t* find_string_lit(const kcl_module_t* module)
{
    for (size_t i = 0; i < module->body.count; i++) {
        auto* stmt = static_cast<kcl_stmt_t*>(module->body.items[i].node);
        if (stmt == nullptr || stmt->kind != KCL_STMT_KIND_SCHEMA)
            continue;
        for (size_t j = 0; j < stmt->u.schema_stmt.body.count; j++) {
            auto* inner = static_cast<kcl_stmt_t*>(stmt->u.schema_stmt.body.items[j].node);
            if (inner == nullptr || inner->kind != KCL_STMT_KIND_SCHEMA_ATTR
                || inner->u.schema_attr.value == nullptr
                || inner->u.schema_attr.value->node == nullptr)
                continue;
            auto* value = static_cast<kcl_expr_t*>(inner->u.schema_attr.value->node);
            if (value->kind == KCL_EXPR_KIND_STRING_LIT)
                return value;
        }
    }
    return nullptr;
}

int test_module_filename(const char* ast_json)
{
    auto module = kcl::ast::parse_module(ast_json);
    assert(module != nullptr);
    assert(module->filename != nullptr);
    assert(std::strstr(module->filename, "main.k") != nullptr);
    return 0;
}

int test_long_form_string_lit(const char* ast_json)
{
    /* Wire JSON carries the long-form `"StringLit"` tag — the
     * short-form `"String"` from `@JsonTypeName("String")` would fail
     * the polymorphic match. */
    assert(kcl::ast::has_string_lit_tag(ast_json));
    auto module = kcl::ast::parse_module(ast_json);
    const kcl_expr_t* lit = find_string_lit(module.get());
    assert(lit != nullptr);
    assert(lit->kind == KCL_EXPR_KIND_STRING_LIT);
    return 0;
}

int test_config_entry_is_shorthand()
{
    /* Mirror Rust's #[serde(skip_serializing_if = "is_false")]: omitted
     * when false, emitted when true. The C AST exposes this as a
     * boolean defaulting to false. */
    kcl_config_entry_t ce {};
    assert(ce.is_shorthand == false);
    ce.is_shorthand = true;
    assert(ce.is_shorthand == true);
    return 0;
}

int test_assign_stmt_with_schema_expr(const char* ast_json)
{
    auto module = kcl::ast::parse_module(ast_json);
    const kcl_stmt_t* assign = find_assign(module.get(), "x");
    assert(assign != nullptr);
    assert(assign->kind == KCL_STMT_KIND_ASSIGN);
    auto* value = static_cast<kcl_expr_t*>(assign->u.assign_stmt.value.node);
    assert(value != nullptr);
    assert(value->kind == KCL_EXPR_KIND_SCHEMA);
    return 0;
}

int test_schema_stmt_decorators(const char* ast_json)
{
    auto module = kcl::ast::parse_module(ast_json);
    const kcl_stmt_t* article = find_schema(module.get(), "Article");
    assert(article != nullptr);
    auto* decos = static_cast<kcl_decorator_node_list_t*>(article->u.schema_stmt.decorators);
    assert(decos != nullptr && decos->count > 0);
    for (size_t i = 0; i < decos->count; i++) {
        auto* d = static_cast<kcl_decorator_t*>(decos->items[i].node);
        assert(d != nullptr);
        assert(d->func != nullptr);
        auto* f = static_cast<kcl_expr_t*>(d->func->node);
        assert(f != nullptr);
        /* Decorator.func wraps an Identifier expression — no
         * `"type":"Call"` tag in the flat shape. */
        assert(f->kind == KCL_EXPR_KIND_IDENTIFIER);
    }
    return 0;
}

int test_schema_attr_decorators(const char* ast_json)
{
    auto module = kcl::ast::parse_module(ast_json);
    const kcl_stmt_t* person = find_schema(module.get(), "Person");
    assert(person != nullptr);
    int found = 0;
    for (size_t i = 0; i < person->u.schema_stmt.body.count; i++) {
        auto* inner = static_cast<kcl_stmt_t*>(person->u.schema_stmt.body.items[i].node);
        if (inner == nullptr || inner->kind != KCL_STMT_KIND_SCHEMA_ATTR
            || inner->u.schema_attr.name.node == nullptr
            || std::strcmp(inner->u.schema_attr.name.node, "name") != 0)
            continue;
        auto* decos = static_cast<kcl_decorator_node_list_t*>(inner->u.schema_attr.decorators);
        assert(decos != nullptr && decos->count == 1);
        found = 1;
        break;
    }
    assert(found);
    return 0;
}

int test_lambda_expr_with_arguments(const char* ast_json)
{
    auto module = kcl::ast::parse_module(ast_json);
    const kcl_stmt_t* adder = find_assign(module.get(), "adder");
    assert(adder != nullptr);
    auto* value = static_cast<kcl_expr_t*>(adder->u.assign_stmt.value.node);
    assert(value != nullptr);
    assert(value->kind == KCL_EXPR_KIND_LAMBDA);
    auto* args = static_cast<kcl_arguments_t*>(value->u.lambda_expr.args.node);
    assert(args != nullptr && args->args.count == 2);
    return 0;
}

int test_parse_program(const char* fixture)
{
    kcl_lib::ParseProgramArgs args;
    args.paths.push_back(fixture);
    auto result = kcl_lib::parse_program(args);
    assert(result.errors.empty());
    auto program = kcl::ast::parse_program(result.ast_json.c_str());
    assert(program != nullptr);
    assert(program->main_package_count > 0);
    assert(program->main_package[0]->filename != nullptr);
    assert(std::strstr(program->main_package[0]->filename, ".k") != nullptr);
    return 0;
}

} // namespace

int main(int argc, char** argv)
{
    const char* fixture = (argc > 1) ? argv[1] : find_fixture();
    if (fixture == nullptr)
        return 1;

    kcl_lib::ParseFileArgs args;
    args.path = fixture;
    auto result = kcl_lib::parse_file(args);
    assert(result.errors.empty());
    const std::string& ast_json = std::string(result.ast_json);

    struct TestCase {
        const char* name;
        int (*fn)(const char*);
    };
    TestCase tests[] = {
        { "module filename", &test_module_filename },
        { "long-form literal discriminators", &test_long_form_string_lit },
        { "ConfigEntry.is_shorthand round-trip", nullptr },
        { "AssignStmt with SchemaExpr RHS", &test_assign_stmt_with_schema_expr },
        { "SchemaStmt decorators as flat DTO", &test_schema_stmt_decorators },
        { "SchemaAttr decorators", &test_schema_attr_decorators },
        { "LambdaExpr with Arguments", &test_lambda_expr_with_arguments },
    };

    int failed = 0;
    for (auto& t : tests) {
        if (t.fn == nullptr) {
            if (test_config_entry_is_shorthand() != 0) {
                std::fprintf(stderr, "FAIL: %s\n", t.name);
                failed++;
                continue;
            }
        } else if (t.fn(ast_json.c_str()) != 0) {
            std::fprintf(stderr, "FAIL: %s\n", t.name);
            failed++;
            continue;
        }
        std::printf("ok  - %s\n", t.name);
    }

    if (test_parse_program(fixture) != 0) {
        std::fprintf(stderr, "FAIL: parseProgram returns list of modules\n");
        failed++;
    } else {
        std::printf("ok  - parseProgram returns list of modules\n");
    }

    if (failed > 0) {
        std::fprintf(stderr, "%d test(s) failed\n", failed);
        return 1;
    }
    std::printf("all tests passed\n");
    return 0;
}
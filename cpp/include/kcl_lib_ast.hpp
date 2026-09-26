/*
 * kcl_lib_ast.hpp — C++ wrapper around the typed AST module for the
 * C binding.
 *
 * Mirrors the typed AST packages already merged for Java, Go, Python,
 * Node.js, .NET, WASM, Lua, Swift, and Kotlin: parse a real KCL
 * fixture through the native FFI (`kcl_lib::parse_file` /
 * `kcl_lib::parse_program`) and verify the resulting `ast_json` string
 * deserializes cleanly into the typed AST structures declared in
 * `kcl_lib_ast.h`.
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
 * The C++ wrapper adds RAII smart-pointer wrappers around the C
 * types so callers don't have to remember the matching `*_free`
 * function. The underlying C types are still reachable via the
 * `.get()` member for callers who want to walk the AST directly.
 *
 * Build:
 *   $ make cpp
 *   $ ./build/examples/ast_alignment test_data/ast_alignment/main.k
 */

#pragma once

#include <memory>
#include <string>
#include <vector>

#include "kcl_lib_ast.h"

namespace kcl {
namespace ast {

// --- Module -----------------------------------------------------------

inline std::unique_ptr<kcl_module_t, decltype(&kcl_module_free)> parse_module(
    const char* ast_json)
{
    return std::unique_ptr<kcl_module_t, decltype(&kcl_module_free)>(
        kcl_ast_parse_module(ast_json), &kcl_module_free);
}

// --- Program ----------------------------------------------------------

inline std::unique_ptr<kcl_program_t, decltype(&kcl_program_free)> parse_program(
    const char* ast_json)
{
    return std::unique_ptr<kcl_program_t, decltype(&kcl_program_free)>(
        kcl_ast_parse_program(ast_json), &kcl_program_free);
}

// --- Helpers ----------------------------------------------------------

/** True when the wire JSON contains the long-form `"StringLit"` tag —
 *  the polymorphic discriminator that the Rust `ast::Module`
 *  serializer emits for `StringLit`. */
inline bool has_string_lit_tag(const char* ast_json)
{
    if (ast_json == nullptr)
        return false;
    return std::string(ast_json).find("\"StringLit\"") != std::string::npos;
}

} // namespace ast
} // namespace kcl
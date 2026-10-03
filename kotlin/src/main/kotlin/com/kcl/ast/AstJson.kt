// AstJson.kt — Kotlin DSL entry points for the typed AST JSON parser.
//
// Mirrors the Java `JsonUtil.deserializeProgram` helper and the typed AST
// classes in `com.kcl.ast`. The Kotlin binding compiles Java sources
// alongside Kotlin sources, so this reuses the same Jackson-based
// deserialization that powers the Java binding's `com.kcl.ast` classes.
//
// Wire shape mirrors Rust's `#[serde(tag = "type")]` plus the handful of
// flat DTOs (`Decorator`, `SchemaConfig`, `ConfigEntry`, `Keyword`,
// `Arguments`, `MemberOrIndex`, `Target`) whose `NodeRef<T>` payload lacks
// the polymorphic discriminator — the Rust source declares them as plain
// structs rather than enum variants.

package com.kcl.ast

import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jdk8.Jdk8Module

/**
 * Shared `ObjectMapper` configured to ignore unknown properties. This
 * matches the Java binding's `com.kcl.util.JsonUtil` configuration so
 * `parseModule` / `parseProgram` accept both the long-form
 * `NumberLit`/`StringLit`/`NameConstantLit` discriminators (cross the
 * wire) and any future additive fields.
 *
 * The AST models Rust's `Option<T>` as `java.util.Optional`, so the Jdk8
 * module is registered here: without it Jackson raises
 * `InvalidDefinitionException` the moment it meets one of those fields
 * rather than leaving it empty.
 */
internal val AST_OBJECT_MAPPER: ObjectMapper = ObjectMapper().apply {
    registerModule(Jdk8Module())
    configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)
}

/**
 * Deserialize a single-module AST JSON string (the `ast_json` field of
 * `ParseFileResult`) into a typed [Module]. Mirrors the Python
 * `parseModule`, Node.js `parseModule`, .NET `AstLoader.ParseModule`,
 * and WASM `parseModule` helpers.
 */
fun parseModule(astJson: String): Module =
    AST_OBJECT_MAPPER.readValue(astJson, Module::class.java)

/**
 * Deserialize a multi-module AST JSON envelope (the `ast_json` field of
 * `ParseProgramResult`) into a list of typed [Module]s. The wire shape is
 * `{"root": ".", "pkgs": {"__main__": [Module, …]}}` so we read the
 * envelope as a `Program` and return the `__main__` package's modules —
 * matching the Python/Node.js/.NET/WASM `parseProgram` helpers.
 */
fun parseProgram(astJson: String): List<Module> {
    val program = AST_OBJECT_MAPPER.readValue(astJson, Program::class.java)
    return program.mainPackage.orEmpty()
}
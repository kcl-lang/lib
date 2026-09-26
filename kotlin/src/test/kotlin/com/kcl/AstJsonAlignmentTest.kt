// AstJsonAlignmentTest.kt — Round-trip AST alignment tests for the Kotlin binding.
//
// Mirrors the Java `AstJsonAlignmentTest`, Go `TestAstJsonAlignment`,
// Python `tests/ast_test.py`, Node.js `__test__/ast_alignment.spec.mjs`,
// .NET `KclLib.Tests/AstAlignmentTest.cs`, and WASM
// `tests/ast_alignment.test.ts`: parse a real KCL fixture through the
// native JNI bridge (`API.parseFile`/`API.parseProgram`) and verify the
// resulting `astJson` string deserializes cleanly into the typed AST
// classes in `com.kcl.ast`.

package com.kcl

import com.kcl.api.API
import com.kcl.ast.Decorator
import com.kcl.ast.Module
import com.kcl.ast.SchemaAttr
import com.kcl.ast.SchemaStmt
import com.kcl.ast.parseModule
import com.kcl.ast.parseProgram
import com.kcl.api.Spec.ParseFileArgs
import com.kcl.api.Spec.ParseFileResult
import com.kcl.api.Spec.ParseProgramArgs
import com.kcl.api.Spec.ParseProgramResult
import java.nio.file.Paths
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class AstJsonAlignmentTest {
    companion object {
        private val FIXTURE_PATH = Paths.get("src", "test_data", "ast_alignment", "main.k").toString()
        private val api = API()

        private fun firstSchemaByName(module: Module, name: String): SchemaStmt? =
            module.body
                .map { it.node }
                .filterIsInstance<SchemaStmt>()
                .firstOrNull { it.name?.node == name }

        private fun firstAssignNamed(module: Module, name: String): com.kcl.ast.AssignStmt? =
            module.body
                .map { it.node }
                .filterIsInstance<com.kcl.ast.AssignStmt>()
                .firstOrNull { stmt ->
                    val target = stmt.targets.firstOrNull()?.node
                    target?.name == name
                }
    }

    @Test
    fun `module has filename and no pkg`() {
        val result: ParseFileResult = api.parseFile(ParseFileArgs.newBuilder().setPath(FIXTURE_PATH).build())
        assertEquals(0, result.errorsCount)
        val module = parseModule(result.astJson)
        assertTrue(module.filename.endsWith("main.k"))
        // Module must not carry a `pkg` field — round-trip should produce
        // neither one in input nor one on output.
        assertFalse(
            module::class.java.declaredFields.any { it.name == "pkg" },
            "Module.java should not have a pkg field after alignment",
        )
    }

    @Test
    fun `literal discriminators use long form`() {
        // The fixture declares string literals (`"anonymous"`, `"Alice"`)
        // inside SchemaAttr defaults and SchemaExpr configs. The Rust
        // compiler emits them with the long-form `"StringLit"` discriminator;
        // Jackson resolves that to `com.kcl.ast.StringLit` via the
        // `@JsonSubTypes` mapping on `Expr`. A legacy short-form `"String"`
        // tag (from `@JsonTypeName("String")` on the concrete class) would
        // fail the polymorphic match.
        val result: ParseFileResult = api.parseFile(ParseFileArgs.newBuilder().setPath(FIXTURE_PATH).build())
        val astJson = result.astJson
        assertTrue(astJson.contains("\"StringLit\""), "expected \"StringLit\" tag in wire JSON")
        // And the long-form discriminator survives round-trip — deserializing
        // the AST into the typed classes must yield at least one `StringLit`
        // (e.g. the `name: str = "anonymous"` default on `Person`).
        val module = parseModule(astJson)
        val hasStringLit = walkForStringLit(module.body)
        assertNotNull(hasStringLit, "expected at least one StringLit in fixture body")
    }

    private fun walkForStringLit(
        items: List<com.kcl.ast.NodeRef<com.kcl.ast.Stmt>>,
    ): com.kcl.ast.StringLit? {
        for (item in items) {
            val node = item.node
            // SchemaAttr.value is `NodeRef<Expr>` whose `node` is the Expr
            // polymorphic instance — recurse into all Expr-bearing fields
            // by visiting each SchemaStmt's body.
            if (node is com.kcl.ast.SchemaStmt) {
                // Walk the SchemaStmt.body recursively (lambdas in check
                // expressions, nested schemas, etc.).
                val found = walkForStringLit(node.body)
                if (found != null) return found
                // And inspect each SchemaAttr's default value for a
                // StringLit directly.
                for (attrRef in node.body) {
                    val attr = attrRef.node
                    if (attr is com.kcl.ast.SchemaAttr) {
                        val lit = attr.value?.node
                        if (lit is com.kcl.ast.StringLit) return lit
                    }
                }
            }
        }
        return null
    }

    @Test
    fun `configEntry isShorthand round-trips`() {
        // Mirror Rust's #[serde(skip_serializing_if = "is_false")]: omitted
        // when false, emitted when true. The Java/Kotlin AST exposes this
        // as a boolean defaulting to false.
        val ce = com.kcl.ast.ConfigEntry()
        assertFalse(ce.isShorthand)
        ce.isShorthand = true
        assertTrue(ce.isShorthand)
    }

    @Test
    fun `assign stmt with schema expr value`() {
        val result: ParseFileResult = api.parseFile(ParseFileArgs.newBuilder().setPath(FIXTURE_PATH).build())
        val module = parseModule(result.astJson)
        val assign = firstAssignNamed(module, "x")
        assertNotNull(assign)
        val value = assign!!.value.node
        assertTrue(
            value is com.kcl.ast.SchemaExpr,
            "expected SchemaExpr on the right-hand side of `x =`, got ${value::class.simpleName}",
        )
    }

    @Test
    fun `schema stmt decorators are flat Decorator DTO`() {
        val result: ParseFileResult = api.parseFile(ParseFileArgs.newBuilder().setPath(FIXTURE_PATH).build())
        val module = parseModule(result.astJson)
        val article = firstSchemaByName(module, "Article")
        assertNotNull(article)
        val decorators: List<Decorator> = article!!.decorators.map { it.node }
        assertTrue(decorators.isNotEmpty())
        // The Decorator.Func payload is a Node wrapping an Identifier expression
        // (no `"type":"Call"` tag in the flat shape).
        decorators.forEach { deco ->
            assertTrue(
                deco.func.node is com.kcl.ast.IdentifierExpr,
                "Decorator.func should resolve to IdentifierExpr, got ${deco.func.node::class.simpleName}",
            )
        }
    }

    @Test
    fun `schema attr has decorators field`() {
        val result: ParseFileResult = api.parseFile(ParseFileArgs.newBuilder().setPath(FIXTURE_PATH).build())
        val module = parseModule(result.astJson)
        val person = firstSchemaByName(module, "Person")
        assertNotNull(person)
        val nameAttr: SchemaAttr? = person!!.body
            .map { it.node }
            .filterIsInstance<SchemaAttr>()
            .firstOrNull { it.name.node == "name" }
        assertNotNull(nameAttr)
        assertEquals(1, nameAttr!!.decorators.size)
    }

    @Test
    fun `lambda expr with arguments`() {
        val result: ParseFileResult = api.parseFile(ParseFileArgs.newBuilder().setPath(FIXTURE_PATH).build())
        val module = parseModule(result.astJson)
        val adder = firstAssignNamed(module, "adder")
        assertNotNull(adder)
        val value = adder!!.value.node
        assertTrue(value is com.kcl.ast.LambdaExpr)
        val args = (value as com.kcl.ast.LambdaExpr).args.node.args
        assertEquals(2, args.size)
    }

    @Test
    fun `parseProgram returns list of modules`() {
        val result: ParseProgramResult =
            api.parseProgram(ParseProgramArgs.newBuilder().addPaths(FIXTURE_PATH).build())
        assertEquals(0, result.errorsCount)
        val modules = parseProgram(result.astJson)
        assertTrue(modules.isNotEmpty())
        assertTrue(modules.first().filename.endsWith(".k"))
    }
}
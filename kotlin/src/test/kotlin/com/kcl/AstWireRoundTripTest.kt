// AstWireRoundTripTest.kt — The write side, checked against the capture.
//
// `AstJsonAlignmentTest` covers one direction: `ast_json` from the native
// parser deserializes into the typed classes. This covers the other, and the
// round trip between them:
//
//   * decode the golden capture and write it back, expecting the identical
//     document. A dropped field, a renamed key or a `null` written where serde
//     writes a list all show up as a diff, and none of them would be visible
//     from the decode side alone — a decoder that ignores a key it never
//     asked for produces exactly the same objects;
//   * build a node by hand with the `AstBuild.kt` factories and assert it
//     equals the capture's, which is the only way to show the constructors
//     carry every field the wire does rather than a plausible subset.
//
// The capture is `testdata/ast/alignment.json`, the same file the Python
// `ast_contract_test.py` and the .NET `AstWireRoundTripTest` read. No native
// runtime is needed: these tests only exercise the Kotlin AST package, which
// is why they run in the same suite as the parse tests but do not need the
// JNI library.

package com.kcl

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import com.kcl.ast.BasicType
import com.kcl.ast.CmpOp
import com.kcl.ast.ConfigEntryOperation
import com.kcl.ast.ExprContext
import com.kcl.ast.ImportStmt
import com.kcl.ast.Module
import com.kcl.ast.NumberBinarySuffix
import com.kcl.ast.NodeRef
import com.kcl.ast.Program
import com.kcl.ast.program
import com.kcl.ast.QuantOperation
import com.kcl.ast.anyType
import com.kcl.ast.argumentsOf
import com.kcl.ast.Identifier
import com.kcl.ast.assignStmt
import com.kcl.ast.basicIntType
import com.kcl.ast.basicType
import com.kcl.ast.callExpr
import com.kcl.ast.comment
import com.kcl.ast.compare
import com.kcl.ast.configEntry
import com.kcl.ast.emptyNodeRef
import com.kcl.ast.exprStmt
import com.kcl.ast.functionType
import com.kcl.ast.identifier
import com.kcl.ast.identifierExpr
import com.kcl.ast.importStmt
import com.kcl.ast.intNumberLit
import com.kcl.ast.keyword
import com.kcl.ast.listType
import com.kcl.ast.literalIntType
import com.kcl.ast.memberOrIndexOf
import com.kcl.ast.module
import com.kcl.ast.nodeRef
import com.kcl.ast.parseModule
import com.kcl.ast.parseProgram
import com.kcl.ast.schemaAttr
import com.kcl.ast.schemaStmt
import com.kcl.ast.schemaConfig
import com.kcl.ast.stringLit
import com.kcl.ast.subscript
import com.kcl.ast.target
import com.kcl.ast.targetExpr
import com.kcl.ast.toJson
import com.kcl.ast.toProgramJson
import com.kcl.ast.toWire
import com.kcl.ast.typeAliasStmt
import com.kcl.ast.unificationStmt
import com.kcl.ast.quantExpr
import com.kcl.ast.unaryExpr
import com.kcl.ast.UnaryOp
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.util.Optional
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class AstWireRoundTripTest {
    companion object {
        private val json: ObjectMapper = ObjectMapper()

        /**
         * The capture lives at the repository root, one directory above this
         * module. Searched for rather than counted out, so the test still finds
         * it when the runner's working directory is not `kotlin/`.
         */
        private val golden: Path by lazy { findGolden() }

        private fun findGolden(): Path {
            val relative = Paths.get("testdata", "ast", "alignment.json")
            var dir: Path? = Paths.get("").toAbsolutePath()
            while (dir != null) {
                val candidate = dir.resolve(relative)
                if (Files.exists(candidate)) return candidate
                dir = dir.parent
            }
            throw java.io.FileNotFoundException("no testdata/ast/alignment.json above ${Paths.get("").toAbsolutePath()}")
        }

        // Files.readString is a Java 11 API and the CI leg compiles against
        // JDK 8; readAllBytes + explicit charset is equivalent here.
        private fun goldenJson(): String = String(Files.readAllBytes(golden), Charsets.UTF_8)

        private fun parse(text: String): JsonNode = json.readTree(text)

        /** Jackson's `JsonNode.equals` is a deep comparison that ignores key order. */
        private fun assertJsonEqual(expected: JsonNode, actual: JsonNode) {
            assertTrue(
                expected == actual,
                "written document differs from the capture.\n--- expected ---\n$expected\n--- actual ---\n$actual",
            )
        }

        private fun <T> wrap(node: T, line: Long = 1L, column: Long = 1L, endColumn: Long = column) =
            nodeRef(node, GOLDEN_FILE, line, column, endColumn = endColumn)

        private const val GOLDEN_FILE = "testdata/ast/alignment.k"

        /** The first payload in the capture whose `type` is [type]. */
        private fun firstWithType(type: String): JsonNode? {
            fun walk(node: JsonNode): JsonNode? {
                if (node.isObject) {
                    if (node.has("type") && node["type"].asText() == type) return node
                    for (name in node.fieldNames()) walk(node[name])?.let { return it }
                } else if (node.isArray) {
                    for (child in node) walk(child)?.let { return it }
                }
                return null
            }
            return walk(parse(goldenJson()))
        }

        private fun firstGoldenWithType(type: String): JsonNode =
            firstWithType(type) ?: error("no $type in the capture")
    }

    // -----------------------------------------------------------------------
    // Decode, encode, decode: the document is a fixed point
    // -----------------------------------------------------------------------

    @Test
    fun `a decoded module written back is byte-identical`() {
        val module = parseModule(goldenJson())
        assertJsonEqual(parse(goldenJson()), parse(toJson(module)))
    }

    @Test
    fun `the fixed point holds a second time over`() {
        // A writer that is a fixed point once but not twice is still wrong: the
        // first pass can only agree with the capture by accident.
        val once = toJson(parseModule(goldenJson()))
        assertJsonEqual(parse(once), parse(toJson(parseModule(once))))
    }

    @Test
    fun `the written module carries no pkg key`() {
        // Rust's `Module` has no `pkg` field. Emitting one, or dropping the four
        // it does have, would both break a strict consumer.
        val written = parse(toJson(parseModule(goldenJson())))
        assertEquals(
            listOf("body", "comments", "doc", "filename"),
            written.fieldNames().asSequence().sorted().toList(),
        )
    }

    @Test
    fun `the program envelope round trips`() {
        // `SerializeProgram` is `{root, pkgs: {<pkg>: [Module, …]}}` — a
        // different envelope from a single `Module`, and the one `parseProgram`
        // reads.
        val modules = parseProgram(toProgramJson(listOf(module("a.k"), module("b.k"))))
        assertEquals(listOf("a.k", "b.k"), modules.map { it.filename })
    }

    @Test
    fun `a program built by hand is the document toProgramJson writes`() {
        // `toProgramJson` spells the envelope out as a literal map; `program()`
        // builds the DTO that `toWire` walks. They are two routes to one
        // document, so the constructor is only correct if the routes agree —
        // and `pkgs` defaulting to `emptyMap()` must not quietly drop the
        // modules that were put in.
        val built = program(
            Program.MAIN_PKG,
            mapOf(Program.MAIN_PKG to listOf(module("a.k"), module("b.k"))),
        )
        assertJsonEqual(parse(toProgramJson(listOf(module("a.k"), module("b.k")))), parse(toJson(built)))
        assertEquals(listOf("a.k", "b.k"), parseProgram(toJson(built)).map { it.filename })
    }

    // -----------------------------------------------------------------------
    // Built by hand, compared with the capture
    // -----------------------------------------------------------------------

    @Test
    fun `a call built by hand equals the captured call`() {
        // `Expr::Call(CallExpr)` is a newtype over a struct, so serde flattens
        // the struct's fields beside the tag. There is no `call` wrapper key to
        // descend through and none to emit — a writer that nests one produces a
        // document the parser would not recognise.
        //
        // The comparison is against the payload rather than a wrapper because
        // the call is the *value* of an assignment, so the capture has no
        // `Node` around it. The keyword's `arg` carries its own position and
        // `"ctx":"Load"` in the capture, so those are built here too: a
        // hand-built node that can reproduce the parser's bytes is the claim
        // being tested, and a `Keyword` assembled from a bare string would
        // differ in exactly the two fields a shape check does not look at.
        val call = callExpr(
            func = wrap(identifierExprAtPos("Person", 53, 4, 10), 53, 4, 10),
            args = listOf(wrap(intNumberLit(1L), 53, 11, 12)),
            keywords = listOf(
                wrap(
                    keyword(
                        arg = wrap(
                            identifierAtPos("name", 53, 14, 18, ctx = ExprContext.Load),
                            53, 14, 18,
                        ),
                        value = wrap(stringLit("Bob"), 53, 21, 26),
                    ),
                    53, 14, 26,
                ),
            ),
        )

        assertJsonEqual(parse(toJson(call)), firstGoldenWithType("Call"))
    }

    @Test
    fun `a type alias built by hand equals the captured alias`() {
        // `Type` is adjacently tagged and `Type::List` is not a unit variant,
        // so the payload lives under `value` — and the tag names the *shape*:
        // `Basic` with the variant as a bare string, not `Int`.
        val alias = typeAliasStmt(
            typeName = wrap(identifierAtPos("TList", 22, 5, 10, ctx = ExprContext.Load), 22, 5, 10),
            typeValue = wrap("[int]", 22, 13, 18),
            ty = wrap(listType(wrap(basicIntType(), 22, 14, 17)), 22, 13, 18),
        )

        assertJsonEqual(
            parse(toJson(wrap(alias, 22, 5, 18))),
            capturedTypeAlias("TList"),
        )
    }

    // -----------------------------------------------------------------------
    // The individual decisions a fixed point would not explain
    // -----------------------------------------------------------------------

    @Test
    fun `a comment is written under a node key as an object and not as a bare string`() {
        // Rust declares `Comment` as a plain struct with one `String` field, so
        // the object under `node` is `{"text": "…"}` and *not* the text. A
        // writer that emits the bare string produces a document no decoder can
        // read back — the bug that has shipped in four bindings, and once more
        // in Python.
        val written = parse(toJson(wrap(comment("# a comment"))))
        assertEquals(listOf("text"), written["node"].fieldNames().asSequence().sorted().toList())
        assertEquals("# a comment", written["node"]["text"].asText())
    }

    @Test
    fun `the captured comments survive with their text`() {
        // Both directions matter and neither shows up in a shape check: a
        // decoder that unwraps `node` again reads a key the payload does not
        // have, and one that reads the payload as the text gets an object where
        // it promised a string. Both yield "" for every comment in the file.
        val module = parseModule(goldenJson())
        assertNotNull(module.comments, "no comments decoded at all")
        assertTrue(module.comments.isNotEmpty(), "every comment was dropped")
        module.comments.forEach {
            assertTrue(it.node.text.startsWith("#"), "a comment lost its text: '${it.node.text}'")
        }
    }

    @Test
    fun `a tagged expr flattens its struct fields beside the tag`() {
        val written = parse(toJson(callExpr()))
        assertEquals(
            listOf("args", "func", "keywords", "type"),
            written.fieldNames().asSequence().sorted().toList(),
        )
        assertFalse(written.has("call"), "the struct was nested under a wrapper key")
    }

    @Test
    fun `a tagged stmt is not wrapped in a node`() {
        // `Stmt` variants are tagged statements: their fields sit on the
        // statement object itself, so there is no `node` key to descend into
        // and none to write.
        val written = parse(toJson(exprStmt()))
        assertEquals(listOf("exprs", "type"), written.fieldNames().asSequence().sorted().toList())
    }

    @Test
    fun `a basic type is adjacently tagged with a bare string payload`() {
        // The tag names the *shape*, so `BasicType::Int` is
        // `{"type":"Basic","value":"Int"}` and never `{"type":"Int"}`. A
        // registry keyed on the variant name matches nothing.
        val written = parse(toJson(basicIntType()))
        assertEquals("Basic", written["type"].asText())
        assertEquals("Int", written["value"].asText())
    }

    @Test
    fun `the any type is the bare tag with no value key`() {
        val written = parse(toJson(anyType()))
        assertEquals(listOf("type"), written.fieldNames().asSequence().sorted().toList())
    }

    @Test
    fun `a literal type nests a second tagged document`() {
        // `LiteralType` is `tag + content` too, so it is doubly nested:
        // `{"type":"Literal","value":{"type":"Int","value":{"value":1,"suffix":null}}}`.
        val inner = parse(toJson(literalIntType(1L)))
        assertEquals("Literal", inner["type"].asText())
        assertEquals("Int", inner["value"]["type"].asText())
        assertEquals(1L, inner["value"]["value"]["value"].asLong())
        assertTrue(inner["value"]["value"].has("suffix"), "the suffix key is written, as null")
        assertTrue(inner["value"]["value"]["suffix"].isNull)
    }

    @Test
    fun `a literal type with a suffix spells the variant of the suffix`() {
        val inner = parse(toJson(literalIntType(1L, NumberBinarySuffix.Ki)))
        assertEquals("Ki", inner["value"]["value"]["suffix"].asText())
    }

    @Test
    fun `a number literal is doubly tagged too`() {
        // `NumberLitValue` is `tag = "type", content = "value"`, so the number
        // is a document of its own and not a bare `1`.
        val written = parse(toJson(intNumberLit(1L)))
        assertEquals("NumberLit", written["type"].asText())
        assertTrue(written.has("binary_suffix"), "the Option key is written, as null")
        assertTrue(written["binary_suffix"].isNull)
        assertEquals("Int", written["value"]["type"].asText())
        assertEquals(1L, written["value"]["value"].asLong())
    }

    @Test
    fun `function params_ty is null or a list and never an empty one`() {
        // `Option<Vec<NodeRef<Type>>>` — the one list field on the wire that is
        // nullable. The parser only produces `None` or `Some(non-empty)`
        // (`crates/parser/src/parser/ty.rs` ~line 244), so there is no empty
        // case to invent.
        val noArgs = parse(toJson(functionType()))
        assertTrue(noArgs["value"]["params_ty"].isNull, "None is written as null, not []")

        val one = parse(toJson(functionType(Optional.of(listOf(nodeRef(basicIntType()))))))
        assertEquals(1, one["value"]["params_ty"].size())
        assertEquals("Basic", one["value"]["params_ty"][0]["node"]["type"].asText())
    }

    @Test
    fun `argument defaults keep their null slots`() {
        // `Vec<Option<NodeRef<Expr>>>`. `lambda x` is `"defaults":[null]`, and
        // reading that with a list decoder that skips nulls shortens the
        // parameter list — a silent one, because nothing about the result looks
        // wrong to a caller that never counted.
        val written = parse(toJson(wrap(argumentsOf("x", "y"))))
        assertEquals(2, written["node"]["args"].size())
        assertEquals(2, written["node"]["defaults"].size())
        assertTrue(written["node"]["defaults"][0].isNull)
        assertTrue(written["node"]["defaults"][1].isNull)
        assertEquals(2, written["node"]["ty_list"].size())
    }

    @Test
    fun `a lambda parameter name is the untagged identifier struct`() {
        // `Arguments.args` is `Vec<NodeRef<Identifier>>`, not
        // `Vec<NodeRef<Expr>>`: the same name reached as an *expression* carries
        // `"type":"Identifier"` and the parameter does not.
        val written = parse(toJson(wrap(argumentsOf("p"))))
        val arg = written["node"]["args"][0]
        assertFalse(arg["node"].has("type"), "a parameter name picked up a tag it does not have")
        assertEquals("p", arg["node"]["names"][0]["node"].asText())
    }

    @Test
    fun `a config entry drops is_shorthand when it is false`() {
        // `#[serde(skip_serializing_if = "is_false")]`. Writing
        // `"is_shorthand": false` puts a key Rust never writes next to the three
        // it does.
        val plain = parse(toJson(configEntry(operation = ConfigEntryOperation.Override)))
        assertEquals(
            listOf("key", "operation", "value"),
            plain.fieldNames().asSequence().sorted().toList(),
        )

        val shorthand = parse(toJson(configEntry(operation = ConfigEntryOperation.Override, isShorthand = true)))
        assertTrue(shorthand["is_shorthand"].asBoolean())
    }

    @Test
    fun `a unification value is untagged`() {
        // `UnificationStmt.value` is a `NodeRef<SchemaConfig>` reached through a
        // struct-typed field, so the payload carries no `type` key — the one
        // place a `SchemaExpr` appears without one, even though the tagged
        // `Expr::Schema` writes `"type":"Schema"`.
        val written = parse(
            toJson(
                unificationStmt(
                    target = wrap(identifier("u"), 2, 0, 1),
                    value = wrap(schemaConfig(name = wrap(identifier("Person")))),
                ),
            ),
        )
        val value = written["value"]["node"]
        assertEquals(
            listOf("args", "config", "kwargs", "name"),
            value.fieldNames().asSequence().sorted().toList(),
        )
        assertFalse(value.has("type"), "the payload picked up a tag it does not have")
    }

    @Test
    fun `a schema attr doc is a string and a schema stmt doc is optional`() {
        // `SchemaAttr::doc` is a `String` and is written as `""`; `SchemaStmt::doc`
        // is an `Option<NodeRef<String>>` and is written as `null`. Two
        // adjacent fields, opposite treatment, and a `@JsonInclude(NON_NULL)`
        // round trip gets both wrong.
        val attr = parse(toJson(schemaAttr()))
        assertTrue(attr.has("doc"))
        assertEquals("", attr["doc"].asText())

        val schema = parse(toJson(schemaStmt()))
        assertTrue(schema.has("doc"))
        assertTrue(schema["doc"].isNull)
    }

    @Test
    fun `a subscript keeps its slice bounds`() {
        val plain = parse(toJson(subscript()))
        assertEquals(
            listOf("ctx", "has_question", "index", "lower", "step", "type", "upper", "value"),
            plain.fieldNames().asSequence().sorted().toList(),
        )
        assertTrue(plain["lower"].isNull, "a plain a[0] has no lower bound")
        assertTrue(plain["upper"].isNull)
        assertTrue(plain["step"].isNull)

        val slice = parse(
            toJson(
                subscript(
                    lower = wrap(intNumberLit(1L)),
                    upper = wrap(intNumberLit(9L)),
                    step = wrap(intNumberLit(2L)),
                ),
            ),
        )
        assertEquals(1L, slice["lower"]["node"]["value"]["value"].asLong())
        assertEquals(9L, slice["upper"]["node"]["value"]["value"].asLong())
        assertEquals(2L, slice["step"]["node"]["value"]["value"].asLong())
    }

    @Test
    fun `a present wrapper with no value is distinct from an absent one`() {
        // `Node<T>.node` is not an `Option`, so serde writes `"node": null` and
        // keeps the key; the `Option` is on the wrapper, so an absent wrapper is
        // the field itself being `null`. Dropping the key instead merges the two
        // cases and loses a node that a round trip has to preserve.
        val absent = parse(toJson(null))
        assertTrue(absent.isNull, "an absent wrapper is written as null")

        val present = parse(toJson(emptyNodeRef<Identifier>()))
        assertTrue(present.has("node"), "the node key is emitted even when the value is null")
        assertTrue(present["node"].isNull)
    }

    @Test
    fun `node positions are flattened onto the wrapper and not nested under a pos key`() {
        val written = parse(toJson(nodeRef(intNumberLit(1L), "a.k", 3, 2, endColumn = 5)))
        assertFalse(written.has("pos"), "the position was nested")
        assertEquals("a.k", written["filename"].asText())
        assertEquals(3L, written["line"].asLong())
        assertEquals(2L, written["column"].asLong())
        assertEquals(3L, written["end_line"].asLong())
        assertEquals(5L, written["end_column"].asLong())
    }

    @Test
    fun `node ids are never written`() {
        // Rust only serialises `Node::id` under `SHOULD_SERIALIZE_ID`, which is
        // off, so `id` never appears in `ast_json`. The Java `Node` class has
        // the field for the facade, so a writer that dumps the object rather
        // than the contract puts it on the wire.
        val written = parse(toJson(nodeRef(intNumberLit(1L), "a.k", 1, 1, endColumn = 2)))
        assertFalse(written.has("id"))
    }

    @Test
    fun `member or index is a tag beside a content key`() {
        val member = parse(toJson(memberOrIndexOf("b")))
        assertEquals("Member", member["type"].asText())
        assertEquals("b", member["value"]["node"].asText())
    }

    @Test
    fun `a comma list is written as a list of ops`() {
        // A `CmpOp` is a fieldless enum, not a node: a bare array of strings,
        // with no `node` key and no position around each entry.
        val written = parse(toJson(compare(ops = listOf(CmpOp.Gt))))
        assertEquals(1, written["ops"].size())
        assertEquals("Gt", written["ops"][0].asText())
        assertFalse(written["ops"][0].isObject, "an op is a scalar, not a wrapped node")
    }

    @Test
    fun `an empty vec is written as an array and not as null`() {
        // A Rust `Vec` is never absent, so a `Vec` field with nothing in it is
        // `[]`. The classes cannot tell "empty" from "unset" — both are null in
        // Java — and null is right for the `Option` fields and wrong for these.
        val written = parse(toJson(callExpr()))
        assertTrue(written["args"].isArray)
        assertEquals(0, written["args"].size())
        assertTrue(written["keywords"].isArray)

        val module = parse(toJson(module("a.k")))
        assertTrue(module["body"].isArray, "an empty body is [], not null")
        assertTrue(module["comments"].isArray)
    }

    @Test
    fun `an import spells asname without a separator`() {
        val written = parse(toJson(importStmt(rawpath = "data.cloud", name = "cloud", pkgName = "__main__")))
        assertEquals(
            listOf("asname", "name", "path", "pkg_name", "rawpath", "type"),
            written.fieldNames().asSequence().sorted().toList(),
        )
        assertTrue(written["asname"].isNull, "an absent alias is null, not an empty string")
    }

    @Test
    fun `a schema attr decorator is untagged even though its payload is a call`() {
        // `SchemaAttr.decorators` is `Vec<NodeRef<CallExpr>>` reached through a
        // field, not through the `Expr` enum, so the struct arrives with no
        // `"type":"Call"` beside it. The same class in an expression position
        // does carry the tag.
        val tagged = parse(toJson(callExpr()))
        assertEquals("Call", tagged["type"].asText())

        val untagged = firstSchemaAttrDecorator()["node"]
        assertFalse(untagged.has("type"), "a decorator picked up a tag it does not have")
        assertTrue(untagged.has("func"))
    }

    @Test
    fun `a target is the untagged struct and a target expression is tagged`() {
        val untagged = parse(toJson(target("a")))
        assertEquals(
            listOf("name", "paths", "pkgpath"),
            untagged.fieldNames().asSequence().sorted().toList(),
        )

        val tagged = parse(toJson(targetExpr("a")))
        assertEquals("Target", tagged["type"].asText())
    }

    @Test
    fun `an operator is written as the rust variant name`() {
        val unary = parse(toJson(unaryExpr(UnaryOp.USub)))
        assertEquals("USub", unary["op"].asText())

        val quant = parse(toJson(quantExpr(op = QuantOperation.All)))
        assertEquals("All", quant["op"].asText())
    }

    @Test
    fun `an expression context is the variant name and may be null`() {
        assertEquals("Load", parse(toJson(identifierExpr("a")))["ctx"].asText())
        assertEquals("Store", parse(toJson(identifier("a", ctx = ExprContext.Store)))["ctx"].asText())
        assertTrue(parse(toJson(identifier("a")))["ctx"].isNull, "an unset ctx is written as null")
    }

    @Test
    fun `a basic type factory round trips through the writer`() {
        for (name in listOf("Int", "Str", "Bool", "Float")) {
            val written = parse(toJson(basicType(BasicType.BasicTypeEnum.valueOf(name))))
            assertEquals("Basic", written["type"].asText())
            assertEquals(name, written["value"].asText())
        }
    }

    @Test
    fun `an assigned statement carries its targets value and type`() {
        val written = parse(
            toJson(
                assignStmt(
                    targets = listOf(wrap(target("x"))),
                    value = wrap(intNumberLit(1L)),
                ),
            ),
        )
        assertEquals("Assign", written["type"].asText())
        assertEquals("x", written["targets"][0]["node"]["name"]["node"].asText())
        assertTrue(written["ty"].isNull, "an absent type annotation is null")
    }

    @Test
    fun `toJson and toWire compose`() {
        // `toWire` already converts, so composing the two entry points must not
        // run the conversion twice — a second pass finds no AST node and writes
        // `null`.
        val call = callExpr()
        assertJsonEqual(parse(toJson(call)), parse(toJson(toWire(call))))
    }

    // -----------------------------------------------------------------------
    // helpers that need the capture
    // -----------------------------------------------------------------------

    /**
     * An `Identifier` whose single name segment carries a position. The capture
     * gives every name segment a `NodeRef` of its own, so a name built from a
     * bare string differs in five keys that no shape check looks at.
     */
    private fun identifierAtPos(name: String, line: Long, column: Long, endColumn: Long, ctx: ExprContext? = null) =
        identifier(name, ctx = ctx).also { it.setNames(listOf(wrap(name, line, column, endColumn))) }

    /** The tagged spelling of the same thing, for an expression position. */
    private fun identifierExprAtPos(name: String, line: Long, column: Long, endColumn: Long) =
        identifierExpr(name).also { it.setNames(listOf(wrap(name, line, column, endColumn))) }

    /** The `TypeAlias` statement in the capture that declares [aliasName]. */
    private fun capturedTypeAlias(aliasName: String): JsonNode =
        parse(goldenJson())["body"].firstOrNull {
            it["node"]?.get("type")?.asText() == "TypeAlias" &&
                it["node"]["type_name"]["node"]["names"][0]["node"].asText() == aliasName
        } ?: error("no $aliasName type alias in the capture")

    /**
     * The first decorator in the capture, found by walking for a `SchemaAttr`
     * that actually has one. Most attributes in the file are undecorated, so
     * taking the first `SchemaAttr` found would read `decorators[0]` off an
     * empty array and say nothing about decorator shape.
     */
    private fun firstSchemaAttrDecorator(): JsonNode {
        fun walk(node: JsonNode): JsonNode? {
            if (node.isObject) {
                if (node.has("type") && node["type"].asText() == "SchemaAttr" &&
                    node["decorators"]?.isEmpty == false
                ) {
                    return node["decorators"][0]
                }
                for (name in node.fieldNames()) walk(node[name])?.let { return it }
            } else if (node.isArray) {
                for (child in node) walk(child)?.let { return it }
            }
            return null
        }
        return walk(parse(goldenJson())) ?: error("no decorated SchemaAttr in the capture")
    }
}

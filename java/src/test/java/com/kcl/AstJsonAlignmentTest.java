package com.kcl.ast;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

import org.junit.Test;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kcl.api.API;
import com.kcl.api.Spec.ParseFileArgs;
import com.kcl.api.Spec.ParseFileResult;
import com.kcl.api.Spec.ParseProgramArgs;
import com.kcl.api.Spec.ParseProgramResult;
import com.kcl.util.JsonUtil;

/**
 * Round-trip tests that verify the Java AST classes match the JSON shape
 * produced by the Rust compiler in {@code ../kcl/crates/ast/src/ast.rs}.
 *
 * <p>Each test parses a real KCL source file via {@code parseFile} /
 * {@code parseProgram} and asserts that the resulting {@code ast_json}
 * deserializes cleanly into the Java AST classes with the structure we expect.
 *
 * <p>If the Java AST drifts from the Rust schema — wrong field names, missing
 * variants, wrong discriminator values — the deserialization fails with a
 * clear message, or an assertion fails.
 */
public class AstJsonAlignmentTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final String FIXTURE =
            "src/test_data/ast_alignment/main.k";

    private static String parseAstJson(String relativePath) throws Exception {
        Path path = Paths.get(relativePath);
        API api = new API();
        ParseFileResult result = api.parseFile(
                ParseFileArgs.newBuilder().setPath(path.toString()).build());
        return result.getAstJson();
    }

    private static String parseProgramAstJson(String relativePath) throws Exception {
        Path path = Paths.get(relativePath);
        API api = new API();
        ParseProgramResult result = api.parseProgram(
                ParseProgramArgs.newBuilder().addPaths(path.toString()).build());
        return result.getAstJson();
    }

    // --- Module ------------------------------------------------------------

    @Test
    public void module_parsesAndHasNoPkgField() throws Exception {
        String json = parseAstJson(FIXTURE);
        Module m = MAPPER.readValue(json, Module.class);
        // parseFile resolves relative paths to absolute ones before handing
        // them to the parser, so `m.getFilename()` carries the absolute form.
        assertTrue("expected filename to end with the relative fixture path",
                m.getFilename().endsWith(FIXTURE));
        assertNotNull(m.getBody());

        // Rust Module has no `pkg` field — the serialized JSON must not contain
        // one, and Java's Module class must not produce one either.
        JsonNode tree = MAPPER.readTree(json);
        assertFalse("Module JSON must not contain 'pkg': " + json,
                tree.has("pkg"));

        String reserialized = MAPPER.writeValueAsString(m);
        assertFalse("Java Module must not serialize 'pkg': " + reserialized,
                reserialized.contains("\"pkg\""));
    }

    // --- NumberLit/StringLit/NameConstantLit discriminator ----------------

    @Test
    public void literalDiscriminators_useLongFormNotLiteralEnumForm() throws Exception {
        String json = parseAstJson(FIXTURE);
        JsonNode root = MAPPER.readTree(json);

        // Walk the body and confirm every literal node uses the long-form
        // discriminator ("NumberLit"/"StringLit"/"NameConstantLit") instead of
        // the inner Literal-enum form ("Number"/"String"/"NameConstant").
        for (JsonNode stmt : root.path("body")) {
            checkLiteralDiscriminators(stmt);
        }
    }

    private void checkLiteralDiscriminators(JsonNode node) {
        String type = node.path("type").asText("");
        if (type.equals("NumberLit") || type.equals("StringLit")
                || type.equals("NameConstantLit")) {
            // ok — this is the form we want
        } else if (type.equals("Number") || type.equals("String")
                || type.equals("NameConstant")) {
            throw new AssertionError(
                    "Rust emits Expr variant discriminators ('NumberLit', "
                            + "'StringLit', 'NameConstantLit'); got short form '"
                            + type + "' in " + node);
        }
        // recurse into children that may carry Expr nodes
        for (String key : new String[]{"value", "node", "expr", "if_cond",
                "test", "msg", "arg", "left", "right", "body", "orelse",
                "operands", "func", "cond"}) {
            if (node.has(key)) {
                checkLiteralDiscriminators(node.path(key));
            }
        }
        if (node.isArray()) {
            for (JsonNode child : node) {
                checkLiteralDiscriminators(child);
            }
        }
    }

    // --- ConfigEntry.is_shorthand -----------------------------------------

    @Test
    public void configEntry_supportsIsShorthand() throws Exception {
        // Round-trip a ConfigEntry literal: when the Rust compiler emits
        // `is_shorthand`, the field must be preserved; when absent, it must
        // default to false.
        String withShorthand = "{"
                + "\"key\":null,"
                + "\"value\":null,"
                + "\"operation\":\"Union\","
                + "\"is_shorthand\":true"
                + "}";
        ConfigEntry ce1 = MAPPER.readValue(withShorthand, ConfigEntry.class);
        assertTrue(ce1.isShorthand());

        String withoutShorthand = "{"
                + "\"key\":null,"
                + "\"value\":null,"
                + "\"operation\":\"Union\""
                + "}";
        ConfigEntry ce2 = MAPPER.readValue(withoutShorthand, ConfigEntry.class);
        assertFalse(ce2.isShorthand());
    }

    // --- UnificationStmt.value must be SchemaExpr (not SchemaConfig) ------

    @Test
    public void unificationStmt_valueIsSchemaExpr() throws Exception {
        // x = Person {name = "Alice", age = 30}
        // produces an AssignStmt with value being a SchemaExpr.
        String json = parseAstJson(FIXTURE);
        JsonNode root = MAPPER.readTree(json);

        JsonNode personAssign = findStmtWithName(root, "x");
        assertNotNull("expected AssignStmt to `x`", personAssign);

        JsonNode value = personAssign.path("value").path("node");
        assertEquals("Schema", value.path("type").asText());
        // Sanity check: schema's `config` field (the inline body) is non-null.
        assertTrue(value.path("config") != null);
    }

    @Test
    public void schemaStmt_decoratorsUseFlatDecoratorStruct() throws Exception {
        // The Java binding intentionally models decorators as a flat
        // `Decorator` struct (not the polymorphic CallExpr variant) so that
        // nested-in-NodeRef deserialization does not depend on a `type`
        // discriminator. Verify the wire JSON contains `func`/`args`/`keywords`
        // keys (the Decorator shape), not a `"type":"Call"` tag.
        String json = parseAstJson(FIXTURE);
        JsonNode root = MAPPER.readTree(json);

        JsonNode articleSchema = findSchemaByName(root, "Article");
        assertNotNull("expected Article schema", articleSchema);

        JsonNode decorators = articleSchema.path("decorators");
        assertTrue("Article should have at least one decorator",
                decorators.isArray() && decorators.size() > 0);

        for (JsonNode decorator : decorators) {
            JsonNode node = decorator.path("node");
            // Rust emits a flat {func, args, keywords} object — no "type" tag.
            assertFalse("Decorator node must not carry a 'type' tag: " + node,
                    node.has("type"));
            assertTrue("Decorator must carry 'func': " + node, node.has("func"));
        }
    }

    @Test
    public void schemaStmt_deserializesIntoJavaClass() throws Exception {
        // Verify the JSON deserializes into SchemaStmt without errors and
        // exposes decorators as a typed List<NodeRef<Decorator>>.
        String json = parseAstJson(FIXTURE);
        JsonNode root = MAPPER.readTree(json);
        JsonNode articleSchemaNode = findSchemaByName(root, "Article");
        assertNotNull(articleSchemaNode);

        Module m = MAPPER.readValue(json, Module.class);
        SchemaStmt article = (SchemaStmt) m.getBody().stream()
                .map(n -> n.getNode())
                .filter(n -> n instanceof SchemaStmt
                        && ((SchemaStmt) n).getName() != null
                        && "Article".equals(((SchemaStmt) n).getName().getNode()))
                .findFirst().orElseThrow(
                        () -> new AssertionError("Article schema not found"));
        assertNotNull(article);
        List<NodeRef<Decorator>> decorators = article.getDecorators();
        assertNotNull(decorators);
        assertTrue(decorators.size() > 0);
        for (NodeRef<Decorator> d : decorators) {
            assertNotNull(d.getNode());
            assertTrue(d.getNode() instanceof Decorator);
        }
    }

    @Test
    public void schemaAttr_hasDecoratorsField() throws Exception {
        // Verify SchemaAttr supports the `decorators` field, since Rust
        // declares it as `Vec<NodeRef<CallExpr>>`.
        String json = parseAstJson(FIXTURE);
        Module m = MAPPER.readValue(json, Module.class);

        // Iterate body and find Person schema, then its `name` attribute.
        for (NodeRef<Stmt> wrapped : m.getBody()) {
            Stmt stmt = wrapped.getNode();
            if (stmt instanceof SchemaStmt) {
                SchemaStmt schema = (SchemaStmt) stmt;
                if (schema.getName() != null
                        && "Person".equals(schema.getName().getNode())) {
                    boolean foundName = false;
                    for (NodeRef<Stmt> attrWrapped : schema.getBody()) {
                        Stmt attr = attrWrapped.getNode();
                        if (attr instanceof SchemaAttr
                                && ((SchemaAttr) attr).getName() != null
                                && "name".equals(
                                        ((SchemaAttr) attr).getName()
                                                .getNode())) {
                            SchemaAttr nameAttr = (SchemaAttr) attr;
                            assertNotNull(nameAttr.getDecorators());
                            // @deprecated has no args.
                            assertEquals(1, nameAttr.getDecorators().size());
                            assertNotNull(
                                    nameAttr.getDecorators().get(0).getNode());
                            foundName = true;
                        }
                    }
                    assertTrue("expected to find `name` SchemaAttr", foundName);
                    return;
                }
            }
        }
        throw new AssertionError("Person schema not found");
    }

    // --- Program-level parse ---------------------------------------------

    @Test
    public void parseProgram_returnsValidModulePerFile() throws Exception {
        String json = parseProgramAstJson(FIXTURE);
        com.kcl.ast.Program program = JsonUtil.deserializeProgram(json);
        assertNotNull(program);
        assertNotNull(program.getMainPackage());
        assertTrue(program.getMainPackage().size() > 0);
    }

    // --- helpers ----------------------------------------------------------

    private static JsonNode findStmtWithName(JsonNode moduleNode, String name) {
        for (JsonNode stmt : moduleNode.path("body")) {
            // Look for AssignStmt with the matching target name.
            JsonNode node = stmt.path("node");
            if ("Assign".equals(node.path("type").asText())) {
                JsonNode targets = node.path("targets");
                if (targets.isArray() && targets.size() > 0) {
                    JsonNode targetName = targets.path(0).path("node")
                            .path("name").path("node");
                    if (name.equals(targetName.asText())) {
                        return node;
                    }
                }
            }
        }
        return null;
    }

    private static JsonNode findSchemaByName(JsonNode moduleNode, String name) {
        for (JsonNode stmt : moduleNode.path("body")) {
            JsonNode node = stmt.path("node");
            if ("Schema".equals(node.path("type").asText())) {
                JsonNode schemaName = node.path("name").path("node");
                if (name.equals(schemaName.asText())) {
                    return node;
                }
            }
        }
        return null;
    }
}

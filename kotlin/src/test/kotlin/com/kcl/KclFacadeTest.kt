package com.kcl

import com.kcl.api.Spec.ExecProgramArgs
import com.kcl.api.Spec.ExecProgramResult
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Tests for the high-level [Kcl] facade: inline code runs, file runs,
 * error propagation, kcl.yaml settings parsing, option merging and
 * [KCLResult] accessors.
 */
class KclFacadeTest {

    companion object {
        private const val FACADE_DIR = "./src/test_data/facade"
    }

    @Test
    fun testRunInlineCode() {
        val result = Kcl.run("a = 1\nb = {c = \"x\"}")
        assertEquals(1, result.size)
        val first = result.first()!!
        assertEquals(1, first.getInt("a"))
        assertEquals("x", first.getString("b.c"))
        assertEquals("x", (first.get("b") as Map<*, *>)["c"])
        assertEquals(2, first.toMap().size)
        assertTrue(result.rawYamlResult.contains("a: 1"))
        assertTrue(result.rawJsonResult.contains("\"a\": 1"))
    }

    @Test
    fun testRunInlineCodeWithOverrides() {
        val result = Kcl.run("a = 1", Kcl.withOverrides("a=2"))
        assertEquals(2, result.first()!!.getInt("a"))
    }

    @Test
    fun testRunInlineCodeWithSelectors() {
        val result = Kcl.run("a = 1\nb = {c = 2}", Kcl.withSelectors("b"))
        assertNull(result.first()!!.get("a"))
        assertEquals(2, result.first()!!.getInt("c"))
        assertNull(result.first()!!.get("missing.key"))
    }

    @Test
    fun testRunMultiDocumentYaml() {
        val result = Kcl.run("import manifests\nmanifests.yaml_stream([{x = 1}, {y = 2}])")
        assertEquals(2, result.size)
        assertEquals(1, result[0].getInt("x"))
        assertEquals(2, result[1].getInt("y"))
        assertEquals(2, result.tail()!!.getInt("y"))
        assertTrue(result.rawYamlResult.contains("---"))
        assertTrue(result[0].yamlString().contains("x: 1"))
    }

    @Test
    fun testRunFiles() {
        val result = Kcl.runFiles("./src/test_data/schema.k")
        assertEquals(2, result.first()!!.getInt("app.replicas"))

        val listed = Kcl.runFiles(listOf("./src/test_data/schema.k"))
        assertEquals(2, listed.first()!!.getInt("app.replicas"))
    }

    @Test
    fun testRunFilesWithExternalPkgs() {
        val result = Kcl.runFiles(
            "./src/test_data/schema.k",
            Kcl.withExternalPkgs(mapOf("pkg" to "./src/test_data/pkg"))
        )
        assertEquals(2, result.first()!!.getInt("app.replicas"))
    }

    @Test
    fun testDslConfigurationLambda() {
        val result = Kcl.run("a = 1") {
            overrides += "a=2"
        }
        assertEquals(2, result.first()!!.getInt("a"))
    }

    @Test
    fun testRunThrowsOnEvalError() {
        val err = assertThrows(KclException::class.java) {
            Kcl.run("a = = 1")
        }
        assertFalse(err.message.isNullOrEmpty())
    }

    @Test
    fun testRunThrowsWhenNoInputOrBadSettings() {
        assertThrows(KclException::class.java) { Kcl.runWithOpts() }
        assertThrows(KclException::class.java) {
            Kcl.run("a = 1", Kcl.withSettings("no/such/kcl.yaml"))
        }
    }

    @Test
    fun testSettingsRun() {
        val result = Kcl.runWithOpts(
            Kcl.withSettings("$FACADE_DIR/kcl.yaml"),
            Kcl.withWorkDir(FACADE_DIR)
        )
        // path_selector selects INTO the path, yielding the app subtree
        val doc = result.toMap()
        assertEquals(2, doc.size)
        assertTrue(doc.containsKey("replicas"))
        // overrides are applied
        assertEquals(4, result.first()!!.getInt("replicas"))
        // kcl_options become option() arguments
        assertEquals("prod", result.first()!!.getString("name"))
        // sort_keys is observable in the raw YAML key order
        assertTrue(result.rawYamlResult.indexOf("name:") < result.rawYamlResult.indexOf("replicas:"))
    }

    @Test
    fun testSettingsDisableNoneAndOverlay() {
        // settings file sets disable_none: true, so `nothing` is omitted
        val disabled = Kcl.runWithOpts(
            Kcl.withSettings("$FACADE_DIR/kcl_none.yaml"),
            Kcl.withWorkDir(FACADE_DIR)
        )
        assertNull(disabled.first()!!.get("nothing"))
        assertEquals("dev", disabled.first()!!.getString("app.name"))

        // kcl-go merge semantics: withDisableNone(false) does not turn the
        // flag back off, `nothing` stays omitted
        val overlay = Kcl.runWithOpts(
            Kcl.withSettings("$FACADE_DIR/kcl_none.yaml"),
            Kcl.withWorkDir(FACADE_DIR),
            Kcl.withDisableNone(false)
        )
        assertNull(overlay.first()!!.get("nothing"))

        // without a settings file the explicit true takes effect
        val plain = Kcl.run("nothing = None\nother = 1", Kcl.withDisableNone(true))
        assertNull(plain.first()!!.get("nothing"))
        assertEquals(1, plain.first()!!.getInt("other"))
        // and by default None values are kept
        val withNone = Kcl.run("nothing = None\nother = 1")
        assertTrue(withNone.first()!!.toMap().containsKey("nothing"))
    }

    @Test
    fun testSettingsParsingDetails() {
        val args = loadSettings("$FACADE_DIR/kcl.yaml", FACADE_DIR)
        // relative file entries resolve against the work dir
        assertEquals(listOf("src/test_data/facade/main.k"), args.kFilenameListList)
        assertTrue(args.disableNone)
        assertTrue(args.sortKeys)
        assertTrue(args.strictRangeCheck)
        assertTrue(args.showHidden)
        assertEquals(2, args.verbose)
        assertEquals(1, args.debug)
        assertEquals(listOf("app"), args.pathSelectorList)
        assertEquals(listOf("app.replicas=4"), args.overridesList)
        // kcl_options: scalars become plain strings
        assertEquals("prod", args.getArgs(0).value)
        // kcl_options: map values become JSON with document order preserved
        assertEquals("{\"b\":2,\"a\":1}", args.getArgs(1).value)

        // singular `file:` is honoured too
        val singular = loadSettings("$FACADE_DIR/kcl_file.yaml", FACADE_DIR)
        assertEquals(listOf("src/test_data/facade/main.k"), singular.kFilenameListList)
    }

    private fun loadSettings(path: String, workDir: String): ExecProgramArgs {
        val builder = ExecProgramArgs.newBuilder()
        KclSettingsFile.load(path).applyTo(builder, workDir)
        return builder.build()
    }

    @Test
    fun testShowHiddenOption() {
        val code = "_hidden = 1\nvisible = 2"
        assertNull(Kcl.run(code).first()!!.get("_hidden"))
        assertEquals(1, Kcl.run(code, Kcl.withShowHidden(true)).first()!!.getInt("_hidden"))
    }

    @Test
    fun testArgsOption() {
        val result = Kcl.run("name = option(\"env\")", Kcl.withArgs(mapOf("env" to "staging")))
        assertEquals("staging", result.first()!!.getString("name"))
    }

    @Test
    fun testKclResultTypedAccessors() {
        val result = Kcl.run("s = \"1\"\ni = 2\nf = 1.5\nt = True\nl = [1, 2]").first()!!
        assertEquals("1", result.getString("s"))
        assertEquals(2, result.getInt("i"))
        assertEquals(1.5, result.getDouble("f"))
        assertEquals(true, result.getBoolean("t"))
        assertEquals(2, result.getInt("l.1"))
        assertNull(result.getInt("missing"))
        assertThrows(KclException::class.java) { result.getInt("s") }
        assertThrows(KclException::class.java) { result.toList() }
    }

    @Test
    fun testExecResultToKCLResult() {
        // one JSON stream value per YAML document
        val multi = ExecProgramResult.newBuilder()
            .setJsonResult("{\"x\": 1}\n{\"y\": 2}")
            .setYamlResult("x: 1\n---\n'y': 2")
            .build()
        val parsed = Kcl.execResultToKCLResult(multi)
        assertEquals(2, parsed.size)
        assertEquals(1, parsed[0].getInt("x"))
        assertEquals(2, parsed[1].getInt("y"))
        assertEquals("x: 1", parsed[0].yamlString().trim())

        // a stream holding a single whole-document list
        val listDoc = ExecProgramResult.newBuilder()
            .setJsonResult("[[1, 2]]")
            .setYamlResult("- 1\n- 2")
            .build()
        assertEquals(listOf(1, 2), Kcl.execResultToKCLResult(listDoc).first()!!.toList())

        // err_message becomes an exception (kcl-go ExecResultToKCLResult)
        val failed = ExecProgramResult.newBuilder().setErrMessage("boom").build()
        val err = assertThrows(KclException::class.java) { Kcl.execResultToKCLResult(failed) }
        assertEquals("boom", err.message)

        // a blank JSON mirror yields an empty result list (kcl-go semantics)
        val noJson = ExecProgramResult.newBuilder().setYamlResult("a: 1").build()
        assertTrue(Kcl.execResultToKCLResult(noJson).isEmpty())
    }

    @Test
    fun testOptionMergeOrderAppends() {
        val result = Kcl.run("a = \"seed\"", Kcl.withCode("b = \"extra\""))
        assertEquals("seed", result.first()!!.getString("a"))
        assertEquals("extra", result.first()!!.getString("b"))
        assertNotNull(result.first())
    }
}

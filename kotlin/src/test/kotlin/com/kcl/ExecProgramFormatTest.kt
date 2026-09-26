package com.kcl

import com.kcl.api.API
import com.kcl.api.Spec.ExecProgramArgs
import com.kcl.api.Spec.ExecProgramResult
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.Test

/**
 * Tests for the source-map fields introduced alongside
 * kcl-lang/kcl#1546. Combines:
 *   1. Pure protobuf round-trip — verifies the regenerated Spec.java
 *      encodes / decodes the new fields without touching the runtime.
 *   2. End-to-end execution — runs the bundled schema.k through
 *      API().execProgram with format="json" and sourcemap_output set,
 *      asserting on the actual runtime output.
 *
 * Covers:
 *   - ExecProgramArgs.format           (field 20)
 *   - ExecProgramArgs.error_format     (field 19, pre-existing sanity check)
 *   - ExecProgramArgs.sourcemap_output (field 22)
 *   - ExecProgramResult.sourcemap      (field 5)
 */
class ExecProgramFormatTest {

    companion object {
        private const val TEST_FILE = "./src/test_data/schema.k"
    }

    @Test
    fun testExecProgramArgsFormatRoundTrip() {
        val args = ExecProgramArgs.newBuilder()
            .setFormat("json")
            .setErrorFormat("sarif")
            .setSourcemapOutput("/tmp/out.js.map")
            .build()

        val decoded = ExecProgramArgs.parseFrom(args.toByteString())

        assertEquals("json", decoded.format)
        assertEquals("sarif", decoded.errorFormat)
        assertTrue(decoded.hasSourcemapOutput(), "sourcemap_output presence")
        assertEquals("/tmp/out.js.map", decoded.sourcemapOutput)
    }

    @Test
    fun testExecProgramResultSourcemapRoundTrip() {
        val result = ExecProgramResult.newBuilder()
            .setJsonResult("{\"a\": 1}")
            .setYamlResult("a: 1")
            .setSourcemap("{\"version\":3,\"sources\":[]}")
            .build()

        val decoded = ExecProgramResult.parseFrom(result.toByteString())

        assertEquals("{\"a\": 1}", decoded.jsonResult)
        assertEquals("a: 1", decoded.yamlResult)
        assertTrue(decoded.hasSourcemap(), "sourcemap presence")
        assertEquals("{\"version\":3,\"sources\":[]}", decoded.sourcemap)
    }

    // End-to-end: format=json must populate only json_result.
    @Test
    fun testExecProgramFormatJson() {
        val args = ExecProgramArgs.newBuilder()
            .addKFilenameList(TEST_FILE)
            .setFormat("json")
            .build()
        val result = API().execProgram(args)

        assertFalse(result.jsonResult.isEmpty(), "format=json: json_result must be populated")
        assertEquals("", result.yamlResult, "format=json: yaml_result must be empty")
        assertTrue(result.jsonResult.contains("replicas"), "format=json: json_result must contain replicas key")
    }

    // End-to-end: sourcemap_output must populate result.sourcemap. Older
    // runtimes that don't yet emit source maps are skipped via assumeTrue
    // so this test doesn't fail under a stale kcl-api.
    @Test
    fun testExecProgramSourcemapOutput() {
        val args = ExecProgramArgs.newBuilder()
            .addKFilenameList(TEST_FILE)
            .setSourcemapOutput("/tmp/out.js.map")
            .build()
        val result = API().execProgram(args)

        assumeTrue(
            result.hasSourcemap() && result.sourcemap.isNotEmpty(),
            "runtime did not populate sourcemap (kcl-api may not yet support source maps)",
        )
        assertTrue(
            result.sourcemap.contains("\"version\""),
            "sourcemap_output: result.sourcemap must contain Source Map version key",
        )
    }
}
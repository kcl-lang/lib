package com.kcl

import com.kcl.api.Spec
import com.kcl.api.coverageSummary
import com.kcl.api.execProgramArgs
import com.kcl.api.fileCoverage
import com.kcl.api.testArgs
import com.kcl.api.testCaseInfo
import com.kcl.api.testCoverageReport
import com.kcl.api.testResult
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class CoverageFieldsTest {
    @Test
    fun testExecProgramArgsEmitAttributeMetadataRoundTrip() {
        val args = execProgramArgs {
            format = "json"
            emitAttributeMetadata = true
        }
        assertTrue(args.emitAttributeMetadata)
        val parsed = Spec.ExecProgramArgs.parseFrom(args.toByteArray())
        assertEquals(args, parsed)
        assertTrue(parsed.emitAttributeMetadata)
        assertEquals("json", parsed.format)
        val cleared = parsed.toBuilder().clearEmitAttributeMetadata().build()
        assertFalse(cleared.emitAttributeMetadata)
    }

    @Test
    fun testTestArgsCoverageRoundTrip() {
        val args = testArgs {
            runRegexp = ".*"
            coverage = true
        }
        assertTrue(args.coverage)
        val parsed = Spec.TestArgs.parseFrom(args.toByteArray())
        assertEquals(args, parsed)
        assertTrue(parsed.coverage)
        assertFalse(Spec.TestArgs.getDefaultInstance().coverage)
    }

    @Test
    fun testTestResultCoverageAndLineHitsRoundTrip() {
        val result = testResult {
            info += testCaseInfo {
                name = "case-a"
                duration = 42uL.toLong()
                lineHits["main.k:1"] = 2uL.toLong()
                lineHits["main.k:3"] = 1uL.toLong()
            }
            coverage = testCoverageReport {
                files["main.k"] = fileCoverage {
                    filename = "main.k"
                    coveredLines += listOf(1uL.toLong(), 3uL.toLong())
                    executableLines += listOf(1uL.toLong(), 2uL.toLong(), 3uL.toLong())
                    lineHits[1uL.toLong()] = 2uL.toLong()
                    lineHits[3uL.toLong()] = 1uL.toLong()
                }
                summary = coverageSummary {
                    covered = 2uL.toLong()
                    executable = 3uL.toLong()
                    percent = 66.67
                }
            }
        }
        val parsed = Spec.TestResult.parseFrom(result.toByteArray())
        assertEquals(result, parsed)
        assertEquals(result.hashCode(), parsed.hashCode())
        assertTrue(parsed.hasCoverage())

        val report = parsed.coverage
        assertEquals(2, report.summary.covered)
        assertEquals(3, report.summary.executable)
        assertEquals(66.67, report.summary.percent, 1e-9)

        val file = report.filesMap.getValue("main.k")
        assertEquals(listOf(1uL.toLong(), 3uL.toLong()), file.coveredLinesList)
        assertEquals(listOf(1uL.toLong(), 2uL.toLong(), 3uL.toLong()), file.executableLinesList)
        assertEquals(2uL.toLong(), file.getLineHitsOrDefault(1uL.toLong(), 0uL.toLong()))
        assertTrue(file.containsLineHits(3uL.toLong()))

        val info = parsed.getInfo(0)
        assertEquals("case-a", info.name)
        assertEquals(42uL.toLong(), info.duration)
        assertEquals(2uL.toLong(), info.getLineHitsOrThrow("main.k:1"))
        assertEquals(1, info.getLineHitsOrDefault("missing.k:9", 1uL.toLong()))
    }

    @Test
    fun testCoverageMessagesRegisteredInDescriptor() {
        val descriptor = Spec.getDescriptor()
        assertEquals(4, descriptor.findMessageTypeByName("FileCoverage").fields.size)
        assertEquals(2, descriptor.findMessageTypeByName("TestCoverageReport").fields.size)
        assertEquals(3, descriptor.findMessageTypeByName("CoverageSummary").fields.size)
        assertTrue(descriptor.findMessageTypeByName("TestCoverageReport").findFieldByName("files").isMapField)
        assertTrue(descriptor.findMessageTypeByName("FileCoverage").findFieldByName("line_hits").isMapField)
        assertTrue(descriptor.findMessageTypeByName("FileCoverage").findFieldByName("covered_lines").isRepeated)
    }

    /**
     * `Spec.java` is a checked-in protoc artifact, so it can silently fall behind
     * `spec.proto` — and it did: the generated stub was missing every message added
     * for `LoadPackageResult.imports`/`kcl_mod`/`apps`, so a caller could not read
     * those fields at all. This used to be guarded by asserting an absolute
     * `messageTypes.size`, which is the wrong shape for a canary: the stub and the
     * number were both stale and therefore agreed, so the test passed while the
     * binding was broken. Asserting that each message the spec declares is present
     * fails on the real condition instead, and does not need editing when one is added.
     */
    @Test
    fun testGeneratedStubCoversEveryMessageInSpec() {
        val spec = java.io.File("../spec/spec.proto")
        assertTrue(spec.isFile, "spec.proto not found at ${spec.absolutePath}")
        val declared = Regex("(?m)^message (\\w+)").findAll(spec.readText()).map { it.groupValues[1] }.toSet()
        assertTrue(declared.size > 50, "expected the spec to declare many messages, found ${declared.size}")

        val descriptor = Spec.getDescriptor()
        val present = descriptor.messageTypes.map { it.name }.toSet()
        val missing = declared - present
        assertTrue(missing.isEmpty(), "spec.proto declares messages absent from the generated stub: $missing")
    }
}

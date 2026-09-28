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
        assertEquals(67, descriptor.messageTypes.size)
        val fileCoverageDesc = descriptor.findMessageTypeByName("FileCoverage")
        val reportDesc = descriptor.findMessageTypeByName("TestCoverageReport")
        val summaryDesc = descriptor.findMessageTypeByName("CoverageSummary")
        assertEquals(4, fileCoverageDesc.fields.size)
        assertEquals(2, reportDesc.fields.size)
        assertEquals(3, summaryDesc.fields.size)
        assertTrue(reportDesc.findFieldByName("files").isMapField)
        assertTrue(fileCoverageDesc.findFieldByName("line_hits").isMapField)
        assertTrue(fileCoverageDesc.findFieldByName("covered_lines").isRepeated)
    }
}

package com.kcl;

import java.util.Arrays;

import com.kcl.api.API;
import com.kcl.api.Spec;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.FileCoverage;
import com.kcl.api.Spec.TestArgs;
import com.kcl.api.Spec.TestCaseInfo;
import com.kcl.api.Spec.TestCoverageReport;
import com.kcl.api.Spec.TestResult;
import com.google.protobuf.Descriptors;

import org.junit.Assert;
import org.junit.Test;

public class CoverageFieldsTest {
    @Test
    public void testExecProgramArgsEmitAttributeMetadataRoundTrip() throws Exception {
        ExecProgramArgs args = ExecProgramArgs.newBuilder().setFormat("json").setEmitAttributeMetadata(true).build();
        Assert.assertTrue(args.getEmitAttributeMetadata());
        ExecProgramArgs parsed = ExecProgramArgs.parseFrom(args.toByteArray());
        Assert.assertEquals(args, parsed);
        Assert.assertTrue(parsed.getEmitAttributeMetadata());
        Assert.assertEquals("json", parsed.getFormat());
        ExecProgramArgs cleared = parsed.toBuilder().clearEmitAttributeMetadata().build();
        Assert.assertFalse(cleared.getEmitAttributeMetadata());
    }

    @Test
    public void testTestArgsCoverageRoundTrip() throws Exception {
        TestArgs args = TestArgs.newBuilder().setRunRegexp(".*").setCoverage(true).build();
        Assert.assertTrue(args.getCoverage());
        TestArgs parsed = TestArgs.parseFrom(args.toByteArray());
        Assert.assertEquals(args, parsed);
        Assert.assertTrue(parsed.getCoverage());
        Assert.assertFalse(TestArgs.getDefaultInstance().getCoverage());
    }

    @Test
    public void testTestResultCoverageAndLineHitsRoundTrip() throws Exception {
        TestResult result = TestResult.newBuilder()
                .addInfo(TestCaseInfo.newBuilder().setName("case-a").setDuration(42L).putLineHits("main.k:1", 2L)
                        .putLineHits("main.k:3", 1L))
                .setCoverage(TestCoverageReport.newBuilder().putFiles("main.k",
                        FileCoverage.newBuilder().setFilename("main.k").addAllCoveredLines(Arrays.asList(1L, 3L))
                                .addAllExecutableLines(Arrays.asList(1L, 2L, 3L)).putLineHits(1L, 2L)
                                .putLineHits(3L, 1L).build())
                        .setSummary(Spec.CoverageSummary.newBuilder().setCovered(2L).setExecutable(3L).setPercent(66.67)
                                .build()))
                .build();
        TestResult parsed = TestResult.parseFrom(result.toByteArray());
        Assert.assertEquals(result, parsed);
        Assert.assertEquals(result.hashCode(), parsed.hashCode());
        Assert.assertTrue(parsed.hasCoverage());

        TestCoverageReport report = parsed.getCoverage();
        Assert.assertEquals(2L, report.getSummary().getCovered());
        Assert.assertEquals(3L, report.getSummary().getExecutable());
        Assert.assertEquals(66.67, report.getSummary().getPercent(), 1e-9);

        FileCoverage file = report.getFilesOrThrow("main.k");
        Assert.assertEquals(Arrays.asList(1L, 3L), file.getCoveredLinesList());
        Assert.assertEquals(Arrays.asList(1L, 2L, 3L), file.getExecutableLinesList());
        Assert.assertEquals(2L, file.getLineHitsOrDefault(1L, 0L));
        Assert.assertTrue(file.containsLineHits(3L));

        TestCaseInfo info = parsed.getInfo(0);
        Assert.assertEquals("case-a", info.getName());
        Assert.assertEquals(42L, info.getDuration());
        Assert.assertEquals(2L, info.getLineHitsOrThrow("main.k:1"));
        Assert.assertEquals(1L, info.getLineHitsOrDefault("missing.k:9", 1L));
    }

    @Test
    public void testCoverageMessagesRegisteredInDescriptor() {
        Descriptors.FileDescriptor descriptor = Spec.getDescriptor();
        Assert.assertEquals(67, descriptor.getMessageTypes().size());
        Descriptors.Descriptor fileCoverageDesc = descriptor.findMessageTypeByName("FileCoverage");
        Descriptors.Descriptor reportDesc = descriptor.findMessageTypeByName("TestCoverageReport");
        Descriptors.Descriptor summaryDesc = descriptor.findMessageTypeByName("CoverageSummary");
        Assert.assertEquals(4, fileCoverageDesc.getFields().size());
        Assert.assertEquals(2, reportDesc.getFields().size());
        Assert.assertEquals(3, summaryDesc.getFields().size());
        Assert.assertTrue(reportDesc.findFieldByName("files").isMapField());
        Assert.assertTrue(fileCoverageDesc.findFieldByName("line_hits").isMapField());
        Assert.assertTrue(fileCoverageDesc.findFieldByName("covered_lines").isRepeated());
    }

    @Test
    public void testTestingApiWithCoverage() throws Exception {
        API apiInstance = new API();
        TestArgs args = TestArgs.newBuilder().addPkgList("./src/test_data/testing/...").setCoverage(true).build();
        TestResult result = apiInstance.test(args);
        Assert.assertEquals(result.getInfoCount(), 2);
        Assert.assertTrue(result.hasCoverage());

        TestCoverageReport report = result.getCoverage();
        // The summary aggregates the coverage of the tested package fixtures.
        Assert.assertTrue(report.getSummary().getExecutable() > 0);
        Assert.assertTrue(report.getSummary().getCovered() > 0);
        Assert.assertTrue(report.getSummary().getPercent() >= 0.0);
        Assert.assertTrue(report.getFilesCount() >= 2);

        FileCoverage funcFile = null;
        FileCoverage funcTestFile = null;
        for (java.util.Map.Entry<String, FileCoverage> entry : report.getFilesMap().entrySet()) {
            if (entry.getKey().endsWith("func.k")) {
                funcFile = entry.getValue();
            } else if (entry.getKey().endsWith("func_test.k")) {
                funcTestFile = entry.getValue();
            }
        }
        Assert.assertNotNull(funcFile);
        Assert.assertNotNull(funcTestFile);
        Assert.assertFalse(funcFile.getCoveredLinesList().isEmpty());
        Assert.assertFalse(funcFile.getLineHitsMap().isEmpty());
        Assert.assertFalse(funcTestFile.getCoveredLinesList().isEmpty());
        Assert.assertFalse(funcTestFile.getLineHitsMap().isEmpty());

        Assert.assertFalse(result.getInfo(0).getLineHitsMap().isEmpty());
        Assert.assertFalse(result.getInfo(1).getLineHitsMap().isEmpty());
    }
}

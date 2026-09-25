package com.kcl;

import java.nio.file.Paths;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.ListDepFilesArgs;
import com.kcl.api.Spec.ListDepFilesResult;

public class ListDepFilesTest {
    @Test
    public void testListDepFiles() throws Exception {
        API api = new API();
        // Use the test data directory which contains KCL files.
        String workDir = Paths.get("src/test/resources").toAbsolutePath().toString();
        ListDepFilesArgs args = ListDepFilesArgs.newBuilder()
                .setWorkDir(workDir)
                .setUseAbsPath(false)
                .setIncludeAll(true)
                .setUseFastParser(false)
                .build();
        ListDepFilesResult result = api.listDepFiles(args);
        Assert.assertNotNull(result.getFiles());
    }
}

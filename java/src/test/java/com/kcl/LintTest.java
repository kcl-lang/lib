package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.LintPath_Args;
import com.kcl.api.Spec.LintPath_Result;
import org.junit.Assert;
import org.junit.Test;

public class LintTest {
    @Test
    public void testLintPathApi() throws Exception {
        final String TEST_PATH = "./src/test_data/lint_path/test-lint.k";

        LintPath_Args args = LintPath_Args.newBuilder().addPaths(TEST_PATH).build();

        API apiInstance = new API();
        LintPath_Result result = apiInstance.lintPath(args);
        boolean foundWarning = result.getResultsList().stream()
                .anyMatch(warning -> warning.contains("Module 'math' imported but unused"));
        Assert.assertTrue("Expected warning not found", foundWarning);
    }
}
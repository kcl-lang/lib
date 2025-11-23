package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.ExecProgramResult;

import org.junit.Assert;
import org.junit.Test;

public class ExecProgramTest {

    private static final String TEST_FILE = "./src/test_data/schema.k";

    @Test
    public void testExecProgramApi() throws Exception {
        ExecProgramArgs args = ExecProgramArgs.newBuilder().addKFilenameList(TEST_FILE).build();

        API apiInstance = new API();
        ExecProgramResult result = apiInstance.execProgram(args);
        Assert.assertEquals(result.getYamlResult(), "app:\n" + "  replicas: 2");
    }

    @Test
    public void testExecProgramApiInvalid() {
        try {
            ExecProgramArgs args = ExecProgramArgs.newBuilder().build();

            API apiInstance = new API();
            apiInstance.execProgram(args);
        } catch (Exception e) {
            Assert.assertEquals(e.getMessage(), "No input KCL files or paths");
        }
    }
}

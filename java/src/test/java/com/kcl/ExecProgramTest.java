package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgram_Args;
import com.kcl.api.Spec.ExecProgram_Result;

import org.junit.Assert;
import org.junit.Test;

public class ExecProgramTest {

    private static final String TEST_FILE = "./src/test_data/schema.k";

    @Test
    public void testGetSchemaTypeApi() throws Exception {
        ExecProgram_Args args = ExecProgram_Args.newBuilder().addKFilenameList(TEST_FILE).build();

        API apiInstance = new API();
        ExecProgram_Result result = apiInstance.execProgram(args);
        Assert.assertEquals(result.getYamlResult(), "app:\n" + "  replicas: 2");
    }
}

package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgram_Args;
import com.kcl.api.Spec.GetSchemaTypeMapping_Args;
import com.kcl.api.Spec.GetSchemaTypeMapping_Result;
import com.kcl.api.Spec.KclType;

import org.junit.Assert;
import org.junit.Test;

public class GetSchemaTypeTest {

    private static final String TEST_FILE = "./src/test_data/schema.k";

    @Test
    public void testGetSchemaTypeApi() throws Exception {
        ExecProgram_Args execArgs = ExecProgram_Args.newBuilder().addKFilenameList(TEST_FILE).build();

        GetSchemaTypeMapping_Args args = GetSchemaTypeMapping_Args.newBuilder().setExecArgs(execArgs).build();

        API apiInstance = new API();
        GetSchemaTypeMapping_Result result = apiInstance.getSchemaTypeMapping(args);

        KclType appSchemaType = result.getSchemaTypeMappingMap().get("app");
        String replicasType = appSchemaType.getPropertiesOrThrow("replicas").getType();
        Assert.assertEquals("int", replicasType);
    }
}

package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.GetSchemaTypeMappingArgs;
import com.kcl.api.Spec.GetSchemaTypeMappingResult;
import com.kcl.api.Spec.KclType;

import org.junit.Assert;
import org.junit.Test;

public class GetSchemaTypeTest {

    private static final String TEST_FILE = "./src/test_data/schema.k";

    @Test
    public void testGetSchemaTypeApi() throws Exception {
        ExecProgramArgs execArgs = ExecProgramArgs.newBuilder().addKFilenameList(TEST_FILE).build();

        GetSchemaTypeMappingArgs args = GetSchemaTypeMappingArgs.newBuilder().setExecArgs(execArgs).build();

        API apiInstance = new API();
        GetSchemaTypeMappingResult result = apiInstance.getSchemaTypeMapping(args);

        KclType appSchemaType = result.getSchemaTypeMappingMap().get("app");
        String replicasType = appSchemaType.getPropertiesOrThrow("replicas").getType();
        Assert.assertEquals("int", replicasType);
    }
}

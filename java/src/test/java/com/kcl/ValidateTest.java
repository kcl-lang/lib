package com.kcl;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.ValidateCode_Args;
import com.kcl.api.Spec.ValidateCode_Result;

public class ValidateTest {
    @Test
    public void testValidateCodeApi() throws Exception {
        String code = "schema Person:\n" + "    name: str\n" + "    age: int\n" + "    check:\n"
                + "        0 < age < 120\n";

        String data = "{\"name\": \"Alice\", \"age\": 10}";

        ValidateCode_Args args = ValidateCode_Args.newBuilder().setCode(code).setData(data).setFormat("json").build();
        API apiInstance = new API();
        ValidateCode_Result result = apiInstance.validateCode(args);

        Assert.assertTrue(result.getSuccess());
        Assert.assertEquals("", result.getErrMessage());
    }
}

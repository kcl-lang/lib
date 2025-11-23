package com.kcl;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.ValidateCodeArgs;
import com.kcl.api.Spec.ValidateCodeResult;

public class ValidateTest {
    @Test
    public void testValidateCodeApi() throws Exception {
        String code = "schema Person:\n" + "    name: str\n" + "    age: int\n" + "    check:\n"
                + "        0 < age < 120\n";

        String data = "{\"name\": \"Alice\", \"age\": 10}";

        ValidateCodeArgs args = ValidateCodeArgs.newBuilder().setCode(code).setData(data).setFormat("json").build();
        API apiInstance = new API();
        ValidateCodeResult result = apiInstance.validateCode(args);

        Assert.assertTrue(result.getSuccess());
        Assert.assertEquals("", result.getErrMessage());
    }
}

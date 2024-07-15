package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.FormatCode_Args;
import com.kcl.api.Spec.FormatCode_Result;
import com.kcl.api.Spec.FormatPath_Args;
import org.junit.Assert;
import org.junit.Test;

public class FormatTest {
    @Test
    public void testFormatPathApi() throws Exception {
        final String TEST_PATH = "./src/test_data/format_path/test.k";
        FormatPath_Args args = FormatPath_Args.newBuilder().setPath(TEST_PATH).build();
        API apiInstance = new API();
        apiInstance.formatPath(args);
    }

    @Test
    public void testFormatCodeApi() throws Exception {
        String sourceCode = "schema Person:\n" + "    name:   str\n" + "    age:    int\n" + "    check:\n"
                + "        0 <   age <   120\n";

        FormatCode_Args args = FormatCode_Args.newBuilder().setSource(sourceCode).build();

        API apiInstance = new API();
        FormatCode_Result result = apiInstance.formatCode(args);

        String expectedFormattedCode = "schema Person:\n" + "    name: str\n" + "    age: int\n\n" + "    check:\n"
                + "        0 < age < 120\n\n";

        Assert.assertEquals(expectedFormattedCode, result.getFormatted().toStringUtf8());
    }
}

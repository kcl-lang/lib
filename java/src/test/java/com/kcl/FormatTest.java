package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.FormatCodeArgs;
import com.kcl.api.Spec.FormatCodeResult;
import com.kcl.api.Spec.FormatPathArgs;
import org.junit.Assert;
import org.junit.Test;

public class FormatTest {
    @Test
    public void testFormatPathApi() throws Exception {
        final String TEST_PATH = "./src/test_data/format_path/test.k";
        FormatPathArgs args = FormatPathArgs.newBuilder().setPath(TEST_PATH).build();
        API apiInstance = new API();
        apiInstance.formatPath(args);
    }

    @Test
    public void testFormatCodeApi() throws Exception {
        String sourceCode = "schema Person:\n" + "    name:   str\n" + "    age:    int\n" + "    check:\n"
                + "        0 <   age <   120\n";

        FormatCodeArgs args = FormatCodeArgs.newBuilder().setSource(sourceCode).build();

        API apiInstance = new API();
        FormatCodeResult result = apiInstance.formatCode(args);

        String expectedFormattedCode = "schema Person:\n" + "    name: str\n" + "    age: int\n\n" + "    check:\n"
                + "        0 < age < 120\n\n";

        Assert.assertEquals(expectedFormattedCode, result.getFormatted().toStringUtf8());
    }
}

package com.kcl;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.ParseFile_Args;
import com.kcl.api.Spec.ParseFile_Result;

public class ParseTest {
    @Test
    public void testParseFile() throws Exception {
        ParseFile_Args args = ParseFile_Args.newBuilder().setPath("./src/test_data/parse/main.k").build();

        API apiInstance = new API();
        ParseFile_Result result = apiInstance.parseFile(args);
        Assert.assertNotNull(result.getAstJson());
        Assert.assertEquals(result.getDepsCount(), 2);
    }
}

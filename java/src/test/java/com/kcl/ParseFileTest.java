package com.kcl;

import java.nio.file.Path;
import java.nio.file.Paths;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.ParseFile_Args;
import com.kcl.api.Spec.ParseFile_Result;

public class ParseFileTest {
    @Test
    public void testParseFile() throws Exception {
        Path path = Paths.get("src", "test_data", "parse", "main.k");
        ParseFile_Args args = ParseFile_Args.newBuilder().setPath(path.toString()).build();

        API apiInstance = new API();
        ParseFile_Result result = apiInstance.parseFile(args);
        Assert.assertNotNull(result.getAstJson());
        Assert.assertEquals(result.getDepsCount(), 2);
    }
}

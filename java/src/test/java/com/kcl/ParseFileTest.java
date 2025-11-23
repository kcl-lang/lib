package com.kcl;

import java.nio.file.Path;
import java.nio.file.Paths;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.ParseFileArgs;
import com.kcl.api.Spec.ParseFileResult;

public class ParseFileTest {
    @Test
    public void testParseFile() throws Exception {
        Path path = Paths.get("src", "test_data", "parse", "main.k");
        ParseFileArgs args = ParseFileArgs.newBuilder().setPath(path.toString()).build();

        API apiInstance = new API();
        ParseFileResult result = apiInstance.parseFile(args);
        Assert.assertNotNull(result.getAstJson());
        Assert.assertEquals(result.getDepsCount(), 2);
    }
}

package com.kcl;

import java.nio.file.Path;
import java.nio.file.Paths;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.ParseProgramArgs;
import com.kcl.api.Spec.ParseProgramResult;
import com.kcl.ast.Program;
import com.kcl.util.JsonUtil;

public class ParseProgramTest {
    @Test
    public void testParseProgram() throws Exception {
        Path path = Paths.get("src", "test_data", "parse", "main.k");
        ParseProgramArgs args = ParseProgramArgs.newBuilder().addPaths(path.toString()).build();

        API apiInstance = new API();
        ParseProgramResult result = apiInstance.parseProgram(args);
        Assert.assertEquals(result.getPathsCount(), 3);
        Program program = JsonUtil.deserializeProgram(result.getAstJson());
        Assert.assertTrue(program.getRoot().contains("test_data"));
        Assert.assertEquals(program.getMainPackage().get(0).getBody().size(), 6);
    }
}

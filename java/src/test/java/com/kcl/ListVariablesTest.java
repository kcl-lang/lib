package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ListVariables_Args;
import com.kcl.api.Spec.ListVariables_Options;
import com.kcl.api.Spec.ListVariables_Result;

import java.nio.file.Paths;

import org.junit.Assert;
import org.junit.Test;

public class ListVariablesTest {
    @Test
    public void testListVariables() throws Exception {
        // API instance
        API api = new API();

        // Define the variables to test and their expected results
        String[][] testCases = { { "a", "1", "", "=" }, { "a1", "2", "", "=" }, { "a3", "3m", "", "=" },
                { "b1", "True", "", "=" }, { "b2", "False", "", "=" }, { "s1", "\"Hello\"", "", "=" },
                { "array1", "[1, 2, 3]", "", "=" }, { "dict1", "{\"a\": 1, \"b\": 2}", "", "=" },
                { "dict1.a", "1", "", ":" }, { "dict1.b", "2", "", ":" }, { "dict2.b.c", "2", "", ":" },
                { "dict2.b.d", "3", "", ":" }, { "sha.name", "\"Hello\"", "", ":" },
                { "sha.ids", "[1, 2, 3]", "", ":" }, { "sha.data.a.b", "{\"c\": 2}", "", ":" },
                { "sha.data.a.b.c", "2", "", ":" }, { "shb.a.name", "\"HelloB\"", "", ":" },
                { "shb.a.ids", "[4, 5, 6]", "", ":" }, { "shb.a.data.d.e", "{\"f\": 3}", "", ":" },
                { "uconfa.name", "\"b\"", "", "=" }, { "c.a", "{name: \"Hello\"}", "", ":" },
                { "c1", "C {}", "C", "=" }, { "c2", "a.b.C {}", "a.b.C", "=" } };

        for (String[] testCase : testCases) {
            String spec = testCase[0];
            String expectedValue = testCase[1];
            String expectedName = testCase[2];
            String expectOpSym = testCase[3];
            ListVariables_Result result = api.listVariables(ListVariables_Args.newBuilder()
                    .addFiles("./src/test_data/list_variables/main.k").addSpecs(spec).build());

            Assert.assertEquals(result.getVariablesCount(), 1);
            System.out.println("spec is " + spec);
            Assert.assertEquals(result.getVariablesMap().get(spec).getVariables(0).getValue(), expectedValue);
            Assert.assertEquals(result.getVariablesMap().get(spec).getVariables(0).getTypeName(), expectedName);
            Assert.assertEquals(result.getVariablesMap().get(spec).getVariables(0).getOpSym(), expectOpSym);
        }
    }

    @Test
    public void testListVariablesWithInvalidKcl() throws Exception {
        // API instance
        API api = new API();

        String filePath = Paths.get("./src/test_data/list_variables/invalid.k").toAbsolutePath().toString();

        ListVariables_Result result = api
                .listVariables(ListVariables_Args.newBuilder().addFiles(filePath).addSpecs("a").build());

        Assert.assertEquals(result.getParseErrorsCount(), 2);
        Assert.assertEquals(result.getParseErrors(0).getLevel(), "error");
        Assert.assertEquals(result.getParseErrors(0).getCode(), "Error(InvalidSyntax)");
        Assert.assertTrue(result.getParseErrors(0).getMessages(0).getPos().getFilename()
                .contains(Paths.get("src/test_data/list_variables/invalid.k").getFileName().toString()));
        Assert.assertEquals(result.getParseErrors(0).getMessages(0).getPos().getLine(), 1);
        Assert.assertEquals(result.getParseErrors(0).getMessages(0).getPos().getColumn(), 8);
        Assert.assertEquals(result.getParseErrors(0).getMessages(0).getMsg(), "expected one of [\"=\"] got eof");
    }

    @Test
    public void testListVariablesWithList() throws Exception {
        // API instance
        API api = new API();

        String filePath = Paths.get("./src/test_data/list_variables/list.k").toAbsolutePath().toString();

        ListVariables_Result result = api
                .listVariables(ListVariables_Args.newBuilder().addFiles(filePath).addSpecs("list0").build());
        Assert.assertEquals(result.getVariablesCount(), 1);
        Assert.assertEquals(result.getVariablesMap().get("list0").getVariables(0).getValue(), "[1, 2, 3]");
        Assert.assertEquals(result.getVariablesMap().get("list0").getVariables(0).getTypeName(), "");
        Assert.assertEquals(result.getVariablesMap().get("list0").getVariables(0).getOpSym(), "=");
        Assert.assertEquals(result.getVariablesMap().get("list0").getVariables(0).getListItemsCount(), 3);
        Assert.assertEquals(result.getVariablesMap().get("list0").getVariables(0).getListItems(0).getValue(), "1");
        Assert.assertEquals(result.getVariablesMap().get("list0").getVariables(0).getListItems(1).getValue(), "2");
        Assert.assertEquals(result.getVariablesMap().get("list0").getVariables(0).getListItems(2).getValue(), "3");
    }

    @Test
    public void testListMergedVariables() throws Exception {
        // API instance
        API api = new API();

        String[][] testData = {
                { "./src/test_data/list_merged_variables/merge_0/main.k",
                        "./src/test_data/list_merged_variables/merge_0/base.k", "tests.aType", "\"Internet\"" },
                { "./src/test_data/list_merged_variables/merge_1/base.k",
                        "./src/test_data/list_merged_variables/merge_1/main.k", "appConfiguration.resource",
                        "res.Resource {cpu = \"2\", disk = \"35Gi\", memory = \"4Gi\"}" } };

        for (String[] data : testData) {
            String mainFilePath = Paths.get(data[0]).toAbsolutePath().toString();
            String baseFilePath = Paths.get(data[1]).toAbsolutePath().toString();
            String spec = data[2];
            String expectedValue = data[3];

            ListVariables_Result result = api.listVariables(ListVariables_Args.newBuilder()
                    .setOptions(ListVariables_Options.newBuilder().setMergeProgram(true).build()).addFiles(baseFilePath)
                    .addFiles(mainFilePath).addSpecs(spec).build());

            Assert.assertEquals(result.getVariablesCount(), 1);
            Assert.assertEquals(result.getVariablesMap().get(spec).getVariables(0).getValue(), expectedValue);
        }
    }
}

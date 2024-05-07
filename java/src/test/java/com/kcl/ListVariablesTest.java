package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ListVariables_Args;
import com.kcl.api.Spec.ListVariables_Result;
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
                { "uconfa.name", "\"b\"", "", "=" }, { "c.a", "{ids: [7, 8, 9]}", "", ":" }, { "c1", "C {}", "C", "=" },
                { "c2", "a.b.C {}", "a.b.C", "=" } };

        for (String[] testCase : testCases) {
            String spec = testCase[0];
            String expectedValue = testCase[1];
            String expectedName = testCase[2];
            String expectOpSym = testCase[3];
            ListVariables_Result result = api.listVariables(ListVariables_Args.newBuilder()
                    .setFile("./src/test_data/list_variables/main.k").addSpecs(spec).build());

            Assert.assertEquals(result.getVariablesCount(), 1);
            System.out.println("spec is " + spec);
            Assert.assertEquals(result.getVariablesMap().get(spec).getValue(), expectedValue);
            Assert.assertEquals(result.getVariablesMap().get(spec).getTypeName(), expectedName);
            Assert.assertEquals(result.getVariablesMap().get(spec).getOpSym(), expectOpSym);
        }
    }
}

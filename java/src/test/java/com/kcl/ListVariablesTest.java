package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ListVariables_Args;
import com.kcl.api.Spec.ListVariables_Result;
import com.kcl.api.Spec.LoadPackage_Args;
import com.kcl.api.Spec.LoadPackage_Result;
import com.kcl.api.Spec.ParseProgram_Args;
import com.kcl.api.Spec.Scope;
import com.kcl.api.Spec.Symbol;
import com.kcl.api.Spec.SymbolIndex;
import com.kcl.ast.NodeRef;
import com.kcl.ast.Program;
import com.kcl.ast.Stmt;
import com.kcl.util.JsonUtil;
import com.kcl.util.SematicUtil;
import org.junit.Assert;
import org.junit.Test;

public class ListVariablesTest {
    @Test
    public void testListVariables() throws Exception {
        // API instance
        API api = new API();

        // Define the variables to test and their expected results
        String[][] testCases = { { "a", "1" }, { "a1", "2" }, { "a3", "3m" }, { "b1", "True" }, { "b2", "False" },
                { "s1", "\"Hello\"" }, { "array1", "[1, 2, 3]" }, { "dict1", "{\"a\": 1, \"b\": 2}" },
                { "dict1.a", "1" }, { "dict1.b", "2" }, { "dict2.b.c", "2" }, { "dict2.b.d", "3" },
                { "sha.name", "\"Hello\"" }, { "sha.ids", "[1, 2, 3]" }, { "sha.data.a.b", "{\"c\": 2}" },
                { "sha.data.a.b.c", "2" }, { "shb.a.name", "\"HelloB\"" }, { "shb.a.ids", "[4, 5, 6]" },
                { "shb.a.data.d.e", "{\"f\": 3}" }, { "uconfa.name", "\"b\"" }, { "c.a", "{ids: [7, 8, 9]}" }, };

        for (String[] testCase : testCases) {
            String spec = testCase[0];
            String expectedValue = testCase[1];
            ListVariables_Result result = api.listVariables(ListVariables_Args.newBuilder()
                    .setFile("./src/test_data/list_variables/main.k").addSpecs(spec).build());

            Assert.assertEquals(result.getVariablesCount(), 1);
            Assert.assertEquals(result.getVariablesMap().get(spec).getValue(), expectedValue);

        }
    }

    @Test
    public void testProgramSymbolsWithCache() throws Exception {
        // API instance
        API api = new API();
        // Note call `loadPackageWithCache` here.
        LoadPackage_Result result = api.loadPackageWithCache(LoadPackage_Args.newBuilder().setResolveAst(true)
                .setWithAstIndex(true)
                .setParseArgs(ParseProgram_Args.newBuilder().addPaths("./src/test_data/schema.k").build()).build());
        // Get parse errors
        Assert.assertEquals(result.getParseErrorsList().size(), 0);
        // Get Type errors
        Assert.assertEquals(result.getTypeErrorsList().size(), 0);
        // Get AST
        Program program = JsonUtil.deserializeProgram(result.getProgram());
        Assert.assertTrue(program.getRoot().contains("test_data"));
        // Variable definitions in the main scope.
        Scope mainScope = SematicUtil.findMainPackageScope(result);
        // Child scopes of the main scope.
        Assert.assertEquals(mainScope.getChildrenList().size(), 2);
        // Mapping AST node to Symbol type
        NodeRef<Stmt> stmt = program.getFirstModule().getBody().get(0);
        Assert.assertTrue(SematicUtil.findSymbolByAstId(result, stmt.getId()).getName().contains("pkg"));
        // Mapping symbol to AST node
        SymbolIndex appSymbolIndex = mainScope.getDefs(1);
        Symbol appSymbol = SematicUtil.findSymbol(result, appSymbolIndex);
        Assert.assertEquals(appSymbol.getTy().getSchemaName(), "AppConfig");
        // Query type symbol using variable type.
        String schemaFullName = appSymbol.getTy().getPkgPath() + "." + appSymbol.getTy().getSchemaName();
        Symbol appConfigSymbol = SematicUtil.findSymbol(result,
                result.getFullyQualifiedNameMapOrDefault(schemaFullName, null));
        Assert.assertEquals(appConfigSymbol.getTy().getSchemaName(), "AppConfig");
        // Query AST node using the symbol
        Assert.assertNotNull(SematicUtil.findNodeBySymbol(result, appSymbolIndex));
        // Query Scope using the symbol
        Assert.assertEquals(SematicUtil.findScopeBySymbol(result, appSymbolIndex).getDefsCount(), 2);
    }
}

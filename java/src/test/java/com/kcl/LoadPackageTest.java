package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.LoadPackageArgs;
import com.kcl.api.Spec.LoadPackageResult;
import com.kcl.api.Spec.ParseProgramArgs;
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

public class LoadPackageTest {
    @Test
    public void testProgramSymbols() throws Exception {
        // API instance
        API api = new API();
        LoadPackageResult result = api.loadPackage(LoadPackageArgs.newBuilder().setResolveAst(true)
                .setWithAstIndex(true)
                .setParseArgs(ParseProgramArgs.newBuilder().addPaths("./src/test_data/schema.k").build()).build());
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

    @Test
    public void testProgramSymbolsWithCache() throws Exception {
        // API instance
        API api = new API();
        // Note call `loadPackageWithCache` here.
        LoadPackageResult result = api.loadPackageWithCache(LoadPackageArgs.newBuilder().setResolveAst(true)
                .setWithAstIndex(true)
                .setParseArgs(ParseProgramArgs.newBuilder().addPaths("./src/test_data/schema.k").build()).build());
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

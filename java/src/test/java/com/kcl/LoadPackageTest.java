package com.kcl;

import java.util.Collection;

import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.LoadPackage_Args;
import com.kcl.api.Spec.LoadPackage_Result;
import com.kcl.api.Spec.ParseProgram_Args;
import com.kcl.api.Spec.Scope;
import com.kcl.api.Spec.Symbol;
import com.kcl.ast.NodeRef;
import com.kcl.ast.Program;
import com.kcl.ast.Stmt;
import com.kcl.util.JsonUtil;
import com.kcl.util.SematicUtil;

public class LoadPackageTest {
    @Test
    public void testProgramSymbols() throws Exception {
        // API instance
        API api = new API();
        LoadPackage_Result result = api.loadPackage(
                LoadPackage_Args.newBuilder().setResolveAst(true).setWithAstIndex(true).setParseArgs(
                        ParseProgram_Args.newBuilder().addPaths("./src/test_data/schema.k").build())
                        .build());
        // Get parse errors
        System.out.println(result.getParseErrorsList());
        // Get Type errors
        System.out.println(result.getTypeErrorsList());
        // Get AST
        Program program = JsonUtil.deserializeProgram(result.getProgram());
        System.out.println(program.getRoot());
        // Get symbols
        Collection<Symbol> symbols = result.getSymbolsMap().values();
        symbols.forEach(s -> System.out.println(s));
        // Get scopes
        Collection<Scope> scopes = result.getScopesMap().values();
        scopes.forEach(s -> System.out.println(s));
        // Variable definitions in the main scope.
        Scope mainScope = SematicUtil.findMainPackageScope(result);
        mainScope.getDefsList().forEach(s -> {
            try {
                System.out.println(SematicUtil.findSymbol(result, s));
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
        // Child scopes of the main scope.
        System.out.println(mainScope.getChildrenList());
        // Mapping AST node to Symbol type
        NodeRef<Stmt> stmt = program.getFirstModule().getBody().get(0);
        System.out.println(SematicUtil.findSymbolByAstId(result, stmt.getId()));
    }
}

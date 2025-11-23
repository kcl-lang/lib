package com.kcl.util;

import com.kcl.api.Spec.LoadPackageResult;
import com.kcl.api.Spec.Scope;
import com.kcl.api.Spec.ScopeIndex;
import com.kcl.api.Spec.Symbol;
import com.kcl.api.Spec.SymbolIndex;
import com.kcl.ast.Program;
import java.util.HashMap;
import java.util.Map;

public class SematicUtil {
    static String indexStringFormat = "{\"i\":%d,\"g\":%d,\"kind\":\"%s\"}";

    public static Symbol findSymbol(LoadPackageResult result, SymbolIndex index) throws Exception {
        if (result == null || index == null) {
            return null;
        }
        String key = String.format(indexStringFormat, index.getI(), index.getG(), index.getKind());
        Map<String, Symbol> symbols = result.getSymbolsMap();
        return symbols.get(key);
    }

    public static Symbol findSymbolByAstId(LoadPackageResult result, String id) throws Exception {
        if (id == null) {
            return null;
        }
        return findSymbol(result, result.getNodeSymbolMapOrDefault(id, null));
    }

    public static Scope findScope(LoadPackageResult result, ScopeIndex index) throws Exception {
        if (result == null || index == null) {
            return null;
        }
        String key = String.format(indexStringFormat, index.getI(), index.getG(), index.getKind());
        Map<String, Scope> scopes = result.getScopesMap();
        return scopes.get(key);
    }

    public static Scope findScopeByAstId(LoadPackageResult result, String id) throws Exception {
        if (result == null || id == null) {
            return null;
        }
        return findScopeBySymbol(result, result.getNodeSymbolMapOrDefault(id, null));
    }

    public static Scope findScopeBySymbol(LoadPackageResult result, SymbolIndex index) throws Exception {
        if (result == null || index == null) {
            return null;
        }
        for (ScopeIndex scopeIndex : result.getPkgScopeMapMap().values()) {
            Scope scope = symbolCurrentScope(result, index, scopeIndex);
            if (scope != null) {
                return scope;
            }
        }
        return null;
    }

    public static Map<SymbolIndex, ScopeIndex> getSymbolScopeMap(LoadPackageResult result) throws Exception {
        if (result == null) {
            return null;
        }
        HashMap<SymbolIndex, ScopeIndex> map = new HashMap<>();
        for (ScopeIndex scopeIndex : result.getPkgScopeMapMap().values()) {
            constructSymbolScopeMap(map, result, scopeIndex);
        }
        return map;
    }

    private static void constructSymbolScopeMap(Map<SymbolIndex, ScopeIndex> map, LoadPackageResult result,
            ScopeIndex scopeIndex) throws Exception {
        Scope scope = findScope(result, scopeIndex);
        if (scope != null) {
            for (SymbolIndex index : scope.getDefsList()) {
                map.put(index, scopeIndex);
            }
            for (ScopeIndex child : scope.getChildrenList()) {
                constructSymbolScopeMap(map, result, child);
            }
        }
    }

    private static Scope symbolCurrentScope(LoadPackageResult result, SymbolIndex symbolIndex, ScopeIndex scopeIndex)
            throws Exception {
        Scope scope = findScope(result, scopeIndex);
        if (scope != null) {
            for (SymbolIndex index : scope.getDefsList()) {
                if (symbolIndex.equals(index)) {
                    return scope;
                }
            }
            for (ScopeIndex child : scope.getChildrenList()) {
                scope = symbolCurrentScope(result, symbolIndex, child);
                if (scope != null) {
                    return scope;
                }
            }
        }
        return null;
    }

    public static Scope findPackageScope(LoadPackageResult result, String pkg) throws Exception {
        if (result == null) {
            return null;
        }
        if (pkg == null || pkg.equals("")) {
            return findScope(result, result.getPkgScopeMapOrDefault(Program.MAIN_PKG, null));
        }
        return findScope(result, result.getPkgScopeMapOrDefault(pkg, null));
    }

    public static Scope findMainPackageScope(LoadPackageResult result) throws Exception {
        return findPackageScope(result, Program.MAIN_PKG);
    }

    public static String findNodeBySymbol(LoadPackageResult result, SymbolIndex index) throws Exception {
        if (result == null || index == null) {
            return null;
        }
        String key = String.format(indexStringFormat, index.getI(), index.getG(), index.getKind());
        Map<String, String> symbolNodes = result.getSymbolNodeMapMap();
        return symbolNodes.get(key);
    }
}

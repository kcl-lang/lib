package com.kcl.util;

import java.util.Map;

import com.kcl.api.Spec.LoadPackage_Result;
import com.kcl.api.Spec.Scope;
import com.kcl.api.Spec.ScopeIndex;
import com.kcl.api.Spec.Symbol;
import com.kcl.api.Spec.SymbolIndex;

public class SematicUtil {
    static String indexStringFormat = "{\"i\":%d,\"g\":%d,\"kind\":\"%s\"}";

    public static Symbol findSymbol(LoadPackage_Result result, SymbolIndex index) throws Exception {
        if (result == null || index == null) {
            return null;
        }
        String key = String.format(indexStringFormat, index.getI(), index.getG(), index.getKind());
        Map<String, Symbol> symbols = result.getSymbolsMap();
        return symbols.get(key);
    }

    public static Symbol findSymbolByAstId(LoadPackage_Result result, String id) throws Exception {
        if (id == null) {
            return null;
        }
        return findSymbol(result, result.getNodeSymbolMapOrDefault(id, null));
    }

    public static Scope findScope(LoadPackage_Result result, ScopeIndex index) throws Exception {
        if (result == null || index == null) {
            return null;
        }
        String key = String.format(indexStringFormat, index.getI(), index.getG(), index.getKind());
        Map<String, Scope> scopes = result.getScopesMap();
        return scopes.get(key);
    }

    public static Scope findPackageScope(LoadPackage_Result result, String pkg) throws Exception {
        if (result == null) {
            return null;
        }
        if (pkg == null || pkg.equals("")) {
            return findScope(result, result.getPkgScopeMapOrDefault("__main__", null));
        }
        return findScope(result, result.getPkgScopeMapOrDefault(pkg, null));
    }

    public static Scope findMainPackageScope(LoadPackage_Result result) throws Exception {
        return findPackageScope(result, "__main__");
    }
}

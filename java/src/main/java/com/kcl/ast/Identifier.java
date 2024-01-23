package com.kcl.ast;

import java.util.List;
import java.util.stream.Collectors;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Identifier, e.g.
 * 
 * <pre>{@code 
 *a
 *b
 *_c
 *pkg.a}
 *</pre>
 */
public class Identifier {
    @JsonProperty("names")
    private List<NodeRef<String>> names;

    @JsonProperty("pkgpath")
    private String pkgpath;

    @JsonProperty("ctx")
    private ExprContext ctx;

    // Method to get combined name
    public String getName() {
        return names.stream()
                .map(Node::getNode)
                .collect(Collectors.joining("."));
    }

    // Method to get list of names
    public List<String> getNames() {
        return names.stream()
                .map(Node::getNode)
                .collect(Collectors.toList());
    }

    public void setNames(List<NodeRef<String>> names) {
        this.names = names;
    }

    public String getPkgpath() {
        return pkgpath;
    }

    public void setPkgpath(String pkgpath) {
        this.pkgpath = pkgpath;
    }

    public ExprContext getCtx() {
        return ctx;
    }

    public void setCtx(ExprContext ctx) {
        this.ctx = ctx;
    }
}

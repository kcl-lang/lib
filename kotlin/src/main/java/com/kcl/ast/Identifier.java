package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Identifier, e.g.
 *
 * <pre>
 * {@code
 * a
 * b
 * _c
 * pkg.a
 * }
 * </pre>
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
        return names.stream().map(Node::getNode).collect(Collectors.joining("."));
    }

    // Method to get list of names
    public List<String> getNames() {
        return names.stream().map(Node::getNode).collect(Collectors.toList());
    }

    public void setNames(List<NodeRef<String>> names) {
        this.names = names;
    }

    /**
     * The `names` value as the wire carries it. `getNames()` above flattens the
     * same field to a list of strings for callers that only want the dotted
     * name, which leaves no public accessor for the `NodeRef` list itself —
     * so a tree read back from `ast_json` cannot be written out again.
     * `@JsonIgnore` keeps this off the wire: it is an accessor, not a field.
     */
    @JsonIgnore
    public List<NodeRef<String>> getNameNodes() {
        return names;
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

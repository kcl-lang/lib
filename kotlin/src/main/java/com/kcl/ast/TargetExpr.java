package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * Target, e.g.
 *
 * <pre>
 * {@code
 * a
 * b
 * _c
 * a["b"][0].c
 * }
 * </pre>
 */
public class TargetExpr extends Expr {
    @JsonProperty("name")
    private NodeRef<String> name;

    @JsonProperty("pkgpath")
    private String pkgpath;

    @JsonProperty("paths")
    private List<MemberOrIndex> paths;

    // Method to get combined name
    public String getName() {
        return name.getNode();
    }

    public void setName(NodeRef<String> name) {
        this.name = name;
    }

    /**
     * The `name` field as the wire carries it. `getName()` above unwraps it to
     * the bare string, which is what a caller assembling a target wants and
     * what makes the `NodeRef` — and its position — unreadable. See
     * `Identifier.getNameNodes`.
     */
    @JsonIgnore
    public NodeRef<String> getNameRef() {
        return name;
    }

    public String getPkgpath() {
        return pkgpath;
    }

    public void setPkgpath(String pkgpath) {
        this.pkgpath = pkgpath;
    }

    public List<MemberOrIndex> getPaths() {
        return paths;
    }

    public void setPaths(List<MemberOrIndex> paths) {
        this.paths = paths;
    }
}

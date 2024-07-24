package com.kcl.ast;

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
public class Target {
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

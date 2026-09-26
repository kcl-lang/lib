package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Keyword, e.g.
 *
 * <pre>
 * {@code
 * arg = value
 * }
 * </pre>
 */
public class Keyword {
    @JsonProperty("arg")
    private NodeRef<Identifier> arg;

    @JsonProperty("value")
    private NodeRef<Expr> value;

    public NodeRef<Identifier> getArg() {
        return arg;
    }

    public void setArg(NodeRef<Identifier> arg) {
        this.arg = arg;
    }

    public NodeRef<Expr> getValue() {
        return value;
    }

    public void setValue(NodeRef<Expr> value) {
        this.value = value;
    }
}

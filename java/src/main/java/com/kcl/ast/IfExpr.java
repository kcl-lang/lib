package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * IfExpr, e.g.
 *
 * <pre>
 * {@code
 * 1 if condition else 2
 * }
 * </pre>
 */
@JsonTypeName("If")
public class IfExpr extends Expr {
    @JsonProperty("body")
    private NodeRef<Expr> body;

    @JsonProperty("cond")
    private NodeRef<Expr> cond;

    @JsonProperty("orelse")
    private NodeRef<Expr> orelse;

    public NodeRef<Expr> getBody() {
        return body;
    }

    public void setBody(NodeRef<Expr> body) {
        this.body = body;
    }

    public NodeRef<Expr> getCond() {
        return cond;
    }

    public void setCond(NodeRef<Expr> cond) {
        this.cond = cond;
    }

    public NodeRef<Expr> getOrelse() {
        return orelse;
    }

    public void setOrelse(NodeRef<Expr> orelse) {
        this.orelse = orelse;
    }
}

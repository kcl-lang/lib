package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;
import java.util.List;

/**
 * IfStmt, e.g.
 *
 * <p>
 *
 * <pre>
 * {@code
 * if condition1:
 *     if condition2:
 *         a = 1
 * elif condition3:
 *     b = 2
 * else:
 *     c = 3</code>
 * }
 * </pre>
 */
@JsonTypeName("If")
public class IfStmt extends Stmt {
    @JsonProperty("body")
    private List<NodeRef<Stmt>> body;

    @JsonProperty("cond")
    private NodeRef<Expr> cond;

    @JsonProperty("orelse")
    private List<NodeRef<Stmt>> orelse;

    public List<NodeRef<Stmt>> getBody() {
        return body;
    }

    public void setBody(List<NodeRef<Stmt>> body) {
        this.body = body;
    }

    public NodeRef<Expr> getCond() {
        return cond;
    }

    public void setCond(NodeRef<Expr> cond) {
        this.cond = cond;
    }

    public List<NodeRef<Stmt>> getOrelse() {
        return orelse;
    }

    public void setOrelse(List<NodeRef<Stmt>> orelse) {
        this.orelse = orelse;
    }

    // Constructor, getters, and setters...
}

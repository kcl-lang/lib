package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * ExprStmt represents a expression statement, e.g.
 *
 * <p>
 * <code>
 * 1
 * </code>
 *
 * <p>
 * <code>
 * """A long string"""
 * </code>
 *
 * <p>
 * <code>
 * 'A string'
 * </code>
 */
public class ExprStmt extends Stmt {
    @JsonProperty("exprs")
    private List<NodeRef<Expr>> exprs;

    public List<NodeRef<Expr>> getExprs() {
        return exprs;
    }

    public void setExprs(List<NodeRef<Expr>> exprs) {
        this.exprs = exprs;
    }
}

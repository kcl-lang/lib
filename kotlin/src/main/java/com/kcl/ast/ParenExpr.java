package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * ParenExpr, e.g.
 *
 * <pre>
 * {@code
 * 1 + (2 - 3)
 * }
 * </pre>
 */
@JsonTypeName("Paren")
public class ParenExpr extends Expr {
    @JsonProperty("expr")
    private NodeRef<Expr> expr;

    public NodeRef<Expr> getExpr() {
        return expr;
    }

    public void setExpr(NodeRef<Expr> expr) {
        this.expr = expr;
    }
}

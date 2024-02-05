package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;
import java.util.List;

/**
 * ListIfItemExpr, e.g.
 *
 * <pre>
 * {@code
 * [1, if True: 2, 3]
 * }
 * </pre>
 */
@JsonTypeName("ListIfItem")
public class ListIfItemExpr extends Expr {
    @JsonProperty("if_cond")
    private NodeRef<Expr> ifCond;

    @JsonProperty("exprs")
    private List<NodeRef<Expr>> exprs;

    @JsonProperty("orelse")
    private NodeRef<Expr> orelse;

    public NodeRef<Expr> getIfCond() {
        return ifCond;
    }

    public void setIfCond(NodeRef<Expr> ifCond) {
        this.ifCond = ifCond;
    }

    public List<NodeRef<Expr>> getExprs() {
        return exprs;
    }

    public void setExprs(List<NodeRef<Expr>> exprs) {
        this.exprs = exprs;
    }

    public NodeRef<Expr> getOrelse() {
        return orelse;
    }

    public void setOrelse(NodeRef<Expr> orelse) {
        this.orelse = orelse;
    }
}

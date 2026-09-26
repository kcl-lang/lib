package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;
import java.util.List;

/**
 * QuantExpr, <op> <variables> in <target> {<test> <if_cond>} e.g.
 *
 * <pre>
 * {@code
 * all x in collection {x > 0}
 * any y in collection {y < 0}
 * map x in collection {x + 1}
 * filter x in collection {x > 1}
 * }
 * </pre>
 */
@JsonTypeName("Quant")
public class QuantExpr extends Expr {
    @JsonProperty("target")
    private NodeRef<Expr> target;

    @JsonProperty("variables")
    private List<NodeRef<Identifier>> variables;

    @JsonProperty("op")
    private QuantOperation op;

    @JsonProperty("test")
    private NodeRef<Expr> test;

    @JsonProperty("if_cond")
    private NodeRef<Expr> ifCond;

    @JsonProperty("ctx")
    private ExprContext ctx;

    public NodeRef<Expr> getTarget() {
        return target;
    }

    public void setTarget(NodeRef<Expr> target) {
        this.target = target;
    }

    public List<NodeRef<Identifier>> getVariables() {
        return variables;
    }

    public void setVariables(List<NodeRef<Identifier>> variables) {
        this.variables = variables;
    }

    public QuantOperation getOp() {
        return op;
    }

    public void setOp(QuantOperation op) {
        this.op = op;
    }

    public NodeRef<Expr> getTest() {
        return test;
    }

    public void setTest(NodeRef<Expr> test) {
        this.test = test;
    }

    public NodeRef<Expr> getIfCond() {
        return ifCond;
    }

    public void setIfCond(NodeRef<Expr> ifCond) {
        this.ifCond = ifCond;
    }

    public ExprContext getCtx() {
        return ctx;
    }

    public void setCtx(ExprContext ctx) {
        this.ctx = ctx;
    }
}

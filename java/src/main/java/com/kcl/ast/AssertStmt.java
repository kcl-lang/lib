package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * AssertStmt represents an assert statement, e.g.
 *
 * <p>
 * <code>assert True if condition, "Assert failed message"</code>
 */
@JsonTypeName("Assert")
public class AssertStmt extends Stmt {
    @JsonProperty("test")
    private NodeRef<Expr> test;

    @JsonProperty("if_cond")
    private NodeRef<Expr> ifCond;

    @JsonProperty("msg")
    private NodeRef<Expr> msg;

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

    public NodeRef<Expr> getMsg() {
        return msg;
    }

    public void setMsg(NodeRef<Expr> msg) {
        this.msg = msg;
    }
}

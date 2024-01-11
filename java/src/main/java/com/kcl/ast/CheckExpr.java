package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// CheckExpr class equivalent in Java
@JsonTypeName("Check")
public class CheckExpr extends Expr {
    @JsonProperty("test")
    private NodeRef<Expr> test;

    @JsonProperty("if_cond")
    private NodeRef<Expr> ifCond; // Nullable to represent Rust's Option

    @JsonProperty("msg")
    private NodeRef<Expr> msg; // Nullable to represent Rust's Option

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

    // Constructor, getters, and setters...
}

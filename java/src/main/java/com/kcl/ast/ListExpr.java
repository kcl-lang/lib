package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// ListExpr class equivalent in Java
@JsonTypeName("List")
public class ListExpr extends Expr {
    @JsonProperty("elts")
    private List<NodeRef<Expr>> elts;

    @JsonProperty("ctx")
    private ExprContext ctx;

	public List<NodeRef<Expr>> getElts() {
		return elts;
	}

	public void setElts(List<NodeRef<Expr>> elts) {
		this.elts = elts;
	}

	public ExprContext getCtx() {
		return ctx;
	}

	public void setCtx(ExprContext ctx) {
		this.ctx = ctx;
	}

    // Constructor, getters, and setters...
}

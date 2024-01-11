package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;

// ExprStmt class equivalent in Java
public class ExprStmt extends Stmt {
    @JsonProperty("exprs")
    private List<NodeRef<Expr>> exprs;

	public List<NodeRef<Expr>> getExprs() {
		return exprs;
	}

	public void setExprs(List<NodeRef<Expr>> exprs) {
		this.exprs = exprs;
	}

    // Constructor, getters, and setters...
}

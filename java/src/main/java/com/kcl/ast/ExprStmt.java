package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * ExprStmt represents a expression statement, e.g.
 * <p>
 * <code>
 * 1
 * </code>
 * </p>
 * <p>
 * <code>
 * """A long string"""
 * </code>
 * </p>
 * <p>
 * <code>
 * 'A string'
 * </code>
 * </p>
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

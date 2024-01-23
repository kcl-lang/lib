package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * StarredExpr, e.g.
 * 
 * <pre>{@code
 *[1, 2, *[3, 4]]
 * }</pre>
 */
@JsonTypeName("Starred")
public class StarredExpr extends Expr {
	@JsonProperty("value")
	private NodeRef<Expr> value;

	@JsonProperty("ctx")
	private ExprContext ctx;

	public NodeRef<Expr> getValue() {
		return value;
	}

	public void setValue(NodeRef<Expr> value) {
		this.value = value;
	}

	public ExprContext getCtx() {
		return ctx;
	}

	public void setCtx(ExprContext ctx) {
		this.ctx = ctx;
	}
}

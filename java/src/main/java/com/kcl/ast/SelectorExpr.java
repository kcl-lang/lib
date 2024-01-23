package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * SelectorExpr, e.g.
 * 
 * <pre>{@code
 *x.y
 *x?.y
 * }</pre>
 */
@JsonTypeName("Selector")
public class SelectorExpr extends Expr {
	@JsonProperty("value")
	private NodeRef<Expr> value;

	@JsonProperty("attr")
	private NodeRef<Identifier> attr;

	@JsonProperty("ctx")
	private ExprContext ctx;

	@JsonProperty("has_question")
	private boolean hasQuestion;

	public NodeRef<Expr> getValue() {
		return value;
	}

	public void setValue(NodeRef<Expr> value) {
		this.value = value;
	}

	public NodeRef<Identifier> getAttr() {
		return attr;
	}

	public void setAttr(NodeRef<Identifier> attr) {
		this.attr = attr;
	}

	public ExprContext getCtx() {
		return ctx;
	}

	public void setCtx(ExprContext ctx) {
		this.ctx = ctx;
	}

	public boolean isHasQuestion() {
		return hasQuestion;
	}

	public void setHasQuestion(boolean hasQuestion) {
		this.hasQuestion = hasQuestion;
	}
}

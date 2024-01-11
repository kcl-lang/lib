package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// Subscript class equivalent in Java
@JsonTypeName("Subscript")
public class Subscript extends Expr {
    @JsonProperty("value")
    private NodeRef<Expr> value;

    @JsonProperty("index")
    private NodeRef<Expr> index; // Nullable to represent Rust's Option

    @JsonProperty("lower")
    private NodeRef<Expr> lower; // Nullable to represent Rust's Option

    @JsonProperty("upper")
    private NodeRef<Expr> upper; // Nullable to represent Rust's Option

    @JsonProperty("step")
    private NodeRef<Expr> step; // Nullable to represent Rust's Option

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

	public NodeRef<Expr> getIndex() {
		return index;
	}

	public void setIndex(NodeRef<Expr> index) {
		this.index = index;
	}

	public NodeRef<Expr> getLower() {
		return lower;
	}

	public void setLower(NodeRef<Expr> lower) {
		this.lower = lower;
	}

	public NodeRef<Expr> getUpper() {
		return upper;
	}

	public void setUpper(NodeRef<Expr> upper) {
		this.upper = upper;
	}

	public NodeRef<Expr> getStep() {
		return step;
	}

	public void setStep(NodeRef<Expr> step) {
		this.step = step;
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

    // Constructor, getters, and setters...
}

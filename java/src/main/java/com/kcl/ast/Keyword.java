package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// Keyword class equivalent in Java
@JsonTypeName("Keyword")
public class Keyword extends Expr {
    @JsonProperty("arg")
    private NodeRef<Identifier> arg;

    @JsonProperty("value")
    private NodeRef<Expr> value; // Nullable to represent Rust's Option

	public NodeRef<Identifier> getArg() {
		return arg;
	}

	public void setArg(NodeRef<Identifier> arg) {
		this.arg = arg;
	}

	public NodeRef<Expr> getValue() {
		return value;
	}

	public void setValue(NodeRef<Expr> value) {
		this.value = value;
	}

    // Constructor, getters, and setters...
}

package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;

// UnificationStmt class equivalent in Java
public class UnificationStmt extends Stmt {
    @JsonProperty("target")
    private NodeRef<Identifier> target;

    public NodeRef<Identifier> getTarget() {
		return target;
	}

	public void setTarget(NodeRef<Identifier> target) {
		this.target = target;
	}

	@JsonProperty("value")
    private NodeRef<SchemaExpr> value;

	public NodeRef<SchemaExpr> getValue() {
		return value;
	}

	public void setValue(NodeRef<SchemaExpr> value) {
		this.value = value;
	}

    // Constructor, getters, and setters...
}

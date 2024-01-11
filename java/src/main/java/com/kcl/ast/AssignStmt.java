package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

// AssignStmt class equivalent in Java
public class AssignStmt extends Stmt {
    @JsonProperty("targets")
    private List<NodeRef<Identifier>> targets;

    @JsonProperty("value")
    private NodeRef<Expr> value;

    @JsonProperty("ty")
    private NodeRef<Type> ty; // This is optional in Rust, so it can be null in Java

	public List<NodeRef<Identifier>> getTargets() {
		return targets;
	}

	public void setTargets(List<NodeRef<Identifier>> targets) {
		this.targets = targets;
	}

	public NodeRef<Expr> getValue() {
		return value;
	}

	public void setValue(NodeRef<Expr> value) {
		this.value = value;
	}

	public NodeRef<Type> getTy() {
		return ty;
	}

	public void setTy(NodeRef<Type> ty) {
		this.ty = ty;
	}

    // Constructor, getters, and setters...
}

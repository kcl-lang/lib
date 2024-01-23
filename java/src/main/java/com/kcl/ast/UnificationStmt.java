package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * UnificationStmt represents a declare statement with the union operator, e.g.
 * <p>
 * <code>data: ASchema {}</code>
 * </p>
 */
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
	private NodeRef<SchemaConfig> value;

	public NodeRef<SchemaConfig> getValue() {
		return value;
	}

	public void setValue(NodeRef<SchemaConfig> value) {
		this.value = value;
	}
}

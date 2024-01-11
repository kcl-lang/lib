package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;

// ConfigEntry class equivalent in Java
public class ConfigEntry {
    @JsonProperty("key")
    private NodeRef<Expr> key; // Nullable to represent Rust's Option

    @JsonProperty("value")
    private NodeRef<Expr> value;

    @JsonProperty("operation")
    private ConfigEntryOperation operation;

    @JsonProperty("insert_index")
    private int insertIndex;

	public NodeRef<Expr> getKey() {
		return key;
	}

	public void setKey(NodeRef<Expr> key) {
		this.key = key;
	}

	public NodeRef<Expr> getValue() {
		return value;
	}

	public void setValue(NodeRef<Expr> value) {
		this.value = value;
	}

	public ConfigEntryOperation getOperation() {
		return operation;
	}

	public void setOperation(ConfigEntryOperation operation) {
		this.operation = operation;
	}

	public int getInsertIndex() {
		return insertIndex;
	}

	public void setInsertIndex(int insertIndex) {
		this.insertIndex = insertIndex;
	}

    // Constructor, getters, and setters...
}

package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;

// SchemaIndexSignature class equivalent in Java
public class SchemaIndexSignature {
    @JsonProperty("key_name")
    private String keyName; // Nullable to represent Rust's Option

    @JsonProperty("value")
    private NodeRef<Expr> value; // Nullable to represent Rust's Option

    @JsonProperty("any_other")
    private boolean anyOther;

    @JsonProperty("key_ty")
    private NodeRef<Type> keyTy;

    @JsonProperty("value_ty")
    private NodeRef<Type> valueTy;

	public String getKeyName() {
		return keyName;
	}

	public void setKeyName(String keyName) {
		this.keyName = keyName;
	}

	public NodeRef<Expr> getValue() {
		return value;
	}

	public void setValue(NodeRef<Expr> value) {
		this.value = value;
	}

	public boolean isAnyOther() {
		return anyOther;
	}

	public void setAnyOther(boolean anyOther) {
		this.anyOther = anyOther;
	}

	public NodeRef<Type> getKeyTy() {
		return keyTy;
	}

	public void setKeyTy(NodeRef<Type> keyTy) {
		this.keyTy = keyTy;
	}

	public NodeRef<Type> getValueTy() {
		return valueTy;
	}

	public void setValueTy(NodeRef<Type> valueTy) {
		this.valueTy = valueTy;
	}

    // Constructor, getters, and setters...
}

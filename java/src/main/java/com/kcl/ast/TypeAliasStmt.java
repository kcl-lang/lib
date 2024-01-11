package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("TypeAlias")
public class TypeAliasStmt extends Stmt {
    @JsonProperty("type_name")
    private NodeRef<Identifier> typeName;

    @JsonProperty("type_value")
    private NodeRef<String> typeValue;

    // Assume Type and Identifier are already defined
    @JsonProperty("ty")
    private NodeRef<Type> ty;

	public NodeRef<Identifier> getTypeName() {
		return typeName;
	}

	public void setTypeName(NodeRef<Identifier> typeName) {
		this.typeName = typeName;
	}

	public NodeRef<String> getTypeValue() {
		return typeValue;
	}

	public void setTypeValue(NodeRef<String> typeValue) {
		this.typeValue = typeValue;
	}

	public NodeRef<Type> getTy() {
		return ty;
	}

	public void setTy(NodeRef<Type> ty) {
		this.ty = ty;
	}

    // Constructor, getters, and setters...
}

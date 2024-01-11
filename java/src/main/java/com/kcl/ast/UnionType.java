package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

import java.util.List;;

// UnionType class equivalent in Java
@JsonTypeName("Union")
public class UnionType extends Type {
    public List<NodeRef<Type>> getTypeElements() {
		return typeElements;
	}

	public void setTypeElements(List<NodeRef<Type>> typeElements) {
		this.typeElements = typeElements;
	}

	private List<NodeRef<Type>> typeElements;

    // Constructor, getters, and setters...
}

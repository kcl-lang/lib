package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

import java.util.List;;

// UnionType class equivalent in Java
@JsonTypeName("Union")
public class UnionType extends Type {
	public static class UnionTypeValue {

		public List<NodeRef<Type>> getTypeElements() {
			return typeElements;
		}

		public void setTypeElements(List<NodeRef<Type>> typeElements) {
			this.typeElements = typeElements;
		}

		private List<NodeRef<Type>> typeElements;
	}

	public UnionTypeValue getValue() {
		return value;
	}

	public void setValue(UnionTypeValue data) {
		this.value = data;
	}

	UnionTypeValue value;
}

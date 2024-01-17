package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

import java.util.Optional;

// ListType class equivalent in Java
@JsonTypeName("List")
public class ListType extends Type {
	public static class ListTypeValue {
		public Optional<NodeRef<Type>> getInnerType() {
			return innerType;
		}

		public void setInnerType(Optional<NodeRef<Type>> innerType) {
			this.innerType = innerType;
		}

		private Optional<NodeRef<Type>> innerType;

	}

	public ListTypeValue getValue() {
		return value;
	}

	public void setValue(ListTypeValue data) {
		this.value = data;
	}

	ListTypeValue value;
}

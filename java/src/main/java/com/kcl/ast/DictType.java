package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

import java.util.Optional;

@JsonTypeName("Dict")
public class DictType extends Type {

	public static class DictTypeValue {
		private Optional<NodeRef<Type>> keyType;
		private Optional<NodeRef<Type>> valueType;

		public Optional<NodeRef<Type>> getKeyType() {
			return keyType;
		}

		public void setKeyType(Optional<NodeRef<Type>> keyType) {
			this.keyType = keyType;
		}

		public Optional<NodeRef<Type>> getValueType() {
			return valueType;
		}

		public void setValueType(Optional<NodeRef<Type>> valueType) {
			this.valueType = valueType;
		}
	}

	DictTypeValue value;

	public DictTypeValue getValue() {
		return value;
	}

	public void setValue(DictTypeValue data) {
		this.value = data;
	}
}

package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

import java.util.Optional;

@JsonTypeName("Int")
public class IntLiteralType extends LiteralTypeValue {
	public static class IntLiteralTypeValue {
		private long value;
		private Optional<NumberBinarySuffix> suffix;

		public long getValue() {
			return value;
		}

		public void setValue(long value) {
			this.value = value;
		}

		public Optional<NumberBinarySuffix> getSuffix() {
			return suffix;
		}

		public void setSuffix(Optional<NumberBinarySuffix> suffix) {
			this.suffix = suffix;
		}
	}

	public IntLiteralTypeValue getValue() {
		return value;
	}

	public void setValue(IntLiteralTypeValue value) {
		this.value = value;
	}

	IntLiteralTypeValue value;

}

package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

import java.util.Optional;

@JsonTypeName("Int")
public class IntLiteralType extends LiteralType {
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

    // Constructor, getters, and setters...
}

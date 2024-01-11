package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

// Subclasses for different NumberLitValue types
@JsonTypeName("Int")
public class IntNumberLitValue extends NumberLitValue {
    private long value;

	public long getValue() {
		return value;
	}

	public void setValue(long value) {
		this.value = value;
	}

    // Constructor, getters, and setters...
}

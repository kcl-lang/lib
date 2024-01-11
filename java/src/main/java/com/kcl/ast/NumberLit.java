package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

import java.util.Optional;

// NumberLit class equivalent in Java
@JsonTypeName("Number")
public class NumberLit extends Literal {
    private Optional<NumberBinarySuffix> binarySuffix;
    private NumberLitValue value;
	public Optional<NumberBinarySuffix> getBinarySuffix() {
		return binarySuffix;
	}
	public void setBinarySuffix(Optional<NumberBinarySuffix> binarySuffix) {
		this.binarySuffix = binarySuffix;
	}
	public NumberLitValue getValue() {
		return value;
	}
	public void setValue(NumberLitValue value) {
		this.value = value;
	}

    // Constructor, getters, and setters...
}

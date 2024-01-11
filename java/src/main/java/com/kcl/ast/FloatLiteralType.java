package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Float")
public class FloatLiteralType extends LiteralType {
    private double value;

	public double getValue() {
		return value;
	}

	public void setValue(double value) {
		this.value = value;
	}

    // Constructor, getters, and setters...
}

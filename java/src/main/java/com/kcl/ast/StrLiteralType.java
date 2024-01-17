package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Str")
public class StrLiteralType extends LiteralTypeValue {
    private String value;

	public String getValue() {
		return value;
	}

	public void setValue(String value) {
		this.value = value;
	}

    // Constructor, getters, and setters...
}

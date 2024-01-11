package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

// StringLit class equivalent in Java
@JsonTypeName("String")
public class StringLit extends Literal {
    private boolean isLongString;
    private String rawValue;
    private String value;

    // Constructor that replicates the TryFrom implementation in Rust
    public StringLit(String value) {
        this.value = value;
        this.rawValue = String.format("%s", value); // Adding quotes, escaping, etc., if needed
        this.isLongString = false; // Determine based on actual logic (e.g., presence of line breaks)
    }

	public boolean isLongString() {
		return isLongString;
	}

	public void setLongString(boolean isLongString) {
		this.isLongString = isLongString;
	}

	public String getRawValue() {
		return rawValue;
	}

	public void setRawValue(String rawValue) {
		this.rawValue = rawValue;
	}

	public String getValue() {
		return value;
	}

	public void setValue(String value) {
		this.value = value;
	}

    // Getters and setters...
}

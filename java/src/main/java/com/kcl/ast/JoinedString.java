package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// JoinedString class equivalent in Java
@JsonTypeName("JoinedString")
public class JoinedString extends Expr {
    @JsonProperty("is_long_string")
    private boolean isLongString;

    @JsonProperty("values")
    private List<NodeRef<Expr>> values;

    @JsonProperty("raw_value")
    private String rawValue;

	public boolean isLongString() {
		return isLongString;
	}

	public void setLongString(boolean isLongString) {
		this.isLongString = isLongString;
	}

	public List<NodeRef<Expr>> getValues() {
		return values;
	}

	public void setValues(List<NodeRef<Expr>> values) {
		this.values = values;
	}

	public String getRawValue() {
		return rawValue;
	}

	public void setRawValue(String rawValue) {
		this.rawValue = rawValue;
	}

    // Constructor, getters, and setters...
}

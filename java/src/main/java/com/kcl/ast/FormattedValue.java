package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// FormattedValue class equivalent in Java
@JsonTypeName("FormattedValue")
public class FormattedValue extends Expr {
    @JsonProperty("is_long_string")
    private boolean isLongString;

    @JsonProperty("value")
    private NodeRef<Expr> value;

    @JsonProperty("format_spec")
    private String formatSpec; // Nullable to represent Rust's Option

	public boolean isLongString() {
		return isLongString;
	}

	public void setLongString(boolean isLongString) {
		this.isLongString = isLongString;
	}

	public NodeRef<Expr> getValue() {
		return value;
	}

	public void setValue(NodeRef<Expr> value) {
		this.value = value;
	}

	public String getFormatSpec() {
		return formatSpec;
	}

	public void setFormatSpec(String formatSpec) {
		this.formatSpec = formatSpec;
	}

    // Constructor, getters, and setters...
}

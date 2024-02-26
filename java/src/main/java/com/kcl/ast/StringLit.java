package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * StringLit, e.g.
 *
 * <pre>
 * {@code
 * "string literal"
 * """long string literal"""
 * }
 * </pre>
 */
@JsonTypeName("String")
public class StringLit extends Expr {
    private boolean isLongString;
    private String rawValue;
    private String value;

    public StringLit() {
        this.value = "";
        this.rawValue = "\"\"";
        this.isLongString = false;
    }

    // Constructor that replicates the TryFrom implementation in Rust
    public StringLit(String value, String rawValue, boolean isLongString) {
        this.value = value;
        this.rawValue = rawValue;
        this.isLongString = isLongString;
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
}

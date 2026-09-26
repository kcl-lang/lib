package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/** FormattedValue, e.g. var1 and var2 in the string interpolation "${var1} abc ${var2}" */
@JsonTypeName("FormattedValue")
public class FormattedValue extends Expr {
    @JsonProperty("is_long_string")
    private boolean isLongString;

    @JsonProperty("value")
    private NodeRef<Expr> value;

    @JsonProperty("format_spec")
    private String formatSpec;

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
}

package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;
import java.util.List;

/** JoinedString, e.g. abc in the string interpolation "${var1} abc ${var2}" */
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
}

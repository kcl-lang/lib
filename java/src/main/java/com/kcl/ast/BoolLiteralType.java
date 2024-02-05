package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Bool")
public class BoolLiteralType extends LiteralTypeValue {
    private boolean value;

    public boolean isValue() {
        return value;
    }

    public void setValue(boolean value) {
        this.value = value;
    }
}

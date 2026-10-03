package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Literal")
public class LiteralType extends Type {
    // Jackson's default field visibility is PUBLIC_ONLY, so a field with no
    // accessor is not a property at all and the `Literal` payload is dropped.
    // Every sibling `Type` variant has the pair; this one did not.
    private LiteralTypeValue value;

    public LiteralTypeValue getValue() {
        return value;
    }

    public void setValue(LiteralTypeValue value) {
        this.value = value;
    }
}

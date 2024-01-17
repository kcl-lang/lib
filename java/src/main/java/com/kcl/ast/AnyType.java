package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

// AnyType class placeholder
@JsonTypeName("Any")
public class AnyType extends Type {
    // Fields and methods specific to AnyType
    public static enum AnyTypeEnum {
        Any
    }

    public AnyTypeEnum getValue() {
        return value;
    }

    public void setValue(AnyTypeEnum data) {
        this.value = data;
    }

    AnyTypeEnum value;
}

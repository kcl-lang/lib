package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * Any type is the builtin any type annotation.
 * 
 * <p>
 * <code>a: any = 1</code>
 * </p>
 */
@JsonTypeName("Any")
public class AnyType extends Type {
    // Fields and methods specific to AnyType
    public static enum AnyTypeEnum {
        Any
    }

    AnyTypeEnum value;

    public AnyTypeEnum getValue() {
        return value;
    }

    public void setValue(AnyTypeEnum data) {
        this.value = data;
    }
}

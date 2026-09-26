package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Basic")
public class BasicType extends Type {
    public static enum BasicTypeEnum {
        Bool, Int, Float, Str
    }

    public BasicTypeEnum getValue() {
        return value;
    }

    public void setValue(BasicTypeEnum data) {
        this.value = data;
    }

    BasicTypeEnum value;
}

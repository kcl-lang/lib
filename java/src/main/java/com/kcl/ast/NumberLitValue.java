package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

// NumberLitValue class equivalent in Java
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.EXTERNAL_PROPERTY, property = "type")
@JsonSubTypes({
    @JsonSubTypes.Type(value = IntNumberLitValue.class, name = "Int"),
    @JsonSubTypes.Type(value = FloatNumberLitValue.class, name = "Float")
})
public abstract class NumberLitValue {
    // Common fields and methods for number literals, if needed
}

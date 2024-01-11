package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

// Base class for all literal types
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({
    @JsonSubTypes.Type(value = NumberLit.class, name = "Number"),
    @JsonSubTypes.Type(value = StringLit.class, name = "String"),
    @JsonSubTypes.Type(value = NameConstantLit.class, name = "NameConstant")
})
public abstract class Literal {
    // Common fields and methods for literals, if needed
}

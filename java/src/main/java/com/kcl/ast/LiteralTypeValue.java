package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

// LiteralType class equivalent in Java
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.EXTERNAL_PROPERTY, property = "type")
@JsonSubTypes({
    @JsonSubTypes.Type(value = BoolLiteralType.class, name = "Bool"),
    @JsonSubTypes.Type(value = IntLiteralType.class, name = "Int"),
    @JsonSubTypes.Type(value = FloatLiteralType.class, name = "Float"),
    @JsonSubTypes.Type(value = StrLiteralType.class, name = "Str")
})
public abstract class LiteralTypeValue {

}

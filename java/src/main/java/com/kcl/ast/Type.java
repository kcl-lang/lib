package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

// Base class for all types
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({
    @JsonSubTypes.Type(value = AnyType.class, name = "Any"),
    @JsonSubTypes.Type(value = NamedType.class, name = "Named"),
    @JsonSubTypes.Type(value = BasicType.class, name = "Basic"),
    @JsonSubTypes.Type(value = ListType.class, name = "List"),
    @JsonSubTypes.Type(value = DictType.class, name = "Dict"),
    @JsonSubTypes.Type(value = UnionType.class, name = "Union"),
    @JsonSubTypes.Type(value = LiteralType.class, name = "Literal"),
    @JsonSubTypes.Type(value = FunctionType.class, name = "Function")
})
public abstract class Type {
    // Common fields and methods for types
}

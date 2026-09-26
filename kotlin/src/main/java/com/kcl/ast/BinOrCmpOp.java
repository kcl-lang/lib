package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

// BinOrCmpOp class equivalent in Java
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({ @JsonSubTypes.Type(value = BinBinOrCmpOp.class, name = "Bin"),
        @JsonSubTypes.Type(value = CmpBinOrCmpOp.class, name = "Cmp") })
public abstract class BinOrCmpOp {
}

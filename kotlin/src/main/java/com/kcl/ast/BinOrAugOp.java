package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({ @JsonSubTypes.Type(value = BinBinOrAugOp.class, name = "Bin"),
        @JsonSubTypes.Type(value = AugBinOrAugOp.class, name = "Aug") })
public abstract class BinOrAugOp {
}

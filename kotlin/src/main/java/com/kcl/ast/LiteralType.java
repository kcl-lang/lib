package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Literal")
public class LiteralType extends Type {
    LiteralTypeValue value;
}

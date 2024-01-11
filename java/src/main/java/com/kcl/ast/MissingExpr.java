package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

// MissingExpr class equivalent in Java
@JsonTypeName("MissingExpr")
public class MissingExpr extends Expr {
    // MissingExpr can be an empty class, used as a placeholder
}

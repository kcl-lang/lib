package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * MissingExpr placeholder for error recovery.
 */
@JsonTypeName("MissingExpr")
public class MissingExpr extends Expr {
    // MissingExpr can be an empty class, used as a placeholder
}

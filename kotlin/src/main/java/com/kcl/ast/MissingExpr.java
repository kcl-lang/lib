package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * MissingExpr placeholder for error recovery.
 *
 * <p>Named for the Rust struct, but the wire tag is the variant name: {@code
 * Expr::Missing(MissingExpr)} in {@code kcl/crates/ast/src/ast.rs}. The
 * explicit {@link com.fasterxml.jackson.annotation.JsonSubTypes.Type} entry
 * on {@link Expr} already said so and takes precedence, so this annotation was
 * only ever a second, contradicting answer to the same question.
 */
@JsonTypeName("Missing")
public class MissingExpr extends Expr {
    // MissingExpr can be an empty class, used as a placeholder
}

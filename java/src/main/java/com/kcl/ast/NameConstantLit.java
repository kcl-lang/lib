package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * NameConstantLit, e.g.
 *
 * <pre>
 * {@code
 * True
 * False
 * None
 * Undefined
 * }
 * </pre>
 *
 * The polymorphic discriminator {@code "NameConstantLit"} is registered on the
 * {@link Expr} base class via {@code @JsonSubTypes}; do NOT add a
 * {@code @JsonTypeName} here or it will conflict.
 */
public class NameConstantLit extends Expr {
    @JsonProperty("value")
    private NameConstant value;

    public NameConstant getValue() {
        return value;
    }

    public void setValue(NameConstant value) {
        this.value = value;
    }
}

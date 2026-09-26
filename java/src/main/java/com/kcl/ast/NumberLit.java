package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.Optional;

/**
 * NumberLit, e.g.
 *
 * <pre>
 * {@code
 * 1
 * 2.0
 * 1m
 * 1K
 * 1Mi
 * }
 * </pre>
 *
 * The polymorphic discriminator {@code "NumberLit"} is registered on the
 * {@link Expr} base class via {@code @JsonSubTypes}; do NOT add a
 * {@code @JsonTypeName} here or it will conflict.
 */
public class NumberLit extends Expr {
    @JsonProperty("binary_suffix")
    private Optional<NumberBinarySuffix> binarySuffix;

    @JsonProperty("value")
    private NumberLitValue value;

    public Optional<NumberBinarySuffix> getBinarySuffix() {
        return binarySuffix;
    }

    public void setBinarySuffix(Optional<NumberBinarySuffix> binarySuffix) {
        this.binarySuffix = binarySuffix;
    }

    public NumberLitValue getValue() {
        return value;
    }

    public void setValue(NumberLitValue value) {
        this.value = value;
    }
}

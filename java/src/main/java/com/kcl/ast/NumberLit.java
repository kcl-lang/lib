package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;
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
 */
@JsonTypeName("Number")
public class NumberLit extends Expr {
    private Optional<NumberBinarySuffix> binarySuffix;
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

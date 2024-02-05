package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * NameConstant, e.g.
 *
 * <pre>
 * {@code
 * True
 * False
 * None
 * Undefined
 * }
 * </pre>
 */
@JsonTypeName("NameConstant")
class NameConstantLit extends Expr {
    private NameConstant value;

    public NameConstant getValue() {
        return value;
    }

    public void setValue(NameConstant value) {
        this.value = value;
    }
}

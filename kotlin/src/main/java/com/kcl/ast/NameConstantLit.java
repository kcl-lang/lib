package com.kcl.ast;

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
class NameConstantLit extends Expr {
    private NameConstant value;

    public NameConstant getValue() {
        return value;
    }

    public void setValue(NameConstant value) {
        this.value = value;
    }
}

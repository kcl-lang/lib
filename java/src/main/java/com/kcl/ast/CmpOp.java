package com.kcl.ast;

// CmpOp enum equivalent in Java
public enum CmpOp {
    Eq("=="),
    NotEq("!="),
    Lt("<"),
    LtE("<="),
    Gt(">"),
    GtE(">="),
    Is("is"),
    In("in"),
    NotIn("not in"),
    Not("not"),
    IsNot("is not");

    private final String symbol;

    CmpOp(String symbol) {
        this.symbol = symbol;
    }

    public String symbol() {
        return symbol;
    }
}

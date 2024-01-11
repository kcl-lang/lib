package com.kcl.ast;

// UnaryOp enum equivalent in Java
public enum UnaryOp {
    UAdd("+"),
    USub("-"),
    Invert("~"),
    Not("not");

    private final String symbol;

    UnaryOp(String symbol) {
        this.symbol = symbol;
    }

    public String symbol() {
        return symbol;
    }
}

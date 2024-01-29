package com.kcl.ast;

public enum UnaryOp {
    UAdd("+"), USub("-"), Invert("~"), Not("not");

    private final String symbol;

    UnaryOp(String symbol) {
        this.symbol = symbol;
    }

    public String symbol() {
        return symbol;
    }
}

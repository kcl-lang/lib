package com.kcl.ast;

public enum BinOp {
    Add("+"),
    Sub("-"),
    Mul("*"),
    Div("/"),
    Mod("%"),
    Pow("**"),
    FloorDiv("//"),
    LShift("<<"),
    RShift(">>"),
    BitXor("^"),
    BitAnd("&"),
    BitOr("|"),
    And("and"),
    Or("or"),
    As("as");

    private final String symbol;

    BinOp(String symbol) {
        this.symbol = symbol;
    }

    public String symbol() {
        return symbol;
    }
}

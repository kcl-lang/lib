package com.kcl.ast;

// AugOp enum equivalent in Java
public enum AugOp {
    Assign("="),
    Add("+="),
    Sub("-="),
    Mul("*="),
    Div("/="),
    Mod("%="),
    Pow("**="),
    FloorDiv("//="),
    LShift("<<="),
    RShift(">>="),
    BitXor("^="),
    BitAnd("&="),
    BitOr("|=");

    private final String symbol;

    AugOp(String symbol) {
        this.symbol = symbol;
    }

    public String symbol() {
        return symbol;
    }
    
    // Method to convert AugOp to BinOp, if possible
    public BinOp toBinOp() throws IllegalArgumentException {
        switch (this) {
            case Add:
                return BinOp.Add;
            case Sub:
                return BinOp.Sub;
            case Mul:
                return BinOp.Mul;
            case Div:
                return BinOp.Div;
            case Mod:
                return BinOp.Mod;
            case Pow:
                return BinOp.Pow;
            case FloorDiv:
                return BinOp.FloorDiv;
            case LShift:
                return BinOp.LShift;
            case RShift:
                return BinOp.RShift;
            case BitXor:
                return BinOp.BitXor;
            case BitAnd:
                return BinOp.BitAnd;
            case BitOr:
                return BinOp.BitOr;
            default:
                throw new IllegalArgumentException("AugOp cannot be converted to BinOp");
        }
    }
}

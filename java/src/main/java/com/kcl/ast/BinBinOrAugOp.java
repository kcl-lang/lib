package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Bin")
public class BinBinOrAugOp extends BinOrAugOp {
    private BinOp op;

    public BinOp getOp() {
        return op;
    }

    public void setOp(BinOp op) {
        this.op = op;
    }
}

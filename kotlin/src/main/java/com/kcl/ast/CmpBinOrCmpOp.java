package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Cmp")
public class CmpBinOrCmpOp extends BinOrCmpOp {
    private CmpOp op;

    public CmpOp getOp() {
        return op;
    }

    public void setOp(CmpOp op) {
        this.op = op;
    }
}

package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Aug")
public class AugBinOrAugOp extends BinOrAugOp {
    public AugOp getOp() {
        return op;
    }

    public void setOp(AugOp op) {
        this.op = op;
    }

    private AugOp op;
}

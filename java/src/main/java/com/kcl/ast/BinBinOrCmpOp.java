package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Bin")
public class BinBinOrCmpOp extends BinOrCmpOp {
	private BinOp op;

	public BinOp getOp() {
		return op;
	}

	public void setOp(BinOp op) {
		this.op = op;
	}

}
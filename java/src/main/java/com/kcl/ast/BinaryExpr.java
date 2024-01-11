package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// BinaryExpr class
@JsonTypeName("Binary")
public class BinaryExpr extends Expr {
    @JsonProperty("left")
    private NodeRef<Expr> left;

    @JsonProperty("op")
    private BinOrCmpOp op;

    @JsonProperty("right")
    private NodeRef<Expr> right;

	public NodeRef<Expr> getLeft() {
		return left;
	}

	public void setLeft(NodeRef<Expr> left) {
		this.left = left;
	}

	public BinOrCmpOp getOp() {
		return op;
	}

	public void setOp(BinOrCmpOp op) {
		this.op = op;
	}

	public NodeRef<Expr> getRight() {
		return right;
	}

	public void setRight(NodeRef<Expr> right) {
		this.right = right;
	}

    // ... Constructor, getters, setters ...
}

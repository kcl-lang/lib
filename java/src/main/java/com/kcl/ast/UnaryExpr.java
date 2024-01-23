package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * UnaryExpr, e.g.
 * 
 * <pre>{@code
 *+1
 *-2
 *~3
 *not True
 * }</pre>
 */
@JsonTypeName("Unary")
public class UnaryExpr extends Expr {
	@JsonProperty("op")
	private UnaryOp op;

	public UnaryOp getOp() {
		return op;
	}

	public void setOp(UnaryOp op) {
		this.op = op;
	}

	@JsonProperty("operand")
	private NodeRef<Expr> operand;

	public NodeRef<Expr> getOperand() {
		return operand;
	}

	public void setOperand(NodeRef<Expr> operand) {
		this.operand = operand;
	}
}

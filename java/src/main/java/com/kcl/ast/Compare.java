package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * Compare, e.g.
 * 
 * <pre>{@code
0 < a < 10
b is not None
c != d
 * }</pre>
 */
@JsonTypeName("Compare")
public class Compare extends Expr {
	@JsonProperty("left")
	private NodeRef<Expr> left;

	@JsonProperty("ops")
	private List<CmpOp> ops;

	@JsonProperty("comparators")
	private List<NodeRef<Expr>> comparators;

	public NodeRef<Expr> getLeft() {
		return left;
	}

	public void setLeft(NodeRef<Expr> left) {
		this.left = left;
	}

	public List<CmpOp> getOps() {
		return ops;
	}

	public void setOps(List<CmpOp> ops) {
		this.ops = ops;
	}

	public List<NodeRef<Expr>> getComparators() {
		return comparators;
	}

	public void setComparators(List<NodeRef<Expr>> comparators) {
		this.comparators = comparators;
	}

}

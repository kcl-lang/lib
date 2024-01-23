package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * ConfigIfEntryExpr, e.g.
 * 
 * <pre>{@code
i, a in [1, 2, 3] if i > 1 and a > 1
 * }</pre>
 */
public class CompClause {
	@JsonProperty("targets")
	private List<NodeRef<Identifier>> targets;

	@JsonProperty("iter")
	private NodeRef<Expr> iter;

	@JsonProperty("ifs")
	private List<NodeRef<Expr>> ifs;

	public List<NodeRef<Identifier>> getTargets() {
		return targets;
	}

	public void setTargets(List<NodeRef<Identifier>> targets) {
		this.targets = targets;
	}

	public NodeRef<Expr> getIter() {
		return iter;
	}

	public void setIter(NodeRef<Expr> iter) {
		this.iter = iter;
	}

	public List<NodeRef<Expr>> getIfs() {
		return ifs;
	}

	public void setIfs(List<NodeRef<Expr>> ifs) {
		this.ifs = ifs;
	}
}

package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;

// CompClause class equivalent in Java
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

    // Constructor, getters, and setters...
}

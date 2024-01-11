package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// ListComp class equivalent in Java
@JsonTypeName("ListComp")
public class ListComp extends Expr {
    @JsonProperty("elt")
    private NodeRef<Expr> elt;

    @JsonProperty("generators")
    private List<NodeRef<CompClause>> generators;

	public NodeRef<Expr> getElt() {
		return elt;
	}

	public void setElt(NodeRef<Expr> elt) {
		this.elt = elt;
	}

	public List<NodeRef<CompClause>> getGenerators() {
		return generators;
	}

	public void setGenerators(List<NodeRef<CompClause>> generators) {
		this.generators = generators;
	}

    // Constructor, getters, and setters...
}

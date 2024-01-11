package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// IfStmt class equivalent in Java
@JsonTypeName("If")
public class IfStmt extends Stmt {
    @JsonProperty("body")
    private List<NodeRef<Stmt>> body;

    @JsonProperty("cond")
    private NodeRef<Expr> cond;

    @JsonProperty("orelse")
    private List<NodeRef<Stmt>> orelse;

	public List<NodeRef<Stmt>> getBody() {
		return body;
	}

	public void setBody(List<NodeRef<Stmt>> body) {
		this.body = body;
	}

	public NodeRef<Expr> getCond() {
		return cond;
	}

	public void setCond(NodeRef<Expr> cond) {
		this.cond = cond;
	}

	public List<NodeRef<Stmt>> getOrelse() {
		return orelse;
	}

	public void setOrelse(List<NodeRef<Stmt>> orelse) {
		this.orelse = orelse;
	}

    // Constructor, getters, and setters...
}

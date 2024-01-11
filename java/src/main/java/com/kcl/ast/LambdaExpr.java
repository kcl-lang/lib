package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// LambdaExpr class equivalent in Java
@JsonTypeName("Lambda")
public class LambdaExpr extends Expr {
    @JsonProperty("args")
    private NodeRef<Arguments> args; // Nullable to represent Rust's Option

    @JsonProperty("body")
    private List<NodeRef<Stmt>> body;

    @JsonProperty("return_ty")
    private NodeRef<Type> returnTy; // Nullable to represent Rust's Option

	public NodeRef<Arguments> getArgs() {
		return args;
	}

	public void setArgs(NodeRef<Arguments> args) {
		this.args = args;
	}

	public List<NodeRef<Stmt>> getBody() {
		return body;
	}

	public void setBody(List<NodeRef<Stmt>> body) {
		this.body = body;
	}

	public NodeRef<Type> getReturnTy() {
		return returnTy;
	}

	public void setReturnTy(NodeRef<Type> returnTy) {
		this.returnTy = returnTy;
	}

    // Constructor, getters, and setters...
}

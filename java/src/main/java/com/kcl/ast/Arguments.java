package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * Arguments, e.g.
 * 
 * <pre>{@code
lambda x: int = 1, y: int = 1 {
    x + y
}
 * }</pre>
 */
public class Arguments {
	@JsonProperty("args")
	private List<NodeRef<Identifier>> args;

	@JsonProperty("defaults")
	private List<NodeRef<Expr>> defaults; // List can contain nulls to represent Rust's Vec<Option<NodeRef<Expr>>>

	@JsonProperty("ty_list")
	private List<NodeRef<Type>> tyList; // List can contain nulls to represent Rust's Vec<Option<NodeRef<Type>>>

	public List<NodeRef<Identifier>> getArgs() {
		return args;
	}

	public void setArgs(List<NodeRef<Identifier>> args) {
		this.args = args;
	}

	public List<NodeRef<Expr>> getDefaults() {
		return defaults;
	}

	public void setDefaults(List<NodeRef<Expr>> defaults) {
		this.defaults = defaults;
	}

	public List<NodeRef<Type>> getTyList() {
		return tyList;
	}

	public void setTyList(List<NodeRef<Type>> tyList) {
		this.tyList = tyList;
	}
}

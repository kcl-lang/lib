package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * ConfigIfEntryExpr, e.g.
 * 
 * <pre>{@code
{
    k1 = 1
    if condition:
        k2 = 2
}
 * }</pre>
 */
@JsonTypeName("ConfigIfEntry")
public class ConfigIfEntryExpr extends Expr {
	@JsonProperty("if_cond")
	private NodeRef<Expr> ifCond;

	@JsonProperty("items")
	private List<NodeRef<ConfigEntry>> items;

	@JsonProperty("orelse")
	private NodeRef<Expr> orelse;

	public NodeRef<Expr> getIfCond() {
		return ifCond;
	}

	public void setIfCond(NodeRef<Expr> ifCond) {
		this.ifCond = ifCond;
	}

	public List<NodeRef<ConfigEntry>> getItems() {
		return items;
	}

	public void setItems(List<NodeRef<ConfigEntry>> items) {
		this.items = items;
	}

	public NodeRef<Expr> getOrelse() {
		return orelse;
	}

	public void setOrelse(NodeRef<Expr> orelse) {
		this.orelse = orelse;
	}
}

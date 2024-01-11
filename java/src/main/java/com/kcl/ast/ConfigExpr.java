package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// ConfigExpr class equivalent in Java
@JsonTypeName("Config")
public class ConfigExpr extends Expr {
    @JsonProperty("items")
    private List<NodeRef<ConfigEntry>> items;

	public List<NodeRef<ConfigEntry>> getItems() {
		return items;
	}

	public void setItems(List<NodeRef<ConfigEntry>> items) {
		this.items = items;
	}

    // Constructor, getters, and setters...
}

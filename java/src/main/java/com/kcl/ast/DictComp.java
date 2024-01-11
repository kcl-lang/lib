package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// DictComp class equivalent in Java
@JsonTypeName("DictComp")
public class DictComp extends Expr {
    @JsonProperty("entry")
    private ConfigEntry entry;

    @JsonProperty("generators")
    private List<NodeRef<CompClause>> generators;

	public ConfigEntry getEntry() {
		return entry;
	}

	public void setEntry(ConfigEntry entry) {
		this.entry = entry;
	}

	public List<NodeRef<CompClause>> getGenerators() {
		return generators;
	}

	public void setGenerators(List<NodeRef<CompClause>> generators) {
		this.generators = generators;
	}

    // Constructor, getters, and setters...
}

package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

// NamedType class placeholder
@JsonTypeName("Named")
public class NamedType extends Type {
    private Identifier identifier;

	public Identifier getIdentifier() {
		return identifier;
	}

	public void setIdentifier(Identifier identifier) {
		this.identifier = identifier;
	}

    // Constructor, getters, and setters...
}

package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

// NameConstantLit class, assuming it's already defined
@JsonTypeName("NameConstant")
class NameConstantLit extends Expr {
    private NameConstant value;

	public NameConstant getValue() {
		return value;
	}

	public void setValue(NameConstant value) {
		this.value = value;
	}
}

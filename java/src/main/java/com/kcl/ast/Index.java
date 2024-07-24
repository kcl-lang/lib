package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Index")
public class Index extends MemberOrIndex {
    @JsonProperty("value")
    private NodeRef<Expr> value;

    public NodeRef<Expr> getValue() {
        return value;
    }

    public void setValue(NodeRef<Expr> value) {
        this.value = value;
    }

    public Index(NodeRef<Expr> index) {
        this.value = index;
    }

    public Index() {
    }
}

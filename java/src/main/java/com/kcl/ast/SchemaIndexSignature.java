package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * SchemaIndexSignature, e.g.
 *
 * <pre>
 * {@code
 * schema SchemaIndexSignatureExample:
 *    [str]: int
 * }
 * </pre>
 */
public class SchemaIndexSignature {
    @JsonProperty("key_name")
    private NodeRef<String> keyName;

    @JsonProperty("value")
    private NodeRef<Expr> value;

    @JsonProperty("any_other")
    private boolean anyOther;

    @JsonProperty("key_ty")
    private NodeRef<Type> keyTy;

    @JsonProperty("value_ty")
    private NodeRef<Type> valueTy;

    public NodeRef<String> getKeyName() {
        return keyName;
    }

    public void setKeyName(NodeRef<String> keyName) {
        this.keyName = keyName;
    }

    public NodeRef<Expr> getValue() {
        return value;
    }

    public void setValue(NodeRef<Expr> value) {
        this.value = value;
    }

    public boolean isAnyOther() {
        return anyOther;
    }

    public void setAnyOther(boolean anyOther) {
        this.anyOther = anyOther;
    }

    public NodeRef<Type> getKeyTy() {
        return keyTy;
    }

    public void setKeyTy(NodeRef<Type> keyTy) {
        this.keyTy = keyTy;
    }

    public NodeRef<Type> getValueTy() {
        return valueTy;
    }

    public void setValueTy(NodeRef<Type> valueTy) {
        this.valueTy = valueTy;
    }
}

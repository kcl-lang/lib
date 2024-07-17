package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * ConfigExpr, e.g.
 *
 * <pre>
 * {@code
 * {
 * attr1 = 1
 * attr2 += [0, 1]
 * attr3: {key = value}
 * }
 * }
 * </pre>
 */
public class ConfigEntry {
    @JsonProperty("key")
    private NodeRef<Expr> key;

    @JsonProperty("value")
    private NodeRef<Expr> value;

    @JsonProperty("operation")
    private ConfigEntryOperation operation;

    public NodeRef<Expr> getKey() {
        return key;
    }

    public void setKey(NodeRef<Expr> key) {
        this.key = key;
    }

    public NodeRef<Expr> getValue() {
        return value;
    }

    public void setValue(NodeRef<Expr> value) {
        this.value = value;
    }

    public ConfigEntryOperation getOperation() {
        return operation;
    }

    public void setOperation(ConfigEntryOperation operation) {
        this.operation = operation;
    }
}

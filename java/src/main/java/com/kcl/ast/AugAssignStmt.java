package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * AugAssignStmt represents an argument assignment, e.g.
 *
 * <p>
 * <code>a += 1</code>
 *
 * <p>
 * <code>a -= 1</code>
 */
@JsonTypeName("AugAssign")
public class AugAssignStmt extends Stmt {
    @JsonProperty("target")
    private NodeRef<Identifier> target;

    @JsonProperty("value")
    private NodeRef<Expr> value;

    @JsonProperty("op")
    private AugOp op;

    public NodeRef<Identifier> getTarget() {
        return target;
    }

    public void setTarget(NodeRef<Identifier> target) {
        this.target = target;
    }

    public NodeRef<Expr> getValue() {
        return value;
    }

    public void setValue(NodeRef<Expr> value) {
        this.value = value;
    }

    public AugOp getOp() {
        return op;
    }

    public void setOp(AugOp op) {
        this.op = op;
    }
}

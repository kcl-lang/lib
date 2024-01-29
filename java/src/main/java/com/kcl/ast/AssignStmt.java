package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * AssignStmt represents an assignment, e.g.
 *
 * <p>
 * <code>a: int = 1</code>
 *
 * <p>
 * <code>a = 1</code>
 *
 * <p>
 * <code>a = b = 1</code>
 */
public class AssignStmt extends Stmt {
    @JsonProperty("targets")
    private List<NodeRef<Identifier>> targets;

    @JsonProperty("value")
    private NodeRef<Expr> value;

    @JsonProperty("ty")
    private NodeRef<Type> ty;

    public List<NodeRef<Identifier>> getTargets() {
        return targets;
    }

    public void setTargets(List<NodeRef<Identifier>> targets) {
        this.targets = targets;
    }

    public NodeRef<Expr> getValue() {
        return value;
    }

    public void setValue(NodeRef<Expr> value) {
        this.value = value;
    }

    public NodeRef<Type> getTy() {
        return ty;
    }

    public void setTy(NodeRef<Type> ty) {
        this.ty = ty;
    }
}

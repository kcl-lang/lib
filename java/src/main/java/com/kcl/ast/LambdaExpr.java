package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;
import java.util.List;

/**
 * LambdaExpr, e.g.
 *
 * <pre>
 * {@code
 * lambda x, y {
 * z = 2 * x
 * z + y
 * }
 * }
 * </pre>
 */
@JsonTypeName("Lambda")
public class LambdaExpr extends Expr {
    @JsonProperty("args")
    private NodeRef<Arguments> args;

    @JsonProperty("body")
    private List<NodeRef<Stmt>> body;

    @JsonProperty("return_ty")
    private NodeRef<Type> returnTy;

    public NodeRef<Arguments> getArgs() {
        return args;
    }

    public void setArgs(NodeRef<Arguments> args) {
        this.args = args;
    }

    public List<NodeRef<Stmt>> getBody() {
        return body;
    }

    public void setBody(List<NodeRef<Stmt>> body) {
        this.body = body;
    }

    public NodeRef<Type> getReturnTy() {
        return returnTy;
    }

    public void setReturnTy(NodeRef<Type> returnTy) {
        this.returnTy = returnTy;
    }
}

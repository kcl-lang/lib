package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * SchemaConfig, e.g.
 *
 * <pre>
 * {@code
 * ASchema(arguments) {
 * attr1 = 1
 * attr2 = BSchema {attr3 = 2}
 * }
 * }
 * </pre>
 */
public class SchemaConfig {
    @JsonProperty("name")
    private NodeRef<Identifier> name;

    @JsonProperty("args")
    private List<NodeRef<Expr>> args;

    @JsonProperty("kwargs")
    private List<NodeRef<Keyword>> kwargs;

    @JsonProperty("config")
    private NodeRef<Expr> config;

    public NodeRef<Identifier> getName() {
        return name;
    }

    public void setName(NodeRef<Identifier> name) {
        this.name = name;
    }

    public List<NodeRef<Expr>> getArgs() {
        return args;
    }

    public void setArgs(List<NodeRef<Expr>> args) {
        this.args = args;
    }

    public List<NodeRef<Keyword>> getKwargs() {
        return kwargs;
    }

    public void setKwargs(List<NodeRef<Keyword>> kwargs) {
        this.kwargs = kwargs;
    }

    public NodeRef<Expr> getConfig() {
        return config;
    }

    public void setConfig(NodeRef<Expr> config) {
        this.config = config;
    }
}

package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;
import java.util.List;

/**
 * DictComp, e.g.
 *
 * <pre>
 * {@code
 * {k: v + 1 for k, v in {k1 = 1, k2 = 2}}
 * }
 * </pre>
 */
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
}

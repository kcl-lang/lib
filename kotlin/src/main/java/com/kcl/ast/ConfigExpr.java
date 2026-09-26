package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;
import java.util.List;

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
@JsonTypeName("Config")
public class ConfigExpr extends Expr {
    @JsonProperty("items")
    private List<NodeRef<ConfigEntry>> items;

    public List<NodeRef<ConfigEntry>> getItems() {
        return items;
    }

    public void setItems(List<NodeRef<ConfigEntry>> items) {
        this.items = items;
    }
}

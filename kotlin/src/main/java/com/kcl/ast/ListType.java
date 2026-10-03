package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;
import java.util.Optional;

@JsonTypeName("List")
public class ListType extends Type {
    public static class ListTypeValue {
        public Optional<NodeRef<Type>> getInnerType() {
            return innerType;
        }

        public void setInnerType(Optional<NodeRef<Type>> innerType) {
            this.innerType = innerType;
        }

        @JsonProperty("inner_type")
        private Optional<NodeRef<Type>> innerType;
    }

    public ListTypeValue getValue() {
        return value;
    }

    public void setValue(ListTypeValue data) {
        this.value = data;
    }

    ListTypeValue value;
}

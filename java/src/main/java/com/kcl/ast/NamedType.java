package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Named")
public class NamedType extends Type {
    public static class NamedTypeValue {
        private Identifier identifier;

        public Identifier getIdentifier() {
            return identifier;
        }

        public void setIdentifier(Identifier identifier) {
            this.identifier = identifier;
        }
    }

    NamedTypeValue value;

    public NamedTypeValue getValue() {
        return value;
    }

    public void setValue(NamedTypeValue data) {
        this.value = data;
    }
}

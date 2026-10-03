package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Named")
public class NamedType extends Type {
    /**
     * Rust declares {@code Named(Identifier)} — a newtype variant of the
     * adjacently tagged {@code Type} enum, so serde puts the {@code Identifier}
     * struct's own fields straight under {@code value} and there is no
     * {@code identifier} key to wrap them in. Extending {@code Identifier} is
     * what makes the inherited accessors bind those fields.
     */
    public static class NamedTypeValue extends Identifier {
    }

    NamedTypeValue value;

    public NamedTypeValue getValue() {
        return value;
    }

    public void setValue(NamedTypeValue data) {
        this.value = data;
    }
}

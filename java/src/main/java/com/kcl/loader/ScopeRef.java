package com.kcl.loader;

import java.io.Serializable;

// Equivalent to Rust's SerializableSymbolRef struct
public class ScopeRef implements Serializable {
    private long i;
    private long g;
    private ScopeKind kind;

    public ScopeRef(long i, long g, ScopeKind kind) {
        this.i = i;
        this.g = g;
        this.kind = kind;
    }

    // Getters and setters for i, g, and kind
    public long getI() {
        return i;
    }

    public void setI(long i) {
        this.i = i;
    }

    public long getG() {
        return g;
    }

    public void setG(long g) {
        this.g = g;
    }

    public ScopeKind getKind() {
        return kind;
    }

    public void setKind(ScopeKind kind) {
        this.kind = kind;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + (int) (i ^ (i >>> 32));
        result = prime * result + (int) (g ^ (g >>> 32));
        result = prime * result + ((kind == null) ? 0 : kind.hashCode());
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        ScopeRef other = (ScopeRef) obj;
        if (i != other.i)
            return false;
        if (g != other.g)
            return false;
        if (kind != other.kind)
            return false;
        return true;
    }
}

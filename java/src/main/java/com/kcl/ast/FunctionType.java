package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;
import java.util.List;
import java.util.Optional;

// FunctionType class equivalent in Java
@JsonTypeName("Function")
public class FunctionType extends Type {
    public static class FunctionTypeValue {
        public Optional<List<NodeRef<Type>>> getParamsTy() {
            return paramsTy;
        }

        public void setParamsTy(Optional<List<NodeRef<Type>>> paramsTy) {
            this.paramsTy = paramsTy;
        }

        private Optional<List<NodeRef<Type>>> paramsTy;

        public Optional<NodeRef<Type>> getRetTy() {
            return retTy;
        }

        public void setRetTy(Optional<NodeRef<Type>> retTy) {
            this.retTy = retTy;
        }

        private Optional<NodeRef<Type>> retTy;
    }

    FunctionTypeValue value;

    public FunctionTypeValue getValue() {
        return value;
    }

    public void setValue(FunctionTypeValue value) {
        this.value = value;
    }
}

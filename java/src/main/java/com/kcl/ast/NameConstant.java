package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * NameConstant, e.g.
 * 
 * <pre>{@code
True
False
None
Undefined
 * }</pre>
 */
@JsonTypeName("NameConstant")
public enum NameConstant {
    True, False, None, Undefined;

    // Method to return the symbol for each constant
    public String symbol() {
        switch (this) {
            case True:
                return "True";
            case False:
                return "False";
            case None:
                return "None";
            case Undefined:
                return "Undefined";
            default:
                throw new IllegalArgumentException("Unknown NameConstant: " + this);
        }
    }

    // Method to return the JSON value for each constant
    public String jsonValue() {
        switch (this) {
            case True:
                return "true";
            case False:
                return "false";
            case None:
            case Undefined:
                return "null";
            default:
                throw new IllegalArgumentException("Unknown NameConstant: " + this);
        }
    }
}

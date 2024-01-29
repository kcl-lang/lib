package com.kcl.ast;

public enum ConfigEntryOperation {
    Union, Override, Insert;

    public int value() {
        switch (this) {
        case Union:
            return 0;
        case Override:
            return 1;
        case Insert:
            return 2;
        default:
            throw new IllegalStateException("Unknown operation: " + this);
        }
    }

    public String symbol() {
        switch (this) {
        case Union:
            return ":";
        case Override:
            return "=";
        case Insert:
            return "+=";
        default:
            throw new IllegalStateException("Unknown operation: " + this);
        }
    }
}

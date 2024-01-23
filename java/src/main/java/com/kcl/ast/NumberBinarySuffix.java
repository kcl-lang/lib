package com.kcl.ast;

public enum NumberBinarySuffix {
    n, u, m, k, K, M, G, T, P, Ki, Mi, Gi, Ti, Pi;

    // Method to convert suffix to string
    public String value() {
        return this.name();
    }

    // Method to get all names of NumberBinarySuffix
    public static String[] allNames() {
        return new String[] { "n", "u", "m", "k", "K", "M", "G", "T", "P", "Ki", "Mi", "Gi", "Ti", "Pi", "i" };
    }
}

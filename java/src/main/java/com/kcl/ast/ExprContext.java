package com.kcl.ast;

/**
 * ExprContext denotes the value context in the expression. e.g.,
 * 
 * <p>
 * The context of {@code a} in {@code a = b} is {@code Store}
 * </p>
 * <p>
 * The context of {@code b} in {@code a = b} is {@code Load}
 * </p>
 */
public enum ExprContext {
    Load, Store
}

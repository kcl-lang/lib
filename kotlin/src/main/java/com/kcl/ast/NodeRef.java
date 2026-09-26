package com.kcl.ast;

/**
 * NodeRef is the file, line and column number information that all AST nodes need to contain. In fact, column and
 * end_column are the counts of character, For example, `\t` is counted as 1 character, so it is recorded as 1 here, but
 * generally col is 4.
 */
public class NodeRef<T> extends Node<T> {

    public NodeRef() {
    }

    public NodeRef(String id, T node, String filename, long line, long column, long endLine, long endColumn) {
        super(id, node, filename, line, column, endLine, endColumn);
    }
}

package com.kcl.ast;

public class NodeRef<T> extends Node<T> {

    public NodeRef() {}

	public NodeRef(AstIndex id, T node, String filename, long line, long column, long endLine, long endColumn) {
		super(id, node, filename, line, column, endLine, endColumn);
	}
    
}

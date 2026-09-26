package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;

/**
 * Node is the file, line and column number information that all AST nodes need to contain. In fact, column and
 * end_column are the counts of character, For example, `\t` is counted as 1 character, so it is recorded as 1 here, but
 * generally col is 4.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
@JsonSerialize
@JsonDeserialize
public class Node<T> {
    @JsonProperty("id")
    private String id;

    @JsonProperty("node")
    private T node;

    @JsonProperty("filename")
    private String filename;

    @JsonProperty("line")
    private long line;

    @JsonProperty("column")
    private long column;

    @JsonProperty("end_line")
    private long endLine;

    @JsonProperty("end_column")
    private long endColumn;

    public long getEndColumn() {
        return endColumn;
    }

    public void setEndColumn(long endColumn) {
        this.endColumn = endColumn;
    }

    public Node() {
    }

    public Node(String id, T node, String filename, long line, long column, long endLine, long endColumn) {
        this.id = id;
        this.node = node;
        this.filename = filename;
        this.line = line;
        this.column = column;
        this.endLine = endLine;
        this.endColumn = endColumn;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public T getNode() {
        return node;
    }

    public void setNode(T node) {
        this.node = node;
    }

    public String getFilename() {
        return filename;
    }

    public void setFilename(String filename) {
        this.filename = filename;
    }

    public long getLine() {
        return line;
    }

    public void setLine(long line) {
        this.line = line;
    }

    public long getColumn() {
        return column;
    }

    public void setColumn(long column) {
        this.column = column;
    }

    public long getEndLine() {
        return endLine;
    }

    public void setEndLine(long endLine) {
        this.endLine = endLine;
    }

    // Getters and setters...
}

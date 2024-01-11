package com.kcl.ast;

import java.util.ArrayList;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;

// Java equivalent of the Module struct in Rust
public class Module {
    @JsonProperty("filename")
    private String filename;
    @JsonProperty("pkg")
    private String pkg;
    @JsonProperty("doc")
    private NodeRef<String> doc;
    @JsonProperty("name")
    private String name;
    @JsonProperty("body")
    private List<NodeRef<Stmt>> body;
    @JsonProperty("comments")
    private List<NodeRef<Comment>> comments;

    public Module() {
        body = new ArrayList<>();
        comments = new ArrayList<>();
    }

    // Implement the methods from the Rust Module impl
    public List<SchemaStmt> filterSchemaStmtFromModule() {
        List<SchemaStmt> stmts = new ArrayList<>();
        for (NodeRef<Stmt> stmt : body) {
            if (stmt.getNode() instanceof SchemaStmt) {
                Stmt node = stmt.getNode();
                SchemaStmt schemaStmt = (SchemaStmt)node;
                stmts.add(schemaStmt);
            }
        }
        return stmts;
    }
}

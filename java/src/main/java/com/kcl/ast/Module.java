package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.ArrayList;
import java.util.List;

/** Module is an abstract syntax tree for a single KCL file. */
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
                SchemaStmt schemaStmt = (SchemaStmt) node;
                stmts.add(schemaStmt);
            }
        }
        return stmts;
    }

    public String getFilename() {
        return filename;
    }

    public void setFilename(String filename) {
        this.filename = filename;
    }

    public String getPkg() {
        return pkg;
    }

    public void setPkg(String pkg) {
        this.pkg = pkg;
    }

    public NodeRef<String> getDoc() {
        return doc;
    }

    public void setDoc(NodeRef<String> doc) {
        this.doc = doc;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public List<NodeRef<Stmt>> getBody() {
        return body;
    }

    public void setBody(List<NodeRef<Stmt>> body) {
        this.body = body;
    }

    public List<NodeRef<Comment>> getComments() {
        return comments;
    }

    public void setComments(List<NodeRef<Comment>> comments) {
        this.comments = comments;
    }
}

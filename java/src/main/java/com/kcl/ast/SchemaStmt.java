package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

import java.util.List;

// SchemaStmt class equivalent in Java
@JsonTypeName("Schema")
public class SchemaStmt extends Stmt {
    @JsonProperty("doc")
    private NodeRef<String> doc;

    @JsonProperty("name")
    private NodeRef<String> name;

    @JsonProperty("parent_name")
    private NodeRef<Identifier> parentName;

    @JsonProperty("for_host_name")
    private NodeRef<Identifier> forHostName;

    @JsonProperty("is_mixin")
    private boolean isMixin;

    @JsonProperty("is_protocol")
    private boolean isProtocol;

    @JsonProperty("args")
    private NodeRef<Arguments> args;

    @JsonProperty("mixins")
    private List<NodeRef<Identifier>> mixins;

    @JsonProperty("body")
    private List<NodeRef<Stmt>> body;

    @JsonProperty("decorators")
    private List<NodeRef<CallExpr>> decorators;

    @JsonProperty("checks")
    private List<NodeRef<CheckExpr>> checks;

    @JsonProperty("index_signature")
    private NodeRef<SchemaIndexSignature> indexSignature;

	public NodeRef<String> getDoc() {
		return doc;
	}

	public void setDoc(NodeRef<String> doc) {
		this.doc = doc;
	}

	public NodeRef<String> getName() {
		return name;
	}

	public void setName(NodeRef<String> name) {
		this.name = name;
	}

	public NodeRef<Identifier> getParentName() {
		return parentName;
	}

	public void setParentName(NodeRef<Identifier> parentName) {
		this.parentName = parentName;
	}

	public NodeRef<Identifier> getForHostName() {
		return forHostName;
	}

	public void setForHostName(NodeRef<Identifier> forHostName) {
		this.forHostName = forHostName;
	}

	public boolean isMixin() {
		return isMixin;
	}

	public void setMixin(boolean isMixin) {
		this.isMixin = isMixin;
	}

	public boolean isProtocol() {
		return isProtocol;
	}

	public void setProtocol(boolean isProtocol) {
		this.isProtocol = isProtocol;
	}

	public NodeRef<Arguments> getArgs() {
		return args;
	}

	public void setArgs(NodeRef<Arguments> args) {
		this.args = args;
	}

	public List<NodeRef<Identifier>> getMixins() {
		return mixins;
	}

	public void setMixins(List<NodeRef<Identifier>> mixins) {
		this.mixins = mixins;
	}

	public List<NodeRef<Stmt>> getBody() {
		return body;
	}

	public void setBody(List<NodeRef<Stmt>> body) {
		this.body = body;
	}

	public List<NodeRef<CallExpr>> getDecorators() {
		return decorators;
	}

	public void setDecorators(List<NodeRef<CallExpr>> decorators) {
		this.decorators = decorators;
	}

	public List<NodeRef<CheckExpr>> getChecks() {
		return checks;
	}

	public void setChecks(List<NodeRef<CheckExpr>> checks) {
		this.checks = checks;
	}

	public NodeRef<SchemaIndexSignature> getIndexSignature() {
		return indexSignature;
	}

	public void setIndexSignature(NodeRef<SchemaIndexSignature> indexSignature) {
		this.indexSignature = indexSignature;
	}

    // Constructor, getters, and setters...
}

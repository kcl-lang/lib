package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// RuleStmt class equivalent in Java
@JsonTypeName("Rule")
public class RuleStmt extends Stmt {
    @JsonProperty("doc")
    private NodeRef<String> doc; // Nullable to represent Rust's Option

    @JsonProperty("name")
    private NodeRef<String> name;

    @JsonProperty("parent_rules")
    private List<NodeRef<Identifier>> parentRules;

    @JsonProperty("decorators")
    private List<NodeRef<CallExpr>> decorators;

    @JsonProperty("checks")
    private List<NodeRef<CheckExpr>> checks;

    @JsonProperty("args")
    private NodeRef<Arguments> args; // Nullable to represent Rust's Option

    @JsonProperty("for_host_name")
    private NodeRef<Identifier> forHostName; // Nullable to represent Rust's Option

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

	public List<NodeRef<Identifier>> getParentRules() {
		return parentRules;
	}

	public void setParentRules(List<NodeRef<Identifier>> parentRules) {
		this.parentRules = parentRules;
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

	public NodeRef<Arguments> getArgs() {
		return args;
	}

	public void setArgs(NodeRef<Arguments> args) {
		this.args = args;
	}

	public NodeRef<Identifier> getForHostName() {
		return forHostName;
	}

	public void setForHostName(NodeRef<Identifier> forHostName) {
		this.forHostName = forHostName;
	}

    // Constructor, getters, and setters...
}

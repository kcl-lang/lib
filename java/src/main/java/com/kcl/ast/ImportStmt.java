package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * ImportStmt, e.g.
 * <p>
 * {@code import pkg as pkg_alias}
 * </p>
 */
@JsonTypeName("Import")
public class ImportStmt extends Stmt {
	@JsonProperty("path")
	private NodeRef<String> path;

	@JsonProperty("rawpath")
	private String rawpath;

	@JsonProperty("name")
	private String name;

	@JsonProperty("asname")
	private NodeRef<String> asname;

	@JsonProperty("pkg_name")
	private String pkgName;

	public NodeRef<String> getPath() {
		return path;
	}

	public void setPath(NodeRef<String> path) {
		this.path = path;
	}

	public String getRawpath() {
		return rawpath;
	}

	public void setRawpath(String rawpath) {
		this.rawpath = rawpath;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public NodeRef<String> getAsname() {
		return asname;
	}

	public void setAsname(NodeRef<String> asname) {
		this.asname = asname;
	}

	public String getPkgName() {
		return pkgName;
	}

	public void setPkgName(String pkgName) {
		this.pkgName = pkgName;
	}
}

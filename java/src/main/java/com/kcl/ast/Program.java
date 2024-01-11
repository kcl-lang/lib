package com.kcl.ast;

import java.util.HashMap;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

// Program class equivalent to the Program struct in Rust
@JsonIgnoreProperties(ignoreUnknown = true)
@JsonTypeName("Program")
public class Program {

    @JsonProperty("root")
    private String root;

    @JsonProperty("pkgs")
    private HashMap<String, List<Module>> pkgs;

    public Program() {
        pkgs = new HashMap<>();
    }

    // Getters and setters...

	public String getRoot() {
		return root;
	}

	public void setRoot(String root) {
		this.root = root;
	}

	public HashMap<String, List<Module>> getPkgs() {
		return pkgs;
	}

	public void setPkgs(HashMap<String, List<Module>> pkgs) {
		this.pkgs = pkgs;
	}

    // Other methods and logic...
}

package com.kcl.ast;

import java.util.HashMap;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * The `ast` file contains the definitions of all KCL AST nodes
 * and operators and all AST nodes are derived from the `AST` class.
 * The main structure of a KCL program is as follows:
 * 
 * ┌─────────────────────────────────────────────────────────────────┐
 * │ Program │
 * │ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
 * │ │ Main Package │ │ Package1 │ │ Package2 │ │
 * │ │ ┌───────────┐ │ │ ┌───────────┐ │ │ ┌───────────┐ │ │
 * │ │ │ Module1 │ │ │ │ Module1 │ │ │ │ Module1 │ │ │
 * │ │ └───────────┘ │ │ └───────────┘ │ │ └───────────┘ │ │
 * │ │ ┌───────────┐ │ │ ┌───────────┐ │ │ ┌───────────┐ │ │
 * │ │ │ Module2 │ │ │ │ Module2 │ │ │ │ Module2 │ │ │
 * │ │ └───────────┘ │ │ └───────────┘ │ │ └───────────┘ │ │
 * │ │ ┌───────────┐ │ │ ┌───────────┐ │ │ ┌───────────┐ │ │
 * │ │ │ ... │ │ │ │ ... │ │ │ │ ... │ │ │
 * │ │ └───────────┘ │ │ └───────────┘ │ │ └───────────┘ │ │
 * │ └─────────────────┘ └─────────────────┘ └─────────────────┘ │
 * └─────────────────────────────────────────────────────────────────┘
 *
 * <p>
 * A single KCL file represents a module, which records file information,
 * package path information, and module document information, which is
 * mainly composed of all the statements in the KCL file.
 * </p>
 *
 * <p>
 * The combination of multiple KCL files is regarded as a complete KCL
 * Program. For example, a single KCL file can be imported into KCL
 * files in other packages through statements such as import. Therefore,
 * the Program is composed of multiple modules, and each module is
 * associated with it. Corresponding to the package path.
 * </p>
 */
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

	public List<Module> getMainPackage() {
		return pkgs.get("__main__");
	}

	public Module getFirstModule() {
		List<Module> modules = getMainPackage();
		if (modules == null) {
			return null;
		}
		return modules.get(0);
	}

	// Other methods and logic...
}

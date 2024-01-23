package com.kcl.ast;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * Schema attribute definitions
 * 
 * <pre>{@code
 *schema SchemaAttrExample:
 *    x: int
 *    y: str}</pre>
 */
@JsonTypeName("SchemaAttr")
public class SchemaAttr extends Stmt {
	@JsonProperty("doc")
	private String doc;

	@JsonProperty("name")
	private NodeRef<String> name;

	@JsonProperty("op")
	private AugOp op;

	@JsonProperty("value")
	private NodeRef<Expr> value;

	@JsonProperty("is_optional")
	private boolean isOptional;

	@JsonProperty("decorators")
	private List<NodeRef<CallExpr>> decorators;

	@JsonProperty("ty")
	private NodeRef<Type> ty;

	public String getDoc() {
		return doc;
	}

	public void setDoc(String doc) {
		this.doc = doc;
	}

	public NodeRef<String> getName() {
		return name;
	}

	public void setName(NodeRef<String> name) {
		this.name = name;
	}

	public AugOp getOp() {
		return op;
	}

	public void setOp(AugOp op) {
		this.op = op;
	}

	public NodeRef<Expr> getValue() {
		return value;
	}

	public void setValue(NodeRef<Expr> value) {
		this.value = value;
	}

	public boolean isOptional() {
		return isOptional;
	}

	public void setOptional(boolean isOptional) {
		this.isOptional = isOptional;
	}

	public List<NodeRef<CallExpr>> getDecorators() {
		return decorators;
	}

	public void setDecorators(List<NodeRef<CallExpr>> decorators) {
		this.decorators = decorators;
	}

	public NodeRef<Type> getTy() {
		return ty;
	}

	public void setTy(NodeRef<Type> ty) {
		this.ty = ty;
	}
}

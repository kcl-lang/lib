package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.annotation.JsonSubTypes;

@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({
        @JsonSubTypes.Type(value = TypeAliasStmt.class, name = "TypeAlias"),
        @JsonSubTypes.Type(value = ExprStmt.class, name = "Expr"),
        @JsonSubTypes.Type(value = UnificationStmt.class, name = "Unification"),
        @JsonSubTypes.Type(value = AssignStmt.class, name = "Assign"),
        @JsonSubTypes.Type(value = AugAssignStmt.class, name = "AugAssign"),
        @JsonSubTypes.Type(value = AssertStmt.class, name = "Assert"),
        @JsonSubTypes.Type(value = IfStmt.class, name = "If"),
        @JsonSubTypes.Type(value = ImportStmt.class, name = "Import"),
        @JsonSubTypes.Type(value = SchemaAttr.class, name = "SchemaAttr"),
        @JsonSubTypes.Type(value = SchemaStmt.class, name = "Schema"),
        @JsonSubTypes.Type(value = RuleStmt.class, name = "Rule"),
})
public abstract class Stmt {
}

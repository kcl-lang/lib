package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

// The base class for all expression types
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({ @JsonSubTypes.Type(value = TargetExpr.class, name = "Target"),
        @JsonSubTypes.Type(value = IdentifierExpr.class, name = "Identifier"),
        @JsonSubTypes.Type(value = UnaryExpr.class, name = "Unary"),
        @JsonSubTypes.Type(value = BinaryExpr.class, name = "Binary"),
        @JsonSubTypes.Type(value = IfExpr.class, name = "If"),
        @JsonSubTypes.Type(value = SelectorExpr.class, name = "Selector"),
        @JsonSubTypes.Type(value = CallExpr.class, name = "Call"),
        @JsonSubTypes.Type(value = ParenExpr.class, name = "Paren"),
        @JsonSubTypes.Type(value = QuantExpr.class, name = "Quant"),
        @JsonSubTypes.Type(value = ListExpr.class, name = "List"),
        @JsonSubTypes.Type(value = ListIfItemExpr.class, name = "ListIfItem"),
        @JsonSubTypes.Type(value = ListComp.class, name = "ListComp"),
        @JsonSubTypes.Type(value = StarredExpr.class, name = "Starred"),
        @JsonSubTypes.Type(value = DictComp.class, name = "DictComp"),
        @JsonSubTypes.Type(value = ConfigIfEntryExpr.class, name = "ConfigIfEntry"),
        @JsonSubTypes.Type(value = CompClause.class, name = "CompClause"),
        @JsonSubTypes.Type(value = SchemaExpr.class, name = "Schema"),
        @JsonSubTypes.Type(value = ConfigExpr.class, name = "Config"),
        @JsonSubTypes.Type(value = LambdaExpr.class, name = "Lambda"),
        @JsonSubTypes.Type(value = Subscript.class, name = "Subscript"),
        @JsonSubTypes.Type(value = Compare.class, name = "Compare"),
        @JsonSubTypes.Type(value = NumberLit.class, name = "NumberLit"),
        @JsonSubTypes.Type(value = StringLit.class, name = "StringLit"),
        @JsonSubTypes.Type(value = NameConstantLit.class, name = "NameConstantLit"),
        @JsonSubTypes.Type(value = JoinedString.class, name = "JoinedString"),
        @JsonSubTypes.Type(value = FormattedValue.class, name = "FormattedValue"),
        @JsonSubTypes.Type(value = MissingExpr.class, name = "Missing"), })
public abstract class Expr {
}

package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

/**
 * Base class for member or index expression
 *
 * <pre>
 * {@code
 * a.<member>
 * b[<index>]
 * }
 * </pre>
 */
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({ @JsonSubTypes.Type(value = Member.class, name = "Member"),
        @JsonSubTypes.Type(value = Index.class, name = "Index") })
public abstract class MemberOrIndex {
}

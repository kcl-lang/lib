package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

/**
 * Comment, e.g.
 *
 * <pre>
 * {@code
 * # This is a comment
 * }
 * </pre>
 */
@JsonTypeName("Comment")
public class Comment {
    @JsonProperty("text")
    private String text;

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }
}

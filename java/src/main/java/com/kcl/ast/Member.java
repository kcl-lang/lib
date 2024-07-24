package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName("Member")
public class Member extends MemberOrIndex {
    @JsonProperty("value")
    private NodeRef<String> value;

    public Member(NodeRef<String> member) {
        this.value = member;
    }

    public Member() {
    }

    public NodeRef<String> getValue() {
        return value;
    }

    public void setValue(NodeRef<String> member) {
        this.value = member;
    }
}

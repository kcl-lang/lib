package com.kcl.util;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
import com.kcl.ast.Program;
import java.io.IOException;

public class JsonUtil {
    public static Program deserializeProgram(String jsonString) throws IOException {
        // The AST models Rust's `Option<T>` as `java.util.Optional`, which
        // Jackson can only construct with the Jdk8 module registered.
        ObjectMapper objectMapper = new ObjectMapper().registerModule(new Jdk8Module());
        objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

        return objectMapper.readValue(jsonString, Program.class);
    }
}
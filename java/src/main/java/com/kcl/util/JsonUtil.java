package com.kcl.util;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
import com.kcl.ast.Program;
import com.kcl.loader.ScopeRef;
import com.kcl.loader.SymbolRef;
import java.io.IOException;

public class JsonUtil {
    // The AST models Rust's `Option<T>` as `java.util.Optional`, which Jackson
    // can only construct once the Jdk8 module is registered. Without it the
    // deserialiser raises `InvalidDefinitionException` on the first optional
    // field it meets rather than leaving it empty, so this is not optional
    // plumbing — every mapper that touches an AST type needs it.
    private static ObjectMapper newMapper() {
        return new ObjectMapper().registerModule(new Jdk8Module())
                .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
    }

    public static Program deserializeProgram(String jsonString) throws IOException {
        return newMapper().readValue(jsonString, Program.class);
    }

    public static SymbolRef deserializeSymbolRef(String jsonString) throws IOException {
        return newMapper().readValue(jsonString, SymbolRef.class);
    }

    public static ScopeRef deserializeScopeRef(String jsonString) throws IOException {
        return newMapper().readValue(jsonString, ScopeRef.class);
    }
}

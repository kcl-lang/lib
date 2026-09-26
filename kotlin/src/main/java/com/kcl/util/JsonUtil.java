package com.kcl.util;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kcl.ast.Program;
import java.io.IOException;

public class JsonUtil {
    public static Program deserializeProgram(String jsonString) throws IOException {
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

        return objectMapper.readValue(jsonString, Program.class);
    }
}
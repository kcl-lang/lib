package com.kcl;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import com.fasterxml.jackson.dataformat.yaml.YAMLMapper;
import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;

/**
 * Shared Jackson mappers for the facade. {@link ObjectMapper} instances are thread-safe after configuration, so a
 * single instance of each is kept.
 */
final class KclMappers {
    // The AST models Rust's `Option<T>` as `java.util.Optional`, so the Jdk8
    // module has to be registered before any AST type is read.
    private static final ObjectMapper JSON = new ObjectMapper().registerModule(new Jdk8Module());
    private static final YAMLMapper YAML = withJdk8(new YAMLMapper(new YAMLFactory()));

    private KclMappers() {
    }

    /**
     * {@code ObjectMapper.registerModule} is declared to return {@code ObjectMapper}, so chaining it off a
     * {@code YAMLMapper} widens the type and no longer assigns to a {@code YAMLMapper} field. The call registers in
     * place and returns the same instance; this says so in a way the compiler can still type as {@code YAMLMapper}.
     */
    private static YAMLMapper withJdk8(YAMLMapper mapper) {
        mapper.registerModule(new Jdk8Module());
        return mapper;
    }

    static ObjectMapper json() {
        return JSON;
    }

    static YAMLMapper yaml() {
        return YAML;
    }
}

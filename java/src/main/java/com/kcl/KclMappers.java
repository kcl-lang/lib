package com.kcl;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import com.fasterxml.jackson.dataformat.yaml.YAMLMapper;

/**
 * Shared Jackson mappers for the facade. {@link ObjectMapper} instances are
 * thread-safe after configuration, so a single instance of each is kept.
 */
final class KclMappers {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final YAMLMapper YAML = new YAMLMapper(new YAMLFactory());

    private KclMappers() {
    }

    static ObjectMapper json() {
        return JSON;
    }

    static YAMLMapper yaml() {
        return YAML;
    }
}

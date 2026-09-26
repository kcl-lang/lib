package com.kcl;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.fasterxml.jackson.core.JsonProcessingException;

/**
 * Structured view of one configuration document produced by a KCL run. The
 * parsed value (a {@code Map}, {@code List} or scalar decoded from the
 * runtime JSON stream) plus the raw YAML document the runtime emitted for it.
 */
public final class KCLResult {
    private final Object result;
    private final String yamlDocument;

    KCLResult(Object result, String yamlDocument) {
        this.result = result;
        this.yamlDocument = yamlDocument;
    }

    /**
     * The raw decoded value of this document: a {@code Map<String, Object>},
     * {@code List<Object>} or scalar ({@code String}, {@code Number},
     * {@code Boolean}), or {@code null}.
     */
    public Object getValue() {
        return result;
    }

    /**
     * Look up {@code key} in the parsed value: dotted keys navigate nested
     * maps and numeric segments index into lists. Returns {@code null} when
     * the key is absent.
     */
    public Object get(String key) {
        Object value = result;
        for (String part : key.split("\\.")) {
            if (value instanceof Map) {
                value = ((Map<?, ?>) value).get(part);
            } else if (value instanceof List && isIndex(part)) {
                List<?> list = (List<?>) value;
                int index = Integer.parseInt(part);
                value = index >= 0 && index < list.size() ? list.get(index) : null;
            } else {
                return null;
            }
            if (value == null) {
                return null;
            }
        }
        return value;
    }

    /**
     * Typed variant of {@link #get(String)}: the value at {@code key}
     * converted to {@code target} (numeric widening allowed, everything else
     * strict). Empty when the key is absent.
     *
     * @throws KclException
     *             when the value exists but cannot be represented as
     *             {@code target}
     */
    public <T> Optional<T> get(String key, Class<T> target) {
        Object value = get(key);
        if (value == null) {
            return Optional.empty();
        }
        return Optional.of(convert(key, value, target));
    }

    /** The value at {@code key} as a string; empty when absent. */
    public Optional<String> getString(String key) {
        return get(key, String.class);
    }

    /** The value at {@code key} as an integer; empty when absent. */
    public Optional<Integer> getInt(String key) {
        return get(key, Integer.class);
    }

    /** The value at {@code key} as a double; empty when absent. */
    public Optional<Double> getDouble(String key) {
        return get(key, Double.class);
    }

    /** The value at {@code key} as a boolean; empty when absent. */
    public Optional<Boolean> getBoolean(String key) {
        return get(key, Boolean.class);
    }

    /** The whole document as a string, when it is one. */
    public Optional<String> asString() {
        return as(String.class);
    }

    /** The whole document as an integer, when it is numeric. */
    public Optional<Integer> asInt() {
        return as(Integer.class);
    }

    /** The whole document as a double, when it is numeric. */
    public Optional<Double> asDouble() {
        return as(Double.class);
    }

    /** The whole document as a boolean, when it is one. */
    public Optional<Boolean> asBoolean() {
        return as(Boolean.class);
    }

    /**
     * The whole document as a map.
     *
     * @throws KclException
     *             when the document is not a map
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> toMap() {
        if (!(result instanceof Map)) {
            throw new KclException("failed to convert result to map: type mismatch, got "
                    + (result == null ? "null" : result.getClass().getSimpleName()));
        }
        return (Map<String, Object>) result;
    }

    /**
     * The whole document as a list.
     *
     * @throws KclException
     *             when the document is not a list
     */
    @SuppressWarnings("unchecked")
    public List<Object> toList() {
        if (!(result instanceof List)) {
            throw new KclException("failed to convert result to list: type mismatch, got "
                    + (result == null ? "null" : result.getClass().getSimpleName()));
        }
        return (List<Object>) result;
    }

    /**
     * The raw YAML document emitted by the runtime for this result (one
     * slice of the multi-document {@code yaml_result}), or {@code ""} when
     * unavailable.
     */
    public String yamlString() {
        return yamlDocument == null ? "" : yamlDocument;
    }

    /** The document re-encoded as JSON. */
    public String jsonString() {
        try {
            return KclMappers.json().writerWithDefaultPrettyPrinter().writeValueAsString(result);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("failed to encode KCL result as JSON", e);
        }
    }

    private <T> Optional<T> as(Class<T> target) {
        if (result == null) {
            return Optional.empty();
        }
        return Optional.of(convert("<result>", result, target));
    }

    private static boolean isIndex(String part) {
        if (part.isEmpty() || part.length() > 9) {
            return false;
        }
        for (int i = 0; i < part.length(); i++) {
            if (!Character.isDigit(part.charAt(i))) {
                return false;
            }
        }
        return true;
    }

    private static <T> T convert(String key, Object value, Class<T> target) {
        if (target.isInstance(value)) {
            return target.cast(value);
        }
        if (target == Integer.class && value instanceof Number) {
            // numeric widening, mirroring kcl-go GetValue float64-to-*int
            return target.cast(Integer.valueOf(((Number) value).intValue()));
        }
        if (target == Double.class && value instanceof Number) {
            return target.cast(Double.valueOf(((Number) value).doubleValue()));
        }
        throw new KclException("failed to convert " + key + " to " + target.getSimpleName()
                + ": type mismatch, got " + (value == null ? "null" : value.getClass().getSimpleName()));
    }
}

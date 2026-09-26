package com.kcl;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.fasterxml.jackson.databind.JsonNode;
import com.kcl.api.Spec.Argument;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.ExecProgramArgs.Builder;
import com.kcl.api.Spec.ExternalPkg;

/**
 * Parsed {@code kcl.yaml} settings file, mirroring kcl-go's
 * {@code settings.SettingsFile}: a {@code kcl_cli_configs} mapping plus a
 * {@code kcl_options} list of {@code {key, value}} entries. YAML parsing is
 * done with Jackson (jackson-dataformat-yaml), preserving mapping order so
 * {@code kcl_options} values round-trip like kcl-go's order-aware encoding.
 *
 * <p>
 * Supported {@code kcl_cli_configs} fields: {@code file}/{@code files},
 * {@code overrides}, {@code path_selector}, {@code strict_range_check},
 * {@code disable_none}, {@code verbose}, {@code debug}, {@code package_maps},
 * {@code sort_keys}, {@code show_hidden} and {@code include_schema_type_path}.
 * The {@code output} field is not supported because the underlying
 * {@code ExecProgramArgs} proto has no output format field.
 */
final class KclSettingsFile {
    private final JsonNode config;
    private final List<Argument> options;

    private KclSettingsFile(JsonNode config, List<Argument> options) {
        this.config = config;
        this.options = options;
    }

    /**
     * Load and parse a settings file. Missing or unparsable files raise
     * {@link KclException}, mirroring kcl-go's {@code WithSettings} error
     * propagation; empty files yield an empty config.
     */
    static KclSettingsFile load(String filename) {
        Path path = Paths.get(filename);
        String text;
        try {
            text = new String(Files.readAllBytes(path), java.nio.charset.StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new KclException("kcl.WithSettings(" + filename + "): " + e.getMessage(), e);
        }
        if (text.trim().isEmpty()) {
            return new KclSettingsFile(null, new ArrayList<Argument>());
        }
        final JsonNode root;
        try {
            root = KclMappers.yaml().readTree(text);
        } catch (IOException e) {
            throw new KclException("kcl.WithSettings(" + filename + "): " + e.getMessage(), e);
        }
        if (root == null || !root.isObject()) {
            return new KclSettingsFile(null, new ArrayList<Argument>());
        }
        JsonNode configNode = root.get("kcl_cli_configs");
        JsonNode optionsNode = root.get("kcl_options");
        List<Argument> options = new ArrayList<Argument>();
        if (optionsNode != null && optionsNode.isArray()) {
            for (JsonNode entry : optionsNode) {
                if (entry == null || !entry.isObject()) {
                    continue;
                }
                JsonNode key = entry.get("key");
                if (key == null || !key.isTextual()) {
                    continue;
                }
                options.add(Argument.newBuilder().setName(key.asText()).setValue(stringifyValue(entry.get("value")))
                        .build());
            }
        }
        return new KclSettingsFile(configNode != null && configNode.isObject() ? configNode : null, options);
    }

    /**
     * Populate a proto builder from this file, mirroring kcl-go's
     * {@code SettingsFile.To_ExecProgramArgs}. Relative input files are
     * resolved against {@code workDir} with {@code ${PWD}} and
     * {@code ${KCL_MOD}} expansion.
     */
    void applyTo(Builder builder, String workDir) {
        if (config == null) {
            return;
        }
        addStrings(builder, "file", config, workDir);
        addStrings(builder, "files", config, workDir);
        JsonNode overrides = config.get("overrides");
        if (overrides != null && overrides.isArray()) {
            for (JsonNode item : overrides) {
                if (item != null && item.isTextual() && !item.asText().isEmpty()) {
                    builder.addOverrides(item.asText());
                }
            }
        }
        JsonNode selectors = config.get("path_selector");
        if (selectors != null && selectors.isArray()) {
            for (JsonNode item : selectors) {
                if (item != null && item.isTextual() && !item.asText().isEmpty()) {
                    builder.addPathSelector(item.asText());
                }
            }
        }
        if (config.path("strict_range_check").asBoolean(false)) {
            builder.setStrictRangeCheck(true);
        }
        if (config.path("disable_none").asBoolean(false)) {
            builder.setDisableNone(true);
        }
        int verbose = config.path("verbose").asInt(0);
        if (verbose > 0) {
            builder.setVerbose(verbose);
        }
        if (config.path("debug").asBoolean(false)) {
            builder.setDebug(1);
        }
        if (config.path("sort_keys").asBoolean(false)) {
            builder.setSortKeys(true);
        }
        if (config.path("show_hidden").asBoolean(false)) {
            builder.setShowHidden(true);
        }
        if (config.path("include_schema_type_path").asBoolean(false)) {
            builder.setIncludeSchemaTypePath(true);
        }
        JsonNode packageMaps = config.get("package_maps");
        if (packageMaps != null && packageMaps.isObject()) {
            for (Map.Entry<String, JsonNode> entry : iterable(packageMaps.fields())) {
                if (entry.getValue() != null && entry.getValue().isTextual()) {
                    builder.addExternalPkgs(ExternalPkg.newBuilder().setPkgName(entry.getKey())
                            .setPkgPath(entry.getValue().asText()).build());
                }
            }
        }
        builder.addAllArgs(options);
    }

    private static void addStrings(Builder builder, String field, JsonNode config, String workDir) {
        JsonNode node = config.get(field);
        if (node == null) {
            return;
        }
        List<String> values = new ArrayList<String>();
        if (node.isTextual()) {
            values.add(node.asText());
        } else if (node.isArray()) {
            for (JsonNode item : node) {
                if (item != null && item.isTextual()) {
                    values.add(item.asText());
                }
            }
        }
        for (String value : values) {
            if (value == null || value.isEmpty()) {
                continue;
            }
            builder.addKFilenameList(resolveInputFile(value, workDir));
        }
    }

    private static String resolveInputFile(String s, String workDir) {
        String pkgRoot = findPkgRoot(workDir);
        if (s.contains("${PWD}")) {
            s = s.replace("${PWD}", workDir);
        }
        if (s.contains("${KCL_MOD}") && !pkgRoot.isEmpty()) {
            s = s.replace("${KCL_MOD}", pkgRoot);
        }
        if (s.startsWith(".") || (!s.startsWith("${") && !Paths.get(s).isAbsolute())) {
            return Paths.get(workDir).resolve(s).normalize().toString();
        }
        return s;
    }

    /**
     * Walk up from {@code workDir} looking for a {@code kcl.mod} file,
     * mirroring kcl-go's {@code tools/list.FindPkgInfo}. Returns the package
     * root or an empty string when no {@code kcl.mod} is found.
     */
    private static String findPkgRoot(String workDir) {
        Path dir = Paths.get(workDir == null || workDir.isEmpty() ? "." : workDir).toAbsolutePath().normalize();
        while (dir != null) {
            if (Files.exists(dir.resolve("kcl.mod"))) {
                return dir.toString();
            }
            dir = dir.getParent();
        }
        return "";
    }

    /**
     * Serialise a {@code kcl_options} value like kcl-go: map/list values
     * become JSON (preserving document order), scalars become their plain
     * string form, and {@code null} becomes the empty string.
     */
    private static String stringifyValue(JsonNode value) {
        if (value == null || value.isNull()) {
            return "";
        }
        if (value.isObject() || value.isArray()) {
            return value.toString();
        }
        if (value.isTextual()) {
            return value.asText();
        }
        return value.asText();
    }

    private static <T> List<T> iterable(java.util.Iterator<T> iterator) {
        List<T> list = new ArrayList<T>();
        while (iterator.hasNext()) {
            list.add(iterator.next());
        }
        return list;
    }
}

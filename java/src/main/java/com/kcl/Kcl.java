package com.kcl;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Map;

import com.fasterxml.jackson.databind.MappingIterator;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kcl.api.API;
import com.kcl.api.Spec.Argument;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.ExecProgramResult;
import com.kcl.api.Spec.ExternalPkg;

/**
 * High-level entry points for evaluating KCL, modelled on the capabilities
 * of kcl-go's {@code pkg/kcl} with a JVM-first shape:
 * {@link #run(String, KclOption[])} evaluates in-memory source,
 * {@link #runFiles(List, KclOption[])} evaluates files, and failures always
 * raise {@link KclException} (unchecked) rather than returning error values.
 *
 * <p>
 * Options are built with the static {@code with*} factories and merged with
 * kcl-go's {@code Option.Merge} semantics; see {@link KclOption} for details.
 *
 * <p>
 * Example:
 *
 * <pre>
 * {@code
 * KCLResultList result = Kcl.run("a = 1\nb = {c = 2}", Kcl.withSortKeys(true));
 * Optional<Integer> c = result.first().getInt("b.c");
 *
 * KCLResultList files = Kcl.runFiles(Arrays.asList("main.k"),
 *         Kcl.withWorkDir("."), Kcl.withOverrides("name=\"bob\""));
 * }
 * </pre>
 */
public final class Kcl {
    private Kcl() {
    }

    // ------------------------------------------------------------------
    // Entry points
    // ------------------------------------------------------------------

    /**
     * Evaluate the in-memory KCL source {@code code} with optional
     * {@code options}. Equivalent to kcl-go's {@code Run} combined with
     * {@code WithCode}.
     *
     * @throws KclException
     *             when no input is given, the settings file is invalid, or the
     *             run fails (transport error or non-empty
     *             {@code err_message})
     */
    public static KCLResultList run(String code, KclOption... options) {
        KclOptionBag bag = newBag(options);
        bag.kCodeList.add(code);
        return exec(bag);
    }

    /**
     * Evaluate the KCL file {@code path}. Convenience single-file variant of
     * {@link #runFiles(List, KclOption[])}.
     */
    public static KCLResultList runFiles(String path, KclOption... options) {
        return runFiles(Collections.singletonList(path), options);
    }

    /**
     * Evaluate the KCL files {@code paths} with optional {@code options}.
     * Equivalent to kcl-go's {@code RunFiles}.
     *
     * @throws KclException
     *             when no input is given, the settings file is invalid, or the
     *             run fails
     */
    public static KCLResultList runFiles(List<String> paths, KclOption... options) {
        KclOptionBag bag = newBag(options);
        bag.kFilenameList.addAll(paths);
        return exec(bag);
    }

    /**
     * Evaluate with only {@code options} (no seeded input); specify files or
     * code through {@link #withKFilenames(String[])} /
     * {@link #withCode(String[])} or a settings file. Equivalent to kcl-go's
     * {@code RunWithOpts}.
     *
     * @throws KclException
     *             when no input is given, the settings file is invalid, or the
     *             run fails
     */
    public static KCLResultList runWithOpts(KclOption... options) {
        return exec(newBag(options));
    }

    // ------------------------------------------------------------------
    // Option factories
    // ------------------------------------------------------------------

    /** Append in-memory KCL source codes to the program (kcl-go {@code WithCode}). */
    public static KclOption withCode(String... codes) {
        final List<String> values = KclOptionBag.strings(codes);
        return bag -> bag.kCodeList.addAll(values);
    }

    /** Append KCL file paths to the program (kcl-go {@code WithKFilenames}). */
    public static KclOption withKFilenames(String... paths) {
        final List<String> values = KclOptionBag.strings(paths);
        return bag -> bag.kFilenameList.addAll(values);
    }

    /** Set the working directory for the evaluation (kcl-go {@code WithWorkDir}). */
    public static KclOption withWorkDir(String workDir) {
        return bag -> bag.workDir = workDir;
    }

    /** Set override specs (the {@code -O} flag). */
    public static KclOption withOverrides(List<String> specs) {
        final List<String> values = new ArrayList<String>(specs);
        return bag -> bag.overrides.addAll(values);
    }

    /** Set override specs (the {@code -O} flag). */
    public static KclOption withOverrides(String... specs) {
        return withOverrides(Arrays.asList(specs));
    }

    /** Set path selectors (the {@code -S} flag). */
    public static KclOption withSelectors(List<String> selectors) {
        final List<String> values = new ArrayList<String>(selectors);
        return bag -> bag.selectors.addAll(values);
    }

    /** Set path selectors (the {@code -S} flag). */
    public static KclOption withSelectors(String... selectors) {
        return withSelectors(Arrays.asList(selectors));
    }

    /**
     * Record a {@code kcl.yaml} settings file whose fields provide the base
     * program arguments (kcl-go {@code WithSettings}). Explicit
     * {@code with*} options override the file. An unreadable or invalid file
     * fails the run.
     */
    public static KclOption withSettings(String path) {
        return bag -> bag.settingsPath = path;
    }

    /**
     * Toggle {@code disable_none} (the {@code -n} flag). Like kcl-go's
     * {@code Merge}, only {@code true} takes effect; {@code false} leaves the
     * current value untouched.
     */
    public static KclOption withDisableNone(boolean disableNone) {
        return bag -> bag.disableNone = disableNone;
    }

    /** Toggle {@code sort_keys} (the {@code -k} flag); only {@code true} takes effect. */
    public static KclOption withSortKeys(boolean sortKeys) {
        return bag -> bag.sortKeys = sortKeys;
    }

    /** Toggle {@code show_hidden} (the {@code -H} flag); only {@code true} takes effect. */
    public static KclOption withShowHidden(boolean showHidden) {
        return bag -> bag.showHidden = showHidden;
    }

    /** Toggle {@code include_schema_type_path}; only {@code true} takes effect. */
    public static KclOption withIncludeSchemaTypePath(boolean includeSchemaTypePath) {
        return bag -> bag.includeSchemaTypePath = includeSchemaTypePath;
    }

    /** Toggle {@code strict_range_check}; only {@code true} takes effect. */
    public static KclOption withStrictRangeCheck(boolean strictRangeCheck) {
        return bag -> bag.strictRangeCheck = strictRangeCheck;
    }

    /** Attach external packages (the {@code -E} flag) as package name to path entries. */
    public static KclOption withExternalPkgs(Map<String, String> nameToPath) {
        final List<ExternalPkg> values = new ArrayList<ExternalPkg>();
        for (Map.Entry<String, String> entry : nameToPath.entrySet()) {
            values.add(ExternalPkg.newBuilder().setPkgName(entry.getKey()).setPkgPath(entry.getValue()).build());
        }
        return bag -> bag.externalPkgs.addAll(values);
    }

    /** Set {@code option(...)} arguments (the {@code -D} flag). */
    public static KclOption withArgs(Map<String, String> nameToValue) {
        final List<Argument> values = new ArrayList<Argument>();
        for (Map.Entry<String, String> entry : nameToValue.entrySet()) {
            values.add(Argument.newBuilder().setName(entry.getKey()).setValue(entry.getValue()).build());
        }
        return bag -> bag.args.addAll(values);
    }

    /** Set the verbose level; only positive values take effect. */
    public static KclOption withVerbose(int verbose) {
        return bag -> bag.verbose = verbose;
    }

    /** Set the debug level; only non-zero values take effect. */
    public static KclOption withDebug(boolean debug) {
        return bag -> bag.debug = debug ? 1 : 0;
    }

    // ------------------------------------------------------------------
    // Internal plumbing
    // ------------------------------------------------------------------

    private static KclOptionBag newBag(KclOption... options) {
        KclOptionBag bag = new KclOptionBag();
        bag.applyAll(Arrays.asList(options));
        return bag;
    }

    private static KCLResultList exec(KclOptionBag bag) {
        ExecProgramArgs args = bag.toExecProgramArgs();
        if (args.getKFilenameListCount() == 0 && args.getKCodeListCount() == 0) {
            throw new KclException("kcl.Run: no kcl file or code");
        }
        final ExecProgramResult resp;
        try {
            resp = new API().execProgram(args);
        } catch (Exception e) {
            throw new KclException(e.getMessage(), e);
        }
        return execResultToKCLResult(resp);
    }

    /**
     * Turn an {@link ExecProgramResult} into a {@link KCLResultList},
     * mirroring kcl-go's {@code ExecResultToKCLResult}: a non-empty
     * {@code err_message} becomes an exception; the document list is built by
     * splitting {@code yaml_result} on {@code ---} separators while the
     * decoded values come from the runtime JSON stream (with a YAML
     * per-document fallback).
     */
    static KCLResultList execResultToKCLResult(ExecProgramResult resp) {
        if (resp.getErrMessage() != null && !resp.getErrMessage().isEmpty()) {
            throw new KclException(resp.getErrMessage());
        }
        String json = resp.getJsonResult();
        String yaml = resp.getYamlResult();
        if (json == null || json.trim().isEmpty()) {
            return new KCLResultList(new ArrayList<KCLResult>(), json, yaml);
        }
        List<String> documents = splitDocuments(yaml);
        List<Object> values = parseJsonStream(json);
        List<KCLResult> results = new ArrayList<KCLResult>();
        int count = Math.max(documents.size(), values.size());
        for (int i = 0; i < count; i++) {
            String document = i < documents.size() ? documents.get(i) : null;
            if (document != null && document.trim().isEmpty() && i >= values.size()) {
                continue;
            }
            Object value = i < values.size() ? values.get(i) : parseYamlDocument(document);
            results.add(new KCLResult(value, document));
        }
        return new KCLResultList(results, json, yaml);
    }

    /**
     * Split a YAML stream into its documents. A separator is any line
     * starting with {@code ---}; only whitespace or comments may follow on
     * the same line. Mirrors kcl-go's {@code SplitDocuments}.
     */
    static List<String> splitDocuments(String yaml) {
        List<String> docs = new ArrayList<String>();
        if (yaml == null || yaml.isEmpty()) {
            return docs;
        }
        List<String> lines = Arrays.asList(yaml.split("\n", -1));
        List<String> current = new ArrayList<String>();
        boolean valid = true;
        for (int i = 0; i < lines.size(); i++) {
            String line = stripCarriageReturn(lines.get(i));
            if (line.startsWith("---")) {
                String rest = line.substring(3).trim();
                if (!rest.isEmpty() && !rest.startsWith("#")) {
                    valid = false;
                    break;
                }
                docs.add(joinLines(current));
                current = new ArrayList<String>();
            } else {
                current.add(lines.get(i));
            }
        }
        if (!valid) {
            return new ArrayList<String>();
        }
        docs.add(joinLines(current));
        return docs;
    }

    private static String stripCarriageReturn(String line) {
        return line.endsWith("\r") ? line.substring(0, line.length() - 1) : line;
    }

    private static String joinLines(List<String> lines) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < lines.size(); i++) {
            if (i > 0) {
                sb.append('\n');
            }
            sb.append(lines.get(i));
        }
        return sb.toString();
    }

    private static List<Object> parseJsonStream(String json) {
        ObjectMapper mapper = KclMappers.json();
        List<Object> values = new ArrayList<Object>();
        try {
            MappingIterator<Object> iterator = mapper.readerFor(Object.class).readValues(json);
            while (iterator.hasNext()) {
                values.add(iterator.next());
            }
        } catch (IOException e) {
            throw new KclException("failed to parse KCL JSON result: " + e.getMessage(), e);
        }
        return values;
    }

    private static Object parseYamlDocument(String document) {
        if (document == null || document.trim().isEmpty()) {
            return null;
        }
        try {
            return KclMappers.yaml().readValue(document, Object.class);
        } catch (IOException e) {
            throw new KclException("failed to parse KCL YAML document: " + e.getMessage(), e);
        }
    }
}

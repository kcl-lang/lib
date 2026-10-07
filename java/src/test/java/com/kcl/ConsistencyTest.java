package com.kcl;

import java.io.IOException;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.google.protobuf.Message;
import com.google.protobuf.util.JsonFormat;
import com.kcl.api.API;
import com.kcl.api.Spec.Argument;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.ExecProgramResult;
import com.kcl.api.Spec.FormatCodeArgs;
import com.kcl.api.Spec.FormatCodeResult;
import com.kcl.api.Spec.FormatPathArgs;
import com.kcl.api.Spec.FormatPathResult;
import com.kcl.api.Spec.FormatTestReportArgs;
import com.kcl.api.Spec.FormatTestReportResult;
import com.kcl.api.Spec.GenerateDocArgs;
import com.kcl.api.Spec.GenerateDocResult;
import com.kcl.api.Spec.GenerateKclArgs;
import com.kcl.api.Spec.GenerateKclResult;
import com.kcl.api.Spec.GenerateOpenAPIArgs;
import com.kcl.api.Spec.GenerateOpenAPIResult;
import com.kcl.api.Spec.GenerateProtoArgs;
import com.kcl.api.Spec.GenerateProtoResult;
import com.kcl.api.Spec.GenerateTomlArgs;
import com.kcl.api.Spec.GenerateTomlResult;
import com.kcl.api.Spec.GetSchemaTypeMappingArgs;
import com.kcl.api.Spec.KeyValuePair;
import com.kcl.api.Spec.GetSchemaTypeMappingResult;
import com.kcl.api.Spec.GetVersionArgs;
import com.kcl.api.Spec.GetVersionResult;
import com.kcl.api.Spec.LintPathArgs;
import com.kcl.api.Spec.LintPathResult;
import com.kcl.api.Spec.ListMethodResult;
import com.kcl.api.Spec.ListOptionsResult;
import com.kcl.api.Spec.ListVariablesArgs;
import com.kcl.api.Spec.ListVariablesOptions;
import com.kcl.api.Spec.ListVariablesResult;
import com.kcl.api.Spec.LoadPackageArgs;
import com.kcl.api.Spec.LoadPackageResult;
import com.kcl.api.Spec.LoadSettingsFilesArgs;
import com.kcl.api.Spec.LoadSettingsFilesResult;
import com.kcl.api.Spec.OptionHelp;
import com.kcl.api.Spec.OverrideFileArgs;
import com.kcl.api.Spec.OverrideFileResult;
import com.kcl.api.Spec.ParseFileArgs;
import com.kcl.api.Spec.ParseFileResult;
import com.kcl.api.Spec.ParseProgramArgs;
import com.kcl.api.Spec.ParseProgramResult;
import com.kcl.api.Spec.PingArgs;
import com.kcl.api.Spec.PingResult;
import com.kcl.api.Spec.TestArgs;
import com.kcl.api.Spec.TestCaseInfo;
import com.kcl.api.Spec.TestResult;
import com.kcl.api.Spec.UpdateDependenciesArgs;
import com.kcl.api.Spec.UpdateDependenciesResult;
import com.kcl.api.Spec.ValidateCodeArgs;
import com.kcl.api.Spec.ValidateCodeResult;

import org.junit.AfterClass;
import org.junit.Assert;
import org.junit.Assume;
import org.junit.Test;

/**
 * Cross-language consistency runner: executes the hermetic cases from {@code tests/consistency/cases.json} (generated
 * by {@code tests/consistency/generate_cases.py}) and asserts the same golden expectations as every other language
 * runner.
 *
 * Run from the {@code java} module directory:
 *
 * <pre>
 * mvn test -Dtest=ConsistencyTest
 * </pre>
 */
public class ConsistencyTest {

    private static final Path CASES_JSON = Paths.get("..", "tests", "consistency", "cases.json");
    private static final Path REPO_ROOT = CASES_JSON.toAbsolutePath().normalize().getParent().getParent().getParent();
    private static final Path TESTDATA = REPO_ROOT.resolve(Paths.get("tests", "consistency", "testdata"));
    private static final ObjectMapper MAPPER = new ObjectMapper();

    /**
     * The marker {@code generate_cases.py} writes into a path that names a template rather than a file.
     * {@code scratch:a/b.k} means "b.k inside a copy of testdata/a"; the copy is what makes the RPCs that write files
     * safe to run, and it is also why the expectations for those cases pin the RPC's answer rather than a path.
     */
    private static final String SCRATCH_PREFIX = "scratch:";

    private static JsonNode manifest;
    private static API apiInstance;
    private static Set<String> availableMethods;

    /**
     * Every case this class executes, recorded at the top of {@link #runCase} rather than at the end so a case that
     * fails is not additionally reported as unexecuted. {@link #testEveryManifestCaseHasARunner} fails if the manifest
     * grows a case this runner does not dispatch -- the check that turns "this runner quietly covers half the spec"
     * into a build failure.
     */
    private static final Set<String> executed = new HashSet<>();

    private static JsonNode manifest() throws Exception {
        if (manifest == null) {
            Assert.assertTrue(
                    "consistency manifest not found at " + CASES_JSON.toAbsolutePath()
                            + ". Run `python tests/consistency/generate_cases.py` to generate it.",
                    Files.exists(CASES_JSON));
            manifest = MAPPER.readTree(CASES_JSON.toFile());
            Assert.assertEquals("unsupported consistency manifest version", 1, manifest.get("version").asInt());
        }
        return manifest;
    }

    private static API api() {
        if (apiInstance == null) {
            apiInstance = new API();
        }
        return apiInstance;
    }

    /**
     * Determine the available RPC surface once per run. Cores that predate {@code BuiltinService.ListMethod} answer
     * with an empty list (or throw), in which case {@code new_core} cases are skipped.
     */
    private static Set<String> methods() throws Exception {
        if (availableMethods == null) {
            availableMethods = new HashSet<>();
            try {
                for (String name : api().listMethod().getMethodNameListList()) {
                    availableMethods.add(name);
                }
            } catch (Exception e) {
                // treat the RPC surface as unknown
            }
        }
        return availableMethods;
    }

    private static JsonNode findCase(String name) throws Exception {
        for (JsonNode node : manifest().get("cases")) {
            if (node.get("name").asText().equals(name)) {
                return node;
            }
        }
        Assert.fail("consistency case not found in manifest: " + name);
        return null;
    }

    private static String diff(String expected, String actual) {
        String[] el = expected.split("\n", -1);
        String[] al = actual.split("\n", -1);
        StringBuilder sb = new StringBuilder("--- expected\n+++ actual\n");
        int n = Math.max(el.length, al.length);
        for (int i = 0; i < n; i++) {
            String e = i < el.length ? el[i] : null;
            String a = i < al.length ? al[i] : null;
            if (e != null && e.equals(a)) {
                sb.append("  ").append(e).append('\n');
            } else {
                if (e != null) {
                    sb.append("- ").append(e).append('\n');
                }
                if (a != null) {
                    sb.append("+ ").append(a).append('\n');
                }
            }
        }
        return sb.toString();
    }

    private static void assertField(String caseName, String field, String expected, String actual) {
        Assert.assertEquals(
                "consistency case `" + caseName + "` field `" + field + "` mismatch:\n" + diff(expected, actual),
                expected, actual);
    }

    /**
     * Assert that a projection matches the pinned fields of the manifest. Only the fields the manifest pins are
     * compared, so adding a field to {@code expect} is the only way to start asserting on it -- and a pinned field the
     * projection does not produce is still a failure, because the key is missing either way. Both sides go through
     * {@link #canonical} so the comparison does not depend on protobuf map iteration order or on an absolute path.
     */
    private static void assertShape(String caseName, JsonNode expect, ObjectNode actual) {
        ObjectNode trimmed = MAPPER.createObjectNode();
        Iterator<String> names = actual.fieldNames();
        while (names.hasNext()) {
            String field = names.next();
            if (expect.has(field)) {
                trimmed.set(field, actual.get(field));
            }
        }
        String want = render(expect);
        String got = render(trimmed);
        Assert.assertEquals("consistency case `" + caseName + "` mismatch:\n" + diff(want, got), want, got);
    }

    /**
     * Sort every object key and drop {@code filename}. The schema-mapping documents hold two protobuf maps whose
     * iteration order is undefined, and {@code filename} is an absolute path that differs on every machine, so neither
     * can be pinned as they arrive. Scalars are passed through untouched rather than round-tripped, so a number stays
     * the same Jackson node type on both sides.
     */
    private static JsonNode canonical(JsonNode node) {
        if (node.isObject()) {
            List<String> keys = new ArrayList<>();
            node.fieldNames().forEachRemaining(keys::add);
            Collections.sort(keys);
            ObjectNode out = MAPPER.createObjectNode();
            for (String key : keys) {
                if (!key.equals("filename")) {
                    out.set(key, canonical(node.get(key)));
                }
            }
            return out;
        }
        if (node.isArray()) {
            ArrayNode out = MAPPER.createArrayNode();
            node.forEach(item -> out.add(canonical(item)));
            return out;
        }
        return node;
    }

    private static String render(JsonNode node) {
        try {
            return MAPPER.writeValueAsString(canonical(node));
        } catch (Exception e) {
            throw new AssertionError("could not render " + node, e);
        }
    }

    private static ObjectNode obj() {
        return MAPPER.createObjectNode();
    }

    /** The manifest omits default-valued fields, so an absent array and an empty one are the same input. */
    private static List<String> strings(JsonNode values) {
        List<String> out = new ArrayList<>();
        for (JsonNode value : values) {
            out.add(value.asText());
        }
        return out;
    }

    /**
     * Copy a scratch template and return the path inside the copy. Each case gets its own temporary directory, so two
     * cases -- and two runs -- never observe each other's writes and the repository is never the target of an RPC that
     * rewrites files.
     */
    private static String scratch(String rest) throws Exception {
        String template = rest.contains("/") ? rest.substring(0, rest.indexOf('/')) : rest;
        String tail = rest.contains("/") ? rest.substring(rest.indexOf('/') + 1) : "";
        Path src = TESTDATA.resolve(template);
        Assert.assertTrue("scratch template is not a directory: " + src, Files.isDirectory(src));
        Path dest = Files.createTempDirectory("kcl-consistency-").resolve(template);
        copyTree(src, dest);
        return tail.isEmpty() ? dest.toString() : dest.resolve(tail).toString();
    }

    private static void copyTree(Path src, Path dest) throws Exception {
        Files.walkFileTree(src, new SimpleFileVisitor<Path>() {
            @Override
            public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) throws IOException {
                Files.createDirectories(dest.resolve(src.relativize(dir).toString()));
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                Files.copy(file, dest.resolve(src.relativize(file).toString()), StandardCopyOption.REPLACE_EXISTING);
                return FileVisitResult.CONTINUE;
            }
        });
    }

    /** Manifest path entries are repo-relative (pinned by generate_cases.py); absolute entries are kept as-is. */
    private static String resolvePath(String p) throws Exception {
        if (p.startsWith(SCRATCH_PREFIX)) {
            return scratch(p.substring(SCRATCH_PREFIX.length()));
        }
        Path path = Paths.get(p);
        return path.isAbsolute() ? p : REPO_ROOT.resolve(path).toString();
    }

    private static List<String> resolvePaths(JsonNode values) throws Exception {
        List<String> out = new ArrayList<>();
        for (JsonNode value : values) {
            out.add(resolvePath(value.asText()));
        }
        return out;
    }

    /**
     * Build {@code ExecProgramArgs} from the manifest. {@code k_filename_list} is resolved by the core against the
     * process working directory rather than against {@code work_dir}, so it has to be made absolute here or it will not
     * survive being run from another directory.
     */
    private static ExecProgramArgs execArgs(JsonNode a) throws Exception {
        ExecProgramArgs.Builder builder = ExecProgramArgs.newBuilder();
        for (JsonNode code : a.path("k_code_list")) {
            builder.addKCodeList(code.asText());
        }
        String workDir = resolvePath(a.path("work_dir").asText("."));
        for (JsonNode name : a.path("k_filename_list")) {
            builder.addKFilenameList(Paths.get(name.asText()).isAbsolute() ? name.asText()
                    : Paths.get(workDir).resolve(name.asText()).toString());
        }
        if (a.hasNonNull("work_dir")) {
            builder.setWorkDir(workDir);
        }
        for (JsonNode arg : a.path("args")) {
            builder.addArgs(Argument.newBuilder().setName(arg.path("name").asText(""))
                    .setValue(arg.path("value").asText("")).build());
        }
        for (JsonNode override : a.path("overrides")) {
            builder.addOverrides(override.asText());
        }
        return builder.build();
    }

    private static ParseProgramArgs parseArgs(JsonNode node) throws Exception {
        ParseProgramArgs.Builder builder = ParseProgramArgs.newBuilder();
        builder.addAllPaths(resolvePaths(node.path("paths")));
        for (JsonNode source : node.path("sources")) {
            builder.addSources(source.asText());
        }
        return builder.build();
    }

    /** The schema-mapping documents, in the form every binding can produce. */
    private static JsonNode kclTypes(Map<String, ?> mapping) throws Exception {
        JsonFormat.Printer printer = JsonFormat.printer().preservingProtoFieldNames();
        ObjectNode document = obj();
        for (Map.Entry<String, ?> entry : mapping.entrySet()) {
            document.set(entry.getKey(), MAPPER.readTree(printer.print((Message) entry.getValue())));
        }
        return document;
    }

    private static void runCase(String name) throws Exception {
        executed.add(name);
        JsonNode c = findCase(name);
        String rpc = c.get("rpc").asText();
        JsonNode args = c.get("args");
        JsonNode expect = c.get("expect");

        switch (rpc) {
        case "KclService.Ping": {
            PingResult result = api().ping(PingArgs.newBuilder().setValue(args.get("value").asText()).build());
            assertField(name, "value", expect.get("value").asText(), result.getValue());
            break;
        }
        case "KclService.ExecProgram": {
            ExecProgramResult result = api().execProgram(execArgs(args));
            if (expect.has("yaml_result")) {
                assertField(name, "yaml_result", expect.get("yaml_result").asText(), result.getYamlResult());
            }
            if (expect.has("json_result")) {
                assertField(name, "json_result", expect.get("json_result").asText(), result.getJsonResult());
            }
            break;
        }
        case "KclService.FormatCode": {
            FormatCodeResult result = api()
                    .formatCode(FormatCodeArgs.newBuilder().setSource(args.get("source").asText()).build());
            assertField(name, "formatted", expect.get("formatted").asText(), result.getFormatted().toStringUtf8());
            break;
        }
        case "KclService.ValidateCode": {
            ValidateCodeResult result = api()
                    .validateCode(ValidateCodeArgs.newBuilder().setCode(args.get("code").asText())
                            .setData(args.get("data").asText()).setFormat(args.path("format").asText("")).build());
            ObjectNode actual = obj();
            actual.put("success", result.getSuccess());
            // The diagnostic carries ANSI colour escapes, a random temp path and a temp filename, so
            // the string itself is not pinnable but its presence is.
            actual.put("has_error_message", !result.getErrMessage().isEmpty());
            if (expect.has("err_message")) {
                actual.put("err_message", result.getErrMessage());
            }
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.ParseFile": {
            ParseFileResult result = api().parseFile(ParseFileArgs.newBuilder().setPath(args.path("path").asText(""))
                    .setSource(args.path("source").asText("")).build());
            ObjectNode actual = obj();
            // A bare `Module` document, so the statements are at `body`.
            JsonNode module = result.getAstJson().isEmpty() ? null : MAPPER.readTree(result.getAstJson());
            actual.put("body_count", module == null ? 0 : module.path("body").size());
            actual.put("error_count", result.getErrorsCount());
            ArrayNode deps = actual.putArray("deps");
            result.getDepsList().forEach(deps::add);
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.ParseProgram": {
            ParseProgramResult result = api().parseProgram(parseArgs(args));
            ObjectNode actual = obj();
            // `ParseProgram` returns a `pkgs` document, not a module: one Module per file, keyed by
            // package path.
            JsonNode doc = result.getAstJson().isEmpty() ? null : MAPPER.readTree(result.getAstJson());
            actual.put("module_count", doc == null ? 0 : doc.path("pkgs").path("__main__").size());
            actual.put("error_count", result.getErrorsCount());
            ArrayNode paths = actual.putArray("paths");
            for (String p : result.getPathsList()) {
                paths.add(Paths.get(p).getFileName().toString());
            }
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.ListOptions": {
            ListOptionsResult result = api().listOptions(parseArgs(args));
            ObjectNode actual = obj();
            actual.put("option_count", result.getOptionsCount());
            List<OptionHelp> options = new ArrayList<>(result.getOptionsList());
            options.sort(Comparator.comparing(OptionHelp::getName));
            ArrayNode pinned = actual.putArray("options");
            for (OptionHelp option : options) {
                pinned.add(MAPPER.createArrayNode().add(option.getName()).add(option.getRequired()));
            }
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.ListVariables": {
            ListVariablesArgs.Builder builder = ListVariablesArgs.newBuilder()
                    .addAllFiles(resolvePaths(args.path("files"))).addAllSpecs(strings(args.path("specs")))
                    .setOptions(ListVariablesOptions.newBuilder()
                            .setMergeProgram(args.path("options").path("merge_program").asBoolean()).build());
            ListVariablesResult result = api().listVariables(builder.build());
            ObjectNode actual = obj();
            ObjectNode values = actual.putObject("values");
            new TreeMap<>(result.getVariablesMap()).forEach((spec, list) -> {
                ArrayNode items = values.putArray(spec);
                list.getVariablesList().forEach(v -> items.add(v.getValue()));
            });
            ArrayNode unsupported = actual.putArray("unsupported_codes");
            result.getUnsupportedCodesList().forEach(unsupported::add);
            actual.put("parse_error_count", result.getParseErrorsCount());
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.LoadPackage": {
            LoadPackageArgs.Builder builder = LoadPackageArgs.newBuilder()
                    .setParseArgs(parseArgs(args.get("parse_args"))).setResolveAst(args.path("resolve_ast").asBoolean())
                    .setLoadBuiltin(args.path("load_builtin").asBoolean())
                    .setWithAstIndex(args.path("with_ast_index").asBoolean());
            LoadPackageResult result = api().loadPackage(builder.build());
            ObjectNode actual = obj();
            actual.put("path_count", result.getPathsCount());
            actual.put("type_error_count", result.getTypeErrorsCount());
            actual.put("parse_error_count", result.getParseErrorsCount());
            actual.put("symbol_count", result.getSymbolsCount());
            actual.put("scope_count", result.getScopesCount());
            actual.put("has_kcl_mod", result.hasKclMod());
            actual.put("kcl_mod_name", result.hasKclMod() ? result.getKclMod().getPackage().getName() : "");
            actual.put("app_count", result.getAppsCount());
            actual.put("import_count", result.getImportsCount());
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.GetSchemaTypeMapping":
        case "KclService.GetSchemaTypeMappingUnderPath": {
            GetSchemaTypeMappingArgs.Builder builder = GetSchemaTypeMappingArgs.newBuilder()
                    .setExecArgs(execArgs(args.get("exec_args"))).setSchemaName(args.path("schema_name").asText(""));
            Map<String, ?> mapping = "KclService.GetSchemaTypeMapping".equals(rpc)
                    ? api().getSchemaTypeMapping(builder.build()).getSchemaTypeMappingMap()
                    : api().getSchemaTypeMappingUnderPath(builder.build()).getSchemaTypeMappingMap();
            ObjectNode actual = obj();
            actual.set("type_mapping", kclTypes(mapping));
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.GetVersion": {
            GetVersionResult result = api().getVersion(GetVersionArgs.getDefaultInstance());
            ObjectNode actual = obj();
            String version = result.getVersion();
            String[] parts = version.split("\\.");
            actual.put("version", parts.length >= 2 ? parts[0] + "." + parts[1] : version);
            actual.put("has_checksum", !result.getChecksum().isEmpty());
            actual.put("has_git_sha", !result.getGitSha().isEmpty());
            actual.put("has_version_info", !result.getVersionInfo().isEmpty());
            assertShape(name, expect, actual);
            break;
        }
        case "BuiltinService.ListMethod": {
            ListMethodResult result = api().listMethod();
            List<String> names = result.getMethodNameListList();
            ObjectNode actual = obj();
            actual.put("has_kclservice_ping", names.contains("KclService.Ping"));
            actual.put("has_kclservice_parse_program", names.contains("KclService.ParseProgram"));
            actual.put("has_builtinservice_list_method", names.contains("BuiltinService.ListMethod"));
            actual.put("method_count", names.size());
            actual.put("has_empty_name", names.stream().anyMatch(String::isEmpty));
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.LintPath": {
            LintPathResult result = api()
                    .lintPath(LintPathArgs.newBuilder().addAllPaths(resolvePaths(args.path("paths"))).build());
            ObjectNode actual = obj();
            actual.put("result_count", result.getResultsCount());
            actual.put("has_result", result.getResultsCount() > 0);
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.FormatPath": {
            FormatPathResult result = api()
                    .formatPath(FormatPathArgs.newBuilder().setPath(resolvePath(args.path("path").asText("")))
                            .setDryRun(args.path("dry_run").asBoolean()).build());
            ObjectNode actual = obj();
            actual.put("changed_count", result.getChangedPathsCount());
            List<String> names = new ArrayList<>();
            for (String p : result.getChangedPathsList()) {
                names.add(Paths.get(p).getFileName().toString());
            }
            Collections.sort(names);
            ArrayNode changed = actual.putArray("changed");
            names.forEach(changed::add);
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.Test": {
            TestArgs.Builder builder = TestArgs.newBuilder().setExecArgs(execArgs(args.path("exec_args")))
                    .addAllPkgList(resolvePaths(args.path("pkg_list"))).setRunRegexp(args.path("run_regexp").asText(""))
                    .setFailFast(args.path("fail_fast").asBoolean()).setCoverage(args.path("coverage").asBoolean());
            TestResult result = api().test(builder.build());
            ObjectNode actual = obj();
            List<String> names = new ArrayList<>();
            List<String> failed = new ArrayList<>();
            for (TestCaseInfo info : result.getInfoList()) {
                names.add(info.getName());
                if (!info.getError().isEmpty()) {
                    failed.add(info.getName());
                }
            }
            Collections.sort(names);
            Collections.sort(failed);
            ArrayNode all = actual.putArray("names");
            names.forEach(all::add);
            ArrayNode bad = actual.putArray("failed");
            failed.forEach(bad::add);
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.OverrideFile": {
            OverrideFileResult result = api().overrideFile(OverrideFileArgs.newBuilder()
                    .setFile(resolvePath(args.path("file").asText(""))).addAllSpecs(strings(args.path("specs")))
                    .addAllImportPaths(resolvePaths(args.path("import_paths"))).build());
            ObjectNode actual = obj();
            actual.put("result", result.getResult());
            actual.put("parse_error_count", result.getParseErrorsCount());
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.LoadSettingsFiles": {
            LoadSettingsFilesResult result = api().loadSettingsFiles(
                    LoadSettingsFilesArgs.newBuilder().setWorkDir(resolvePath(args.path("work_dir").asText("")))
                            .addAllFiles(resolvePaths(args.path("files"))).build());
            ObjectNode actual = obj();
            List<KeyValuePair> options = new ArrayList<>(result.getKclOptionsList());
            options.sort(Comparator.comparing(KeyValuePair::getKey));
            ArrayNode pinned = actual.putArray("options");
            for (KeyValuePair option : options) {
                pinned.add(MAPPER.createArrayNode().add(option.getKey()).add(option.getValue()));
            }
            actual.put("output", result.getKclCliConfigs().getOutput());
            ArrayNode overrides = actual.putArray("overrides");
            result.getKclCliConfigs().getOverridesList().forEach(overrides::add);
            actual.put("strict_range_check", result.getKclCliConfigs().getStrictRangeCheck());
            actual.put("verbose", result.getKclCliConfigs().getVerbose());
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.UpdateDependencies": {
            UpdateDependenciesResult result = api().updateDependencies(UpdateDependenciesArgs.newBuilder()
                    .setManifestPath(resolvePath(args.path("manifest_path").asText("")))
                    .setVendor(args.path("vendor").asBoolean()).build());
            ObjectNode actual = obj();
            actual.put("external_pkg_count", result.getExternalPkgsCount());
            assertShape(name, expect, actual);
            break;
        }
        case "KclService.FormatTestReport": {
            Assume.assumeTrue("core does not list " + rpc + " (old core)", methods().contains(rpc));
            List<TestCaseInfo> infos = new ArrayList<>();
            for (JsonNode info : args.get("result").get("info")) {
                infos.add(TestCaseInfo.newBuilder().setName(info.get("name").asText())
                        .setError(info.path("error").asText(""))
                        .setDuration(Long.parseUnsignedLong(info.get("duration").asText()))
                        .setLogMessage(info.path("log_message").asText("")).build());
            }
            FormatTestReportResult result = api().formatTestReport(
                    FormatTestReportArgs.newBuilder().setResult(TestResult.newBuilder().addAllInfo(infos)).build());
            assertField(name, "report", expect.get("report").asText(), result.getReport());
            break;
        }
        case "KclService.GenerateToml": {
            Assume.assumeTrue("core does not list " + rpc + " (old core)", methods().contains(rpc));
            GenerateTomlResult result = api()
                    .generateToml(GenerateTomlArgs.newBuilder().setExecArgs(execArgs(args.get("exec_args")))
                            .setSortKeys(args.path("sort_keys").asBoolean()).build());
            assertField(name, "toml", expect.get("toml").asText(), result.getToml());
            break;
        }
        case "KclService.GenerateKcl": {
            Assume.assumeTrue("core does not list " + rpc + " (old core)", methods().contains(rpc));
            GenerateKclResult result = api().generateKcl(GenerateKclArgs.newBuilder()
                    .setSource(args.get("source").asText()).setFilename(args.get("filename").asText())
                    .setFormat(args.path("format").asText("")).build());
            assertField(name, "kcl", expect.get("kcl").asText(), result.getKcl());
            break;
        }
        case "KclService.GenerateOpenAPI": {
            Assume.assumeTrue("core does not list " + rpc + " (old core)", methods().contains(rpc));
            GenerateOpenAPIResult result = api()
                    .generateOpenAPI(GenerateOpenAPIArgs.newBuilder().setParseArgs(parseArgs(args.get("parse_args")))
                            .setVersion(args.path("version").asText("")).build());
            assertField(name, "spec", expect.get("spec").asText(), result.getSpec());
            break;
        }
        case "KclService.GenerateProto": {
            Assume.assumeTrue("core does not list " + rpc + " (old core)", methods().contains(rpc));
            GenerateProtoResult result = api()
                    .generateProto(GenerateProtoArgs.newBuilder().setParseArgs(parseArgs(args.get("parse_args")))
                            .setPackage(args.path("package").asText("")).build());
            assertField(name, "proto", expect.get("proto").asText(), result.getProto());
            break;
        }
        case "KclService.GenerateDoc": {
            Assume.assumeTrue("core does not list " + rpc + " (old core)", methods().contains(rpc));
            GenerateDocResult result = api().generateDoc(GenerateDocArgs.newBuilder()
                    .setParseArgs(parseArgs(args.get("parse_args"))).setFormat(args.path("format").asText("")).build());
            assertField(name, "content", expect.get("content").asText(), result.getContent());
            break;
        }
        default:
            Assert.fail("no runner support for rpc " + rpc);
        }
    }

    /**
     * Every case in the manifest must be dispatched by a {@code @Test} in this class. Without this, a runner that
     * covers half the spec passes silently -- which is exactly how this class went from 13 cases to 29 in the manifest
     * while still only running 13.
     *
     * <p>
     * An {@code @AfterClass} rather than a {@code @Test} because JUnit does not order methods: run last or it would
     * report a half-covered manifest as a failure on a green run.
     */
    @AfterClass
    public static void everyManifestCaseHasARunner() throws Exception {
        List<String> missing = new ArrayList<>();
        for (JsonNode c : manifest().get("cases")) {
            if (!executed.contains(c.get("name").asText())) {
                missing.add(c.get("name").asText());
            }
        }
        Assert.assertEquals("cases.json has cases this runner does not execute; add a test method for each",
                Collections.emptyList(), missing);
    }

    @Test
    public void testPing() throws Exception {
        runCase("ping");
    }

    @Test
    public void testExecProgramBasic() throws Exception {
        runCase("exec_program_basic");
    }

    @Test
    public void testExecProgramOverrides() throws Exception {
        runCase("exec_program_overrides");
    }

    @Test
    public void testFormatCode() throws Exception {
        runCase("format_code");
    }

    @Test
    public void testValidateCodeOk() throws Exception {
        runCase("validate_code_ok");
    }

    @Test
    public void testValidateCodeInvalid() throws Exception {
        runCase("validate_code_invalid");
    }

    @Test
    public void testGenerateKclJson() throws Exception {
        runCase("generate_kcl_json");
    }

    @Test
    public void testGenerateKclYaml() throws Exception {
        runCase("generate_kcl_yaml");
    }

    @Test
    public void testGenerateToml() throws Exception {
        runCase("generate_toml");
    }

    @Test
    public void testFormatTestReport() throws Exception {
        runCase("format_test_report");
    }

    @Test
    public void testGenerateOpenAPIV3() throws Exception {
        runCase("generate_openapi_v3");
    }

    @Test
    public void testGenerateProto() throws Exception {
        runCase("generate_proto");
    }

    @Test
    public void testGenerateDocMd() throws Exception {
        runCase("generate_doc_md");
    }

    @Test
    public void testParseFile() throws Exception {
        runCase("parse_file");
    }

    @Test
    public void testParseProgram() throws Exception {
        runCase("parse_program");
    }

    @Test
    public void testListOptions() throws Exception {
        runCase("list_options");
    }

    @Test
    public void testListVariables() throws Exception {
        runCase("list_variables");
    }

    @Test
    public void testLoadPackage() throws Exception {
        runCase("load_package");
    }

    @Test
    public void testGetSchemaTypeMapping() throws Exception {
        runCase("get_schema_type_mapping");
    }

    @Test
    public void testGetSchemaTypeMappingUnderPath() throws Exception {
        runCase("get_schema_type_mapping_under_path");
    }

    @Test
    public void testGetVersion() throws Exception {
        runCase("get_version");
    }

    @Test
    public void testListMethod() throws Exception {
        runCase("list_method");
    }

    @Test
    public void testLintPathClean() throws Exception {
        runCase("lint_path_clean");
    }

    @Test
    public void testLintPathWithErrors() throws Exception {
        runCase("lint_path_with_errors");
    }

    @Test
    public void testFormatPathDryRun() throws Exception {
        runCase("format_path_dry_run");
    }

    @Test
    public void testTestRun() throws Exception {
        runCase("test_run");
    }

    @Test
    public void testOverrideFile() throws Exception {
        runCase("override_file");
    }

    @Test
    public void testLoadSettingsFiles() throws Exception {
        runCase("load_settings_files");
    }

    @Test
    public void testUpdateDependenciesNoDeps() throws Exception {
        runCase("update_dependencies_no_deps");
    }
}

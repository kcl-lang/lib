package com.kcl;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.ExecProgramResult;
import com.kcl.api.Spec.FormatCodeArgs;
import com.kcl.api.Spec.FormatCodeResult;
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
import com.kcl.api.Spec.ParseProgramArgs;
import com.kcl.api.Spec.PingArgs;
import com.kcl.api.Spec.PingResult;
import com.kcl.api.Spec.TestCaseInfo;
import com.kcl.api.Spec.TestResult;
import com.kcl.api.Spec.ValidateCodeArgs;
import com.kcl.api.Spec.ValidateCodeResult;

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
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private static JsonNode manifest;
    private static API apiInstance;
    private static Set<String> availableMethods;

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

    private static void runCase(String name) throws Exception {
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
            ExecProgramArgs.Builder builder = ExecProgramArgs.newBuilder();
            args.get("k_code_list").forEach(node -> builder.addKCodeList(node.asText()));
            if (args.has("overrides")) {
                args.get("overrides").forEach(node -> builder.addOverrides(node.asText()));
            }
            ExecProgramResult result = api().execProgram(builder.build());
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
            ValidateCodeResult result = api().validateCode(ValidateCodeArgs.newBuilder()
                    .setCode(args.get("code").asText()).setData(args.get("data").asText()).build());
            Assert.assertEquals("consistency case `" + name + "` field `success`", expect.get("success").asBoolean(),
                    result.getSuccess());
            if (expect.has("err_message")) {
                assertField(name, "err_message", expect.get("err_message").asText(), result.getErrMessage());
            }
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
            ExecProgramArgs.Builder execBuilder = ExecProgramArgs.newBuilder();
            args.get("exec_args").get("k_code_list").forEach(node -> execBuilder.addKCodeList(node.asText()));
            GenerateTomlResult result = api()
                    .generateToml(GenerateTomlArgs.newBuilder().setExecArgs(execBuilder).build());
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
     * Build {@code ParseProgramArgs} from the manifest. Path entries are pinned repo-relative by
     * {@code generate_cases.py}; they are resolved against the repository root (the parent of the directory holding
     * cases.json), while absolute entries are kept as-is.
     */
    private static ParseProgramArgs parseArgs(JsonNode node) {
        Path repoRoot = CASES_JSON.toAbsolutePath().normalize().getParent().getParent().getParent();
        ParseProgramArgs.Builder builder = ParseProgramArgs.newBuilder();
        for (JsonNode path : node.path("paths")) {
            String p = path.asText();
            builder.addPaths(Paths.get(p).isAbsolute() ? p : repoRoot.resolve(p).toString());
        }
        for (JsonNode source : node.path("sources")) {
            builder.addSources(source.asText());
        }
        return builder.build();
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
}

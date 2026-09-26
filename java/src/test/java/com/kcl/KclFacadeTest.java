package com.kcl;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.Spec.ExecProgramArgs;

/**
 * Tests for the high-level {@link Kcl} facade: inline code runs, file runs,
 * error propagation, kcl.yaml settings parsing, option merging and
 * {@link KCLResult} accessors.
 */
public class KclFacadeTest {

    private static final String FACADE_DIR = "./src/test_data/facade";

    @Test
    public void testRunInlineCode() {
        KCLResultList result = Kcl.run("a = 1\nb = {c = \"x\"}");
        Assert.assertEquals(1, result.size());
        KCLResult first = result.first();
        Assert.assertEquals(Optional.of(1), first.getInt("a"));
        Assert.assertEquals(Optional.of("x"), first.getString("b.c"));
        Assert.assertEquals("x", first.get("b", Map.class).orElse(null).get("c"));
        Assert.assertEquals(2, first.toMap().size());
        Assert.assertTrue(result.getRawYamlResult().contains("a: 1"));
        Assert.assertTrue(result.getRawJsonResult().contains("\"a\": 1"));
    }

    @Test
    public void testRunInlineCodeWithOverrides() {
        KCLResultList result = Kcl.run("a = 1", Kcl.withOverrides("a=2"));
        Assert.assertEquals(Optional.of(2), result.first().getInt("a"));
    }

    @Test
    public void testRunInlineCodeWithSelectors() {
        KCLResultList result = Kcl.run("a = 1\nb = {c = 2}", Kcl.withSelectors("b"));
        Assert.assertNull(result.first().get("a"));
        Assert.assertEquals(Optional.of(2), result.first().getInt("c"));
        Assert.assertNull(result.first().get("missing.key"));
    }

    @Test
    public void testRunMultiDocumentYaml() {
        KCLResultList result = Kcl.run("import manifests\nmanifests.yaml_stream([{x = 1}, {y = 2}])");
        Assert.assertEquals(2, result.size());
        Assert.assertEquals(Optional.of(1), result.get(0).getInt("x"));
        Assert.assertEquals(Optional.of(2), result.get(1).getInt("y"));
        Assert.assertEquals(Optional.of(2), result.tail().getInt("y"));
        Assert.assertTrue(result.getRawYamlResult().contains("---"));
        Assert.assertTrue(result.get(0).yamlString().contains("x: 1"));
    }

    @Test
    public void testRunFiles() {
        KCLResultList result = Kcl.runFiles("./src/test_data/schema.k");
        Assert.assertEquals(Optional.of(2), result.first().getInt("app.replicas"));

        KCLResultList listed = Kcl.runFiles(Arrays.asList("./src/test_data/schema.k"));
        Assert.assertEquals(Optional.of(2), listed.first().getInt("app.replicas"));
    }

    @Test
    public void testRunFilesWithExternalPkgs() {
        Map<String, String> pkgs = new HashMap<String, String>();
        pkgs.put("pkg", "./src/test_data/pkg");
        KCLResultList result = Kcl.runFiles("./src/test_data/schema.k", Kcl.withExternalPkgs(pkgs));
        Assert.assertEquals(Optional.of(2), result.first().getInt("app.replicas"));
    }

    @Test
    public void testRunThrowsOnEvalError() {
        KclException err = Assert.assertThrows(KclException.class, () -> Kcl.run("a = = 1"));
        Assert.assertFalse(err.getMessage().isEmpty());
    }

    @Test
    public void testRunThrowsWhenNoInputOrBadSettings() {
        Assert.assertThrows(KclException.class, () -> Kcl.runWithOpts());
        Assert.assertThrows(KclException.class,
                () -> Kcl.run("a = 1", Kcl.withSettings("no/such/kcl.yaml")));
    }

    @Test
    public void testSettingsRun() {
        KCLResultList result = Kcl.runWithOpts(Kcl.withSettings(FACADE_DIR + "/kcl.yaml"),
                Kcl.withWorkDir(FACADE_DIR));
        // path_selector selects INTO the path, yielding the app subtree
        Map<String, Object> doc = result.toMap();
        Assert.assertEquals(2, doc.size());
        Assert.assertTrue(doc.containsKey("replicas"));
        // overrides are applied
        Assert.assertEquals(Optional.of(4), result.first().getInt("replicas"));
        // kcl_options become option() arguments
        Assert.assertEquals(Optional.of("prod"), result.first().getString("name"));
        // sort_keys is observable in the raw YAML key order
        Assert.assertTrue(result.getRawYamlResult().indexOf("name:") < result.getRawYamlResult()
                .indexOf("replicas:"));
    }

    @Test
    public void testSettingsDisableNoneAndOverlay() {
        // settings file sets disable_none: true, so `nothing` is omitted
        KCLResultList disabled = Kcl.runWithOpts(Kcl.withSettings(FACADE_DIR + "/kcl_none.yaml"),
                Kcl.withWorkDir(FACADE_DIR));
        Assert.assertNull(disabled.first().get("nothing"));
        Assert.assertEquals(Optional.of("dev"), disabled.first().getString("app.name"));

        // kcl-go merge semantics: withDisableNone(false) does not turn the
        // flag back off, `nothing` stays omitted
        KCLResultList overlay = Kcl.runWithOpts(Kcl.withSettings(FACADE_DIR + "/kcl_none.yaml"),
                Kcl.withWorkDir(FACADE_DIR), Kcl.withDisableNone(false));
        Assert.assertNull(overlay.first().get("nothing"));

        // without a settings file the explicit true takes effect
        KCLResultList plain = Kcl.run("nothing = None\nother = 1", Kcl.withDisableNone(true));
        Assert.assertNull(plain.first().get("nothing"));
        Assert.assertEquals(Optional.of(1), plain.first().getInt("other"));
        // and by default None values are kept
        KCLResultList withNone = Kcl.run("nothing = None\nother = 1");
        Assert.assertTrue(withNone.first().toMap().containsKey("nothing"));
    }

    @Test
    public void testSettingsParsingDetails() {
        ExecProgramArgs args = loadSettings(FACADE_DIR + "/kcl.yaml", FACADE_DIR);
        // relative file entries resolve against the work dir
        Assert.assertEquals(Arrays.asList("src/test_data/facade/main.k"), args.getKFilenameListList());
        Assert.assertTrue(args.getDisableNone());
        Assert.assertTrue(args.getSortKeys());
        Assert.assertTrue(args.getStrictRangeCheck());
        Assert.assertTrue(args.getShowHidden());
        Assert.assertEquals(2, args.getVerbose());
        Assert.assertEquals(1, args.getDebug());
        Assert.assertEquals(Arrays.asList("app"), args.getPathSelectorList());
        Assert.assertEquals(Arrays.asList("app.replicas=4"), args.getOverridesList());
        // kcl_options: scalars become plain strings
        Assert.assertEquals("prod", args.getArgs(0).getValue());
        // kcl_options: map values become JSON with document order preserved
        Assert.assertEquals("{\"b\":2,\"a\":1}", args.getArgs(1).getValue());

        // singular `file:` is honoured too
        ExecProgramArgs singular = loadSettings(FACADE_DIR + "/kcl_file.yaml", FACADE_DIR);
        Assert.assertEquals(Arrays.asList("src/test_data/facade/main.k"), singular.getKFilenameListList());
    }

    private static ExecProgramArgs loadSettings(String path, String workDir) {
        ExecProgramArgs.Builder builder = ExecProgramArgs.newBuilder();
        KclSettingsFile.load(path).applyTo(builder, workDir);
        return builder.build();
    }

    @Test
    public void testShowHiddenOption() {
        String code = "_hidden = 1\nvisible = 2";
        Assert.assertNull(Kcl.run(code).first().get("_hidden"));
        Assert.assertEquals(Optional.of(1), Kcl.run(code, Kcl.withShowHidden(true)).first().getInt("_hidden"));
    }

    @Test
    public void testArgsOption() {
        Map<String, String> args = new HashMap<String, String>();
        args.put("env", "staging");
        KCLResultList result = Kcl.run("name = option(\"env\")", Kcl.withArgs(args));
        Assert.assertEquals(Optional.of("staging"), result.first().getString("name"));
    }

    @Test
    public void testKclResultTypedAccessors() {
        KCLResult result = Kcl.run("s = \"1\"\ni = 2\nf = 1.5\nt = True\nl = [1, 2]").first();
        Assert.assertEquals(Optional.of("1"), result.getString("s"));
        Assert.assertEquals(Optional.of(2), result.getInt("i"));
        Assert.assertEquals(Optional.of(1.5), result.getDouble("f"));
        Assert.assertEquals(Optional.of(true), result.getBoolean("t"));
        Assert.assertEquals(Optional.of(2), result.getInt("l.1"));
        Assert.assertFalse(result.getInt("missing").isPresent());
        Assert.assertThrows(KclException.class, () -> result.getInt("s"));
        Assert.assertThrows(KclException.class, result::toList);
    }

    @Test
    public void testExecResultToKCLResult() {
        // one JSON stream value per YAML document
        com.kcl.api.Spec.ExecProgramResult multi = com.kcl.api.Spec.ExecProgramResult.newBuilder()
                .setJsonResult("{\"x\": 1}\n{\"y\": 2}")
                .setYamlResult("x: 1\n---\n'y': 2")
                .build();
        KCLResultList parsed = Kcl.execResultToKCLResult(multi);
        Assert.assertEquals(2, parsed.size());
        Assert.assertEquals(Optional.of(1), parsed.get(0).getInt("x"));
        Assert.assertEquals(Optional.of(2), parsed.get(1).getInt("y"));
        Assert.assertEquals("x: 1", parsed.get(0).yamlString().trim());

        // a stream holding a single whole-document list
        com.kcl.api.Spec.ExecProgramResult listDoc = com.kcl.api.Spec.ExecProgramResult.newBuilder()
                .setJsonResult("[[1, 2]]")
                .setYamlResult("- 1\n- 2")
                .build();
        Assert.assertEquals(Arrays.asList(1, 2), Kcl.execResultToKCLResult(listDoc).first().toList());

        // err_message becomes an exception
        com.kcl.api.Spec.ExecProgramResult failed = com.kcl.api.Spec.ExecProgramResult.newBuilder()
                .setErrMessage("boom")
                .build();
        KclException err = Assert.assertThrows(KclException.class, () -> Kcl.execResultToKCLResult(failed));
        Assert.assertEquals("boom", err.getMessage());

        // a blank JSON mirror yields an empty result list
        com.kcl.api.Spec.ExecProgramResult noJson = com.kcl.api.Spec.ExecProgramResult.newBuilder()
                .setYamlResult("a: 1")
                .build();
        Assert.assertTrue(Kcl.execResultToKCLResult(noJson).isEmpty());
    }

    @Test
    public void testOptionMergeOrderAppends() {
        KCLResultList result = Kcl.run("a = \"seed\"", Kcl.withCode("b = \"extra\""));
        Assert.assertEquals(Optional.of("seed"), result.first().getString("a"));
        Assert.assertEquals(Optional.of("extra"), result.first().getString("b"));
    }
}

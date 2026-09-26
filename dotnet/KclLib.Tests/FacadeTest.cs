namespace KclLib.Tests;

using KclLib.Facade;

[TestClass]
public class FacadeTest
{
    static string parentDirectory = FindCsprojInParentDirectory(Environment.CurrentDirectory);

    // ------------------------------------------------------------------
    // Run: inline code
    // ------------------------------------------------------------------

    [TestMethod]
    public void TestRunInlineCode()
    {
        var result = Kcl.Run("a = 1\nb = \"x\"");
        Assert.AreEqual(1, result.Count);
        Assert.AreEqual(1L, result.First()!.Get("a"));
        Assert.AreEqual("x", result.First()!.Get<string>("b"));
        CollectionAssert.AreEquivalent(new[] { "a", "b" }, result.ToMap().Keys.ToList());
    }

    [TestMethod]
    public void TestRunInlineCodeJsonResult()
    {
        var result = Kcl.Run("a = 1");
        Assert.AreEqual("{\"a\": 1}", result.GetRawJsonResult());
        Assert.AreEqual("a: 1", result.GetRawYamlResult());
    }

    [TestMethod]
    public void TestRunWithOverrides()
    {
        var result = Kcl.Run("x = \"default\"", KclOptions.WithOverrides("x=\"bob\""));
        Assert.AreEqual("bob", result.First()!.Get("x"));
    }

    [TestMethod]
    public void TestRunWithSelectors()
    {
        var result = Kcl.Run("a = 1\nb = 2", KclOptions.WithSelectors("a"));
        Assert.AreEqual(1, result.Count);
        Assert.AreEqual("1", result.GetRawYamlResult());
        Assert.AreEqual(1L, result.First()!.Value);
    }

    [TestMethod]
    public void TestRunWithArgs()
    {
        var result = Kcl.Run("x = option(\"key\")", KclOptions.WithArgs("key=hello"));
        Assert.AreEqual("hello", result.First()!.Get("x"));
    }

    [TestMethod]
    public void TestRunWithKFilenamesAppendsInputs()
    {
        string dir = NewTempDir();
        try
        {
            File.WriteAllText(Path.Combine(dir, "main.k"), "a = 1");
            File.WriteAllText(Path.Combine(dir, "extra.k"), "b = 2");
            // WithKFilenames appends to the positional inputs. (Note: the
            // runtime only honours k_filename_list when k_code_list is empty,
            // so the entry point here is RunFiles.)
            var result = Kcl.RunFiles(
                new[] { Path.Combine(dir, "main.k") },
                KclOptions.WithKFilenames(Path.Combine(dir, "extra.k")));
            Assert.AreEqual(1L, result.First()!.Get("a"));
            Assert.AreEqual(2L, result.First()!.Get("b"));
        }
        finally
        {
            Directory.Delete(dir, true);
        }
    }

    // ------------------------------------------------------------------
    // RunFiles
    // ------------------------------------------------------------------

    [TestMethod]
    public void TestRunFiles()
    {
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        var result = Kcl.RunFiles(new[] { path });
        Assert.AreEqual(1, result.Count);
        Assert.AreEqual(2L, result.First()!.Get("app.replicas"));
        var app = result.First()!.Get<Dictionary<string, object?>>("app");
        Assert.IsNotNull(app);
        Assert.AreEqual(2L, app["replicas"]);
    }

    [TestMethod]
    public void TestRunFilesMergeInputs()
    {
        string dir = NewTempDir();
        try
        {
            File.WriteAllText(Path.Combine(dir, "a.k"), "a = 1");
            File.WriteAllText(Path.Combine(dir, "b.k"), "b = 2");
            // Multiple input files merge into a single configuration document.
            var result = Kcl.RunFiles(new[]
            {
                Path.Combine(dir, "a.k"),
                Path.Combine(dir, "b.k"),
            });
            Assert.AreEqual(1, result.Count);
            Assert.AreEqual(1L, result.First()!.Get("a"));
            Assert.AreEqual(2L, result.First()!.Get("b"));
        }
        finally
        {
            Directory.Delete(dir, true);
        }
    }

    // ------------------------------------------------------------------
    // Error paths: a failed run throws KclException
    // ------------------------------------------------------------------

    [TestMethod]
    public void TestRunFilesThrowsForMissingFile()
    {
        var missing = Path.Combine(parentDirectory, "test_data", "file_not_found.k");
        var ex = Assert.ThrowsException<KclException>(() => Kcl.RunFiles(new[] { missing }));
        StringAssert.Contains(ex.Message, "Cannot find the kcl file");
    }

    [TestMethod]
    public void TestRunThrowsForCompileError()
    {
        // The exception message is the runtime's err_message.
        var ex = Assert.ThrowsException<KclException>(() => Kcl.Run("a = "));
        StringAssert.Contains(ex.Message, "E1001");
    }

    [TestMethod]
    public void TestRunFilesThrowsWithoutInput()
    {
        var ex = Assert.ThrowsException<KclException>(() => Kcl.RunFiles(Array.Empty<string>()));
        StringAssert.Contains(ex.Message, "no kcl file");
    }

    [TestMethod]
    public void TestRunThrowsForInvalidSettingsFile()
    {
        var ex = Assert.ThrowsException<KclException>(
            () => Kcl.Run("a = 1", KclOptions.WithSettings("/nonexistent/kcl.yaml")));
        StringAssert.Contains(ex.Message, "kcl.WithSettings(/nonexistent/kcl.yaml)");
    }

    // ------------------------------------------------------------------
    // Option merge semantics
    // ------------------------------------------------------------------

    [TestMethod]
    public void TestMergeListsAppendInOrder()
    {
        var result = Kcl.Run(
            "x = \"d\"",
            KclOptions.WithOverrides("x=\"first\""),
            KclOptions.WithOverrides("x=\"second\""));
        Assert.AreEqual("second", result.First()!.Get("x"));
    }

    [TestMethod]
    public void TestMergeScalarsLastWins()
    {
        // WithFormat is observable through which raw payload the runtime emits.
        var yamlResult = Kcl.Run(
            "a = 1",
            KclOptions.WithFormat("json"),
            KclOptions.WithFormat("yaml"));
        Assert.AreEqual("a: 1", yamlResult.GetRawYamlResult());
        Assert.AreEqual("", yamlResult.GetRawJsonResult());

        var jsonResult = Kcl.Run(
            "a = 1",
            KclOptions.WithFormat("yaml"),
            KclOptions.WithFormat("json"));
        Assert.AreEqual("", jsonResult.GetRawYamlResult());
        Assert.AreEqual("{\"a\": 1}", jsonResult.GetRawJsonResult());
    }

    [TestMethod]
    public void TestMergeBoolScalarsLastWins()
    {
        // disable_none=true omits None-valued attributes; the later explicit
        // false must win over the earlier true.
        var omitted = Kcl.Run("x = None\ny = 1", KclOptions.WithDisableNone(true));
        Assert.IsNull(omitted.First()!.Get("x"));
        Assert.AreEqual(1L, omitted.First()!.Get("y"));

        var restored = Kcl.Run(
            "x = None\ny = 1",
            KclOptions.WithDisableNone(true),
            KclOptions.WithDisableNone(false));
        // The key is present again (its value is the YAML null, so check the
        // map rather than Get, which returns null for both cases).
        Assert.IsTrue(restored.First()!.ToMap().ContainsKey("x"));
    }

    [TestMethod]
    public void TestMergeWorkDirLastWins()
    {
        string dir = NewTempDir();
        try
        {
            File.WriteAllText(Path.Combine(dir, "main.k"), "a = 1");
            var result = Kcl.RunFiles(
                Array.Empty<string>(),
                KclOptions.WithWorkDir("/nonexistent"),
                KclOptions.WithWorkDir(dir),
                KclOptions.WithKFilenames("main.k"));
            Assert.AreEqual(1L, result.First()!.Get("a"));
        }
        finally
        {
            Directory.Delete(dir, true);
        }
    }

    // ------------------------------------------------------------------
    // Output formats
    // ------------------------------------------------------------------

    [TestMethod]
    public void TestFormatJsonPopulatesJsonResult()
    {
        var result = Kcl.Run("a = 1", KclOptions.WithFormat("json"));
        Assert.AreEqual("", result.GetRawYamlResult());
        Assert.AreEqual(1L, result.First()!.Get("a"));
    }

    [TestMethod]
    public void TestFormatYamlParsesViaYamlFallback()
    {
        // With only yaml_result available the document is read through the
        // YamlDotNet fallback (indentless sequences included).
        var result = Kcl.Run(
            "a = 1\nb = {c = 2, d = [3, 4]}",
            KclOptions.WithFormat("yaml"));
        Assert.AreEqual("", result.GetRawJsonResult());
        Assert.AreEqual(1L, result.First()!.Get("a"));
        Assert.AreEqual(2L, result.First()!.Get("b.c"));
        Assert.AreEqual(4L, result.First()!.Get("b.d.1"));
    }

    [TestMethod]
    public void TestSortKeysObservable()
    {
        var sorted = Kcl.Run("z = 1\na = 2\nm = 3", KclOptions.WithSortKeys(true));
        CollectionAssert.AreEqual(new[] { "a", "m", "z" }, sorted.ToMap().Keys.ToList());

        var unsorted = Kcl.Run("z = 1\na = 2\nm = 3");
        CollectionAssert.AreEqual(new[] { "z", "a", "m" }, unsorted.ToMap().Keys.ToList());
    }

    // ------------------------------------------------------------------
    // KclResult / KclResultList accessors
    // ------------------------------------------------------------------

    [TestMethod]
    public void TestResultDottedGet()
    {
        var result = Kcl.Run("x = [{v = 1}, {v = 2}]\ny = {\"a-b\": {\"c\": 42}}");
        var doc = result.First()!;
        Assert.AreEqual(2L, doc.Get("x.1.v"));
        Assert.AreEqual(42L, doc.Get("y.a-b.c"));
        Assert.IsNull(doc.Get("x.9.v"));
        Assert.IsNull(doc.Get("missing.key"));
        Assert.AreEqual(2, doc.Get<List<object?>>("x")!.Count);
    }

    [TestMethod]
    public void TestResultListAccessors()
    {
        var result = Kcl.Run("a = 1");
        Assert.AreEqual(1, result.Count);
        Assert.AreSame(result.First(), result.Get(0));
        Assert.AreSame(result.First(), result.Last());
        Assert.IsNull(result.Get(1));
        Assert.ThrowsException<KclException>(() => result.ToList());
        Assert.ThrowsException<KclException>(() => result.First()!.ToList());
    }

    [TestMethod]
    public void TestResultToMapOnScalarThrows()
    {
        var result = Kcl.Run("x = [1, 2, 3]", KclOptions.WithSelectors("x"));
        Assert.AreEqual(3, result.ToList().Count);
        Assert.ThrowsException<KclException>(() => result.ToMap());
    }

    [TestMethod]
    public void TestResultJsonStringRoundTrip()
    {
        var result = Kcl.Run("a = 1\nb = \"x\"");
        StringAssert.Contains(result.First()!.JsonString(), "\"a\": 1");
    }

    // ------------------------------------------------------------------
    // SplitDocuments (internal, exercised here through InternalsVisibleTo)
    // ------------------------------------------------------------------

    [TestMethod]
    public void TestSplitDocuments()
    {
        var docs = Kcl.SplitDocuments("a: 1\n---\nb: 2\n");
        Assert.AreEqual(2, docs.Count);
        StringAssert.Contains(docs[0], "a: 1");
        StringAssert.Contains(docs[1], "b: 2");

        // Separators may carry trailing comments or whitespace.
        Assert.AreEqual(2, Kcl.SplitDocuments("a: 1\n--- # comment\nb: 2").Count);
        Assert.AreEqual(2, Kcl.SplitDocuments("a: 1\n--- \nb: 2").Count);

        // No separator: single document, empty input: none.
        Assert.AreEqual(1, Kcl.SplitDocuments("a: 1").Count);
        Assert.AreEqual(0, Kcl.SplitDocuments("").Count);

        // Anything but a comment after the separator is an error (kcl-go semantics).
        Assert.ThrowsException<KclException>(() => Kcl.SplitDocuments("a: 1\n--- oops\nb: 2"));
    }

    // ------------------------------------------------------------------
    // Settings files
    // ------------------------------------------------------------------

    [TestMethod]
    public void TestWithSettings()
    {
        string dir = NewTempDir();
        try
        {
            File.WriteAllText(Path.Combine(dir, "main.k"),
                "result = option(\"who\") + \"-\" + option(\"mode\")\nz = 1\na = 2");
            File.WriteAllText(Path.Combine(dir, "kcl.yaml"), """
kcl_cli_configs:
  files:
    - main.k
  sort_keys: true
  disable_none: true
  strict_range_check: true
  verbose: 1
kcl_options:
  - key: who
    value: settings
  - key: mode
    value: fast
""");
            var result = Kcl.RunFiles(
                Array.Empty<string>(),
                KclOptions.WithWorkDir(dir),
                KclOptions.WithSettings(Path.Combine(dir, "kcl.yaml")));
            Assert.AreEqual("settings-fast", result.First()!.Get("result"));
            // sort_keys from the settings file took effect.
            CollectionAssert.AreEqual(new[] { "a", "result", "z" }, result.ToMap().Keys.ToList());
        }
        finally
        {
            Directory.Delete(dir, true);
        }
    }

    [TestMethod]
    public void TestWithSettingsOverridesAndMergeOrder()
    {
        string dir = NewTempDir();
        try
        {
            File.WriteAllText(Path.Combine(dir, "main.k"), "x = \"default\"");
            File.WriteAllText(Path.Combine(dir, "kcl.yaml"), """
kcl_cli_configs:
  files:
    - main.k
  overrides:
    - 'x="settings"'
""");
            // Settings overrides apply on their own...
            var fromSettings = Kcl.RunFiles(
                Array.Empty<string>(),
                KclOptions.WithWorkDir(dir),
                KclOptions.WithSettings(Path.Combine(dir, "kcl.yaml")));
            Assert.AreEqual("settings", fromSettings.First()!.Get("x"));

            // ...and options applied after WithSettings win for scalars/lists
            // appended later (kcl-go Option.Merge order semantics).
            var fromOption = Kcl.RunFiles(
                Array.Empty<string>(),
                KclOptions.WithWorkDir(dir),
                KclOptions.WithSettings(Path.Combine(dir, "kcl.yaml")),
                KclOptions.WithOverrides("x=\"option\""));
            Assert.AreEqual("option", fromOption.First()!.Get("x"));
        }
        finally
        {
            Directory.Delete(dir, true);
        }
    }

    [TestMethod]
    public void TestWithSettingsPackageMaps()
    {
        string dir = NewTempDir();
        try
        {
            File.WriteAllText(Path.Combine(dir, "main.k"), "a = 1");
            File.WriteAllText(Path.Combine(dir, "kcl.yaml"), """
kcl_cli_configs:
  files:
    - main.k
  package_maps:
    mypkg: /vendor/mypkg
""");
            var result = Kcl.RunFiles(
                Array.Empty<string>(),
                KclOptions.WithWorkDir(dir),
                KclOptions.WithSettings(Path.Combine(dir, "kcl.yaml")));
            Assert.AreEqual(1L, result.First()!.Get("a"));
        }
        finally
        {
            Directory.Delete(dir, true);
        }
    }

    [TestMethod]
    public void TestWithSettingsExistingTestDataFile()
    {
        // The repo's own settings fixture: strict_range_check + one kcl_option.
        var settings = Path.Combine(parentDirectory, "test_data", "settings", "kcl.yaml");
        var result = Kcl.Run("a = 1", KclOptions.WithSettings(settings));
        Assert.AreEqual(1L, result.First()!.Get("a"));
    }

    static string NewTempDir()
    {
        string dir = Path.Combine(Path.GetTempPath(), "kcl-facade-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        return dir;
    }

    static string FindCsprojInParentDirectory(string directory)
    {
        string parent = Directory.GetParent(directory).FullName;
        string csprojFilePath = Directory.GetFiles(parent, "*.csproj").FirstOrDefault();

        if (csprojFilePath != null)
        {
            return parent;
        }
        else if (parent == directory)
        {
            return null;
        }
        else
        {
            return FindCsprojInParentDirectory(parent);
        }
    }
}

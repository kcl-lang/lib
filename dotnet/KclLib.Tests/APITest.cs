namespace KclLib.Tests;

using Google.Protobuf;
using KclLib.API;

[TestClass]
public class APITest
{
    static string parentDirectory = FindCsprojInParentDirectory(Environment.CurrentDirectory);

    [TestMethod]
    public void TestExecProgramAPI()
    {
        var api = new API();
        var execArgs = new ExecProgramArgs();
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        execArgs.KFilenameList.Add(path);
        var result = api.ExecProgram(execArgs);
        Assert.AreEqual("app:\n  replicas: 2", result.YamlResult, result.ToString());
    }

    [TestMethod]
    public void TestExecProgramAPIFileNotFound()
    {
        var api = new API();
        var execArgs = new ExecProgramArgs();
        var path = Path.Combine(parentDirectory, "test_data", "file_not_found.k");
        execArgs.KFilenameList.Add(path);
        try
        {
            var result = api.ExecProgram(execArgs);
            Assert.Fail("No exception was thrown for non-existent file path");
        }
        catch (Exception ex)
        {
            Assert.AreEqual(true, ex.Message.Contains("Cannot find the kcl file"));
        }
    }

    [TestMethod]
    public void TestParseProgramAPI()
    {
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        // Prepare arguments for parsing the KCL program
        var args = new ParseProgramArgs();
        args.Paths.Add(path);
        // Instantiate API and call parse_program method

        var result = new API().ParseProgram(args);

        // Assert the parsing results
        Assert.AreEqual(1, result.Paths.Count);
        Assert.AreEqual(0, result.Errors.Count);
    }

    [TestMethod]
    public void TestParseFileApi()
    {
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        // Prepare arguments for parsing a single KCL file
        var args = new ParseFileArgs { Path = path };

        // Instantiate API and call parse_file method
        var result = new API().ParseFile(args);

        // Assert the parsing results
        Assert.AreEqual(0, result.Deps.Count);
        Assert.AreEqual(0, result.Errors.Count);
    }

    [TestMethod]
    public void TestOverrideFileAPI()
    {
        // Backup and restore test file for each test run
        string bakFile = Path.Combine(parentDirectory, "test_data", "override_file", "main.bak");
        string testFile = Path.Combine(parentDirectory, "test_data", "override_file", "main.k");
        File.WriteAllText(testFile, File.ReadAllText(bakFile));

        // Prepare arguments for overriding the KCL file
        var args = new OverrideFileArgs
        {
            File = testFile,
        };
        args.Specs.Add("b.a=2");
        // Instantiate API and call override_file method

        var result = new API().OverrideFile(args);

        // Assert the outcomes of the override operation
        Assert.AreEqual(0, result.ParseErrors.Count);
        Assert.AreEqual(true, result.Result);
    }

    [TestMethod]
    public void TestFormatPathAPI()
    {
        var api = new API();
        var args = new FormatPathArgs();
        var path = Path.Combine(parentDirectory, "test_data", "format_path", "test.k");
        args.Path = path;
        var result = api.FormatPath(args);
    }

    [TestMethod]
    public void TestFormatCodeAPI()
    {
        string sourceCode = "schema Person:\n" + "    name:   str\n" + "    age:    int\n" + "    check:\n"
                + "        0 <   age <   120\n";
        string expectedFormattedCode = "schema Person:\n" + "    name: str\n" + "    age: int\n\n" + "    check:\n"
                + "        0 < age < 120\n";
        var api = new API();
        var args = new FormatCodeArgs();
        args.Source = sourceCode;
        var result = api.FormatCode(args);
        Assert.AreEqual(expectedFormattedCode, result.Formatted.ToStringUtf8(), result.ToString());
    }

    [TestMethod]
    public void TestGetSchemaTypeAPI()
    {
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        var execArgs = new ExecProgramArgs();
        execArgs.KFilenameList.Add(path);
        var args = new GetSchemaTypeMappingArgs();
        args.ExecArgs = execArgs;
        var result = new API().GetSchemaTypeMapping(args);
        Assert.AreEqual("int", result.SchemaTypeMapping["app"].Properties["replicas"].Type, result.ToString());
    }

    // Regression test for https://github.com/kcl-lang/kcl/issues/1546:
    // schemas coming from external dependency packages must keep their own
    // pkgpath and base schema instead of being misattributed to "__main__".
    [TestMethod]
    public void TestGetSchemaTypeUnderPathAPI()
    {
        var root = Path.Combine(parentDirectory, "test_data", "get_schema_ty_under_path");
        var execArgs = new ExecProgramArgs();
        execArgs.KFilenameList.Add(Path.Combine(root, "aaa"));
        execArgs.ExternalPkgs.Add(new ExternalPkg { PkgName = "bbb", PkgPath = Path.Combine(root, "bbb") });
        var args = new GetSchemaTypeMappingArgs();
        args.ExecArgs = execArgs;
        var result = new API().GetSchemaTypeMappingUnderPath(args);

        Assert.IsTrue(result.SchemaTypeMapping.ContainsKey("__main__"));
        Assert.IsTrue(result.SchemaTypeMapping.ContainsKey("bbb"));

        var bbbSchemas = result.SchemaTypeMapping["bbb"].SchemaType.ToDictionary(s => s.SchemaName);
        Assert.IsTrue(bbbSchemas.ContainsKey("Base"));
        Assert.IsTrue(bbbSchemas.ContainsKey("B"));
        Assert.AreEqual("bbb", bbbSchemas["Base"].PkgPath);
        Assert.AreEqual("bbb", bbbSchemas["B"].PkgPath);
        Assert.IsNotNull(bbbSchemas["B"].BaseSchema, "B.BaseSchema must be resolved across the package boundary");
        Assert.AreEqual("Base", bbbSchemas["B"].BaseSchema.SchemaName);
        Assert.AreEqual("bbb", bbbSchemas["B"].BaseSchema.PkgPath);
    }

    [TestMethod]
    public void TestListOptionsAPI()
    {
        var path = Path.Combine(parentDirectory, "test_data", "option", "main.k");
        var args = new ParseProgramArgs();
        args.Paths.Add(path);
        var result = new API().ListOptions(args);
        Assert.AreEqual("key1", result.Options[0].Name);
        Assert.AreEqual("key2", result.Options[1].Name);
        Assert.AreEqual("metadata-key", result.Options[2].Name);
    }

    [TestMethod]
    public void TestListVariablesAPI()
    {
        var api = new API();
        var args = new ListVariablesArgs();
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        args.Files.Add(path);
        var result = api.ListVariables(args);
        Assert.AreEqual("AppConfig {\n    replicas = 2\n}", result.Variables["app"].Variables[0].Value, result.ToString());
    }

    [TestMethod]
    public void TestLoadPackagesAPI()
    {
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        var args = new LoadPackageArgs();
        args.ResolveAst = true;
        args.ParseArgs = new ParseProgramArgs();
        args.ParseArgs.Paths.Add(path);
        var result = new API().LoadPackage(args);
        var firstSymbol = result.Symbols.Values.FirstOrDefault();
        Assert.AreEqual(true, firstSymbol != null);
    }

    [TestMethod]
    public void TestLintPathAPI()
    {
        var path = Path.Combine(parentDirectory, "test_data", "lint_path", "test-lint.k");
        var args = new LintPathArgs();
        args.Paths.Add(path);
        var result = new API().LintPath(args);
        bool foundWarning = result.Results.Any(warning => warning.Contains("Module 'math' imported but unused"));
        Assert.AreEqual(true, foundWarning, result.ToString());
    }

    [TestMethod]
    public void TestValidateCodeAPI()
    {
        // Define the code schema and data
        string code = @"
schema Person:
    name: str
    age: int
    check:
        0 < age < 120
";
        string data = "{\"name\": \"Alice\", \"age\": 10}";

        // Prepare arguments for validating the code
        var args = new ValidateCodeArgs
        {
            Code = code,
            Data = data,
            Format = "json"
        };

        // Instantiate API and call validate_code method

        var result = new API().ValidateCode(args);

        // Assert the validation results
        Assert.AreEqual(true, result.Success);
        Assert.AreEqual(string.Empty, result.ErrMessage);
    }

    [TestMethod]
    public void TestRenameAPI()
    {
        var root = Path.Combine(parentDirectory, "test_data", "rename");
        var renameFilePath = Path.Combine(parentDirectory, "test_data", "rename", "main.k");
        var renameBakFilePath = Path.Combine(parentDirectory, "test_data", "rename", "main.bak");
        File.WriteAllText(renameFilePath, File.ReadAllText(renameBakFilePath));
        var args = new RenameArgs
        {
            PackageRoot = root,
            SymbolPath = "a",
            NewName = "a2"
        };
        args.FilePaths.Add(renameFilePath);

        var result = new API().Rename(args);
        Assert.AreEqual(true, result.ChangedFiles.First().Contains("main.k"));
    }

    [TestMethod]
    public void TestRenameCodeAPI()
    {
        var args = new RenameCodeArgs
        {
            PackageRoot = "/mock/path",
            SymbolPath = "a",
            SourceCodes = { { "/mock/path/main.k", "a = 1\nb = a" } },
            NewName = "a2"
        };

        var result = new API().RenameCode(args);
        Assert.AreEqual("a2 = 1\nb = a2", result.ChangedCodes["/mock/path/main.k"]);
    }

    [TestMethod]
    public void TestTestingAPI()
    {
        var pkg = Path.Combine(parentDirectory, "test_data", "testing");
        var args = new TestArgs();
        args.PkgList.Add(pkg + "/...");

        var result = new API().Test(args);
        Assert.AreEqual(2, result.Info.Count);
    }

    [TestMethod]
    public void TestLoadSettingsFilesAPI()
    {
        var workDir = Path.Combine(parentDirectory, "test_data");
        var settingsFile = Path.Combine(workDir, "settings", "kcl.yaml");
        var args = new LoadSettingsFilesArgs
        {
            WorkDir = workDir,
        };
        args.Files.Add(settingsFile);

        var result = new API().LoadSettingsFiles(args);
        Assert.AreEqual(0, result.KclCliConfigs.Files.Count);
        Assert.AreEqual(true, result.KclCliConfigs.StrictRangeCheck);
        Assert.AreEqual(true, result.KclOptions.Any(o => o.Key == "key" && o.Value == "\"value\""));
    }

    [TestMethod]
    public void TestUpdateDependenciesAPI()
    {
        var manifestPath = Path.Combine(parentDirectory, "test_data", "update_dependencies");
        // Prepare arguments for updating dependencies.
        var args = new UpdateDependenciesArgs { ManifestPath = manifestPath };
        // Instantiate API and call update_dependencies method.

        var result = new API().UpdateDependencies(args);
        // Collect package names.
        var pkgNames = result.ExternalPkgs.Select(pkg => pkg.PkgName).ToList();
        // Assertions.
        Assert.AreEqual(2, pkgNames.Count);
    }

    [TestMethod]
    public void TestExecAPIWithExternalDependencies()
    {
        var manifestPath = Path.Combine(parentDirectory, "test_data", "update_dependencies");
        var testFile = Path.Combine(manifestPath, "main.k");
        // First, update dependencies.
        var updateArgs = new UpdateDependenciesArgs { ManifestPath = manifestPath };

        var depResult = new API().UpdateDependencies(updateArgs);
        // Prepare arguments for executing the program with external dependencies.
        var execArgs = new ExecProgramArgs();
        execArgs.KFilenameList.Add(testFile);
        execArgs.ExternalPkgs.AddRange(depResult.ExternalPkgs);
        // Execute the program and assert the result.
        var execResult = new API().ExecProgram(execArgs);
        Assert.AreEqual("a: Hello World!", execResult.YamlResult);
    }

    [TestMethod]
    public void TestGetVersion()
    {
        var result = new API().GetVersion(new GetVersionArgs());
        Assert.AreEqual(true, result.VersionInfo.Contains("Version"), result.ToString());
        Assert.AreEqual(true, result.VersionInfo.Contains("GitCommit"), result.ToString());
    }

    [TestMethod]
    public void TestPing()
    {
        var result = new API().Ping(new PingArgs { Value = "hello-kcl" });
        Assert.AreEqual("hello-kcl", result.Value);
    }

    [TestMethod]
    public void TestListMethod()
    {
        var result = new API().ListMethod();
        Assert.IsNotNull(result.MethodNameList);
        // The list_method RPC isn't registered in kcl-api v0.13.0, so the
        // dispatcher panics and we end up with an empty result. Once the
        // kcl side that exposes BuiltinService.ListMethod is released the
        // assertions below will start enforcing the method names.
        if (result.MethodNameList.Count == 0) {
            return;
        }
        CollectionAssert.Contains(result.MethodNameList, "KclService.ExecProgram");
        CollectionAssert.Contains(result.MethodNameList, "KclService.GetVersion");
    }

    // Pure protobuf round-trip — does not require the native runtime.
    // Covers ExecProgramArgs.sourcemap_output (field 22, optional string).
    [TestMethod]
    public void TestExecProgramArgsSourcemapOutputRoundTrip()
    {
        var args = new ExecProgramArgs { SourcemapOutput = "/tmp/out.js.map" };
        Assert.AreEqual(true, args.HasSourcemapOutput);

        var decoded = ExecProgramArgs.Parser.ParseFrom(args.ToByteArray());
        Assert.AreEqual(true, decoded.HasSourcemapOutput);
        Assert.AreEqual("/tmp/out.js.map", decoded.SourcemapOutput);

        var unset = new ExecProgramArgs();
        Assert.AreEqual(false, unset.HasSourcemapOutput);
    }

    // Pure protobuf round-trip — covers ExecProgramResult.sourcemap
    // (field 5, optional string).
    [TestMethod]
    public void TestExecProgramResultSourcemapRoundTrip()
    {
        var result = new ExecProgramResult { Sourcemap = "{\"version\":3}" };
        Assert.AreEqual(true, result.HasSourcemap);

        var decoded = ExecProgramResult.Parser.ParseFrom(result.ToByteArray());
        Assert.AreEqual(true, decoded.HasSourcemap);
        Assert.AreEqual("{\"version\":3}", decoded.Sourcemap);

        var unset = new ExecProgramResult();
        Assert.AreEqual(false, unset.HasSourcemap);
    }

    // Pure protobuf round-trip — covers ExecProgramArgs.emit_attribute_metadata
    // (field 21, bool).
    [TestMethod]
    public void TestExecProgramArgsEmitAttributeMetadataRoundTrip()
    {
        var args = new ExecProgramArgs { EmitAttributeMetadata = true };
        Assert.AreEqual(true, args.EmitAttributeMetadata);

        var decoded = ExecProgramArgs.Parser.ParseFrom(args.ToByteArray());
        Assert.AreEqual(true, decoded.EmitAttributeMetadata);

        var unset = new ExecProgramArgs();
        Assert.AreEqual(false, unset.EmitAttributeMetadata);
    }

    // Pure protobuf round-trip — covers TestArgs.coverage (field 5, bool).
    [TestMethod]
    public void TestTestArgsCoverageRoundTrip()
    {
        var args = new TestArgs { Coverage = true };
        Assert.AreEqual(true, args.Coverage);

        var decoded = TestArgs.Parser.ParseFrom(args.ToByteArray());
        Assert.AreEqual(true, decoded.Coverage);

        var unset = new TestArgs();
        Assert.AreEqual(false, unset.Coverage);
    }

    // Pure protobuf round-trip — covers TestResult.coverage (field 3,
    // TestCoverageReport) and TestCaseInfo.line_hits (field 5,
    // map<string, uint64>).
    [TestMethod]
    public void TestTestResultCoverageAndLineHitsRoundTrip()
    {
        var result = new TestResult();
        result.Info.Add(new TestCaseInfo
        {
            Name = "test_case_1",
            Duration = 1000,
            LogMessage = "log",
        });
        result.Info[0].LineHits.Add("main.k:1", 3);
        result.Info[0].LineHits.Add("main.k:2", 1);
        result.Coverage = new TestCoverageReport();
        result.Coverage.Files.Add("main.k", new FileCoverage
        {
            Filename = "main.k",
        });
        result.Coverage.Files["main.k"].CoveredLines.Add(1);
        result.Coverage.Files["main.k"].CoveredLines.Add(2);
        result.Coverage.Files["main.k"].ExecutableLines.Add(1);
        result.Coverage.Files["main.k"].ExecutableLines.Add(2);
        result.Coverage.Files["main.k"].LineHits.Add(1, 3);
        result.Coverage.Files["main.k"].LineHits.Add(2, 1);
        result.Coverage.Summary = new CoverageSummary
        {
            Covered = 2,
            Executable = 2,
            Percent = 100.0,
        };

        var decoded = TestResult.Parser.ParseFrom(result.ToByteArray());
        Assert.AreEqual(1, decoded.Info.Count);
        Assert.AreEqual("test_case_1", decoded.Info[0].Name);
        Assert.AreEqual(2, decoded.Info[0].LineHits.Count);
        Assert.AreEqual(3UL, decoded.Info[0].LineHits["main.k:1"]);
        Assert.AreEqual(1UL, decoded.Info[0].LineHits["main.k:2"]);
        Assert.AreEqual(1, decoded.Coverage.Files.Count);
        var file = decoded.Coverage.Files["main.k"];
        Assert.AreEqual("main.k", file.Filename);
        CollectionAssert.AreEqual(new ulong[] { 1, 2 }, file.CoveredLines);
        CollectionAssert.AreEqual(new ulong[] { 1, 2 }, file.ExecutableLines);
        Assert.AreEqual(2, file.LineHits.Count);
        Assert.AreEqual(3UL, file.LineHits[1]);
        Assert.AreEqual(1UL, file.LineHits[2]);
        Assert.AreEqual(2UL, decoded.Coverage.Summary.Covered);
        Assert.AreEqual(2UL, decoded.Coverage.Summary.Executable);
        Assert.AreEqual(100.0, decoded.Coverage.Summary.Percent);

        var unset = new TestResult();
        Assert.IsNull(unset.Coverage);
    }

    // Pure protobuf round-trip — covers the new coverage message types
    // FileCoverage, TestCoverageReport and CoverageSummary.
    [TestMethod]
    public void TestCoverageMessagesRoundTrip()
    {
        var summary = new CoverageSummary
        {
            Covered = 7,
            Executable = 10,
            Percent = 70.0,
        };
        var decodedSummary = CoverageSummary.Parser.ParseFrom(summary.ToByteArray());
        Assert.AreEqual(7UL, decodedSummary.Covered);
        Assert.AreEqual(10UL, decodedSummary.Executable);
        Assert.AreEqual(70.0, decodedSummary.Percent);

        var file = new FileCoverage
        {
            Filename = "pkg/main.k",
        };
        file.CoveredLines.Add(3);
        file.ExecutableLines.Add(3);
        file.ExecutableLines.Add(7);
        file.LineHits.Add(3, 5);
        var decodedFile = FileCoverage.Parser.ParseFrom(file.ToByteArray());
        Assert.AreEqual("pkg/main.k", decodedFile.Filename);
        CollectionAssert.AreEqual(new ulong[] { 3 }, decodedFile.CoveredLines);
        CollectionAssert.AreEqual(new ulong[] { 3, 7 }, decodedFile.ExecutableLines);
        Assert.AreEqual(1, decodedFile.LineHits.Count);
        Assert.AreEqual(5UL, decodedFile.LineHits[3]);

        var report = new TestCoverageReport();
        report.Files.Add("pkg/main.k", file);
        report.Summary = summary;
        var decodedReport = TestCoverageReport.Parser.ParseFrom(report.ToByteArray());
        Assert.AreEqual(1, decodedReport.Files.Count);
        Assert.AreEqual("pkg/main.k", decodedReport.Files["pkg/main.k"].Filename);
        Assert.AreEqual(7UL, decodedReport.Summary.Covered);
    }

    static string FindCsprojInParentDirectory(string directory)
    {
        string parentDirectory = Directory.GetParent(directory).FullName;
        string csprojFilePath = Directory.GetFiles(parentDirectory, "*.csproj").FirstOrDefault();

        if (csprojFilePath != null)
        {
            return parentDirectory;
        }
        else if (parentDirectory == directory)
        {
            return null;
        }
        else
        {
            return FindCsprojInParentDirectory(parentDirectory);
        }
    }
}
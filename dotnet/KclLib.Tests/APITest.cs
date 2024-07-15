namespace KclLib.Tests;

using KclLib.API;

[TestClass]
public class APITest
{
    static string parentDirectory = FindCsprojInParentDirectory(Environment.CurrentDirectory);

    [TestMethod]
    public void TestExecProgramAPI()
    {
        var api = new API();
        var execArgs = new ExecProgram_Args();
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        execArgs.KFilenameList.Add(path);
        var result = api.ExecProgram(execArgs);
        Assert.AreEqual("app:\n  replicas: 2", result.YamlResult, result.ToString());
    }

    [TestMethod]
    public void TestExecProgramAPIFileNotFound()
    {
        var api = new API();
        var execArgs = new ExecProgram_Args();
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
        var args = new ParseProgram_Args();
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
        var args = new ParseFile_Args { Path = path };

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
        var args = new OverrideFile_Args
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
        var args = new FormatPath_Args();
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
                + "        0 < age < 120\n\n";
        var api = new API();
        var args = new FormatCode_Args();
        args.Source = sourceCode;
        var result = api.FormatCode(args);
        Assert.AreEqual(expectedFormattedCode, result.Formatted.ToStringUtf8(), result.ToString());
    }

    [TestMethod]
    public void TestGetSchemaTypeAPI()
    {
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        var execArgs = new ExecProgram_Args();
        execArgs.KFilenameList.Add(path);
        var args = new GetSchemaTypeMapping_Args();
        args.ExecArgs = execArgs;
        var result = new API().GetSchemaTypeMapping(args);
        Assert.AreEqual("int", result.SchemaTypeMapping["app"].Properties["replicas"].Type, result.ToString());
    }

    [TestMethod]
    public void TestListOptionsAPI()
    {
        var path = Path.Combine(parentDirectory, "test_data", "option", "main.k");
        var args = new ParseProgram_Args();
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
        var args = new ListVariables_Args();
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        args.Files.Add(path);
        var result = api.ListVariables(args);
        Assert.AreEqual("AppConfig {replicas = 2}", result.Variables["app"].Variables[0].Value, result.ToString());
    }

    [TestMethod]
    public void TestLoadPackagesAPI()
    {
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        var args = new LoadPackage_Args();
        args.ResolveAst = true;
        args.ParseArgs = new ParseProgram_Args();
        args.ParseArgs.Paths.Add(path);
        var result = new API().LoadPackage(args);
        var firstSymbol = result.Symbols.Values.FirstOrDefault();
        Assert.AreEqual(true, firstSymbol != null);
    }

    [TestMethod]
    public void TestLintPathAPI()
    {
        var path = Path.Combine(parentDirectory, "test_data", "lint_path", "test-lint.k");
        var args = new LintPath_Args();
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
        var args = new ValidateCode_Args
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
        var args = new Rename_Args
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
        var args = new RenameCode_Args
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
        var args = new Test_Args();
        args.PkgList.Add(pkg + "/...");

        var result = new API().Test(args);
        Assert.AreEqual(2, result.Info.Count);
    }

    [TestMethod]
    public void TestLoadSettingsFilesAPI()
    {
        var workDir = Path.Combine(parentDirectory, "test_data");
        var settingsFile = Path.Combine(workDir, "settings", "kcl.yaml");
        var args = new LoadSettingsFiles_Args
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
        var args = new UpdateDependencies_Args { ManifestPath = manifestPath };
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
        var updateArgs = new UpdateDependencies_Args { ManifestPath = manifestPath };

        var depResult = new API().UpdateDependencies(updateArgs);
        // Prepare arguments for executing the program with external dependencies.
        var execArgs = new ExecProgram_Args();
        execArgs.KFilenameList.Add(testFile);
        execArgs.ExternalPkgs.AddRange(depResult.ExternalPkgs);
        // Execute the program and assert the result.
        var execResult = new API().ExecProgram(execArgs);
        Assert.AreEqual("a: Hello World!", execResult.YamlResult);
    }

    [TestMethod]
    public void TestGetVersion()
    {
        var result = new API().GetVersion(new GetVersion_Args());
        Assert.AreEqual(true, result.VersionInfo.Contains("Version"), result.ToString());
        Assert.AreEqual(true, result.VersionInfo.Contains("GitCommit"), result.ToString());
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
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
    public void TestListVariablesAPI()
    {
        var api = new API();
        var args = new ListVariables_Args();
        var path = Path.Combine(parentDirectory, "test_data", "schema.k");
        args.Files.Add(path);
        var result = api.ListVariables(args);
        Assert.AreEqual("AppConfig {replicas = 2}", result.Variables["app"].Variables[0].Value, result.ToString());
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
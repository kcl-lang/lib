namespace KclLib.Tests;

using KclLib.API;
using KclLib.Plugin;

[TestClass]
public class PluginTest
{
    static string parentDirectory = FindCsprojInParentDirectory(Environment.CurrentDirectory);

    [TestMethod]
    public void TestExecProgramWithPlugin()
    {
        var context = new PluginContext();
        context.RegisterPlugin("my_plugin", new Dictionary<string, MethodFunction>
        {
            {
                "add",
                (args, kwargs) => Convert.ToInt32(args[0]) + Convert.ToInt32(args[1])
            },
        });
        API.AttachPluginContext(context);

        var path = Path.Combine(parentDirectory, "test_data", "plugin", "plugin.k");
        var execArgs = new ExecProgramArgs();
        execArgs.KFilenameList.Add(path);
        var result = new API().ExecProgram(execArgs);
        Assert.AreEqual("result: 2", result.YamlResult, result.ToString());

        context.RegisterPlugin("my_plugin", new Dictionary<string, MethodFunction>
        {
            {
                "add",
                (args, kwargs) => args[20]
            },
        });
        result = new API().ExecProgram(execArgs);
        Assert.AreEqual(true, result.ErrMessage.Length > 0, result.ToString());
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

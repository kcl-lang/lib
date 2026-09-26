namespace KclLib.Tests;

using System.Collections.Concurrent;
using System.Threading.Tasks;
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

    // Regression test for the plugin-agent buffer race fixed in
    // KclLib/api/API.cs. The previous implementation reused a single
    // `pluginAgentBuffer` that was lazily resized under a lock; under
    // concurrent dispatcher invocations thread A could fill the buffer
    // and release the lock before the dispatcher finished reading it
    // while thread B reallocated or freed it. We now allocate a fresh
    // buffer per plugin-agent invocation and free them all once the
    // surrounding dispatcher call returns.
    //
    // This test runs N=8 threads × 100 calls each, every call invoking
    // `add` and asserting that the dispatcher returns the expected
    // "result: <N>" YAML output. With the old race any failure would
    // surface as a wrong result, a thrown exception, or a non-empty
    // ErrMessage.
    [TestMethod]
    public void TestConcurrentPluginAgentInvocations()
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
        const int threadCount = 8;
        const int callsPerThread = 100;
        var failures = new ConcurrentBag<string>();

        Parallel.For(0, threadCount, threadIdx =>
        {
            for (int i = 0; i < callsPerThread; ++i)
            {
                try
                {
                    var execArgs = new ExecProgramArgs();
                    execArgs.KFilenameList.Add(path);
                    var result = new API().ExecProgram(execArgs);
                    if (result.YamlResult != "result: 2")
                    {
                        failures.Add($"thread={threadIdx} call={i} unexpected result: {result.YamlResult}");
                    }
                    if (result.ErrMessage.Length > 0)
                    {
                        failures.Add($"thread={threadIdx} call={i} error: {result.ErrMessage}");
                    }
                }
                catch (System.Exception e)
                {
                    failures.Add($"thread={threadIdx} call={i} exception: {e.GetType().Name}: {e.Message}");
                }
            }
        });

        if (!failures.IsEmpty)
        {
            Assert.Fail($"Concurrent plugin-agent stress test produced {failures.Count} failure(s):\n" +
                string.Join("\n", failures.Take(20)));
        }
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

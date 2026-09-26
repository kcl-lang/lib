namespace KclLib.API;

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Google.Protobuf;

using KclLib.Plugin;

public class API : IService
{
    private const string LIB_NAME = "kcl_lib_dotnet";
    // Single source of truth for the error prefix the Rust dispatcher
    // prepends to every error reply. Must stay in lockstep with the
    // `format!("ERROR:{}", ...)` literals in `crates/api/src/service/capi.rs`.
    // See `/Users/timi/codes/lib/docs/abi.md` §4 for the full convention.
    private const string ERROR_PREFIX = "ERROR:";

    // Native methods declarations
    [DllImport(LIB_NAME, CallingConvention = CallingConvention.Cdecl)]
    private static extern int callNative([In] byte[] name, int nameLength, [In] byte[] args, int argsLength, IntPtr buffer);

    [DllImport(LIB_NAME, CallingConvention = CallingConvention.Cdecl, EntryPoint = "call_native_with_plugin_agent")]
    private static extern int callNativeWithPluginAgent([In] byte[] name, int nameLength, [In] byte[] args, int argsLength, IntPtr buffer, long pluginAgent);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate IntPtr PluginAgentDelegate(IntPtr method, IntPtr argsJson, IntPtr kwargsJson);

    private static PluginContext? pluginContext;
    private static PluginAgentDelegate? pluginAgent;
    private static IntPtr pluginAgentPtr;

    // Buffers handed to the Rust plugin agent are tracked here so they
    // remain valid for the entire duration of the surrounding
    // `callNativeWithPluginAgent` invocation, and so we can free them in
    // one batch once Rust no longer holds any of the pointers.
    //
    // Plugin-agent callbacks return `IntPtr`s that the Rust dispatcher reads
    // synchronously and then returns to the caller. Each callback's pointer
    // must outlive the dispatcher call, but can be freed once the dispatcher
    // returns. We use a `ThreadLocal<List<IntPtr>>` so that concurrent Call()
    // invocations from different threads free only their own buffers — a
    // shared list would race: thread A's `Call()` finally block would free
    // thread B's still-in-use buffer.
    //
    // See `/Users/timi/codes/lib/docs/abi.md` §3 for the full discussion.
    private static readonly ThreadLocal<List<IntPtr>> pluginAgentBuffers =
        new ThreadLocal<List<IntPtr>>(() => new List<IntPtr>());

    public static void AttachPluginContext(PluginContext context)
    {
        pluginContext = context ?? throw new ArgumentNullException(nameof(context));
        if (pluginAgentPtr == IntPtr.Zero)
        {
            pluginAgent = PluginAgentCallback;
            pluginAgentPtr = Marshal.GetFunctionPointerForDelegate(pluginAgent);
        }
    }

    private static IntPtr PluginAgentCallback(IntPtr methodPtr, IntPtr argsJsonPtr, IntPtr kwargsJsonPtr)
    {
        string method = Marshal.PtrToStringUTF8(methodPtr) ?? string.Empty;
        string argsJson = Marshal.PtrToStringUTF8(argsJsonPtr) ?? string.Empty;
        string kwargsJson = Marshal.PtrToStringUTF8(kwargsJsonPtr) ?? string.Empty;
        string resultJson = pluginContext?.CallMethod(method, argsJson, kwargsJson) ?? string.Empty;
        byte[] resultBytes = System.Text.Encoding.UTF8.GetBytes(resultJson + "\0");

        // Allocate a fresh buffer per invocation and record it for later
        // cleanup. Rust may keep the returned pointer alive across multiple
        // plugin calls within the same `callNativeWithPluginAgent` run,
        // so we cannot free it here; `FreePluginAgentBuffers` runs once
        // the dispatcher returns.
        IntPtr buffer = Marshal.AllocHGlobal(resultBytes.Length);
        Marshal.Copy(resultBytes, 0, buffer, resultBytes.Length);
        pluginAgentBuffers.Value.Add(buffer);
        return buffer;
    }

    private static void FreePluginAgentBuffers()
    {
        List<IntPtr> buffers = pluginAgentBuffers.Value;
        foreach (var ptr in buffers)
        {
            Marshal.FreeHGlobal(ptr);
        }
        buffers.Clear();
    }

    public API()
    {

    }

    // Implementing IService methods
    public ParseProgramResult ParseProgram(ParseProgramArgs args)
    {
        return ParseProgramResult.Parser.ParseFrom(Call("KclService.ParseProgram", args.ToByteArray()));
    }

    public ParseFileResult ParseFile(ParseFileArgs args)
    {
        return ParseFileResult.Parser.ParseFrom(Call("KclService.ParseFile", args.ToByteArray()));
    }

    public LoadPackageResult LoadPackage(LoadPackageArgs args)
    {
        return LoadPackageResult.Parser.ParseFrom(Call("KclService.LoadPackage", args.ToByteArray()));
    }

    public ListVariablesResult ListVariables(ListVariablesArgs args)
    {
        return ListVariablesResult.Parser.ParseFrom(Call("KclService.ListVariables", args.ToByteArray()));
    }

    public ListOptionsResult ListOptions(ParseProgramArgs args)
    {
        return ListOptionsResult.Parser.ParseFrom(Call("KclService.ListOptions", args.ToByteArray()));
    }

    public ExecProgramResult ExecProgram(ExecProgramArgs args)
    {
        return ExecProgramResult.Parser.ParseFrom(Call("KclService.ExecProgram", args.ToByteArray()));
    }

    public OverrideFileResult OverrideFile(OverrideFileArgs args)
    {
        return OverrideFileResult.Parser.ParseFrom(Call("KclService.OverrideFile", args.ToByteArray()));
    }

    public GetSchemaTypeMappingResult GetSchemaTypeMapping(GetSchemaTypeMappingArgs args)
    {
        return GetSchemaTypeMappingResult.Parser.ParseFrom(Call("KclService.GetSchemaTypeMapping", args.ToByteArray()));
    }

    public GetSchemaTypeMappingUnderPathResult GetSchemaTypeMappingUnderPath(GetSchemaTypeMappingArgs args)
    {
        return GetSchemaTypeMappingUnderPathResult.Parser.ParseFrom(Call("KclService.GetSchemaTypeMappingUnderPath", args.ToByteArray()));
    }

    public FormatCodeResult FormatCode(FormatCodeArgs args)
    {
        return FormatCodeResult.Parser.ParseFrom(Call("KclService.FormatCode", args.ToByteArray()));
    }

    public FormatPathResult FormatPath(FormatPathArgs args)
    {
        return FormatPathResult.Parser.ParseFrom(Call("KclService.FormatPath", args.ToByteArray()));
    }

    public LintPathResult LintPath(LintPathArgs args)
    {
        return LintPathResult.Parser.ParseFrom(Call("KclService.LintPath", args.ToByteArray()));
    }

    public ValidateCodeResult ValidateCode(ValidateCodeArgs args)
    {
        return ValidateCodeResult.Parser.ParseFrom(Call("KclService.ValidateCode", args.ToByteArray()));
    }

    public LoadSettingsFilesResult LoadSettingsFiles(LoadSettingsFilesArgs args)
    {
        return LoadSettingsFilesResult.Parser.ParseFrom(Call("KclService.LoadSettingsFiles", args.ToByteArray()));
    }

    public RenameResult Rename(RenameArgs args)
    {
        return RenameResult.Parser.ParseFrom(Call("KclService.Rename", args.ToByteArray()));
    }

    public RenameCodeResult RenameCode(RenameCodeArgs args)
    {
        return RenameCodeResult.Parser.ParseFrom(Call("KclService.RenameCode", args.ToByteArray()));
    }

    public TestResult Test(TestArgs args)
    {
        return TestResult.Parser.ParseFrom(Call("KclService.Test", args.ToByteArray()));
    }

    public UpdateDependenciesResult UpdateDependencies(UpdateDependenciesArgs args)
    {
        return UpdateDependenciesResult.Parser.ParseFrom(Call("KclService.UpdateDependencies", args.ToByteArray()));
    }

    public GetVersionResult GetVersion(GetVersionArgs args)
    {
        return GetVersionResult.Parser.ParseFrom(Call("KclService.GetVersion", args.ToByteArray()));
    }

    public PingResult Ping(PingArgs args)
    {
        return PingResult.Parser.ParseFrom(Call("KclService.Ping", args.ToByteArray()));
    }

    public ListMethodResult ListMethod()
    {
        // `ListMethodArgs` is an empty proto message but the runtime still
        // expects the encoded zero-byte payload for the dispatcher.
        var emptyArgs = new ListMethodArgs();
        return ListMethodResult.Parser.ParseFrom(Call("BuiltinService.ListMethod", emptyArgs.ToByteArray()));
    }

    private byte[] Call(string name, byte[] args)
    {
        var nameBytes = System.Text.Encoding.UTF8.GetBytes(name);
        IntPtr resultBuf = Marshal.AllocHGlobal(2048 * 2048);
        int resultLength;
        try
        {
            if (pluginContext != null)
            {
                resultLength = callNativeWithPluginAgent(nameBytes, nameBytes.Length, args, args.Length, resultBuf, pluginAgentPtr.ToInt64());
            }
            else
            {
                resultLength = callNative(nameBytes, nameBytes.Length, args, args.Length, resultBuf);
            }
        }
        finally
        {
            // The Rust dispatcher is no longer running and no longer holds
            // any of the plugin-agent buffers; free them all together. This
            // must run even if the dispatcher threw, hence the try/finally.
            FreePluginAgentBuffers();
        }
        var result = new byte[resultLength];
        Marshal.Copy(resultBuf, result, 0, resultLength);
        Marshal.FreeHGlobal(resultBuf);
        var resultString = System.Text.Encoding.UTF8.GetString(result);
        if (result == null || !resultString.StartsWith(ERROR_PREFIX))
        {
            return result;
        }
        throw new Exception(resultString.Substring(ERROR_PREFIX.Length));
    }
}

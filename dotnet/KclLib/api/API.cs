namespace KclLib.API;

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Google.Protobuf;

using KclLib.Plugin;

public class API : IService
{
    private const string LIB_NAME = "kcl_lib_dotnet";
    private const string ERROR_PREFIX = "ERROR:";

    // Native methods declarations
    [DllImport(LIB_NAME, CallingConvention = CallingConvention.Cdecl)]
    private static extern int callNative([In] byte[] name, int nameLength, [In] byte[] args, int argsLength, IntPtr buffer);

    public API()
    {

    }

    // Implementing IService methods
    public ParseProgram_Result ParseProgram(ParseProgram_Args args)
    {
        return ParseProgram_Result.Parser.ParseFrom(Call("KclvmService.ParseProgram", args.ToByteArray()));
    }

    public ParseFile_Result ParseFile(ParseFile_Args args)
    {
        return ParseFile_Result.Parser.ParseFrom(Call("KclvmService.ParseFile", args.ToByteArray()));
    }

    public LoadPackage_Result LoadPackage(LoadPackage_Args args)
    {
        return LoadPackage_Result.Parser.ParseFrom(Call("KclvmService.LoadPackage", args.ToByteArray()));
    }

    public ListVariables_Result ListVariables(ListVariables_Args args)
    {
        return ListVariables_Result.Parser.ParseFrom(Call("KclvmService.ListVariables", args.ToByteArray()));
    }

    public ListOptions_Result ListOptions(ParseProgram_Args args)
    {
        return ListOptions_Result.Parser.ParseFrom(Call("KclvmService.ListOptions", args.ToByteArray()));
    }

    public ExecProgram_Result ExecProgram(ExecProgram_Args args)
    {
        return ExecProgram_Result.Parser.ParseFrom(Call("KclvmService.ExecProgram", args.ToByteArray()));
    }

    public OverrideFile_Result OverrideFile(OverrideFile_Args args)
    {
        return OverrideFile_Result.Parser.ParseFrom(Call("KclvmService.OverrideFile", args.ToByteArray()));
    }

    public GetSchemaTypeMapping_Result GetSchemaTypeMapping(GetSchemaTypeMapping_Args args)
    {
        return GetSchemaTypeMapping_Result.Parser.ParseFrom(Call("KclvmService.GetSchemaTypeMapping", args.ToByteArray()));
    }

    public FormatCode_Result FormatCode(FormatCode_Args args)
    {
        return FormatCode_Result.Parser.ParseFrom(Call("KclvmService.FormatCode", args.ToByteArray()));
    }

    public FormatPath_Result FormatPath(FormatPath_Args args)
    {
        return FormatPath_Result.Parser.ParseFrom(Call("KclvmService.FormatPath", args.ToByteArray()));
    }

    public LintPath_Result LintPath(LintPath_Args args)
    {
        return LintPath_Result.Parser.ParseFrom(Call("KclvmService.LintPath", args.ToByteArray()));
    }

    public ValidateCode_Result ValidateCode(ValidateCode_Args args)
    {
        return ValidateCode_Result.Parser.ParseFrom(Call("KclvmService.ValidateCode", args.ToByteArray()));
    }

    public LoadSettingsFiles_Result LoadSettingsFiles(LoadSettingsFiles_Args args)
    {
        return LoadSettingsFiles_Result.Parser.ParseFrom(Call("KclvmService.LoadSettingsFiles", args.ToByteArray()));
    }

    public Rename_Result Rename(Rename_Args args)
    {
        return Rename_Result.Parser.ParseFrom(Call("KclvmService.Rename", args.ToByteArray()));
    }

    public RenameCode_Result RenameCode(RenameCode_Args args)
    {
        return RenameCode_Result.Parser.ParseFrom(Call("KclvmService.RenameCode", args.ToByteArray()));
    }

    public Test_Result Test(Test_Args args)
    {
        return Test_Result.Parser.ParseFrom(Call("KclvmService.Test", args.ToByteArray()));
    }

    public UpdateDependencies_Result UpdateDependencies(UpdateDependencies_Args args)
    {
        return UpdateDependencies_Result.Parser.ParseFrom(Call("KclvmService.UpdateDependencies", args.ToByteArray()));
    }

    public GetVersion_Result GetVersion(GetVersion_Args args)
    {
        return GetVersion_Result.Parser.ParseFrom(Call("KclvmService.GetVersion", args.ToByteArray()));
    }

    private byte[] Call(string name, byte[] args)
    {
        var nameBytes = System.Text.Encoding.UTF8.GetBytes(name);
        IntPtr resultBuf = Marshal.AllocHGlobal(2048 * 2048);
        int resultLength = callNative(nameBytes, nameBytes.Length, args, args.Length, resultBuf);
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

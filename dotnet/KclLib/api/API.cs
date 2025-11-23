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

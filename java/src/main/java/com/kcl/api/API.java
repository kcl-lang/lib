package com.kcl.api;

import com.kcl.api.Spec.*;

public class API implements Service {
	static {
		// Load the dynamic library (the .dll, .so, or .dylib file)
		System.loadLibrary("kcl_lib_jni");
	}

	private native byte[] callNative(byte[] call, byte[] args);

	public API() {
	}

	/**
	 * Parses a program given a set of file paths and returns the result.
	 * *
	 * <p>
	 * Example usage:
	 * 
	 * <pre>{@code
	 * 
	 * import com.kcl.api.*;
	 * import com.kcl.ast.*;
	 * import com.kcl.util.JsonUtil;
	 * 
	 * // Create an instance of the API class
	 * API api = new API();
	 * // Parse the program by providing the file paths to the API
	 * ParseProgram_Result result = api.parseProgram(
	 *     ParseProgram_Args.newBuilder().addPaths("path/to/kcl.k").build()
	 * );
	 * // Print the JSON representation of the AST (Abstract Syntax Tree)
	 * System.out.println(result.getAstJson());
	 * // Deserialize the JSON string into a Program object
	 * Program program = JsonUtil.deserializeProgram(result.getAstJson());
	 * }</pre>
	 * 
	 * @param args the arguments specifying the file paths to be parsed.
	 * @return the result of parsing the program and parse errors, including the AST
	 *         in JSON format.
	 * @throws Exception if an error occurs during the remote procedure call.
	 */
	@Override
	public ParseProgram_Result parseProgram(ParseProgram_Args args) throws Exception {
		return ParseProgram_Result.parseFrom(call("KclvmService.ParseProgram", args.toByteArray()));
	}

	@Override
	public ParseFile_Result parseFile(ParseFile_Args args) throws Exception {
		return ParseFile_Result.parseFrom(call("KclvmService.ParseFile", args.toByteArray()));
	}

	/**
	 * Loads KCL package and returns the AST, symbol, type, definition information.
	 * *
	 * <p>
	 * Example usage:
	 * 
	 * <pre>{@code
	 * 
	 * import com.kcl.api.*;
	 *
	 * API api = new API();
	 * LoadPackage_Result result = api.loadPackage(
	 *     LoadPackage_Args.newBuilder().setResolveAst(true).setParseArgs(
	 *     ParseProgram_Args.newBuilder().addPaths("/path/to/kcl.k").build())
	 *     .build());
	 * result.getSymbolsMap().values().forEach(s -> System.out.println(s));
	 * }</pre>
	 * 
	 * @param args the arguments specifying the file paths to be parsed.
	 * @return the result of parsing the program and parse errors, including the AST
	 *         in JSON format.
	 * @throws Exception if an error occurs during the remote procedure call.
	 */
	@Override
	public LoadPackage_Result loadPackage(LoadPackage_Args args) throws Exception {
		return LoadPackage_Result.parseFrom(call("KclvmService.LoadPackage", args.toByteArray()));
	}

	public ExecProgram_Result execProgram(ExecProgram_Args args) throws Exception {
		return ExecProgram_Result.parseFrom(call("KclvmService.ExecProgram", args.toByteArray()));
	}

	@Override
	public OverrideFile_Result overrideFile(OverrideFile_Args args) throws Exception {
		return OverrideFile_Result.parseFrom(call("KclvmService.OverrideFile", args.toByteArray()));
	}

	@Override
	public GetSchemaType_Result getFullSchemaType(GetFullSchemaType_Args args) throws Exception {
		return GetSchemaType_Result.parseFrom(call("KclvmService.GetSchemaType", args.toByteArray()));
	}

	@Override
	public FormatCode_Result formatCode(FormatCode_Args args) throws Exception {
		return FormatCode_Result.parseFrom(call("KclvmService.FormatCode", args.toByteArray()));
	}

	@Override
	public FormatPath_Result formatPath(FormatPath_Args args) throws Exception {
		return FormatPath_Result.parseFrom(call("KclvmService.FormatPath", args.toByteArray()));
	}

	@Override
	public LintPath_Result lintPath(LintPath_Args args) throws Exception {
		return LintPath_Result.parseFrom(call("KclvmService.LintPath", args.toByteArray()));
	}

	@Override
	public ValidateCode_Result validateCode(ValidateCode_Args args) throws Exception {
		return ValidateCode_Result.parseFrom(call("KclvmService.ValidateCode", args.toByteArray()));
	}

	@Override
	public LoadSettingsFiles_Result loadSettingsFiles(LoadSettingsFiles_Args args) throws Exception {
		return LoadSettingsFiles_Result.parseFrom(call("KclvmService.LoadSettingsFiles", args.toByteArray()));
	}

	@Override
	public Rename_Result rename(Rename_Args args) throws Exception {
		return Rename_Result.parseFrom(call("KclvmService.Rename", args.toByteArray()));
	}

	@Override
	public RenameCode_Result renameCode(RenameCode_Args args) throws Exception {
		return RenameCode_Result.parseFrom(call("KclvmService.RenameCode", args.toByteArray()));
	}

	@Override
	public Test_Result test(Test_Args args) throws Exception {
		return Test_Result.parseFrom(call("KclvmService.Test", args.toByteArray()));
	}

	private byte[] call(String name, byte[] args) throws Exception {
		byte[] result = callNative(name.getBytes(), args);
		if (result != null && startsWith(result, "ERROR")) {
			throw new java.lang.Error(result.toString());
		}
		return result;
	}

	static boolean startsWith(byte[] array, String prefix) {
		byte[] prefixBytes = prefix.getBytes();
		if (array.length < prefixBytes.length) {
			return false;
		}

		for (int i = 0; i < prefixBytes.length; i++) {
			if (array[i] != prefixBytes[i]) {
				return false;
			}
		}

		return true;
	}
}

package com.kcl.api;

import com.kcl.api.Spec.*;

public class API implements Service {
    static {
        // Load the dynamic library (the .dll, .so, or .dylib file)
        System.loadLibrary("kcl_lib_jni");
    }

    private native byte[] callNative(byte[] call, byte[] args);

    // Example method that calls a native function
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
            throw new Error(result.toString());
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

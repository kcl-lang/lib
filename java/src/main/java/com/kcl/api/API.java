package com.kcl.api;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.Map;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

import com.kcl.api.Spec.*;
import com.kcl.plugin.MethodFunction;
import com.kcl.plugin.PluginContext;

public class API implements Service {
    static String LIB_NAME = "kcl_lib_jni";
    static String ERROR_PREFIX = "ERROR:";
    static {
        loadLibrary();
    }

    public static void loadLibrary() {
        // Load the dynamic library (the .dll, .so, or .dylib file)
        try {
            doLoadLibrary();
        } catch (IOException e) {
            throw new UncheckedIOException("Unable to load the KCL shared library", e);
        }
    }

    private static void doLoadLibrary() throws IOException {
        try {
            // try dynamic library - the search path can be configured via "-Djava.library.path"
            System.loadLibrary(LIB_NAME);
            return;
        } catch (UnsatisfiedLinkError ignore) {
            // ignore - try to find native libraries from class path
        }
        doLoadBundledLibrary();
    }

    private static void doLoadBundledLibrary() throws IOException {
        final String libraryPath = bundledLibraryPath();
        try (final InputStream is = API.class.getResourceAsStream(libraryPath)) {
            if (is == null) {
                throw new IOException("cannot find " + libraryPath);
            }
            final int dot = libraryPath.indexOf('.');
            final File tmpFile = File.createTempFile(libraryPath.substring(0, dot), libraryPath.substring(dot));
            tmpFile.deleteOnExit();
            Files.copy(is, tmpFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
            System.load(tmpFile.getAbsolutePath());
        }
    }

    private static String bundledLibraryPath() {
        final String classifier = Environment.getClassifier();
        final String libraryName = System.mapLibraryName(LIB_NAME);
        return "/native/" + classifier + "/" + libraryName;
    }

    private native byte[] callNative(byte[] call, byte[] args);

    private native byte[] loadPackageWithCache(byte[] args);

    private native void registerPluginContext(PluginContext ctx);

    private static PluginContext pluginContext = new PluginContext();
    private static byte[] buffer = new byte[1024];

    public static void registerPlugin(String name, Map<String, MethodFunction> methodMap) {
        pluginContext.registerPlugin(name, methodMap);
    }

    private String callMethod(String method, String argsJson, String kwArgsJson) {
        return pluginContext.callMethod(method, argsJson, kwArgsJson);
    }

    public API() {
        registerPluginContext(pluginContext);
    }

    /**
     * Parses a program given a set of file paths and returns the result. *
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     * import com.kcl.ast.*;
     * import com.kcl.util.JsonUtil;
     *
     * API api = new API();
     * ParseProgram_Result result = api.parseProgram(
     *    ParseProgram_Args.newBuilder().addPaths("path/to/kcl.k").build()
     * );
     * System.out.println(result.getAstJson());
     * Program program = JsonUtil.deserializeProgram(result.getAstJson());
     * }
     * </pre>
     *
     * @param args
     *            the arguments specifying the file paths to be parsed.
     * 
     * @return the result of parsing the program and parse errors, including the AST in JSON format.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
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
     * Loads KCL package and returns the AST, symbol, type, definition information. *
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * API api = new API();
     * LoadPackage_Result result = api.loadPackage(
     *     LoadPackage_Args.newBuilder().setResolveAst(true).setParseArgs(
     *     ParseProgram_Args.newBuilder().addPaths("/path/to/kcl.k").build())
     *     .build());
     * result.getSymbolsMap().values().forEach(s -> System.out.println(s));
     * }
     * </pre>
     *
     * @param args
     *            the arguments specifying the file paths to be parsed and resolved.
     * 
     * @return the result of parsing the program and parse errors, type errors, including the AST in JSON format and
     *         symbol, type and definition information.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public LoadPackage_Result loadPackage(LoadPackage_Args args) throws Exception {
        return LoadPackage_Result.parseFrom(call("KclvmService.LoadPackage", args.toByteArray()));
    }

    /**
     * List variables and return the code text*
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * API api = new API();
     * ListVariables_Result result = api.listVariables(
     *     ListVariables_Args.newBuilder().setResolveAst(true).setParseArgs(
     *     ParseProgram_Args.newBuilder().addPaths("/path/to/kcl.k").build())
     *     .build());
     * result.getSymbolsMap().values().forEach(s -> System.out.println(s));
     * }
     * </pre>
     *
     * @param args
     *            the arguments specifying the file paths to be parsed and resolved.
     * 
     * @return the result of parsing the program and parse errors, type errors, including the AST in JSON format and
     *         symbol, type and definition information.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public ListVariables_Result listVariables(ListVariables_Args args) throws Exception {
        return ListVariables_Result.parseFrom(call("KclvmService.ListVariables", args.toByteArray()));
    }

    /**
     * Loads KCL package with the internal cache and returns the AST, symbol, type, definition information. *
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * API api = new API();
     * LoadPackage_Result result = api.loadPackageWithCache(
     *     LoadPackage_Args.newBuilder().setResolveAst(true).setParseArgs(
     *     ParseProgram_Args.newBuilder().addPaths("/path/to/kcl.k").build())
     *     .build());
     * result.getSymbolsMap().values().forEach(s -> System.out.println(s));
     * }
     * </pre>
     *
     * @param args
     *            the arguments specifying the file paths to be parsed and resolved.
     * 
     * @return the result of parsing the program and parse errors, type errors, including the AST in JSON format and
     *         symbol, type and definition information.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public LoadPackage_Result loadPackageWithCache(LoadPackage_Args args) throws Exception {
        return LoadPackage_Result.parseFrom(callLoadPackageWithCache(args.toByteArray()));
    }

    public ExecProgram_Result execProgram(ExecProgram_Args args) throws Exception {
        return ExecProgram_Result.parseFrom(call("KclvmService.ExecProgram", args.toByteArray()));
    }

    @Override
    public OverrideFile_Result overrideFile(OverrideFile_Args args) throws Exception {
        return OverrideFile_Result.parseFrom(call("KclvmService.OverrideFile", args.toByteArray()));
    }

    @Override
    public GetSchemaTypeMapping_Result getSchemaTypeMapping(GetSchemaTypeMapping_Args args) throws Exception {
        return GetSchemaTypeMapping_Result.parseFrom(call("KclvmService.GetSchemaTypeMapping", args.toByteArray()));
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

    @Override
    public UpdateDependencies_Result updateDependencies(UpdateDependencies_Args args) throws Exception {
        return UpdateDependencies_Result.parseFrom(call("KclvmService.UpdateDependencies", args.toByteArray()));
    }

    private byte[] call(String name, byte[] args) throws Exception {
        byte[] result = callNative(name.getBytes(), args);
        if (result != null && startsWith(result, ERROR_PREFIX)) {
            throw new java.lang.Error(result.toString().substring(ERROR_PREFIX.length()).trim());
        }
        return result;
    }

    private byte[] callLoadPackageWithCache(byte[] args) throws Exception {
        byte[] result = loadPackageWithCache(args);
        if (result != null && startsWith(result, ERROR_PREFIX)) {
            throw new java.lang.Error(result.toString().substring(ERROR_PREFIX.length()).trim());
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

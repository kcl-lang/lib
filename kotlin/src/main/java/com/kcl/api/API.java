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

    private static void loadLibrary() {
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
     * Parses a program given a set of file paths and returns the result.
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

    /**
     * Parses a single file and returns its AST and errors.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     * 
     * ParseFile_Args args = ParseFile_Args.newBuilder().setPath("./src/test_data/parse/main.k").build();
     * API apiInstance = new API();
     * ParseFile_Result result = apiInstance.parseFile(args);
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the file path to be parsed.
     * 
     * @return the result of parsing the file including the AST in JSON format and any errors.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public ParseFile_Result parseFile(ParseFile_Args args) throws Exception {
        return ParseFile_Result.parseFrom(call("KclvmService.ParseFile", args.toByteArray()));
    }

    /**
     * Loads a KCL package and returns AST, symbol, type, and definition information.
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
     *        ParseProgram_Args.newBuilder().addPaths("/path/to/kcl.k").build())
     *     .build());
     * result.getSymbolsMap().values().forEach(s -> System.out.println(s));
     * }
     * </pre>
     *
     * @param args
     *            the arguments specifying the file paths to be parsed and resolved.
     * 
     * @return the result including AST, symbol, type, and definition information.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public LoadPackage_Result loadPackage(LoadPackage_Args args) throws Exception {
        return LoadPackage_Result.parseFrom(call("KclvmService.LoadPackage", args.toByteArray()));
    }

    /**
     * Lists variables in the KCL program and returns detailed information.
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
     *            the arguments specifying the file paths and other details.
     * 
     * @return the result including the variables found and their information.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public ListVariables_Result listVariables(ListVariables_Args args) throws Exception {
        return ListVariables_Result.parseFrom(call("KclvmService.ListVariables", args.toByteArray()));
    }

    /**
     * listOptions provides users with the ability to parse KCL program and get all option information.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * ParseProgram_Args args = ParseProgram_Args.newBuilder().addPaths("./src/test_data/option/main.k").build();
     * API apiInstance = new API();
     * ListOptions_Result result = apiInstance.listOptions(args);
     * }
     * </pre>
     *
     * @param args
     *            the arguments specifying the file paths and other details.
     * 
     * @return the result including the variables found and their information.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public ListOptions_Result listOptions(ParseProgram_Args args) throws Exception {
        return ListOptions_Result.parseFrom(call("KclvmService.ListOptions", args.toByteArray()));
    }

    /**
     * Loads a KCL package using the internal cache and returns various details.
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
     *        ParseProgram_Args.newBuilder().addPaths("/path/to/kcl.k").build())
     *     .build());
     * result.getSymbolsMap().values().forEach(s -> System.out.println(s));
     * }
     * </pre>
     *
     * @param args
     *            the arguments specifying the file paths and resolution details.
     * 
     * @return the result including AST, symbol, type, and definition information.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public LoadPackage_Result loadPackageWithCache(LoadPackage_Args args) throws Exception {
        return LoadPackage_Result.parseFrom(callLoadPackageWithCache(args.toByteArray()));
    }

    /**
     * Executes a KCL program with the given arguments.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * ExecProgram_Args args = ExecProgram_Args.newBuilder().addKFilenameList("schema.k").build();
     * API apiInstance = new API();
     * ExecProgram_Result result = apiInstance.execProgram(args);
     * }
     * </pre>
     * 
     * @param args
     *            the arguments for executing the program.
     * 
     * @return the result of executing the program.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    public ExecProgram_Result execProgram(ExecProgram_Args args) throws Exception {
        return ExecProgram_Result.parseFrom(call("KclvmService.ExecProgram", args.toByteArray()));
    }

    /**
     * Overrides a KCL file with new content.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * API api = new API();
     * String spec = "a=2";
     * OverrideFile_Result result = api.overrideFile(OverrideFile_Args.newBuilder()
     *     .setFile("./src/test_data/override_file/main.k").addSpecs(spec).build());
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the file and the new content.
     * 
     * @return the result of overriding the file.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public OverrideFile_Result overrideFile(OverrideFile_Args args) throws Exception {
        return OverrideFile_Result.parseFrom(call("KclvmService.OverrideFile", args.toByteArray()));
    }

    /**
     * Gets schema type mappings from a KCL program.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     * 
     * ExecProgram_Args execArgs = ExecProgram_Args.newBuilder().addKFilenameList("schema.k").build();
     * GetSchemaTypeMapping_Args args = GetSchemaTypeMapping_Args.newBuilder().setExecArgs(execArgs).build();
     * API apiInstance = new API();
     * GetSchemaTypeMapping_Result result = apiInstance.getSchemaTypeMapping(args);
     * KclType appSchemaType = result.getSchemaTypeMappingMap().get("app");
     * String replicasType = appSchemaType.getPropertiesOrThrow("replicas").getType();
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the program and schema.
     * 
     * @return the schema type mappings in the program.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public GetSchemaTypeMapping_Result getSchemaTypeMapping(GetSchemaTypeMapping_Args args) throws Exception {
        return GetSchemaTypeMapping_Result.parseFrom(call("KclvmService.GetSchemaTypeMapping", args.toByteArray()));
    }

    /**
     * Formats KCL code according to the language standards.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * String sourceCode = "schema Person:\n" + "    name:   str\n" + "    age:    int\n" + "    check:\n"
     *         + "        0 <   age <   120\n";
     * FormatCode_Args args = FormatCode_Args.newBuilder().setSource(sourceCode).build();
     * API apiInstance = new API();
     * FormatCode_Result result = apiInstance.formatCode(args);
     * String expectedFormattedCode = "schema Person:\n" + "    name: str\n" + "    age: int\n\n" + "    check:\n"
     *         + "        0 < age < 120\n\n";
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the code to be formatted.
     * 
     * @return the formatted code.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public FormatCode_Result formatCode(FormatCode_Args args) throws Exception {
        return FormatCode_Result.parseFrom(call("KclvmService.FormatCode", args.toByteArray()));
    }

    /**
     * Formats a specified path containing KCL files.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * FormatPath_Args args = FormatPath_Args.newBuilder().setPath("test.k").build();
     * API apiInstance = new API();
     * FormatPath_Result result = apiInstance.formatPath(args);
     * Assert.assertTrue(result.getChangedPathsList().isEmpty());
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the path to be formatted.
     * 
     * @return the paths of files that were changed during the format process.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public FormatPath_Result formatPath(FormatPath_Args args) throws Exception {
        return FormatPath_Result.parseFrom(call("KclvmService.FormatPath", args.toByteArray()));
    }

    /**
     * Lints a specified path containing KCL files.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * LintPath_Args args = LintPath_Args.newBuilder().addPaths("test.k").build();
     * API apiInstance = new API();
     * LintPath_Result result = apiInstance.lintPath(args);
     * boolean foundWarning = result.getResultsList().stream()
     *         .anyMatch(warning -> warning.contains("Module 'math' imported but unused"));
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the path to be linted.
     * 
     * @return the lint results including warnings and errors.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public LintPath_Result lintPath(LintPath_Args args) throws Exception {
        return LintPath_Result.parseFrom(call("KclvmService.LintPath", args.toByteArray()));
    }

    /**
     * Validates KCL code using given schema and data strings.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * String code = "schema Person:\n" + "    name: str\n" + "    age: int\n" + "    check:\n"
     *         + "        0 < age < 120\n";
     * String data = "{\"name\": \"Alice\", \"age\": 10}";
     * ValidateCode_Args args = ValidateCode_Args.newBuilder().setCode(code).setData(data).setFormat("json").build();
     * API apiInstance = new API();
     * ValidateCode_Result result = apiInstance.validateCode(args);
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the code, schema, and data for validation.
     * 
     * @return the validation result.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public ValidateCode_Result validateCode(ValidateCode_Args args) throws Exception {
        return ValidateCode_Result.parseFrom(call("KclvmService.ValidateCode", args.toByteArray()));
    }

    /**
     * Loads setting files and returns the result.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * API api = new API();
     * LoadSettingsFiles_Args args = LoadSettingsFiles_Args.newBuilder().addFiles("kcl.yaml")
     *         .build();
     * LoadSettingsFiles_Result result = api.loadSettingsFiles(args);
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the settings to be loaded.
     * 
     * @return the loaded settings result.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public LoadSettingsFiles_Result loadSettingsFiles(LoadSettingsFiles_Args args) throws Exception {
        return LoadSettingsFiles_Result.parseFrom(call("KclvmService.LoadSettingsFiles", args.toByteArray()));
    }

    /**
     * Renames symbols in the given KCL files.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * Rename_Args args = Rename_Args.newBuilder().setPackageRoot("./src/test_data/rename").setSymbolPath("a")
     *         .addFilePaths("./src/test_data/rename/main.k").setNewName("a2").build();
     * API apiInstance = new API();
     * Rename_Result result = apiInstance.rename(args);
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the symbols to be renamed.
     * 
     * @return the result of the rename operation.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public Rename_Result rename(Rename_Args args) throws Exception {
        return Rename_Result.parseFrom(call("KclvmService.Rename", args.toByteArray()));
    }

    /**
     * Renames symbols in the given KCL code and returns the modified code.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * API api = new API();
     * RenameCode_Args args = RenameCode_Args.newBuilder().setPackageRoot("/mock/path").setSymbolPath("a")
     *         .putSourceCodes("/mock/path/main.k", "a = 1\nb = a").setNewName("a2").build();
     * RenameCode_Result result = api.renameCode(args);
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the symbols to be renamed in the code.
     * 
     * @return the result of the rename operation including the modified code.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public RenameCode_Result renameCode(RenameCode_Args args) throws Exception {
        return RenameCode_Result.parseFrom(call("KclvmService.RenameCode", args.toByteArray()));
    }

    /**
     * Tests KCL packages with the given test arguments.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * API apiInstance = new API();
     * Test_Args args = Test_Args.newBuilder().addPkgList("./src/test_data/testing/...").build();
     * Test_Result result = apiInstance.test(args);
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the test details.
     * 
     * @return the test result including the test logs and errors.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public Test_Result test(Test_Args args) throws Exception {
        return Test_Result.parseFrom(call("KclvmService.Test", args.toByteArray()));
    }

    /**
     * Updates dependencies defined in the kcl.mod file.
     *
     * <p>
     * Example usage:
     *
     * <pre>
     * {@code
     * import com.kcl.api.*;
     *
     * API api = new API();
     * UpdateDependencies_Result result = api.updateDependencies(
     *         UpdateDependencies_Args.newBuilder().setManifestPath("/path/to/module").build());
     * }
     * </pre>
     * 
     * @param args
     *            the arguments specifying the dependencies to be updated.
     * 
     * @return the result of updating dependencies.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public UpdateDependencies_Result updateDependencies(UpdateDependencies_Args args) throws Exception {
        return UpdateDependencies_Result.parseFrom(call("KclvmService.UpdateDependencies", args.toByteArray()));
    }

    /**
     * Gets the version information of the KCL service.
     *
     * @param args
     *            the arguments specifying the version request.
     * 
     * @return the version result including version number and other details.
     * 
     * @throws Exception
     *             if an error occurs during the remote procedure call.
     */
    @Override
    public GetVersion_Result getVersion(GetVersion_Args args) throws Exception {
        return GetVersion_Result.parseFrom(call("KclvmService.GetVersion", args.toByteArray()));
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

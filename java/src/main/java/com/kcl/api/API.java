package com.kcl.api;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.Map;
import java.nio.charset.StandardCharsets;
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
     * ParseProgramResult result = api.parseProgram(
     *    ParseProgramArgs.newBuilder().addPaths("path/to/kcl.k").build()
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
    public ParseProgramResult parseProgram(ParseProgramArgs args) throws Exception {
        return ParseProgramResult.parseFrom(call("KclService.ParseProgram", args.toByteArray()));
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
     * ParseFileArgs args = ParseFileArgs.newBuilder().setPath("./src/test_data/parse/main.k").build();
     * API apiInstance = new API();
     * ParseFileResult result = apiInstance.parseFile(args);
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
    public ParseFileResult parseFile(ParseFileArgs args) throws Exception {
        return ParseFileResult.parseFrom(call("KclService.ParseFile", args.toByteArray()));
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
     * LoadPackageResult result = api.loadPackage(
     *     LoadPackageArgs.newBuilder().setResolveAst(true).setParseArgs(
     *        ParseProgramArgs.newBuilder().addPaths("/path/to/kcl.k").build())
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
    public LoadPackageResult loadPackage(LoadPackageArgs args) throws Exception {
        return LoadPackageResult.parseFrom(call("KclService.LoadPackage", args.toByteArray()));
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
     * ListVariablesResult result = api.listVariables(
     *     ListVariablesArgs.newBuilder().setResolveAst(true).setParseArgs(
     *     ParseProgramArgs.newBuilder().addPaths("/path/to/kcl.k").build())
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
    public ListVariablesResult listVariables(ListVariablesArgs args) throws Exception {
        return ListVariablesResult.parseFrom(call("KclService.ListVariables", args.toByteArray()));
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
     * ParseProgramArgs args = ParseProgramArgs.newBuilder().addPaths("./src/test_data/option/main.k").build();
     * API apiInstance = new API();
     * ListOptionsResult result = apiInstance.listOptions(args);
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
    public ListOptionsResult listOptions(ParseProgramArgs args) throws Exception {
        return ListOptionsResult.parseFrom(call("KclService.ListOptions", args.toByteArray()));
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
     * LoadPackageResult result = api.loadPackageWithCache(
     *     LoadPackageArgs.newBuilder().setResolveAst(true).setParseArgs(
     *        ParseProgramArgs.newBuilder().addPaths("/path/to/kcl.k").build())
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
    public LoadPackageResult loadPackageWithCache(LoadPackageArgs args) throws Exception {
        return LoadPackageResult.parseFrom(callLoadPackageWithCache(args.toByteArray()));
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
     * ExecProgramArgs args = ExecProgramArgs.newBuilder().addKFilenameList("schema.k").build();
     * API apiInstance = new API();
     * ExecProgramResult result = apiInstance.execProgram(args);
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
    public ExecProgramResult execProgram(ExecProgramArgs args) throws Exception {
        return ExecProgramResult.parseFrom(call("KclService.ExecProgram", args.toByteArray()));
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
     * OverrideFileResult result = api.overrideFile(OverrideFileArgs.newBuilder()
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
    public OverrideFileResult overrideFile(OverrideFileArgs args) throws Exception {
        return OverrideFileResult.parseFrom(call("KclService.OverrideFile", args.toByteArray()));
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
     * ExecProgramArgs execArgs = ExecProgramArgs.newBuilder().addKFilenameList("schema.k").build();
     * GetSchemaTypeMappingArgs args = GetSchemaTypeMappingArgs.newBuilder().setExecArgs(execArgs).build();
     * API apiInstance = new API();
     * GetSchemaTypeMappingResult result = apiInstance.getSchemaTypeMapping(args);
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
    public GetSchemaTypeMappingResult getSchemaTypeMapping(GetSchemaTypeMappingArgs args) throws Exception {
        return GetSchemaTypeMappingResult.parseFrom(call("KclService.GetSchemaTypeMapping", args.toByteArray()));
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
     * FormatCodeArgs args = FormatCodeArgs.newBuilder().setSource(sourceCode).build();
     * API apiInstance = new API();
     * FormatCodeResult result = apiInstance.formatCode(args);
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
    public FormatCodeResult formatCode(FormatCodeArgs args) throws Exception {
        return FormatCodeResult.parseFrom(call("KclService.FormatCode", args.toByteArray()));
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
     * FormatPathArgs args = FormatPathArgs.newBuilder().setPath("test.k").build();
     * API apiInstance = new API();
     * FormatPathResult result = apiInstance.formatPath(args);
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
    public FormatPathResult formatPath(FormatPathArgs args) throws Exception {
        return FormatPathResult.parseFrom(call("KclService.FormatPath", args.toByteArray()));
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
     * LintPathArgs args = LintPathArgs.newBuilder().addPaths("test.k").build();
     * API apiInstance = new API();
     * LintPathResult result = apiInstance.lintPath(args);
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
    public LintPathResult lintPath(LintPathArgs args) throws Exception {
        return LintPathResult.parseFrom(call("KclService.LintPath", args.toByteArray()));
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
     * ValidateCodeArgs args = ValidateCodeArgs.newBuilder().setCode(code).setData(data).setFormat("json").build();
     * API apiInstance = new API();
     * ValidateCodeResult result = apiInstance.validateCode(args);
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
    public ValidateCodeResult validateCode(ValidateCodeArgs args) throws Exception {
        return ValidateCodeResult.parseFrom(call("KclService.ValidateCode", args.toByteArray()));
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
     * LoadSettingsFilesArgs args = LoadSettingsFilesArgs.newBuilder().addFiles("kcl.yaml")
     *         .build();
     * LoadSettingsFilesResult result = api.loadSettingsFiles(args);
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
    public LoadSettingsFilesResult loadSettingsFiles(LoadSettingsFilesArgs args) throws Exception {
        return LoadSettingsFilesResult.parseFrom(call("KclService.LoadSettingsFiles", args.toByteArray()));
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
     * RenameArgs args = RenameArgs.newBuilder().setPackageRoot("./src/test_data/rename").setSymbolPath("a")
     *         .addFilePaths("./src/test_data/rename/main.k").setNewName("a2").build();
     * API apiInstance = new API();
     * RenameResult result = apiInstance.rename(args);
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
    public RenameResult rename(RenameArgs args) throws Exception {
        return RenameResult.parseFrom(call("KclService.Rename", args.toByteArray()));
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
     * RenameCodeArgs args = RenameCodeArgs.newBuilder().setPackageRoot("/mock/path").setSymbolPath("a")
     *         .putSourceCodes("/mock/path/main.k", "a = 1\nb = a").setNewName("a2").build();
     * RenameCodeResult result = api.renameCode(args);
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
    public RenameCodeResult renameCode(RenameCodeArgs args) throws Exception {
        return RenameCodeResult.parseFrom(call("KclService.RenameCode", args.toByteArray()));
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
     * TestArgs args = TestArgs.newBuilder().addPkgList("./src/test_data/testing/...").build();
     * TestResult result = apiInstance.test(args);
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
    public TestResult test(TestArgs args) throws Exception {
        return TestResult.parseFrom(call("KclService.Test", args.toByteArray()));
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
     * UpdateDependenciesResult result = api.updateDependencies(
     *         UpdateDependenciesArgs.newBuilder().setManifestPath("/path/to/module").build());
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
    public UpdateDependenciesResult updateDependencies(UpdateDependenciesArgs args) throws Exception {
        return UpdateDependenciesResult.parseFrom(call("KclService.UpdateDependencies", args.toByteArray()));
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
    public GetVersionResult getVersion(GetVersionArgs args) throws Exception {
        return GetVersionResult.parseFrom(call("KclService.GetVersion", args.toByteArray()));
    }

    private byte[] call(String name, byte[] args) throws Exception {
        byte[] result = callNative(name.getBytes(), args);
        if (result != null && startsWith(result, ERROR_PREFIX)) {
            String resultString = new String(result, StandardCharsets.UTF_8);
            throw new Exception(resultString.substring(ERROR_PREFIX.length()).trim());
        }
        return result;
    }

    private byte[] callLoadPackageWithCache(byte[] args) throws Exception {
        byte[] result = loadPackageWithCache(args);
        if (result != null && startsWith(result, ERROR_PREFIX)) {
            String resultString = new String(result, StandardCharsets.UTF_8);
            throw new Exception(resultString.substring(ERROR_PREFIX.length()).trim());
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

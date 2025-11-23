import kcl_lib
import kcl_lib.plugin as plugin
from .spec_pb2 import (
    PingArgs,
    PingResult,
    GetVersionArgs,
    GetVersionResult,
    ParseFileArgs,
    ParseFileResult,
    ParseProgramArgs,
    ParseProgramResult,
    LoadPackageArgs,
    LoadPackageResult,
    ListOptionsResult,
    ExecProgramArgs,
    ExecProgramResult,
    BuildProgramArgs,
    BuildProgramResult,
    ExecArtifactArgs,
    FormatCodeArgs,
    FormatCodeResult,
    FormatPathArgs,
    FormatPathResult,
    LintPathArgs,
    LintPathResult,
    OverrideFileArgs,
    OverrideFileResult,
    ListVariablesArgs,
    ListVariablesResult,
    GetSchemaTypeMappingArgs,
    GetSchemaTypeMappingResult,
    ValidateCodeArgs,
    ValidateCodeResult,
    ListDepFilesArgs,
    ListDepFilesResult,
    LoadSettingsFilesArgs,
    LoadSettingsFilesResult,
    RenameArgs,
    RenameResult,
    RenameCodeArgs,
    RenameCodeResult,
    TestArgs,
    TestResult,
    UpdateDependenciesArgs,
    UpdateDependenciesResult,
)
from google.protobuf import message as _message


class API:
    """KCL APIs

    ## Examples

    Python Code

    ```python
    import kcl_lib.api as api
    args = api.ExecProgramArgs(k_filename_list=["a.k"])
    api = api.API()

    result = api.exec_program(args)
    print(result.yaml_result)
    ```
    """

    def __init__(self, plugin_agent: int = plugin.plugin_agent_addr):
        self.plugin_agent = plugin_agent

    def ping(self, args: PingArgs) -> PingResult:
        return self.call("KclService.Ping", args)

    def parse_program(self, args: ParseProgramArgs) -> ParseProgramResult:
        """Parse KCL program with entry files and return the AST JSON string.

        ## Example

        The content of `schema.k` is

        ```python
        schema AppConfig:
           replicas: int
        app: AppConfig {
           replicas: 2
        }
        ```

        Python Code

        ```python
        import kcl_lib.api as api

        args = api.ParseProgramArgs(paths=["schema.k"])
        api = api.API()
        result = api.parse_program(args)
        assert len(result.paths) == 1
        assert len(result.errors) == 0
        ```
        """
        return self.call("KclService.ParseProgram", args)

    def exec_program(self, args: ExecProgramArgs) -> ExecProgramResult:
        """Execute KCL file with arguments and return the JSON/YAML result.

        ## Examples

        The content of `schema.k` is

        ```python
        schema AppConfig:
            replicas: int
        app: AppConfig {
            replicas: 2
        }
        ```

        Python Code

        ```python
        import kcl_lib.api as api

        args = api.ExecProgramArgs(k_filename_list=["schema.k"])
        api = api.API()
        result = api.exec_program(args)
        ```

        A case with the file not found error

        ```python
        import kcl_lib.api as api
        try:
            args = api.ExecProgramArgs(k_filename_list=["file_not_found"])
            api = api.API()
            result = api.exec_program(args)
            assert False
        except Exception as err:
            assert "Cannot find the kcl file" in str(err)
        ```
        """
        return self.call("KclService.ExecProgram", args)

    def parse_file(self, args: ParseFileArgs) -> ParseFileResult:
        """Parse KCL single file to Module AST JSON string with import dependencies and parse errors.

        ## Example

        The content of `schema.k` is

        ```python
        schema AppConfig:
            replicas: int
        app: AppConfig {
            replicas: 2
        }
        ```

        Python Code

        ```python
        import kcl_lib.api as api

        args = api.ParseProgramArgs(paths=[TEST_FILE])
        api = api.API()
        result = api.parse_program(args)
        assert len(result.paths) == 1
        assert len(result.errors) == 0
        ```
        """
        return self.call("KclService.ParseFile", args)

    def parse_program(self, args: ParseProgramArgs) -> ParseProgramResult:
        """Parse KCL program with entry files and return the AST JSON string.

        ## Example

        The content of `schema.k` is

        ```python
        schema AppConfig:
            replicas: int
        app: AppConfig {
            replicas: 2
        }
        ```

        Python Code

        ```python
        import kcl_lib.api as api

        args = api.ParseProgramArgs(paths=["schema.k"])
        api = api.API()
        result = api.parse_program(args)
        assert len(result.paths) == 1
        assert len(result.errors) == 0
        ```
        """
        return self.call("KclService.ParseProgram", args)

    def load_package(self, args: LoadPackageArgs) -> LoadPackageResult:
        """load_package provides users with the ability to parse KCL program and semantic model information including symbols, types, definitions, etc.

        ## Example

        The content of `schema.k` is

        ```python
        schema AppConfig:
            replicas: int
        app: AppConfig {
            replicas: 2
        }
        ```

        Python Code

        ```python
        import kcl_lib.api as api
        args = api.LoadPackageArgs(
            parse_args=api.ParseProgramArgs(paths=["schema.k"]), resolve_ast=True
        )
        api = api.API()
        result = api.load_package(args)
        assert list(result.symbols.values())[0].ty.schema_name == "AppConfig"
        ```
        """
        return self.call("KclService.LoadPackage", args)

    def list_options(self, args: ParseProgramArgs) -> ListOptionsResult:
        """list_options provides users with the ability to parse KCL program and get all option information.

        ## Example

        The content of `options.k` is

        ```python
        a = option("key1")
        b = option("key2", required=True)
        c = {
            metadata.key = option("metadata-key")
        }
        ```

        Python Code

        ```python
        import kcl_lib.api as api

        args = api.ParseProgramArgs(paths=["options.k"])
        api = api.API()
        result = api.list_options(args)
        assert len(result.options) == 3
        assert result.options[0].name == "key1"
        assert result.options[1].name == "key2"
        assert result.options[2].name == "metadata-key"
        ```
        """
        return self.call("KclService.ListOptions", args)

    def list_variables(self, args: ListVariablesArgs) -> ListVariablesResult:
        """list_variables provides users with the ability to parse KCL program and get all variables by specs.

        ## Example

        The content of `schema.k` is

        ```python
        schema AppConfig:
            replicas: int
        app: AppConfig {
            replicas: 2
        }
        ```

        Python Code

        ```python
        import kcl_lib.api as api

        args = api.ListVariablesArgs(files=[TEST_FILE])
        api = api.API()
        result = api.list_variables(args)
        ```
        """
        return self.call("KclService.ListVariables", args)

    def format_code(self, args: FormatCodeArgs) -> FormatCodeResult:
        """Format the code source.

        ## Example

        Python Code

        ```python
        import kcl_lib.api as api
        source_code = "a   =   1"
        args = api.FormatCodeArgs(source=source_code)
        api_instance = api.API()

        result = api_instance.format_code(args)
        assert result.formatted.decode(), "a = 1"
        ```
        """
        return self.call("KclService.FormatCode", args)

    def format_path(self, args: FormatPathArgs) -> FormatPathResult:
        """Format KCL file or directory path contains KCL files and returns the changed file paths.

        ## Example

        The content of `format_path.k` is

        ```python
        schema Person:
            name:   str
            age:    int
            check:
                0 <   age <   120
        ```

        Python Code

        ```python
        import kcl_lib.api as api

        args = api.FormatPathArgs(path="format_path.k")
        api_instance = api.API()
        result = api_instance.format_path(args)
        print(result)
        ```
        """
        return self.call("KclService.FormatPath", args)

    def lint_path(self, args: LintPathArgs) -> LintPathResult:
        """Lint files and return error messages including errors and warnings.

        ## Example

        The content of `lint_path.k` is

        ```python
        import math

        ```

        Python Code

        ```python
        import kcl_lib.api as api

        args = api.LintPathArgs(paths=["lint_path.k"])
        api_instance = api.API()
        result = api_instance.lint_path(args)
        ```
        """
        return self.call("KclService.LintPath", args)

    def override_file(self, args: OverrideFileArgs) -> OverrideFileResult:
        """Override KCL file with arguments. See [https://www.kcl-lang.io/docs/user_docs/guides/automation](https://www.kcl-lang.io/docs/user_docs/guides/automation) for more override spec guide.

        ## Example

        The content of `main.k` is

        ```python
        a = 1
        b = {
            "a": 1
            "b": 2
        }
        ```

        Python Code

        ```python
        import kcl_lib.api as api
        import pathlib

        test_file = "main.k"
        args = api.OverrideFileArgs(
            file=test_file,
            specs=["b.a=2"],
        )
        api = api.API()
        result = api.override_file(args)
        assert len(result.parse_errors) == 0
        assert result.result == True
        assert pathlib.Path(test_file).read_text() == \"\"\"a = 1
        b = {
            "a": 2
            "b": 2
        }
        \"\"\"
        ```
        """
        return self.call("KclService.OverrideFile", args)

    def get_schema_type_mapping(
        self,
        args: GetSchemaTypeMappingArgs,
    ) -> GetSchemaTypeMappingResult:
        """Get schema type mapping defined in the program.

        ## Example

        The content of `schema.k` is

        ```python
        schema AppConfig:
            replicas: int
        app: AppConfig {
            replicas: 2
        }
        ```

        Python Code

        ```python
        import kcl_lib.api as api

        exec_args = api.ExecProgramArgs(k_filename_list=["schema.k"])
        args = api.GetSchemaTypeMappingArgs(exec_args=exec_args)
        api = api.API()
        result = api.get_schema_type_mapping(args)
        assert result.schema_type_mapping["app"].properties["replicas"].type == "int"
        ```
        """
        return self.call("KclService.GetSchemaTypeMapping", args)

    def validate_code(self, args: ValidateCodeArgs) -> ValidateCodeResult:
        """Validate code using schema and JSON/YAML data strings.

        ## Example
        Python Code

        ```python
        import kcl_lib.api as api

        code = \"\"\"
        schema Person:
            name: str
            age: int
            check:
                0 < age < 120
        \"\"\"
        data = '{"name": "Alice", "age": 10}'
        args = api.ValidateCodeArgs(code=code, data=data, format="json")
        api_instance = api.API()
        result = api_instance.validate_code(args)
        assert result.success == True
        assert result.err_message == ""
        ```
        """
        return self.call("KclService.ValidateCode", args)

    def load_settings_files(
        self,
        args: LoadSettingsFilesArgs,
    ) -> LoadSettingsFilesResult:
        """Load the setting file config defined in `kcl.yaml`

        ## Example

        The content of `kcl.yaml` is

        ```yaml
        kcl_cli_configs:
          strict_range_check: true
        kcl_options:
          - key: key
            value: value
        ```

        Python Code

        ```python
        import kcl_lib.api as api
        args = api.LoadSettingsFilesArgs(
            work_dir=".", files=["kcl.yaml"]
        )
        api_instance = api.API()
        result = api_instance.load_settings_files(args)
        assert result.kcl_cli_configs.files == []
        assert result.kcl_cli_configs.strict_range_check == True
        assert (
            result.kcl_options[0].key == "key" and result.kcl_options[0].value == '"value"'
        )
        ```
        """
        return self.call("KclService.LoadSettingsFiles", args)

    def rename(self, args: RenameArgs) -> RenameResult:
        """Rename all the occurrences of the target symbol in the files. This API will rewrite files if they contain symbols to be renamed. Return the file paths that got changed.

        ## Example

        The content of main.k is

        ```python

        a = 1
        b = a
        ```

        Python Code

        ```python
        import kcl_lib.api as api
        args = api.RenameArgs(
            package_root=".",
            symbol_path="a",
            file_paths=["main.k"],
            new_name="a2",
        )
        api_instance = api.API()
        result = api_instance.rename(args)
        ```
        """
        return self.call("KclService.Rename", args)

    def rename_code(self, args: RenameCodeArgs) -> RenameCodeResult:
        """Rename all the occurrences of the target symbol and return the modified code if any code has been changed. This API won't rewrite files but return the changed code.

        ## Example

        Python Code

        ```python
        import kcl_lib.api as api
        args = api.RenameCodeArgs(
            package_root="/mock/path",
            symbol_path="a",
            source_codes={"/mock/path/main.k": "a = 1"},
            new_name="a2",
        )
        api_instance = api.API()
        result = api_instance.rename_code(args)
        assert result.changed_codes["/mock/path/main.k"] == "a2 = 1"
        ```
        """
        return self.call("KclService.RenameCode", args)

    def test(self, args: TestArgs) -> TestResult:
        """Test KCL packages with test arguments.

        ## Example

        Python Code

        ```python
        import kcl_lib.api as api
        args = api.TestArgs(
            pkg_list=["path/to/testing/pkg/..."],
        )
        api_instance = api.API()
        result = api_instance.test(args)
        ```
        """
        return self.call("KclService.Test", args)

    def update_dependencies(
        self, args: UpdateDependenciesArgs
    ) -> UpdateDependenciesResult:
        """Download and update dependencies defined in the `kcl.mod` file and return the external package name and location list.

        ## Examples

        The content of `module/kcl.mod` is

        ```yaml
        [package]
        name = "mod_update"
        edition = "0.0.1"
        version = "0.0.1"

        [dependencies]
        helloworld = { oci = "oci://ghcr.io/kcl-lang/helloworld", tag = "0.1.0" }
        flask = { git = "https://github.com/kcl-lang/flask-demo-kcl-manifests", commit = "ade147b" }
        ```

        Python Code

        ```python
        import kcl_lib.api as api
        args = api.UpdateDependenciesArgs(
            manifest_path="module"
        )
        api_instance = api.API()
        result = api_instance.update_dependencies(args)
        pkg_names = [pkg.pkg_name for pkg in result.external_pkgs]
        assert len(pkg_names) == 2
        assert "helloworld" in pkg_names
        assert "flask" in pkg_names
        ```

        Call `exec_program` with external dependencies

        The content of `module/kcl.mod` is

        ```yaml
        [package]
        name = "mod_update"
        edition = "0.0.1"
        version = "0.0.1"

        [dependencies]
        helloworld = { oci = "oci://ghcr.io/kcl-lang/helloworld", tag = "0.1.0" }
        flask = { git = "https://github.com/kcl-lang/flask-demo-kcl-manifests", commit = "ade147b" }
        ```

        The content of `module/main.k` is

        ```python
        import helloworld
        import flask
        a = helloworld.The_first_kcl_program
        ```

        Python Code

        ```python
        import kcl_lib.api as api
        args = api.UpdateDependenciesArgs(
            manifest_path="module"
        )
        api_instance = api.API()
        result = api_instance.update_dependencies(args)
        exec_args = api.ExecProgramArgs(
            k_filename_list=["module/main.k"],
            external_pkgs=result.external_pkgs,
        )
        result = api_instance.exec_program(exec_args)
        assert result.yaml_result == "a: Hello World!"
        ```
        """
        return self.call("KclService.UpdateDependencies", args)

    def get_version(self) -> GetVersionResult:
        """Return the KCL service version information.

        ## Example

        Python Code

        ```python
        import kcl_lib.api as api

        api_instance = api.API()
        result = api_instance.get_version()
        print(result.version_info)
        ```
        """
        return self.call("KclService.GetVersion", GetVersionArgs())

    # Helper method to perform the call
    def call(self, name: str, args):
        """Call KCL API with the API name and argument protobuf bytes."""
        # Serialize arguments using pickle or json
        args_serialized = args.SerializeToString()
        # Call the service function and get the result
        result = bytes(
            kcl_lib.call_with_plugin_agent(
                name.encode("utf-8"), args_serialized, self.plugin_agent
            )
        )
        if result.startswith(b"ERROR:"):
            raise Exception(result.decode(encoding="utf-8").removeprefix("ERROR:"))
        msg = self.create_method_resp_message(name)
        msg.ParseFromString(result)
        return msg

    def create_method_req_message(self, method: str) -> _message.Message:
        if method in ["Ping", "KclService.Ping"]:
            return PingArgs()
        elif method in ["ExecProgram", "KclService.ExecProgram"]:
            return ExecProgramArgs()
        elif method in ["BuildProgram", "KclService.BuildProgram"]:
            return BuildProgramArgs()
        elif method in ["ExecArtifact", "KclService.ExecArtifact"]:
            return ExecArtifactArgs()
        elif method in ["ParseFile", "KclService.ParseFile"]:
            return ParseFileArgs()
        elif method in ["ParseProgram", "KclService.ParseProgram"]:
            return ParseProgramArgs()
        elif method in ["LoadPackage", "KclService.LoadPackage"]:
            return LoadPackageArgs()
        elif method in ["ListOptions", "KclService.ListOptions"]:
            return ParseProgramArgs()
        elif method in ["ListVariables", "KclService.ListVariables"]:
            return ListVariablesArgs()
        elif method in ["FormatCode", "KclService.FormatCode"]:
            return FormatCodeArgs()
        elif method in ["FormatPath", "KclService.FormatPath"]:
            return FormatPathArgs()
        elif method in ["LintPath", "KclService.LintPath"]:
            return LintPathArgs()
        elif method in ["OverrideFile", "KclService.OverrideFile"]:
            return OverrideFileArgs()
        elif method in ["GetSchemaTypeMapping", "KclService.GetSchemaTypeMapping"]:
            return GetSchemaTypeMappingArgs()
        elif method in ["ValidateCode", "KclService.ValidateCode"]:
            return ValidateCodeArgs()
        elif method in ["ListDepFiles", "KclService.ListDepFiles"]:
            return ListDepFilesArgs()
        elif method in ["LoadSettingsFiles", "KclService.LoadSettingsFiles"]:
            return LoadSettingsFilesArgs()
        elif method in ["Rename", "KclService.Rename"]:
            return RenameArgs()
        elif method in ["RenameCode", "KclService.RenameCode"]:
            return RenameCodeArgs()
        elif method in ["Test", "KclService.Test"]:
            return TestArgs()
        elif method in ["UpdateDependencies", "KclService.UpdateDependencies"]:
            return UpdateDependenciesArgs()
        elif method in ["GetVersion", "KclService.GetVersion"]:
            return GetVersionArgs()
        raise Exception(f"unknown method: {method}")

    def create_method_resp_message(self, method: str) -> _message.Message:
        if method in ["Ping", "KclService.Ping"]:
            return PingResult()
        elif method in ["ExecProgram", "KclService.ExecProgram"]:
            return ExecProgramResult()
        elif method in ["BuildProgram", "KclService.BuildProgram"]:
            return BuildProgramResult()
        elif method in ["ExecArtifact", "KclService.ExecArtifact"]:
            return ExecProgramResult()
        elif method in ["ParseFile", "KclService.ParseFile"]:
            return ParseFileResult()
        elif method in ["ParseProgram", "KclService.ParseProgram"]:
            return ParseProgramResult()
        elif method in ["LoadPackage", "KclService.LoadPackage"]:
            return LoadPackageResult()
        elif method in ["ListOptions", "KclService.ListOptions"]:
            return ListOptionsResult()
        elif method in ["ListVariables", "KclService.ListVariables"]:
            return ListVariablesResult()
        elif method in ["FormatCode", "KclService.FormatCode"]:
            return FormatCodeResult()
        elif method in ["FormatPath", "KclService.FormatPath"]:
            return FormatPathResult()
        elif method in ["LintPath", "KclService.LintPath"]:
            return LintPathResult()
        elif method in ["OverrideFile", "KclService.OverrideFile"]:
            return OverrideFileResult()
        elif method in ["GetSchemaTypeMapping", "KclService.GetSchemaTypeMapping"]:
            return GetSchemaTypeMappingResult()
        elif method in ["ValidateCode", "KclService.ValidateCode"]:
            return ValidateCodeResult()
        elif method in ["ListDepFiles", "KclService.ListDepFiles"]:
            return ListDepFilesResult()
        elif method in ["LoadSettingsFiles", "KclService.LoadSettingsFiles"]:
            return LoadSettingsFilesResult()
        elif method in ["Rename", "KclService.Rename"]:
            return RenameResult()
        elif method in ["RenameCode", "KclService.RenameCode"]:
            return RenameCodeResult()
        elif method in ["Test", "KclService.Test"]:
            return TestResult()
        elif method in ["UpdateDependencies", "KclService.UpdateDependencies"]:
            return UpdateDependenciesResult()
        elif method in ["GetVersion", "KclService.GetVersion"]:
            return GetVersionResult()
        raise Exception(f"unknown method: {method}")

import kcl_lib
import kcl_lib.plugin as plugin
from .spec_pb2 import (
    Ping_Args,
    Ping_Result,
    GetVersion_Args,
    GetVersion_Result,
    ParseFile_Args,
    ParseFile_Result,
    ParseProgram_Args,
    ParseProgram_Result,
    LoadPackage_Args,
    LoadPackage_Result,
    ListOptions_Result,
    ExecProgram_Args,
    ExecProgram_Result,
    BuildProgram_Args,
    BuildProgram_Result,
    ExecArtifact_Args,
    FormatCode_Args,
    FormatCode_Result,
    FormatPath_Args,
    FormatPath_Result,
    LintPath_Args,
    LintPath_Result,
    OverrideFile_Args,
    OverrideFile_Result,
    ListVariables_Args,
    ListVariables_Result,
    GetSchemaTypeMapping_Args,
    GetSchemaTypeMapping_Result,
    ValidateCode_Args,
    ValidateCode_Result,
    ListDepFiles_Args,
    ListDepFiles_Result,
    LoadSettingsFiles_Args,
    LoadSettingsFiles_Result,
    Rename_Args,
    Rename_Result,
    RenameCode_Args,
    RenameCode_Result,
    Test_Args,
    Test_Result,
    UpdateDependencies_Args,
    UpdateDependencies_Result,
)
from google.protobuf import message as _message


class API:
    """KCL APIs

    ## Examples

    Python Code

    ```python
    import kcl_lib.api as api
    args = api.ExecProgram_Args(k_filename_list=["a.k"])
    api = api.API()

    result = api.exec_program(args)
    print(result.yaml_result)
    ```
    """

    def __init__(self, plugin_agent: int = plugin.plugin_agent_addr):
        self.plugin_agent = plugin_agent

    def ping(self, args: Ping_Args) -> Ping_Result:
        return self.call("KclvmService.Ping", args)

    def parse_program(self, args: ParseProgram_Args) -> ParseProgram_Result:
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

        args = api.ParseProgram_Args(paths=["schema.k"])
        api = api.API()
        result = api.parse_program(args)
        assert len(result.paths) == 1
        assert len(result.errors) == 0
        ```
        """
        return self.call("KclvmService.ParseProgram", args)

    def exec_program(self, args: ExecProgram_Args) -> ExecProgram_Result:
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

        args = api.ExecProgram_Args(k_filename_list=["schema.k"])
        api = api.API()
        result = api.exec_program(args)
        ```

        A case with the file not found error

        ```python
        import kcl_lib.api as api
        try:
            args = api.ExecProgram_Args(k_filename_list=["file_not_found"])
            api = api.API()
            result = api.exec_program(args)
            assert False
        except Exception as err:
            assert "Cannot find the kcl file" in str(err)
        ```
        """
        return self.call("KclvmService.ExecProgram", args)

    def parse_file(self, args: ParseFile_Args) -> ParseFile_Result:
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

        args = api.ParseProgram_Args(paths=[TEST_FILE])
        api = api.API()
        result = api.parse_program(args)
        assert len(result.paths) == 1
        assert len(result.errors) == 0
        ```
        """
        return self.call("KclvmService.ParseFile", args)

    def parse_program(self, args: ParseProgram_Args) -> ParseProgram_Result:
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

        args = api.ParseProgram_Args(paths=["schema.k"])
        api = api.API()
        result = api.parse_program(args)
        assert len(result.paths) == 1
        assert len(result.errors) == 0
        ```
        """
        return self.call("KclvmService.ParseProgram", args)

    def load_package(self, args: LoadPackage_Args) -> LoadPackage_Result:
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
        args = api.LoadPackage_Args(
            parse_args=api.ParseProgram_Args(paths=["schema.k"]), resolve_ast=True
        )
        api = api.API()
        result = api.load_package(args)
        assert list(result.symbols.values())[0].ty.schema_name == "AppConfig"
        ```
        """
        return self.call("KclvmService.LoadPackage", args)

    def list_options(self, args: ParseProgram_Args) -> ListOptions_Result:
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

        args = api.ParseProgram_Args(paths=["options.k"])
        api = api.API()
        result = api.list_options(args)
        assert len(result.options) == 3
        assert result.options[0].name == "key1"
        assert result.options[1].name == "key2"
        assert result.options[2].name == "metadata-key"
        ```
        """
        return self.call("KclvmService.ListOptions", args)

    def list_variables(self, args: ListVariables_Args) -> ListVariables_Result:
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

        args = api.ListVariables_Args(files=[TEST_FILE])
        api = api.API()
        result = api.list_variables(args)
        ```
        """
        return self.call("KclvmService.ListVariables", args)

    def format_code(self, args: FormatCode_Args) -> FormatCode_Result:
        """Format the code source.

        ## Example

        Python Code

        ```python
        import kcl_lib.api as api
        source_code = "a   =   1"
        args = api.FormatCode_Args(source=source_code)
        api_instance = api.API()

        result = api_instance.format_code(args)
        assert result.formatted.decode(), "a = 1"
        ```
        """
        return self.call("KclvmService.FormatCode", args)

    def format_path(self, args: FormatPath_Args) -> FormatPath_Result:
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

        args = api.FormatPath_Args(path="format_path.k")
        api_instance = api.API()
        result = api_instance.format_path(args)
        print(result)
        ```
        """
        return self.call("KclvmService.FormatPath", args)

    def lint_path(self, args: LintPath_Args) -> LintPath_Result:
        """Lint files and return error messages including errors and warnings.

        ## Example

        The content of `lint_path.k` is

        ```python
        import math

        ```

        Python Code

        ```python
        import kcl_lib.api as api

        args = api.LintPath_Args(paths=["lint_path.k"])
        api_instance = api.API()
        result = api_instance.lint_path(args)
        ```
        """
        return self.call("KclvmService.LintPath", args)

    def override_file(self, args: OverrideFile_Args) -> OverrideFile_Result:
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
        args = api.OverrideFile_Args(
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
        return self.call("KclvmService.OverrideFile", args)

    def get_schema_type_mapping(
        self,
        args: GetSchemaTypeMapping_Args,
    ) -> GetSchemaTypeMapping_Result:
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

        exec_args = api.ExecProgram_Args(k_filename_list=["schema.k"])
        args = api.GetSchemaTypeMapping_Args(exec_args=exec_args)
        api = api.API()
        result = api.get_schema_type_mapping(args)
        assert result.schema_type_mapping["app"].properties["replicas"].type == "int"
        ```
        """
        return self.call("KclvmService.GetSchemaTypeMapping", args)

    def validate_code(self, args: ValidateCode_Args) -> ValidateCode_Result:
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
        args = api.ValidateCode_Args(code=code, data=data, format="json")
        api_instance = api.API()
        result = api_instance.validate_code(args)
        assert result.success == True
        assert result.err_message == ""
        ```
        """
        return self.call("KclvmService.ValidateCode", args)

    def load_settings_files(
        self,
        args: LoadSettingsFiles_Args,
    ) -> LoadSettingsFiles_Result:
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
        args = api.LoadSettingsFiles_Args(
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
        return self.call("KclvmService.LoadSettingsFiles", args)

    def rename(self, args: Rename_Args) -> Rename_Result:
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
        args = api.Rename_Args(
            package_root=".",
            symbol_path="a",
            file_paths=["main.k"],
            new_name="a2",
        )
        api_instance = api.API()
        result = api_instance.rename(args)
        ```
        """
        return self.call("KclvmService.Rename", args)

    def rename_code(self, args: RenameCode_Args) -> RenameCode_Result:
        """Rename all the occurrences of the target symbol and return the modified code if any code has been changed. This API won't rewrite files but return the changed code.

        ## Example

        Python Code

        ```python
        import kcl_lib.api as api
        args = api.RenameCode_Args(
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
        return self.call("KclvmService.RenameCode", args)

    def test(self, args: Test_Args) -> Test_Result:
        """Test KCL packages with test arguments.

        ## Example

        Python Code

        ```python
        import kcl_lib.api as api
        args = api.Test_Args(
            pkg_list=["path/to/testing/pkg/..."],
        )
        api_instance = api.API()
        result = api_instance.test(args)
        ```
        """
        return self.call("KclvmService.Test", args)

    def update_dependencies(
        self, args: UpdateDependencies_Args
    ) -> UpdateDependencies_Result:
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
        args = api.UpdateDependencies_Args(
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
        args = api.UpdateDependencies_Args(
            manifest_path="module"
        )
        api_instance = api.API()
        result = api_instance.update_dependencies(args)
        exec_args = api.ExecProgram_Args(
            k_filename_list=["module/main.k"],
            external_pkgs=result.external_pkgs,
        )
        result = api_instance.exec_program(exec_args)
        assert result.yaml_result == "a: Hello World!"
        ```
        """
        return self.call("KclvmService.UpdateDependencies", args)

    def get_version(self) -> GetVersion_Result:
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
        return self.call("KclvmService.GetVersion", GetVersion_Args())

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
        if method in ["Ping", "KclvmService.Ping"]:
            return Ping_Args()
        elif method in ["ExecProgram", "KclvmService.ExecProgram"]:
            return ExecProgram_Args()
        elif method in ["BuildProgram", "KclvmService.BuildProgram"]:
            return BuildProgram_Args()
        elif method in ["ExecArtifact", "KclvmService.ExecArtifact"]:
            return ExecArtifact_Args()
        elif method in ["ParseFile", "KclvmService.ParseFile"]:
            return ParseFile_Args()
        elif method in ["ParseProgram", "KclvmService.ParseProgram"]:
            return ParseProgram_Args()
        elif method in ["LoadPackage", "KclvmService.LoadPackage"]:
            return LoadPackage_Args()
        elif method in ["ListOptions", "KclvmService.ListOptions"]:
            return ParseProgram_Args()
        elif method in ["ListVariables", "KclvmService.ListVariables"]:
            return ListVariables_Args()
        elif method in ["FormatCode", "KclvmService.FormatCode"]:
            return FormatCode_Args()
        elif method in ["FormatPath", "KclvmService.FormatPath"]:
            return FormatPath_Args()
        elif method in ["LintPath", "KclvmService.LintPath"]:
            return LintPath_Args()
        elif method in ["OverrideFile", "KclvmService.OverrideFile"]:
            return OverrideFile_Args()
        elif method in ["GetSchemaTypeMapping", "KclvmService.GetSchemaTypeMapping"]:
            return GetSchemaTypeMapping_Args()
        elif method in ["ValidateCode", "KclvmService.ValidateCode"]:
            return ValidateCode_Args()
        elif method in ["ListDepFiles", "KclvmService.ListDepFiles"]:
            return ListDepFiles_Args()
        elif method in ["LoadSettingsFiles", "KclvmService.LoadSettingsFiles"]:
            return LoadSettingsFiles_Args()
        elif method in ["Rename", "KclvmService.Rename"]:
            return Rename_Args()
        elif method in ["RenameCode", "KclvmService.RenameCode"]:
            return RenameCode_Args()
        elif method in ["Test", "KclvmService.Test"]:
            return Test_Args()
        elif method in ["UpdateDependencies", "KclvmService.UpdateDependencies"]:
            return UpdateDependencies_Args()
        elif method in ["GetVersion", "KclvmService.GetVersion"]:
            return GetVersion_Args()
        raise Exception(f"unknown method: {method}")

    def create_method_resp_message(self, method: str) -> _message.Message:
        if method in ["Ping", "KclvmService.Ping"]:
            return Ping_Result()
        elif method in ["ExecProgram", "KclvmService.ExecProgram"]:
            return ExecProgram_Result()
        elif method in ["BuildProgram", "KclvmService.BuildProgram"]:
            return BuildProgram_Result()
        elif method in ["ExecArtifact", "KclvmService.ExecArtifact"]:
            return ExecProgram_Result()
        elif method in ["ParseFile", "KclvmService.ParseFile"]:
            return ParseFile_Result()
        elif method in ["ParseProgram", "KclvmService.ParseProgram"]:
            return ParseProgram_Result()
        elif method in ["LoadPackage", "KclvmService.LoadPackage"]:
            return LoadPackage_Result()
        elif method in ["ListOptions", "KclvmService.ListOptions"]:
            return ListOptions_Result()
        elif method in ["ListVariables", "KclvmService.ListVariables"]:
            return ListVariables_Result()
        elif method in ["FormatCode", "KclvmService.FormatCode"]:
            return FormatCode_Result()
        elif method in ["FormatPath", "KclvmService.FormatPath"]:
            return FormatPath_Result()
        elif method in ["LintPath", "KclvmService.LintPath"]:
            return LintPath_Result()
        elif method in ["OverrideFile", "KclvmService.OverrideFile"]:
            return OverrideFile_Result()
        elif method in ["GetSchemaTypeMapping", "KclvmService.GetSchemaTypeMapping"]:
            return GetSchemaTypeMapping_Result()
        elif method in ["ValidateCode", "KclvmService.ValidateCode"]:
            return ValidateCode_Result()
        elif method in ["ListDepFiles", "KclvmService.ListDepFiles"]:
            return ListDepFiles_Result()
        elif method in ["LoadSettingsFiles", "KclvmService.LoadSettingsFiles"]:
            return LoadSettingsFiles_Result()
        elif method in ["Rename", "KclvmService.Rename"]:
            return Rename_Result()
        elif method in ["RenameCode", "KclvmService.RenameCode"]:
            return RenameCode_Result()
        elif method in ["Test", "KclvmService.Test"]:
            return Test_Result()
        elif method in ["UpdateDependencies", "KclvmService.UpdateDependencies"]:
            return UpdateDependencies_Result()
        elif method in ["GetVersion", "KclvmService.GetVersion"]:
            return GetVersion_Result()
        raise Exception(f"unknown method: {method}")

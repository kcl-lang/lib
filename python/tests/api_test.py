TEST_FILE = "./tests/test_data/schema.k"


def test_exec_api():
    import kcl_lib.api as api

    # Call the `exec_program` method with appropriate arguments
    args = api.ExecProgram_Args(k_filename_list=[TEST_FILE])
    # Usage
    api = api.API()
    result = api.exec_program(args)
    assert result.yaml_result == "app:\n  replicas: 2"


def test_exec_api_failed():
    import kcl_lib.api as api

    try:
        # Call the `exec_program` method with appropriate arguments
        args = api.ExecProgram_Args(k_filename_list=["file_not_found"])
        # Usage
        api = api.API()
        result = api.exec_program(args)
        assert False
    except Exception as err:
        assert "Cannot find the kcl file" in str(err)


def test_load_package_api():
    import kcl_lib.api as api

    # Call the `exec_program` method with appropriate arguments
    args = api.LoadPackage_Args(
        parse_args=api.ParseProgram_Args(paths=[TEST_FILE]), resolve_ast=True
    )
    # Usage
    api = api.API()
    result = api.load_package(args)
    assert list(result.symbols.values())[0].ty.schema_name == "AppConfig"


def test_list_variable_api():
    import kcl_lib.api as api

    # Call the `exec_program` method with appropriate arguments
    args = api.ListVariables_Args(files=[TEST_FILE])
    # Usage
    api = api.API()
    result = api.list_variables(args)
    assert result.variables["app"].variables[0].value == "AppConfig {replicas: 2}"


def test_get_schema_type_api():
    import kcl_lib.api as api

    exec_args = api.ExecProgram_Args(k_filename_list=[TEST_FILE])
    # Call the `exec_program` method with appropriate arguments
    args = api.GetSchemaTypeMapping_Args(exec_args=exec_args)
    # Usage
    api = api.API()
    result = api.get_schema_type_mapping(args)
    assert result.schema_type_mapping["app"].properties["replicas"].type == "int"


def test_format_code_api():
    import kcl_lib.api as api

    source_code = """\
schema Person:
    name:   str
    age:    int

    check:
        0 <   age <   120
"""

    args = api.FormatCode_Args(source=source_code)

    api_instance = api.API()
    result = api_instance.format_code(args)

    assert (
        result.formatted.decode()
        == """\
schema Person:
    name: str
    age: int

    check:
        0 < age < 120

"""
    )


def test_format_path_api():
    import kcl_lib.api as api

    TEST_PATH = "./tests/test_data/format_path/test.k"

    args = api.FormatPath_Args(path=TEST_PATH)

    api_instance = api.API()
    result = api_instance.format_path(args)

    assert result.changed_paths == []


def test_lint_path_api():
    import kcl_lib.api as api

    TEST_PATH = "./tests/test_data/lint_path/test-lint.k"

    args = api.LintPath_Args(paths=[TEST_PATH])

    api_instance = api.API()
    result = api_instance.lint_path(args)

    assert "Module 'math' imported but unused" in result.results


def test_validate_code_api():
    import kcl_lib.api as api

    code = """\
schema Person:
    name: str
    age: int

    check:
        0 < age < 120
"""
    data = '{"name": "Alice", "age": 10}'

    args = api.ValidateCode_Args(code=code, data=data, format="json")

    api_instance = api.API()
    result = api_instance.validate_code(args)

    assert result.success == True
    assert result.err_message == ""


def test_rename_api():
    import kcl_lib.api as api
    import pathlib

    pathlib.Path("./tests/test_data/rename/main.k").write_text(
        pathlib.Path("./tests/test_data/rename/main.bak").read_text()
    )

    args = api.Rename_Args(
        package_root="./tests/test_data/rename",
        symbol_path="a",
        file_paths=["./tests/test_data/rename/main.k"],
        new_name="a2",
    )

    api_instance = api.API()
    result = api_instance.rename(args)

    assert "tests/test_data/rename/main.k" in result.changed_files[0]


def test_rename_code_api():
    import kcl_lib.api as api

    args = api.RenameCode_Args(
        package_root="/mock/path",
        symbol_path="a",
        source_codes={"/mock/path/main.k": "a = 1\nb = a"},
        new_name="a2",
    )

    api_instance = api.API()
    result = api_instance.rename_code(args)

    assert result.changed_codes["/mock/path/main.k"] == "a2 = 1\nb = a2"


def test_load_settings_files_api():
    import kcl_lib.api as api

    args = api.LoadSettingsFiles_Args(
        work_dir="./tests/test_data", files=["./tests/test_data/settings/kcl.yaml"]
    )

    api_instance = api.API()
    result = api_instance.load_settings_files(args)

    assert result.kcl_cli_configs.files == []
    assert result.kcl_cli_configs.strict_range_check == True
    assert (
        result.kcl_options[0].key == "key" and result.kcl_options[0].value == '"value"'
    )


def test_update_dependencies_api():
    import kcl_lib.api as api

    args = api.UpdateDependencies_Args(
        manifest_path="./tests/test_data/update_dependencies"
    )

    api_instance = api.API()
    result = api_instance.update_dependencies(args)
    pkg_names = [pkg.pkg_name for pkg in result.external_pkgs]

    assert len(pkg_names) == 2
    assert "helloworld" in pkg_names
    assert "flask" in pkg_names


def test_exec_api_with_external_dependencies():
    import kcl_lib.api as api

    args = api.UpdateDependencies_Args(
        manifest_path="./tests/test_data/update_dependencies"
    )

    api_instance = api.API()
    result = api_instance.update_dependencies(args)
    exec_args = api.ExecProgram_Args(
        k_filename_list=["./tests/test_data/update_dependencies/main.k"],
        external_pkgs=result.external_pkgs,
    )
    result = api_instance.exec_program(exec_args)
    assert result.yaml_result == "a: Hello World!"

import kcl_lib.api as api

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

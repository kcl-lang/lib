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


def test_load_package_api():
    import kcl_lib.api as api

    # Call the `exec_program` method with appropriate arguments
    args = api.LoadPackage_Args(parse_args=api.ParseProgram_Args(paths=[TEST_FILE]), resolve_ast=True)
    # Usage
    api = api.API()
    result = api.load_package(args)
    assert list(result.symbols.values())[0].ty.schema_name == "AppConfig"


def test_list_variable_api():
    import kcl_lib.api as api

    # Call the `exec_program` method with appropriate arguments
    args = api.ListVariables_Args(file=TEST_FILE)
    # Usage
    api = api.API()
    result = api.list_variables(args)
    assert result.variables["app"].value == "AppConfig {replicas: 2}"

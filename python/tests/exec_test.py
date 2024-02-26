import os
import kcl_lib.bootstrap as bootstrap

os.environ[bootstrap.KCLVM_CLI_USE_TEST_ENV_VAR] = "ok"


def test_exec_api():
    import kcl_lib.api as api

    # Call the `exec_program` method with appropriate arguments
    args = api.ExecProgram_Args(k_filename_list=["./tests/test_data/schema.k"])
    # Usage
    api = api.API()
    result = api.exec_program(args)
    print(result.yaml_result)

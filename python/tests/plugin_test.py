import kcl_lib.plugin as plugin
import kcl_lib.api as api

TEST_FILE = "./tests/test_data/plugin.k"


def test_exec_api():
    plugin.register_plugin("my_plugin", {"add": lambda x, y: x + y})
    result = api.API().exec_program(api.ExecProgram_Args(k_filename_list=[TEST_FILE]))
    assert result.yaml_result == "result: 2"


def test_exec_api_failed():
    error_msg = "plugin error"

    def func(x, y):
        raise ValueError(error_msg)

    plugin.register_plugin("my_plugin", {"add": func})
    result = api.API().exec_program(api.ExecProgram_Args(k_filename_list=[TEST_FILE]))
    assert error_msg in result.err_message

import kcl_lib.plugin as plugin
import kcl_lib.api as api

TEST_FILE = "./tests/test_data/plugin.k"


def test_exec_api():
    plugin.register_plugin("my_plugin", {"add": lambda x, y: x + y})
    result = api.API(plugin.plugin_agent_addr).exec_program(
        api.ExecProgram_Args(k_filename_list=[TEST_FILE])
    )
    assert result.yaml_result == "result: 2"

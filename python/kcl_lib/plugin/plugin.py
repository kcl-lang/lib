import json
import typing
from ctypes import *
from dataclasses import dataclass


@dataclass
class Plugin:
    name: str
    method_map: typing.Dict[str, typing.Callable]


class PluginContext:
    def __init__(self):
        self._plugin_dict: typing.Dict[str, Plugin] = {}

    def call_method(self, name: str, args_json: str, kwargs_json: str) -> str:
        return self._call_py_method(name, args_json, kwargs_json)

    def _call_py_method(self, name: str, args_json: str, kwargs_json: str) -> str:
        try:
            return self._call_py_method_unsafe(name, args_json, kwargs_json)
        except Exception as e:
            return json.dumps({"__kcl_PanicInfo__": f"{e}"})

    def _call_py_method_unsafe(
        self, name: str, args_json: str, kwargs_json: str
    ) -> str:
        dotIdx = name.rfind(".")
        if dotIdx < 0:
            return ""

        # kcl_plugin.<module_path>.<method_name>
        module_path = name[:dotIdx]
        method_name = name[dotIdx + 1 :]
        plugin_name = module_path[module_path.rfind(".") + 1 :]

        method_func = self._plugin_dict.get(
            plugin_name, Plugin(name="", method_map={})
        ).method_map.get(method_name, None)

        args = []
        kwargs = {}

        if args_json:
            args = json.loads(args_json)
            if not isinstance(args, list):
                return ""

        if kwargs_json:
            kwargs = json.loads(kwargs_json)
            if not isinstance(kwargs, dict):
                return ""

        result = method_func(*args, **kwargs) if method_func else None
        return json.dumps(result)


__plugin_context__ = PluginContext()
__plugin_method_agent_buffer__ = create_string_buffer(1024)


def register_plugin(
    name: str, method_map: typing.Dict[str, typing.Callable]
) -> c_char_p:
    __plugin_context__._plugin_dict[name] = Plugin(name, method_map)


@CFUNCTYPE(c_char_p, c_char_p, c_char_p, c_char_p)
def plugin_method_agent(method: str, args_json: str, kwargs_json: str) -> c_char_p:
    method = str(method, encoding="utf-8")
    args_json = str(args_json, encoding="utf-8")
    kwargs_json = str(kwargs_json, encoding="utf-8")

    json_result = __plugin_context__.call_method(method, args_json, kwargs_json)

    global __plugin_method_agent_buffer__
    __plugin_method_agent_buffer__ = create_string_buffer(json_result.encode("utf-8"))
    return addressof(__plugin_method_agent_buffer__)


plugin_agent_addr = cast(plugin_method_agent, c_void_p).value

import ctypes
import tempfile
import threading
import os
from kcl_lib.bootstrap import (
    KCLVM_CLI_INSTALL_PATH_ENV_VAR,
    KCLVM_CLI_BIN_PATH_ENV_VAR,
    KCLVM_CLI_USE_TEST_ENV_VAR,
    lib_full_name,
    install_kclvm,
)
from kcl_lib.bootstrap.artifact import lib_path, LIB_ROOT
from .spec_pb2 import *
from ctypes import c_char_p, c_void_p
from google.protobuf import message as _message


class API:
    """KCL APIs

    Examples
    --------
    ```python
    import kcl_lib.api as api
    # Call the `exec_program` method with appropriate arguments
    args = api.ExecProgram_Args(k_filename_list=["a.k"])
    # Usage
    api = api.API()
    result = api.exec_program(args)
    print(result.yaml_result)
    ```
    """

    def __init__(self):
        self.caller = Caller()

    def ping(self, args: Ping_Args) -> Ping_Result:
        return self.caller.call("KclvmService.Ping", args)

    def parse_program(self, args: ParseProgram_Args) -> ParseProgram_Result:
        return self.caller.call("KclvmService.ParseProgram", args)

    def exec_program(self, args: ExecProgram_Args) -> ExecProgram_Result:
        return self.caller.call("KclvmService.ExecProgram", args)

    def build_program(self, args: BuildProgram_Args) -> BuildProgram_Result:
        return self.caller.call("KclvmService.BuildProgram", args)

    def exec_artifact(self, args: ExecArtifact_Args) -> ExecProgram_Result:
        return self.caller.call("KclvmService.ExecArtifact", args)

    def parse_file(self, args: ParseFile_Args) -> ParseFile_Result:
        return self.caller.call("KclvmService.ParseFile", args)

    def parse_program(self, args: ParseProgram_Args) -> ParseProgram_Result:
        return self.caller.call("KclvmService.ParseProgram", args)

    def load_package(self, args: LoadPackage_Args) -> LoadPackage_Result:
        return self.caller.call("KclvmService.LoadPackage", args)

    def format_code(self, args: FormatCode_Args) -> FormatCode_Result:
        return self.caller.call("KclvmService.FormatCode", args)

    def format_path(self, args: FormatPath_Args) -> FormatPath_Result:
        return self.caller.call("KclvmService.FormatPath", args)

    def lint_path(self, args: LintPath_Args) -> LintPath_Result:
        return self.caller.call("KclvmService.LintPath", args)

    def override_file(self, args: OverrideFile_Args) -> OverrideFile_Result:
        return self.caller.call("KclvmService.OverrideFile", args)

    def get_full_schema_type(
        self,
        args: GetFullSchemaType_Args,
    ) -> GetSchemaType_Result:
        return self.caller.call("KclvmService.GetFullSchemaType", args)

    def validate_code(self, args: ValidateCode_Args) -> ValidateCode_Result:
        return self.caller.call("KclvmService.ValidateCode", args)

    def load_settings_files(
        self,
        args: LoadSettingsFiles_Args,
    ) -> LoadSettingsFiles_Result:
        return self.caller.call("KclvmService.LoadSettingsFiles", args)

    def rename(self, args: Rename_Args) -> Rename_Result:
        return self.caller.call("KclvmService.Rename", args)

    def rename_code(self, args: RenameCode_Args) -> RenameCode_Result:
        return self.caller.call("KclvmService.RenameCode", args)

    def test(self, args: Test_Args) -> Test_Result:
        return self.caller.call("KclvmService.Test", args)

    # Helper method to perform the call
    def call(self, function_name: str, args):
        return self.caller.call(function_name, args)


class Caller:
    def __init__(self):
        self._dir = tempfile.TemporaryDirectory()
        env_path = os.environ.get(KCLVM_CLI_BIN_PATH_ENV_VAR)
        env_install_path = os.environ.get(KCLVM_CLI_INSTALL_PATH_ENV_VAR)
        env_use_test = os.environ.get(KCLVM_CLI_USE_TEST_ENV_VAR)
        if env_path:
            self.lib = ctypes.CDLL(os.path.join(env_path, lib_full_name()))
        elif env_install_path:
            install_kclvm(env_install_path)
            self.lib = ctypes.CDLL(
                os.path.join(env_install_path, "bin", lib_full_name())
            )
        # Default test cases
        elif env_use_test:
            # Install temp path.
            install_kclvm(self._dir.name)
            self.lib = ctypes.CDLL(self._dir.name + "/bin/" + lib_full_name())
        else:
            # The release lib is located at "kcl_lib/bin/"
            lib_path = LIB_ROOT.joinpath("bin")
            os.environ[KCLVM_CLI_BIN_PATH_ENV_VAR] = str(lib_path)
            self.lib = ctypes.CDLL(str(lib_path.joinpath(lib_full_name())))
        # Assuming the shared library exposes a function `kclvm_service_new`
        self.lib.kclvm_service_new.argtypes = [ctypes.c_uint64]
        self.lib.kclvm_service_new.restype = ctypes.c_void_p
        self.handler = self.lib.kclvm_service_new(0)

        self.mutex = threading.Lock()

    def call(self, name: str, args):
        with self.mutex:
            # Serialize arguments using pickle or json
            args_serialized = args.SerializeToString()

            # Assuming the library exposes a service call function
            self.lib.kclvm_service_call.argtypes = [c_void_p, c_char_p, c_char_p]
            self.lib.kclvm_service_call.restype = c_char_p

            # Call the service function and get the result
            result_ptr = self.lib.kclvm_service_call(
                self.handler, name.encode("utf-8"), args_serialized
            )
            result = ctypes.cast(result_ptr, ctypes.c_char_p).value
            if result.startswith(b"ERROR"):
                raise Exception(str(result))
            msg = self.create_method_resp_message(name)
            msg.ParseFromString(result)
            return msg

    def create_method_req_message(self, method: str) -> _message.Message:
        if method in ["Ping", "KclvmService.Ping"]:
            return Ping_Args()
        if method in ["ExecProgram", "KclvmService.ExecProgram"]:
            return ExecProgram_Args()
        if method in ["BuildProgram", "KclvmService.BuildProgram"]:
            return BuildProgram_Args()
        if method in ["ExecArtifact", "KclvmService.ExecArtifact"]:
            return ExecArtifact_Args()
        if method in ["ParseFile", "KclvmService.ParseFile"]:
            return ParseFile_Args()
        if method in ["ParseProgram", "KclvmService.ParseProgram"]:
            return ParseProgram_Args()
        if method in ["FormatCode", "KclvmService.FormatCode"]:
            return FormatCode_Args()
        if method in ["FormatPath", "KclvmService.FormatPath"]:
            return FormatPath_Args()
        if method in ["LintPath", "KclvmService.LintPath"]:
            return LintPath_Args()
        if method in ["OverrideFile", "KclvmService.OverrideFile"]:
            return OverrideFile_Args()
        if method in ["GetSchemaType", "KclvmService.GetSchemaType"]:
            return GetSchemaType_Args()
        if method in ["GetFullSchemaType", "KclvmService.GetFullSchemaType"]:
            return GetFullSchemaType_Args()
        if method in ["ValidateCode", "KclvmService.ValidateCode"]:
            return ValidateCode_Args()
        if method in ["ListDepFiles", "KclvmService.ListDepFiles"]:
            return ListDepFiles_Args()
        if method in ["LoadSettingsFiles", "KclvmService.LoadSettingsFiles"]:
            return LoadSettingsFiles_Args()
        if method in ["Rename", "KclvmService.Rename"]:
            return Rename_Args()
        if method in ["RenameCode", "KclvmService.RenameCode"]:
            return RenameCode_Args()
        if method in ["Test", "KclvmService.Test"]:
            return Test_Args()
        raise Exception(f"unknown method: {method}")

    def create_method_resp_message(self, method: str) -> _message.Message:
        if method in ["Ping", "KclvmService.Ping"]:
            return Ping_Result()
        if method in ["ExecProgram", "KclvmService.ExecProgram"]:
            return ExecProgram_Result()
        if method in ["BuildProgram", "KclvmService.BuildProgram"]:
            return BuildProgram_Result()
        if method in ["ExecArtifact", "KclvmService.ExecArtifact"]:
            return ExecProgram_Result()
        if method in ["ParseFile", "KclvmService.ParseFile"]:
            return ParseFile_Result()
        if method in ["ParseProgram", "KclvmService.ParseProgram"]:
            return ParseProgram_Result()
        if method in ["FormatCode", "KclvmService.FormatCode"]:
            return FormatCode_Result()
        if method in ["FormatPath", "KclvmService.FormatPath"]:
            return FormatPath_Result()
        if method in ["LintPath", "KclvmService.LintPath"]:
            return LintPath_Result()
        if method in ["OverrideFile", "KclvmService.OverrideFile"]:
            return OverrideFile_Result()
        if method in ["GetSchemaType", "KclvmService.GetSchemaType"]:
            return GetSchemaType_Result()
        if method in ["GetFullSchemaType", "KclvmService.GetFullSchemaType"]:
            return GetSchemaType_Result()
        if method in ["ValidateCode", "KclvmService.ValidateCode"]:
            return ValidateCode_Result()
        if method in ["ListDepFiles", "KclvmService.ListDepFiles"]:
            return ListDepFiles_Result()
        if method in ["LoadSettingsFiles", "KclvmService.LoadSettingsFiles"]:
            return LoadSettingsFiles_Result()
        if method in ["Rename", "KclvmService.Rename"]:
            return Rename_Result()
        if method in ["RenameCode", "KclvmService.RenameCode"]:
            return RenameCode_Result()
        if method in ["Test", "KclvmService.Test"]:
            return Test_Result()
        raise Exception(f"unknown method: {method}")

    # def __del__(self):
    #    # Assuming the shared library exposes a function `kclvm_service_delete`
    #    self.lib.kclvm_service_delete.argtypes = [c_void_p]
    #    self.lib.kclvm_service_delete(self.handler)
    #    self._dir.cleanup()

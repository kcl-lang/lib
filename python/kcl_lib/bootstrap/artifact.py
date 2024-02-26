import platform
import sys
import pathlib
import os

_lib_root = os.environ.get("KCL_LIB_ROOT")
if _lib_root:
    LIB_ROOT = pathlib.Path(_lib_root)
else:
    # Test Lib ROOT
    TEST_LIB_ROOT = pathlib.Path(__file__).parent.parent.parent.parent
    LIB_ROOT = TEST_LIB_ROOT
    if not TEST_LIB_ROOT.joinpath("lib").exists():
        LIB_ROOT = pathlib.Path(__file__).parent.parent


def is_amd64_arch():
    return platform.machine() in ["x86_64", "amd64", "AMD64"]


if sys.platform == "darwin":

    def cli_lib():
        if is_amd64_arch():
            with open(
                f"{LIB_ROOT}/lib/darwin-amd64/libkclvm_cli_cdylib.dylib", "rb"
            ) as f:
                DARWIN_AMD64_CLI_LIB = f.read()
        else:
            with open(
                f"{LIB_ROOT}/lib/darwin-arm64/libkclvm_cli_cdylib.dylib", "rb"
            ) as f:
                DARWIN_ARM64_CLI_LIB = f.read()
        return DARWIN_AMD64_CLI_LIB if is_amd64_arch() else DARWIN_ARM64_CLI_LIB

    def lib_path() -> str:
        if is_amd64_arch():
            return str(LIB_ROOT.joinpath("lib").joinpath("darwin-amd64"))
        return str(LIB_ROOT.joinpath("lib").joinpath("darwin-arm64"))

    def lib_name() -> str:
        return "libkclvm_cli_cdylib.dylib"

elif sys.platform.startswith("linux"):

    def cli_lib():
        if is_amd64_arch():
            with open(f"{LIB_ROOT}/lib/linux-amd64/libkclvm_cli_cdylib.so", "rb") as f:
                LINUX_AMD64_CLI_LIB = f.read()
        else:
            with open(f"{LIB_ROOT}/lib/linux-arm64/libkclvm_cli_cdylib.so", "rb") as f:
                LINUX_ARM64_CLI_LIB = f.read()
        return LINUX_AMD64_CLI_LIB if is_amd64_arch() else LINUX_ARM64_CLI_LIB

    def lib_path() -> str:
        if is_amd64_arch():
            return str(LIB_ROOT.joinpath("lib").joinpath("linux-amd64"))
        return str(LIB_ROOT.joinpath("lib").joinpath("linux-arm64"))

    def lib_name() -> str:
        return "libkclvm_cli_cdylib.so"

elif sys.platform == "win32":

    def cli_lib():
        if is_amd64_arch():
            with open(f"{LIB_ROOT}/lib/windows-amd64/kclvm_cli_cdylib.dll", "rb") as f:
                WINDOWS_AMD64_CLI_LIB = f.read()
        else:
            with open(f"{LIB_ROOT}/lib/windows-arm64/kclvm_cli_cdylib.dll", "rb") as f:
                WINDOWS_ARM64_CLI_LIB = f.read()
        return WINDOWS_AMD64_CLI_LIB if is_amd64_arch() else WINDOWS_ARM64_CLI_LIB

    def export_lib():
        if is_amd64_arch():
            with open(f"{LIB_ROOT}/lib/windows-amd64/kclvm_cli_cdylib.lib", "rb") as f:
                WINDOWS_AMD64_EXPORT_LIB = f.read()
        else:
            with open(f"{LIB_ROOT}/lib/windows-arm64/kclvm_cli_cdylib.lib", "rb") as f:
                WINDOWS_ARM64_EXPORT_LIB = f.read()
        return WINDOWS_AMD64_EXPORT_LIB if is_amd64_arch() else WINDOWS_ARM64_EXPORT_LIB

    def lib_path() -> str:
        if is_amd64_arch():
            return str(LIB_ROOT.joinpath("lib").joinpath("windows-amd64"))
        return str(LIB_ROOT.joinpath("lib").joinpath("windows-arm64"))

    def lib_name() -> str:
        return "kclvm_cli_cdylib.dll"

    def export_lib_name() -> str:
        return "kclvm_cli_cdylib.lib"

else:
    raise f"Unsupported platform {sys.platform}, expected win32, linux or darwin platform"

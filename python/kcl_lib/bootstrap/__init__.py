import os
import sys
import platform
from pathlib import Path

KCLVM_VERSION = "0.8.4"  # You should replace this with actual version
KCLVM_CLI_BIN_PATH_ENV_VAR = "KCLVM_CLI_BIN_PATH"
KCLVM_CLI_INSTALL_PATH_ENV_VAR = "KCLVM_CLI_INSTALL_PATH"
KCLVM_CLI_USE_TEST_ENV_VAR = "KCLVM_CLI_USE_TEST"
LIB_NAME = "kclvm_cli_cdylib"


def lib_full_name():
    if sys.platform == "darwin":
        return f"lib{LIB_NAME}.dylib"
    elif sys.platform == "win32":
        return f"{LIB_NAME}.dll"
    else:
        return f"lib{LIB_NAME}.so"


def write_lib(lib_dir, lib_full_name, content, version_matched):
    lib_full_path = lib_dir / lib_full_name
    if lib_full_path.exists() and version_matched:
        return
    lib_dir.mkdir(parents=True, exist_ok=True)
    with lib_full_path.open("wb") as lib_file:
        lib_file.write(content)


def install_lib(lib_dir, lib_name, version_matched):
    # You would implement the cli_lib and export_lib functions based on your specific case
    from .artifact import cli_lib

    if sys.platform == "win32":
        from .artifact import export_lib

        write_lib(lib_dir, f"{lib_name}.dll", cli_lib(), version_matched)
        write_lib(lib_dir, f"{lib_name}.lib", export_lib(), version_matched)
    else:
        write_lib(lib_dir, lib_full_name(), cli_lib(), version_matched)


def get_version():
    return f"{KCLVM_VERSION}-{sys.platform}-{platform.machine()}"


def check_version(kclvm_version_dir):
    kclvm_version_path = kclvm_version_dir / "kclvm.version"
    if not kclvm_version_path.exists():
        kclvm_version_dir.mkdir(parents=True, exist_ok=True)
        with kclvm_version_path.open("w") as version_file:
            version_file.write(get_version())
        return False
    with kclvm_version_path.open("r") as version_file:
        version = version_file.read().strip()
    return get_version() == version


def install_kclvm(install_root):
    install_root = Path(install_root).resolve()
    bin_path = install_root / "bin"
    version_matched = check_version(bin_path)
    install_lib(bin_path, LIB_NAME, version_matched)
    if not version_matched:
        kclvm_version_path = bin_path / "kclvm.version"
        with kclvm_version_path.open("w") as file:
            file.write(get_version())

    path_env = os.environ.get("PATH", "")
    bin_path_str = str(bin_path)
    new_path_env = f"{path_env}{os.pathsep}{bin_path_str}"
    os.environ["PATH"] = new_path_env
    os.environ[KCLVM_CLI_BIN_PATH_ENV_VAR] = bin_path_str

#! /usr/bin/env python
# -*- coding: utf-8 -*-
import pathlib
import shutil
import platform
import sys
import os

try:
    from setuptools import setup
except ImportError:
    from distutils.core import setup
from pkg_resources import require

# Steps:
# 1. modify kcl_lib version in setup.py
# 2. run `python3 setup.py bdist_wheel` to build package
# 3. run `python3 -m twine upload dist/kcl_lib-*.*` to upload package to PyPI
# 4. input username and password of PyPI
# See PEP 425 for more information
# Platforms
# * linux_x86_64
# *

DIST_PLATFORMS = {
    "macosx_11_0_intel": ["darwin", "amd64"],
    "macosx_11_0_x86_64": ["darwin", "amd64"],
    "macosx_11_0_arm64": ["darwin", "arm64"],
    "manylinux2014_x86_64": ["linux", "amd64"],
    "manylinux_2_27_x86_64": ["linux", "amd64"],
    "manylinux2014_aarch64": ["linux", "arm64"],
    "manylinux_2_27_aarch64": ["linux", "arm64"],
    "win32": ["win32", "amd64"],
    "win_amd64": ["win32", "amd64"],
}
custom_param = None
for i, arg in enumerate(sys.argv):
    if arg in ["--plat-name"]:
        if i + 1 < len(sys.argv):
            custom_param = sys.argv[i + 1]
            break
if custom_param in DIST_PLATFORMS:
    PLATFORM = DIST_PLATFORMS[custom_param][0]
    ARCH = DIST_PLATFORMS[custom_param][1]
else:
    PLATFORM = sys.platform
    ARCH = platform.machine()

print(f"Building dist for {PLATFORM}-{ARCH}...")


def is_amd64_arch():
    return ARCH in ["x86_64", "amd64", "AMD64"]


if PLATFORM == "darwin":
    if is_amd64_arch():
        DARWIN_AMD64_CLI_LIB = f"lib/darwin-amd64/libkclvm_cli_cdylib.dylib"
    else:
        DARWIN_ARM64_CLI_LIB = f"lib/darwin-arm64/libkclvm_cli_cdylib.dylib"

    def cli_lib():
        return DARWIN_AMD64_CLI_LIB if is_amd64_arch() else DARWIN_ARM64_CLI_LIB

elif PLATFORM.startswith("linux"):
    if is_amd64_arch():
        LINUX_AMD64_CLI_LIB = "lib/linux-amd64/libkclvm_cli_cdylib.so"
    else:
        LINUX_ARM64_CLI_LIB = "lib/linux-arm64/libkclvm_cli_cdylib.so"

    def cli_lib():
        return LINUX_AMD64_CLI_LIB if is_amd64_arch() else LINUX_ARM64_CLI_LIB

elif PLATFORM == "win32":
    if is_amd64_arch():
        WINDOWS_AMD64_CLI_LIB = "lib/windows-amd64/kclvm_cli_cdylib.dll"
        WINDOWS_AMD64_EXPORT_LIB = "lib/windows-amd64/kclvm_cli_cdylib.lib"
    else:
        WINDOWS_ARM64_CLI_LIB = "lib/windows-arm64/kclvm_cli_cdylib.dll"
        WINDOWS_ARM64_EXPORT_LIB = "lib/windows-arm64/kclvm_cli_cdylib.lib"

    def cli_lib():
        return WINDOWS_AMD64_CLI_LIB if is_amd64_arch() else WINDOWS_ARM64_CLI_LIB

    def export_lib():
        return WINDOWS_AMD64_EXPORT_LIB if is_amd64_arch() else WINDOWS_ARM64_EXPORT_LIB

else:
    raise f"Unsupported platform {PLATFORM}, expected win32, linux or darwin platform"


def copyfile(src: pathlib.Path, dst: pathlib.Path) -> str:
    os.makedirs(dst.parent, exist_ok=True)
    shutil.copyfile(src, dst)
    return str(dst.relative_to(pathlib.Path(__file__).parent))


def copy_libs():
    source_dir = pathlib.Path(__file__).parent.parent
    target_dir = pathlib.Path(__file__).parent.joinpath("kcl_lib")
    data_files = []
    data_files.append(copyfile(source_dir / cli_lib(), target_dir / cli_lib()))
    if PLATFORM in ["windows"]:
        data_files.append(
            copyfile(source_dir / export_lib(), target_dir / export_lib())
        )
    return data_files


# Copy libraries.
data_files = copy_libs()
print(data_files)

install_requires = []
require_path = pathlib.Path(__file__).parent.joinpath("scripts/requirements.txt")
with open(require_path) as f:
    requires = f.read().split("\n")
    for require in requires:
        install_requires.append(require)

setup(
    name="kcl_lib",
    author="KCL Authors",
    version="0.8.0-alpha.3",
    license="Apache License 2.0",
    python_requires=">=3.7",
    description="KCL Artifact Library for Python",
    long_description="""A constraint-based record & functional language mainly used in configuration and policy scenarios.""",
    author_email="",
    url="https://kcl-lang.io/",
    packages=["kcl_lib", "kcl_lib/api", "kcl_lib/bootstrap"],
    data_files=data_files,
    include_package_data=True,
    zip_safe=True,
    install_requires=install_requires,
)

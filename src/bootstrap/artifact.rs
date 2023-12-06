#[cfg(target_os = "macos")]
const DARWIN_AMD64_CLI_LIB: &[u8] =
    include_bytes!("../../lib/darwin-amd64/libkclvm_cli_cdylib.dylib");
#[cfg(target_os = "macos")]
const DARWIN_ARM64_CLI_LIB: &[u8] =
    include_bytes!("../../lib/darwin-arm64/libkclvm_cli_cdylib.dylib");

#[inline]
fn is_amd64_arch() -> bool {
    std::env::consts::ARCH == "x86" || std::env::consts::ARCH == "x86_64"
}

#[cfg(target_os = "macos")]
pub(crate) fn cli_lib() -> &'static [u8] {
    if is_amd64_arch() {
        DARWIN_AMD64_CLI_LIB
    } else {
        DARWIN_ARM64_CLI_LIB
    }
}

#[cfg(target_os = "linux")]
const LINUX_AMD64_CLI_LIB: &[u8] = include_bytes!("../../lib/linux-amd64/libkclvm_cli_cdylib.so");
#[cfg(target_os = "linux")]
const LINUX_ARM64_CLI_LIB: &[u8] = include_bytes!("../../lib/linux-arm64/libkclvm_cli_cdylib.so");

#[cfg(target_os = "linux")]
pub(crate) fn cli_lib() -> &'static [u8] {
    if is_amd64_arch() {
        LINUX_AMD64_CLI_LIB
    } else {
        LINUX_ARM64_CLI_LIB
    }
}

#[cfg(target_os = "windows")]
const WINDOWS_AMD64_CLI_LIB: &[u8] = include_bytes!("../../lib/windows-amd64/kclvm_cli_cdylib.dll");
#[cfg(target_os = "windows")]
const WINDOWS_ARM64_CLI_LIB: &[u8] = include_bytes!("../../lib/windows-arm64/kclvm_cli_cdylib.dll");
#[cfg(target_os = "windows")]
const WINDOWS_AMD64_EXPORT_LIB: &[u8] =
    include_bytes!("../../lib/windows-amd64/kclvm_cli_cdylib.lib");
#[cfg(target_os = "windows")]
const WINDOWS_ARM64_EXPORT_LIB: &[u8] =
    include_bytes!("../../lib/windows-arm64/kclvm_cli_cdylib.lib");

#[cfg(target_os = "windows")]
pub(crate) fn cli_lib() -> &'static [u8] {
    if is_amd64_arch() {
        WINDOWS_AMD64_CLI_LIB
    } else {
        WINDOWS_ARM64_CLI_LIB
    }
}

#[cfg(target_os = "windows")]
pub(crate) fn export_lib() -> &'static [u8] {
    if is_amd64_arch() {
        WINDOWS_AMD64_EXPORT_LIB
    } else {
        WINDOWS_ARM64_EXPORT_LIB
    }
}

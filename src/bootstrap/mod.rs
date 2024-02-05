use std::env;
use std::fs::{self, File};
use std::io::{self, Write};
use std::path::Path;

mod artifact;

const KCLVM_VERSION: &str = env!("CARGO_PKG_VERSION");
const KCLVM_CLI_BIN_PATH_ENV_VAR: &str = "KCLVM_CLI_BIN_PATH";
pub const LIB_NAME: &str = "kclvm_cli_cdylib";

#[inline]
pub(crate) fn lib_full_name() -> String {
    match std::env::consts::OS {
        "macos" => format!("lib{}.dylib", LIB_NAME),
        "windows" => format!("{}.dll", LIB_NAME),
        _ => format!("lib{}.so", LIB_NAME),
    }
}

/// Install kcl core into the path.
pub(crate) fn install_kclvm<P: AsRef<Path>>(install_root: P) -> io::Result<()> {
    let install_root = install_root.as_ref().canonicalize()?;
    let bin_path = install_root.join("bin");
    let version_matched = check_version(&bin_path)?;
    let path = install_lib(&bin_path, LIB_NAME, version_matched)?;

    if !version_matched {
        let kclvm_version_path = bin_path.join("kclvm.version");
        fs::write(kclvm_version_path, get_version())?;
    }

    let path_env = env::var("PATH").unwrap_or_default();
    let bin_path = bin_path.to_str().unwrap();
    let new_path_env = format!(
        "{}{}",
        path_env,
        std::path::MAIN_SEPARATOR.to_string() + bin_path
    );
    env::set_var("PATH", new_path_env.clone());
    env::set_var(KCLVM_CLI_BIN_PATH_ENV_VAR, bin_path);

    Ok(path)
}

fn write_lib(
    lib_dir: &Path,
    lib_full_name: &str,
    content: &[u8],
    version_matched: bool,
) -> io::Result<()> {
    let lib_full_path = lib_dir.join(lib_full_name);
    if lib_full_path.exists() && version_matched {
        return Ok(());
    }

    fs::create_dir_all(lib_dir)?;
    let mut lib_file = File::create(&lib_full_path)?;
    lib_file.write_all(content)?;

    Ok(())
}

#[cfg(not(target_os = "windows"))]
fn install_lib(lib_dir: &Path, lib_name: &str, version_matched: bool) -> io::Result<()> {
    use artifact::cli_lib;
    let lib_full_name = match std::env::consts::OS {
        "macos" => format!("lib{}.dylib", lib_name),
        "linux" => format!("lib{}.so", lib_name),
        _ => return Ok(()),
    };
    write_lib(lib_dir, &lib_full_name, &cli_lib(), version_matched)
}

#[cfg(target_os = "windows")]
fn install_lib(lib_dir: &Path, lib_name: &str, version_matched: bool) -> io::Result<()> {
    use artifact::{cli_lib, export_lib};
    let lib_full_name = format!("{}.dll", lib_name);
    let export_lib_full_name = format!("{}.lib", lib_name);
    write_lib(lib_dir, &lib_full_name, &cli_lib(), version_matched)?;
    write_lib(
        lib_dir,
        &export_lib_full_name,
        &export_lib(),
        version_matched,
    )?;

    Ok(())
}

fn get_version() -> String {
    format!(
        "{}-{}-{}",
        KCLVM_VERSION,
        env::consts::OS,
        env::consts::ARCH
    )
}

fn check_version(kclvm_version_dir: &Path) -> io::Result<bool> {
    let kclvm_version_path = kclvm_version_dir.join("kclvm.version");

    if !kclvm_version_path.exists() {
        fs::create_dir_all(kclvm_version_dir)?;

        let mut version_file = File::create(&kclvm_version_path)?;
        version_file.write_all(get_version().as_bytes())?;
        version_file.flush()?;
        return Ok(false);
    }

    let version = fs::read_to_string(kclvm_version_path)?;
    Ok(get_version() == version.trim())
}

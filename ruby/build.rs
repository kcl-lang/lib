//! Link configuration for the Ruby extension cdylib.
//!
//! rb-sys already emits `-Wl,-undefined,dynamic_lookup` from its own build
//! script, but cargo only honours `cargo:rustc-link-arg` from the top-level
//! crate's build script, so the flag is repeated here. Without it the macOS
//! linker fails on the Ruby C API symbols, which are resolved at load time
//! when Ruby requires the bundle.

fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        println!("cargo:rustc-link-arg=-Wl,-undefined,dynamic_lookup");
    }
}

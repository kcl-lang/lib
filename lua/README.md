# KCL Artifact Library for Lua

This repo is under development, PRs welcome!

## Build from Source

**Prerequisites**

+ Lua
+ Cargo

### Lua version

You have to enable one of the features: lua54, lua53, lua52, lua51, luajit(52) or luau in `Cargo.toml`, according to the chosen Lua version. **Default Lua version is 5.2**.

If you build on macos, you can set the environment to prevent link errors.

```shell
# Set cargo build target on macos
export MACOSX_DEPLOYMENT_TARGET='10.13'
```

### Linux

```shell
make
# copy to lua share library directory
cp ./target/release/libkcl_lib_lua.so /usr/lib/lua/5.2/kcl_lib.so
```

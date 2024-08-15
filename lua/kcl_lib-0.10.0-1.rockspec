package = "kcl_lib"
version = "0.10.0-1"

source = {
    url = "git+https://github.com/kcl-lang/kcl",
}

description = {
    summary = "KCL Lua Bindings",
    detailed = [[
        KCL Lua Bindings
    ]],
    homepage = "https://kcl-lang.io/",
    license = " Apache-2.0"
}

dependencies = {
    "lua >= 5.1",
    "luarocks-build-rust-mlua = 0.2.0",
}

build = {
    type = "rust-mlua",
    modules = {
        ["kcl_lib"] = "kcl_lib_lua",
    },
    target_path = "target",
}
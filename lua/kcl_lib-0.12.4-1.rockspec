local package_version = "0.12.4"
local rockspec_revision = "1"

rockspec_format = "3.0"
package = "kcl_lib"
version = package_version .. "-" .. rockspec_revision
source = {
  url = "git+https://github.com/kcl-lang/lib.git",
  tag = "v" .. package_version,
  dir = "lib/lua",
}
description = {
  summary = "KCL Lua Bindings",
  detailed = [[
      KCL Lua bindings to interact with KCL files directly in Lua.
    ]],
  homepage = "https://kcl-lang.io/",
  license = "Apache-2.0",
}
build_dependencies = {
  -- "luarocks-build-rust-mlua = 0.2.0", see: https://github.com/luarocks/luarocks/issues/1880
}
dependencies = {
  "luarocks-build-rust-mlua = 0.2.0", -- see: comment in `build_dependencies`
  "lua >= 5.1, < 5.5",
  "lua-protobuf >= 0.5",
  "dkjson >= 2.9",
}
test_dependencies = {
  "busted >= 2.2",
  "penlight >= 1.15",
}
test = {
  type = "busted",
}
build = {
  type = "rust-mlua",
  modules = {
    ["kcl_lib"] = "kcl_lib_lua",
  },
  target_path = "target",
  install = {
    lua = {
      ["kcl_lib.api"] = "kcl_lib/api.lua",
      ["kcl_lib.raw_api"] = "kcl_lib/raw_api.lua",
      ["kcl_lib.types"] = "kcl_lib/types.lua",
      ["kcl_lib.schema"] = "kcl_lib/schema.lua",
    },
  },
}

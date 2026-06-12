local package_version = "0.12.3"
local rockspec_revision = "1"

rockspec_format = "3.0"
package = "kcl_lib"
version = package_version .. "-" .. rockspec_revision
source = {
  url = "git+https://github.com/kcl-lang/lib",
  -- tag = "lua/v" .. version,
}
description = {
  summary = "KCL Lua Bindings",
  detailed = [[
      KCL Lua Bindings
    ]],
  homepage = "https://kcl-lang.io/",
  license = " Apache-2.0",
}
dependencies = {
  "lua >= 5.1",
  "luarocks-build-rust-mlua = 0.2.0",
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
  include = {
    "api.lua",
    "raw_api.lua",
    "types.lua",
    "schema.lua",
  },
}

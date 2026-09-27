# KCL Artifact Library for Lua

> [!WARNING]
> This repo is under development, PRs welcome!

A Lua library for interacting with KCL (Kusion Configuration Language) artifacts. This library
enables you to work with KCL modules, configurations, and artifacts directly from Lua scripts.

## Installation

You will need the following tooling regardless of which installation approach you choose. The rock
is currently packaged as sources files rather than architecture dependent binaries.

- **Rust** (with Cargo) - For building the library.
- **Lua** - The target Lua version you want to use.
- **LuaRocks** - The Lua package manager to manage the build and installation.

### From LuaRocks

```bash
luarocks install kcl_lib
```

### From Source

#### Supported Lua Versions

This library supports multiple Lua versions. Enable the appropriate feature in `Cargo.toml`:

- `lua54` - Lua 5.4
- `lua53` - Lua 5.3
- `lua52` - Lua 5.2 (default)
- `lua51` - Lua 5.1
- `luajit` - LuaJIT

#### Platform-Specific Setup

**macOS:** Set the deployment target to avoid link errors:

```bash
# Set cargo build target on macos
export MACOSX_DEPLOYMENT_TARGET='10.13'
```

#### Build Steps

Use `luarocks` to build the library and install it for your current Lua version:

```bash
luarocks --local make
```

If you need to re-generate the protobuf spec files, run:

```bash
luajit hack/generate_pb.lua
```

## Usage

### Basic Usage

The high-level `kcl_lib.api` facade mirrors the Go SDK's `kcl` package:
`run` accepts a KCL source string, a file path, or a list of file paths,
plus an options table (the equivalent of kcl-go's functional options), and
`validate` checks data against a schema.

```lua
local api = require("kcl_lib.api")

-- Execute a single KCL file
local result = api:run("./config/schema.k")
print("Configuration result:", result:yaml())

-- Execute multiple KCL files
local result = api:run({
  "./config/schema.k",
  "./config/data.k",
})
print("Combined configuration:", result:json())

-- Execute an in-memory KCL program
local result = api:run("a = 1\nb = 2")
print(result:yaml())

-- Read values back with a dotted path
print(result:get("a")) -- 1
```

### Run Options

The second argument of `run` is an options table; settings files are
parsed and merged via the LoadSettingsFiles RPC, and explicit options take
precedence over settings file values.

```lua
local api = require("kcl_lib.api")

local result = api:run("./config/schema.k", {
  work_dir = "./config",
  args = { "env=prod" },          -- -D name=value option(...) values
  overrides = { "app.replicas=3" }, -- -O override specs
  selectors = { "app" },          -- -S path selectors
  settings = { "kcl.yaml" },      -- kcl.yaml settings file(s)
  format = "json",                -- "json" or "yaml" output
  disable_none = true,            -- omit none values
  sort_keys = true,               -- sort result keys
  show_hidden = true,             -- include hidden attributes
  include_schema_type_path = true, -- emit _type attributes (short form)
  full_schema_type_path = true,   -- keep full schema type paths
  strict_range_check = true,
  error_format = "json",          -- "pretty", "short", "arcanist", "sarif"
  external_pkgs = { "pkg=./path" }, -- -E name=path external packages
})

-- A failed run raises the runtime error message (kcl-go's MustRun
-- semantics); pass strict = false to inspect :err_message() instead.
local ok, result = pcall(api.run, api, "./config/missing.k")
```

### Validate

Validate YAML or JSON data against a schema.

```lua
local api = require("kcl_lib.api")

local result = api:validate({
  code = "schema Person:\n  name: str",
  data = '{"name": "Alice"}',
  format = "json", -- "yaml" (default) or "json"
})
assert(result.success)
```

### Raw API

The raw protobuf-shaped API remains available for direct service calls.

```lua
local raw_api = require("kcl_lib.raw_api")

local result = raw_api:exec_program({
  k_filename_list = { "./config/schema.k" },
})
print("Configuration result", result.yaml_result)
```

## Development

### Running Tests

Tests are directly run in Lua using `busted`. You can run them using:

```bash
luarocks test
```

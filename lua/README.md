# KCL Artifact Library for Lua

> [!WARNING]
> This repo is under development, PRs welcome!

A Lua library for interacting with KCL (Kusion Configuration Language) artifacts. This library
enables you to work with KCL modules, configurations, and artifacts directly from Lua scripts.

## Installation

### From Source

#### Prerequisites

- **Rust** (with Cargo) - For building the library.
- **Lua** - The target Lua version you want to use.
- **LuaRocks** - The Lua package manager to manage the build and installation.

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

The KCL Lua library provides two main functions for working with KCL configurations:

```lua
local api = require("kcl_lib.api")

-- Execute a single KCL file
local result = api:run("./config/schema.k")
print("Configuration result:", result:yaml())

-- Execute multiple KCL files
local result = api:run({
    "./config/schema.k",
    "./config/data.k"
})
print("Combined configuration:", result:json())

-- Using the raw API to the native service
local raw_api = require("kcl_lib.raw_api")

-- Perform a call to a native service function
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

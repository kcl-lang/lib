# The mlua dependency is gated behind a Lua-version feature (lua51/lua52/
# lua53/lua54/luajit/luajit52); see Cargo.toml. CI selects the right one via
# luarocks; locally we default to lua54 to match the version used by
# `.github/workflows/publish-luarocks.yaml`. Override with
# `make build LUA_FEATURE=luajit` etc.

LUA_FEATURE ?= lua54

.PHONY: all
all: build

.PHONY: build
build:
	cargo build -r --no-default-features --features "$(LUA_FEATURE)"

.PHONY: fmt
fmt:
	cargo fmt

.PHONY: check
check:
	cargo check --no-default-features --features "$(LUA_FEATURE)"

.PHONY: clean
clean:
	cargo clean

# The mlua dependency is gated behind a Lua-version feature (lua51/lua52/
# lua53/lua54/luajit/luajit52); see Cargo.toml. CI selects the right one via
# luarocks; locally we default to lua54 to match the version used by
# `.github/workflows/publish-luarocks.yaml`. Override with
# `make build LUA_FEATURE=luajit` etc.

LUA_FEATURE ?= lua54
LUA ?= lua

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

# `hack/generate_pb.lua` writes the bare descriptor blob; re-prepend
# `hack/schema_header.lua` so the checked-in file documents its provenance.
# Run from this directory: the generator uses repo-relative paths.
.PHONY: proto
proto:
	$(LUA) hack/generate_pb.lua
	cat hack/schema_header.lua kcl_lib/schema.lua > kcl_lib/schema.lua.tmp
	mv kcl_lib/schema.lua.tmp kcl_lib/schema.lua

.PHONY: test
test:
	luarocks make ./*.rockspec
	luarocks test ./*.rockspec

.PHONY: clean
clean:
	cargo clean

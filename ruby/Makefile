# Ruby bindings for the KCL language core.
#
# `make build` compiles the Rust cdylib and copies it next to the Ruby
# sources as `lib/kcl_lib/kcl_ruby.<DLEXT>` so `require "kcl_lib"` finds it
# (`Init_kcl_ruby` matches the file basename). `make test` runs the minitest
# suite with the local Ruby.
#
# Local macOS setup uses the Homebrew Ruby (keg-only, hence the explicit
# path preference below); CI uses ruby/setup-ruby which puts `ruby` on PATH.

RUBY ?= $(firstword $(wildcard /opt/homebrew/opt/ruby@3.4/bin/ruby) $(wildcard /opt/homebrew/opt/ruby/bin/ruby) ruby)

# Reuse the repository-wide Cargo target dir so the (very large) kcl-api
# dependency graph is shared with the other bindings; set CARGO_TARGET_DIR
# to override, e.g. to `target` for an isolated build. It is also set inline
# on the cargo commands because environment overrides are the most portable
# way to reach cargo regardless of make version.
export CARGO_TARGET_DIR ?= $(abspath ../target)

export RUBY
export PATH := $(dir $(RUBY)):$(PATH)

# Ruby loads the native extension by its platform-specific DLEXT
# ("bundle" on macOS, "so" on Linux/Windows), so the copy destination must
# follow the running Ruby rather than hard-coding the macOS name.
DLEXT := $(shell $(RUBY) -rrbconfig -e 'print RbConfig::CONFIG["DLEXT"]')
NATIVE_DST := lib/kcl_lib/kcl_ruby.$(DLEXT)

.PHONY: all
all: build

.PHONY: build
build:
	CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" cargo build --release
	@# The artifact locator runs in the recipe shell, not $(wildcard): GNU
	@# make caches directory listings per run, so a wildcard cannot see files
	@# created earlier in the same run (e.g. by cargo on a cold checkout).
	@src=$$(ls $(CARGO_TARGET_DIR)/release/libkcl_ruby.dylib $(CARGO_TARGET_DIR)/release/libkcl_ruby.so $(CARGO_TARGET_DIR)/release/libkcl_ruby.dll 2>/dev/null | head -1); \
	test -n "$$src" || { echo "error: libkcl_ruby artifact not found under $(CARGO_TARGET_DIR)/release" >&2; exit 1; }; \
	cp "$$src" $(NATIVE_DST)

.PHONY: test
test: build
	$(RUBY) -Ilib -Itest -e 'Dir.glob("test/**/*_test.rb").sort.each { |f| require_relative f }'

.PHONY: proto
proto:
	protoc -I../spec --ruby_out=lib/kcl_lib ../spec/spec.proto

.PHONY: fmt
fmt:
	cargo fmt

.PHONY: clean
clean:
	CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" cargo clean -p kcl-lib-ruby
	rm -f $(NATIVE_DST)

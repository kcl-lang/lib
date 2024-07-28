INCLUDE_DIR=./Sources/CKclLib/include
LIB_DIR=./Sources/CKclLib/lib

.PHONY: all
all: build

.PHONY: build
build: cargo
	swift build

.PHONY: cargo
cargo:
	cargo build -r
	mkdir -p $(LIB_DIR)
	cp ./target/release/libkcl_lib_c.a $(LIB_DIR)

.PHONY: test
test: cargo
	swift test

.PHONY: clean
clean:
	cargo clean
	rm -rf $(LIB_DIR)

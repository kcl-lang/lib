.PHONY: fmt
fmt:
	cargo fmt
	find . -name '*.cpp' -exec clang-format -i --style=WebKit --verbose {} \;
	find . -name '*.c' -exec clang-format -i --style=WebKit --verbose {} \;

.PHONY: cargo
cargo:
	cargo build -r

.PHONY: cpp
cpp:
	cmake --build build --parallel

.PHONY: examples
examples: cpp
	./scripts/run_examples.sh

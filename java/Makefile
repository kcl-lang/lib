default: build

deps:
	cargo build --release
	cp ./target/release/libkcl_lib_jni.* .

build: deps
	mvn -B install -U -Djava.library.path=.

fmt:
	cargo fmt
	mvn formatter:format

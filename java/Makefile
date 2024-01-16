default: build

deps:
	cargo build --release
	cp ./target/release/libkcl_lib_jni.* .

build: deps
	mvn -B install -U

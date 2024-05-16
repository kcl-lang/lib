build:
	maturin develop

fmt:
	python3 -m pip install black
	python3 -m black .
	cargo fmt

test:
	python3 -m pip install pytest && python3 -m pytest

deps:
	python3 -m venv venv
	source venv/bin/activate
	cargo install maturin

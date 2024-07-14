build:
	maturin develop

fmt:
	python3 -m pip install black
	python3 -m black .
	cargo fmt

test:
	export PYTHONPATH=${PWD} && python3 -m pip install pytest && python3 -m pytest -vv

deps:
	python3 -m venv venv
	source venv/bin/activate
	cargo install maturin

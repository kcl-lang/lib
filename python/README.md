# KCL Artifact Library for Python

## Installation

```shell
python3 -m pip install kcl-lib
```

## Quick Start

```python
import kcl_lib.api as api

args = api.ExecProgram_Args(k_filename_list=["./tests/test_data/schema.k"])
api = api.API()
result = api.exec_program(args)
print(result.yaml_result)
```

## Developing

Setup virtualenv:

```shell
python3 -m venv venv
```

Activate venv:

```shell
source venv/bin/activate
```

Install maturin:

```shell
cargo install maturin
```

Build bindings:

```shell
maturin develop
```

Test

```shell
python3 -m pytest
```

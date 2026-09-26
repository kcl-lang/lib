"""Tests for the high-level :mod:`kcl_lib.kcl` facade."""

from __future__ import annotations

import pathlib
import tempfile

import pytest

import kcl_lib
from kcl_lib import (
    KCLResult,
    KCLResultList,
    format_code,
    get_version,
    list_dep_files,
    must_run,
    run,
    validate,
    validate_code,
    with_k_filenames,
    with_overrides,
)


@pytest.fixture
def tmp_k(tmp_path):
    """Yield a temp ``.k`` file with a simple schema and instance."""
    path = tmp_path / "test.k"
    path.write_text(
        'schema Foo:\n    name: str = "alice"\n\nx = Foo {}\n',
        encoding="utf-8",
    )
    yield str(path)


def test_run_basic(tmp_k):
    """``run`` evaluates a file and returns a populated KCLResultList."""
    results, err = run(tmp_k)
    assert err is None
    assert isinstance(results, KCLResultList)
    assert len(results) >= 1
    payload = results.to_dict()
    assert payload["x"]["name"] == "alice"


def test_run_with_options(tmp_k):
    """``with_overrides`` propagates into the KCL evaluation."""
    results, err = run(tmp_k, with_overrides(['x.name="bob"']))
    assert err is None
    assert results.to_dict()["x"]["name"] == "bob"


def test_must_run_raises(tmp_path):
    """``must_run`` raises on a missing file."""
    missing = str(tmp_path / "nope.k")
    with pytest.raises(Exception) as excinfo:
        must_run(missing)
    assert "Cannot find" in str(excinfo.value) or "not found" in str(excinfo.value).lower()


def test_format_code():
    """``format_code`` normalises whitespace from a KCL source."""
    raw = "schema Person:\n    name:   str\n"
    out = format_code(raw)
    assert isinstance(out, bytes)
    assert b"name: str" in out


def test_validate_code():
    """``validate_code`` returns True for matching data/schema."""
    code = (
        "schema Person:\n"
        "    name: str\n"
        "    age: int\n"
        "    check:\n"
        "        0 < age < 120\n"
    )
    data = '{"name": "Alice", "age": 10}'
    assert validate_code(data, code, format="json") is True


def test_kclresult_to_dict(tmp_k):
    """``KCLResult.to_dict`` parses the YAML/JSON result."""
    results, _ = run(tmp_k)
    payload = results.first().to_dict()
    assert isinstance(payload, dict)
    assert "x" in payload
    assert payload["x"]["name"] == "alice"


def test_kclresult_get(tmp_k):
    """``KCLResult.get`` honours dotted keys and ``target`` coercion."""
    results, _ = run(tmp_k)
    first = results.first()
    # Plain lookup returns the raw value.
    assert first.get("x.name") == "alice"
    # ``target=str`` coerces the value.
    assert first.get("x.name", str) == "alice"
    # Missing keys return None.
    assert first.get("x.absent") is None


def test_list_dep_files():
    """``list_dep_files`` returns a list (possibly empty for a fresh dir)."""
    with tempfile.TemporaryDirectory() as td:
        pathlib.Path(td, "main.k").write_text("x = 1\n", encoding="utf-8")
        result = list_dep_files(td)
    assert isinstance(result, list)


def test_get_version():
    """``get_version`` returns a populated VersionResult."""
    v = get_version()
    assert v.version
    assert v.version_info
    assert "Version" in v.version_info
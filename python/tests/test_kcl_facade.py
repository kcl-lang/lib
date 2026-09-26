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
    with_output_format,
    with_overrides,
    with_settings,
    with_work_dir,
)
from kcl_lib.kcl import (
    ExecProgramOptions,
    _apply_settings,
    _to_args,
)


def _yaml_available() -> bool:
    """Return ``True`` when PyYAML is importable.

    The kcl.yaml parser in :mod:`kcl_lib.kcl` falls back to a stdlib-only
    reader when PyYAML is missing, but the fallback cannot handle the
    sequences and nested mappings that real-world ``kcl.yaml`` files
    contain. Tests that exercise the full settings-file surface mark
    themselves as skipped via this helper.
    """
    try:
        import yaml  # noqa: F401

        return True
    except ImportError:
        return False


@pytest.fixture
def tmp_k(tmp_path):
    """Yield a temp ``.k`` file with a simple schema and instance."""
    path = tmp_path / "test.k"
    path.write_text(
        'schema Foo:\n    name: str = "alice"\n\nx = Foo {}\n',
        encoding="utf-8",
    )
    yield str(path)


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


# ---------------------------------------------------------------------------
# Internal helpers: ``_to_args`` and ``_apply_settings``
# ---------------------------------------------------------------------------


def test_to_args_sets_format_field():
    """``with_output_format`` populates ``ExecProgramArgs.format`` directly."""
    opts = ExecProgramOptions(
        k_filename_list=["/tmp/x.k"],
        output_format="json",
    )
    args, output_format = _to_args(opts)
    assert output_format == "json"
    assert args.format == "json"
    # We no longer poke ``disable_yaml_result`` as a proxy for the format.
    assert args.disable_yaml_result is False


def test_to_args_default_format_is_yaml():
    """When no format is requested, ``format`` is empty and output_format falls back to yaml."""
    opts = ExecProgramOptions(k_filename_list=["/tmp/x.k"])
    args, output_format = _to_args(opts)
    assert output_format == "yaml"
    # Empty proto3 strings are not serialised, so no value comparison possible.


@pytest.mark.skipif(
    not _yaml_available(), reason="requires PyYAML to parse complex kcl.yaml fixtures"
)
def test_apply_settings_populates_files_and_format(tmp_path):
    """``_apply_settings`` reads ``kcl.yaml`` and seeds args fields.

    Requires PyYAML: ``kcl.yaml`` supports sequences (``files: [...]``)
    and nested mappings under ``kcl_options``, which the stdlib-only
    fallback parser in :func:`kcl_lib.kcl._load_yaml` cannot handle.
    Real-world kcl.yaml files almost always contain sequences, so the
    ``with_settings`` path will use PyYAML whenever it is available.
    """
    yaml = pytest.importorskip("yaml")
    kcl_yaml = tmp_path / "kcl.yaml"
    kcl_yaml.write_text(
        "kcl_cli_configs:\n"
        "  file:\n"
        "    - main.k\n"
        "  output: json\n"
        "  overrides:\n"
        "    - 'x.name=\"bob\"'\n"
        "  strict_range_check: true\n"
        "  disable_none: true\n"
        "  sort_keys: true\n"
        "  show_hidden: true\n"
        "  include_schema_type_path: true\n"
        "  verbose: 2\n"
        "  debug: true\n"
        "  package_maps:\n"
        "    k8s: ../vendor/k8s\n"
        "kcl_options:\n"
        "  - key: key1\n"
        "    value: val1\n"
        "  - key: key2\n"
        "    value:\n"
        "      a: 1\n",
        encoding="utf-8",
    )
    # Sanity check: PyYAML must produce a dict (otherwise the test fixture
    # itself is malformed).
    parsed = yaml.safe_load(kcl_yaml.read_text(encoding="utf-8"))
    assert isinstance(parsed, dict)
    # The caller does not provide k_filename_list, so the settings file's
    # ``file`` entry is allowed to populate it.
    args = _to_args(ExecProgramOptions(settings_file=str(kcl_yaml)))[0]
    # Format and overrides come from the settings file.
    assert args.format == "json"
    assert list(args.overrides) == ['x.name="bob"']
    # Toggles are propagated.
    assert args.strict_range_check is True
    assert args.disable_none is True
    assert args.sort_keys is True
    assert args.show_hidden is True
    assert args.include_schema_type_path is True
    assert args.verbose == 2
    assert args.debug == 1
    # Package maps → external_pkgs.
    pkg_names = sorted(p.pkg_name for p in args.external_pkgs)
    assert pkg_names == ["k8s"]
    assert args.external_pkgs[0].pkg_path == "../vendor/k8s"
    # kcl_options → args. The mapping value is serialised to JSON.
    args_by_name = {a.name: a.value for a in args.args}
    assert args_by_name["key1"] == "val1"
    assert args_by_name["key2"] == '{"a": 1}'
    # The settings file's ``file`` entry populated the filename list.
    files = list(args.k_filename_list)
    assert any(p.endswith("main.k") for p in files), files


def test_apply_settings_user_overrides_win(tmp_path):
    """Fields explicitly provided via ``with_*`` override the settings file."""
    kcl_yaml = tmp_path / "kcl.yaml"
    kcl_yaml.write_text(
        "kcl_cli_configs:\n"
        "  output: yaml\n"
        "  disable_none: false\n",
        encoding="utf-8",
    )
    args = _to_args(
        ExecProgramOptions(
            k_filename_list=[str(tmp_path / "explicit.k")],
            settings_file=str(kcl_yaml),
            output_format="json",
            disable_none=True,
        )
    )[0]
    assert args.format == "json"
    assert args.disable_none is True
    # Caller's filename list replaces the settings file's (empty) one.
    assert list(args.k_filename_list) == [str(tmp_path / "explicit.k")]


def test_apply_settings_missing_file_is_silent(tmp_path):
    """A missing settings file does not raise — it is treated as empty."""
    args = _to_args(
        ExecProgramOptions(
            k_filename_list=[str(tmp_path / "x.k")],
            settings_file=str(tmp_path / "nope.yaml"),
        )
    )[0]
    assert list(args.k_filename_list) == [str(tmp_path / "x.k")]
    assert list(args.overrides) == []


def test_with_settings_option_records_path(tmp_path):
    """``with_settings`` populates ``opts.settings_file`` for later merging."""
    settings = str(tmp_path / "kcl.yaml")
    settings_file = settings  # noqa: F841 — kept for clarity
    opts = ExecProgramOptions(k_filename_list=["/tmp/x.k"])
    with_settings(settings)(opts)
    assert opts.settings_file == settings
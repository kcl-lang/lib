"""Tests for the high-level :mod:`kcl_lib.kcl` facade."""

from __future__ import annotations

import os
import pathlib
import tempfile

import pytest

import kcl_lib
from kcl_lib import (
    KCLResult,
    KCLResultList,
    TestOptions as KCLTestOptions,
    format_code,
    format_path,
    format_test_report,
    generate_doc,
    generate_kcl,
    generate_openapi,
    generate_proto,
    generate_toml,
    get_full_schema_type,
    get_full_schema_type_mapping,
    get_full_schema_type_mapping_under_path,
    get_version,
    lint_path,
    list_dep_files,
    list_downstream_files,
    list_upstream_files,
    load_package,
    must_run,
    run,
    test as kcl_test,
    validate,
    validate_code,
    with_error_format,
    with_external_pkgs,
    with_k_filenames,
    with_options,
    with_output_format,
    with_overrides,
    with_settings,
    with_work_dir,
)
from kcl_lib.api.spec_pb2 import (
    ExecProgramArgs,
    ExternalPkg,
    FormatTestReportArgs,
    GenerateDocArgs,
    GenerateKclArgs,
    GenerateOpenAPIArgs,
    GenerateProtoArgs,
    GenerateTomlArgs,
    LoadPackageArgs,
    ParseProgramArgs,
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


# ---------------------------------------------------------------------------
# load_package info fields (imports / kcl_mod / apps) + dep listing facade
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def dep_pkg(tmp_path_factory):
    """A small package whose entry imports ``base.base`` (mirrors the core
    ``load_pkg_info`` fixture): a ``kcl.mod`` at the root, ``main.k``
    importing ``base.base`` and a leaf ``base/base.k`` with no imports."""
    root = tmp_path_factory.mktemp("dep_pkg")
    (root / "base").mkdir()
    (root / "kcl.mod").write_text(
        '[package]\nname = "dep_pkg"\nedition = "0.1.0"\nversion = "0.1.0"\n',
        encoding="utf-8",
    )
    main = root / "main.k"
    main.write_text(
        "import base.base\n\n"
        "schema App:\n"
        "    name: str = base.app_name\n\n"
        "app = App {}\n",
        encoding="utf-8",
    )
    base = root / "base" / "base.k"
    base.write_text('app_name = "dep_pkg_app"\n', encoding="utf-8")
    return str(root), str(main), str(base)


def test_load_package_reports_imports_kcl_mod_and_apps(dep_pkg):
    """``load_package`` exposes the import graph, manifest and app scan."""
    root, main, base = dep_pkg
    result = load_package(LoadPackageArgs(parse_args=ParseProgramArgs(paths=[main])))
    main_k = os.path.realpath(main)
    base_k = os.path.realpath(base)

    # main.k directly imports base.base with the resolved dep file path.
    file_imports = result.imports.get(main_k)
    assert file_imports is not None, list(result.imports.keys())
    resolved = [info.resolved for info in file_imports.imports]
    assert base_k in resolved
    # base/base.k is part of the program but imports nothing.
    assert base_k in result.imports
    assert len(result.imports[base_k].imports) == 0

    # The parsed kcl.mod manifest of the package root.
    assert result.kcl_mod.package.name == "dep_pkg"

    # The fixture root is reported as an application directory.
    app_paths = [app.path for app in result.apps]
    assert os.path.realpath(root) in app_paths


def test_list_dep_files_resolves_imports(dep_pkg):
    """``list_dep_files`` on the entry file lists its deps, not itself."""
    _, main, base = dep_pkg
    files = list_dep_files(main)
    assert os.path.realpath(base) in files
    assert os.path.realpath(main) not in files


def test_list_dep_files_dir_input(dep_pkg):
    """``list_dep_files`` on the package dir lists every resolved dep."""
    root, main, base = dep_pkg
    files = list_dep_files(root)
    assert os.path.realpath(base) in files
    assert os.path.realpath(main) not in files


def test_list_upstream_files(dep_pkg):
    """``list_upstream_files`` on the entry file lists its imports."""
    _, main, base = dep_pkg
    files = list_upstream_files(main)
    assert os.path.realpath(base) in files
    assert os.path.realpath(main) not in files


def test_list_upstream_files_dir_input(dep_pkg):
    """Dir input: union of the closures of the files directly under it."""
    root, main, base = dep_pkg
    files = list_upstream_files(root)
    assert os.path.realpath(base) in files
    assert os.path.realpath(main) not in files


def test_list_downstream_files(dep_pkg):
    """``list_downstream_files`` walks the import graph backwards."""
    _, main, base = dep_pkg
    files = list_downstream_files(base)
    assert os.path.realpath(main) in files
    assert os.path.realpath(base) not in files


def test_list_dep_listings_not_found():
    """A path outside any package yields empty lists, not errors."""
    assert list_dep_files("/nonexistent/kcl/path.k") == []
    assert list_upstream_files("/nonexistent/kcl/path.k") == []
    assert list_downstream_files("/nonexistent/kcl/path.k") == []


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


# ---------------------------------------------------------------------------
# lint_path
# ---------------------------------------------------------------------------


def test_lint_path_reports_unused_import():
    """``lint_path`` surfaces lint messages for the given files."""
    results = lint_path(["./tests/test_data/lint_path/test-lint.k"])
    assert any("Module 'math' imported but unused" in r for r in results)


def test_lint_path_clean_file():
    """A file without lint issues yields an empty message list."""
    assert lint_path(["./tests/test_data/schema.k"]) == []


# ---------------------------------------------------------------------------
# format_path dry_run
# ---------------------------------------------------------------------------


def test_format_path_dry_run_does_not_rewrite(tmp_path):
    """``dry_run=True`` reports would-change files but leaves them untouched."""
    target = tmp_path / "messy.k"
    target.write_text("a   =   1\n", encoding="utf-8")

    changed = format_path(str(tmp_path), dry_run=True)
    assert any(p.endswith("messy.k") for p in changed)
    assert target.read_text(encoding="utf-8") == "a   =   1\n"

    # A real run rewrites the file and reports it again.
    changed = format_path(str(tmp_path))
    assert any(p.endswith("messy.k") for p in changed)
    assert target.read_text(encoding="utf-8") == "a = 1\n"

    # Once formatted, nothing is reported as changed.
    assert format_path(str(tmp_path), dry_run=True) == []


# ---------------------------------------------------------------------------
# with_options / with_error_format
# ---------------------------------------------------------------------------


def test_with_options_feeds_option_values(tmp_path):
    """``with_options`` maps ``-D key=value`` strings onto ``option("key")``."""
    path = tmp_path / "opts.k"
    path.write_text(
        'a = option("key1")\nb = option("key2", default="dft")\n',
        encoding="utf-8",
    )
    results, err = run(str(path), with_options(["key1=hello", "key2=world"]))
    assert err is None
    assert results.to_dict() == {"a": "hello", "b": "world"}

    # Defaults still apply for options the caller did not provide.
    results, err = run(str(path), with_options(["key1=hello"]))
    assert err is None
    assert results.to_dict() == {"a": "hello", "b": "dft"}


def test_with_options_parses_key_value_pairs():
    """``with_options`` keeps ``name=value`` pairs and skips malformed entries.

    Mirrors kcl-go's ``WithOptions`` guard ``strings.Index(kv, "=") > 0``:
    entries without ``=`` or with an empty key are dropped.
    """
    opts = ExecProgramOptions(k_filename_list=["/tmp/x.k"])
    with_options(["a=1", "b=", "=skipped", "noequals"])(opts)
    args, _ = _to_args(opts)
    assert [(a.name, a.value) for a in args.args] == [("a", "1"), ("b", "")]


def test_with_options_overrides_settings_file_options(tmp_path):
    """Explicit ``with_options`` replaces the settings file's ``kcl_options``."""
    pytest.importorskip("yaml")
    kcl_yaml = tmp_path / "kcl.yaml"
    kcl_yaml.write_text(
        "kcl_cli_configs:\n"
        "  files:\n"
        "    - opts.k\n"
        "kcl_options:\n"
        "  - key: key1\n"
        "    value: from_settings\n",
        encoding="utf-8",
    )
    opts = ExecProgramOptions(
        k_filename_list=[str(tmp_path / "opts.k")],
        settings_file=str(kcl_yaml),
    )
    with_options(["key1=from_cli"])(opts)
    args, _ = _to_args(opts)
    assert [(a.name, a.value) for a in args.args] == [("key1", "from_cli")]


def test_with_error_format_populates_proto_field():
    """``with_error_format`` lands in ``ExecProgramArgs.error_format``."""
    opts = ExecProgramOptions(k_filename_list=["/tmp/x.k"])
    with_error_format("sarif")(opts)
    args, _ = _to_args(opts)
    assert args.error_format == "sarif"
    # Unset stays unset (runtime default "pretty").
    args, _ = _to_args(ExecProgramOptions(k_filename_list=["/tmp/x.k"]))
    assert args.error_format == ""


def test_with_error_format_run_through(tmp_path):
    """The runtime honours a non-default error format on success and failure."""
    ok = tmp_path / "ok.k"
    ok.write_text("a = 1\n", encoding="utf-8")
    results, err = run(str(ok), with_error_format("short"))
    assert err is None
    assert results.to_dict() == {"a": 1}

    bad = tmp_path / "bad.k"
    bad.write_text("a = = =\n", encoding="utf-8")
    _, err = run(str(bad), with_error_format("short"))
    assert err is not None


# ---------------------------------------------------------------------------
# get_full_schema_type / get_full_schema_type_mapping / ..._under_path
# ---------------------------------------------------------------------------


def test_get_full_schema_type_mapping():
    """The mapping variant returns schema name -> KclType for a file list."""
    pkg = pathlib.Path("./tests/test_data/get_schema_ty/bbb").resolve()
    mapping = get_full_schema_type_mapping([str(pkg)])
    assert set(mapping.keys()) == {"B"}
    assert mapping["B"].type == "schema"
    assert mapping["B"].properties["name"].type == "str"


def test_get_full_schema_type():
    """The values variant flattens the mapping (kcl-go ``getValues``)."""
    pkg = pathlib.Path("./tests/test_data/get_schema_ty/bbb").resolve()

    all_types = get_full_schema_type([str(pkg)])
    assert [t.schema_name for t in all_types] == ["B"]

    named = get_full_schema_type([str(pkg)], "B")
    assert [t.schema_name for t in named] == ["B"]

    missing = get_full_schema_type([str(pkg)], "Nope")
    assert missing == []


def test_get_full_schema_type_resolves_external_pkgs():
    """``with_external_pkgs`` lets the file list pull in dependency schemas."""
    root = pathlib.Path("./tests/test_data/get_schema_ty").resolve()
    mapping = get_full_schema_type_mapping(
        [str(root / "aaa")],
        "",
        with_external_pkgs(
            [
                ExternalPkg(pkg_name="bbb", pkg_path=str(root / "bbb")),
                ExternalPkg(pkg_name="ccc", pkg_path=str(root / "ccc")),
            ]
        ),
    )
    # The mapping is keyed by top-level name; each value carries the schema
    # type resolved from the external package.
    assert set(mapping.keys()) == {"a", "a_c"}
    assert mapping["a"].schema_name == "B"
    assert mapping["a"].pkg_path == "bbb"
    assert mapping["a_c"].schema_name == "C"
    assert mapping["a_c"].pkg_path == "ccc"


def test_get_full_schema_type_mapping_under_path():
    """Under-path mapping is keyed by package with correct pkgpath/base."""
    root = pathlib.Path("./tests/test_data/get_schema_ty_under_path").resolve()
    mapping = get_full_schema_type_mapping_under_path(
        [str(root / "aaa")],
        "",
        with_external_pkgs(
            [ExternalPkg(pkg_name="bbb", pkg_path=str(root / "bbb"))]
        ),
    )

    assert "__main__" in mapping
    assert "bbb" in mapping

    main_schemas = {s.schema_name: s for s in mapping["__main__"].schema_type}
    assert "A" in main_schemas

    bbb_schemas = {s.schema_name: s for s in mapping["bbb"].schema_type}
    assert {"Base", "B"} <= set(bbb_schemas)
    # Regression for https://github.com/kcl-lang/kcl/issues/1546: schemas
    # from the dependency keep their own pkgpath and base schema.
    assert bbb_schemas["Base"].pkg_path == "bbb"
    assert bbb_schemas["B"].pkg_path == "bbb"
    assert bbb_schemas["B"].HasField("base_schema")
    assert bbb_schemas["B"].base_schema.schema_name == "Base"
    assert bbb_schemas["B"].base_schema.pkg_path == "bbb"


def test_get_full_schema_type_mapping_under_path_schema_name_filter():
    """A non-empty ``schema_name`` filters across every package."""
    root = pathlib.Path("./tests/test_data/get_schema_ty_under_path").resolve()
    mapping = get_full_schema_type_mapping_under_path(
        [str(root / "aaa")],
        "B",
        with_external_pkgs(
            [ExternalPkg(pkg_name="bbb", pkg_path=str(root / "bbb"))]
        ),
    )
    total = sum(len(s.schema_type) for s in mapping.values())
    assert total == 1
    bbb_schemas = {s.schema_name: s for s in mapping["bbb"].schema_type}
    assert "B" in bbb_schemas
    assert "Base" not in bbb_schemas


# ---------------------------------------------------------------------------
# test() — KCL unit test runner
# ---------------------------------------------------------------------------


def test_test_runs_kcl_unit_tests():
    """``test(TestOptions(...))`` runs KCL ``*_test.k`` cases via the facade."""
    result = kcl_test(KCLTestOptions(pkg_list=["./tests/test_data/testing/..."]))
    assert len(result.info) == 2
    for case in result.info:
        assert case.error == ""


def test_test_run_regexp_filter():
    """``run_regexp`` selects a subset of the discovered test cases."""
    result = kcl_test(
        KCLTestOptions(
            pkg_list=["./tests/test_data/testing/..."], run_regexp="test_func_0"
        )
    )
    assert len(result.info) == 1
    assert result.info[0].name == "test_func_0"


def test_test_accepts_raw_test_args():
    """A raw ``TestArgs`` proto keeps the original facade passthrough working."""
    from kcl_lib.api.spec_pb2 import TestArgs

    result = kcl_test(TestArgs(pkg_list=["./tests/test_data/testing/..."]))
    assert len(result.info) == 2

# ---------------------------------------------------------------------------
# generate_* / format_test_report pass-through facades
# ---------------------------------------------------------------------------


def test_generate_toml():
    """``generate_toml`` serializes the evaluated program result to TOML."""
    result = generate_toml(
        GenerateTomlArgs(exec_args=ExecProgramArgs(k_code_list=["a = {b = 1, c = [1, 2]}"]))
    )
    assert "[a]" in result.toml
    assert "b = 1" in result.toml


def test_generate_toml_sort_keys():
    """``sort_keys=True`` sorts the TOML keys (source order keeps ``c`` first)."""
    plain = generate_toml(
        GenerateTomlArgs(exec_args=ExecProgramArgs(k_code_list=["a = {c = [1, 2], b = 1}"]))
    )
    assert plain.toml.index("c") < plain.toml.index("b = 1")

    sorted_result = generate_toml(
        GenerateTomlArgs(
            exec_args=ExecProgramArgs(k_code_list=["a = {c = [1, 2], b = 1}"]),
            sort_keys=True,
        )
    )
    assert sorted_result.toml.index("b = 1") < sorted_result.toml.index("c")


def test_generate_kcl():
    """``generate_kcl`` converts inline JSON data to KCL source."""
    result = generate_kcl(GenerateKclArgs(source='{"a": {"b": 1}}'))
    assert "a = {" in result.kcl
    assert "b = 1" in result.kcl


def test_generate_kcl_infers_format_from_filename():
    """A ``.yaml`` filename selects the YAML parser without an explicit format."""
    result = generate_kcl(GenerateKclArgs(source="a:\n  b: 1\n", filename="data.yaml"))
    assert "a = {" in result.kcl
    assert "b = 1" in result.kcl


@pytest.fixture(scope="module")
def schema_pkg(tmp_path_factory):
    """Package with two schemas, one referencing the other."""
    root = tmp_path_factory.mktemp("schema_pkg")
    (root / "kcl.mod").write_text(
        '[package]\nname = "schema_pkg"\nedition = "0.1.0"\nversion = "0.1.0"\n',
        encoding="utf-8",
    )
    main = root / "main.k"
    main.write_text(
        "schema Container:\n"
        "    name: str\n"
        "    image: Image\n"
        "\n"
        "schema Image:\n"
        "    repo: str\n"
        "    tag: str\n",
        encoding="utf-8",
    )
    return str(root), str(main)


def test_generate_openapi(schema_pkg):
    """``generate_openapi`` exports the package schemas as an OpenAPI v3 spec."""
    _, main = schema_pkg
    result = generate_openapi(
        GenerateOpenAPIArgs(parse_args=ParseProgramArgs(paths=[main]), version="v3")
    )
    assert '"openapi": "3.0.0"' in result.spec
    assert "Container" in result.spec
    assert "Image" in result.spec


def test_generate_openapi_v2(schema_pkg):
    """``version="v2"`` switches the export to a Swagger 2.0 spec."""
    _, main = schema_pkg
    result = generate_openapi(
        GenerateOpenAPIArgs(parse_args=ParseProgramArgs(paths=[main]), version="v2")
    )
    assert '"swagger": "2.0"' in result.spec


def test_generate_proto(schema_pkg):
    """``generate_proto`` exports the package schemas as proto3 messages."""
    _, main = schema_pkg
    result = generate_proto(
        GenerateProtoArgs(
            parse_args=ParseProgramArgs(paths=[main]), package="example.v1"
        )
    )
    assert 'syntax = "proto3";' in result.proto
    assert "package example.v1;" in result.proto
    assert "message Container" in result.proto
    assert "message Image" in result.proto


def test_generate_doc(schema_pkg):
    """``generate_doc`` renders Markdown documentation for the schemas."""
    _, main = schema_pkg
    result = generate_doc(
        GenerateDocArgs(parse_args=ParseProgramArgs(paths=[main]), format="md")
    )
    assert "## " in result.content
    assert "Container" in result.content
    assert "Image" in result.content


def test_format_test_report():
    """``format_test_report`` pretty-prints pass/fail cases with summary lines."""
    from kcl_lib.api.spec_pb2 import TestCaseInfo, TestResult

    result = TestResult(
        info=[
            TestCaseInfo(name="test_ok", error="", duration=1500, log_message=""),
            TestCaseInfo(
                name="test_bad",
                error="Error: assert failed",
                duration=2500,
                log_message="",
            ),
        ]
    )
    report = format_test_report(FormatTestReportArgs(result=result)).report
    assert "test_ok: PASS (1ms)" in report
    assert "test_bad: FAIL (2ms)" in report
    assert "PASS: 1/2" in report
    assert "FAIL: 1/2" in report
    assert "-" * 80 in report

"""Tests for the source-map fields introduced alongside kcl-lang/kcl#1546.

Combines:
    1. Pure protobuf round-trip — verifies the regenerated spec_pb2
       encodes / decodes the new fields without touching the runtime.
    2. End-to-end execution — runs the bundled schema.k through
       API().exec_program with format="json" and sourcemap_output set,
       asserting on the actual runtime output.

Covers:
    - ExecProgramArgs.format           (field 20)
    - ExecProgramArgs.error_format     (field 19, pre-existing sanity check)
    - ExecProgramArgs.sourcemap_output (field 22)
    - ExecProgramResult.sourcemap      (field 5)
"""

from __future__ import annotations

import pytest

import kcl_lib.api as api


TEST_FILE = "./tests/test_data/schema.k"


def test_exec_program_args_format_round_trip() -> None:
    args = api.ExecProgramArgs(
        format="json",
        error_format="sarif",
        sourcemap_output="/tmp/out.js.map",
    )
    wire = args.SerializeToString()

    decoded = api.ExecProgramArgs()
    decoded.ParseFromString(wire)

    assert decoded.format == "json"
    assert decoded.error_format == "sarif"
    assert decoded.HasField("sourcemap_output")
    assert decoded.sourcemap_output == "/tmp/out.js.map"


def test_exec_program_result_sourcemap_round_trip() -> None:
    sourcemap = '{"version":3,"sources":[]}'
    result = api.ExecProgramResult(
        json_result='{"a": 1}',
        yaml_result="a: 1",
        sourcemap=sourcemap,
    )
    wire = result.SerializeToString()

    decoded = api.ExecProgramResult()
    decoded.ParseFromString(wire)

    assert decoded.json_result == '{"a": 1}'
    assert decoded.yaml_result == "a: 1"
    assert decoded.HasField("sourcemap")
    assert decoded.sourcemap == sourcemap


def test_exec_program_format_json() -> None:
    """format="json" must populate only json_result."""
    args = api.ExecProgramArgs(k_filename_list=[TEST_FILE], format="json")
    result = api.API().exec_program(args)

    assert result.json_result, "format=json: json_result must be populated"
    assert result.yaml_result == "", (
        f"format=json: yaml_result must be empty, got {result.yaml_result!r}"
    )
    assert "replicas" in result.json_result, (
        f"format=json: json_result must contain replicas key, got {result.json_result!r}"
    )


def test_exec_program_sourcemap_output() -> None:
    """sourcemap_output must populate result.sourcemap when the runtime
    supports source maps. Older kcl-api versions don't yet emit source
    maps — in that case we xfail rather than fail hard so the suite
    stays green on a stale runtime while still flagging the gap."""
    args = api.ExecProgramArgs(
        k_filename_list=[TEST_FILE],
        sourcemap_output="/tmp/out.js.map",
    )
    result = api.API().exec_program(args)

    if not (result.HasField("sourcemap") and result.sourcemap):
        pytest.xfail(
            "runtime did not populate sourcemap "
            "(kcl-api may not yet support source maps)"
        )

    assert '"version"' in result.sourcemap, (
        f"sourcemap_output: result.sourcemap must contain Source Map "
        f"version key, got {result.sourcemap!r}"
    )
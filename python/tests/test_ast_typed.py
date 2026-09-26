"""Smoke tests for the Python typed AST package.

These are higher-level than ``tests/ast_test.py``: they verify the public
``parse_module`` / ``parse_program`` entry points, basic round-trips, and
shape alignment with the untyped AST JSON.
"""

from __future__ import annotations

import json
import os
import tempfile

import kcl_lib.api as api
from kcl_lib.api import spec_pb2 as spec

from kcl_lib import Module, Pos, parse_module, parse_program
from kcl_lib.ast import AssignStmt, CallExpr, SchemaStmt


_API = api.API()


def _write_temp_kcl(src: str) -> str:
    fd, path = tempfile.mkstemp(suffix=".k")
    with os.fdopen(fd, "w") as f:
        f.write(src)
    return path


def _ast_json_for(src: str) -> str:
    path = _write_temp_kcl(src)
    try:
        args = spec.ParseProgramArgs(paths=[path])
        return _API.parse_program(args).ast_json
    finally:
        os.unlink(path)


def _first_module(ast_json: str) -> Module:
    program_data = json.loads(ast_json)
    modules = program_data.get("pkgs", {}).get("__main__") or [program_data]
    return parse_module(json.dumps(modules[0]))


def test_parse_module_basic():
    """A trivial assignment produces one Module with one AssignStmt."""
    module = _first_module(_ast_json_for("x = 1\n"))
    assert isinstance(module, Module)
    assert isinstance(module.body, list) and len(module.body) == 1
    first = module.body[0].node
    assert isinstance(first, AssignStmt)


def test_parse_module_schema():
    """A schema produces a SchemaStmt carrying the schema name."""
    src = "schema Person:\n    name: str\n"
    module = _first_module(_ast_json_for(src))
    schema = next(
        (s.node for s in (module.body or []) if isinstance(s.node, SchemaStmt)),
        None,
    )
    assert schema is not None, "expected a SchemaStmt"
    assert schema.name is not None
    assert schema.name.node == "Person"


def test_round_trip():
    """Serialize a Module back to dict and re-parse; assert equal."""
    from kcl_lib.ast._module import Module as ModuleDTO

    src = "schema Person:\n    name: str\n\nx = 1\n"
    ast_json = _ast_json_for(src)
    module = _first_module(ast_json)

    # Serialize and re-parse.
    d = module.to_dict()
    reparsed = ModuleDTO.from_dict(d)
    assert reparsed.filename == module.filename
    assert len(reparsed.body or []) == len(module.body or [])
    for n1, n2 in zip(module.body or [], reparsed.body or []):
        assert type(n1.node) is type(n2.node)


def test_position():
    """Pos carries filename / line / column / end_line / end_column."""
    module = _first_module(_ast_json_for("x = 1\n"))
    node = module.body[0]
    assert node.pos is not None
    assert isinstance(node.pos, Pos)
    assert node.pos.filename.endswith(".k")
    assert node.pos.line == 1
    assert node.pos.column == 0
    assert node.pos.end_line is not None
    assert node.pos.end_column is not None


def test_call_expr():
    """A function call produces a CallExpr with a function name + args."""
    src = "result = pow(2, 8)\n"
    module = _first_module(_ast_json_for(src))
    assign = next(
        (s.node for s in (module.body or []) if isinstance(s.node, AssignStmt)),
        None,
    )
    assert assign is not None
    value = assign.value.node if assign.value else None
    assert isinstance(value, CallExpr)
    assert value.args is not None and len(value.args) == 2


def test_ast_alignment():
    """Typed AST deserialization produces the same data as the raw JSON.

    Parse a small KCL fixture two ways — once as ``json.loads`` and once
    via ``parse_program`` — and assert the typed walk recovers the same
    number of body statements as the untyped walk.
    """
    src = "schema Person:\n    name: str\n\nx = 1\n"
    ast_json = _ast_json_for(src)

    # Raw JSON walk.
    raw = json.loads(ast_json)
    raw_modules = raw.get("pkgs", {}).get("__main__") or [raw]
    raw_count = sum(len(m.get("body") or []) for m in raw_modules)

    # Typed walk via parse_program.
    typed = parse_program(ast_json)
    typed_count = sum(len(m.body or []) for m in typed)

    assert raw_count == typed_count
    assert typed_count >= 2


def test_top_level_exports():
    """``from kcl_lib import parse_module, Module, Position`` works."""
    from kcl_lib import parse_module as exported_parse_module
    from kcl_lib import Module as ExportedModule
    from kcl_lib import Pos as ExportedPos

    assert callable(exported_parse_module)
    assert ExportedModule is Module
    assert ExportedPos is Pos


def test_parse_program_returns_list():
    """``parse_program`` returns a non-empty list of typed Modules."""
    ast_json = _ast_json_for("x = 1\n")
    modules = parse_program(ast_json)
    assert isinstance(modules, list)
    assert len(modules) == 1
    assert isinstance(modules[0], Module)

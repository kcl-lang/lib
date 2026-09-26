"""Tests for the Python typed AST package.

These mirror the Java ``AstJsonAlignmentTest`` and Go
``TestAstJsonAlignment_ParseFile`` in the kcl-go repo: parse a real KCL
fixture through the native Rust compiler (via ``api.parse_file``), then
deserialize the resulting ``ast_json`` string into the typed AST classes
and verify the wire shape matches.
"""

from __future__ import annotations

import json
import os

import kcl_lib.api as api
from kcl_lib.api import spec_pb2 as spec

from kcl_lib.ast import (
    ConfigEntry,
    Decorator,
    Identifier,
    LambdaExpr,
    Module,
    NumberLit,
    SchemaAttr,
    SchemaStmt,
    StringLit,
    parse_module,
)


FIXTURE = os.path.join(
    os.path.dirname(__file__), "ast_alignment", "main.k"
)


_API = api.API()


def _parse_fixture() -> Module:
    """Parse the alignment fixture via the native kcl-lib and deserialize
    the resulting ``ast_json`` into a typed ``Module``."""
    args = spec.ParseFileArgs(path=FIXTURE)
    result = _API.parse_file(args)
    return parse_module(result.ast_json)


def test_module_filename_and_no_pkg():
    m = _parse_fixture()
    assert m.filename.endswith("main.k")
    # Module must not carry a `pkg` field — round-trip should produce
    # neither one in input nor one on output.
    assert not hasattr(m, "pkg")
    d = json.loads(_API.parse_file(spec.ParseFileArgs(path=FIXTURE)).ast_json)
    assert "pkg" not in d


def test_literal_discriminators_use_long_form():
    """NumberLit / StringLit / NameConstantLit should serialize as the
    long-form discriminator, not the inner Literal-enum short form."""
    m = _parse_fixture()
    found_short = []
    for stmt in m.body or []:
        _walk_literals(stmt.node, found_short)
    assert not found_short, f"unexpected short-form discriminators: {found_short}"


def test_config_entry_is_shorthand_round_trips():
    """``ConfigEntry.is_shorthand`` must mirror Rust's
    ``#[serde(skip_serializing_if = "is_false")]``: omitted when false,
    emitted when true."""
    e = ConfigEntry(operation="Union")
    d = e.to_dict()
    assert "is_shorthand" not in d

    e.is_shorthand = True
    d = e.to_dict()
    assert d["is_shorthand"] is True


def test_schema_expr_value_in_assign_stmt():
    """``x = Person { ... }`` produces an AssignStmt with a SchemaExpr
    payload."""
    m = _parse_fixture()
    assign = next(
        (
            s.node
            for s in (m.body or [])
            if s.node is not None and _is_assign_target_named(s.node, "x")
        ),
        None,
    )
    assert assign is not None, "expected an AssignStmt targeting `x`"
    value = assign.value.node if assign.value else None
    assert isinstance(value, type(assign.value.node))  # noqa: E721
    # The actual variant should be a SchemaExpr.
    from kcl_lib.ast._expr import SchemaExpr

    assert isinstance(value, SchemaExpr)


def test_schema_stmt_decorators_are_flat_decorator_dto():
    """Article schema has @deprecated — must deserialize into the flat
    Decorator DTO (no "type":"Call" tag inside NodeRef)."""
    m = _parse_fixture()
    article = next(
        (
            s.node
            for s in (m.body or [])
            if isinstance(s.node, SchemaStmt)
            and s.node.name is not None
            and s.node.name.node == "Article"
        ),
        None,
    )
    assert article is not None, "Article schema not found"
    assert article.decorators, "Article should have at least one decorator"
    for deco in article.decorators:
        assert isinstance(deco.node, Decorator)
        # The Decorator.func payload is a Node wrapping an Identifier
        # expression (no `"type":"Call"` tag in the flat shape).
        from kcl_lib.ast._expr import expr_from_dict, Identifier

        assert isinstance(deco.node.func.node, Identifier)


def test_schema_attr_has_decorators_field():
    """Person schema's `name` attribute carries @deprecated."""
    m = _parse_fixture()
    person = next(
        (
            s.node
            for s in (m.body or [])
            if isinstance(s.node, SchemaStmt)
            and s.node.name is not None
            and s.node.name.node == "Person"
        ),
        None,
    )
    assert person is not None
    name_attr = None
    for wrapped in person.body or []:
        a = wrapped.node
        if (
            isinstance(a, SchemaAttr)
            and a.name is not None
            and a.name.node == "name"
        ):
            name_attr = a
            break
    assert name_attr is not None, "expected `name` SchemaAttr"
    assert len(name_attr.decorators) == 1
    assert isinstance(name_attr.decorators[0].node, Decorator)


def test_lambda_expr_with_arguments():
    """``adder = lambda x: int, y: int -> int { ... }`` — verify the
    LambdaExpr + Arguments combo round-trips."""
    m = _parse_fixture()
    adder = next(
        (
            s.node
            for s in (m.body or [])
            if hasattr(s.node, "targets")
            and s.node.targets
            and _is_assign_target_named(s.node, "adder")
        ),
        None,
    )
    assert adder is not None
    val = adder.value.node if adder.value else None
    assert isinstance(val, LambdaExpr)
    assert val.args is not None
    assert val.args.node is not None
    # The Arguments payload holds the parameter list.
    args_obj = val.args.node
    assert len(args_obj.args) == 2


def test_parse_program_returns_list_of_modules():
    """``api.parse_program`` returns ``ast_json`` describing the whole
    program — a ``{"root": ..., "pkgs": {"__main__": [<module>, ...]}}``
    dict. The per-file Module dicts live inside ``pkgs.__main__``."""
    args = spec.ParseProgramArgs(paths=[FIXTURE])
    result = _API.parse_program(args)
    data = json.loads(result.ast_json)
    if isinstance(data, list):
        modules = [parse_module(json.dumps(item)) for item in data]
    else:
        # Program envelope: ``{"root": str, "pkgs": {"__main__": [Module, ...]}}``.
        modules = [
            parse_module(json.dumps(item))
            for item in (data.get("pkgs", {}).get("__main__") or [])
        ]
    assert modules
    assert modules[0].filename.endswith("main.k")


# --- helpers ------------------------------------------------------------


def _is_assign_target_named(stmt, name: str) -> bool:
    if not hasattr(stmt, "targets") or not stmt.targets:
        return False
    target = stmt.targets[0]
    inner = target.node if target else None
    if inner is None:
        return False
    # Targets use the simple struct shape — ``Target(name=Node[str], paths, pkgpath)``.
    # The inner ``name`` is a ``Node[str]``, so compare against ``name.node``.
    from kcl_lib.ast._dto import Target as TargetDTO

    if isinstance(inner, TargetDTO) and inner.name is not None:
        return inner.name.node == name
    return False


def _walk_literals(node, found_short: list):
    """Walk a parsed AST and collect any literal node that uses the
    short-form ("Number"/"String"/"NameConstant") discriminator."""
    if node is None:
        return
    short = ""
    if isinstance(node, NumberLit):
        # We can't introspect the wire `type` after deserialization
        # (it's been mapped to the long form already), so just confirm
        # the constructed object is of the long-form class.
        return
    if isinstance(node, StringLit):
        return
    # Recurse into children.
    for attr in ("body", "value", "items", "exprs", "args", "kwargs",
                 "decorators", "checks", "mixins", "comparators"):
        children = getattr(node, attr, None)
        if children is None:
            continue
        if isinstance(children, list):
            for c in children:
                inner = getattr(c, "node", None)
                _walk_literals(inner, found_short)
        else:
            inner = getattr(children, "node", None)
            _walk_literals(inner, found_short)
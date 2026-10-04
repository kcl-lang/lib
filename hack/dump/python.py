#!/usr/bin/env python3
"""Cross-language AST dump for the Python binding.

    python3 hack/dump/python.py <golden.json> <out.json>          # reflective
    python3 hack/dump/python.py <golden.json> <out.json> --wire   # round-trip

Runs the binding's real decoder (``kcl_lib.ast.parse_module``) over the shared
capture and writes the tree in the shape ``hack/ast_diff/canonical.rb``
compares.

Python's decoder is a set of ``@dataclass`` types, so the default walk is
reflective — ``dataclasses.fields()`` for the structure, the concrete class
name for ``@cls``, and the binding's *own* tag registry for ``@tag``. That
gives the comparator three independent claims to cross-check at every tagged
node: the class name, the tag the binding says the class has, and the golden.
It is the same discipline as the Ruby and Dart dumpers.

With ``--wire`` the walk instead returns the binding's own ``to_dict()`` tree
— a genuinely different implementation of the wire shape, written by hand
alongside the decoder. That is a second, independent check of the same
capture: a ``to_dict`` that read a field wrongly would show up here even when
``from_dict`` read it correctly. Its output is the wire verbatim, so there is
no class name to record and the comparator treats it as a raw passthrough
(R12) — which is honest, and is what the ``mode`` field in the dump says.

``kcl_lib/__init__.py`` does ``from ._kcl_lib import *``, so importing the
package pulls in the compiled extension. The AST subpackage does not use it,
and the binding's own contract test installs the same stub — so this does too
rather than pretending a built ``_kcl_lib`` is required.
"""

import dataclasses
import json
import os
import sys
import types

# Install the `kcl_lib` package stub before importing the AST subpackage, so
# the compiled `_kcl_lib` extension is not needed. Same trick as
# `hack/ast_diff/bindings.rb`'s probe.
_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(_ROOT, "python"))
_stub = types.ModuleType("kcl_lib")
_stub.__path__ = [os.path.join(_ROOT, "python", "kcl_lib")]
sys.modules["kcl_lib"] = _stub

import kcl_lib.ast as A  # noqa: E402
from kcl_lib.ast import _base, _expr, _stmt, _types  # noqa: E402

# The binding's own tag registries. These are the inverse maps the decoder
# itself dispatches through, so a tag here is the binding's own claim rather
# than something this dumper worked out.
TAG_FOR = {
    _expr.Expr: _expr._expr_tag_for,
    _stmt.Stmt: _stmt._stmt_tag_for,
    _types.Type: _types._type_tag_for,
}


def tag_for(value):
    """The wire tag the binding's own registry gives this object's class."""
    for base, lookup in TAG_FOR.items():
        if isinstance(value, base):
            return lookup(type(value))
    return None


def short(name: str) -> str:
    """`kcl_lib.ast._expr.IdentifierExpr` -> `IdentifierExpr`."""
    return name.rsplit(".", 1)[-1]


def dump_reflect(value):
    """Walk the decoded object graph by reflection. Nothing is reshaped."""
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    if isinstance(value, (list, tuple)):
        return [dump_reflect(item) for item in value]
    if not dataclasses.is_dataclass(value):
        # `MemberOrIndex.value` and `UnknownExpr.value` are held as the raw
        # wire object; walking them is walking the wire, and the comparator
        # knows to treat that as a passthrough.
        if isinstance(value, dict):
            return {str(k): dump_reflect(v) for k, v in value.items()}
        return value

    cls = short(type(value).__name__)
    out = {"@cls": cls}
    tag = tag_for(value)
    if tag is not None:
        out["@tag"] = tag
    for f in dataclasses.fields(value):
        out[f.name] = dump_reflect(getattr(value, f.name))
    return out


def dump_wire(value):
    """Hand the object to the binding's own serializer and keep the result."""
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    if isinstance(value, (list, tuple)):
        return [dump_wire(item) for item in value]
    if hasattr(value, "to_dict"):
        inner = value.to_dict()
        return inner if isinstance(inner, dict) else {"@cls": short(type(value).__name__), **inner}
    if dataclasses.is_dataclass(value):
        out = {"@cls": short(type(value).__name__)}
        for f in dataclasses.fields(value):
            out[f.name] = dump_wire(getattr(value, f.name))
        return out
    if isinstance(value, dict):
        return {str(k): dump_wire(v) for k, v in value.items()}
    return value


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if len(args) != 2:
        print("usage: python3 hack/dump/python.py <golden.json> <out.json> [--wire]", file=sys.stderr)
        return 2

    golden_path, out_path = args
    wire = "--wire" in sys.argv[1:]

    with open(golden_path, encoding="utf-8") as fh:
        module_ast = A.parse_module(fh.read())

    root = dump_wire(module_ast) if wire else dump_reflect(module_ast)
    # `Pos` is the only type whose `to_dict` is a leaf serializer, so the wire
    # walk still records a class name for it; nothing else below `Module` does
    # because `Module.to_dict` is recursive.

    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(
            {"schema": "kcl-ast-canonical/1", "binding": "python",
             "mode": "wire" if wire else "reflect", "root": root},
            fh,
            indent=2,
        )
        fh.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

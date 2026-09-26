"""Base AST infrastructure: ``Node``, ``Pos``, ``Comment``, and the
``parse_module`` / ``parse_program`` entry points.

The Rust AST crate (see ``kcl-lang/kcl/crates/ast/src/ast.rs``) wraps every
trivia in a ``Node<T>`` with positional metadata. This module provides the
Python equivalent.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Generic, List, Optional, TypeVar

T = TypeVar("T")


@dataclass
class Pos:
    """Source position tuple (filename, line, column, end_line, end_column).

    Mirrors Rust's ``ast::Pos``. All five fields are optional on the wire —
    omitted positions surface as ``None`` (Rust omits them via
    ``#[serde(skip_serializing_if = "...")]``).
    """

    filename: Optional[str] = None
    line: Optional[int] = None
    column: Optional[int] = None
    end_line: Optional[int] = None
    end_column: Optional[int] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["Pos"]:
        if d is None:
            return None
        return cls(
            filename=d.get("filename"),
            line=d.get("line"),
            column=d.get("column"),
            end_line=d.get("end_line"),
            end_column=d.get("end_column"),
        )

    def to_dict(self) -> dict:
        d: dict = {}
        if self.filename is not None:
            d["filename"] = self.filename
        if self.line is not None:
            d["line"] = self.line
        if self.column is not None:
            d["column"] = self.column
        if self.end_line is not None:
            d["end_line"] = self.end_line
        if self.end_column is not None:
            d["end_column"] = self.end_column
        return d


@dataclass
class Node(Generic[T]):
    """``Node<T>`` — the positional wrapper around any AST payload.

    Mirrors Rust's ``ast::Node<T>``. The optional ``id`` field is the
    AST-index into the symbol table; ``node`` holds the actual payload.
    """

    node: Optional[T] = None
    id: Optional[str] = None
    pos: Optional[Pos] = None

    @classmethod
    def from_dict(cls, d: Optional[dict], inner_loader=None) -> Optional["Node[T]"]:
        """Deserialize a Node. ``inner_loader(node_dict) -> T`` resolves the
        polymorphic payload (e.g. ``expr_from_dict``)."""
        if d is None:
            return None
        inner = d.get("node")
        if inner_loader is not None:
            payload = inner_loader(inner)
        else:
            payload = inner
        return cls(
            node=payload,
            id=d.get("id"),
            pos=Pos.from_dict(
                {k: v for k, v in d.items() if k != "node" and k != "id"}
            ),
        )

    def to_dict(self, inner_dumper=None) -> dict:
        """Serialize. ``inner_dumper(node) -> dict`` turns ``self.node``
        into its dict representation. The ``pos`` fields are flattened
        alongside ``node`` and ``id`` to match the wire shape."""
        if inner_dumper is not None and self.node is not None:
            inner = inner_dumper(self.node)
        else:
            inner = self.node
        d: dict = {"node": inner}
        if self.id is not None:
            d["id"] = self.id
        if self.pos is not None:
            d.update(self.pos.to_dict())
        return d


@dataclass
class Comment:
    """A line/block comment captured during parsing."""

    text: str = ""

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["Comment"]:
        if d is None:
            return None
        node = d.get("node") or {}
        return cls(text=node.get("text", ""))

    def to_dict(self) -> dict:
        return {"text": self.text}


# The two top-level parsers. Imported lazily to avoid a circular import
# between ``_base`` and the concrete type modules (``_stmt``, ``_module``).


def parse_module(ast_json: str) -> "Module":  # noqa: F821
    """Parse an ``ast_json`` string from ``ParseFileResult.ast_json`` into a
    typed ``Module``."""
    from ._module import Module

    data = json.loads(ast_json)
    return Module.from_dict(data)


def parse_program(program_json: str) -> List["Module"]:  # noqa: F821
    """Parse the JSON document emitted by ``ParseProgramResult.ast_json`` /
    ``LoadPackageResult.program`` into a list of typed ``Module``s — one
    per file in the program."""
    from ._module import Module

    data = json.loads(program_json)
    if isinstance(data, list):
        return [Module.from_dict(item) for item in data]
    if isinstance(data, dict):
        # Program envelope: ``{"root": str, "pkgs": {"__main__": [Module, ...]}}``.
        # The per-file Module dicts live inside ``pkgs.__main__`` — flat list
        # of modules, one per file in the program.
        pkgs = data.get("pkgs")
        if isinstance(pkgs, dict):
            main = pkgs.get("__main__")
            if isinstance(main, list):
                return [Module.from_dict(item) for item in main]
            if main is None:
                # pkgs.__main__ may be absent for empty programs.
                return []
        # Legacy shapes: single Module, or a map keyed by filename.
        try:
            return [Module.from_dict(data)]
        except Exception:
            return [Module.from_dict(v) for v in data.values()]
    raise ValueError(f"unexpected program JSON shape: {type(data).__name__}")
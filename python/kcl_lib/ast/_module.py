"""Module — the root AST node. Mirrors ``ast::Module`` in
``kcl-lang/kcl/crates/ast/src/ast.rs``.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional


@dataclass
class Module:
    """Top-level AST node for a single KCL file.

    Note: Rust's Module has no ``pkg`` field. The Java and Go bindings
    previously exposed one and were aligned to drop it.
    """

    filename: str = ""
    doc: Optional["Node[str]"] = None
    body: Optional[List["Node[object]"]] = None
    comments: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "Module":
        from ._base import Comment, Node
        from ._stmt import stmt_from_dict

        body_raw = d.get("body") or []
        comments_raw = d.get("comments") or []
        return cls(
            filename=d.get("filename", ""),
            doc=Node.from_dict(d.get("doc"), lambda x: x),
            body=[Node.from_dict(b, stmt_from_dict) for b in body_raw],
            comments=[
                Node.from_dict(c, lambda x: Comment.from_dict(x))
                for c in comments_raw
            ],
        )

    def to_dict(self) -> dict:
        from ._base import Node
        from ._stmt import stmt_to_dict

        d: dict = {"filename": self.filename}
        if self.doc is not None:
            d["doc"] = Node.to_dict(self.doc, lambda x: x)
        if self.body is not None:
            d["body"] = [Node.to_dict(b, stmt_to_dict) for b in self.body]
        if self.comments is not None:
            d["comments"] = [
                Node.to_dict(c, lambda x: Comment.to_dict(x))
                if not isinstance(c.node, Comment)
                else c.node.to_dict()
                for c in self.comments
            ]
        return d

    def filter_schemas(self) -> List["SchemaStmt"]:
        """Return every SchemaStmt in the module body. Mirrors Rust's
        ``Module::filter_schema_stmt_from_module``."""
        from ._stmt import SchemaStmt

        out: List[SchemaStmt] = []
        for wrapped in self.body or []:
            inner = wrapped.node if wrapped else None
            if isinstance(inner, SchemaStmt):
                out.append(inner)
        return out
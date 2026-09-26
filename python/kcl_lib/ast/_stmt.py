"""Statement hierarchy — mirrors ``ast::Stmt`` in
``kcl-lang/kcl/crates/ast/src/ast.rs``.

The Rust enum uses ``#[serde(tag = "type")]``, so each variant appears
in JSON as a ``{"type": "<Variant>", ...}`` object. ``stmt_from_dict``
dispatches on that tag.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional


@dataclass
class Stmt:
    """Base class. Concrete variants subclass this and add their fields."""


@dataclass
class ExprStmt(Stmt):
    """A bare expression statement, e.g. ``"A long string"`` at module scope."""

    exprs: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "ExprStmt":
        from ._base import Node
        from ._expr import expr_from_dict

        return cls(
            exprs=[Node.from_dict(e, expr_from_dict) for e in d.get("exprs") or []]
        )


@dataclass
class UnificationStmt(Stmt):
    """``data: ASchema {}`` — declare with the union operator.

    The ``value`` field's wire shape is the *flat* ``SchemaConfig``
    payload (no ``"type":"Schema"`` discriminator) — see ``AST_DRIFT.md``
    note A in the ``kcl-lang/lib`` repo.
    """

    target: Optional["Node[object]"] = None
    value: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "UnificationStmt":
        from ._base import Node
        from ._dto import SchemaConfig

        return cls(
            target=Node.from_dict(d.get("target"), lambda x: x),
            value=Node.from_dict(d.get("value"), lambda x: SchemaConfig.from_dict(x)),
        )


@dataclass
class AssignStmt(Stmt):
    """``a: int = 1`` / ``a.b["key"] = "value"``."""

    targets: Optional[List["Node[object]"]] = None
    ty: Optional["Node[object]"] = None
    value: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "AssignStmt":
        from ._base import Node
        from ._dto import Target as TargetDTO
        from ._expr import expr_from_dict
        from ._types import type_from_dict

        return cls(
            targets=[
                Node.from_dict(t, lambda x: TargetDTO.from_dict(x))
                for t in d.get("targets") or []
            ],
            ty=Node.from_dict(d.get("ty"), lambda x: type_from_dict(x)),
            value=Node.from_dict(d.get("value"), expr_from_dict),
        )


@dataclass
class SchemaStmt(Stmt):
    """``schema Foo(Base): ...`` / ``mixin ...`` / ``protocol ...``.

    Decorators on a schema are the flat ``Decorator`` DTOs — see
    ``AST_DRIFT.md`` note A.
    """

    doc: Optional["Node[str]"] = None
    name: Optional["Node[str]"] = None
    parent_name: Optional["Node[object]"] = None
    for_host_name: Optional["Node[object]"] = None
    is_mixin: bool = False
    is_protocol: bool = False
    args: Optional["Node[object]"] = None
    mixins: Optional[List["Node[object]"]] = None
    body: Optional[List["Node[object]"]] = None
    decorators: Optional[List["Node[object]"]] = None
    checks: Optional[List["Node[object]"]] = None
    index_signature: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "SchemaStmt":
        from ._base import Node
        from ._dto import Arguments, Decorator
        from ._expr import expr_from_dict

        body_raw = d.get("body") or []
        return cls(
            doc=Node.from_dict(d.get("doc"), lambda x: x),
            name=Node.from_dict(d.get("name"), lambda x: x),
            parent_name=Node.from_dict(d.get("parent_name"), lambda x: x),
            for_host_name=Node.from_dict(d.get("for_host_name"), lambda x: x),
            is_mixin=d.get("is_mixin", False),
            is_protocol=d.get("is_protocol", False),
            args=Node.from_dict(d.get("args"), lambda x: Arguments.from_dict(x)),
            mixins=[Node.from_dict(m, lambda x: x) for m in d.get("mixins") or []],
            body=[Node.from_dict(b, stmt_from_dict) for b in body_raw],
            decorators=[
                Node.from_dict(deco, lambda x: Decorator.from_dict(x))
                for deco in d.get("decorators") or []
            ],
            checks=[
                Node.from_dict(c, lambda x: expr_from_dict(x))
                for c in d.get("checks") or []
            ],
            index_signature=Node.from_dict(d.get("index_signature"), lambda x: x),
        )


@dataclass
class SchemaAttr(Stmt):
    """``x: int = 1`` — one attribute declaration inside a schema."""

    doc: str = ""
    name: Optional["Node[str]"] = None
    op: Optional[str] = None  # AugOp
    value: Optional["Node[object]"] = None
    is_optional: bool = False
    decorators: Optional[List["Node[object]"]] = None
    ty: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "SchemaAttr":
        from ._base import Node
        from ._dto import Decorator
        from ._expr import expr_from_dict
        from ._types import type_from_dict

        return cls(
            doc=d.get("doc", ""),
            name=Node.from_dict(d.get("name"), lambda x: x),
            op=d.get("op"),
            value=Node.from_dict(d.get("value"), expr_from_dict),
            is_optional=d.get("is_optional", False),
            decorators=[
                Node.from_dict(deco, lambda x: Decorator.from_dict(x))
                for deco in d.get("decorators") or []
            ],
            ty=Node.from_dict(d.get("ty"), lambda x: type_from_dict(x)),
        )


@dataclass
class RuleStmt(Stmt):
    """``rule Foo: ...`` — KCL rule statement."""

    doc: Optional["Node[str]"] = None
    name: Optional["Node[str]"] = None
    parent_rules: Optional[List["Node[object]"]] = None
    decorators: Optional[List["Node[object]"]] = None
    checks: Optional[List["Node[object]"]] = None
    args: Optional["Node[object]"] = None
    for_host_name: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "RuleStmt":
        from ._base import Node
        from ._dto import Arguments, Decorator
        from ._expr import expr_from_dict

        return cls(
            doc=Node.from_dict(d.get("doc"), lambda x: x),
            name=Node.from_dict(d.get("name"), lambda x: x),
            parent_rules=[
                Node.from_dict(p, lambda x: x) for p in d.get("parent_rules") or []
            ],
            decorators=[
                Node.from_dict(deco, lambda x: Decorator.from_dict(x))
                for deco in d.get("decorators") or []
            ],
            checks=[
                Node.from_dict(c, lambda x: expr_from_dict(x))
                for c in d.get("checks") or []
            ],
            args=Node.from_dict(d.get("args"), lambda x: Arguments.from_dict(x)),
            for_host_name=Node.from_dict(d.get("for_host_name"), lambda x: x),
        )


@dataclass
class ImportStmt(Stmt):
    """``import kcl_plugin.hello`` / ``import as ...``."""

    path: Optional[str] = None
    as_name: Optional[str] = None
    pkg_name: Optional[str] = None
    pkg_root: Optional[str] = None

    @classmethod
    def from_dict(cls, d: dict) -> "ImportStmt":
        node = d.get("node") or {}
        return cls(
            path=node.get("path"),
            as_name=node.get("as_name"),
            pkg_name=node.get("pkg_name"),
            pkg_root=node.get("pkg_root"),
        )


@dataclass
class AugAssignStmt(Stmt):
    """``a += 1`` — augmented assignment."""

    target: Optional["Node[object]"] = None
    op: Optional[str] = None  # AugOp
    value: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "AugAssignStmt":
        from ._base import Node
        from ._dto import Target as TargetDTO
        from ._expr import expr_from_dict

        return cls(
            target=Node.from_dict(d.get("target"), lambda x: TargetDTO.from_dict(x)),
            op=d.get("op"),
            value=Node.from_dict(d.get("value"), expr_from_dict),
        )


@dataclass
class IfStmt(Stmt):
    """``if cond: ...`` — module-level if statement (different from IfExpr)."""

    cond: Optional["Node[object]"] = None
    body: Optional[List["Node[object]"]] = None
    orelse: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "IfStmt":
        from ._base import Node
        from ._expr import expr_from_dict

        return cls(
            cond=Node.from_dict(d.get("cond"), expr_from_dict),
            body=[Node.from_dict(b, stmt_from_dict) for b in d.get("body") or []],
            orelse=[
                Node.from_dict(b, stmt_from_dict) for b in d.get("orelse") or []
            ],
        )


@dataclass
class TypeAliasStmt(Stmt):
    """``type X = int`` — type alias statement."""

    name: Optional["Node[str]"] = None
    ty: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "TypeAliasStmt":
        from ._base import Node
        from ._types import type_from_dict

        return cls(
            name=Node.from_dict(d.get("name"), lambda x: x),
            ty=Node.from_dict(d.get("ty"), lambda x: type_from_dict(x)),
        )


@dataclass
class AssertStmt(Stmt):
    """``assert a > 0, "must be positive"`` — assertion statement."""

    test: Optional["Node[object]"] = None
    msg: Optional["Node[str]"] = None
    if_cond: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "AssertStmt":
        from ._base import Node
        from ._expr import expr_from_dict

        return cls(
            test=Node.from_dict(d.get("test"), expr_from_dict),
            msg=Node.from_dict(d.get("msg"), lambda x: x),
            if_cond=Node.from_dict(d.get("if_cond"), expr_from_dict),
        )


_STMT_REGISTRY = {
    "Expr": ExprStmt,
    "Unification": UnificationStmt,
    "Assign": AssignStmt,
    "Schema": SchemaStmt,
    "SchemaAttr": SchemaAttr,
    "Rule": RuleStmt,
    "Import": ImportStmt,
    "AugAssign": AugAssignStmt,
    "If": IfStmt,
    "TypeAlias": TypeAliasStmt,
    "Assert": AssertStmt,
}


def stmt_from_dict(d: Optional[dict]) -> Optional[Stmt]:
    """Polymorphic Stmt loader. Mirrors Rust's ``#[serde(tag = "type")]``
    on ``ast::Stmt``."""
    if d is None:
        return None
    if not isinstance(d, dict):
        return None
    variant = d.get("type")
    if variant is None:
        return None
    cls = _STMT_REGISTRY.get(variant)
    if cls is None:
        return Stmt()
    return cls.from_dict(d)


def stmt_to_dict(stmt: "Stmt") -> dict:
    """Polymorphic Stmt serializer. Round-trips back through ``stmt_from_dict``
    via the same ``"type":"<Variant>"`` discriminator the wire shape uses."""
    if stmt is None:
        return {}
    if isinstance(stmt, Stmt) and type(stmt) is Stmt:
        # Unknown / fallback — emit only the variant tag.
        return {"type": getattr(stmt, "_variant", "Unknown")}
    # Resolve the wire tag from the variant name: "AssignStmt" -> "Assign".
    tag = _STMT_TAG_BY_CLASS.get(type(stmt)) or type(stmt).__name__
    inner = _stmt_inner_to_dict(stmt)
    inner["type"] = tag
    return inner


_STMT_TAG_BY_CLASS = {cls: tag for tag, cls in _STMT_REGISTRY.items()}


def _stmt_inner_to_dict(stmt: "Stmt") -> dict:
    from ._base import Node
    from ._dto import (
        Arguments,
        Decorator,
        SchemaConfig,
        Target as TargetDTO,
    )
    from ._expr import expr_to_dict
    from ._types import type_to_dict

    if isinstance(stmt, ExprStmt):
        return {"exprs": [Node.to_dict(e, expr_to_dict) for e in (stmt.exprs or [])]}
    if isinstance(stmt, UnificationStmt):
        return {
            "target": Node.to_dict(stmt.target, lambda x: x)
            if stmt.target
            else None,
            "value": Node.to_dict(stmt.value, lambda x: SchemaConfig.to_dict(x))
            if stmt.value
            else None,
        }
    if isinstance(stmt, AssignStmt):
        return {
            "targets": [
                Node.to_dict(t, lambda x: TargetDTO.to_dict(x))
                for t in (stmt.targets or [])
            ],
            "ty": Node.to_dict(stmt.ty, lambda x: type_to_dict(x))
            if stmt.ty
            else None,
            "value": Node.to_dict(stmt.value, expr_to_dict) if stmt.value else None,
        }
    if isinstance(stmt, SchemaStmt):
        return {
            "doc": Node.to_dict(stmt.doc, lambda x: x) if stmt.doc else None,
            "name": Node.to_dict(stmt.name, lambda x: x) if stmt.name else None,
            "parent_name": Node.to_dict(stmt.parent_name, lambda x: x)
            if stmt.parent_name
            else None,
            "for_host_name": Node.to_dict(stmt.for_host_name, lambda x: x)
            if stmt.for_host_name
            else None,
            "is_mixin": stmt.is_mixin,
            "is_protocol": stmt.is_protocol,
            "args": Node.to_dict(stmt.args, lambda x: Arguments.to_dict(x))
            if stmt.args
            else None,
            "mixins": [
                Node.to_dict(m, lambda x: x) for m in (stmt.mixins or [])
            ],
            "body": [Node.to_dict(b, stmt_to_dict) for b in (stmt.body or [])],
            "decorators": [
                Node.to_dict(d, lambda x: Decorator.to_dict(x))
                for d in (stmt.decorators or [])
            ],
            "checks": [
                Node.to_dict(c, expr_to_dict) for c in (stmt.checks or [])
            ],
            "index_signature": Node.to_dict(stmt.index_signature, lambda x: x)
            if stmt.index_signature
            else None,
        }
    if isinstance(stmt, SchemaAttr):
        return {
            "doc": stmt.doc,
            "name": Node.to_dict(stmt.name, lambda x: x) if stmt.name else None,
            "op": stmt.op,
            "value": Node.to_dict(stmt.value, expr_to_dict)
            if stmt.value
            else None,
            "is_optional": stmt.is_optional,
            "decorators": [
                Node.to_dict(d, lambda x: Decorator.to_dict(x))
                for d in (stmt.decorators or [])
            ],
            "ty": Node.to_dict(stmt.ty, lambda x: type_to_dict(x))
            if stmt.ty
            else None,
        }
    if isinstance(stmt, RuleStmt):
        return {
            "doc": Node.to_dict(stmt.doc, lambda x: x) if stmt.doc else None,
            "name": Node.to_dict(stmt.name, lambda x: x) if stmt.name else None,
            "parent_rules": [
                Node.to_dict(p, lambda x: x) for p in (stmt.parent_rules or [])
            ],
            "decorators": [
                Node.to_dict(d, lambda x: Decorator.to_dict(x))
                for d in (stmt.decorators or [])
            ],
            "checks": [
                Node.to_dict(c, expr_to_dict) for c in (stmt.checks or [])
            ],
            "args": Node.to_dict(stmt.args, lambda x: Arguments.to_dict(x))
            if stmt.args
            else None,
            "for_host_name": Node.to_dict(stmt.for_host_name, lambda x: x)
            if stmt.for_host_name
            else None,
        }
    if isinstance(stmt, ImportStmt):
        return {"node": stmt.to_dict() if hasattr(stmt, "to_dict") else {}}
    if isinstance(stmt, AugAssignStmt):
        return {
            "target": Node.to_dict(stmt.target, lambda x: TargetDTO.to_dict(x))
            if stmt.target
            else None,
            "op": stmt.op,
            "value": Node.to_dict(stmt.value, expr_to_dict)
            if stmt.value
            else None,
        }
    if isinstance(stmt, IfStmt):
        return {
            "cond": Node.to_dict(stmt.cond, expr_to_dict) if stmt.cond else None,
            "body": [Node.to_dict(b, stmt_to_dict) for b in (stmt.body or [])],
            "orelse": [Node.to_dict(b, stmt_to_dict) for b in (stmt.orelse or [])],
        }
    if isinstance(stmt, TypeAliasStmt):
        return {
            "name": Node.to_dict(stmt.name, lambda x: x) if stmt.name else None,
            "ty": Node.to_dict(stmt.ty, lambda x: type_to_dict(x))
            if stmt.ty
            else None,
        }
    if isinstance(stmt, AssertStmt):
        return {
            "test": Node.to_dict(stmt.test, expr_to_dict) if stmt.test else None,
            "msg": Node.to_dict(stmt.msg, lambda x: x) if stmt.msg else None,
            "if_cond": Node.to_dict(stmt.if_cond, expr_to_dict)
            if stmt.if_cond
            else None,
        }
    return {}
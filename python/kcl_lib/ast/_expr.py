"""Expression hierarchy — mirrors ``ast::Expr`` in
``kcl-lang/kcl/crates/ast/src/ast.rs``.

The Rust enum uses an internally-tagged representation
(``#[serde(tag = "type")]``), so each variant appears in JSON as a
``{"type": "<Variant>", ...}`` object. ``expr_from_dict`` dispatches on
that tag.

When an expression appears nested under a ``NodeRef<T>`` *inside* a parent
field (e.g. inside ``SchemaStmt.decorators``), the outer discriminator
is gone — the JSON is the flat payload. Use the ``Decorator`` /
``SchemaConfig`` DTOs in ``_dto.py`` for those positions instead of
``expr_from_dict``.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import List, Optional


class ExprContext(str, Enum):
    Load = "Load"
    Store = "Store"


class NameConstant(str, Enum):
    True_ = "True"
    False_ = "False"
    None_ = "None"
    Undefined = "Undefined"


@dataclass
class Expr:
    """Base class. Concrete variants subclass this and add their fields."""


@dataclass
class Target(Expr):
    """``Expr::Target(Target)`` — assignment target as an expression.

    Mirrors Rust's ``Expr::Target`` variant — same wire payload as the
    bare ``ast::Target`` struct (``name``, ``paths``, ``pkgpath``), but
    with the outer ``"type":"Target"`` discriminator added by the
    polymorphic enum encoding.
    """

    name: Optional["Node[str]"] = None
    paths: Optional[List[object]] = None  # List[MemberOrIndex]
    pkgpath: str = ""

    @classmethod
    def from_dict(cls, d: dict) -> "Target":
        from ._dto import Target as TargetDTO

        inner = {k: v for k, v in d.items() if k != "type"}
        dto = TargetDTO.from_dict(inner)
        return cls(
            name=dto.name if dto else None,
            paths=dto.paths if dto else None,
            pkgpath=(dto.pkgpath if dto else ""),
        )


@dataclass
class Identifier(Expr):
    """A bare identifier reference. Same shape as ``Target`` minus the
    multi-segment ``names`` chain — used as the leaf in selector chains
    and as the receiver of assignments.
    """

    names: Optional[List["Node[object]"]] = None
    pkgpath: str = ""
    ctx: Optional[str] = None

    @classmethod
    def from_dict(cls, d: dict) -> "Identifier":
        from ._base import Node

        return cls(
            names=[Node.from_dict(n, lambda x: x) for n in d.get("names") or []]
            or None,
            pkgpath=d.get("pkgpath", ""),
            ctx=d.get("ctx"),
        )


@dataclass
class UnaryExpr(Expr):
    op: Optional[str] = None  # UnaryOp
    operand: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "UnaryExpr":
        from ._base import Node

        return cls(
            op=d.get("op"),
            operand=Node.from_dict(d.get("operand"), expr_from_dict),
        )


@dataclass
class BinaryExpr(Expr):
    left: Optional["Node[object]"] = None
    op: Optional[str] = None
    right: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "BinaryExpr":
        from ._base import Node

        return cls(
            left=Node.from_dict(d.get("left"), expr_from_dict),
            op=d.get("op"),
            right=Node.from_dict(d.get("right"), expr_from_dict),
        )


@dataclass
class IfExpr(Expr):
    body: Optional["Node[object]"] = None
    cond: Optional["Node[object]"] = None
    orelse: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "IfExpr":
        from ._base import Node

        return cls(
            body=Node.from_dict(d.get("body"), expr_from_dict),
            cond=Node.from_dict(d.get("cond"), expr_from_dict),
            orelse=Node.from_dict(d.get("orelse"), expr_from_dict),
        )


@dataclass
class SelectorExpr(Expr):
    value: Optional["Node[object]"] = None
    attr: Optional["Node[object]"] = None
    ctx: Optional[str] = None
    has_question: bool = False

    @classmethod
    def from_dict(cls, d: dict) -> "SelectorExpr":
        from ._base import Node

        return cls(
            value=Node.from_dict(d.get("value"), expr_from_dict),
            attr=Node.from_dict(d.get("attr"), expr_from_dict),
            ctx=d.get("ctx"),
            has_question=d.get("has_question", False),
        )


@dataclass
class CallExpr(Expr):
    func: Optional["Node[object]"] = None
    args: Optional[List["Node[object]"]] = None
    keywords: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "CallExpr":
        from ._base import Node

        return cls(
            func=Node.from_dict(d.get("func"), expr_from_dict),
            args=[Node.from_dict(a, expr_from_dict) for a in d.get("args") or []],
            keywords=[
                Node.from_dict(k, lambda x: _keyword_from_dict(x))
                for k in d.get("keywords") or []
            ],
        )


@dataclass
class ParenExpr(Expr):
    expr: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "ParenExpr":
        from ._base import Node

        return cls(expr=Node.from_dict(d.get("expr"), expr_from_dict))


@dataclass
class QuantExpr(Expr):
    target: Optional["Node[object]"] = None
    variables: Optional[List["Node[object]"]] = None
    op: Optional[str] = None
    test: Optional["Node[object]"] = None
    if_cond: Optional["Node[object]"] = None
    ctx: Optional[str] = None

    @classmethod
    def from_dict(cls, d: dict) -> "QuantExpr":
        from ._base import Node

        return cls(
            target=Node.from_dict(d.get("target"), expr_from_dict),
            variables=[
                Node.from_dict(v, expr_from_dict) for v in d.get("variables") or []
            ],
            op=d.get("op"),
            test=Node.from_dict(d.get("test"), expr_from_dict),
            if_cond=Node.from_dict(d.get("if_cond"), expr_from_dict),
            ctx=d.get("ctx"),
        )


@dataclass
class ListExpr(Expr):
    elts: Optional[List["Node[object]"]] = None
    ctx: Optional[str] = None

    @classmethod
    def from_dict(cls, d: dict) -> "ListExpr":
        from ._base import Node

        return cls(
            elts=[Node.from_dict(e, expr_from_dict) for e in d.get("elts") or []],
            ctx=d.get("ctx"),
        )


@dataclass
class ListIfItemExpr(Expr):
    if_cond: Optional["Node[object]"] = None
    exprs: Optional[List["Node[object]"]] = None
    orelse: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "ListIfItemExpr":
        from ._base import Node

        return cls(
            if_cond=Node.from_dict(d.get("if_cond"), expr_from_dict),
            exprs=[Node.from_dict(e, expr_from_dict) for e in d.get("exprs") or []],
            orelse=Node.from_dict(d.get("orelse"), expr_from_dict),
        )


@dataclass
class ListComp(Expr):
    elt: Optional["Node[object]"] = None
    generators: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "ListComp":
        from ._base import Node

        return cls(
            elt=Node.from_dict(d.get("elt"), expr_from_dict),
            generators=[
                Node.from_dict(g, expr_from_dict)
                for g in d.get("generators") or []
            ],
        )


@dataclass
class StarredExpr(Expr):
    value: Optional["Node[object]"] = None
    ctx: Optional[str] = None

    @classmethod
    def from_dict(cls, d: dict) -> "StarredExpr":
        from ._base import Node

        return cls(
            value=Node.from_dict(d.get("value"), expr_from_dict),
            ctx=d.get("ctx"),
        )


@dataclass
class DictComp(Expr):
    """``{k: v for ...}`` — dict comprehension."""

    entry_key: Optional["Node[object]"] = None  # older Rust versions
    key: Optional["Node[object]"] = None
    value: Optional["Node[object]"] = None
    generators: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "DictComp":
        from ._base import Node

        return cls(
            entry_key=Node.from_dict(d.get("entry_key"), expr_from_dict),
            key=Node.from_dict(d.get("key"), expr_from_dict),
            value=Node.from_dict(d.get("value"), expr_from_dict),
            generators=[
                Node.from_dict(g, expr_from_dict)
                for g in d.get("generators") or []
            ],
        )


@dataclass
class ConfigIfEntryExpr(Expr):
    if_cond: Optional["Node[object]"] = None
    items: Optional[List["Node[object]"]] = None
    orelse: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "ConfigIfEntryExpr":
        from ._base import Node

        return cls(
            if_cond=Node.from_dict(d.get("if_cond"), expr_from_dict),
            items=[
                Node.from_dict(i, lambda x: _config_entry_from_dict(x))
                for i in d.get("items") or []
            ],
            orelse=Node.from_dict(d.get("orelse"), expr_from_dict),
        )


@dataclass
class CompClause(Expr):
    targets: Optional[List["Node[object]"]] = None
    iter: Optional["Node[object]"] = None
    ifs: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "CompClause":
        from ._base import Node

        return cls(
            targets=[
                Node.from_dict(t, expr_from_dict) for t in d.get("targets") or []
            ],
            iter=Node.from_dict(d.get("iter"), expr_from_dict),
            ifs=[Node.from_dict(i, expr_from_dict) for i in d.get("ifs") or []],
        )


@dataclass
class SchemaExpr(Expr):
    """``ASchema(args) { ... }`` — the schema instantiation expression.

    When this is nested directly under a parent like
    ``UnificationStmt.value``, the outer ``"type":"Schema"`` discriminator
    is gone — use ``SchemaConfig`` from ``_dto.py`` for that position.
    """

    name: Optional["Node[object]"] = None
    args: Optional[List["Node[object]"]] = None
    kwargs: Optional[List["Node[object]"]] = None
    config: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "SchemaExpr":
        from ._base import Node

        return cls(
            name=Node.from_dict(d.get("name"), expr_from_dict),
            args=[Node.from_dict(a, expr_from_dict) for a in d.get("args") or []],
            kwargs=[
                Node.from_dict(k, lambda x: _keyword_from_dict(x))
                for k in d.get("kwargs") or []
            ],
            config=Node.from_dict(d.get("config"), expr_from_dict),
        )


@dataclass
class ConfigExpr(Expr):
    """``{key = value, ...}`` — config / dict literal."""

    items: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "ConfigExpr":
        from ._base import Node

        return cls(
            items=[
                Node.from_dict(i, lambda x: _config_entry_from_dict(x))
                for i in d.get("items") or []
            ]
        )


@dataclass
class LambdaExpr(Expr):
    args: Optional["Node[object]"] = None
    body: Optional[List["Node[object]"]] = None
    return_ty: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "LambdaExpr":
        from ._base import Node

        return cls(
            args=Node.from_dict(d.get("args"), lambda x: _arguments_from_dict(x)),
            body=[Node.from_dict(b, expr_from_dict) for b in d.get("body") or []],
            return_ty=Node.from_dict(
                d.get("return_ty"), lambda x: type_from_dict(x)
            ),
        )


@dataclass
class Subscript(Expr):
    value: Optional["Node[object]"] = None
    index: Optional["Node[object]"] = None
    ctx: Optional[str] = None

    @classmethod
    def from_dict(cls, d: dict) -> "Subscript":
        from ._base import Node

        return cls(
            value=Node.from_dict(d.get("value"), expr_from_dict),
            index=Node.from_dict(d.get("index"), expr_from_dict),
            ctx=d.get("ctx"),
        )


@dataclass
class Compare(Expr):
    left: Optional["Node[object]"] = None
    ops: Optional[List[str]] = None
    comparators: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "Compare":
        from ._base import Node

        return cls(
            left=Node.from_dict(d.get("left"), expr_from_dict),
            ops=d.get("ops") or [],
            comparators=[
                Node.from_dict(c, expr_from_dict) for c in d.get("comparators") or []
            ],
        )


@dataclass
class NumberLit(Expr):
    """Numeric literal — ``1``, ``2.0``, ``1m``, ``1K``, ``1Mi``..."""

    binary_suffix: Optional[str] = None
    value: Optional[dict] = None  # {"type":"Int","value":...} or {"type":"Float",...}

    @classmethod
    def from_dict(cls, d: dict) -> "NumberLit":
        return cls(
            binary_suffix=d.get("binary_suffix"),
            value=d.get("value"),
        )


@dataclass
class StringLit(Expr):
    is_long_string: bool = False
    raw_value: str = "\"\""
    value: str = ""

    @classmethod
    def from_dict(cls, d: dict) -> "StringLit":
        return cls(
            is_long_string=d.get("is_long_string", False),
            raw_value=d.get("raw_value", "\"\""),
            value=d.get("value", ""),
        )


@dataclass
class NameConstantLit(Expr):
    """``True`` / ``False`` / ``None`` / ``Undefined``."""

    value: Optional[str] = None  # NameConstant

    @classmethod
    def from_dict(cls, d: dict) -> "NameConstantLit":
        return cls(value=d.get("value"))


@dataclass
class JoinedString(Expr):
    """String interpolation — ``"${var1} abc ${var2}"``."""

    values: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "JoinedString":
        from ._base import Node

        return cls(
            values=[
                Node.from_dict(v, expr_from_dict) for v in d.get("values") or []
            ]
        )


@dataclass
class FormattedValue(Expr):
    """One interpolation slot inside a ``JoinedString``."""

    value: Optional["Node[object]"] = None
    conversion: Optional[str] = None
    format_spec: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "FormattedValue":
        from ._base import Node

        return cls(
            value=Node.from_dict(d.get("value"), expr_from_dict),
            conversion=d.get("conversion"),
            format_spec=Node.from_dict(d.get("format_spec"), expr_from_dict),
        )


@dataclass
class MissingExpr(Expr):
    """The ``Missing`` sentinel that completes partially-applied schemas."""

    @classmethod
    def from_dict(cls, d: dict) -> "MissingExpr":
        return cls()


@dataclass
class CheckExpr(Expr):
    """``check:`` expression used inside a schema attribute body."""

    test: Optional["Node[object]"] = None
    msg: Optional["Node[str]"] = None
    if_cond: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "CheckExpr":
        from ._base import Node

        return cls(
            test=Node.from_dict(d.get("test"), expr_from_dict),
            msg=Node.from_dict(d.get("msg"), lambda x: x),
            if_cond=Node.from_dict(d.get("if_cond"), expr_from_dict),
        )


# --- Polymorphic dispatch ----------------------------------------------


_EXPR_REGISTRY = {
    "Target": Target,
    "Identifier": Identifier,
    "Unary": UnaryExpr,
    "Binary": BinaryExpr,
    "If": IfExpr,
    "Selector": SelectorExpr,
    "Call": CallExpr,
    "Paren": ParenExpr,
    "Quant": QuantExpr,
    "List": ListExpr,
    "ListIfItem": ListIfItemExpr,
    "ListComp": ListComp,
    "Starred": StarredExpr,
    "DictComp": DictComp,
    "ConfigIfEntry": ConfigIfEntryExpr,
    "CompClause": CompClause,
    "Schema": SchemaExpr,
    "Config": ConfigExpr,
    "Lambda": LambdaExpr,
    "Subscript": Subscript,
    "Compare": Compare,
    "NumberLit": NumberLit,
    "StringLit": StringLit,
    "NameConstantLit": NameConstantLit,
    "JoinedString": JoinedString,
    "FormattedValue": FormattedValue,
    "Missing": MissingExpr,
    "CheckExpr": CheckExpr,
}


def expr_from_dict(d: Optional[dict]) -> Optional[Expr]:
    """Polymorphic Expr loader. Returns ``None`` for a ``None`` or empty
    payload (Rust uses ``null`` for absent fields)."""
    if d is None:
        return None
    if not isinstance(d, dict):
        return None
    variant = d.get("type")
    if variant is None:
        # Some payloads (e.g. Decorator.func) carry a Node-typed expr
        # without the "type" tag — that's wrong-shaped input. Return None
        # rather than crashing so the rest of the tree deserializes.
        return None
    cls = _EXPR_REGISTRY.get(variant)
    if cls is None:
        return Expr()
    return cls.from_dict(d)


# Local late-bound helpers to avoid an import cycle between ``_expr`` and
# ``_dto``. Each helper delegates to the actual class once both modules
# are fully loaded.


def _keyword_from_dict(d):
    from ._dto import Keyword

    return Keyword.from_dict(d)


def _arguments_from_dict(d):
    from ._dto import Arguments

    return Arguments.from_dict(d)


def _config_entry_from_dict(d):
    from ._dto import ConfigEntry

    return ConfigEntry.from_dict(d)


def type_from_dict(d):
    from ._types import type_from_dict

    return type_from_dict(d)


def expr_to_dict(expr: Expr) -> dict:
    """Polymorphic Expr serializer. Mirror of ``expr_from_dict`` for the
    round-trip property. Round-trips back through ``expr_from_dict`` via
    the same ``"type":"<Variant>"`` discriminator the wire shape uses."""
    if expr is None:
        return None  # type: ignore[return-value]
    tag = _EXPR_TAG_BY_CLASS.get(type(expr))
    if tag is None:
        return {"type": "Unknown"}
    inner = _expr_inner_to_dict(expr)
    inner["type"] = tag
    return inner


_EXPR_TAG_BY_CLASS = {cls: tag for tag, cls in _EXPR_REGISTRY.items()}


def _expr_inner_to_dict(expr: Expr) -> dict:
    from ._base import Node
    from ._dto import (
        Arguments,
        ConfigEntry,
        Decorator,
        Keyword,
        SchemaConfig,
        Target as TargetDTO,
    )

    if isinstance(expr, Target):
        return TargetDTO(
            name=expr.name,
            paths=expr.paths or [],
            pkgpath=expr.pkgpath,
        ).to_dict()
    if isinstance(expr, Identifier):
        return {
            "names": [Node.to_dict(n, lambda x: x) for n in (expr.names or [])] or None,
            "pkgpath": expr.pkgpath,
            "ctx": expr.ctx,
        }
    if isinstance(expr, UnaryExpr):
        return {
            "op": expr.op,
            "operand": Node.to_dict(expr.operand, expr_to_dict)
            if expr.operand
            else None,
        }
    if isinstance(expr, BinaryExpr):
        return {
            "left": Node.to_dict(expr.left, expr_to_dict) if expr.left else None,
            "op": expr.op,
            "right": Node.to_dict(expr.right, expr_to_dict) if expr.right else None,
        }
    if isinstance(expr, IfExpr):
        return {
            "body": Node.to_dict(expr.body, expr_to_dict) if expr.body else None,
            "cond": Node.to_dict(expr.cond, expr_to_dict) if expr.cond else None,
            "orelse": Node.to_dict(expr.orelse, expr_to_dict) if expr.orelse else None,
        }
    if isinstance(expr, SelectorExpr):
        return {
            "value": Node.to_dict(expr.value, expr_to_dict) if expr.value else None,
            "attr": Node.to_dict(expr.attr, expr_to_dict) if expr.attr else None,
            "ctx": expr.ctx,
            "has_question": expr.has_question,
        }
    if isinstance(expr, CallExpr):
        return {
            "func": Node.to_dict(expr.func, expr_to_dict) if expr.func else None,
            "args": [Node.to_dict(a, expr_to_dict) for a in (expr.args or [])],
            "keywords": [
                Node.to_dict(k, lambda x: Keyword.to_dict(x))
                for k in (expr.keywords or [])
            ],
        }
    if isinstance(expr, ParenExpr):
        return {
            "expr": Node.to_dict(expr.expr, expr_to_dict) if expr.expr else None,
        }
    if isinstance(expr, QuantExpr):
        return {
            "target": Node.to_dict(expr.target, expr_to_dict)
            if expr.target
            else None,
            "variables": [
                Node.to_dict(v, expr_to_dict) for v in (expr.variables or [])
            ],
            "op": expr.op,
            "test": Node.to_dict(expr.test, expr_to_dict) if expr.test else None,
            "if_cond": Node.to_dict(expr.if_cond, expr_to_dict)
            if expr.if_cond
            else None,
            "ctx": expr.ctx,
        }
    if isinstance(expr, ListExpr):
        return {
            "elts": [Node.to_dict(e, expr_to_dict) for e in (expr.elts or [])],
            "ctx": expr.ctx,
        }
    if isinstance(expr, ListIfItemExpr):
        return {
            "if_cond": Node.to_dict(expr.if_cond, expr_to_dict)
            if expr.if_cond
            else None,
            "exprs": [Node.to_dict(e, expr_to_dict) for e in (expr.exprs or [])],
            "orelse": Node.to_dict(expr.orelse, expr_to_dict)
            if expr.orelse
            else None,
        }
    if isinstance(expr, ListComp):
        return {
            "elt": Node.to_dict(expr.elt, expr_to_dict) if expr.elt else None,
            "generators": [
                Node.to_dict(g, expr_to_dict) for g in (expr.generators or [])
            ],
        }
    if isinstance(expr, StarredExpr):
        return {
            "value": Node.to_dict(expr.value, expr_to_dict) if expr.value else None,
            "ctx": expr.ctx,
        }
    if isinstance(expr, DictComp):
        return {
            "entry_key": Node.to_dict(expr.entry_key, expr_to_dict)
            if expr.entry_key
            else None,
            "key": Node.to_dict(expr.key, expr_to_dict) if expr.key else None,
            "value": Node.to_dict(expr.value, expr_to_dict) if expr.value else None,
            "generators": [
                Node.to_dict(g, expr_to_dict) for g in (expr.generators or [])
            ],
        }
    if isinstance(expr, ConfigIfEntryExpr):
        return {
            "if_cond": Node.to_dict(expr.if_cond, expr_to_dict)
            if expr.if_cond
            else None,
            "items": [
                Node.to_dict(i, lambda x: ConfigEntry.to_dict(x))
                for i in (expr.items or [])
            ],
            "orelse": Node.to_dict(expr.orelse, expr_to_dict)
            if expr.orelse
            else None,
        }
    if isinstance(expr, CompClause):
        return {
            "targets": [Node.to_dict(t, expr_to_dict) for t in (expr.targets or [])],
            "iter": Node.to_dict(expr.iter, expr_to_dict) if expr.iter else None,
            "ifs": [Node.to_dict(i, expr_to_dict) for i in (expr.ifs or [])],
        }
    if isinstance(expr, SchemaExpr):
        return {
            "name": Node.to_dict(expr.name, expr_to_dict) if expr.name else None,
            "args": [Node.to_dict(a, expr_to_dict) for a in (expr.args or [])],
            "kwargs": [
                Node.to_dict(k, lambda x: Keyword.to_dict(x))
                for k in (expr.kwargs or [])
            ],
            "config": Node.to_dict(expr.config, expr_to_dict)
            if expr.config
            else None,
        }
    if isinstance(expr, ConfigExpr):
        return {
            "items": [
                Node.to_dict(i, lambda x: ConfigEntry.to_dict(x))
                for i in (expr.items or [])
            ],
        }
    if isinstance(expr, LambdaExpr):
        return {
            "args": Node.to_dict(expr.args, lambda x: Arguments.to_dict(x))
            if expr.args
            else None,
            "body": [Node.to_dict(b, expr_to_dict) for b in (expr.body or [])],
            "return_ty": Node.to_dict(expr.return_ty, lambda x: _type_to_dict_stub(x))
            if expr.return_ty
            else None,
        }
    if isinstance(expr, Subscript):
        return {
            "value": Node.to_dict(expr.value, expr_to_dict) if expr.value else None,
            "index": Node.to_dict(expr.index, expr_to_dict) if expr.index else None,
            "ctx": expr.ctx,
        }
    if isinstance(expr, Compare):
        return {
            "left": Node.to_dict(expr.left, expr_to_dict) if expr.left else None,
            "ops": expr.ops or [],
            "comparators": [
                Node.to_dict(c, expr_to_dict) for c in (expr.comparators or [])
            ],
        }
    if isinstance(expr, NumberLit):
        return {"binary_suffix": expr.binary_suffix, "value": expr.value}
    if isinstance(expr, StringLit):
        return {
            "is_long_string": expr.is_long_string,
            "raw_value": expr.raw_value,
            "value": expr.value,
        }
    if isinstance(expr, NameConstantLit):
        return {"value": expr.value}
    if isinstance(expr, JoinedString):
        return {
            "values": [Node.to_dict(v, expr_to_dict) for v in (expr.values or [])],
        }
    if isinstance(expr, FormattedValue):
        return {
            "value": Node.to_dict(expr.value, expr_to_dict) if expr.value else None,
            "conversion": expr.conversion,
            "format_spec": Node.to_dict(expr.format_spec, expr_to_dict)
            if expr.format_spec
            else None,
        }
    if isinstance(expr, MissingExpr):
        return {}
    if isinstance(expr, CheckExpr):
        return {
            "test": Node.to_dict(expr.test, expr_to_dict) if expr.test else None,
            "msg": Node.to_dict(expr.msg, lambda x: x) if expr.msg else None,
            "if_cond": Node.to_dict(expr.if_cond, expr_to_dict)
            if expr.if_cond
            else None,
        }
    return {}


def _type_to_dict_stub(d):
    from ._types import type_to_dict

    return type_to_dict(d)
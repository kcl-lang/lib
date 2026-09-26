"""Type hierarchy — mirrors ``kcl-lang/kcl/crates/ast/src/ast.rs::Type``.

The Rust ``Type`` enum uses the same internally-tagged representation as
``Expr`` and ``Stmt`` (``#[serde(tag = "type")]``), so deserialization
dispatches on a ``"type"`` discriminator.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional


@dataclass
class Type:
    """Base class. Concrete variants subclass this and add their fields."""

    pass


@dataclass
class BasicType(Type):
    """A primitive type, e.g. ``int``, ``str``, ``bool``, ``float``."""

    value: str = ""

    @classmethod
    def from_dict(cls, d: dict) -> "BasicType":
        return cls(value=d.get("value", ""))


@dataclass
class ListType(Type):
    """``[T]`` — homogeneous list type."""

    elem_type: Optional["Type"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "ListType":
        inner = d.get("elem_type")
        return cls(elem_type=type_from_dict(inner) if inner else None)


@dataclass
class DictType(Type):
    """``{K: V}`` — dict type with explicit key/value types."""

    key_type: Optional["Type"] = None
    value_type: Optional["Type"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "DictType":
        return cls(
            key_type=type_from_dict(d.get("key_type")),
            value_type=type_from_dict(d.get("value_type")),
        )


@dataclass
class SchemaRefType(Type):
    """A named-schema reference (e.g. ``Person``)."""

    schema_name: str = ""
    pkgpath: str = ""

    @classmethod
    def from_dict(cls, d: dict) -> "SchemaRefType":
        return cls(
            schema_name=d.get("schema_name", ""),
            pkgpath=d.get("pkgpath", ""),
        )


@dataclass
class LiteralType(Type):
    """A literal value used as a type (rare; e.g. ``"Red" | "Blue"``)."""

    value: str = ""

    @classmethod
    def from_dict(cls, d: dict) -> "LiteralType":
        return cls(value=d.get("value", ""))


@dataclass
class FunctionType(Type):
    """``(T1, T2) -> R`` — function signature.

    The wire shape nests the params/return inside ``value``::

        {"type": "Function", "value": {"params_ty": [...], "ret_ty": ...}}

    Flat ``params`` / ``return_type`` accessors are exposed as properties.
    """

    params: Optional[List["Type"]] = None
    return_type: Optional["Type"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "FunctionType":
        # Wire shape: {"type": "Function", "value": {"params_ty": [...], "ret_ty": ...}}.
        inner = d.get("value") or {}
        params_ty = inner.get("params_ty") or d.get("params") or []
        ret_ty = inner.get("ret_ty") or d.get("return_type")
        return cls(
            params=[type_from_dict(p) for p in params_ty],
            return_type=type_from_dict(ret_ty),
        )


@dataclass
class UnionType(Type):
    """``T1 | T2 | ...`` — union of multiple types."""

    types: Optional[List["Type"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "UnionType":
        return cls(types=[type_from_dict(t) for t in d.get("types", []) or []])


@dataclass
class KeyValueType(Type):
    """``KeyValue`` — used in dict-entry key types when they are themselves
    typed expressions. Less common; included for completeness."""

    key: Optional["Type"] = None
    value: Optional["Type"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "KeyValueType":
        return cls(
            key=type_from_dict(d.get("key")),
            value=type_from_dict(d.get("value")),
        )


@dataclass
class AnyType(Type):
    """``any`` — the top type that all types are assignable to."""

    @classmethod
    def from_dict(cls, d: dict) -> "AnyType":
        return cls()


@dataclass
class NamedType(Type):
    """A named type reference that re-uses an ``Identifier``-shaped payload."""

    value: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: dict) -> "NamedType":
        from ._base import Node
        from ._expr import expr_from_dict

        return cls(value=Node.from_dict(d.get("value"), expr_from_dict))


@dataclass
class StrLiteralType(Type):
    """A string literal used as a type, e.g. ``"red"`` in a union."""

    value: str = ""

    @classmethod
    def from_dict(cls, d: dict) -> "StrLiteralType":
        return cls(value=d.get("value", ""))


@dataclass
class IntLiteralType(Type):
    """An integer literal used as a type."""

    value: int = 0

    @classmethod
    def from_dict(cls, d: dict) -> "IntLiteralType":
        return cls(value=d.get("value", 0))


@dataclass
class FloatLiteralType(Type):
    """A float literal used as a type."""

    value: float = 0.0

    @classmethod
    def from_dict(cls, d: dict) -> "FloatLiteralType":
        return cls(value=d.get("value", 0.0))


@dataclass
class BoolLiteralType(Type):
    """A boolean literal used as a type."""

    value: bool = False

    @classmethod
    def from_dict(cls, d: dict) -> "BoolLiteralType":
        return cls(value=d.get("value", False))


_TYPE_REGISTRY = {
    "Basic": BasicType,
    "List": ListType,
    "Dict": DictType,
    "SchemaRef": SchemaRefType,
    "Literal": LiteralType,
    "Function": FunctionType,
    "Union": UnionType,
    "KeyValue": KeyValueType,
    "Any": AnyType,
    "Named": NamedType,
    "StrLiteral": StrLiteralType,
    "IntLiteral": IntLiteralType,
    "FloatLiteral": FloatLiteralType,
    "BoolLiteral": BoolLiteralType,
}


def type_from_dict(d: Optional[dict]) -> Optional[Type]:
    """Polymorphic dispatch for the ``Type`` enum.

    Mirrors Rust's ``#[serde(tag = "type")]`` on ``ast::Type`` — the
    JSON carries a ``"type":"<Variant>"`` discriminator."""
    if d is None:
        return None
    if not isinstance(d, dict):
        return None
    variant = d.get("type")
    cls = _TYPE_REGISTRY.get(variant)
    if cls is None:
        # Unknown variant — fall back to a generic Type so the loader
        # doesn't blow up on forward-compat types.
        return Type()
    return cls.from_dict(d)


def type_to_dict(ty: "Type") -> dict:
    """Polymorphic Type serializer. Mirror of ``type_from_dict`` for the
    round-trip property."""
    if ty is None:
        return {}
    tag = _TYPE_TAG_BY_CLASS.get(type(ty)) or "Unknown"
    inner = _type_inner_to_dict(ty)
    inner["type"] = tag
    return inner


_TYPE_TAG_BY_CLASS = {cls: tag for tag, cls in _TYPE_REGISTRY.items()}


def _type_inner_to_dict(ty: "Type") -> dict:
    from ._base import Node
    from ._expr import expr_to_dict

    if isinstance(ty, BasicType):
        return {"value": ty.value}
    if isinstance(ty, ListType):
        return {"elem_type": type_to_dict(ty.elem_type) if ty.elem_type else None}
    if isinstance(ty, DictType):
        return {
            "key_type": type_to_dict(ty.key_type) if ty.key_type else None,
            "value_type": type_to_dict(ty.value_type) if ty.value_type else None,
        }
    if isinstance(ty, SchemaRefType):
        return {"schema_name": ty.schema_name, "pkgpath": ty.pkgpath}
    if isinstance(ty, LiteralType):
        return {"value": ty.value}
    if isinstance(ty, FunctionType):
        return {
            "value": {
                "params_ty": [type_to_dict(p) for p in (ty.params or [])],
                "ret_ty": type_to_dict(ty.return_type) if ty.return_type else None,
            }
        }
    if isinstance(ty, UnionType):
        return {"types": [type_to_dict(t) for t in (ty.types or [])]}
    if isinstance(ty, KeyValueType):
        return {
            "key": type_to_dict(ty.key) if ty.key else None,
            "value": type_to_dict(ty.value) if ty.value else None,
        }
    if isinstance(ty, AnyType):
        return {}
    if isinstance(ty, NamedType):
        return {
            "value": Node.to_dict(ty.value, expr_to_dict) if ty.value else None
        }
    if isinstance(ty, StrLiteralType):
        return {"value": ty.value}
    if isinstance(ty, IntLiteralType):
        return {"value": ty.value}
    if isinstance(ty, FloatLiteralType):
        return {"value": ty.value}
    if isinstance(ty, BoolLiteralType):
        return {"value": ty.value}
    return {}
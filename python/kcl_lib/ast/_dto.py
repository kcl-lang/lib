"""Flat DTOs and helper types.

These classes intentionally avoid the polymorphic ``Expr`` / ``Type`` /
``Stmt`` dispatch. They exist because several Rust AST fields nest a
type directly under ``NodeRef<T>`` (e.g. ``SchemaStmt.decorators``,
``UnificationStmt.value``) without the outer enum discriminator, so the
JSON shape is the *flat* payload — no ``"type"`` tag.

This matches the Java / Go bindings' existing design. See ``AST_DRIFT.md``
note A in the ``kcl-lang/lib`` repo.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional


# Forward imports to break circulars; resolved at runtime by ``from_dict``.
def _expr_from_dict(d):
    from ._expr import expr_from_dict

    return expr_from_dict(d)


def _keyword_from_dict(d):
    return Keyword.from_dict(d)


def _arguments_from_dict(d):
    return Arguments.from_dict(d)


@dataclass
class Decorator:
    """``@deprecated(strict=True)`` — the flat decorator payload.

    Mirrors Rust's ``NodeRef<CallExpr>`` *when nested inside* a parent
    field like ``SchemaStmt.decorators``. There is no ``"type":"Call"``
    tag on the wire in that context — the discriminator only appears
    when CallExpr is the outer ``Expr::Call`` variant.
    """

    func: Optional["Node[object]"] = None
    args: Optional[List["Node[object]"]] = None
    keywords: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["Decorator"]:
        if d is None:
            return None
        from ._base import Node

        func = Node.from_dict(d.get("func"), _expr_from_dict)
        args_raw = d.get("args") or []
        kw_raw = d.get("keywords") or []
        return cls(
            func=func,
            args=[Node.from_dict(a, _expr_from_dict) for a in args_raw],
            keywords=[Node.from_dict(k, _keyword_from_dict) for k in kw_raw],
        )

    def to_dict(self) -> dict:
        from ._base import Node
        from ._expr import expr_to_dict

        d: dict = {"func": Node.to_dict(self.func, expr_to_dict) if self.func else None}
        d["args"] = [Node.to_dict(a, expr_to_dict) for a in (self.args or [])]
        d["keywords"] = [
            Node.to_dict(k, lambda kw: kw.to_dict()) for k in (self.keywords or [])
        ]
        return d


@dataclass
class SchemaConfig:
    """``ASchema(args) { ... }`` — the inline schema instantiation payload.

    Mirrors Rust's ``NodeRef<SchemaExpr>`` *when nested inside*
    ``UnificationStmt.value``. No ``"type":"Schema"`` tag on the wire in
    that context.
    """

    name: Optional["Node[object]"] = None
    args: Optional[List["Node[object]"]] = None
    kwargs: Optional[List["Node[object]"]] = None
    config: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["SchemaConfig"]:
        if d is None:
            return None
        from ._base import Node

        return cls(
            name=Node.from_dict(d.get("name"), _expr_from_dict),
            args=[Node.from_dict(a, _expr_from_dict) for a in d.get("args") or []],
            kwargs=[
                Node.from_dict(k, _keyword_from_dict) for k in d.get("kwargs") or []
            ],
            config=Node.from_dict(d.get("config"), _expr_from_dict),
        )

    def to_dict(self) -> dict:
        from ._base import Node
        from ._expr import expr_to_dict

        d: dict = {
            "name": Node.to_dict(self.name, expr_to_dict) if self.name else None,
            "args": [Node.to_dict(a, expr_to_dict) for a in (self.args or [])],
            "kwargs": [
                Node.to_dict(k, lambda kw: kw.to_dict())
                for k in (self.kwargs or [])
            ],
            "config": Node.to_dict(self.config, expr_to_dict) if self.config else None,
        }
        return d


@dataclass
class ConfigEntry:
    """One entry in a config expression, e.g. ``key = value``."""

    key: Optional["Node[object]"] = None
    value: Optional["Node[object]"] = None
    operation: Optional[str] = None  # ConfigEntryOperation
    is_shorthand: bool = False

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["ConfigEntry"]:
        if d is None:
            return None
        from ._base import Node

        return cls(
            key=Node.from_dict(d.get("key"), _expr_from_dict),
            value=Node.from_dict(d.get("value"), _expr_from_dict),
            operation=d.get("operation"),
            is_shorthand=d.get("is_shorthand", False),
        )

    def to_dict(self) -> dict:
        from ._base import Node
        from ._expr import expr_to_dict

        d: dict = {
            "key": Node.to_dict(self.key, expr_to_dict) if self.key else None,
            "value": Node.to_dict(self.value, expr_to_dict) if self.value else None,
        }
        if self.operation is not None:
            d["operation"] = self.operation
        # Match Rust's `#[serde(skip_serializing_if = "is_false")]`.
        if self.is_shorthand:
            d["is_shorthand"] = True
        return d


@dataclass
class MemberOrIndex:
    """``a.b`` or ``a[0]`` — one segment in a target's ``paths``.

    Mirrors Rust's internally-tagged ``MemberOrIndex`` enum
    (``#[serde(tag = "type", content = "value")]``):

    - ``Member``: ``{"type":"Member", "value":<NodeRef<String>>}``
    - ``Index``: ``{"type":"Index", "value":<NodeRef<Expr>>}``
    """

    member: Optional["Node[str]"] = None
    index: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["MemberOrIndex"]:
        if d is None:
            return None
        from ._base import Node

        variant = d.get("type")
        if variant == "Member":
            return cls(member=Node.from_dict(d.get("value"), lambda x: x))
        if variant == "Index":
            return cls(index=Node.from_dict(d.get("value"), _expr_from_dict))
        return cls()

    def to_dict(self) -> dict:
        from ._base import Node
        from ._expr import expr_to_dict

        if self.member is not None:
            return {"type": "Member", "value": Node.to_dict(self.member, lambda x: x)}
        if self.index is not None:
            return {"type": "Index", "value": Node.to_dict(self.index, expr_to_dict)}
        return {}


@dataclass
class Target:
    """``a.b.c`` — the simple target struct used in ``AssignStmt.targets``.

    Mirrors Rust's ``ast::Target`` struct (``name``, ``paths``, ``pkgpath``).
    Note this is *not* the same as ``Expr::Target`` — the latter wraps this
    same payload with an outer ``"type":"Target"`` discriminator when it
    appears as an expression variant. ``AssignStmt.targets`` always uses
    this flat shape.
    """

    name: Optional["Node[str]"] = None
    paths: Optional[List["MemberOrIndex"]] = None
    pkgpath: str = ""

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["Target"]:
        if d is None:
            return None
        from ._base import Node

        return cls(
            name=Node.from_dict(d.get("name"), lambda x: x),
            paths=[MemberOrIndex.from_dict(p) for p in d.get("paths") or []],
            pkgpath=d.get("pkgpath", ""),
        )

    def to_dict(self) -> dict:
        from ._base import Node

        return {
            "name": Node.to_dict(self.name, lambda x: x) if self.name else None,
            "paths": [m.to_dict() for m in (self.paths or [])],
            "pkgpath": self.pkgpath,
        }


@dataclass
class Keyword:
    """A keyword argument, e.g. ``arg = value``.

    Used both as ``Expr::Keyword(Keyword)`` (with a ``"type":"Keyword"``
    discriminator) and as the flat payload inside ``CallExpr.keywords`` /
    ``SchemaConfig.kwargs`` (no discriminator).
    """

    arg: Optional["Node[object]"] = None
    value: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["Keyword"]:
        if d is None:
            return None
        from ._base import Node

        return cls(
            arg=Node.from_dict(d.get("arg"), _expr_from_dict),
            value=Node.from_dict(d.get("value"), _expr_from_dict),
        )

    def to_dict(self) -> dict:
        from ._base import Node
        from ._expr import expr_to_dict

        d: dict = {}
        if self.arg is not None:
            d["arg"] = Node.to_dict(self.arg, expr_to_dict)
        if self.value is not None:
            d["value"] = Node.to_dict(self.value, expr_to_dict)
        return d


@dataclass
class Arguments:
    """Lambda parameter list: ``x: int, y: int = 1``.

    Used both as ``Expr::Arguments(Arguments)`` (with a ``"type":"Arguments"``
    discriminator) and as the flat payload inside ``LambdaExpr.args``.
    """

    args: Optional[List["Node[object]"]] = None
    defaults: Optional[List["Node[object]"]] = None
    ty_list: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["Arguments"]:
        if d is None:
            return None
        from ._base import Node

        return cls(
            args=[Node.from_dict(a, _expr_from_dict) for a in d.get("args") or []],
            defaults=[
                Node.from_dict(v, _expr_from_dict) for v in d.get("defaults") or []
            ],
            ty_list=[
                # ty_list wraps Type, not Expr — use a Type loader.
                Node.from_dict(t, lambda x: type_from_dict(x))
                for t in d.get("ty_list") or []
            ],
        )

    def to_dict(self) -> dict:
        from ._base import Node
        from ._expr import expr_to_dict
        from ._types import type_to_dict

        return {
            "args": [Node.to_dict(a, expr_to_dict) for a in (self.args or [])],
            "defaults": [
                Node.to_dict(v, expr_to_dict) for v in (self.defaults or [])
            ],
            "ty_list": [
                Node.to_dict(t, lambda x: type_to_dict(x)) for t in (self.ty_list or [])
            ],
        }


# Late-bound to avoid circulars.
def type_from_dict(d):
    from ._types import type_from_dict

    return type_from_dict(d)


@dataclass
class SchemaIndexSignature:
    """``[name: str]: T`` — the schema index-signature payload.

    Mirrors Rust's ``ast::SchemaIndexSignature`` struct. Nested inside
    ``SchemaStmt.index_signature`` as a flat payload (no polymorphic
    discriminator). Wire shape::

        {"key_name": <NodeRef<String>>, "value": <NodeRef<Type>>}
    """

    key_name: Optional["Node[str]"] = None
    value: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["SchemaIndexSignature"]:
        if d is None:
            return None
        from ._base import Node
        from ._types import type_from_dict

        return cls(
            key_name=Node.from_dict(d.get("key_name"), lambda x: x),
            value=Node.from_dict(d.get("value"), lambda x: type_from_dict(x)),
        )

    def to_dict(self) -> dict:
        from ._base import Node
        from ._types import type_to_dict

        return {
            "key_name": Node.to_dict(self.key_name, lambda x: x)
            if self.key_name
            else None,
            "value": Node.to_dict(self.value, lambda x: type_to_dict(x))
            if self.value
            else None,
        }


@dataclass
class QuantOperation:
    """``all x in items if x > 0`` — the per-clause of a quantifier expression."""

    target: Optional["Node[object]"] = None  # Target DTO
    op: str = "filter"  # QuantOp

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["QuantOperation"]:
        if d is None:
            return None
        from ._base import Node
        from ._dto import Target as TargetDTO

        return cls(
            target=Node.from_dict(d.get("target"), lambda x: TargetDTO.from_dict(x)),
            op=d.get("op", "filter"),
        )

    def to_dict(self) -> dict:
        from ._base import Node

        return {
            "target": Node.to_dict(self.target, lambda x: x.to_dict())
            if self.target
            else None,
            "op": self.op,
        }


@dataclass
class NumberLitValue:
    """The typed numeric value nested inside ``NumberLit``.

    Mirrors Rust's ``NumberLitValue`` — the ``NumberLit`` expression carries
    one of ``Int`` / ``Float`` / ``Decimal`` depending on the literal's
    syntactic form.
    """

    type: str = "Int"  # "Int" | "Float" | "Decimal"
    value: object = 0

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["NumberLitValue"]:
        if d is None:
            return None
        return cls(type=d.get("type", "Int"), value=d.get("value", 0))

    def to_dict(self) -> dict:
        return {"type": self.type, "value": self.value}


@dataclass
class JoinedStringValue:
    """The value nested inside a ``JoinedString`` literal node.

    The wire shape splits literal / interpolation markers.
    """

    is_long_string: bool = False
    raw_value: str = '""'
    value: str = ""

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["JoinedStringValue"]:
        if d is None:
            return None
        return cls(
            is_long_string=d.get("is_long_string", False),
            raw_value=d.get("raw_value", '""'),
            value=d.get("value", ""),
        )

    def to_dict(self) -> dict:
        return {
            "is_long_string": self.is_long_string,
            "raw_value": self.raw_value,
            "value": self.value,
        }


@dataclass
class ConfigExprEntry:
    """Shorthand: a single key/value inside ``ConfigExpr.items``.

    This is a convenience alias for ``ConfigEntry`` — kept separate to
    document the position (inside ``ConfigExpr.items``).
    """

    key: Optional["Node[object]"] = None
    value: Optional["Node[object]"] = None
    operation: Optional[str] = None
    is_shorthand: bool = False

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["ConfigExprEntry"]:
        from ._dto import ConfigEntry

        return ConfigEntry.from_dict(d)

    def to_dict(self) -> dict:
        from ._dto import ConfigEntry

        return ConfigEntry.to_dict(self)


# `type_to_dict` is referenced above — provide it as a stub for round-trip
# completeness; the full implementation lives in ``_types.py``.
def type_to_dict(d):
    from ._types import type_to_dict

    return type_to_dict(d)


@dataclass
class DecoratorTarget:
    """``@deprecated`` — the inner target identifier of a decorator."""

    name: Optional["Node[str]"] = None
    pkgpath: str = ""

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["DecoratorTarget"]:
        if d is None:
            return None
        from ._base import Node

        return cls(
            name=Node.from_dict(d.get("name"), lambda x: x),
            pkgpath=d.get("pkgpath", ""),
        )

    def to_dict(self) -> dict:
        from ._base import Node

        return {
            "name": Node.to_dict(self.name, lambda x: x) if self.name else None,
            "pkgpath": self.pkgpath,
        }


@dataclass
class ConfigEntryValue:
    """Convenience alias for ``ConfigEntry.value`` field reference."""

    value: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["ConfigEntryValue"]:
        if d is None:
            return None
        from ._base import Node

        return cls(value=Node.from_dict(d, lambda x: x))

    def to_dict(self) -> dict:
        from ._base import Node

        return Node.to_dict(self.value, lambda x: x) if self.value else None


@dataclass
class NumberLitSuffix:
    """The optional ``binary_suffix`` (e.g. ``n``, ``m``, ``u``, ``K``) on
    a ``NumberLit`` expression.

    Mirrors Rust's ``NumberBinarySuffix`` enum (defined in ``_op.py`` as
    the ``NumberBinarySuffix`` enum). This dataclass is a value object for
    the wrapped form.
    """

    suffix: str = ""

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["NumberLitSuffix"]:
        if d is None:
            return None
        return cls(suffix=d.get("suffix", "") if isinstance(d, dict) else "")

    def to_dict(self) -> dict:
        return {"suffix": self.suffix}


@dataclass
class JoinedStringPart:
    """One segment of a ``JoinedString`` — either a literal string or an
    interpolated expression.

    Mirrors Rust's ``JoinedString::StringPart`` enum: either
    ``{"type":"Literal", "value":str}`` or ``{"type":"Expr", "expr":<Expr>}``.
    """

    literal: Optional[str] = None
    expr: Optional["Node[object]"] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["JoinedStringPart"]:
        if d is None:
            return None
        from ._base import Node

        return cls(
            literal=d.get("literal"),
            expr=Node.from_dict(d.get("expr"), lambda x: x),
        )

    def to_dict(self) -> dict:
        from ._base import Node

        d: dict = {}
        if self.literal is not None:
            d["literal"] = self.literal
        if self.expr is not None:
            d["expr"] = Node.to_dict(self.expr, lambda x: x)
        return d


@dataclass
class ModuleRef:
    """``pkg.module`` — a qualified module reference used by ``for_host_name``."""

    pkgpath: str = ""
    name: Optional[str] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["ModuleRef"]:
        if d is None:
            return None
        return cls(pkgpath=d.get("pkgpath", ""), name=d.get("name"))

    def to_dict(self) -> dict:
        return {"pkgpath": self.pkgpath, "name": self.name}


@dataclass
class SchemaIndexSignatureAttr:
    """The ``key_name`` field of ``SchemaIndexSignature``.

    Convenience alias — ``SchemaIndexSignature.key_name`` is itself a
    ``Node[str]`` but wrapping it in a dataclass makes documentation and
    type narrowing clearer.
    """

    key_name: Optional["Node[str]"] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["SchemaIndexSignatureAttr"]:
        if d is None:
            return None
        from ._base import Node

        return cls(key_name=Node.from_dict(d, lambda x: x))

    def to_dict(self) -> dict:
        from ._base import Node

        return Node.to_dict(self.key_name, lambda x: x) if self.key_name else None


@dataclass
class Program:
    """A program envelope containing one or more ``Module``s.

    Mirrors the ``{"root": str, "pkgs": {"__main__": [Module, ...]}}``
    envelope emitted by ``ParseProgramResult.ast_json``.
    """

    root: str = ""
    modules: Optional[List["Module"]] = None

    @classmethod
    def from_dict(cls, d: dict) -> "Program":
        from ._module import Module

        pkgs = d.get("pkgs") or {}
        main = pkgs.get("__main__") or []
        return cls(
            root=d.get("root", ""),
            modules=[Module.from_dict(item) for item in main],
        )

    def to_dict(self) -> dict:
        from ._module import Module

        return {
            "root": self.root,
            "pkgs": {
                "__main__": [Module.to_dict(m) if hasattr(m, "to_dict") else m
                             for m in (self.modules or [])],
            },
        }


@dataclass
class SchemaAttrDecorator:
    """Convenience alias for a decorator attached to a ``SchemaAttr``."""

    decorator: Optional["Decorator"] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["SchemaAttrDecorator"]:
        if d is None:
            return None
        return cls(decorator=Decorator.from_dict(d))

    def to_dict(self) -> dict:
        return Decorator.to_dict(self.decorator) if self.decorator else {}


@dataclass
class SchemaStmtBodyItem:
    """Convenience: a single body item of a ``SchemaStmt``.

    Schema body items can be either ``SchemaAttr`` or nested ``SchemaStmt``;
    this wrapper keeps the polymorphic dispatch hidden when callers
    only need to iterate the body.
    """

    item: Optional[object] = None  # SchemaAttr | SchemaStmt | Stmt

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["SchemaStmtBodyItem"]:
        if d is None:
            return None
        from ._stmt import stmt_from_dict

        return cls(item=stmt_from_dict(d))

    def to_dict(self) -> dict:
        from ._stmt import stmt_to_dict

        return stmt_to_dict(self.item) if self.item else {}


@dataclass
class IfStmtBranch:
    """Convenience: a single branch (body or orelse) of an ``IfStmt``."""

    body: Optional[List["Node[object]"]] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["IfStmtBranch"]:
        if d is None:
            return None
        from ._base import Node
        from ._stmt import stmt_from_dict

        return cls(
            body=[Node.from_dict(b, stmt_from_dict) for b in d.get("body") or []],
        )

    def to_dict(self) -> dict:
        from ._base import Node
        from ._stmt import stmt_to_dict

        return {"body": [Node.to_dict(b, stmt_to_dict) for b in (self.body or [])]}


@dataclass
class DecoratorList:
    """Convenience: a list of ``Decorator`` payloads (used in
    ``SchemaStmt.decorators`` and ``SchemaAttr.decorators``)."""

    decorators: Optional[List["Decorator"]] = None

    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["DecoratorList"]:
        if d is None:
            return None
        return cls(decorators=[Decorator.from_dict(item) for item in (d or [])])

    def to_dict(self) -> dict:
        return [Decorator.to_dict(d) for d in (self.decorators or [])]
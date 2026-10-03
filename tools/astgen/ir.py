"""The intermediate representation the Rust parser produces.

Deliberately dumb: every node here corresponds to something that literally
appears in ``crates/ast/src/ast.rs``. Nothing is inferred, renamed or
reordered at this stage -- deciding that a field is ``Option``-shaped, that an
enum is adjacently tagged, or which Python module a class belongs to happens
one layer up, in :mod:`astgen.model`, where the decision is visible in one
place.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional


@dataclass(frozen=True)
class RustTypeRef:
    """A parsed Rust type expression, e.g. ``Option<Vec<NodeRef<Type>>>``.

    ``name`` is the head of the type -- ``Option``, ``Vec``, ``NodeRef``,
    ``String`` -- and ``args`` its bracketed arguments. Anything the parser
    cannot decompose is kept as a single ``name`` with no args rather than
    dropped, so an unexpected shape shows up in the emitted code instead of
    silently becoming a plain value.
    """

    name: str
    args: tuple = ()

    def render(self) -> str:
        if not self.args:
            return self.name
        return f"{self.name}<{', '.join(a.render() for a in self.args)}>"

    def __str__(self) -> str:  # pragma: no cover - convenience only
        return self.render()


@dataclass
class RustField:
    """One ``pub name: Type,`` inside a struct body."""

    name: str
    type: RustTypeRef
    attrs: Dict[str, object] = field(default_factory=dict)
    doc: str = ""
    line: int = 0

    @property
    def skipped(self) -> bool:
        """True when serde never puts this field on the wire.

        ``Node.span`` is ``#[serde(skip)]``. ``Node.id`` is *not* skipped -- it
        is serialised, but only when a thread-local flag says so -- so it is
        read as an optional key rather than as a required one.
        """
        return bool(self.attrs.get("skip"))

    @property
    def optional(self) -> bool:
        """True when the key may be absent from the payload object."""
        if self.skipped:
            return True
        if "default" in self.attrs or "skip_serializing_if" in self.attrs:
            return True
        if "serialize_with" in self.attrs:
            # A hand-written serialiser decides presence at runtime; the
            # matching field is never deserialised either.
            return True
        return self.type.name == "Option"


@dataclass
class RustVariant:
    """One arm of a Rust ``enum``.

    ``kind`` is ``unit`` for ``Foo,``, ``tuple`` for ``Foo(T),`` / ``Foo(A, B),``
    and ``struct`` for ``Foo { .. }``. ``types`` holds the payload type names
    in declaration order.
    """

    name: str
    kind: str = "unit"
    types: List[RustTypeRef] = field(default_factory=list)
    attrs: Dict[str, object] = field(default_factory=dict)
    doc: str = ""
    line: int = 0

    @property
    def is_other(self) -> bool:
        """``#[serde(other)]`` -- the catch-all arm, never serialised itself."""
        return bool(self.attrs.get("other"))


@dataclass
class RustItem:
    """A ``pub struct``, ``pub enum`` or ``pub type`` in the source."""

    name: str
    kind: str  # "struct" | "enum" | "alias"
    generics: List[str] = field(default_factory=list)
    serde: Dict[str, object] = field(default_factory=dict)
    attrs: List[str] = field(default_factory=list)
    fields: List[RustField] = field(default_factory=list)
    variants: List[RustVariant] = field(default_factory=list)
    alias_target: Optional[RustTypeRef] = None
    doc: str = ""
    line: int = 0
    manual_serialize: bool = False
    """True when the item carries a hand-written ``Serialize`` impl.

    Such a type's wire shape is not described by its ``#[serde(...)]``
    attributes, because it does not have any -- it is the ``serialize_with``
    attribute and the impl that do it. ``Node<T>`` is the only one today.
    """

    @property
    def tag(self) -> Optional[str]:
        value = self.serde.get("tag")
        return str(value) if value is not None else None

    @property
    def content(self) -> Optional[str]:
        value = self.serde.get("content")
        return str(value) if value is not None else None

    @property
    def wire_tagging(self) -> str:
        """``internal`` | ``adjacent`` | ``plain`` | ``bare``.

        ``bare`` is the third kind and the easiest to miss: a Rust enum with no
        ``#[serde(...)]`` at all is externally tagged, every one of its variants
        is a unit variant, and so on the wire it is a bare JSON string --
        ``"Add"``, not ``{"Add": null}``. Eight of the AST's enums are like this
        (``BinOp``, ``AugOp``, ``ExprContext``, ...).
        """
        if self.kind != "enum":
            return "plain"
        if self.tag is not None and self.content is not None:
            return "adjacent"
        if self.tag is not None:
            return "internal"
        return "bare"


@dataclass
class RustCrate:
    """Everything the parser found, keyed by name, with the raw source kept."""

    items: Dict[str, RustItem]
    source_path: str
    source_sha: str
    item_count: int

"""Turn the parsed Rust into a language-neutral model of the AST wire format.

Everything a decoder can get wrong is decided here, once, from the ``#[serde]``
attributes on the type rather than from a list of names:

===========================  =========================================  ==========
Rust                         wire shape                                how it is known
===========================  =========================================  ==========
``struct`` with no tag       ``{field: …}``                            no ``#[serde]``
``enum tag="type"``          ``{"type": "Variant", field: …}``        tag, no content
``enum tag=… content=…``     ``{"type": "Variant", "value": …}``       both
``enum``, no ``#[serde]``    ``"Variant"``                             nothing at all
===========================  =========================================  ==========

The fourth row is the one that reads as an oversight. Eight of the AST's enums
have no ``#[serde]`` attribute whatsoever, so serde tags them externally, every
variant is a unit variant, and the value on the wire is a bare JSON string.
``BinOp::Add`` is ``"Add"``, not ``{"Add": null}``.

Three things are *not* derivable and are therefore written down, each with the
reason next to it: which module a hierarchy's root lives in
(:data:`ENUM_ROOT_MODULE`), the aliases the public API already exposes
(:mod:`astgen.naming`), and the prose in :mod:`astgen.narrative`. Everything
else -- every class, every field, every wire tag, every operator variant -- is
read out of ``ast.rs``.
"""

from __future__ import annotations

from dataclasses import dataclass, field as dc_field
from typing import Dict, List, Optional, Set, Tuple

from . import naming
from .ir import RustCrate, RustField, RustItem, RustTypeRef, RustVariant

#: Which module each tagged hierarchy's root and its own variant classes live
#: in. `Expr` and `Stmt` own `_expr` and `_stmt`; `Type` owns `_types` because
#: every one of its payloads is a type and nothing else in the tree competes
#: for the name. This is a three-entry placement policy, not a list of AST
#: types -- the classes inside those modules are all placed by the rules below.
ENUM_ROOT_MODULE: Dict[str, str] = {
    "Stmt": "_stmt",
    "Expr": "_expr",
    "Type": "_types",
}

#: Types that hold `NodeRef<Self>` and therefore *are* the node hierarchy their
#: variants belong to. Derived, not listed: a tagged enum is a root if some
#: other struct's field is `NodeRef<It>`.
#:
#: `Type` qualifies (`AssignStmt.ty: Option<NodeRef<Type>>`,
#: `UnionType.type_elements`, ...). `NumberLitValue` does not -- `NumberLit.value`
#: holds it bare, which is exactly the difference between a node hierarchy and a
#: value that happens to be tagged.
NODE_ROOTS = ("Node", "NodeRef")

#: The field a *standalone* compact adjacently-tagged enum exposes its tag
#: under. Three such enums exist and all three use `kind`: `NumberLitValue`
#: and `MemberOrIndex` carry their own tag because nothing above them does.
TAG_FIELD_NAME = "kind"

#: The three inline payloads of an adjacently-tagged root whose class is not
#: simply the payload struct's own field list. This is the one table in the
#: model that cannot be derived, and it is here rather than guessed:
#:
#: ``Basic``
#:     ``BasicType`` is a *fieldless* enum, so ``Type::Basic``'s payload is the
#:     bare JSON string ``"Int"`` and there are no struct fields to inherit.
#:     ``name`` is what Java's ``BasicType`` calls the same thing and what both
#:     existing bindings call it.
#: ``Named``
#:     ``Type::Named(Identifier)`` inlines the ``Identifier`` *struct* under
#:     ``value``, with no ``NodeRef`` around it, so the class holds one value
#:     rather than a position. ``identifier`` is the name in Java's
#:     ``NamedType`` and in the existing Python and TypeScript.
#: ``Literal``
#:     ``LiteralType`` is *itself* ``tag/content``, so ``Type::Literal``'s
#:     payload is a second tagged document with no fixed field set (``Int``
#:     carries ``{value, suffix}``; ``Str`` carries a bare string). It is kept
#:     verbatim under ``value`` -- which is also the serde content key, so the
#:     field and the wire key coincide -- and the *inner* tag is exposed
#:     separately as a derived property (see :data:`DERIVED_TAGS`).
ADJACENT_INLINE_FIELDS: Dict[str, str] = {
    "Basic": "name",
    "Named": "identifier",
    "Literal": "value",
}

#: Compact adjacently-tagged enums whose tag is nested inside the payload
#: rather than beside it, and so is exposed as a read-only property computed
#: from the verbatim document rather than as a stored field. `LiteralType` is
#: the only one: it is the payload of `Type::Literal`, so the outer `"Literal"`
#: tag is already read by the dispatcher, and what is left inside is a *second*
#: tag (`"Int"`, `"Str"`, ...). The name is not derivable -- it is the name the
#: existing public API exposes and `python/tests/ast_contract_test.py` asserts.
DERIVED_TAGS: Dict[str, str] = {
    "LiteralType": "inner_tag",
}


class ModelError(RuntimeError):
    """Raised when the source is shaped in a way the model does not cover."""


# --- field shapes ---------------------------------------------------------

#: Every distinct field shape in the AST, and the loader each one needs. A new
#: Rust type in a field position lands here or raises, which is the point: the
#: four shapes below are the ones a decoder can get wrong, and the whole set is
#: small enough to hold in one place.
SHAPE_NODE_STR = "node_str"
SHAPE_NODE = "node"
SHAPE_NODE_LIST = "node_list"
SHAPE_OPT_NODE_LIST = "opt_node_list"
SHAPE_VALUE_LIST = "value_list"
SHAPE_OPT_VEC = "opt_vec"
SHAPE_CLASS_REF = "class_ref"
SHAPE_STR = "str"
SHAPE_OPT_STR = "opt_str"
SHAPE_NUM = "num"
SHAPE_OPT_NUM = "opt_num"
SHAPE_BOOL = "bool"
SHAPE_OP = "op"
SHAPE_RAW_LIST = "raw_list"
SHAPE_OP_LIST = "op_list"
SHAPE_VERBATIM = "verbatim"
#: Verbatim, but the thing kept is a *nested document* rather than any JSON
#: value, so the field defaults to an empty dict instead of ``None`` and the
#: derived tag beside it can always be read. `Type::Literal`'s payload is the
#: one: a second `tag/content` document with no fixed field set.
SHAPE_DOC = "doc"
SHAPE_IGNORED = "ignored"
SHAPE_GENERIC = "generic"
#: A field whose wire form is decided by a hand-written ``serialize_with``
#: function rather than by its Rust type. ``Node.id`` is the only one: it is
#: an ``AstIndex`` (a newtype over a ``uuid::Uuid``) written by ``serialize_id``
#: and marked ``skip_deserializing``, and the impl omits the key entirely unless
#: a thread-local flag says otherwise. The decoder therefore cannot say what the
#: value is, so it passes it through unchanged rather than guessing.
SHAPE_OPAQUE = "opaque"
#: The payload of a compact adjacently-tagged enum whose variants carry a
#: `NodeRef` (`MemberOrIndex`). The loader differs per variant, so the decoder
#: dispatches on the tag before reading the payload.
SHAPE_COMPACT_NODE = "compact_node"

#: Types whose decoder is a *function*, not a per-class `from_dict`, because
#: every other decoder calls it: `Node<T>` is the wrapper, and `node_from_dict`
#: is what unwraps it. Its field list is still read out of the struct -- if
#: `ast.rs` adds a field to `Node`, the generated `Node` and `Pos` gain it too
#: -- but the shape of the read is not "one field per class" and saying so is
#: better than pretending it is.
HAND_WRITTEN_SHAPES = {"Node": "node_wrapper"}


@dataclass
class FieldModel:
    wire: str
    name: str
    shape: str
    payload: Optional[str]
    rust_type: str
    doc: str = ""
    optional: bool = False
    #: True when this field *is* the whole content document rather than a key
    #: inside it. `Type::Basic`'s payload is a bare string, so the class
    #: serialises to that string and `type_to_dict` writes it straight under
    #: `"value"` -- wrapping it again would give `{"value": "Int"}` under a
    #: `"value"` key, which is one level of nesting too many.
    inline: bool = False
    #: `#[serde(skip_serializing_if = "is_false")]`: the key is *absent* from
    #: the wire when the answer is no, rather than present and `false`. Reading
    #: it as absent and writing it back as `false` adds a key the parser never
    #: emitted, which is why `ConfigEntry.to_dict()["is_shorthand"]` has to be
    #: absent for an explicitly-written entry.
    skip_false: bool = False

    @property
    def loader_key(self) -> Optional[str]:
        """The payload word ``hack/check_ast_field_types.rb`` knows, or None."""
        if self.payload is None:
            return None
        return naming.payload_word(self.payload)


@dataclass
class ClassModel:
    rust_name: str
    name: str
    module: str
    kind: str
    fields: List[FieldModel] = dc_field(default_factory=list)
    tag: Optional[str] = None
    content: Optional[str] = None
    base: Optional[str] = None
    owner: Optional[str] = None
    doc: str = ""
    aliases: List[str] = dc_field(default_factory=list)
    variants: List[str] = dc_field(default_factory=list)
    #: True when this class is a root variant *and* is also reachable untagged
    #: through a field declared with the struct (``Expr::Identifier`` is both
    #: ``Expr`` and ``Keyword.arg``). Such a class is emitted once, with the
    #: payload struct's own field list, and the tag is written by the
    #: hierarchy's dispatcher rather than by the class.
    shared: bool = False
    #: For a compact adjacently-tagged enum: the loader per tag, for the one
    #: kind whose payload is a `NodeRef` and therefore differs per variant.
    payload_loaders: Dict[str, str] = dc_field(default_factory=dict)
    #: A read-only accessor computed from another field rather than read off
    #: the wire: ``LiteralType.inner_tag`` is the tag *inside* its verbatim
    #: payload document.
    derived: Optional[Tuple[str, str]] = None
    """``(attribute name, source field)``."""
    #: Raw Rust doc comment lines, for the emitter to fall back on.
    rust_doc: str = ""


@dataclass
class AstModel:
    classes: Dict[str, ClassModel]
    """Every emitted class, keyed by its Rust name (or ``Root::Variant`` for a
    variant that has no struct of its own). Each class appears exactly once, so
    an emitter can iterate this without deduplicating."""

    module_order: List[str]
    enums: Dict[str, ClassModel]
    roots: List[str]
    variants: Dict[str, ClassModel]
    """Wire tag path -> class: ``{"Expr::Call": <CallExpr class>}``. Separate
    from :attr:`classes` because ``Expr::Call`` *is* ``CallExpr``; pointing at
    the one object is what stops the two from drifting."""

    source_sha: str
    source_path: str
    skipped: Dict[str, str]


# --- type classification --------------------------------------------------


def _unwrap_optional(ref: RustTypeRef) -> Tuple[RustTypeRef, bool]:
    if ref.name == "Option":
        if len(ref.args) != 1:
            raise ModelError(f"Option with {len(ref.args)} arguments in {ref.render()}")
        return ref.args[0], True
    return ref, False


def classify_field(
    f: RustField, crate: RustCrate, owner: Optional[RustItem] = None
) -> FieldModel:
    """Decide how one Rust field is read, from its type and its serde attrs."""
    if f.skipped:
        return FieldModel(f.name, f.name, SHAPE_IGNORED, None, f.type.render(), f.doc, True)

    if "serialize_with" in f.attrs and f.attrs.get("skip_deserializing"):
        # `Node.id`: written by a hand-written serialiser, never read back, and
        # the key is absent unless a runtime flag says otherwise. There is no
        # honest type to decode it as, so it is passed through.
        return FieldModel(
            f.name, f.name, SHAPE_OPAQUE, None, f.type.render(), f.doc, True
        )

    ref, was_optional = _unwrap_optional(f.type)
    if owner is not None and ref.name in owner.generics:
        # A generic parameter, i.e. `Node<T>::node`. What it holds depends on
        # the holder, which is exactly why the wrapper is decoded by a function
        # and not by a class.
        return FieldModel(
            f.name, f.name, SHAPE_GENERIC, None, f.type.render(), f.doc, was_optional
        )
    payload: Optional[str] = None
    shape = ""

    if was_optional and ref.name == "Vec":
        # The three-state `Option<Vec<T>>`. This test has to come *before* the
        # plain `Vec` branch below: `_unwrap_optional` above has already turned
        # the `Option` into a bare `Vec`, so by the time the `Vec` branch is
        # reached the optionality is only visible as `was_optional`. Without
        # this test an `Option<Vec<NodeRef<Type>>>` decodes as a `Vec`, and
        # `None` -- a genuinely three-state field -- silently becomes `[]`.
        #
        # The parser never produces `Some(vec![])` --
        # `crates/parser/src/parser/ty.rs` turns an empty `params_type` into
        # `None` -- so an empty list here would be a decoder invention, and the
        # generated reader treats a missing and an empty list the same way and
        # says so in a comment.
        if len(ref.args) != 1:
            raise ModelError(f"{f.name}: {f.type.render()} has no element type")
        shape = SHAPE_OPT_VEC
        payload = _node_payload_of(ref, f.name)
    elif ref.name in ("Node", "NodeRef"):
        if len(ref.args) != 1:
            raise ModelError(f"{f.name}: {f.type.render()} has no payload type")
        inner = ref.args[0].name
        if inner in naming.PRIMITIVE_PAYLOADS:
            shape, payload = SHAPE_NODE_STR, inner
        else:
            shape, payload = SHAPE_NODE, inner
    elif ref.name == "Vec":
        if len(ref.args) != 1:
            raise ModelError(f"{f.name}: {f.type.render()} has no element type")
        elem, elem_optional = _unwrap_optional(ref.args[0])
        if elem.name in ("Node", "NodeRef"):
            inner = elem.args[0].name if elem.args else None
            # `elem_optional` is tested *first*, and the reason is a bug this
            # ordering exists to prevent: `Vec<Node<String>>` -- an ordinary
            # list of name parts, as in `Identifier.names` -- also matches
            # `inner in PRIMITIVE_PAYLOADS`, and testing the payload first
            # types it as a list of *nullable* nodes. `optional_node_list_from_dict`
            # then invents a `None` slot for a `Node<String>` that can never be
            # null, so `Identifier.names` round-trips as `[None, ...]`.
            if elem_optional:
                # `Vec<Option<NodeRef<Expr>>>`: the null occupies a slot and the
                # slot is meaningful. `Arguments.defaults` and
                # `Arguments.ty_list` are both index-aligned with `args`, so a
                # missing default cannot be a shorter list.
                shape, payload = SHAPE_OPT_NODE_LIST, inner
            else:
                shape, payload = SHAPE_NODE_LIST, inner
        elif elem.name in naming.PRIMITIVE_PAYLOADS:
            shape, payload = SHAPE_RAW_LIST, elem.name
        elif crate.items.get(elem.name) is not None and crate.items[elem.name].wire_tagging == "bare":
            # `Vec<CmpOp>`: a list of bare JSON strings. `Compare.ops` is the
            # one, and its elements are index-aligned with `comparators`.
            shape, payload = SHAPE_OP_LIST, elem.name
        elif crate.items.get(elem.name) is not None:
            # `Vec<MemberOrIndex>`: a bare list of values that each carry their
            # own document, with no NodeRef around them, so there is no position
            # on each element and the element decoder is the type's own.
            shape, payload = SHAPE_VALUE_LIST, elem.name
        else:
            raise ModelError(
                f"{f.name}: {f.type.render()} is a Vec of something this generator "
                "does not know how to decode"
            )
    elif ref.name in naming.PRIMITIVE_PAYLOADS:
        shape = {
            "String": SHAPE_STR,
            "bool": SHAPE_BOOL,
            "u64": SHAPE_NUM,
            "i64": SHAPE_NUM,
            "f64": SHAPE_NUM,
        }[ref.name]
        if shape == SHAPE_STR and was_optional:
            shape = SHAPE_OPT_STR
        elif shape == SHAPE_NUM and was_optional:
            shape = SHAPE_OPT_NUM
    elif ref.name in crate.items and crate.items[ref.name].wire_tagging == "bare":
        # A fieldless enum: a bare JSON string on the wire.
        shape, payload = SHAPE_OP, ref.name
        if was_optional:
            shape = SHAPE_OPT_STR
    elif ref.name in crate.items and crate.items[ref.name].kind == "struct":
        # A bare struct reference with no `NodeRef` around it:
        # `DictComp.entry: ConfigEntry` is `{key, value, operation,
        # is_shorthand}` on the wire, not `{"node": {...}}`.
        shape, payload = SHAPE_CLASS_REF, ref.name
    elif ref.name in crate.items and crate.items[ref.name].kind == "enum":
        # A tagged enum held bare, with no `NodeRef` around it.
        # `NumberLit.value: NumberLitValue` is such a field, and the model emits
        # a class for `NumberLitValue` (`kind` plus its payload), so the field
        # reads that class. Only an enum the model does *not* give a class
        # falls back to keeping its document whole -- `LiteralType` has no single
        # field set across its four variants, so splitting it per kind would
        # invent structure the wire does not have.
        if compact_mode(crate.items[ref.name], crate) is not None:
            shape, payload = SHAPE_CLASS_REF, ref.name
        else:
            shape, payload = SHAPE_VERBATIM, ref.name
    else:
        raise ModelError(
            f"{f.name}: {f.type.render()} is not a field shape this generator covers"
        )


    return FieldModel(
        wire=f.name,
        name=f.name,
        shape=shape,
        payload=payload,
        rust_type=f.type.render(),
        doc=f.doc,
        optional=was_optional or f.optional,
        skip_false=f.attrs.get("skip_serializing_if") == "is_false",
    )


def _node_payload_of(vec_ref: RustTypeRef, where: str) -> str:
    if len(vec_ref.args) != 1:
        raise ModelError(f"{where}: {vec_ref.render()} has no element type")
    elem = vec_ref.args[0]
    if elem.name in ("Node", "NodeRef") and elem.args:
        return elem.args[0].name
    raise ModelError(f"{where}: {vec_ref.render()} is not a list of nodes")


# --- compact adjacently-tagged enums --------------------------------------

KIND_COMPACT_NODE = "compact_node"
KIND_COMPACT_VALUE = "compact_value"


def compact_mode(item: RustItem, crate: RustCrate) -> Optional[str]:
    """How an adjacently-tagged enum that is *not* a node hierarchy is emitted.

    A node hierarchy (``Stmt``, ``Expr``, ``Type``) gets one class per variant,
    because each variant names a struct whose fields callers use. The other
    adjacently-tagged enums are values that happen to carry a tag, and the
    natural shape for those is a ``kind`` plus a payload. Which of the two
    payload shapes is derived from the variants themselves:

    * every payload is a ``NodeRef``  -> ``kind`` + ``node``  (``MemberOrIndex``)
    * every payload is a scalar       -> ``kind`` + ``value``  (``NumberLitValue``)
    * the payloads disagree           -> ``kind`` + ``value``, kept verbatim
      (``LiteralType``: ``Int`` inlines a struct, the rest are bare scalars,
      so there is no single set of fields to expose)

    The "is a node hierarchy" half is derived rather than listed: an enum is one
    if some other struct's field is ``NodeRef<It>``. ``Type`` is (eleven fields
    say so); ``LiteralType`` is not (``Type::Literal`` holds it as a variant
    payload, which is a different thing entirely).
    """
    if item.wire_tagging != "adjacent":
        return None
    if item.name in ENUM_ROOT_MODULE:
        return None
    if _is_node_root(item.name, crate):
        return None
    payloads = [v.types[0] for v in item.variants if v.types]
    if payloads and all(p.name in ("Node", "NodeRef") for p in payloads):
        return KIND_COMPACT_NODE
    return KIND_COMPACT_VALUE


def _is_node_root(name: str, crate: RustCrate) -> bool:
    for item in crate.items.values():
        if item.kind != "struct":
            continue
        for f in item.fields:
            ref = f.type
            if ref.name == "Option" and ref.args:
                ref = ref.args[0]
            if ref.name in ("Node", "NodeRef") and ref.args and ref.args[0].name == name:
                return True
    return False


# --- the model ------------------------------------------------------------


def build(crate: RustCrate) -> AstModel:
    """Assemble the whole model, in the order the pieces depend on each other.

    The order is not cosmetic. The holder map has to be built first, because it
    is what says which structs are reachable untagged and therefore which module
    each one belongs in. The struct classes have to exist before the variant
    classes, because ``Expr::Call(CallExpr)`` *is* the ``CallExpr`` class with a
    tag attached rather than a second class with a copied field list.
    """
    items = crate.items
    skipped = dict(naming.NOT_AST_NODES)
    classes: Dict[str, ClassModel] = {}
    enums: Dict[str, ClassModel] = {}
    variants: Dict[str, ClassModel] = {}

    # 1. Which emitted types are held bare -- that is, through a field declared
    #    with the type rather than with an enum variant?  Those are the ones
    #    that arrive on the wire with no tag, and the only thing that tells
    #    `Target` (an `Expr` variant *and* an `AssignStmt.targets` element)
    #    from `MissingExpr` (a variant and nothing else).
    bare_field_types: Dict[str, List[str]] = {}
    for item in sorted(items.values(), key=lambda i: i.name):
        if item.kind != "struct" or item.name in skipped:
            # A type the model deliberately does not emit must not be able to
            # fail the build on a field shape it needs: `Program.pkgs` is a
            # `HashMap` because `Program` is a lock-holding in-memory structure,
            # not because the generator cannot read a map.
            continue
        for f in item.fields:
            m = classify_field(f, crate, item)
            if m.shape in (
                SHAPE_NODE,
                SHAPE_NODE_LIST,
                SHAPE_OPT_NODE_LIST,
                SHAPE_OPT_VEC,
                SHAPE_CLASS_REF,
                SHAPE_VALUE_LIST,
                SHAPE_OP,
                SHAPE_OP_LIST,
                SHAPE_VERBATIM,
            ):
                bare_field_types.setdefault(m.payload, []).append(item.name)

    # 2. One class per struct.
    for name in sorted(items):
        item = items[name]
        if name in skipped or item.kind != "struct":
            continue
        module = _struct_module(name, item, crate, bare_field_types)
        cm = ClassModel(
            rust_name=name,
            name=naming.class_name(name),
            module=module,
            kind=HAND_WRITTEN_SHAPES.get(name, "struct"),
            doc="",
            aliases=naming.variant_aliases(name),
            rust_doc=item.doc,
        )
        cm.fields = [classify_field(f, crate, item) for f in item.fields if not f.skipped]
        _drop_ignored(cm)
        classes[name] = cm

    # 3. The adjacently-tagged enums that are values in their own right: a
    #    `kind` beside a payload, because nothing above them dispatches on it.
    #    An enum that is a *root variant's* payload is deliberately excluded --
    #    `Type::Literal(LiteralType)` is a hierarchy variant, and pass 4 builds
    #    its one class in the hierarchy's own module rather than emitting a
    #    second, colliding `LiteralType` next to it.
    root_payloads = _root_variant_payloads(crate)
    for name in sorted(items):
        item = items[name]
        if item.kind != "enum" or name in skipped or name in ENUM_ROOT_MODULE:
            continue
        mode = compact_mode(item, crate)
        if mode is None or name in root_payloads:
            continue
        cm = _compact_class(name, item, mode, classes, bare_field_types, crate)
        enums[name] = cm
        classes[name] = cm

    # 4. The three node hierarchies, their variant classes and their registries.
    for enum_name in ("Expr", "Stmt", "Type"):
        if enum_name not in items:
            raise ModelError(f"ast.rs no longer declares `enum {enum_name}`")
        item = items[enum_name]
        if item.wire_tagging not in ("internal", "adjacent"):
            raise ModelError(
                f"{enum_name} is {item.wire_tagging}-tagged; the generator models "
                "internal and adjacent tagging only"
            )
        module = ENUM_ROOT_MODULE[enum_name]
        root = ClassModel(
            rust_name=enum_name,
            name=enum_name,
            module=module,
            kind="root",
            tag=item.tag,
            content=item.content,
            doc="",
        )
        enums[enum_name] = root
        for v in item.variants:
            cm, own_class = _variant_class(
                enum_name, item, v, module, classes, bare_field_types, crate
            )
            variants[_variant_key(enum_name, v)] = cm
            if own_class:
                classes[_variant_key(enum_name, v)] = cm
            root.variants.append(v.name)

    # 5. The bare enums: the operator vocabularies. A root variant's payload
    #    is exempt -- `BasicType` is the payload of `Type::Basic` and pass 4
    #    already folded its four strings into that variant's `name` field.
    for name in sorted(items):
        item = items[name]
        if item.kind != "enum" or name in skipped or name in enums:
            continue
        if item.wire_tagging != "bare":
            if name in root_payloads:
                continue
            raise ModelError(
                f"{name} is {item.wire_tagging}-tagged but the model gave it no class"
            )
        if not naming.is_op_enum(item.variants):
            raise ModelError(
                f"{name} is externally tagged but has a non-unit variant, so it is "
                "neither a bare string nor a model this generator understands"
            )
        enums[name] = ClassModel(
            rust_name=name,
            name=name,
            module="_op",
            kind="op_enum",
            doc="",
            variants=[v.name for v in item.variants],
            rust_doc=item.doc,
        )

    model = AstModel(
        classes=classes,
        module_order=["_base", "_op", "_dto", "_expr", "_stmt", "_types", "_module"],
        enums=enums,
        roots=["Expr", "Stmt", "Type"],
        variants=variants,
        source_sha=crate.source_sha,
        source_path=crate.source_path,
        skipped=skipped,
    )
    _validate(model, crate, root_payloads)
    return model


def _root_variant_payloads(crate: RustCrate) -> Set[str]:
    """Every enum name that some root variant carries as its payload."""
    out: Set[str] = set()
    for root in ENUM_ROOT_MODULE:
        item = crate.items.get(root)
        if item is None:
            continue
        for v in item.variants:
            if v.types and len(v.types) == 1:
                out.add(v.types[0].name)
    return out


def _compact_class(
    name: str,
    item: RustItem,
    mode: str,
    classes: Dict[str, ClassModel],
    bare_field_types: Dict[str, List[str]],
    crate: RustCrate,
) -> ClassModel:
    """A tagged value that is not a hierarchy: a ``kind`` plus a payload.

    It is placed next to whichever class holds it, which is the module that
    already imports the thing it decodes -- ``NumberLitValue`` beside
    ``NumberLit`` in ``_expr``, ``MemberOrIndex`` beside ``Target`` in
    ``_dto``. Two holders in different modules would have no right answer, so
    that is an error rather than a guess.
    """
    holder_modules = {
        classes[h].module for h in bare_field_types.get(name, []) if h in classes
    }
    if len(holder_modules) != 1:
        raise ModelError(
            f"{name} is held from {sorted(holder_modules) or 'nothing'}; the generator "
            "places a compact enum next to its holder and cannot choose between them"
        )
    cm = ClassModel(
        rust_name=name,
        name=naming.class_name(name),
        module=holder_modules.pop(),
        kind=mode,
        tag=item.tag,
        content=item.content,
        doc="",
        rust_doc=item.doc,
        variants=[v.name for v in item.variants],
    )
    cm.fields = [FieldModel(item.tag or "type", TAG_FIELD_NAME, SHAPE_STR, None, "String")]
    if mode == KIND_COMPACT_NODE:
        for v in item.variants:
            cm.payload_loaders[v.name] = v.types[0].args[0].name
        cm.fields.append(
            FieldModel(item.content or "value", "node", SHAPE_COMPACT_NODE, None, "NodeRef<T>")
        )
    else:
        cm.fields.append(
            FieldModel(item.content or "value", "value", SHAPE_VERBATIM, None, "T")
        )
    return cm


def _variant_key(enum_name: str, v: RustVariant) -> str:
    return f"{enum_name}::{v.name}"


def _variant_class(
    enum_name: str,
    item: RustItem,
    v: RustVariant,
    module: str,
    classes: Dict[str, ClassModel],
    bare_field_types: Dict[str, List[str]],
    crate: RustCrate,
) -> Tuple[ClassModel, bool]:
    """One class per root variant.

    Returns ``(class, has_own_entry)``. ``has_own_entry`` is False when the
    class is the payload struct's own class, which pass 2 already registered --
    in that case it is *mutated in place* rather than copied, because
    ``Expr::Call`` and ``CallExpr`` are the same document and two field lists
    would be two places for them to drift apart.

    The two hierarchies need different naming rules and both are derived, not
    tabulated:

    * an **internally** tagged root flattens the payload struct's fields into
      the tag's own object, so the class *is* that struct -- ``Expr::Call``
      is the ``CallExpr`` class, and ``Expr::Identifier`` is the ``Identifier``
      class under its Java alias ``IdentifierExpr``;
    * an **adjacently** tagged root puts the payload under a content key and
      every payload is a different kind of thing (a struct, a fieldless enum, a
      second tagged enum), so the class is named after the *variant* with the
      root's own suffix: ``Type::List`` -> ``ListType``, ``Type::Any`` ->
      ``AnyType``, ``Type::Named`` -> ``NamedType``. All eight follow that one
      rule, which is why it is a rule and not a table.
    """
    if len(v.types) > 1:
        raise ModelError(f"{enum_name}::{v.name} has {len(v.types)} payload types")
    adjacent = item.content is not None
    content_key = item.content or "value"

    if not v.types:
        # `Type::Any` is the only unit variant of a root. serde's adjacent
        # representation of a unit variant is the bare tag, with no `value`
        # key at all, so the class has no fields and `to_payload` is absent --
        # emitting `{"type": "Any", "value": null}` would not round-trip.
        if not adjacent:
            raise ModelError(
                f"{enum_name}::{v.name} is a unit variant of an internally tagged enum, "
                "which serde cannot represent: the payload would have nowhere to go"
            )
        cm = ClassModel(
            rust_name=f"{enum_name}::{v.name}",
            name=f"{v.name}Type",
            module=module,
            kind="variant",
            tag=v.name,
            base=enum_name,
            owner=enum_name,
            rust_doc=v.doc,
        )
        return cm, True

    payload = v.types[0]
    payload_item = crate.items.get(payload.name)
    if payload_item is None:
        raise ModelError(
            f"{enum_name}::{v.name} has payload {payload.name}, which ast.rs does not declare"
        )

    # A fieldless enum: `Type::Basic(BasicType)` is `{"type":"Basic","value":"Int"}`
    # -- the tag names the shape and the payload is a bare JSON string.
    if payload_item.wire_tagging == "bare":
        if not adjacent:
            raise ModelError(
                f"{enum_name}::{v.name} carries the fieldless enum {payload.name}, but "
                f"{enum_name} is internally tagged and has nowhere to put a payload"
            )
        cm = ClassModel(
            rust_name=payload.name,
            name=f"{v.name}Type",
            module=module,
            kind="variant",
            tag=v.name,
            base=enum_name,
            owner=enum_name,
            rust_doc=payload_item.doc,
        )
        cm.fields = [
            FieldModel(
                content_key,
                ADJACENT_INLINE_FIELDS[v.name],
                SHAPE_STR,
                None,
                payload.name,
                "",
                inline=True,
            )
        ]
        return cm, True

    # A second tagged document inlined into the payload: `Type::Literal`.
    mode = compact_mode(payload_item, crate)
    if mode is not None:
        if mode == KIND_COMPACT_NODE:
            raise ModelError(
                f"{enum_name}::{v.name} carries {payload.name}, whose payloads are "
                "NodeRefs; the model does not yet cover that inside a content key"
            )
        cm = ClassModel(
            rust_name=payload.name,
            name=f"{v.name}Type",
            module=module,
            kind="variant",
            tag=v.name,
            base=enum_name,
            owner=enum_name,
            content=content_key,
            rust_doc=payload_item.doc,
            variants=[pv.name for pv in payload_item.variants],
        )
        value_field = FieldModel(
            content_key,
            ADJACENT_INLINE_FIELDS[v.name],
            SHAPE_DOC,
            None,
            payload.name,
            inline=True,
        )
        cm.fields = [value_field]
        derived = DERIVED_TAGS.get(payload.name)
        if derived:
            cm.derived = (derived, value_field.name)
        return cm, True

    # A struct: its fields are the variant's fields, under the root's tagging.
    if payload_item.kind != "struct":
        raise ModelError(
            f"{enum_name}::{v.name} has payload {payload.name}, which is a "
            f"{payload_item.wire_tagging} enum the model does not inline"
        )
    target = classes.get(payload.name)
    if target is None:
        raise ModelError(
            f"{enum_name}::{v.name} is {payload.name}, which is not an emitted class"
        )
    if adjacent:
        # The adjacent variant's class is always named `Variant + "Type"`. When
        # that is the payload struct's own name -- `Type::List` -> `ListType`,
        # which is four of the eight -- the two are the same document and the
        # struct's class is mutated in place. When it is not -- `Type::Named`
        # -> `NamedType`, holding an `Identifier` -- the variant class holds the
        # struct as one inline field instead, because a class per document is
        # the whole point.
        if f"{v.name}Type" == target.name:
            target.kind = "shared" if payload.name in bare_field_types else "variant"
            target.shared = target.kind == "shared"
            target.tag = v.name
            target.base = enum_name
            target.owner = enum_name
            if v.doc and not target.rust_doc:
                target.rust_doc = v.doc
            return target, False
        cm = ClassModel(
            rust_name=payload.name,
            name=f"{v.name}Type",
            module=module,
            kind="variant",
            tag=v.name,
            base=enum_name,
            owner=enum_name,
            rust_doc=payload_item.doc or v.doc,
        )
        cm.fields = [
            FieldModel(
                content_key,
                ADJACENT_INLINE_FIELDS[v.name],
                SHAPE_CLASS_REF,
                payload.name,
                payload.name,
                inline=True,
            )
        ]
        return cm, True
    # Internally tagged: the same object, mutated. `shared` records that the
    # class also has to decode from the untagged position, which is why the
    # emitter gives it a `kind` of its own.
    target.kind = "shared" if payload.name in bare_field_types else "variant"
    target.shared = target.kind == "shared"
    target.tag = v.name
    target.base = enum_name
    target.owner = enum_name
    target.aliases = naming.variant_aliases(target.rust_name)
    if v.doc and not target.rust_doc:
        target.rust_doc = v.doc
    return target, False


def _struct_module(
    name: str,
    item: RustItem,
    crate: RustCrate,
    bare_field_types: Dict[str, List[str]],
) -> str:
    if name in ("Comment", "Node"):
        return "_base"
    if name == "Module":
        return "_module"
    if name in bare_field_types:
        # Reachable through a field declared with the struct, so the tag is not
        # there and the class belongs with the other flat payloads.
        return "_dto"
    for enum_name, module in ENUM_ROOT_MODULE.items():
        for v in crate.items[enum_name].variants:
            if v.types and v.types[0].name == name:
                return module
    return "_dto"


def _drop_ignored(cm: ClassModel) -> None:
    cm.fields = [f for f in cm.fields if f.shape != SHAPE_IGNORED]


#: Shapes whose payload has to be a class the model knows how to decode.
NEEDS_A_CLASS = (
    SHAPE_NODE,
    SHAPE_NODE_LIST,
    SHAPE_OPT_NODE_LIST,
    SHAPE_OPT_VEC,
    SHAPE_CLASS_REF,
    SHAPE_VALUE_LIST,
    SHAPE_OP,
    SHAPE_OP_LIST,
    SHAPE_VERBATIM,
)


def _validate(model: AstModel, crate: RustCrate, root_payloads: Set[str]) -> None:
    """Refuse to emit a model that would silently decode the wrong thing."""
    known = set(model.classes) | set(model.enums) | set(naming.PRIMITIVE_PAYLOADS)
    for cm in model.classes.values():
        for f in cm.fields:
            if f.shape not in NEEDS_A_CLASS or f.payload is None:
                # `None` means "kept verbatim": the payload's *name* is a note
                # about where the document came from, not a decoder to call.
                continue
            if f.payload not in known:
                raise ModelError(
                    f"{cm.name}.{f.name} decodes a {f.payload}, which is not in the model"
                )
        for tag, payload in cm.payload_loaders.items():
            if payload not in known:
                raise ModelError(
                    f"{cm.name}'s {tag} payload decodes a {payload}, which is not in the model"
                )
        if cm.derived:
            _, source = cm.derived
            if not any(f.name == source for f in cm.fields):
                raise ModelError(
                    f"{cm.name}.{cm.derived[0]} is derived from a field {source!r} it does not have"
                )
    for enum_name in model.roots:
        root = model.enums[enum_name]
        if not root.variants:
            raise ModelError(f"{enum_name} has no variants")
        for v in root.variants:
            key = f"{enum_name}::{v}"
            if key not in model.variants:
                raise ModelError(f"{enum_name}::{v} produced no class")
    # Every struct in ast.rs is either emitted, folded into a root variant that
    # carries it, deliberately skipped with a stated reason, or the model is
    # incomplete -- and an incomplete model generates a package that is missing
    # a class rather than one that says so.
    for name, item in sorted(crate.items.items()):
        if name in model.classes or name in model.enums:
            continue
        if name in model.skipped or name in root_payloads:
            continue
        raise ModelError(
            f"ast.rs declares {name} ({item.kind}) and the model has nowhere to put it"
        )

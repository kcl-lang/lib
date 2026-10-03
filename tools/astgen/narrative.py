"""The parts of the generated output that are *not* derived from ``ast.rs``.

Everything structural -- which types exist, which are tagged and how, every
field, every wire key, every operator variant, every registry entry -- is read
out of the Rust source. What is left, and what this module holds, is prose and
the binding-level protocol around the wire format:

* **Prose.** Why a shape is the shape it is. A doc comment cannot be derived
  from a type; it is the thing a reader is actually there for, and it is also
  the thing that stops the next person from "simplifying" the shape away.
* **The ``NodeRef`` protocol.** ``Node``/``Pos``/``node_from_dict`` and its four
  siblings. Their *field lists* come from ``ast::Node<T>``, but the
  double-optionality they encode is a property of serde's treatment of
  ``Option`` and is therefore spelled out here.
* **Hand-written methods.** ``Identifier.dotted_name`` and its four siblings,
  which mirror a Rust ``impl`` block rather than a struct.

If you are looking for the reason a field has the type it has, the answer is
in :mod:`astgen.model`. If you are looking for the reason a decoder has the
*shape* it has, the answer is here.
"""

from __future__ import annotations

from typing import Dict, List

# --- module docstrings ---------------------------------------------------

MODULE_DOCS: Dict[str, str] = {
    "_base": '''Base AST infrastructure: ``Node``, ``Pos``, ``Comment``, and the
``parse_module`` / ``parse_program`` entry points.

The Rust AST crate (see ``kcl-lang/kcl/crates/ast/src/ast.rs``) wraps every
trivia in a ``Node<T>`` with positional metadata. This module provides the
Python equivalent.''',
    "_op": '''Operator and context vocabularies, generated from the fieldless enums in
``ast.rs``.

Every one of these is a Rust ``enum`` with unit variants and **no** ``#[serde]``
attribute, so serde tags them externally and each value on the wire is a bare
JSON string: ``"Add"``, not ``{"Add": null}``. The DTO fields hold those raw
strings, so an operator added upstream decodes as a plain string rather than
raising ``ValueError`` mid-parse; these classes are for reference and for
callers who want the names as constants.''',
    "_dto": '''Flat DTOs — the payload structs that appear *without* a ``"type"`` tag.

Rust's ``Expr`` and ``Stmt`` enums are internally tagged (``tag = "type"``),
so a variant's struct fields are flattened into the same JSON object as the
tag: ``{"type":"Identifier","names":[...],"pkgpath":"","ctx":"Load"}``.

But several of those same structs are *also* reachable through a field typed
``Vec<NodeRef<T>>`` / ``Option<NodeRef<T>>``, where the tag is gone because the
field is declared with the struct, not the enum variant. ``SchemaStmt.decorators``
is ``Vec<NodeRef<CallExpr>>``, so each element is a bare
``{"func": ..., "args": [...], "keywords": [...]}`` with no ``"type"`` key.

Both shapes decode to the same Python class; only the serializer differs,
because only the enum position has to write the tag back out.

This module also owns ``CallExpr`` and ``SchemaExpr``, which are shared between
the tagged (``Expr::Call`` / ``Expr::Schema``) and the flat
(``SchemaStmt.decorators`` / ``UnificationStmt.value``) positions. They live
here rather than in ``_expr`` so that ``_expr`` can import this module at
import time without a cycle — the reverse direction resolves lazily inside the
methods that actually need it.''',
    "_expr": '''Expression hierarchy — mirrors ``ast::Expr`` in
``kcl-lang/kcl/crates/ast/src/ast.rs``.

The Rust enum is internally tagged with **no** ``rename_all``::

    #[serde(tag = "type")]
    pub enum Expr { Target(Target), Identifier(Identifier), ..., Missing(MissingExpr) }

Two consequences that a decoder gets wrong silently:

* The tag is the *variant name verbatim* — ``NumberLit``, ``StringLit``,
  ``ListIfItem``, ``Check``. It is not ``Expr::get_expr_name()``'s longer
  diagnostic spelling (``"NumberLitExpression"``, ``"CheckExpression"``), and
  it is not the short ``Literal``-enum form (``"Number"``, ``"String"``).
* Every variant is a newtype over a struct, so serde flattens that struct's
  fields into the *same* object as the tag::

      {"type": "Identifier", "names": [...], "pkgpath": "", "ctx": "Load"}

  not ``{"type": "Identifier", "identifier": {...}}``. A decoder that looks
  for a wrapper key finds nothing and every field decodes to ``None``.

Several of these structs are *also* used in a flat, untagged position
(``_dto.py``) — ``Expr::Identifier`` and ``Keyword.arg`` decode to the same
:class:`Identifier`. Only the serializer differs, because only the enum
position writes the tag back out.''',
    "_stmt": '''Statement hierarchy — mirrors ``ast::Stmt`` in
``kcl-lang/kcl/crates/ast/src/ast.rs``.

The Rust enum is internally tagged with no ``rename_all``::

    #[serde(tag = "type")]
    pub enum Stmt {
        TypeAlias(TypeAliasStmt), Expr(ExprStmt), Unification(UnificationStmt),
        Assign(AssignStmt), AugAssign(AugAssignStmt), Assert(AssertStmt),
        If(IfStmt), Import(ImportStmt), SchemaAttr(SchemaAttr),
        Schema(SchemaStmt), Rule(RuleStmt),
    }

As with ``Expr``, the variant's struct fields are flattened into the same
object as the tag, so ``stmt_from_dict`` hands the whole dict to the variant.

Fields typed with a *struct* rather than an enum variant lose the tag even
inside a tagged statement: ``SchemaStmt.decorators`` is
``Vec<NodeRef<CallExpr>>``, so a decorator is a bare ``{func, args, keywords}``,
and ``SchemaStmt.checks`` is ``Vec<NodeRef<CheckExpr>>``, so a check is a bare
``{test, if_cond, msg}``. Both classes live in ``_dto.py``.''',
    "_types": '''Type hierarchy — mirrors ``kcl-lang/kcl/crates/ast/src/ast.rs::Type``.

``Type`` is the one enum in the AST that is *not* internally tagged. Rust
declares it::

    #[serde(tag = "type", content = "value")]
    pub enum Type {
        Any,
        Named(Identifier),
        Basic(BasicType),
        List(ListType),
        Dict(DictType),
        Union(UnionType),
        Literal(LiteralType),
        Function(FunctionType),
    }

Two consequences that a decoder gets wrong silently:

* The tag names the *shape*, not the type. ``BasicType`` is a fieldless enum
  with no struct wrapper, so the wire is ``{"type":"Basic","value":"Int"}`` —
  never ``{"type":"Int"}``. Keying a registry on ``"Int"`` yields nothing.
* Every payload lives under ``value``, and a *newtype* payload is inlined
  there: ``Named(Identifier)`` is
  ``{"type":"Named","value":{"names":[...],"pkgpath":"","ctx":"Load"}}`` with
  no extra wrapper key.''',
    "_module": '''Module — the root AST node. Mirrors ``ast::Module`` in
``kcl-lang/kcl/crates/ast/src/ast.rs``::

    pub struct Module {
        pub filename: String,
        pub doc: Option<NodeRef<String>>,
        pub body: Vec<NodeRef<Stmt>>,
        pub comments: Vec<NodeRef<Comment>>,
    }

There is no ``pkg`` field. The Java and Go bindings previously exposed one and
were aligned to drop it.''',
}

PACKAGE_DOC = '''Typed AST package for the KCL Python binding.

The AST JSON wire format is whatever the Rust compiler in
``kcl-lang/kcl/crates/ast/src/ast.rs`` emits via ``serde_json``. This package
mirrors that shape as Python dataclasses so Python callers can consume the
``ast_json`` field returned by ``api.parse_file`` / ``api.parse_program`` as
typed objects rather than raw ``dict``s::

    from kcl_lib.ast import Module, SchemaStmt, parse_module
    module = parse_module(api.parse_file(args).ast_json)

Three wire shapes, and picking the wrong one fails silently rather than
loudly — the whole point of the contract tests in
``python/tests/ast_contract_test.py`` is to catch that:

* ``Stmt`` and ``Expr`` are ``#[serde(tag = "type")]`` with no
  ``rename_all``. The tag is the Rust *variant name* verbatim — ``NumberLit``,
  ``StringLit``, ``Check``, not the ``get_expr_name()`` diagnostic spelling
  (``"CheckExpression"``) and not the ``Literal``-enum short form
  (``"Number"``). The variant's struct fields are flattened into the same
  object, so ``{"type":"Identifier","names":[...]}`` has no wrapper key.
* ``Type`` is ``#[serde(tag = "type", content = "value")]`` — adjacently
  tagged, and the tag names the *shape*: ``{"type":"Basic","value":"Int"}``.
* Everything else (``Identifier``, ``Target``, ``Keyword``, ``Arguments``,
  ``ConfigEntry``, ``CheckExpr``, ``CallExpr``, ``CompClause``, …) is a plain
  struct with no tag at all.

A decorator is a ``CallExpr`` and ``UnificationStmt.value`` is a
``SchemaExpr``; both reach the same struct through a field declared with the
struct rather than the enum variant, which is why the tag is missing there.
``Decorator`` and ``SchemaConfig`` are exported as aliases documenting that.

Every module in this package is generated by ``tools/generate_ast.py`` from
``crates/ast/src/ast.rs``. Do not edit any of them by hand — run the generator
and commit the result.'''

# --- class docstrings ----------------------------------------------------

CLASS_DOCS: Dict[str, str] = {
    "Identifier": '''``a`` / ``pkg.a`` / ``_c``.

Rust declares ``pub struct Identifier { names, pkgpath, ctx }`` — a plain
struct, so the same payload appears untagged under ``Keyword.arg``,
``QuantExpr.variables``, ``Arguments.args``, ``SelectorExpr.attr``,
``Type::Named`` and ``TypeAliasStmt.type_name``, and tagged as
``Expr::Identifier``. One class covers both.''',
    "MemberOrIndex": '''``a.b`` / ``b[0]`` inside a ``Target``'s path list.

``MemberOrIndex`` is its own adjacently-tagged enum
(``tag = "type", content = "value"``) and, unusually for this crate, the
payload is a ``NodeRef`` — so the value keeps its own position::

    {"type": "Member", "value": {"node": "b", "line": 3}}
    {"type": "Index",  "value": {"node": {"type": "NumberLit", ...}}}''',
    "Target": '''The left-hand side of an assignment: ``a`` / ``a.b.c`` / ``a[0].b``.

``Target`` is both a plain struct (under ``AssignStmt.targets``) and the
``Expr::Target`` variant, so it decodes from both shapes.''',
    "Keyword": '''``arg=value`` in a call or a schema.

A plain struct: ``CallExpr.keywords`` is ``Vec<NodeRef<Keyword>>``, so an
element arrives untagged, and ``Expr::Keyword`` is the same struct with a
``"type"`` key added.''',
    "Arguments": '''A parameter list — ``lambda x: int = 1, y: int = 1 { ... }``, or a
schema's generics.

``defaults`` and ``ty_list`` are ``Vec<Option<NodeRef<...>>>`` and are
index-aligned with ``args``: slot *i* describes parameter *i*. The nulls
occupy their slots and are kept, because dropping one would shift every later
annotation onto the wrong parameter.''',
    "CheckExpr": '''``len(attr) > 3 if attr, "message"``.

A plain struct, not a tagged ``Expr``: ``SchemaStmt.checks`` is
``Vec<NodeRef<CheckExpr>>`` and every element is a bare
``{test, if_cond, msg}`` object. ``Expr::Check`` is the same struct with a
``"type"`` key.''',
    "CompClause": '''One ``for x in y if z`` leg of a comprehension.

A plain struct: ``ListComp.generators`` and ``DictComp.generators`` are
``Vec<NodeRef<CompClause>>``, so there is no ``"type"`` key to dispatch on.''',
    "CallExpr": '''``f(a, b=1)``.

Also the shape of a decorator — ``SchemaStmt.decorators`` is
``Vec<NodeRef<CallExpr>>``, so ``@deprecated(strict=True)`` arrives as a bare
``{func, args, keywords}`` with no tag.''',
    "SchemaExpr": '''A schema *expression*: ``Person { name = "x" }``.

Reached two ways: as ``Expr::Schema`` (tagged) and as
``UnificationStmt.value`` (``NodeRef<SchemaExpr>``, untagged), which is why it
is declared once and aliased as ``SchemaConfig``.''',
    "ConfigEntry": '''One ``key = value`` / ``key: value`` / ``key += value`` in a config.

``is_shorthand`` is a real ``bool`` — the ``{name}`` form — and the wire omits
the key when it is false, so it is read as ``False`` rather than as absent.
A ``DictComp`` has exactly one ``entry: ConfigEntry``, not separate
key/value/entry_key fields.''',
    "SchemaIndexSignature": '''The ``[k: str]: int`` statement in a schema body.

A statement, not part of the ``schema`` header: ``schema Bag[k: str]`` is a
generic schema whose ``args`` is an ``Arguments``.''',
    "Comment": '''A line/block comment captured during parsing.

A plain struct with a *single* `String` field in Rust, so serde nests it as
``{"node": {"text": "…"}, "line": 1, …}`` — the object under `node` is an
object, not the bare text. Reading it as the text itself yields `""` for
every comment in the file without raising, which is why the round-trip
looks fine and the content does not.''',
    "Module": None,  # the module docstring covers it
    "LiteralType": '''``1``, ``"a"``, ``true`` in a type position.

``LiteralType`` is *itself* adjacently tagged, so the payload is doubly
nested: ``{"type":"Literal","value":{"type":"Int","value":{"value":1,
"suffix":null}}}``. Its four variants do not share a field set — ``Int`` inlines
the ``IntLiteralType`` struct while the other three are bare scalars — so the
inner document is kept whole and ``inner_tag`` records which kind it was.''',
    "NumberLitValue": '''The number inside a ``NumberLit``.

``NumberLitValue`` is its own ``tag + content`` enum, so the wire is
``{"type": "Int", "value": 1}`` — an object, not a bare number.''',
    "MissingExpr": '''The parser's error-recovery placeholder. It has no fields, so the wire
is ``{"type": "Missing"}`` and nothing else.''',
    "AnyType": '''``a: any = 1`` — a unit variant, so the tag is the whole document:
``{"type": "Any"}`` with no ``value`` key at all.''',
    "BasicType": '''``Int`` / ``Str`` / ``Float`` / ``Bool``.

``BasicType`` is a *fieldless* enum in Rust, so there is no struct to nest it
in: the payload is the bare JSON string and the wire is
``{"type":"Basic","value":"Int"}`` — never ``{"type":"Int"}``. The four
strings are read from the enum's own variants rather than listed here, so a
fifth one upstream shows up here as a diff.

They are exposed as a plain ``str`` rather than as an ``Enum`` for the same
reason the DTO fields hold raw strings: a value this build does not recognise
must round-trip, not raise.''',
    "NamedType": '''``Type::Named(Identifier)`` — a named type reference.

The newtype payload is inlined into ``value``, so this is a bare
``Identifier`` and **not** a ``NodeRef<Identifier>``: there is no ``node``
key and no position of its own to unwrap.''',
    "ListType": '''``[T]``. ``inner_type`` is an ``Option<NodeRef<Type>>``, and an absent one
means the list is unparameterised (``list``), not empty.''',
    "DictType": '''``{K: V}``. Both sides are ``Option<NodeRef<Type>>`` for the same reason
``ListType.inner_type`` is optional.''',
    "UnionType": '''``T1 | T2 | ...``. The Rust field is ``type_elements``, not ``types``;
the Python binding keeps the Rust spelling and the TypeScript one renames it
to ``types``. Both are asserted by their contract test, so both are the
existing names rather than a third one.''',
    "FunctionType": '''``(T1, T2) -> R``.

``params_ty`` is an ``Option<Vec<NodeRef<Type>>>``, which is two states on
the wire and not three: the parser turns an empty parameter list into
``None`` (``crates/parser/src/parser/ty.rs``), so ``Some([])`` never arrives
and the reader treats a missing list and an empty one the same way rather
than inventing a distinction the wire cannot carry. It is kept as
``Optional`` rather than defaulted to ``[]`` because ``ret_ty`` alone is a
real ``() -> R`` and the two must stay distinguishable.''',
}

#: The key the *inner* tagged document uses. Only meaningful for a class that
#: inlines a second `tag/content` document (`LiteralType`), where the outer
#: tag names the shape and this one names the kind.
INNER_TAG_KEY = "type"

# --- hand-written methods ------------------------------------------------
#
# These mirror a Rust `impl` block, not a struct, so no amount of reading
# `ast.rs` produces them. They are the *only* hand-written code in the
# generated classes.

EXTRA_METHODS: Dict[str, str] = {
    "Identifier": '''
    def dotted_name(self) -> str:
        """``Identifier::get_name()`` in Rust — the names joined with ``.``."""
        return ".".join(n.node for n in self.names if isinstance(n.node, str))
''',
    "Target": '''
    def dotted_name(self) -> str:
        """``Target::get_name()`` in Rust — the name and every ``.member``."""
        parts = [self.name.node] if self.name is not None else []
        for p in self.paths:
            if p.kind == "Member" and p.node is not None and isinstance(p.node.node, str):
                parts.append(p.node.node)
        return ".".join(str(x) for x in parts if x)
''',
    "NumberLitValue": '''
    def int_value(self) -> Optional[int]:
        """``NumberLitValue::as_int()`` in Rust, narrowed to the integer case."""
        return int(self.value) if self.kind == "Int" and isinstance(self.value, int) else None

    def float_value(self) -> Optional[float]:
        """``NumberLitValue::as_float()`` in Rust, narrowed to the float case."""
        return float(self.value) if self.kind == "Float" and isinstance(self.value, float) else None
''',
    "SchemaStmt": '''
    def schema_name(self) -> str:
        """``SchemaStmt::get_name()`` in Rust."""
        return self.name.node if self.name is not None and isinstance(self.name.node, str) else ""
''',
    "Module": '''
    def filter_schemas(self) -> List["SchemaStmt"]:  # noqa: F821
        """Return every SchemaStmt in the module body. Mirrors Rust's
        ``Module::filter_schema_stmt_from_module``."""
        from ._stmt import SchemaStmt

        out: List[SchemaStmt] = []
        for wrapped in self.body:
            if isinstance(wrapped.node, SchemaStmt):
                out.append(wrapped.node)
        return out
''',
}

#: ``ExprContext`` is generated as a plain string-constant class rather than an
#: `Enum` for the same reason the DTO fields hold raw strings, and it lives in
#: `_expr` rather than `_op` because `Expr::get_ctx_name` is part of the
#: expression vocabulary. Carried here so the exemption is a stated decision
#: rather than a gap in the generated output.
EXPR_CONTEXT_CLASS = '''class ExprContext:
    """``ExprContext`` is a fieldless enum, so it serializes as a bare string.

    Kept as a pair of string constants rather than an ``Enum`` because a new
    variant added upstream must not turn into a ``ValueError`` mid-parse.
    """

    LOAD = "Load"
    STORE = "Store"
'''

#: Bare enums that are *not* emitted as `_op` classes.
OP_ENUM_EXCLUDE: Dict[str, str] = {
    "ExprContext": "kept in _expr as string constants — see EXPR_CONTEXT_CLASS",
    "BasicType": (
        "the only payload of `Type::Basic`, which the generator emits as the "
        "Type variant class; the four bare strings are the `name` field's values"
    ),
    "NameConstant": (
        "its four variants are `True`, `False`, `None` and `Undefined`, which are "
        "Python keywords and cannot be spelled as Enum members; "
        "`NameConstantLit.value` holds the raw wire string, as every other "
        "operator field does"
    ),
}

# --- the NodeRef protocol -------------------------------------------------
#
# `Node<T>`'s field list is generated from `ast::Node<T>`. The functions below
# are the protocol around it: the same four reads the shape rules in
# `astgen.model` produce, written out once so a decoder does not have to know
# the rule to use it.

NODE_PROTOCOLS: Dict[str, str] = {
    "Pos": '''
    @classmethod
    def from_dict(cls, d: Optional[dict]) -> Optional["Pos"]:
        if d is None:
            return None
        return cls(
            {fields}
        )

    def to_dict(self) -> dict:
        d: dict = {{}}
{field_writes}        return d
''',
    "Node": '''
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
            id={id_read},
            pos=Pos.from_dict(
                {{k: v for k, v in d.items() if k != "node" and k != "id"}}
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
        d: dict = {{"node": inner}}
        if self.id is not None:
            d["id"] = self.id
        if self.pos is not None:
            d.update(self.pos.to_dict())
        return d
''',
}

NODE_REF_HELPERS = '''

# --- NodeRef helpers ----------------------------------------------------
#
# `Node<T>` is the *only* positional wrapper in the AST, and whether a field is
# wrapped in one is not guessable from the shape: `Option<NodeRef<Expr>>` and
# `Vec<NodeRef<Stmt>>` both serialize as ordinary JSON values, and a decoder
# that skips the wrapper silently produces `None` for everything. The rule is
# mechanical — it comes from how the Rust field is *declared*:
#
#   Node<String>              path        → {"node": "...", "line": 1, ...}
#   NodeRef<Expr>             value       → {"node": {...}, "line": 1, ...}
#   Vec<NodeRef<Stmt>>        body        → [{"node": {...}, ...}, ...]
#   Vec<Option<NodeRef<Type>>> ty_list    → [null, {"node": {...}}, ...]
#
# The last one is the trap: the slot exists to stay index-aligned with a
# sibling list, so a `null` must be preserved rather than dropped.


def node_from_dict(d: Optional[dict], loader=None) -> Optional[Node]:
    """``Option<NodeRef<T>>`` — a possibly-absent single node.

    ``loader`` resolves the polymorphic payload; without one the raw dict is
    kept as-is (used for ``Node<String>`` and other scalar payloads).
    """
    if d is None:
        return None
    return Node.from_dict(d, loader)


def node_list_from_dict(d: Any, loader=None) -> List[Node]:
    """``Vec<NodeRef<T>>`` — a dense list, so an absent field is an empty list."""
    if not isinstance(d, list):
        return []
    out: List[Node] = []
    for item in d:
        node = Node.from_dict(item, loader) if isinstance(item, dict) else None
        if node is None:
            continue
        out.append(node)
    return out


def optional_node_list_from_dict(d: Any, loader=None) -> List[Optional[Node]]:
    """``Vec<Option<NodeRef<T>>>`` — positional nulls are significant.

    Used for ``Arguments.defaults`` and ``Arguments.ty_list``, both of which
    are index-aligned with ``Arguments.args``: slot *i* describes parameter
    *i*, so dropping an absent entry would shift every later annotation onto
    the wrong parameter.
    """
    if not isinstance(d, list):
        return []
    return [Node.from_dict(item, loader) if isinstance(item, dict) else None for item in d]


def node_to_dict(node: Optional[Node], dumper=None) -> Optional[dict]:
    if node is None:
        return None
    return node.to_dict(dumper)


def node_list_to_dict(nodes: Optional[List[Node]], dumper=None) -> list:
    if not nodes:
        return []
    return [n.to_dict(dumper) for n in nodes if n is not None]


def optional_node_list_to_dict(nodes: Optional[List[Optional[Node]]], dumper=None) -> list:
    """Mirror of :func:`optional_node_list_from_dict` — keeps the nulls."""
    if not nodes:
        return []
    return [None if n is None else n.to_dict(dumper) for n in nodes]

'''

PARSE_ENTRY_POINTS = '''

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
'''

# --- hierarchy roots -----------------------------------------------------

HIERARCHY_BASE = {
    "Expr": '''
@dataclass
class Expr:
    """Base class. Concrete variants add their fields and override both hooks."""

    @classmethod
    def from_dict(cls, d: Any) -> "Expr":
        raise NotImplementedError

    def to_dict(self) -> dict:
        raise NotImplementedError
''',
    "Stmt": '''
@dataclass
class Stmt:
    """Base class. Concrete variants add their fields and override both hooks."""

    @classmethod
    def from_dict(cls, d: Any) -> "Stmt":
        raise NotImplementedError

    def to_dict(self) -> dict:
        raise NotImplementedError
''',
    "Type": '''
@dataclass
class Type:
    """Base class. Concrete variants subclass this and add their fields.

    An unrecognised ``"type"`` tag decodes to :class:`UnknownType`, which keeps
    the raw tag and payload so a forward-compatible parser output is not lost.
    """

    pass
''',
}

UNKNOWN_CLASS = {
    "Expr": '''
@dataclass
class UnknownExpr(Expr):
    """An ``Expr`` variant this build does not know about, preserved verbatim."""

    tag: str = ""
    value: Any = None

    @classmethod
    def from_dict(cls, d: Any) -> "UnknownExpr":
        return cls(tag=str(d.get("type") or ""), value=d)

    def to_dict(self) -> dict:
        return self.value if isinstance(self.value, dict) else {"type": self.tag}
''',
    "Stmt": '''
@dataclass
class UnknownStmt(Stmt):
    """A ``Stmt`` variant this build does not know about, preserved verbatim."""

    tag: str = ""
    value: Any = None

    @classmethod
    def from_dict(cls, d: Any) -> "UnknownStmt":
        return cls(tag=str(d.get("type") or ""), value=d)

    def to_dict(self) -> dict:
        return self.value if isinstance(self.value, dict) else {"type": self.tag}
''',
    "Type": '''
@dataclass
class UnknownType(Type):
    """A tag this build does not know about, preserved verbatim."""

    tag: str = ""
    value: Any = None

    @classmethod
    def from_dict(cls, d: dict) -> "UnknownType":
        return cls(tag=d.get("type", ""), value=d.get("value"))

    def to_payload(self) -> Any:
        return self.value

    def to_dict(self) -> Any:
        return {"type": self.tag, "value": self.value}
''',
}

#: The polymorphic dispatch for a hierarchy. `adjacent` is the difference
#: between `Stmt`/`Expr` (the variant reads the *same* object as the tag) and
#: `Type` (the variant reads the object's `value` key).
#:
#: The registry is built on first use rather than at import time. `Expr`'s
#: shared payloads (`Identifier`, `Target`, `Keyword`, `CallExpr`, `SchemaExpr`)
#: live in `._dto`, which top-imports this module because `class CallExpr(Expr)`
#: needs `Expr` to already exist; importing `_dto` back from here at module
#: scope would be exactly the cycle CPython refuses to resolve. Inside a
#: function it is not a cycle at all: by the time anything calls
#: `expr_from_dict`, both modules have finished loading. That is also why
#: `_dto` is the one module allowed to top-import a hierarchy.
DISPATCH_TEMPLATE = '''

_{SCOPE}_REGISTRY: Optional[Dict[str, Any]] = None
_{SCOPE}_TAGS_BY_CLASS: Dict[type, str] = {{}}


def _{scope}_registry() -> Dict[str, Any]:
    """Wire tag -> class, in the order ``ast.rs`` declares the variants.

    Built on first use rather than at import time: see the note above.
    """
    global _{SCOPE}_REGISTRY, _{SCOPE}_TAGS_BY_CLASS
    if _{SCOPE}_REGISTRY is None:
{imports}        _{SCOPE}_REGISTRY = {{
{registry}}}
        _{SCOPE}_TAGS_BY_CLASS = {{cls: tag for tag, cls in _{SCOPE}_REGISTRY.items()}}
    return _{SCOPE}_REGISTRY


def _{scope}_tag_for(cls: type) -> Optional[str]:
    """The wire tag for a variant class — the inverse of the registry."""
    if not _{SCOPE}_TAGS_BY_CLASS:
        _{scope}_registry()
    return _{SCOPE}_TAGS_BY_CLASS.get(cls)


def {scope}_from_dict(d: Any) -> Any:
    """Polymorphic ``{root}`` loader — the mirror of :func:`{scope}_to_dict`.

    An unrecognised tag decodes to :class:`Unknown{Root}`, which keeps the raw
    tag and payload so a forward-compatible parser output survives the round
    trip instead of being dropped.
    """
    d = d if isinstance(d, dict) else {{}}
    tag = d.get("{tag}") or ""
    cls = _{scope}_registry().get(tag)
    if cls is None:
        return Unknown{Root}.from_dict(d)
    return cls.from_dict({value_arg})


def {scope}_to_dict(s: Any) -> Any:
    """Polymorphic ``{root}`` serializer — the mirror of :func:`{scope}_from_dict`."""
    if s is None:
        return None
    if isinstance(s, Unknown{Root}):
        return s.to_dict()
    tag = _{scope}_tag_for(type(s))
    if tag is None:
        raise TypeError("not a {Root} variant: %s" % type(s).__name__)
{emit}'''

DISPATCH_EMIT_INTERNAL = '''    out = {"type": tag}
    out.update(s.to_dict())
    return out'''

DISPATCH_EMIT_ADJACENT = '''    to_payload = getattr(s, "to_payload", None)
    if to_payload is None:
        # `Any` is a unit variant — the tag is the whole document.
        return {"type": tag}
    return {"type": tag, "value": to_payload()}'''

# --- TypeScript ----------------------------------------------------------

TS_MODULE_DOCS: Dict[str, str] = {
    "_base": """// _base.ts — Pos, Node<T>, Comment, and the wire types they read.
// Mirrors `ast::Pos` / `NodeRef<T>` / `Comment` in `crates/ast/src/ast.rs`.""",
    "_dto": """// _dto.ts — Flat DTOs the AST nests inside `NodeRef<T>` where the wire shape
// lacks a polymorphic `type` discriminator. Mirrors
// `../kcl/crates/ast/src/ast.rs`, where these are plain structs rather than
// enum variants.
//
// Two things are easy to get wrong here and both fail silently, because an
// object with no `type` key decodes to undefined rather than throwing:
//
//   1. `ast::Expr` and `ast::Stmt` are internally tagged, and their variants
//      are *newtypes over a struct*, so serde flattens the struct's fields
//      into the same object. `Expr::Check(CheckExpr)` arrives as
//      `{"type": "Check", "test": ..., "if_cond": ..., "msg": ...}` — there is
//      no `check` wrapper key to descend through.
//   2. These structs carry no tag at all, so they cannot be dispatched on.
//      `SchemaStmt.checks` is `Vec<NodeRef<CheckExpr>>` and its elements are
//      bare `{test, if_cond, msg}` objects.
//
// The cycle between this module and _expr is broken by reading the decoder at
// call time. TypeScript's CommonJS output for a named import is a `require` at
// module scope and a property read at each *use*, so `exprFromWire` is looked
// up when it is called, not when `_dto` is evaluated — and `_dto` is reached
// from `_expr` in the middle of that same load. What would not survive the
// cycle is a table built at module scope: see the tag table in `_expr`.""",
    "_types": """// _types.ts — Type hierarchy. Mirrors `ast::Type` in `crates/ast/src/ast.rs`.
//
// `Type` is declared `#[serde(tag = "type", content = "value")]` — note the
// `content`. That makes it the one hierarchy in the AST that is *adjacently*
// tagged rather than internally tagged: every node is a two-key object
// `{"type": "<Variant>", "value": <payload>}`, and the tag names the shape,
// not the type. A basic type therefore reads back as
// `{"type": "Basic", "value": "Int"}` and **not** as `{"type": "Int"}`,
// because `BasicType` is a fieldless enum with no struct wrapper.
//
// There is no `Void`, `Undefined`, `None`, `SchemaRef` or `KeyValue` variant:
// the eight below are the whole enum. A tag outside this set is returned as
// `UnknownType` rather than dropped, so a newer parser degrades instead of
// throwing.""",
    "_expr": """// _expr.ts — Expression hierarchy. Mirrors `ast::Expr` in `crates/ast/src/ast.rs`.
//
// `Expr` is `#[serde(tag = "type")]`, and because every variant is a
// *newtype over a struct*, serde flattens the struct's fields into the same
// object. An identifier is `{"type": "Identifier", "names": [...]}` — there
// is no `identifier` wrapper key to descend through. Getting that wrong is
// the single most common bug in a hand-written AST loader, and it is silent:
// the wrapper key is always absent, so every identifier comes back empty.
//
// `_dto`, `_expr` and `_stmt` require each other. TypeScript's CommonJS output
// resolves an imported decoder at each call site rather than at module scope,
// so the cycle resolves; the one thing that would not survive it is a tag table
// written as a module-scope object literal, which reads the entry while the
// other half of the cycle is still half-loaded. Hence `tagLoaders` below.""",
    "_stmt": """// _stmt.ts — Statement hierarchy. Mirrors `ast::Stmt` in `crates/ast/src/ast.rs`.
//
// `Stmt` is `#[serde(tag = "type")]` and its variants are newtypes over
// structs, so serde flattens the fields into the same object. `If` is both
// a `Stmt` and an `Expr` — the tag alone does not say which, so the statement
// loader and the expression loader each own their own `If`.""",
    "_module": """// _module.ts — Module AST node + parseModule/parseProgram helpers.
//
// Mirrors `ast::Module` in `crates/ast/src/ast.rs`. The Rust struct has no
// `pkg` field — the Java/Go bindings previously exposed one and were aligned
// to drop it.""",
    "index": """// index.ts — Public surface of the typed AST package.
//
// Mirrors the Python ``kcl_lib.ast`` and Node.js ``src/ast`` packages: a
// thin loader that converts the JSON strings emitted by ``parseFile`` /
// ``parseProgram`` into typed objects matching Rust's AST in
// ``crates/ast/src/ast.rs``.""",
}

#: Class-level JSDoc prose, for the classes whose subtlety is not visible from
#: the Rust alone. Stored without the `/**` delimiters: the emitter wraps them,
#: so a one-line entry stays one line in the output.
TS_CLASS_DOCS: Dict[str, str] = {
    "Identifier": "`ast::Identifier` — `a`, `_c`, `pkg.a`. A plain struct with no tag.",
    "MemberOrIndex": """`ast::MemberOrIndex` — the `tag + content` enum behind a `Target`'s paths.
Its `value` is itself a `NodeRef`, so `Member` wraps a `NodeRef<String>`
and `Index` a `NodeRef<Expr>`.""",
    "Arguments": """`ast::Arguments` — a lambda's parameter list. `defaults` and `tyList` are
`Vec<Option<...>>` the same length as `args`, so the nulls are kept.""",
    "SchemaExpr": """`ast::SchemaExpr` — the payload of both the `Schema` expression variant and
`UnificationStmt.value`. It is a plain struct, so when it appears *outside*
the `Expr` enum (as the right-hand side of `s: Person { ... }`) it arrives
with no `type` tag and cannot go through `exprFromWire`.""",
    "CallExpr": """`ast::CallExpr`. A decorator (`@deprecated(strict=True)`) is one of these —
`SchemaStmt.decorators` is `Vec<NodeRef<CallExpr>>`, and only the *enum* is
tagged, so each element arrives as a bare `{func, args, keywords}`.""",
    "SchemaIndexSignature": """`ast::SchemaIndexSignature` — the `[k: str]: int` statement in a schema
body. Note it is a *body statement*, not part of the `schema` header:
`schema Bag[k: str]` is a generic schema whose `args` is an `Arguments`.""",
    "AnyType": "`Type::Any` — a bare `{\"type\": \"Any\"}` with no payload.",
    "BasicType": "`Type::Basic(BasicType)`. The payload is a bare string, not an object.",
    "NamedType": "`Type::Named(Identifier)`.",
    "ListType": "`Type::List(ListType)`.",
    "DictType": "`Type::Dict(DictType)`.",
    "UnionType": """`Type::Union(UnionType)`. The Rust field is `type_elements`; it is exposed
as `types` here because `types` is what a caller reaches for.""",
    "FunctionType": "`Type::Function(FunctionType)`.",
    "LiteralType": """`Type::Literal(LiteralType)`. `LiteralType` is *itself* tagged, so the
payload is doubly nested: `{"type":"Int","value":{"value":1,"suffix":null}}`.""",
    "UnknownType": """A tag this build does not know about. `value` is the raw payload, so a
caller can still reach the data a future parser emitted.""",
    "Comment": """`Comment` is a plain struct with one `String` field in Rust, so the object
under `node` is `{"text": "…"}` and not the text itself. Typing it as
`Node<string>` hands every caller an object where it promised a string.""",
}

#: `UnknownType` — the arm of the `Type` switch for a tag this build does not
#: know. Not in `ast.rs`: it is the forward-compatibility half of the decoder,
#: and dropping an unrecognised tag would make a newer parser's output silently
#: empty. The three lines of interface are the only structure the emitter
#: invents. `tag` keeps the unrecognised tag rather than flattening it into
#: `type`, so a caller can tell "this build does not know `Void`" from "this is
#: a type literally called `Unknown`" — and `type` is pinned to `'Unknown'` so
#: the `Type` union stays a discriminated union.
TS_UNKNOWN_TYPE = """export interface UnknownType {
  type: 'Unknown';
  tag: string;
  value?: unknown;
}"""

#: Why the emitted list reads keep their length instead of filtering. Prepended
#: as an inline comment to every `Vec<Option<...>>` read, because the `.map` and
#: the absent `.filter` are otherwise indistinguishable from a plain copy.
TS_NULL_SLOT_NOTE = """A `Vec<Option<...>>` null occupies a slot: `.map` keeps it where it
is, and a `filter` would shift every later element one to the left."""

#: Why the emitted tag table is built on first use. The table itself is a loop
#: over the variants; only the reasoning is kept here.
TS_DISPATCH_NOTE = """The `{root}` tag table, built on first use rather than at module scope.

`_dto`, `_expr` and `_stmt` require each other, and a table built while one of
them is half-loaded would freeze a half-loaded decoder into the entry — every
`Call` expression would come back as unknown, with nothing to say so. The
indirection costs one branch and makes the cycle safe."""

TS_FIELD_NOTES: Dict[str, str] = {
    "ConfigEntry.is_shorthand": """
   * ES6 `{name}` form. The wire omits the key when false
   * (`skip_serializing_if`), so this is always a real boolean here.""",
    "Identifier.ctx": """
   * `ExprContext` is a fieldless enum, so this is a bare string on the wire
   * (`"Load"` or `"Store"`), not an object.""",
    "Arguments.defaults": """
   * `Vec<Option<NodeRef<Expr>>>` — index-aligned with `args`, so the nulls
   * keep their slots.""",
    "Arguments.ty_list": """
   * `Vec<Option<NodeRef<Type>>>` — index-aligned with `args`, so the nulls
   * keep their slots.""",
    "FunctionType.ret_ty": """
   * The Rust field is `ret_ty`; it is the `Type` a function returns.""",
    "FunctionType.params_ty": """
   * `Option<Vec<NodeRef<Type>>>`: the parser produces `None` or
   * `Some(non-empty)` and never `Some(vec![])`, so an absent list and an
   * empty one mean the same thing here.""",
    "ImportStmt.path": """
   * `Node<String>`, not `NodeRef<Expr>` — a dotted path, read as a string.""",
    "SchemaIndexSignature.key_name": """
   * `Option<Node<String>>` with `#[serde(flatten)]`, so the key is inlined
   * rather than nested under `node`.""",
    "CheckExpr.if_cond": """
   * `Option<NodeRef<Expr>>` with `#[serde(flatten)]` — the position is
   * optional *and* the wrapper may hold no value.""",
    "LiteralType.value": """
   * The inner document, kept whole: `LiteralType`'s four variants do not
   * share a field set.""",
    "Subscript.lower": """
   * A slice is `lower`/`upper`/`step`; `index` is only set for `a[0]`.""",
    "JoinedString.values": """
   * `Vec<NodeRef<Expr>>` — the interpolated expressions, not the literals.""",
    "FormattedValue.format_spec": """
   * A plain `Option<String>`, not a `NodeRef<Expr>`.""",
    "SchemaStmt.index_signature": """
   * A body statement, not part of the `schema` header.""",
    "DictComp.entry": """
   * A `DictComp` has exactly one `entry: ConfigEntry` — not separate
   * key/value/entry_key fields.""",
    "MissingExpr.*": """
   * `Expr::Missing` has no fields. The parser only emits it during error
   recovery, so it never appears in a clean parse.""",
}

#: `MaybeNode<T>` is the one type in the TypeScript binding that is not derived
#: from a field: it is the *shape* of every `NodeRef` position, and its doc
#: comment is the two-level-optionality argument. Everything else in `_base.ts`
#: -- `Pos`, `Node`, `WirePos`, `WireNode`, `posFromWire`, `nodeFromWire` and
#: `commentFromWire` -- is generated from `ast::Node`'s own field list.
TS_MAYBE_NODE = """/**
 * `NodeRef<T>` at both levels of optionality: the wrapper itself may be absent
 * (an `Option<NodeRef<T>>` field serializes as `null`), and a present wrapper
 * may still hold no value, since serde emits `"node": null` rather than
 * dropping the key. `Vec<Option<...>>` fields — `Arguments.defaults`,
 * `Arguments.ty_list` — are the same idea elementwise: the nulls are
 * meaningful and have to keep their slot.
 */
export type MaybeNode<T> = Node<T | undefined> | undefined;"""

#: The list reader for a `Vec<T>` whose elements arrive *bare* -- no
#: `NodeRef` wrapper around any of them. `Target.paths : Vec<MemberOrIndex>` is
#: the only such field in the tree; everything else that is a list is
#: `Vec<NodeRef<T>>` or `Vec<Option<NodeRef<T>>>` and goes through
#: `nodeFromWire` elementwise. The two look alike and are not
#: interchangeable: routing this one through `nodeFromWire` reads a `node` key
#: that is not on the wire and yields a list of empty wrappers.
#:
#: The name is the one the hand-written binding used for its list reader and
#: the one `hack/check_ast_field_types.rb` keys on (`mapNodes(w.<key>, <load>)`
#: is one of the two spellings its TypeScript list branch accepts). It is
#: inherited rather than chosen for accuracy -- the return type is `T[]`, not
#: `Array<Node<T>>` -- so the signature is the thing to read, and the note
#: above it is the reason the two kinds of list are not merged.
TS_MAP_NODES = """/**
 * Decode a `Vec<T>` whose elements arrive bare -- no `NodeRef` wrapper around
 * any of them. `Target.paths : Vec<MemberOrIndex>` is the only such field in
 * the tree; every other list is `Vec<NodeRef<T>>` or
 * `Vec<Option<NodeRef<T>>>` and is read elementwise through `nodeFromWire`.
 * Sending this one through `nodeFromWire` instead reads a `node` key that is
 * not on the wire and yields a list of empty wrappers.
 *
 * The name is inherited from the hand-written binding and from the spelling
 * `hack/check_ast_field_types.rb` recognises for a list read; the return type
 * is `T[]`, not `Array<Node<T>>`.
 */
export function mapNodes<T>(
  items: unknown[] | undefined | null,
  load: (inner: never) => T,
): Array<T> {
  return (items || []).map((b) => load(b as never));
}"""

#: The two JSON-string entry points. They are public API rather than generated
#: code: `moduleFromWire` below them *is* generated from `ast::Module`'s fields.
TS_MODULE_EXTRAS = {
    "parseModule": '''export function parseModule(astJson: string): Module {
  return moduleFromWire(JSON.parse(astJson));
}''',
    "parseProgram": '''export function parseProgram(programJson: string): Array<Module> {
  const env = JSON.parse(programJson);
  if (Array.isArray(env)) {
    return (env as unknown[]).map((m) => moduleFromWire(m as Record<string, unknown>));
  }
  const pkgs = (env.pkgs as Record<string, unknown> | undefined) || {};
  const main = (pkgs.__main__ as unknown[]) || [];
  return main.map((m) => moduleFromWire(m as Record<string, unknown>));
}''',
}

#: The `Type` switch's unknown-tag arm, and the reason it is a literal rather
#: than a generated arm: it is the forward-compatibility half of the decoder,
#: not a variant in `ast.rs`. Dropping an unrecognised tag would make a newer
#: parser's output silently empty. Kept as two lines with no indentation --
#: the emitter supplies the indent, because the same text sits at a different
#: column in the Python binding's `else:` branch.
TS_TYPE_FALLBACK = """default:
return { type: 'Unknown', tag, value };"""


def all_class_names() -> List[str]:
    return sorted(CLASS_DOCS)

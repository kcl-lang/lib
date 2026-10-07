"""Emit the Go binding's AST package.

Modelled on :mod:`astgen.emit_typescript`. The Python and TypeScript output are
the reference for what the wire looks like; this file's job is the same job in a
language whose shapes differ, not to restate it.

Four things Go does differently, and why each is written the way it is:

**One package, not seven modules.** Python splits the AST across ``_base``,
``_dto``, ``_expr`` and four more because they import each other in a cycle and
a top-level import of the far side fails at import time under CPython. Go has no
such constraint, so the split here is by reading order and there is no
import-cycle policy to maintain -- which is why ``naming.PY_MODULE_POLICY`` has
no Go counterpart and why the generated files are split at all (readability, not
dependency).

**The tag is a field.** Every variant carries ``Type string`\\ ``json:"type"``\\ and
it is set at decode time, so the struct marshals back out through
``encoding/json`` with the discriminator already in place. The alternative is a
``MarshalJSON`` per variant that splices the key back into its own output --
41 extra methods and a re-marshal per node for no gain.

**Generics for the wrapper, named types for its slots.** ``Node[T]`` is generic
because ``ast::Node<T>`` is, but a generic *method* cannot dispatch on ``T``, and
the payload's union has to be named by something. So each payload gets a slot
type -- ``ExprNode`` embeds ``Node[Expr]`` and supplies the one
``UnmarshalJSON`` that calls ``exprFromWire``. Fifteen slots, one dispatcher
each, and the mapping lives in the struct declaration where the compiler checks
it. The alternative is trying every dispatcher in turn and taking the first that
type-asserts, which is what the kcl-go binding does and which yields a zero node
whenever a dispatcher succeeds against the wrong union.

**Hand-written decode, stock encode.** Marshal needs nothing written for it: the
tags are in the declarations and interface-typed fields dispatch on their dynamic
value. Decode is written out per field, because that is the one direction where
picking the wrong shape produces a zero value rather than an error.
"""

from __future__ import annotations

from typing import Dict, List, Optional

from . import model as M
from . import narrative
from .model import AstModel, ClassModel, FieldModel, KIND_COMPACT_NODE

#: Files this emitter owns.
GO_FILES: List[str] = [
    "base_gen.go",
    "op_gen.go",
    "dto_gen.go",
    "nodes_gen.go",
    "expr_gen.go",
    "stmt_gen.go",
    "types_gen.go",
    "module_gen.go",
]

_MODULE_TO_FILE: Dict[str, str] = {
    "_base": "base_gen.go",
    "_op": "op_gen.go",
    "_dto": "dto_gen.go",
    "_expr": "expr_gen.go",
    "_stmt": "stmt_gen.go",
    "_types": "types_gen.go",
    "_module": "module_gen.go",
}

#: `NodeRef<String>` is the one primitive payload; every other slot takes its
#: name from the payload type itself.
_PRIMITIVE_SLOTS = {"String": "StringNode"}

#: Shapes that go through a decoder rather than through `encoding/json`.
_DECODED = (
    M.SHAPE_NODE,
    M.SHAPE_NODE_STR,
    M.SHAPE_NODE_LIST,
    M.SHAPE_OPT_NODE_LIST,
    M.SHAPE_OPT_VEC,
    M.SHAPE_CLASS_REF,
    M.SHAPE_VALUE_LIST,
    M.SHAPE_COMPACT_NODE,
)

_NODE_SHAPES = (
    M.SHAPE_NODE,
    M.SHAPE_NODE_STR,
    M.SHAPE_NODE_LIST,
    M.SHAPE_OPT_NODE_LIST,
    M.SHAPE_OPT_VEC,
)


def go_doc(text: str, indent: str = "") -> List[str]:
    """A doc comment wrapped to Go's width, or nothing for an empty string."""
    text = (text or "").strip()
    if not text:
        return []
    out: List[str] = []
    for paragraph in text.split("\n\n"):
        # A single newline inside a paragraph is a soft wrap in the source
        # prose, not a line break in the comment: joining first is what keeps
        # `gofmt` from reading an indented continuation as a code block and
        # turning the rest of the paragraph into one.
        flat = " ".join(line.strip() for line in paragraph.splitlines())
        lines: List[str] = []
        while len(flat) > 76:
            cut = flat.rfind(" ", 0, 76)
            if cut <= 0:
                cut = 76
            lines.append(flat[:cut])
            flat = flat[cut:].strip()
        lines.append(flat)
        if out:
            out.append(f"{indent}//")
        out.extend(f"{indent}// {line}".rstrip() for line in lines)
    return out


class GoEmitter:
    """Turn the shared :class:`~astgen.model.AstModel` into Go source."""

    def __init__(self, model: AstModel) -> None:
        self.m = model
        # `BasicType` is in `model.enums` as a bare enum *and* is the payload of
        # `Type::Basic`, for which the model emits a class of the same name
        # holding the folded `name` field. Python puts the two in different
        # modules so they never collide; Go has one flat namespace, so the op
        # enum is dropped here rather than emitted under a second name. There is
        # nothing to lose: `Type::Basic`'s class already *is* those four strings.
        emitted = {cm.rust_name for cm in model.classes.values()}
        self._op_enums = {
            n: c
            for n, c in model.enums.items()
            if c.kind == "op_enum" and n not in emitted
        }
        self.slots: Dict[str, str] = {}
        for cm in model.classes.values():
            for f in cm.fields:
                if f.shape in _NODE_SHAPES and f.payload:
                    self.slots.setdefault(f.payload, self._slot_name(f.payload))

    # --- naming ----------------------------------------------------------

    def _slot_name(self, payload: str) -> str:
        return _PRIMITIVE_SLOTS.get(payload, payload + "Node")

    def _slot_payload(self, slot: str) -> str:
        return "string" if slot == "StringNode" else slot[: -len("Node")]

    @staticmethod
    def _exported(field: str) -> str:
        """`end_line` -> `EndLine`. The wire name stays in the struct tag."""
        return "".join(p[:1].upper() + p[1:] for p in field.split("_"))

    # --- types -----------------------------------------------------------

    @staticmethod
    def _num_type(f: FieldModel) -> str:
        return "float64" if "f64" in f.rust_type else "int64"

    def go_type(self, f: FieldModel) -> str:
        s = f.shape
        simple = {
            M.SHAPE_STR: "string",
            M.SHAPE_OPT_STR: "*string",
            M.SHAPE_BOOL: "bool",
            M.SHAPE_NUM: self._num_type(f),
            M.SHAPE_OPT_NUM: None,
            M.SHAPE_OP: f.payload or "string",
            M.SHAPE_OP_LIST: None,
            M.SHAPE_VALUE_LIST: "[]" + str(f.payload),
            M.SHAPE_VERBATIM: "any",
            M.SHAPE_DOC: "map[string]any",
            M.SHAPE_OPAQUE: "any",
            M.SHAPE_GENERIC: "any",
            M.SHAPE_COMPACT_NODE: "*MemberOrIndex",
        }
        if s == M.SHAPE_OPT_NUM:
            return "*" + self._num_type(f)
        if s == M.SHAPE_OP_LIST:
            return "[]" + str(f.payload)
        if s in _NODE_SHAPES:
            slot = self._slot_name(str(f.payload))
            return ("*" + slot) if s in (M.SHAPE_NODE, M.SHAPE_NODE_STR) else ("[]*" + slot)
        if s == M.SHAPE_CLASS_REF:
            return str(f.payload) if f.inline else "*" + str(f.payload)
        if s in simple and simple[s] is not None:
            return simple[s]
        raise M.ModelError(f"{f.wire}: no Go type for shape {s!r}")

    def _tag_key(self, cm: ClassModel) -> str:
        """The wire *key* a variant's tag lives under.

        `ClassModel.tag` is the tag's *value* for a hierarchy variant -- the
        model sets it to the Rust variant name, so `Import` for
        `Stmt::Import`. The key it is written under comes from the root enum's
        serde tagging, which is `type` for all three. The compact classes are
        the opposite case: there `cm.tag` is the key and there is no owner to
        ask.
        """
        if cm.owner and cm.owner in self.m.enums:
            return self.m.enums[cm.owner].tag or "type"
        return cm.tag

    @staticmethod
    def _tag(f: FieldModel) -> str:
        """`omitempty` wherever absent and empty are the same thing on the
        wire. A bare `Option<T>` still needs its key written when it is absent,
        which is why `optional` -- not the shape -- is what decides."""
        parts = [f'json:"{f.wire}']
        # Only `Option` fields are genuinely two-state on the wire, and the
        # model already knows which those are. A plain Rust `String` or integer
        # is written unconditionally -- `Identifier.pkgpath` is `""` on the
        # wire, not absent -- so `omitempty` on one is a key the parser never
        # emitted. A `bool` is the third case: present only when it is true, and
        # that is what `skip_serializing_if` records.
        if f.skip_false:
            parts.append("omitempty")
        return ",".join(parts) + '"'

    # --- decode ----------------------------------------------------------

    def _slot_list(self, f: FieldModel, pad: str, keep_nulls: bool) -> List[str]:
        """Read a list of nodes. A `null` slot is meaningful only for
        `Vec<Option<NodeRef<T>>>`, whose two holders are both index-aligned with
        `Arguments.args` -- dropping an absent default would shift every later
        annotation onto the wrong parameter."""
        slot = self._slot_name(str(f.payload))
        name = self._exported(f.name)
        out = [
            f'{pad}var list []json.RawMessage',
            f'{pad}if err := json.Unmarshal(raw, &list); err != nil {{',
            f"{pad}\treturn err",
            f"{pad}}}",
            f"{pad}c.{name} = make([]*{slot}, len(list))",
            f"{pad}for i, item := range list {{",
        ]
        if keep_nulls:
            out += [
                f"{pad}\tif isJSONNull(item) {{",
                f"{pad}\t\tcontinue",
                f"{pad}\t}}",
            ]
        out += [
            f"{pad}\tvar v {slot}",
            f"{pad}\tif err := json.Unmarshal(item, &v); err != nil {{",
            f"{pad}\t\treturn err",
            f"{pad}\t}}",
            f"{pad}\tc.{name}[i] = &v",
            f"{pad}}}",
        ]
        return out

    def _read(self, f: FieldModel, pad: str) -> List[str]:
        """The statements that read one wire key into one Go field."""
        name = self._exported(f.name)

        if f.shape in _DECODED:
            out = [
                f'{pad}if raw, ok := d["{f.wire}"]; ok && !isJSONNull(raw) {{',
                f'{pad}\tvar c0 {self.go_type(f)}',
                f"{pad}\tif err := json.Unmarshal(raw, &c0); err != nil {{",
                f"{pad}\t\treturn err",
                f"{pad}\t}}",
                f"{pad}\tc.{name} = c0",
                f"{pad}}}",
            ]
            return out

        if f.shape in (M.SHAPE_STR, M.SHAPE_NUM, M.SHAPE_BOOL, M.SHAPE_OP, M.SHAPE_OP_LIST):
            return [
                f'{pad}if raw, ok := d["{f.wire}"]; ok && !isJSONNull(raw) {{',
                f"{pad}\tif err := json.Unmarshal(raw, &c.{name}); err != nil {{",
                f"{pad}\t\treturn err",
                f"{pad}\t}}",
                f"{pad}}}",
            ]

        reader = {
            M.SHAPE_OPT_STR: "readOptString",
            M.SHAPE_VERBATIM: "readJSON",
            M.SHAPE_DOC: "readDocument",
            M.SHAPE_OPAQUE: "readJSON",
        }.get(f.shape)
        if f.shape == M.SHAPE_OPT_NUM:
            reader = "readOptInt64" if self._num_type(f) == "int64" else "readOptFloat64"
        if reader is None:
            raise M.ModelError(f"{f.wire}: no reader for shape {f.shape!r}")
        return [
            f'{pad}c.{name} = {reader}(d["{f.wire}"])',
        ]

    def _from_wire_body(self, cm: ClassModel) -> List[str]:
        out: List[str] = []
        for f in cm.fields:
            out += self._read(f, "\t")
        out.append("\treturn nil")
        return out

    # --- classes ---------------------------------------------------------

    @staticmethod
    def _inline_only(cm: ClassModel) -> bool:
        """True when the class *is* its single inline field's value.

        `Type::Basic` is `{"type":"Basic","value":"Int"}`, so `BasicType`
        serialises to the bare string `Int`; `Type::Named` inlines an
        `Identifier` with no `NodeRef`, so `NamedType` serialises to the
        identifier's own object. Emitting `{"value": …}` under a `value` key for
        either would be one level of nesting too many.
        """
        return len(cm.fields) == 1 and cm.fields[0].inline

    def _emit_class(self, cm: ClassModel) -> List[str]:
        out: List[str] = []

        doc = narrative.CLASS_DOCS.get(cm.rust_name) or cm.rust_doc
        out += go_doc(doc)
        key = self._tag_key(cm)
        # `Type` is adjacently tagged, so every one of its variants puts its
        # payload under the content key: `Type::List(ListType)` is
        # `{"type": "List", "value": {"inner_type": …}}`. `Expr` and `Stmt` are
        # internally tagged and spread their payload's fields beside the tag, so
        # the wrapper is asked of the owning root rather than guessed per class.
        owner = self.m.enums.get(cm.owner) if cm.owner else None
        adjacent = bool(owner and owner.content) and not self._inline_only(cm)
        content = (owner.content if owner else None) or "value"
        # An adjacent payload carries no tag of its own -- the tag is a
        # property of the wrapper `marshalAdjacent` builds around it -- so the
        # field would be dead weight, and a struct that both holds `Type` and
        # re-derives it in `MarshalJSON` has two answers to the same question.
        tag_field = bool(cm.tag) and not self._inline_only(cm) and not adjacent
        out.append(f"type {cm.name} struct {{")
        if tag_field:
            out.append(f'\tType string `json:"{key},omitempty"`')
        if not cm.fields:
            out.append("// The wire document for a unit variant is the bare tag.")
        for f in cm.fields:
            out.append(f"\t{self._exported(f.name)} {self.go_type(f)} `{self._tag(f)}`")
        out.append("}")
        out.append("")

        for alias in cm.aliases:
            out.append(f"// {alias} is the name this document reaches under as a "
                       f"{cm.base or 'root'} variant.")
            out.append(f"type {alias} = {cm.name}")
            out.append("")

        if adjacent:
            out.append("// MarshalJSON nests the fields under the content key, which")
            out.append("// is what an adjacently-tagged enum's variant serialises to.")
            out.append(f"func (c {cm.name}) MarshalJSON() ([]byte, error) {{")
            out.append(f"	type plain {cm.name}")
            out.append(f'	return marshalAdjacent(plain(c), "{cm.tag}", "{key}", "{content}")')
            out.append("}")
            out.append("")

        if self._inline_only(cm):
            f = cm.fields[0]
            field = self._exported(f.name)
            out += go_doc(
                f"`{cm.name}` marshals to its inlined payload itself: `{cm.tag}` puts "
                f"the tag on the *outer* object and the content key "
                f"`{f.wire}` carries the whole value, so wrapping it again would be one "
                f"level of nesting too many."
            )
            out.append(f"func (c {cm.name}) MarshalJSON() ([]byte, error) {{")
            out.append('\treturn json.Marshal(map[string]any{')
            out.append(f'\t\t"type":  "{cm.tag}",')
            out.append(f'\t\t"{f.wire}": c.{field},')
            out.append("\t})")
            out.append("}")
            out.append("")

        out += go_doc(
            f"Read `{cm.name}` from its wire object. Every key is read through its "
            f"own shape, which is the only place the four shapes can be told apart."
        )
        out.append(f"func (c *{cm.name}) fromWire(d map[string]json.RawMessage) error {{")
        if adjacent:
            out.append(f"\t// The document is the wrapper: the payload is under")
            out.append(f'\t// `"{content}"` and the tag is on the object around it.')
            out.append("\tinner, err := readAdjacent(d, " + f'"{content}"' + ")")
            out.append("\tif err != nil {")
            out.append("\t\treturn err")
            out.append("\t}")
            out.append("\td = inner")
        if tag_field:
            out.append(f'\tif raw, ok := d["{key}"]; ok {{')
            out.append(f"\t\tif err := json.Unmarshal(raw, &c.Type); err != nil {{")
            out.append("\t\t\treturn err")
            out.append("\t\t}")
            out.append("\t}")
        out += self._from_wire_body(cm)
        out.append("}")
        out.append("")
        out += go_doc(
            f"UnmarshalJSON is `fromWire` with the document already split. Every "
            f"class gets one so a slot -- or any `json.Unmarshal` of a struct that "
            f"holds one -- reaches the same decoder the hierarchy dispatcher does."
        )
        out.append(f"func (c *{cm.name}) UnmarshalJSON(b []byte) error {{")
        out.append("\tvar d map[string]json.RawMessage")
        out.append("\tif err := json.Unmarshal(b, &d); err != nil {")
        out.append("\t\treturn err")
        out.append("\t}")
        out.append("\treturn c.fromWire(d)")
        out.append("}")
        out.append("")

        if cm.derived:
            attr, source = cm.derived
            out += go_doc(
                f"{attr} is the tag *inside* the verbatim payload. `{cm.name}` is itself "
                f"a `tag/content` document, so the outer `{cm.tag}` tag is already read "
                f"by the dispatcher and what is left under `{cm.content or 'value'}` is a "
                f"second one."
            )
            out.append(f"func (c {cm.name}) {attr}() string {{")
            out.append(f'\tif doc, ok := c.{self._exported(source)}["type"].(map[string]any); ok {{')
            out.append('\t\tif tag, ok := doc["type"].(string); ok {')
            out.append("\t\t\treturn tag")
            out.append("\t\t}")
            out.append("\t}")
            out.append('\treturn ""')
            out.append("}")
            out.append("")
        return out

    def _emit_compact(self, cm: ClassModel) -> List[str]:
        """The tagged value that is not a hierarchy: a `kind` beside a payload.

        The tag is `kind` on the Go side and `type` on the wire -- nothing above
        it dispatches, so the class has to carry the tag itself rather than
        inherit one.
        """
        kind, value = self._exported(cm.fields[0].name), self._exported(cm.fields[1].name)
        content = cm.content or "value"
        out: List[str] = []
        out += go_doc(narrative.CLASS_DOCS.get(cm.rust_name) or cm.rust_doc)
        out.append(f"type {cm.name} struct {{")
        out.append(f'\t{kind} string `json:"{cm.tag},omitempty"`')
        if cm.kind == KIND_COMPACT_NODE:
            # Rust is `enum MemberOrIndex { Member(NodeRef<String>), Index(NodeRef<Expr>) }`
            # -- two variants holding differently-typed nodes. One field cannot
            # hold both, and an `any` would keep the document without decoding
            # it, which is the one thing this package exists not to do. So each
            # variant gets its own field, and `Kind` says which one is live.
            for tag, payload in sorted(cm.payload_loaders.items()):
                out.append(f"\t{tag} *{self._slot_name(payload)} `json:\"-\"`")
        else:
            out.append(f"\t{value} any `json:\"{content},omitempty\"`")
        out.append("}")
        out.append("")
        out.append(f"func (c {cm.name}) MarshalJSON() ([]byte, error) {{")
        if cm.kind == KIND_COMPACT_NODE:
            out.append("\tpayload := any(nil)")
            out.append(f"\tswitch c.{kind} {{")
            for tag in sorted(cm.payload_loaders):
                out += [f'\tcase "{tag}":', f"\t\tpayload = c.{tag}"]
            out += ["\t}", "\treturn json.Marshal(map[string]any{",
                    f'\t\t"{cm.tag}": c.{kind},', f'\t\t"{content}": payload,', "\t})",
                    "}"]
        else:
            out += ["\treturn json.Marshal(map[string]any{",
                    f'\t\t"{cm.tag}": c.{kind},', f'\t\t"{content}": c.{value},', "\t})",
                    "}"]
        out.append("")
        out += go_doc(
            f"Read `{cm.name}`. The payload's decoder differs per variant -- "
            f"{' and '.join(sorted(cm.payload_loaders)) if cm.payload_loaders else 'the payload is kept whole'} "
            f"-- so the tag is read before the payload."
        )
        out.append(f"func (c *{cm.name}) fromWire(d map[string]json.RawMessage) error {{")
        out.append(f'\tif err := json.Unmarshal(d["{cm.tag}"], &c.{kind}); err != nil {{')
        out.append("\t\treturn err")
        out.append("\t}")
        if cm.kind == KIND_COMPACT_NODE:
            out.append(f"\tswitch c.{kind} {{")
            for tag, payload in sorted(cm.payload_loaders.items()):
                slot = self._slot_name(payload)
                out += [
                    f'\tcase "{tag}":',
                    f"\t\tvar v {slot}",
                    f'\t\tif err := json.Unmarshal(d["{content}"], &v); err != nil {{',
                    "\t\t\treturn err",
                    "\t\t}",
                    f"\t\tc.{tag} = &v",
                    "\t\treturn nil",
                ]
            out += [
                "\t}",
                f'\treturn fmt.Errorf("unknown {cm.name} type: %s", c.{kind})',
            ]
            # Every arm returns, so the error return below is the only way out
            # of the function and there is no trailing `return nil` to reach.
            out.append("}")
            out.append("")
            out += self._compact_unmarshal(cm)
            return out
        out.append(f'\tc.{value} = readJSON(d["{content}"])')
        out.append("\treturn nil")
        out.append("}")
        out.append("")
        out += self._compact_unmarshal(cm)
        return out

    @staticmethod
    def _compact_unmarshal(cm: ClassModel) -> List[str]:
        """`UnmarshalJSON` for a compact class, which has no fields to declare it.

        A `fromWire` on its own is not reachable: a field typed `[]MemberOrIndex`
        or `any` is decoded by `encoding/json`, which only calls `UnmarshalJSON`
        and otherwise falls back to matching keys against *struct tags*. Every
        payload field here is `json:"-"` -- `MarshalJSON` places it itself -- so
        the fallback silently drops the whole payload and the object round-trips
        as a bare `{"type": "Member"}`.
        """
        out = go_doc(
            f"UnmarshalJSON is `fromWire` with the document already split. The "
            f"payload fields are `json:\"-\"` because `MarshalJSON` places them, so "
            f"this method is the only thing that reads them back in: without it a "
            f"`[]{cm.name}` field decodes to a row of tags with no payload."
        )
        out.append(f"func (c *{cm.name}) UnmarshalJSON(b []byte) error {{")
        out.append("\tvar d map[string]json.RawMessage")
        out.append("\tif err := json.Unmarshal(b, &d); err != nil {")
        out.append("\t\treturn err")
        out.append("\t}")
        out.append("\treturn c.fromWire(d)")
        out.append("}")
        out.append("")
        return out

    def _emit_root(self, root: str, cm: ClassModel) -> List[str]:
        tag = cm.tag or "type"
        variants = [self.m.variants[f"{root}::{v}"] for v in cm.variants]
        out: List[str] = []

        out += go_doc(
            f"`{root}` is one variant of the {root} hierarchy. It is a marker "
            f"interface rather than one with accessors: the classes are exported "
            f"structs, so a caller type-switches on the concrete type, and Go has no "
            f"equivalent of Python's `isinstance` over a generated variant table. The "
            f"marker is unexported so the union cannot be implemented outside this "
            f"package -- which is what makes the dispatcher's table exhaustive."
        )
        out.append(f"type {root} interface {{")
        out.append(f"\t{root.lower()}Node()")
        out.append("}")
        out.append("")

        out += go_doc(
            f"Read a `{root}` off the wire. `{tag}` is the discriminator every variant "
            f"carries, so the dispatch is a lookup rather than a guess."
        )
        out.append(f"func {root.lower()}FromWire(raw json.RawMessage) ({root}, error) {{")
        out.append("\tvar d map[string]json.RawMessage")
        out.append("\tif err := json.Unmarshal(raw, &d); err != nil {")
        out.append("\t\treturn nil, err")
        out.append("\t}")
        # The tag is read off the same document the payload comes from rather
        # than through a second struct, so the two can never disagree about
        # which variant this is.
        out.append(f'\tvar tag string')
        out.append(f'\tif err := json.Unmarshal(d["{tag}"], &tag); err != nil {{')
        out.append("\t\treturn nil, err")
        out.append("\t}")
        out.append("\tswitch tag {")
        for v in variants:
            out.append(f'\tcase "{v.tag}":')
            out.append(f"\t\tvar c {v.name}")
            out.append("\t\tif err := c.fromWire(d); err != nil {")
            out.append("\t\t\treturn nil, err")
            out.append("\t\t}")
            out.append("\t\treturn &c, nil")
        out.append("\t}")
        out.append(f'\treturn nil, fmt.Errorf("unknown {root} type: %s", tag)')
        out.append("}")
        out.append("")

        out += go_doc(
            "One line per variant: the unexported marker the interface needs, and a "
            "pointer receiver so the dispatcher can return the address it decoded "
            "into. Generated rather than written because a variant that is missing one "
            "is a compile error at the interface -- the compiler checks this part, and "
            "the field lists in the same file check the rest."
        )
        for v in variants:
            out += [
                f"func (*{v.name}) {root.lower()}Node() {{}}",
                "",
            ]
        return out

    # --- files -----------------------------------------------------------

    def emit(self, name: str) -> str:
        body = (
            self._base() if name == "base_gen.go"
            else self._op() if name == "op_gen.go"
            else self._nodes() if name == "nodes_gen.go"
            else self._emit_class(self.m.classes["Module"]) if name == "module_gen.go"
            else self._classes(name)
        )
        text = "\n".join(body)
        # `fmt` is imported only where a dispatcher names the type it could not
        # read; an unused import is a compile error in Go, and a blank use to
        # keep the compiler quiet would hide exactly that.
        imports = []
        if "json." in text:
            imports.append("\t\"encoding/json\"")
        if "fmt." in text:
            imports.append("\t\"fmt\"")
        header = [
            "// Code generated by tools/generate_ast.py from",
            # The path is the repo-relative spelling, not the absolute path of
            # whoever ran the generator: the freshness check regenerates on
            # the CI machine (a different absolute path) and an absolute path
            # here would diff on every run. The TypeScript emitter makes the
            # same choice.
            f"// kcl-lang/kcl/crates/ast/src/ast.rs (sha256:{self.m.source_sha}).",
            "// DO NOT EDIT BY HAND — run `python3 tools/generate_ast.py` and commit the",
            "// result, or `ruby hack/check_generated_ast.rb` will fail.",
            "//",
            "// Every struct, field, wire tag and operator below is derived from the Rust",
            "// source. See tools/astgen/emit_go.py for the shapes and why they are so.",
            "",
            "package ast",
            "",
            *(["import (", *imports, ")", ""] if imports else []),
        ]
        return "\n".join(header + body).rstrip() + "\n"

    def _classes(self, file_name: str) -> List[str]:
        module = next(m for m, f in _MODULE_TO_FILE.items() if f == file_name)
        out: List[str] = []
        for key in sorted(self.m.classes):
            cm = self.m.classes[key]
            if cm.module != module or cm.kind == "node_wrapper":
                continue
            if cm.kind in ("compact_node", "compact_value"):
                out += self._emit_compact(cm)
            else:
                out += self._emit_class(cm)
        for root in self.m.roots:
            if self.m.enums[root].module == module:
                out += self._emit_root(root, self.m.enums[root])
        return out

    def _op(self) -> List[str]:
        out = go_doc(
            "The operator vocabularies.\n\n"
            "Each is a Rust enum with no `#[serde]` attribute at all, so serde tags it "
            "externally, every variant is a unit variant, and the value on the wire is "
            "a bare JSON string -- `BinOp::Add` is `\"Add\"`, not `{\"Add\": null}`. A "
            "named `string` is therefore the whole decoder."
        )
        for name in sorted(self._op_enums):
            cm = self._op_enums[name]
            out += [
                f"type {name} string",
                "",
                f"// The {len(cm.variants)} variants of `{name}`.",
                "const (",
            ]
            out += [f'\t{name}{v} {name} = "{v}"' for v in cm.variants]
            out += [")", ""]
        return out

    def _nodes(self) -> List[str]:
        out = go_doc(
            "One slot type per `NodeRef` payload.\n\n"
            "`ast::Node<T>` is generic and so is `Node[T]`, but a generic *method* "
            "cannot dispatch on `T`, and something has to name the union a payload came "
            "from. The alternatives are both worse: try every dispatcher in turn and "
            "take the first that type-asserts -- which is what the kcl-go binding does, "
            "and which yields a zero node whenever a dispatcher succeeds against the "
            "wrong union -- or hand-roll a decoder per field.\n\n"
            "So the slot is spelled out. `ExprNode` embeds `Node[Expr]` and supplies the "
            "one `UnmarshalJSON` that calls `exprFromWire`; `StringNode` knows a "
            "`NodeRef<String>` carries a bare string under `node` and no tag at all. A "
            "field's declared type names its slot, so the mapping sits in the struct "
            "declaration where the compiler checks it."
        )
        for payload in sorted(self.slots):
            slot = self.slots[payload]
            go_payload = self._slot_payload(slot)
            out += [
                f"// {slot} is a `NodeRef<{payload}>`.",
                f"type {slot} struct {{",
                f"\tNode[{go_payload}]",
                "}",
                "",
                "// UnmarshalJSON reads the wrapper, then dispatches the payload.",
                f"func (n *{slot}) UnmarshalJSON(b []byte) error {{",
                "\tif err := n.Node.UnmarshalJSON(b); err != nil {",
                "\t\treturn err",
                "\t}",
                "\tvar aux struct {",
                '\t\tPayload json.RawMessage `json:"node"`',
                "\t}",
                "\tif err := json.Unmarshal(b, &aux); err != nil {",
                "\t\treturn err",
                "\t}",
            ]
            if payload == "String":
                out += [
                    "\t// A `NodeRef<String>` carries a bare string and no tag.",
                    "\treturn json.Unmarshal(aux.Payload, &n.Payload)",
                ]
            elif payload in self.m.roots:
                out += [
                    f"\tv, err := {payload.lower()}FromWire(aux.Payload)",
                    "\tif err != nil {",
                    "\t\treturn err",
                    "\t}",
                    "\tn.Payload = v",
                    "\treturn nil",
                ]
            else:
                # Not a hierarchy, so there is no dispatcher to call -- the
                # payload is one class and its own `UnmarshalJSON` reads it.
                out += [
                    f"\tvar v {go_payload}",
                    "\tif err := json.Unmarshal(aux.Payload, &v); err != nil {",
                    "\t\treturn err",
                    "\t}",
                    "\tn.Payload = v",
                    "\treturn nil",
                ]
            out += ["}", ""]
        return out

    def _base(self) -> List[str]:
        out = go_doc(
            "`Pos` is `ast::Pos`: the (filename, line, column, end_line, end_column)\n"
            "tuple every `NodeRef` carries. Rust declares it as a tuple struct and serde\n"
            "inlines its five members into the wrapper, so here it is an embedded struct\n"
            "with no key of its own."
        )
        out += [
            "type Pos struct {",
            # No `omitempty` on any of the five: serde writes them
            # unconditionally, and the capture really does carry
            # `"column": 0` for the node that starts at the beginning of a line
            # and `"filename": ""` for the synthesised `NodeRef`s inside a
            # joined string. Dropping either key would be a difference the
            # comparator would have to be told about rather than one it would
            # catch.
            '\tFilename  string `json:"filename"`',
            '\tLine      int64  `json:"line"`',
            '\tColumn    int64  `json:"column"`',
            '\tEndLine   int64  `json:"end_line"`',
            '\tEndColumn int64  `json:"end_column"`',
            "}",
            "",
        ]
        out += go_doc(
            "`Node[T]` mirrors `ast::Node<T>`. Its wire keys come from a hand-written\n"
            "`Serialize` impl rather than a derive: `node`, the five position members, and\n"
            "`id` only when the AST-index serialiser is switched on. `id` is\n"
            "`skip_deserializing`, so it is read back when present and absent when not."
        )
        out += [
            "type Node[T any] struct {",
            '\tID      any `json:"id,omitempty"`',
            '\tPayload T   `json:"node"`',
            "\tPos",
            "}",
            "",
        ]
        out += go_doc(
            "Read the wrapper. The payload is deliberately left alone -- the slot types\n"
            "embed this and supply the `UnmarshalJSON` that knows their union."
        )
        out += [
            "func (n *Node[T]) UnmarshalJSON(b []byte) error {",
            "\tvar aux struct {",
            '\t\tID      any `json:"id"`',
            "\t\tPos",
            "\t}",
            "\tif err := json.Unmarshal(b, &aux); err != nil {",
            "\t\treturn err",
            "\t}",
            "\tn.ID = aux.ID",
            "\tn.Pos = aux.Pos",
            "\treturn nil",
            "}",
            "",
        ]
        out += go_doc(
            "A comment captured during parsing.\n\n"
            "Rust's `Comment` is a plain struct with a single `String` field, so serde\n"
            "nests it as `{\"node\": {\"text\": \"…\"}, \"line\": 1, …}` -- the object under\n"
            "`node` is an object, not the bare text. Reading it as the text itself yields\n"
            "`\"\"` for every comment in the file without raising, which is why the\n"
            "round-trip looks fine and the content does not."
        )
        out += [
            "type Comment struct {",
            '\tText string `json:"text"`',
            "}",
            "",
            "func (c *Comment) fromWire(d map[string]json.RawMessage) error {",
            '\treturn json.Unmarshal(d["text"], &c.Text)',
            "}",
            "",
        ]
        out += go_doc("Read a `Module` from the `ast_json` on `ParseFileResult`.")
        out += [
            "func ParseModule(astJSON string) (*Module, error) {",
            "\tvar m Module",
            "\tif err := json.Unmarshal([]byte(astJSON), &m); err != nil {",
            "\t\treturn nil, err",
            "\t}",
            "\treturn &m, nil",
            "}",
            "",
        ]
        out += go_doc(
            "Read the program document -- one `Module` per file.\n\n"
            "`ParseProgram` flattens `pkgs.__main__`, the shape every other binding\n"
            "exposes and what `ParseProgramResult.ast_json` carries."
        )
        out += [
            "func ParseProgram(programJSON string) ([]*Module, error) {",
            "\tvar doc struct {",
            "\t\tPkgs map[string][]*Module `json:\"pkgs\"`",
            "\t}",
            "\tif err := json.Unmarshal([]byte(programJSON), &doc); err == nil && doc.Pkgs != nil {",
            "\t\tif main, ok := doc.Pkgs[\"__main__\"]; ok {",
            "\t\t\treturn main, nil",
            "\t\t}",
            "\t\t// An empty program has no `__main__` at all.",
            "\t\treturn nil, nil",
            "\t}",
            "\t// A bare list of modules, and a bare single module, are both accepted.",
            "\tvar list []*Module",
            "\tif err := json.Unmarshal([]byte(programJSON), &list); err == nil {",
            "\t\treturn list, nil",
            "\t}",
            "\tvar m Module",
            "\tif err := json.Unmarshal([]byte(programJSON), &m); err != nil {",
            "\t\treturn nil, err",
            "\t}",
            "\treturn []*Module{&m}, nil",
            "}",
            "",
        ]
        return out
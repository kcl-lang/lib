"""Parse ``crates/ast/src/ast.rs`` into :mod:`astgen.ir` items.

This is a line-oriented parser for rustfmt'd Rust, not a Rust parser. It is
only allowed to be correct on input it fully understands, so every construct it
does not recognise raises :class:`AstParseError` with the file and line rather
than being skipped. A parser that quietly ignores a line produces a generator
that quietly omits a type, which is the one failure mode a code generator for a
*source of truth* cannot have: it would reintroduce exactly the drift the
generator exists to remove, and this time invisibly.

Three shapes are recognised and nothing else:

* ``pub struct Name<G> { pub field: Type, ... }``  -- also the unit (``;``) and
  tuple (``(A, B);``) forms, which carry no fields.
* ``pub enum Name { Variant, Variant(T), Variant { .. } }``
* ``pub type Name<G> = Type;``

A top-level item is closed by a ``}`` in column 0, which is what rustfmt emits
for every item at the top level of a module. ``impl`` blocks also close that
way, so the scanner only enters a body after matching ``pub struct`` /
``pub enum`` in column 0 and rejects anything that turns out not to be one.
"""

from __future__ import annotations

import hashlib
import re
from typing import Dict, List, Optional, Tuple

from .ir import RustCrate, RustField, RustItem, RustTypeRef, RustVariant


class AstParseError(RuntimeError):
    """Raised when the source contains something this parser does not model."""


# --- type expressions ---------------------------------------------------

# A type head is an identifier or a path (`schema::Node`, `uuid::Uuid`).
_TYPE_TOKEN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)*")
_SCALARS = {
    "String",
    "str",
    "bool",
    "i8", "i16", "i32", "i64", "i128", "isize",
    "u8", "u16", "u32", "u64", "u128", "usize",
    "f32", "f64",
    "usize_",
    "char",
    "Box",
    "HashMap",
    "HashSet",
    "BTreeMap",
    "Result",
    "Option",
    "Vec",
    "PhantomData",
    "Rc",
    "Arc",
}


def parse_type_ref(text: str, where: str) -> RustTypeRef:
    """Parse one Rust type expression into a :class:`RustTypeRef`.

    ``Vec<Option<NodeRef<Expr>>>`` -> ``Vec< Option< NodeRef< Expr > > >``.  The
    grammar is small and closed: an identifier, optionally followed by a
    comma-separated argument list. Anything else is an error, because a
    mis-parse here turns into a wrong field type in every binding.
    """
    text = text.strip()
    if not text:
        raise AstParseError(f"{where}: empty type")
    m = _TYPE_TOKEN.match(text)
    if not m:
        raise AstParseError(f"{where}: cannot read a type from {text!r}")
    name = m.group(0)
    rest = text[m.end():].strip()
    if not rest:
        return RustTypeRef(name)
    if not rest.startswith("<"):
        raise AstParseError(f"{where}: trailing junk {rest!r} after {name!r}")
    args, end = _split_args(text, m.end(), where)
    if text[end:].strip():
        raise AstParseError(f"{where}: trailing junk {text[end:]!r} after {name}<..>")
    return RustTypeRef(name, tuple(args))


def _split_args(text: str, start: int, where: str) -> Tuple[List[RustTypeRef], int]:
    """Parse ``<A, B<C>>`` starting at ``text[start] == '<'``."""
    assert text[start] == "<"
    i = start + 1
    args: List[RustTypeRef] = []
    depth = 0
    current = []
    while i < len(text):
        ch = text[i]
        if ch == "<":
            depth += 1
            current.append(ch)
        elif ch == ">":
            if depth == 0:
                args.append(parse_type_ref("".join(current), where))
                return args, i + 1
            depth -= 1
            current.append(ch)
        elif ch == "," and depth == 0:
            args.append(parse_type_ref("".join(current), where))
            current = []
        elif ch in "()[]&'" and depth == 0:
            raise AstParseError(f"{where}: unsupported type syntax {text[start:]!r}")
        else:
            current.append(ch)
        i += 1
    raise AstParseError(f"{where}: unterminated type arguments in {text[start:]!r}")


# --- attributes ---------------------------------------------------------

_ATTR_OPEN = "#["


def parse_attributes(lines: List[str], start: int) -> Tuple[List[Dict[str, object]], int]:
    """Consume consecutive ``#[...]`` attributes and doc comments.

    Returns the parsed attributes and the index of the first line that is not
    one. Doc comments come back as the pseudo-attribute ``{"doc": "..."}`` so
    that a single list describes everything that was attached to an item.
    """
    out: List[Dict[str, object]] = []
    i = start
    while i < len(lines):
        raw = lines[i]
        stripped = raw.strip()
        if stripped.startswith("///"):
            out.append({"doc": stripped[3:].strip()})
            i += 1
            continue
        if stripped.startswith("//!") or stripped.startswith("//") or not stripped:
            i += 1
            continue
        if not stripped.startswith(_ATTR_OPEN):
            break
        # Attributes may be wrapped by rustfmt; join until the brackets balance.
        buf = stripped
        while buf.count("[") != buf.count("]") and i + 1 < len(lines):
            i += 1
            buf += " " + lines[i].strip()
        out.append(_parse_one_attr(buf, i + 1))
        i += 1
    return out, i


def _parse_one_attr(text: str, line: int) -> Dict[str, object]:
    body = text.strip()
    if not body.startswith(_ATTR_OPEN) or not body.endswith("]"):
        raise AstParseError(f"line {line}: cannot read attribute from {text!r}")
    body = body[2:-1].strip()
    if not body:
        raise AstParseError(f"line {line}: empty attribute")
    m = re.match(r"^([A-Za-z_][A-Za-z0-9_:]*)", body)
    if not m:
        raise AstParseError(f"line {line}: cannot read an attribute name from {text!r}")
    name = m.group(1)
    rest = body[m.end():].strip()
    if not rest:
        return {"name": name, "args": {}}
    if not (rest.startswith("(") and rest.endswith(")")):
        raise AstParseError(f"line {line}: attribute {name} has an unparsed body {rest!r}")
    inner = rest[1:-1]
    args: Dict[str, object] = {}
    for part in _split_top_level(inner, line):
        part = part.strip()
        if not part:
            continue
        if "=" in part:
            key, _, value = part.partition("=")
            key = key.strip()
            value = value.strip()
            if value.startswith('"') and value.endswith('"') and len(value) >= 2:
                args[key] = value[1:-1]
            else:
                args[key] = value
        else:
            args[part] = True
    return {"name": name, "args": args}


def _split_top_level(text: str, line: int) -> List[str]:
    out: List[str] = []
    depth = 0
    current: List[str] = []
    for ch in text:
        if ch in "(<[":
            depth += 1
        elif ch in ")>]":
            depth -= 1
            if depth < 0:
                raise AstParseError(f"line {line}: unbalanced delimiters in {text!r}")
        if ch == "," and depth == 0:
            out.append("".join(current))
            current = []
        else:
            current.append(ch)
    if depth != 0:
        raise AstParseError(f"line {line}: unbalanced delimiters in {text!r}")
    out.append("".join(current))
    return out


# --- items --------------------------------------------------------------

_ITEM = re.compile(r"^pub (struct|enum|type)\b")
_ATTACHMENT = re.compile(r"^(#\[|///|//!)")


def _attr_block_start(lines: List[str], index: int) -> int:
    """Walk back over the attributes and doc comments attached to an item.

    An item's ``#[serde(...)]`` line is the one that decides whether it is
    internally tagged, adjacently tagged or a bare string on the wire, so
    reading the item without it is the single worst way for this parser to be
    wrong. The scan stops at the first line that is not an attribute or a doc
    comment, which is a blank line, the previous item's ``}``, or an ``impl``.
    """
    start = index
    while start > 0 and _ATTACHMENT.match(lines[start - 1].strip()):
        start -= 1
    return start


def parse_crate(path: str) -> RustCrate:
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()
    return parse_source(text, path)


def parse_source(text: str, path: str = "<source>") -> RustCrate:
    lines = text.split("\n")
    items: Dict[str, RustItem] = {}
    i = 0
    while i < len(lines):
        m = _ITEM.match(lines[i])
        if not m:
            i += 1
            continue
        attrs, start = parse_attributes(lines, _attr_block_start(lines, i))
        item, i = _parse_item(lines, i, m.group(1), path, attrs)
        if item.name in items:
            raise AstParseError(
                f"{path}:{item.line}: {item.name!r} is declared twice; the generator "
                "cannot tell which declaration a field belongs to"
            )
        items[item.name] = item

    _assert_nothing_was_skipped(text, items, path)
    return RustCrate(
        items=items,
        source_path=path,
        source_sha=hashlib.sha256(text.encode("utf-8")).hexdigest(),
        item_count=len(items),
    )


def _assert_nothing_was_skipped(text: str, items: Dict[str, RustItem], path: str) -> None:
    """Count the items the source declares and insist the parser found them all.

    This is the guard against the parser quietly losing a declaration: the two
    counts are computed by independent means, and a mismatch names the line.
    """
    expected_structs = re.findall(r"^pub struct (\w+)", text, re.M)
    expected_enums = re.findall(r"^pub enum (\w+)", text, re.M)
    expected_aliases = re.findall(r"^pub type (\w+)", text, re.M)
    got = {name: item for name, item in items.items()}
    for kind, names in (
        ("struct", expected_structs),
        ("enum", expected_enums),
        ("type alias", expected_aliases),
    ):
        for name in names:
            item = got.get(name)
            if item is None:
                raise AstParseError(
                    f"{path}: `pub {kind} {name}` was declared but the parser did not "
                    "recover it; refusing to generate from a partial model"
                )
            if item.kind != {"struct": "struct", "enum": "enum", "type alias": "alias"}[kind]:
                raise AstParseError(
                    f"{path}: `pub {kind} {name}` was parsed as a {item.kind}"
                )


def _parse_item(
    lines: List[str],
    start: int,
    kind: str,
    path: str,
    attrs: Optional[List[Dict[str, object]]] = None,
) -> Tuple[RustItem, int]:
    header = strip_line_comment(lines[start])
    line_no = start + 1
    if kind == "type":
        return _parse_alias(lines, start, path)
    m = re.match(r"^pub (struct|enum) ([A-Za-z_][A-Za-z0-9_]*)", header)
    if not m:
        raise AstParseError(f"{path}:{line_no}: cannot read an item header from {header!r}")
    name = m.group(2)
    rest = header[m.end():].strip()
    generics: List[str] = []
    if rest.startswith("<"):
        args, end = _split_generics(rest, path, line_no)
        generics = args
        rest = rest[end:].strip()
    attrs = attrs or []
    item = RustItem(
        name=name,
        kind=kind,
        generics=generics,
        serde=_serde_args(attrs),
        doc=" ".join(str(a["doc"]) for a in attrs if "doc" in a).strip(),
        line=line_no,
    )

    if rest == ";" or (rest.startswith("(") and rest.endswith(");")):
        # Unit struct (`pub struct MissingExpr;`) or a tuple struct
        # (`pub struct Pos(String, u64, u64, u64, u64);`). Neither has public
        # fields, so neither is on the AST wire and there is nothing to record
        # beyond the name -- but the form is validated so a broken header is not
        # accepted, and a tuple struct is remembered as one so the model can say
        # why it is skipped instead of just dropping it.
        if rest.startswith("("):
            item.variants = [
                RustVariant(name=field, kind="tuple", line=line_no)
                for field in [p.strip() for p in _split_top_level(rest[1:-2], line_no)]
            ]
        return item, start + 1

    if rest != "{":
        raise AstParseError(
            f"{path}:{line_no}: expected `{{` after `pub {kind} {name}`, got {rest!r}"
        )

    body, i = _collect_body(lines, start + 1, path, line_no)
    if kind == "struct":
        item.fields = _parse_fields(body, path, line_no)
    else:
        item.variants = _parse_variants(body, path, line_no)
    item.manual_serialize = _has_manual_serialize(lines, i, name)
    return item, i


def _split_generics(rest: str, path: str, line_no: int) -> Tuple[List[str], int]:
    assert rest.startswith("<")
    i = 1
    depth = 0
    current: List[str] = []
    out: List[str] = []
    while i < len(rest):
        ch = rest[i]
        if ch == "<":
            depth += 1
            current.append(ch)
        elif ch == ">":
            if depth == 0:
                out.append("".join(current))
                return out, i + 1
            depth -= 1
            current.append(ch)
        elif ch == "," and depth == 0:
            out.append("".join(current))
            current = []
        else:
            current.append(ch)
        i += 1
    raise AstParseError(f"{path}:{line_no}: unterminated generics in {rest!r}")


def _collect_body(lines: List[str], start: int, path: str, line_no: int):
    """Collect lines up to the ``}`` that closes a top-level item."""
    body: List[str] = []
    i = start
    while i < len(lines):
        if lines[i] == "}":
            return body, i + 1
        body.append(lines[i])
        i += 1
    raise AstParseError(
        f"{path}:{line_no}: the item opened on this line is never closed; every "
        "struct and enum body in ast.rs ends with a `}` in column 0"
    )


def _has_manual_serialize(lines: List[str], end: int, name: str) -> bool:
    """True when the item is followed by a hand-written ``Serialize`` impl.

    Such a type's wire shape is not described by its ``#[serde(...)]``
    attributes, because it has none: ``Node<T>`` derives only ``Deserialize``
    and spells its six (or seven, with ``id``) output keys out inside
    ``impl<T: Serialize> Serialize for Node<T>``. rustfmt puts that impl
    directly after the struct, so scanning forward to the first ``impl`` is
    enough -- and a type that has one is flagged rather than silently decoded
    from attributes it does not carry.
    """
    i = end
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("impl"):
            return "Serialize" in line and f"for {name}" in line
        if line == "" or _ITEM.match(line) or line.startswith("///") or line.startswith("#[") or line.startswith("//!"):
            i += 1
            continue
        return False
    return False


_FIELD = re.compile(r"^pub ([A-Za-z_][A-Za-z0-9_]*): (.+)$")
_NON_FIELD = re.compile(r"^(\s*)(#\[|///|//!|//|$)")


def _parse_fields(body: List[str], path: str, line_no: int) -> List[RustField]:
    fields: List[RustField] = []
    attrs, i = parse_attributes(body, 0)
    pending = attrs
    while i < len(body):
        line = strip_line_comment(body[i])
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("#[") or stripped.startswith("///"):
            more, i = parse_attributes(body, i) if stripped.startswith("#") or stripped.startswith("///") else ([], i + 1)
            pending += more
            continue
        m = _FIELD.match(line.strip())
        if not m:
            raise AstParseError(
                f"{path}:{line_no + i + 1}: cannot read a struct field from {line!r}. "
                "A field must be `pub name: Type,`"
            )
        name = m.group(1)
        rendered = m.group(2).strip()
        if not rendered.endswith(","):
            raise AstParseError(
                f"{path}:{line_no + i + 1}: field {name!r} does not end in a comma: {line!r}"
            )
        ftype = parse_type_ref(rendered[:-1], f"{path}:{line_no + i + 1}")
        doc = " ".join(str(a["doc"]) for a in pending if "doc" in a).strip()
        fields.append(
            RustField(
                name=name,
                type=ftype,
                attrs=_serde_args(pending),
                doc=doc,
                line=line_no + i + 1,
            )
        )
        pending = []
        i += 1
    return fields


_VARIANT_TUPLE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\((.*)\)(,?)$")
_VARIANT_UNIT = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)(,?)$")
_VARIANT_STRUCT = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*\{$")


def _parse_variants(body: List[str], path: str, line_no: int) -> List[RustVariant]:
    variants: List[RustVariant] = []
    pending, i = parse_attributes(body, 0)
    depth = 0
    while i < len(body):
        line = strip_line_comment(body[i])
        stripped = line.strip()
        if depth > 0:
            # Inside a `Variant { .. }` or `Variant(..) { .. }` body: skip to the
            # matching close. `Missing(MissingExpr)` has no body, but a variant
            # with named fields would, and its fields are not part of the wire
            # shape this generator models (no such variant exists in ast.rs --
            # `_assert_no_struct_variants` below keeps that honest).
            depth += line.count("{") - line.count("}")
            if depth < 0:
                depth = 0
            i += 1
            continue
        if not stripped or stripped.startswith("//"):
            more, i = parse_attributes(body, i) if stripped.startswith("///") else ([], i + 1)
            pending += more
            continue
        if stripped.startswith("#["):
            more, i = parse_attributes(body, i)
            pending += more
            continue
        if stripped in ("}", "},"):
            i += 1
            continue
        m = _VARIANT_STRUCT.match(stripped)
        if m:
            raise AstParseError(
                f"{path}:{line_no + i + 1}: enum variant {m.group(1)!r} has a named-field "
                "body. ast.rs has no such variant and the generator does not model one."
            )
        m = _VARIANT_TUPLE.match(stripped)
        if m and m.group(2).strip():
            name = m.group(1)
            types = [
                parse_type_ref(p, f"{path}:{line_no + i + 1}")
                for p in _split_top_level(m.group(2), line_no + i + 1)
                if p.strip()
            ]
            doc = " ".join(str(a["doc"]) for a in pending if "doc" in a).strip()
            variants.append(
                RustVariant(
                    name=name,
                    kind="tuple",
                    types=types,
                    attrs=_serde_args(pending),
                    doc=doc,
                    line=line_no + i + 1,
                )
            )
            pending = []
            i += 1
            continue
        m = _VARIANT_UNIT.match(stripped)
        if m:
            doc = " ".join(str(a["doc"]) for a in pending if "doc" in a).strip()
            variants.append(
                RustVariant(
                    name=m.group(1),
                    kind="unit",
                    attrs=_serde_args(pending),
                    doc=doc,
                    line=line_no + i + 1,
                )
            )
            pending = []
            i += 1
            continue
        raise AstParseError(
            f"{path}:{line_no + i + 1}: cannot read an enum variant from {line!r}"
        )
    return variants


def _serde_args(attrs: List[Dict[str, object]]) -> Dict[str, object]:
    out: Dict[str, object] = {}
    for a in attrs:
        if a.get("name") == "serde":
            for key, value in a["args"].items():  # type: ignore[union-attr]
                out[key] = value
    return out


def strip_line_comment(line: str) -> str:
    """Drop a trailing ``// ...`` comment, leaving the code before it.

    ``LiteralType::Int(IntLiteralType) // value + suffix`` is the only place
    ast.rs puts one on a declaration line. The quote scan is here so a ``//``
    inside a string literal is not mistaken for the start of a comment; the
    declarations parsed here contain no such literal today, but silently
    truncating one would be the kind of quiet mis-parse this module refuses to
    make.
    """
    in_str = False
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == "\\" and in_str:
            i += 2
            continue
        if ch == '"':
            in_str = not in_str
        elif ch == "/" and not in_str and line[i + 1: i + 2] == "/":
            return line[:i]
        i += 1
    return line


def _parse_alias(lines: List[str], start: int, path: str) -> Tuple[RustItem, int]:
    buf = strip_line_comment(lines[start]).strip()
    i = start
    while buf.count("<") != buf.count(">") or not buf.rstrip().endswith(";"):
        i += 1
        if i >= len(lines):
            raise AstParseError(f"{path}:{start + 1}: unterminated `pub type`")
        buf += " " + strip_line_comment(lines[i]).strip()
    m = re.match(r"^pub type ([A-Za-z_][A-Za-z0-9_]*)", buf)
    if not m:
        raise AstParseError(f"{path}:{start + 1}: cannot read a type alias from {lines[start]!r}")
    name = m.group(1)
    rest = buf[m.end():].strip()
    generics: List[str] = []
    if rest.startswith("<"):
        generics, end = _split_generics(rest, path, start + 1)
        rest = rest[end:].strip()
    if not rest.startswith("="):
        raise AstParseError(f"{path}:{start + 1}: expected `=` in `pub type {name}`")
    target_text = rest[1:].strip()
    if not target_text.endswith(";"):
        raise AstParseError(f"{path}:{start + 1}: `pub type {name}` does not end in `;`")
    target_text = target_text[:-1].strip()
    if target_text.startswith("(") and target_text.endswith(")"):
        # `PosTuple = (String, u64, ...)` is a tuple type, not a path. It is not
        # an AST node and nothing references it, so it is recorded as an opaque
        # head rather than parsed.
        target_text = "PosTupleTuple"
    item = RustItem(
        name=name,
        kind="alias",
        generics=generics,
        alias_target=parse_type_ref(target_text, f"{path}:{start + 1}"),
        line=start + 1,
    )
    return item, i + 1


def is_known_head(name: str) -> bool:
    return name in _SCALARS or name[0].isupper() or "_" in name.split("::")[-1]


__all__ = [
    "AstParseError",
    "parse_crate",
    "parse_source",
    "parse_type_ref",
    "is_known_head",
]

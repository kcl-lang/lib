"""Emit the PHP binding's typed AST package.

Modelled on :mod:`astgen.emit_go`. The Go output is the reference for what the
wire looks like; this file's job is the same job in a language whose shapes
differ, not to restate it.

Five things PHP does differently, and why each is written the way it is:

**One namespace, one file per class.** PHP has no import cycles to break —
everything lives in ``KclLib\\Ast`` — but PSR-4 wants one class per file named
after the class, so the module split the other generated bindings use becomes
one file per :class:`~astgen.model.ClassModel`. The emitter owns the whole
``php/src/Ast`` directory, support files (``Wire``, ``NodeRef``, ``Ast``) and
``AstBuild`` included, so the orphan half of the freshness check applies.

**The tag lives in the dispatcher, not the object.** PHP has no sum types and
no pattern matching over them, so ``Expr`` / ``Stmt`` / ``Type`` are abstract
base classes whose one static ``fromWire`` dispatches on the wire tag and
returns the variant; the variant classes are plain final classes a caller
type-checks with ``instanceof``. A payload struct that is *also* a variant
(``Identifier`` is both ``Expr::Identifier`` and ``Keyword.arg``'s target)
extends the base once and decodes the same fields in both positions — there is
no second field list to drift, which is exactly the model's ``shared`` kind.

**Decoding goes through one ``Wire`` helper per field shape.** PHP decodes
from ``json_decode`` arrays, not a typed tree, so every field shape maps to one
static helper — ``Wire::nodeRef`` for ``NodeRef<T>``, ``stringNode`` for
``NodeRef<String>``, ``optNodeRefList`` for ``Vec<Option<NodeRef<T>>>`` and so
on. The helpers are the single place the four shapes are told apart, and the
payload each one names is the same vocabulary :mod:`astgen.naming` derives for
``hack/check_ast_field_types.rb`` — a generated decoder counts as *checked*
rather than as an unresolved payload.

**Absent reads substitute, they never throw.** Every ``Wire`` helper answers a
missing or mistyped key with the value the Rust parser itself produces for an
unset field — ``null`` for an optional node, ``''`` for a string, ``[]`` for a
list, ``false`` for a ``skip_serializing_if`` bool — mirroring Kotlin's
``AstBuild.kt`` philosophy: a DTO whose fields are all required is mechanically
correct and ergonomically useless.

**Constructors are generated, not hand-written.** Kotlin's ``AstBuild.kt`` is
the reference form — one factory per node, every parameter defaulted to the
value the Rust parser produces — and a generated copy is the cheapest way to
keep it covering every field of every struct, which is what
``hack/check_ast_constructors.rb`` holds it to.
"""

from __future__ import annotations

from typing import Dict, List, Optional

from . import model as M
from . import narrative
from .model import AstModel, ClassModel, FieldModel

#: The AST package directory, relative to the repository root.
PHP_AST_DIR = "php/src/Ast"

#: Files the emitter always writes, beside the one-file-per-class output.
PHP_SUPPORT_FILES = ["Ast.php", "AstBuild.php", "NodeRef.php", "Wire.php"]


def _doc(text: str, indent: str = "") -> List[str]:
    """A doc comment wrapped to PHP's width, or nothing for an empty string."""
    text = (text or "").strip()
    if not text:
        return []
    out: List[str] = []
    for paragraph in text.split("\n\n"):
        flat = " ".join(line.strip() for line in paragraph.splitlines())
        lines: List[str] = []
        while len(flat) > 76 - len(indent) - 3:
            cut = flat.rfind(" ", 0, 76 - len(indent) - 3)
            if cut <= 0:
                cut = 76 - len(indent) - 3
            lines.append(flat[:cut])
            flat = flat[cut:].strip()
        lines.append(flat)
        if out:
            out.append(f"{indent} *")
        out.extend(f"{indent} * {line}".rstrip() for line in lines)
    return [f"{indent}/**", *out, f"{indent} */"]


class PhpEmitter:
    """Turn the shared :class:`~astgen.model.AstModel` into PHP source."""

    def __init__(self, model: AstModel) -> None:
        self.m = model
        # `BasicType` is in `model.enums` as a bare enum *and* is the payload
        # of `Type::Basic`, for which the model emits a class of the same name
        # holding the folded `name` field. Go drops the op enum there because
        # it has one flat namespace; PHP has one namespace too, so it makes
        # the same choice and for the same reason.
        emitted = {cm.rust_name for cm in model.classes.values()}
        self._op_enums = {
            n: c
            for n, c in model.enums.items()
            if c.kind == "op_enum" and n not in emitted
        }
        self._payload_words = self._collect_payload_words()

    # --- naming -----------------------------------------------------------

    @staticmethod
    def _prop(field: str) -> str:
        """`end_line` -> `endLine`. The wire name stays in the decoder call."""
        from .naming import camel_case

        return camel_case(field)

    @staticmethod
    def _method(name: str) -> str:
        """`SchemaExpr` -> `schemaExpr`, the AstBuild factory spelling."""
        return name[0].lower() + name[1:]

    # --- payload vocabulary -------------------------------------------------

    def _collect_payload_words(self) -> Dict[str, str]:
        """The payload word every decoder is registered under, for `Wire`.

        The same table :mod:`astgen.naming` builds for the shape checks:
        payload word -> the Rust type it decodes, so `Wire::payload` can map a
        word to the one decoder that reads it.
        """
        from .naming import payload_word

        words: Dict[str, str] = {}
        # Only shapes that actually flow through `Wire::payload` register a
        # word: a bare enum (`SHAPE_OP`) and a verbatim document (`SHAPE_DOC`)
        # read as strings/raw values in the helper itself and never dispatch.
        dispatched = (
            M.SHAPE_NODE,
            M.SHAPE_NODE_STR,
            M.SHAPE_NODE_LIST,
            M.SHAPE_OPT_NODE_LIST,
            M.SHAPE_OPT_VEC,
            M.SHAPE_VALUE_LIST,
            M.SHAPE_CLASS_REF,
        )
        for cm in self.m.classes.values():
            for f in cm.fields:
                if f.payload and f.shape in dispatched:
                    words[payload_word(f.payload)] = f.payload
            for payload in cm.payload_loaders.values():
                words[payload_word(payload)] = payload
        # The three hierarchies are reachable as payloads even where no field
        # happens to hold them today; register them so a future field cannot
        # arrive unregistered.
        for root in self.m.roots:
            words[payload_word(root)] = root
        return dict(sorted(words.items()))

    def _decoder_expr(self, rust_name: str) -> str:
        if rust_name in self.m.roots:
            return f"{rust_name}::fromWire($wire)"
        return f"{self.m.classes[rust_name].name}::fromWire($wire)"

    # --- field types ---------------------------------------------------------

    #: How a field shape reads off the wire: the `Wire` helper, and whether
    #: the call names its payload with a literal (the third argument) or the
    #: helper names its own payload (the string readers) or there is no
    #: payload to name at all.
    _READERS = {
        M.SHAPE_NODE_STR: ("stringNode", False),
        M.SHAPE_NODE: ("nodeRef", True),
        M.SHAPE_NODE_LIST: ("nodeRefList", True),
        M.SHAPE_OPT_NODE_LIST: ("optNodeRefList", True),
        M.SHAPE_OPT_VEC: ("nodeRefList", True),
        M.SHAPE_VALUE_LIST: ("classList", True),
        M.SHAPE_CLASS_REF: ("classRef", True),
        M.SHAPE_STR: ("str", None),
        M.SHAPE_OPT_STR: ("optStr", None),
        M.SHAPE_BOOL: ("bool", None),
        M.SHAPE_NUM: ("int", None),
        M.SHAPE_OPT_NUM: ("int", None),
        M.SHAPE_OP: ("op", None),
        M.SHAPE_OP_LIST: ("opList", None),
        M.SHAPE_VERBATIM: ("verbatim", None),
        M.SHAPE_DOC: ("verbatim", None),
        M.SHAPE_OPAQUE: ("verbatim", None),
    }

    def _read(self, f: FieldModel, wire: str = "$w") -> str:
        """The decoder call for one field."""
        from .naming import payload_word

        helper, literal = self._READERS.get(f.shape, (None, None))
        if helper is None:
            raise M.ModelError(f"{f.wire}: no PHP reader for shape {f.shape!r}")
        if literal is True:
            return f"Wire::{helper}({wire}, '{f.wire}', '{payload_word(f.payload or '')}')"
        return f"Wire::{helper}({wire}, '{f.wire}')"

    def _php_type(self, f: FieldModel) -> str:
        """The PHP type of one field, for the promoted property or a parameter."""
        s = f.shape
        if s in (M.SHAPE_NODE, M.SHAPE_NODE_STR):
            return "?NodeRef"
        if s in (M.SHAPE_NODE_LIST, M.SHAPE_OPT_NODE_LIST, M.SHAPE_OPT_VEC,
                 M.SHAPE_VALUE_LIST, M.SHAPE_OP_LIST, M.SHAPE_RAW_LIST,
                 M.SHAPE_DOC):
            return "array"
        if s == M.SHAPE_CLASS_REF:
            return "?" + self.m.classes[f.payload or ""].name
        if s == M.SHAPE_STR:
            return "string"
        if s in (M.SHAPE_OPT_STR, M.SHAPE_OP):
            return "?string"
        if s == M.SHAPE_BOOL:
            return "bool"
        if s in (M.SHAPE_NUM, M.SHAPE_OPT_NUM):
            return "float" if "f64" in f.rust_type else "int"
        if s in (M.SHAPE_VERBATIM, M.SHAPE_OPAQUE):
            return "mixed"
        if s == M.SHAPE_COMPACT_NODE:
            return "?NodeRef"
        raise M.ModelError(f"{f.wire}: no PHP type for shape {s!r}")

    def _doc_type(self, f: FieldModel) -> str:
        """The phpdoc spelling of a field's payload, for `@var` annotations."""
        from .naming import payload_word

        s = f.shape
        if s == M.SHAPE_NODE_STR:
            return "NodeRef<string>"
        if s == M.SHAPE_NODE:
            return f"NodeRef<{f.payload}>"
        if s == M.SHAPE_NODE_LIST:
            inner = "string" if payload_word(f.payload or "") == "string" else str(f.payload)
            return f"list<NodeRef<{inner}>>"
        if s == M.SHAPE_OPT_NODE_LIST:
            return f"list<NodeRef<{f.payload}>|null>"
        if s == M.SHAPE_OPT_VEC:
            return f"list<NodeRef<{f.payload}>>"
        if s == M.SHAPE_VALUE_LIST:
            return f"list<{f.payload}>"
        if s == M.SHAPE_OP_LIST:
            return f"list<{f.payload}>"
        if s == M.SHAPE_VERBATIM:
            return "mixed"
        if s == M.SHAPE_COMPACT_NODE:
            return "NodeRef<string>|NodeRef<Expr>"
        if s == M.SHAPE_DOC:
            return "array<string, mixed>"
        return self._php_type(f)

    @staticmethod
    def _default(f: FieldModel) -> str:
        s = f.shape
        if s == M.SHAPE_STR:
            return "''"
        if s in (M.SHAPE_OPT_STR, M.SHAPE_OP, M.SHAPE_NODE, M.SHAPE_NODE_STR,
                 M.SHAPE_CLASS_REF):
            return "null"
        if s == M.SHAPE_BOOL:
            return "false"
        if s in (M.SHAPE_NUM, M.SHAPE_OPT_NUM):
            return "0"
        if s in (M.SHAPE_VERBATIM, M.SHAPE_OPAQUE, M.SHAPE_COMPACT_NODE):
            return "null"
        return "[]"

    # --- files ---------------------------------------------------------------

    def emit(self, name: str) -> str:
        """The full text of one generated file."""
        stem = name[:-4] if name.endswith(".php") else name
        if stem == "Wire":
            body = self._emit_wire()
        elif stem == "NodeRef":
            body = self._emit_noderef()
        elif stem == "Ast":
            body = self._emit_ast()
        elif stem == "AstBuild":
            body = self._emit_build()
        elif stem in self.m.roots:
            body = self._emit_root(stem)
        elif stem in self._op_enums:
            body = self._emit_op(self._op_enums[stem])
        else:
            cm = next((c for c in self.m.classes.values() if c.name == stem), None)
            if cm is None:
                raise M.ModelError(f"no PHP emitter for {name}")
            body = self._emit_class(cm)
        return self._header() + "\n".join(body).rstrip() + "\n"

    def file_names(self) -> List[str]:
        names = list(PHP_SUPPORT_FILES)
        names += [f"{root}.php" for root in self.m.roots]
        names += [f"{cm.name}.php" for cm in self._emitted_classes()]
        names += [f"{name}.php" for name in sorted(self._op_enums)]
        return sorted(set(names))

    def _emitted_classes(self) -> List[ClassModel]:
        return [cm for cm in self.m.classes.values() if cm.kind != "node_wrapper"]

    def _header(self) -> str:
        return (
            "<?php\n\n"
            "// Code generated by tools/generate_ast.py from\n"
            f"// kcl-lang/kcl/crates/ast/src/ast.rs (sha256:{self.m.source_sha}).\n"
            "// DO NOT EDIT BY HAND — run `python3 tools/generate_ast.py` and commit the\n"
            "// result, or `ruby hack/check_generated_ast.rb` will fail.\n"
            "//\n"
            "// Every class, field, wire tag and operator below is derived from the Rust\n"
            "// source. See tools/astgen/emit_php.py for the shapes and why they are so.\n\n"
            "declare(strict_types=1);\n\n"
            "namespace KclLib\\Ast;\n\n"
        )

    # --- classes -------------------------------------------------------------

    def _base(self, cm: ClassModel) -> Optional[str]:
        return cm.owner if cm.owner in self.m.roots else None

    def _emit_class(self, cm: ClassModel) -> List[str]:
        out: List[str] = []
        doc = narrative.CLASS_DOCS.get(cm.rust_name) or cm.rust_doc
        out += _doc(doc)
        base = self._base(cm)
        extends = f" extends {base}" if base else ""
        out.append(f"final class {cm.name}{extends}")
        out.append("{")
        out += self._emit_constructor(cm)
        out.append("")
        out += self._emit_from_wire(cm)
        if cm.derived:
            out.append("")
            out += self._emit_derived(cm)
        out.append("}")
        out.append("")
        return out

    def _emit_constructor(self, cm: ClassModel) -> List[str]:
        if not cm.fields:
            return [
                "    public function __construct()",
                "    {",
                "    }",
            ]
        out = ["    public function __construct("]
        for i, f in enumerate(cm.fields):
            comma = "," if i < len(cm.fields) - 1 else ""
            out.append(f"        /** @var {self._doc_type(f)} */")
            out.append(
                f"        public readonly {self._php_type(f)} ${self._prop(f.name)} = {self._default(f)}{comma}"
            )
        out.append("    ) {")
        out.append("    }")
        return out

    def _emit_from_wire(self, cm: ClassModel) -> List[str]:
        if len(cm.fields) == 1 and cm.fields[0].inline:
            return self._emit_inline_from_wire(cm)
        if cm.kind in ("compact_value", "compact_node"):
            return self._emit_compact_from_wire(cm)
        out = [
            "    /**",
            "     * Decode from this node's wire object. Every key is read",
            "     * through the one `Wire` helper for its shape, which is the",
            "     * only place the four shapes are told apart.",
            "     */",
            "    public static function fromWire(mixed $w): ?self",
            "    {",
            "        if (!is_array($w)) {",
            "            return null;",
            "        }",
            "",
        ]
        if not cm.fields:
            out = [
                "    /**",
                "     * Decode from this node's wire object. There are no",
                "     * fields to read — the wire document is the tag alone,",
                "     * as in `{\"type\": \"Any\"}` — so any payload (including",
                "     * none) decodes to the one instance shape.",
                "     */",
                "    public static function fromWire(mixed $w): ?self",
                "    {",
                "        return new self();",
                "    }",
            ]
            return out
        out.append("        return new self(")
        for i, f in enumerate(cm.fields):
            comma = "," if i < len(cm.fields) - 1 else ""
            out.append(f"            {self._prop(f.name)}: {self._read(f)}{comma}")
        out.append("        );")
        out.append("    }")
        return out

    def _emit_inline_from_wire(self, cm: ClassModel) -> List[str]:
        """A class whose one inline field *is* the adjacently-tagged payload.

        `Type::Basic` is `{"type":"Basic","value":"Int"}` — the content key
        carries the whole value, so the decoder is handed the payload itself
        and reads no key off it: the bare string for `BasicType`, the
        inlined `Identifier` for `NamedType`, and the second tagged document
        verbatim for `LiteralType`. The payload is not always an array, so
        there is no `is_array` guard up front — each shape checks its own.
        """
        f = cm.fields[0]
        out = [
            "    /**",
            "     * Decode the adjacently-tagged payload this class inlines:",
            "     * the content key carries the whole value, so there is no",
            "     * key to read off it — the payload *is* the field.",
            "     */",
            "    public static function fromWire(mixed $w): ?self",
            "    {",
            "        return new self(",
        ]
        if f.shape == M.SHAPE_STR:
            out.append("            " + self._prop(f.name) + ": Wire::stringValue($w) ?? '',")
        elif f.shape == M.SHAPE_DOC:
            out.append("            " + self._prop(f.name) + ": is_array($w) ? $w : [],")
        elif f.shape == M.SHAPE_CLASS_REF:
            payload = self.m.classes[f.payload or ""].name
            out.append("            " + self._prop(f.name) + f": {payload}::fromWire($w),")
        else:
            raise M.ModelError(f"{cm.name}: no inline decoder for shape {f.shape!r}")
        out.append("        );")
        out.append("    }")
        return out

    def _emit_compact_from_wire(self, cm: ClassModel) -> List[str]:
        """The tagged value that is not a hierarchy: a `kind` plus a payload.

        The payload's decoder differs per variant — `Member` is a
        `NodeRef<String>` and `Index` a `NodeRef<Expr>` — so the tag is read
        before the payload, the same way `Wire::payload` dispatches by word.
        """
        out = [
            "    /**",
            "     * Decode the `kind` plus its payload; the payload's decoder",
            "     * differs per variant, so the tag is read first. Both arms",
            "     * hold a `NodeRef` (`Member` a `NodeRef<string>`, `Index` a",
            "     * `NodeRef<Expr>`), so the wire value is the whole wrapper",
            "     * with its five position keys, not the bare payload.",
            "     */",
            "    public static function fromWire(mixed $w): ?self",
            "    {",
            "        if (!is_array($w)) {",
            "            return null;",
            "        }",
            "",
            "        $kind = Wire::str($w, 'type');",
        ]
        if cm.kind == "compact_node":
            out.append("        $node = Wire::payloadForKind($kind, $w['value'] ?? null);")
        else:
            out.append("        $node = $w['value'] ?? null;")
        out.append("")
        out.append("        return new self($kind, $node);")
        out.append("    }")
        return out

    def _emit_derived(self, cm: ClassModel) -> List[str]:
        attr, source = cm.derived
        prop = self._prop(source)
        return [
            "    /**",
            f"     * The tag *inside* the verbatim `{cm.name}` payload: this class",
            "     * is itself a `tag/content` document, so the outer tag was read",
            "     * by the dispatcher and a second one rides in the payload.",
            "     */",
            f"    public function {attr}(): ?string",
            "    {",
            f"        return is_string($this->{prop}['type'] ?? null) ? $this->{prop}['type'] : null;",
            "    }",
        ]

    # --- roots ---------------------------------------------------------------

    def _emit_root(self, root: str) -> List[str]:
        cm = self.m.enums[root]
        adjacent = bool(cm.content)
        content = cm.content or "value"
        tag = cm.tag or "type"
        variants = [self.m.variants[f"{root}::{v}"] for v in cm.variants]
        doc = {
            "Expr": "One expression variant of the `Expr` hierarchy.",
            "Stmt": "One statement variant of the `Stmt` hierarchy.",
            "Type": "One type variant of the `Type` hierarchy.",
        }[root]
        out: List[str] = []
        out += _doc(doc + " Decode with the one static `fromWire`; a caller "
                         "dispatches on the concrete class with `instanceof`.")
        out.append(f"abstract class {root}")
        out.append("{")
        out.append("    /**")
        out.append(f"     * Read a `{root}` off the wire. `{tag}` is the")
        out.append("     * discriminator every variant carries, so the dispatch")
        out.append("     * is a lookup rather than a guess; a tag this build")
        out.append("     * does not know decodes to null rather than to a")
        out.append("     * zero-valued node.")
        out.append("     */")
        out.append(f"    public static function fromWire(mixed $w): ?{root}")
        out.append("    {")
        out.append("        if (!is_array($w)) {")
        out.append("            return null;")
        out.append("        }")
        out.append("")
        if adjacent:
            out.append(f"        $payload = $w['{content}'] ?? null;")
        else:
            out.append("        $payload = $w;")
        out.append("")
        out.append(f"        return match ($w['{tag}'] ?? null) {{")
        for v in variants:
            out.append(f"            '{v.tag}' => {v.name}::fromWire($payload),")
        out.append("            default => null,")
        out.append("        };")
        out.append("    }")
        out.append("}")
        out.append("")
        return out

    # --- operator vocabularies -------------------------------------------------

    def _emit_op(self, cm: ClassModel) -> List[str]:
        out = _doc(
            f"The variants of `{cm.name}`. A Rust enum with no `#[serde]` "
            "attribute at all, so the value on the wire is a bare JSON string "
            f'— `{cm.name}::{cm.variants[0]}` is "{cm.variants[0]}", not '
            f'`{{"{cm.variants[0]}": null}}` — and these constants are the '
            "whole vocabulary."
        )
        out.append(f"final class {cm.name}")
        out.append("{")
        for v in cm.variants:
            out.append(f"    public const {v} = '{v}';")
        out.append("")
        out.append("    private function __construct()")
        out.append("    {")
        out.append("    }")
        out.append("}")
        out.append("")
        return out

    # --- Wire -------------------------------------------------------------------

    def _emit_wire(self) -> List[str]:
        out: List[str] = []
        out += _doc(
            "The one place the wire shapes are told apart.\n\n"
            "Every decoder hands its field to the helper for the field's "
            "shape, and the helper substitutes the parser-shaped default for "
            "an absent key — `null` for an optional node, `''` for a string, "
            "`[]` for a list, `false` for a `skip_serializing_if` bool — so "
            "nothing here throws on the gaps serde leaves.\n\n"
            "A `NodeRef<T>` wrapper carries the five flattened position keys "
            "beside `node`; there is no `pos` key on the wire and no nested "
            "object."
        )
        out.append("final class Wire")
        out.append("{")
        for method in self._wire_methods():
            out += method
            out.append("")
        out += self._emit_payload_dispatch()
        out.append("")
        out += self._emit_kind_dispatch()
        out.append("}")
        out.append("")
        return out

    def _emit_payload_dispatch(self) -> List[str]:
        out = [
            "    /**",
            "     * Dispatch one payload by its vocabulary word — the same",
            "     * word `hack/check_ast_field_types.rb` reads off the decoder",
            "     * calls, so a generated payload cannot be checked against a",
            "     * different decoder than it runs.",
            "     */",
            "    public static function payload(string $kind, mixed $wire): mixed",
            "    {",
            "        if ($wire === null) {",
            "            return null;",
            "        }",
            "",
            "        return match ($kind) {",
            "            'string' => self::stringValue($wire),",
        ]
        for word, rust in self._payload_words.items():
            if word in ("string", "bool", "int", "float"):
                continue
            out.append(f"            '{word}' => {self._decoder_expr(rust)},")
        out.append("            default => throw new \\InvalidArgumentException(\"unknown AST payload: {$kind}\"),")
        out.append("        };")
        out.append("    }")
        return out

    def _emit_kind_dispatch(self) -> List[str]:
        cm = self.m.classes["MemberOrIndex"]
        out = [
            "    /**",
            "     * The `MemberOrIndex` payload decoder differs per variant,",
            "     * so the tag is read before the payload — the same way",
            "     * `Wire::payload` dispatches by word.",
            "     */",
            "    public static function payloadForKind(string $kind, mixed $wire): mixed",
            "    {",
            "        return match ($kind) {",
        ]
        from .naming import payload_word

        for tag, payload in sorted(cm.payload_loaders.items()):
            if payload_word(payload) == "string":
                expr = "self::nodeRefOf($wire, 'string')"
            else:
                expr = f"self::nodeRefOf($wire, '{payload_word(payload)}')"
            out.append(f"            '{tag}' => {expr},")
        out.append("            default => null,")
        out.append("        };")
        out.append("    }")
        return out

    @staticmethod
    def _wire_methods() -> List[List[str]]:
        return [
            [
                "    /** Decode a `NodeRef<T>`; null when the key is absent. */",
                "    public static function nodeRef(array $w, string $key, string $payload): ?NodeRef",
                "    {",
                "        $wire = $w[$key] ?? null;",
                "        if (!is_array($wire)) {",
                "            return null;",
                "        }",
                "",
                "        return new NodeRef(",
                "            node: self::payload($payload, $wire['node'] ?? null),",
                "            filename: self::stringValue($wire['filename'] ?? null) ?? '',",
                "            line: self::intValue($wire['line'] ?? null) ?? 0,",
                "            column: self::intValue($wire['column'] ?? null) ?? 0,",
                "            endLine: self::intValue($wire['end_line'] ?? null) ?? 0,",
                "            endColumn: self::intValue($wire['end_column'] ?? null) ?? 0,",
                "        );",
                "    }",
            ],
            [
                "    /** Decode a `NodeRef<String>`; the payload is the bare string under `node`. */",
                "    public static function stringNode(array $w, string $key): ?NodeRef",
                "    {",
                "        return self::nodeRef($w, $key, 'string');",
                "    }",
            ],
            [
                "    /** Decode a `Vec<NodeRef<T>>`; an absent key is an empty list. */",
                "    public static function nodeRefList(array $w, string $key, string $payload): array",
                "    {",
                "        $wire = $w[$key] ?? null;",
                "        if (!is_array($wire)) {",
                "        return [];",
                "        }",
                "",
                "        $out = [];",
                "        foreach ($wire as $item) {",
                "            $out[] = is_array($item)",
                "                ? new NodeRef(",
                "                    node: self::payload($payload, $item['node'] ?? null),",
                "                    filename: self::stringValue($item['filename'] ?? null) ?? '',",
                "                    line: self::intValue($item['line'] ?? null) ?? 0,",
                "                    column: self::intValue($item['column'] ?? null) ?? 0,",
                "                    endLine: self::intValue($item['end_line'] ?? null) ?? 0,",
                "                    endColumn: self::intValue($item['end_column'] ?? null) ?? 0,",
                "                )",
                "                : null;",
                "        }",
                "",
                "        return $out;",
                "    }",
            ],
            [
                "    /**",
                "     * Decode a `Vec<Option<NodeRef<T>>>` — `Arguments.defaults` and",
                "     * `ty_list` are index-aligned with `args`, so a null element keeps",
                "     * its slot rather than being dropped and shifting the tail.",
                "     */",
                "    public static function optNodeRefList(array $w, string $key, string $payload): array",
                "    {",
                "        return self::nodeRefList($w, $key, $payload);",
                "    }",
            ],
            [
                "    /** Decode a `Vec<NodeRef<String>>`. */",
                "    public static function stringNodeList(array $w, string $key): array",
                "    {",
                "        return self::nodeRefList($w, $key, 'string');",
                "    }",
            ],
            [
                "    /**",
                "     * Decode a bare struct — `DictComp.entry` is a `ConfigEntry` with",
                "     * no `node` wrapper and no `type` tag, so the whole wire value is",
                "     * handed to the struct's own decoder.",
                "     */",
                "    public static function classRef(array $w, string $key, string $payload): mixed",
                "    {",
                "        $wire = $w[$key] ?? null;",
                "        if (!is_array($wire)) {",
                "            return null;",
                "        }",
                "",
                "        return self::payload($payload, $wire);",
                "    }",
            ],
            [
                "    /** Decode a bare `Vec<T>` of structs — `Target.paths` has no wrapper per element. */",
                "    public static function classList(array $w, string $key, string $payload): array",
                "    {",
                "        $wire = $w[$key] ?? null;",
                "        if (!is_array($wire)) {",
                "            return [];",
                "        }",
                "",
                "        $out = [];",
                "        foreach ($wire as $item) {",
                "            $out[] = self::payload($payload, $item);",
                "        }",
                "",
                "        return $out;",
                "    }",
            ],
            [
                "    /**",
                "     * Decode a `NodeRef<T>` from a value that already *is* the",
                "     * wrapper — the payload of a `MemberOrIndex` arm — rather",
                "     than a key inside a parent object.",
                "     */",
                "    public static function nodeRefOf(mixed $wire, string $payload): ?NodeRef",
                "    {",
                "        if (!is_array($wire)) {",
                "            return null;",
                "        }",
                "",
                "        return new NodeRef(",
                "            node: self::payload($payload, $wire['node'] ?? null),",
                "            filename: self::stringValue($wire['filename'] ?? null) ?? '',",
                "            line: self::intValue($wire['line'] ?? null) ?? 0,",
                "            column: self::intValue($wire['column'] ?? null) ?? 0,",
                "            endLine: self::intValue($wire['end_line'] ?? null) ?? 0,",
                "            endColumn: self::intValue($wire['end_column'] ?? null) ?? 0,",
                "        );",
                "    }",
            ],
            [
                "    /** A string Rust writes whether or not it has a value. */",
                "    public static function str(array $w, string $key, string $default = ''): string",
                "    {",
                "        return self::stringValue($w[$key] ?? null) ?? $default;",
                "    }",
            ],
            [
                "    /** An `Option<String>`: null when the key is absent or JSON null. */",
                "    public static function optStr(array $w, string $key): ?string",
                "    {",
                "        return self::stringValue($w[$key] ?? null);",
                "    }",
            ],
            [
                "    /**",
                "     * A `#[serde(skip_serializing_if = \"is_false\")]` bool — absent on the",
                "     * wire when false, so absent reads as false and nothing is invented.",
                "     */",
                "    public static function bool(array $w, string $key, bool $default = false): bool",
                "    {",
                "        return is_bool($w[$key] ?? null) ? $w[$key] : $default;",
                "    }",
            ],
            [
                "    /** A bare enum (`BinOp`, `ExprContext`, …) arrives as a JSON string. */",
                "    public static function op(array $w, string $key): ?string",
                "    {",
                "        return self::stringValue($w[$key] ?? null);",
                "    }",
            ],
            [
                "    /** A `Vec<CmpOp>` — bare JSON strings, index-aligned with `comparators`. */",
                "    public static function opList(array $w, string $key): array",
                "    {",
                "        $wire = $w[$key] ?? null;",
                "        if (!is_array($wire)) {",
                "            return [];",
                "        }",
                "",
                "        $out = [];",
                "        foreach ($wire as $item) {",
                "            if (is_string($item)) {",
                "                $out[] = $item;",
                "            }",
                "        }",
                "",
                "        return $out;",
                "    }",
            ],
            [
                "    /**",
                "     * Keep a payload verbatim — a `tag/content` document with no fixed",
                "     * field set across its variants (`LiteralType`) or a scalar union",
                "     * (`NumberLitValue`). Splitting it per kind would invent structure",
                "     * the wire does not have.",
                "     */",
                "    public static function verbatim(array $w, string $key): mixed",
                "    {",
                "        return $w[$key] ?? null;",
                "    }",
            ],
            [
                "    public static function stringValue(mixed $v): ?string",
                "    {",
                "        return is_string($v) ? $v : null;",
                "    }",
            ],
            [
                "    public static function intValue(mixed $v): ?int",
                "    {",
                "        return is_int($v) ? $v : null;",
                "    }",
            ],
        ]

    # --- NodeRef / Ast entry points ---------------------------------------------

    def _emit_noderef(self) -> List[str]:
        out: List[str] = []
        out += _doc(
            "The `NodeRef<T>` wrapper every node travels in.\n\n"
            "Rust declares `ast::Node<T>` with its five position members "
            "inlined into the wrapper — `filename`, `line`, `column`, "
            "`end_line` and `end_column` sit beside `node` and there is no "
            "`pos` key. `node` itself is not an `Option`, so serde writes "
            "`\"node\": null` for an empty ref rather than dropping the key; "
            "PHP keeps it as null the same way."
        )
        out.append("final class NodeRef")
        out.append("{")
        out.append("    public function __construct(")
        out.append("        /** The decoded payload — a node class, or a scalar for `NodeRef<string>`. */")
        out.append("        public readonly mixed $node = null,")
        out.append("        public readonly string $filename = '',")
        out.append("        public readonly int $line = 0,")
        out.append("        public readonly int $column = 0,")
        out.append("        public readonly int $endLine = 0,")
        out.append("        public readonly int $endColumn = 0,")
        out.append("    ) {")
        out.append("    }")
        out.append("}")
        out.append("")
        return out

    def _emit_ast(self) -> List[str]:
        out: List[str] = []
        out += _doc(
            "Entry points over the `ast_json` strings the parse RPCs return.\n\n"
            "`parseModule` decodes the `ParseFileResult.ast_json` document; "
            "`parseProgram` accepts the `{\"root\": …, \"pkgs\": {\"__main__\": "
            "[Module, …]}}` envelope `ParseProgramResult.ast_json` carries and "
            "hands back the modules of `pkgs.__main__`, like every other "
            "binding."
        )
        out.append("final class Ast")
        out.append("{")
        out.append("    private function __construct()")
        out.append("    {")
        out.append("    }")
        out.append("")
        out.append("    /** Decode the `ast_json` of a ParseFileResult into a Module. */")
        out.append("    public static function parseModule(string $astJson): Module")
        out.append("    {")
        out.append("        $wire = json_decode($astJson, true);")
        out.append("        if (!is_array($wire)) {")
        out.append("            throw new \\UnexpectedValueException('ParseFileResult.ast_json is not a JSON object');")
        out.append("        }")
        out.append("")
        out.append("        return Module::fromWire($wire);")
        out.append("    }")
        out.append("")
        out.append("    /**")
        out.append("     * Decode the `ast_json` of a ParseProgramResult into")
        out.append("     * the `__main__` modules, accepting both wire shapes:")
        out.append("     * the current `pkgs` envelope and the older bare module")
        out.append("     * list.")
        out.append("     * @return list<Module>")
        out.append("     */")
        out.append("    public static function parseProgram(string $astJson): array")
        out.append("    {")
        out.append("        $wire = json_decode($astJson, true);")
        out.append("        if (!is_array($wire)) {")
        out.append("            throw new \\UnexpectedValueException('ParseProgramResult.ast_json is not JSON');")
        out.append("        }")
        out.append("")
        out.append("        if (!isset($wire['pkgs'])) {")
        out.append("            if (isset($wire['filename']) && isset($wire['body'])) {")
        out.append("                return [Module::fromWire($wire)];")
        out.append("            }")
        out.append("            $modules = [];")
        out.append("            foreach ($wire as $item) {")
        out.append("                $modules[] = Module::fromWire($item);")
        out.append("            }")
        out.append("            return $modules;")
        out.append("        }")
        out.append("")
        out.append("        $modules = [];")
        out.append("        foreach ($wire['pkgs']['__main__'] ?? [] as $item) {")
        out.append("            $modules[] = Module::fromWire($item);")
        out.append("        }")
        out.append("        return $modules;")
        out.append("    }")
        out.append("}")
        out.append("")
        return out

    # --- AstBuild --------------------------------------------------------------

    def _emit_build(self) -> List[str]:
        out: List[str] = []
        out += _doc(
            "Constructors for every node class, the reference form being "
            "kotlin/src/main/kotlin/com/kcl/ast/AstBuild.kt: one factory per "
            "node type, and the default for each parameter is the value the "
            "Rust parser itself produces for that field — a `Vec<T>` defaults "
            "to an empty list and is never `null`, an `Option<T>` defaults to "
            "`null`, a `String` written unconditionally defaults to `''`. "
            "Building an AST node never makes the caller type an empty "
            "collection at every level of the tree."
        )
        out.append("final class AstBuild")
        out.append("{")
        out.append("    private function __construct()")
        out.append("    {")
        out.append("    }")
        out.append("")
        helpers = self._build_helpers()
        ctors = [self._build_ctor(cm) for cm in self._emitted_classes()]
        blocks = helpers + ctors
        for i, block in enumerate(blocks):
            if i > 0:
                out.append("")
            out += block
        out.append("}")
        out.append("")
        return out

    def _build_param(self, f: FieldModel) -> tuple[str, str]:
        return (
            f"        /** @var {self._doc_type(f)} */",
            f"        {self._php_type(f)} ${self._prop(f.name)} = {self._default(f)}",
        )

    def _build_ctor(self, cm: ClassModel) -> List[str]:
        method = self._method(cm.name)
        doc = narrative.CLASS_DOCS.get(cm.rust_name) or cm.rust_doc
        out: List[str] = []
        out += ["    " + line for line in _doc(doc)] if doc else []
        if not cm.fields:
            out.append(f"    public static function {method}(): {cm.name}")
            out.append("    {")
            out.append(f"        return new {cm.name}();")
            out.append("    }")
            return out
        params: List[str] = []
        for f in cm.fields:
            type_line, param_line = self._build_param(f)
            params.append(type_line)
            params.append(param_line + ",")
        signature = [f"    public static function {method}("]
        signature += params
        signature.append(f"    ): {cm.name} {{")
        out += signature
        args = ", ".join(f"{self._prop(f.name)}: ${self._prop(f.name)}" for f in cm.fields)
        out.append(f"        return new {cm.name}({args});")
        out.append("    }")
        return out

    def _build_helpers(self) -> List[List[str]]:
        node_ref_doc = (
            "Wrap a payload in a `NodeRef` — the shape the wire carries. The "
            "five position keys are flattened onto the wrapper beside `node`; "
            "there is no `pos` key on the wire."
        )
        return [
            [
                *[f"    {line}" for line in _doc(node_ref_doc)],
                "    public static function nodeRef(",
                "        mixed $node = null,",
                "        string $filename = '',",
                "        int $line = 1,",
                "        int $column = 1,",
                "        ?int $endLine = null,",
                "        ?int $endColumn = null,",
                "    ): NodeRef {",
                "        return new NodeRef($node, $filename, $line, $column, $endLine ?? $line, $endColumn ?? $column);",
                "    }",
            ],
            [
                "    /**",
                "     * A wrapper that is present but holds nothing — Rust's `Node<T>`,",
                "     * whose `node` field is not an `Option`, so serde writes",
                "     * `\"node\": null` rather than dropping the key.",
                "     */",
                "    public static function emptyNodeRef(",
                "        string $filename = '',",
                "        int $line = 1,",
                "        int $column = 1,",
                "        ?int $endLine = null,",
                "        ?int $endColumn = null,",
                "    ): NodeRef {",
                "        return new NodeRef(null, $filename, $line, $column, $endLine ?? $line, $endColumn ?? $column);",
                "    }",
            ],
            [
                "    /**",
                "     * One segment of a dotted name, wrapped. `nameRef('pkg')`",
                "     * is the `NodeRef<string>` the `Identifier.names` list holds.",
                "     */",
                "    public static function nameRef(",
                "        string $name,",
                "        string $filename = '',",
                "        int $line = 1,",
                "        int $column = 1,",
                "        ?int $endLine = null,",
                "        ?int $endColumn = null,",
                "    ): NodeRef {",
                "        return self::nodeRef($name, $filename, $line, $column, $endLine, $endColumn);",
                "    }",
            ],
        ]

"""Naming policy: the one place where the generator disagrees with Rust.

Every AST type name the generator emits follows the **Java** binding
(``java/src/main/java/com/kcl/ast/``), because that is the reference the repo
settled on. Java's names are the Rust names except for two places, and both are
handled here rather than scattered through the emitters:

``Target`` / ``Identifier``
    Java splits each of these in two -- ``Target.java`` + ``TargetExpr.java``,
    ``Identifier.java`` + ``IdentifierExpr.java`` -- because ``Target`` is both
    a struct (``AssignStmt.targets``) and an ``Expr`` variant
    (``Expr::Target``). The AST has the same split but one Rust type, so the
    generator emits one class per struct and an *alias* for the variant name,
    which is what ``Decorator is CallExpr`` already does for the
    ``CallExpr``/``Decorator`` pair. Two names, one class, no duplicate field
    list to drift.

``CheckExpr``
    Java's name for ``ast::CheckExpr``. The TypeScript binding had called it
    ``Check``; the generator emits ``CheckExpr``. Loader *function* names are
    not touched -- ``checkFromWire`` is fixed by
    ``hack/check_ast_field_types.rb``, which looks the decoder up by
    ``camelize(payload_word) + "FromWire"`` and would report a missing decoder
    for every comment in the tree if the two drifted apart.

Everything else is mechanical, which is the point: the Java set and the Rust
set agree on 60+ names, and the ones that do not are written out below so the
disagreement is visible rather than inherited.
"""

from __future__ import annotations

import re
from typing import Dict, List

# --- Rust name -> emitted class name -------------------------------------

#: Rust type -> emitted class name. A Rust type missing from this table keeps
#: its own name, which is the right default precisely because Java agrees with
#: Rust on every name: `test_naming_matches_java` in the generator's own test
#: run asserts that every name emitted is a file in
#: `java/src/main/java/com/kcl/ast/`, so this table has nothing in it and an
#: entry added here would have to come with a matching Java file.
CLASS_NAME_OVERRIDES: Dict[str, str] = {
    # No override for any struct. See the module docstring for why `Target`
    # and `Identifier` are aliases rather than renames.
}

#: Class emitted for an `Expr` variant that wraps a struct which also exists
#: untagged elsewhere in the tree. The alias is what names the tagged position;
#: the class underneath is the shared one, so `isinstance` keeps working in both
#: positions and there is only one field list to maintain.
VARIANT_ALIASES: Dict[str, str] = {
    "Target": "TargetExpr",
    "Identifier": "IdentifierExpr",
}

#: Aliases that already exist in the hand-written code for the same reason and
#: are kept so the public API does not move: `Decorator` is the `CallExpr`
#: struct, `SchemaConfig` is the `SchemaExpr` struct, `KeyValuePair` is the
#: `ConfigEntry` struct.
LEGACY_ALIASES: Dict[str, str] = {
    "CallExpr": ["Decorator"],
    "SchemaExpr": ["SchemaConfig"],
    "ConfigEntry": ["KeyValuePair"],
}


def class_name(rust_name: str) -> str:
    return CLASS_NAME_OVERRIDES.get(rust_name, rust_name)


def variant_aliases(rust_name: str) -> List[str]:
    out = list(LEGACY_ALIASES.get(rust_name, []))
    if rust_name in VARIANT_ALIASES:
        out.append(VARIANT_ALIASES[rust_name])
    return sorted(out)


# --- payload vocabulary ---------------------------------------------------

#: The word each struct's decoder is known by. `hack/check_ast_field_types.rb`
#: has its own `PAYLOAD_LOADER` table and reads Python's
#: `Identifier.from_dict` / `expr_from_dict` and TypeScript's
#: `identifierFromWire` through it, so the generator uses the same vocabulary
#: rather than a snake_case of its own inventing -- which is what makes a
#: generated decoder count as *checked* rather than as an unresolved payload.
#: Only one entry differs from a plain snake_case, and it is spelled out.
PAYLOAD_WORD_OVERRIDES: Dict[str, str] = {
    "CheckExpr": "check",
}

#: Payloads whose "class" is not an AST struct. `String` is the one that
#: matters: `NodeRef<String>` and `NodeRef<Identifier>` both arrive as an
#: object on the wire and decode completely differently.
PRIMITIVE_PAYLOADS: Dict[str, str] = {
    "String": "string",
    "bool": "bool",
    "u64": "int",
    "i64": "int",
    "f64": "float",
}


def snake_case(name: str) -> str:
    out: List[str] = []
    for index, ch in enumerate(name):
        if ch.isupper() and index > 0 and not name[index - 1].isupper():
            out.append("_")
        out.append(ch.lower())
    return "".join(out)


def payload_word(rust_name: str) -> str:
    if rust_name in PRIMITIVE_PAYLOADS:
        return PRIMITIVE_PAYLOADS[rust_name]
    if rust_name in PAYLOAD_WORD_OVERRIDES:
        return PAYLOAD_WORD_OVERRIDES[rust_name]
    return snake_case(rust_name)


def camel_case(name: str) -> str:
    words = name.split("_")
    return words[0] + "".join(w[:1].upper() + w[1:] for w in words[1:])


def pascal_case(name: str) -> str:
    return "".join(w[:1].upper() + w[1:] for w in name.split("_"))


# --- TypeScript field renames -------------------------------------------

#: snake_case -> camelCase is mechanical; these two are not, and both are
#: already in the hand-written declaration and asserted by
#: `wasm/tests/ast_contract.test.ts`, so the generator keeps them.
#:
#: `UnionType.type_elements` -> `types`  because `types` is what a caller
#:   reaches for and it is the name the other bindings settled on.
#: `Identifier.ctx` / others are untouched: `ctx`, `pkgpath` and `rawpath` are
#:   already single words in Rust, so camelCase is a no-op and the generator
#:   must not "helpfully" capitalise them.
TS_FIELD_RENAMES: Dict[str, str] = {
    "type_elements": "types",
}

#: Rust field names that are not `snake_case` in a way camelCase would mangle.
TS_FIELD_KEEP: Dict[str, str] = {
    "pkgpath": "pkgpath",
    "rawpath": "rawpath",
    "names": "names",
    "ctx": "ctx",
    "op": "op",
    "value": "value",
    "test": "test",
    "message": "message",
    "iter": "iter",
    "ifs": "ifs",
    "paths": "paths",
    "args": "args",
    "body": "body",
    "cond": "cond",
    "doc": "doc",
    "name": "name",
    "items": "items",
    "elts": "elts",
    "exprs": "exprs",
    "defaults": "defaults",
    "comparators": "comparators",
    "checks": "checks",
    "decorators": "decorators",
    "mixins": "mixins",
    "kind": "kind",
    "suffix": "suffix",
    "tag": "tag",
}


def ts_field_name(rust_field: str) -> str:
    if rust_field in TS_FIELD_RENAMES:
        return TS_FIELD_RENAMES[rust_field]
    if rust_field in TS_FIELD_KEEP:
        return TS_FIELD_KEEP[rust_field]
    return camel_case(rust_field)


# --- Python module placement ---------------------------------------------

#: Which generated Python module each class lives in, and which of its imports
#: are top-level and which are deferred into the method bodies.
#:
#: The split is not cosmetic. `kcl_lib.ast` is a package of seven modules that
#: reference each other in a cycle -- `_dto`'s `CallExpr` *is* `Expr::Call` and
#: holds `NodeRef<Expr>`, and `_expr`'s dispatch builds a `CallExpr` -- and a
#: top-level import of the other side of such a cycle fails at import time
#: under CPython. The policy below is the one the hand-written package already
#: used and its tests already exercise:
#:
#: * `_base` imports nothing: it is the bottom of the graph.
#: * `_dto` is the only module that top-imports a *hierarchy*. The shared
#:   payloads live there because they are the DTOs, and a base class has to
#:   exist before `class CallExpr(Expr)` is evaluated, so the arrow points
#:   `_dto -> _expr` / `_dto -> _stmt` at the top and the other way only inside
#:   method bodies.
#: * `_expr` and `_stmt` import `_base` at the top and `_dto` lazily.
#: * `_types` imports *everything* lazily. It is the most tangled corner
#:   (`Type::Named` is an `Identifier`, `ListType.inner_type` is a `Type`, and a
#:   `Type` payload is a `NodeRef<Type>`), and it is the one module where a
#:   top-level import has bitten.
#: * `_module` imports `_base` at the top and `_stmt` lazily, because
#:   `_base.parse_module` calls into `_module`.
#:
#: Which *symbols* are needed is derived from the fields; only this
#: module-to-module policy is written down.
PY_MODULE_POLICY: Dict[str, Dict[str, List[str]]] = {
    "_base": {"top": [], "lazy": []},
    "_op": {"top": [], "lazy": []},
    "_dto": {"top": ["_base", "_expr", "_stmt"], "lazy": ["_types"]},
    "_expr": {"top": ["_base"], "lazy": ["_dto", "_stmt", "_types"]},
    "_stmt": {"top": ["_base"], "lazy": ["_dto", "_expr", "_types"]},
    "_types": {"top": [], "lazy": ["_base", "_dto", "_expr"]},
    "_module": {"top": ["_base"], "lazy": ["_stmt"]},
}

#: The order top-level `from .X import ...` lines appear in. Imports are
#: emitted in this order, filtered to the symbols actually used, so the output
#: is byte-stable rather than dependent on set iteration order.
PY_IMPORT_ORDER: Dict[str, List[str]] = {
    "_base": [
        "Node",
        "Pos",
        "node_from_dict",
        "node_list_from_dict",
        "node_list_to_dict",
        "node_to_dict",
        "optional_node_list_from_dict",
        "optional_node_list_to_dict",
    ],
    "_op": [],
    "_dto": [],
    "_expr": ["Expr"],
    "_stmt": ["Stmt"],
    "_types": ["Type"],
    "_module": ["Module"],
}


# --- Rust items the generator does not model -----------------------------

#: Types in `ast.rs` that are not part of the AST node graph a binding
#: decodes, and why. They are listed rather than filtered by a heuristic so
#: that a new one shows up as a diff instead of as a silently missing class.
#:
#: `Spanned`, `AstIndex`, `Argument`, `OverrideSpec`, `SymbolSelectorSpec`,
#: `ExternalPkg` -- AST metadata the `ast_json` payload never carries.
#: `Program`, `SerializeProgram` -- the in-memory program and its wire form.
#: Both are keyed on a package map the bindings never expose: `parseProgram`
#: flattens to the `__main__` package and returns `list[Module]`, which is what
#: `python/tests/ast_contract_test.py` and the Java `Program` both do.
#: `Pos`, `PosTuple` -- a tuple, not a struct; its five members are inlined
#: into every `NodeRef` on the wire.
NOT_AST_NODES: Dict[str, str] = {
    "Spanned": "AST metadata; `span` is #[serde(skip)]ed and never on the wire",
    "AstIndex": "wrapped by `Node.id`, itself a `serialize_with` key rather than a node",
    "Pos": "a tuple struct; its five members are inlined into every `NodeRef`",
    "PosTuple": "a type alias for a tuple, not an AST node",
    "Argument": "AST metadata, not part of the ast_json payload",
    "OverrideSpec": "AST metadata, not part of the ast_json payload",
    "OverrideAction": "AST metadata, not part of the ast_json payload",
    "SymbolSelectorSpec": "AST metadata, not part of the ast_json payload",
    "ExternalPkg": "AST metadata, not part of the ast_json payload",
    "Program": "the in-memory program; bindings expose `parse_program -> list[Module]`",
    "SerializeProgram": "its wire form; `parse_program` flattens `pkgs.__main__` to a list",
    "NodeRef": "a type alias for `Box<Node<T>>`, not a distinct wire shape",
    "Literal": "a second literal hierarchy; `Expr` carries NumberLit/StringLit directly",
    "CompType": "a sub-tag of the `For` quantifier, not a node on the wire",
    "BinOrCmpOp": "internal to the comparison builder; folded into `CmpOp` on the wire",
}

#: Enums that appear on the wire as a bare JSON string -- no `#[serde]`
#: attributes at all, so serde tags them externally and every variant is a unit
#: variant. Derived from the source, not listed; this is where the emitted
#: Python gets its operator enumerations.
BARE_ENUM_DOC = "externally tagged by serde: a bare JSON string"


def is_op_enum(variants) -> bool:
    return bool(variants) and all(v.kind == "unit" for v in variants)


_CAMEL_SPLIT = re.compile(r"[A-Z][a-z0-9]*")


def words(name: str) -> List[str]:
    return _CAMEL_SPLIT.findall(name)

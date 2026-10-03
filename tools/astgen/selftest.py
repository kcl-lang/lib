"""The generator's own tests.

``python3 tools/generate_ast.py --selftest``. Two kinds of check, and the
second is the one that matters:

*Model invariants* re-derive a handful of facts about the wire format from
``ast.rs`` and assert the model agrees. They are cheap and they fail at the
place the mistake was made, which is worth a lot: a wrong shape does not crash
the emitter, it emits a file that looks fine and decodes to ``undefined``.

*Determinism* generates everything twice, from two independent parses, and
compares the bytes. Without that, "run the generator and commit the result" is
a rule that quietly becomes "commit whatever the generator felt like today" --
and the ``--check`` mode that is supposed to catch it starts failing on a
clean tree, which is how contributors learn to ignore it.

The tests deliberately do not import the emitted code. ``wasm``'s own
``tsc``/``jest`` and ``python/tests/ast_contract_test.py`` do that; duplicating
a structural check here would be a second thing to keep in sync.
"""

from __future__ import annotations

import os
import sys
from typing import Callable, List, Tuple

from .emit_python import PY_MODULES, PythonEmitter
from .emit_typescript import TS_FILES, TypeScriptEmitter
from .model import (
    KIND_COMPACT_NODE,
    KIND_COMPACT_VALUE,
    SHAPE_OPT_NODE_LIST,
    SHAPE_OPT_VEC,
    AstModel,
    build,
)
from .rust_ast import parse_crate
from .naming import LEGACY_ALIASES, VARIANT_ALIASES

Check = Callable[[AstModel], None]
_REGISTRY: List[Tuple[str, Check]] = []

#: The Java binding is the naming reference (`java/src/main/java/com/kcl/ast/`),
#: so this is where the two are compared. It is a path rather than a constant
#: so the check is skipped rather than failed when the checkout has no Java
#: binding -- the generator does not read it, and a missing optional input
#: should not be reported as a naming regression.
JAVA_AST_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))),
    "java",
    "src",
    "main",
    "java",
    "com",
    "kcl",
    "ast",
)

#: The names in the Java binding that are *not* in `ast.rs`, written out so the
#: disagreement is visible rather than inherited. Every one is a Java-side
#: addition, not a rename:
#:
#:   * types Java defines that Rust does not -- `Program`, the AST index, the
#:     six "either op" unions Java uses where Rust has one `BinOp`;
#:   * Rust enums Java decomposes into classes -- `LiteralType` into `Literal`
#:     and the four `*LiteralType`s, `NumberLitValue` into `Int`/`Float`;
#:   * the two arms of `MemberOrIndex`, which Rust keeps behind a tag;
#:   * `NodeRef`, which is spelled `Node`/`MaybeNode` here;
#:   * and the four aliases -- `Decorator`, `SchemaConfig`, `IdentifierExpr`,
#:     `TargetExpr` -- which the generator *does* emit, alongside the struct
#:     each one stands for, so that the public API the hand-written code had
#:     keeps working.
#:
#: A name on this list that stops being emitted is a finding. A name in the
#: generated set that is *not* a Java file is the failure the check is really
#: looking for: that is a class named after Rust rather than after Java.
JAVA_ONLY = {
    "AstIndex", "Program",
    "AugBinOrAugOp", "BinBinOrAugOp", "BinBinOrCmpOp", "BinOrAugOp", "BinOrCmpOp", "CmpBinOrCmpOp",
    "BoolLiteralType", "FloatLiteralType", "StrLiteralType", "Literal", "LiteralTypeValue",
    "FloatNumberLitValue", "IntNumberLitValue",
    "Index", "Member",
    "NodeRef",
    "Decorator", "SchemaConfig", "IdentifierExpr", "TargetExpr",
}


def check(name: str) -> Callable[[Check], Check]:
    def register(fn: Check) -> Check:
        _REGISTRY.append((name, fn))
        return fn

    return register


def _shape(model: AstModel, cls: str, field: str) -> str:
    cm = model.classes[cls]
    for f in cm.fields:
        if f.name == field:
            return f.shape
    raise AssertionError(f"{cls} has no field {field}")


# ---------------------------------------------------------------------------
# model invariants
# ---------------------------------------------------------------------------


@check("internally tagged enums flatten their payload's fields")
def _flat(m: AstModel) -> None:
    """`Expr::Call(CallExpr)` has no `call` wrapper key.

    This is the trap the whole exercise starts from, so it is asserted
    directly: `CallExpr` is a plain struct on the wire *and* the payload of a
    tagged variant, and the model has to reach that conclusion from the Rust
    rather than from a list of names.
    """
    call = m.variants["Expr::Call"]
    assert call.rust_name == "CallExpr", call.rust_name
    assert call.base == "Expr" and call.tag == "Call"
    assert all(not f.inline for f in call.fields), "the payload is inlined, not flattened"
    # The struct also arrives untagged wherever a field is declared with the
    # struct rather than with the variant, so one decoder serves both and the
    # model has to know that -- it is why the class is `kind="shared"`.
    assert m.classes["CallExpr"].kind == "shared", "CallExpr is held bare somewhere"
    assert m.classes["SchemaExpr"].kind == "shared", "SchemaExpr is held bare somewhere"
    assert not m.classes["MissingExpr"].shared, "MissingExpr is only ever a variant"


@check("adjacently tagged enums put the payload under a content key")
def _adjacent(m: AstModel) -> None:
    basic = m.variants["Type::Basic"]
    assert basic.base == "Type" and basic.tag == "Basic"
    assert basic.fields[0].inline, "Type::Basic's payload is the bare string, not a struct"
    assert basic.fields[0].shape == "str"
    named = m.variants["Type::Named"]
    assert named.fields[0].inline and named.fields[0].shape == "class_ref"
    assert named.fields[0].payload == "Identifier", "Type::Named inlines the Identifier struct"
    literal = m.variants["Type::Literal"]
    assert literal.derived, "LiteralType is tagged again, so the inner tag is derived"
    assert literal.fields[0].shape == "doc"
    # The content key is one name for the whole enum, not one per variant: a
    # struct-payload variant carries its whole struct under it, so the model
    # flattens the struct's own fields and they are *not* read off the wire
    # object directly. `Type::List` is the case that catches a generator which
    # forgets the nesting.
    listy = m.variants["Type::List"]
    assert not listy.fields[0].inline, "a struct payload sits under the content key"
    assert listy.fields[0].shape == "node" and listy.fields[0].payload == "Type"
    assert "ListType" in m.classes, "the struct behind it still needs a decoder"
    nl = m.classes["NumberLit"]
    assert _shape(m, "NumberLit", "value") == "class_ref"
    assert nl.fields[1].payload == "NumberLitValue"
    # ...and it is passed through whole, because the two variants behind it hold
    # bare scalars: there is no struct to decode, so both emitters gate the
    # interface and the loader on `kind`, a `compact_value` class produces
    # neither, and `NumberLit.value` is read as `unknown`. The two fields it
    # *does* carry describe the union -- which variant, and the scalar -- and
    # are not wire keys, which is what the pass-through shapes say.
    lit_value = m.classes["NumberLitValue"]
    assert lit_value.kind == KIND_COMPACT_VALUE, "a bare scalar union is not a struct"
    assert m.enums["NumberLitValue"].kind == KIND_COMPACT_VALUE
    assert lit_value.kind != KIND_COMPACT_NODE, "a compact *node* does get a wrapper type"
    assert all(f.shape in ("str", "verbatim") for f in lit_value.fields)


@check("fieldless enums are bare JSON strings")
def _bare(m: AstModel) -> None:
    for name in ("BinOp", "CmpOp", "UnaryOp", "AugOp", "ExprContext", "ConfigEntryOperation"):
        em = m.enums[name]
        assert em.kind == "op_enum", f"{name} lost its fieldless-enum kind"
        assert em.fields == [], f"{name} is fieldless, so it has no fields to decode"
    # A `NodeRef<BinOp>` and a `Vec<CmpOp>` are both copied, not mapped: the
    # value on the wire *is* the payload, with no wrapper to descend through.
    binary = m.variants["Expr::Binary"]
    assert [f.shape for f in binary.fields] == ["node", "op", "node"]
    compare = m.variants["Expr::Compare"]
    assert [f.shape for f in compare.fields] == ["node", "op_list", "node_list"]


@check("NodeRef is optional at two levels, and Vec<Option<..>> keeps its nulls")
def _node_ref(m: AstModel) -> None:
    args = m.classes["Arguments"]
    by_name = {f.name: f.shape for f in args.fields}
    # `args` is `Vec<NodeRef<Identifier>>`: no nulls, so a plain list.
    assert by_name["args"] == "node_list"
    # `defaults` is `Vec<Option<NodeRef<Expr>>>`: the null is a *slot*, and the
    # slots line up with `args`. A decoder that filters them shifts every
    # default one to the left, which looks like a correct decode.
    assert by_name["defaults"] == SHAPE_OPT_NODE_LIST
    assert by_name["ty_list"] == SHAPE_OPT_NODE_LIST


@check("Option<Vec<T>> is three-state in the type and two on the wire")
def _opt_vec(m: AstModel) -> None:
    """`crates/parser/src/parser/ty.rs` never builds `Some(vec![])`.

    So the field has exactly two reachable values, and the model must not
    invent the third by reading it as a plain `Vec`.
    """
    assert _shape(m, "FunctionType", "params_ty") == SHAPE_OPT_VEC
    assert m.classes["FunctionType"].fields[0].payload == "Type"


@check("Vec<Node<String>> is a list, not a list of optional nodes")
def _node_string_list(m: AstModel) -> None:
    """The classifier has to look at the element type, not the shape name.

    `Identifier.names` and `Arguments.defaults` are both `Vec` of a node; only
    one of them can hold a null.
    """
    ident = m.classes["Identifier"]
    names = [f for f in ident.fields if f.name == "names"][0]
    assert names.shape == "node_list" and names.payload == "String"


@check("Comment's payload is the struct, not the text")
def _comment(m: AstModel) -> None:
    comment = m.classes["Comment"]
    assert [f.name for f in comment.fields] == ["text"], "Comment has exactly one field"
    assert _shape(m, "Comment", "text") == "str"


@check("every tagged variant has a class and every class has a module")
def _placement(m: AstModel) -> None:
    for name, em in m.enums.items():
        if em.kind != "root":
            continue
        for tag in em.variants:
            assert f"{name}::{tag}" in m.variants, f"{name}::{tag} has no class"
    for cm in list(m.classes.values()) + list(m.variants.values()):
        assert cm.module, f"{cm.rust_name} has no module"
        assert cm.module.startswith("_"), f"{cm.rust_name}: {cm.module}"


@check("every field's wire name is unique within its class")
def _unique_wire(m: AstModel) -> None:
    for cm in list(m.classes.values()) + list(m.variants.values()):
        wires = [f.wire for f in cm.fields]
        assert len(wires) == len(set(wires)), f"{cm.rust_name}: {wires}"


@check("class names follow the Java binding")
def _naming_matches_java(m: AstModel) -> None:
    """The naming reference is `java/src/main/java/com/kcl/ast/`, not `ast.rs`.

    The agreement is one-directional and that is the point: every name the
    generator emits is spelled the way the Java binding spells it, so a reader
    who knows the Java AST knows this one. The other direction cannot hold --
    Java defines types `ast.rs` has no counterpart for -- so those are listed
    in `JAVA_ONLY` and compared as a set, which turns "somebody renamed a class
    after Rust" into a failed self-test rather than a naming divergence that
    takes a comment to explain.

    `CLASS_NAME_OVERRIDES` is empty for the same reason: with 60+ names
    agreeing and the rest accounted for in one list, an override table would
    only be a second place for the same fact to go stale.
    """
    if not os.path.isdir(JAVA_AST_DIR):
        # Not a failure. The generator does not read the Java binding; it is
        # checked *against* it, and a checkout without one has nothing to
        # compare to.
        return
    java = {f[:-5] for f in os.listdir(JAVA_AST_DIR) if f.endswith(".java")}
    mine = {cm.name for cm in m.classes.values()}
    mine |= {cm.name for cm in m.variants.values()}
    mine |= set(m.enums)

    stray = sorted(n for n in mine if n not in java)
    assert not stray, f"named after Rust, not Java: {stray}"
    gone = sorted(JAVA_ONLY - java)
    assert not gone, f"JAVA_ONLY lists names the Java binding does not have: {gone}"
    added = sorted((java - mine) - JAVA_ONLY)
    assert not added, (
        f"new in the Java binding, not emitted here: {added}. Either add it to "
        "JAVA_ONLY with a reason, or emit it."
    )
    # The four aliases are the one place a Java name is emitted as a second
    # name for a class rather than as a class of its own, and they are easy to
    # drop by accident because nothing in `ast.rs` mentions them.
    for rust_name, alias in list(LEGACY_ALIASES.items()):
        for name in alias:
            assert name in java, f"{name} is not in the Java binding"
            assert rust_name in mine, f"{name} is an alias of a class we do not emit"
    for rust_name, alias in VARIANT_ALIASES.items():
        assert alias in java, f"{alias} is not in the Java binding"
        assert rust_name in mine, f"{alias} is an alias of a class we do not emit"


# ---------------------------------------------------------------------------
# determinism
# ---------------------------------------------------------------------------


def _generate(source: str) -> dict:
    """Everything, from an independent parse of `source`."""
    crate = parse_crate(source)
    model = build(crate)
    files = {}
    py = PythonEmitter(model)
    for module in PY_MODULES:
        files[f"python/kcl_lib/ast/{module}.py"] = py.emit_module(module)
    files["python/kcl_lib/ast/__init__.py"] = py.emit_package_init()
    ts = TypeScriptEmitter(model)
    for name in TS_FILES:
        files[f"wasm/src/ast/{name}"] = ts.emit(name)
    return files


def _determinism(source: str) -> None:
    first = _generate(source)
    second = _generate(source)
    assert sorted(first) == sorted(second), "the same source produced two file lists"
    for name in sorted(first):
        if first[name] != second[name]:
            import difflib

            diff = difflib.unified_diff(
                first[name].splitlines(),
                second[name].splitlines(),
                fromfile=f"pass 1: {name}",
                tofile=f"pass 2: {name}",
                n=2,
            )
            raise AssertionError("not byte-identical across two runs:\n" + "\n".join(diff))
    print(f"    determinism: {len(first)} files byte-identical across two runs")


def _header(source: str) -> None:
    files = _generate(source)
    for name, text in sorted(files.items()):
        head = text.split("\n", 6)[:6]
        assert any("generated by" in line.lower() for line in head), f"{name}: no header"
        assert any("DO NOT EDIT" in line for line in head), f"{name}: no DO NOT EDIT"
    print(f"    headers: all {len(files)} files say generated / do not edit")


def _no_tabs(source: str) -> None:
    """Trailing whitespace and tabs are invisible in review and fatal in diffs."""
    for name, text in sorted(_generate(source).items()):
        for i, line in enumerate(text.split("\n"), 1):
            assert "\t" not in line, f"{name}:{i}: tab"
            assert line == line.rstrip(), f"{name}:{i}: trailing whitespace"


# ---------------------------------------------------------------------------


def run() -> int:
    from .cli import DEFAULT_AST_RS

    if not os.path.exists(DEFAULT_AST_RS):
        print(f"ast.rs not found at {DEFAULT_AST_RS}", file=sys.stderr)
        return 2
    model = build(parse_crate(DEFAULT_AST_RS))
    # The model invariants and the output checks are driven the same way, and
    # both catch *anything* rather than only `AssertionError`. An invariant
    # that raises `KeyError` on a class `ast.rs` no longer declares is a
    # failure of this generator -- the parser dropped something -- and it has
    # to be reported as one. Letting it escape would abort the run, and every
    # check after it would go unreported, which is the one thing a self-test
    # must not do.
    checks = [(name, (lambda fn=fn: fn(model))) for name, fn in _REGISTRY] + [
        (name, (lambda fn=fn: fn(DEFAULT_AST_RS)))
        for name, fn in (("determinism", _determinism), ("headers", _header), ("whitespace", _no_tabs))
    ]
    failures = 0
    for name, fn in checks:
        try:
            fn()
        except Exception as exc:  # noqa: BLE001 -- see above
            failures += 1
            detail = str(exc) or type(exc).__name__
            print(f"FAIL  {name}: {detail}", file=sys.stderr)
        else:
            print(f"ok    {name}")
    if failures:
        print(f"\n{failures} self-test(s) failed", file=sys.stderr)
        return 1
    print(f"\nall {len(checks)} self-tests passed")
    return 0

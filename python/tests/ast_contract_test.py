"""The Python AST wire contract, asserted.

``kcl_lib.ast`` is a hand-written decoder for the JSON the KCL parser emits,
and a wrong guess about that JSON fails *silently*: an object with no ``type``
key falls through to :class:`UnknownExpr`, so a binding keyed on
``"CheckExpression"`` — the spelling ``Expr::get_expr_name()`` returns, which
is a diagnostic name and not the serde tag — still returns a
plausible-looking tree full of unknowns.

These tests decode ``testdata/ast/alignment.json`` — the real parser's output
for ``testdata/ast/alignment.k``, which exercises every node shape — and assert
the contract documented in that directory's README. Decoding the captured JSON
rather than calling ``api.parse_file`` keeps this a pure test of the decoder:
it needs no native runtime, and it does not depend on the parser staying
byte-identical.
"""

from __future__ import annotations

import dataclasses
import json
import os
import sys
import types

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
_GOLDEN = os.path.join(_ROOT, os.pardir, "testdata", "ast", "alignment.json")

# `kcl_lib/__init__.py` does `from ._kcl_lib import *`, so importing anything
# under the package pulls in the native extension. The AST subpackage does not
# use it, so when the extension is missing, register a stub carrying the real
# search path and skip the real `__init__` — that keeps this test runnable
# without a built `_kcl_lib`. When the extension *is* built, nothing is stubbed
# and the rest of the suite is unaffected.
try:
    import kcl_lib.ast  # noqa: F401
except ImportError:
    for _name in [n for n in sys.modules if n == "kcl_lib" or n.startswith("kcl_lib.")]:
        del sys.modules[_name]
    _stub = types.ModuleType("kcl_lib")
    _stub.__path__ = [os.path.join(_HERE, os.pardir, "kcl_lib")]
    sys.modules["kcl_lib"] = _stub

from kcl_lib.ast import (  # noqa: E402
    AnyType,
    AssignStmt,
    BasicType,
    CallExpr,
    CheckExpr,
    Comment,
    Compare,
    CompClause,
    ConfigEntry,
    ConfigEntryOperation,
    ConfigExpr,
    ConfigIfEntryExpr,
    Decorator,
    DictComp,
    DictType,
    Expr,
    ExprStmt,
    FormattedValue,
    FunctionType,
    Identifier,
    IfExpr,
    IfStmt,
    ImportStmt,
    JoinedString,
    Keyword,
    LambdaExpr,
    ListComp,
    ListExpr,
    ListIfItemExpr,
    ListType,
    LiteralType,
    Module,
    NamedType,
    NumberLit,
    QuantExpr,
    RuleStmt,
    SchemaAttr,
    SchemaExpr,
    SchemaIndexSignature,
    SchemaStmt,
    SelectorExpr,
    StarredExpr,
    StringLit,
    Subscript,
    Target,
    TypeAliasStmt,
    UnaryExpr,
    UnknownExpr,
    UnknownStmt,
    UnknownType,
    UnionType,
    UnificationStmt,
    parse_module,
    stmt_from_dict,
)
from kcl_lib.ast import _dto, _expr, _stmt, _types  # noqa: E402


# --- fixtures -----------------------------------------------------------

with open(_GOLDEN) as _f:
    _GOLDEN_JSON = json.load(_f)

GOLDEN: Module = parse_module(json.dumps(_GOLDEN_JSON))


def assigned(name: str) -> AssignStmt:
    """The top-level statement whose assignment target is ``name``."""
    for wrapped in GOLDEN.body:
        s = wrapped.node
        if isinstance(s, AssignStmt) and s.targets:
            target = s.targets[0].node
            if isinstance(target, Target) and target.dotted_name() == name:
                return s
    raise AssertionError(f"no top-level assignment to {name!r}")


def assigned_expr(name: str) -> Expr:
    """The expression assigned to ``name`` in ``name = <expr>``."""
    return assigned(name).value.node


def find_schema(name: str) -> SchemaStmt:
    for wrapped in GOLDEN.body:
        s = wrapped.node
        if isinstance(s, SchemaStmt) and s.schema_name() == name:
            return s
    raise AssertionError(f"no top-level schema named {name!r}")


def find_type_alias(name: str) -> TypeAliasStmt:
    for wrapped in GOLDEN.body:
        s = wrapped.node
        if isinstance(s, TypeAliasStmt) and s.type_name.node.names[0].node == name:
            return s
    raise AssertionError(f"no top-level type alias named {name!r}")


def find_import() -> list:
    return [w.node for w in GOLDEN.body if isinstance(w.node, ImportStmt)]


def int_literal(n: int) -> NumberLit:
    return NumberLit(value=_expr.NumberLitValue(kind="Int", value=n))


# --- the walk that catches everything -----------------------------------


def _children(node):
    if isinstance(node, (list, tuple)):
        return list(node)
    if isinstance(node, _dto.MemberOrIndex):
        return [node.node]
    if dataclasses.is_dataclass(node):
        return [getattr(node, f.name) for f in dataclasses.fields(node)]
    return []


def expect_no_unknown(node, path: str = "module") -> list:
    """Walk the whole tree and collect every tag this build does not know.

    This is the assertion that makes the rest trustworthy. A registry keyed on
    the wrong string still produces a tree — every field just decodes to
    ``None`` — so field-by-field assertions alone would pass on a decoder that
    resolves nothing.
    """
    bad: list = []
    if isinstance(node, (UnknownExpr, UnknownStmt, UnknownType)):
        return [f"{path}: unknown {type(node).__name__}({node.tag!r})"]
    if isinstance(node, _expr.UnknownExpr):
        return [f"{path}: unknown Expr variant {node.tag!r}"]
    if isinstance(node, _stmt.UnknownStmt):
        return [f"{path}: unknown Stmt variant {node.tag!r}"]
    if isinstance(node, _types.UnknownType):
        return [f"{path}: unknown Type variant {node.tag!r}"]
    for i, child in enumerate(_children(node)):
        if child is None or isinstance(child, (str, int, float, bool)):
            continue
        suffix = f"[{i}]" if isinstance(node, (list, tuple)) else ""
        bad += expect_no_unknown(child, f"{path}{suffix}")
    return bad


def test_no_unknown_variants_anywhere_in_the_golden_module():
    bad = expect_no_unknown(GOLDEN)
    assert not bad, "decoder produced unknown variants:\n  " + "\n  ".join(bad)


# --- Expr: the tag is the variant name, verbatim ------------------------


def test_expr_tag_is_the_variant_name_not_the_diagnostic_name():
    """`Expr::get_expr_name()` returns "CheckExpression"; serde emits
    "Check". Keying the registry on the former resolves nothing."""
    assert "Check" in _expr._EXPR_REGISTRY
    assert "CheckExpression" not in _expr._EXPR_REGISTRY
    # Same trap for the literal variants: "NumberLit", not the short-form
    # `Literal` enum's "Number" nor the long-form "NumberLitExpression".
    assert "NumberLit" in _expr._EXPR_REGISTRY
    assert "Number" not in _expr._EXPR_REGISTRY
    assert "NumberLitExpression" not in _expr._EXPR_REGISTRY
    assert "StringLit" in _expr._EXPR_REGISTRY
    assert "String" not in _expr._EXPR_REGISTRY


def test_expr_variant_fields_are_flattened_next_to_the_tag():
    """An internally-tagged newtype flattens its struct into the same object —
    there is no wrapper key to unwrap, so looking for one finds nothing and
    every field decodes to ``None``."""
    raw = _GOLDEN_JSON["body"][_index_of("lit_int")]["node"]["value"]["node"]
    assert raw["type"] == "NumberLit"
    # `binary_suffix` and `value` sit directly on the tagged object.
    assert set(raw) == {"type", "binary_suffix", "value"}

    lit = assigned_expr("lit_int")
    assert isinstance(lit, NumberLit)
    assert lit.value.kind == "Int"


def _index_of(name: str) -> int:
    for i, s in enumerate(_GOLDEN_JSON["body"]):
        n = s["node"]
        if n.get("type") == "Assign":
            if n["targets"][0]["node"]["name"]["node"] == name:
                return i
    raise AssertionError(name)


# --- literals -----------------------------------------------------------


def test_number_literal_carries_a_nested_tagged_value():
    lit = assigned_expr("lit_int")
    assert isinstance(lit, NumberLit)
    # `NumberLitValue` is itself `tag = "type", content = "value"`.
    assert lit.value.kind == "Int"
    assert lit.value.int_value() == 1
    assert lit.value.float_value() is None
    assert lit.binary_suffix is None

    f = assigned_expr("lit_float")
    assert isinstance(f, NumberLit)
    assert f.value.kind == "Float"
    assert f.value.float_value() == 1.5
    assert f.value.int_value() is None


def test_name_constant_value_is_a_bare_string_not_a_json_bool():
    """`NameConstant` is a fieldless enum, so `True` serializes as the string
    "True" — not JSON `true`."""
    lit = assigned_expr("lit_name")
    assert isinstance(lit, _expr.NameConstantLit)
    assert lit.value == "True"


def test_string_literal_keeps_both_raw_and_decoded_value():
    lit = assigned_expr("lit_str")
    assert isinstance(lit, StringLit)
    assert lit.value == "s"
    assert lit.raw_value == '"s"'
    assert lit.is_long_string is False

    long_lit = assigned_expr("lit_long")
    assert isinstance(long_lit, StringLit)
    assert long_lit.is_long_string is True


def test_joined_string_parts_are_a_mixed_expression_list():
    j = assigned_expr("joined")
    assert isinstance(j, JoinedString)
    assert len(j.values) == 2
    assert isinstance(j.values[0].node, StringLit)
    fv = j.values[1].node
    assert isinstance(fv, FormattedValue)
    # `format_spec` is `Option<String>`, not an expression.
    assert fv.format_spec is None
    assert fv.is_long_string is False


# --- identifiers: untagged even inside a tagged node -------------------


def test_selector_attr_is_an_identifier_not_an_expression():
    sel = assigned_expr("selector")
    assert isinstance(sel, SelectorExpr)
    # The node itself is tagged `Selector`, but `attr` is a bare struct.
    assert isinstance(sel.attr.node, Identifier)
    assert sel.attr.node.dotted_name() == "name"
    assert sel.has_question is False


def test_dotted_name_is_one_identifier_with_several_names():
    """`x.name` inside `${...}` is a single Identifier with two names; a
    Selector only appears once there is a subscript or a `?`."""
    j = assigned_expr("joined")
    fv = j.values[1].node
    inner = fv.value.node
    assert isinstance(inner, Identifier)
    assert [n.node for n in inner.names] == ["x", "name"]
    assert inner.dotted_name() == "x.name"


def test_optional_selector_sets_has_question():
    sel = assigned_expr("optional")
    assert isinstance(sel, SelectorExpr)
    assert sel.has_question is True


# --- subscripts ---------------------------------------------------------


def test_subscript_index_lower_upper_step_are_distinct():
    plain = assigned_expr("subscript")
    assert isinstance(plain, Subscript)
    assert plain.index is not None
    assert plain.lower is None and plain.upper is None and plain.step is None

    sl = assigned_expr("subscript_slice")
    assert isinstance(sl, Subscript)
    assert sl.index is None
    assert sl.lower.node == int_literal(0)
    assert sl.upper.node == int_literal(2)
    assert sl.step is None

    st = assigned_expr("subscript_step")
    assert isinstance(st, Subscript)
    assert st.step is not None
    assert st.step.node == int_literal(1)


# --- operators ----------------------------------------------------------


def test_compare_ops_and_comparators_are_parallel_lists():
    c = assigned_expr("compare_chain")
    assert isinstance(c, Compare)
    assert c.ops == ["Lt", "LtE"]
    assert len(c.comparators) == 2


def test_unary_op_is_a_bare_string():
    """`+`/`-` are `UAdd`/`USub` upstream — distinct from `BinOp::Add` and
    `AugOp::Add`, and the parser emits the `U` prefix."""
    u = assigned_expr("unary")
    assert isinstance(u, UnaryExpr)
    assert u.op == "USub"
    assert u.operand is not None
    not_ = assigned_expr("unary_not")
    assert isinstance(not_, UnaryExpr)
    assert not_.op == "Not"


# --- calls, keywords, arguments -----------------------------------------


def test_keyword_arg_is_an_identifier_and_values_are_expressions():
    c = assigned_expr("call")
    assert isinstance(c, CallExpr)
    assert len(c.args) == 2
    assert len(c.keywords) == 1
    kw = c.keywords[0].node
    assert isinstance(kw, Keyword)
    assert isinstance(kw.arg.node, Identifier)
    assert kw.arg.node.dotted_name() == "k"
    assert kw.value.node == int_literal(3)


def test_arguments_ty_list_keeps_positional_nulls():
    """`defaults` and `ty_list` are `Vec<Option<NodeRef<...>>>`: the slot
    exists even when the parameter has no default, because both are
    index-aligned with `args`."""
    lam = assigned_expr("lambda_expr")
    assert isinstance(lam, LambdaExpr)
    args = lam.args.node
    assert len(args.args) == 1
    # `lambda p: int -> int { p }` — no default, so slot 0 is null, but the
    # annotation is at slot 0 and must not be shifted.
    assert len(args.defaults) == 1
    assert args.defaults[0] is None
    assert len(args.ty_list) == 1
    assert isinstance(args.ty_list[0].node, BasicType)
    assert args.ty_list[0].node.name == "Int"
    assert isinstance(lam.return_ty.node, BasicType)
    assert lam.return_ty.node.name == "Int"


def test_lambda_body_is_statements_not_expressions():
    lam = assigned_expr("lambda_plain")
    assert isinstance(lam, LambdaExpr)
    assert lam.args is None
    assert lam.return_ty is None
    assert len(lam.body) == 1
    # `lambda { a }` parses to a `Stmt::Expr`, not a bare `Expr`.
    assert isinstance(lam.body[0].node, ExprStmt)
    assert isinstance(lam.body[0].node.exprs[0].node, Identifier)


# --- collections --------------------------------------------------------


def test_list_comprehension_generators_are_comp_clauses():
    lc = assigned_expr("list_if")
    assert isinstance(lc, ListComp)
    assert len(lc.generators) == 1
    gen = lc.generators[0].node
    assert isinstance(gen, CompClause)
    # `targets` are identifiers and the iterable field is spelled `iter`.
    assert isinstance(gen.targets[0].node, Identifier)
    assert gen.targets[0].node.dotted_name() == "i"
    assert gen.iter.node.dotted_name() == "list_lit"
    assert len(gen.ifs) == 1


def test_dict_comp_entry_is_a_bare_config_entry():
    """Rust declares `pub entry: ConfigEntry`, not `NodeRef<ConfigEntry>`, so
    there is no `{"node": ...}` wrapper to unwrap."""
    dc = assigned_expr("dict_comp")
    assert isinstance(dc, DictComp)
    assert isinstance(dc.entry, ConfigEntry)
    assert dc.entry.key.node.dotted_name() == "k"
    assert dc.entry.value.node.dotted_name() == "v"
    assert dc.entry.operation == "Union"
    assert len(dc.generators) == 1
    assert isinstance(dc.generators[0].node, CompClause)


def test_list_if_item_has_its_own_if_cond_exprs_and_orelse():
    lst = assigned_expr("list_if_entry")
    assert isinstance(lst, ListExpr)
    item = lst.elts[0].node
    assert isinstance(item, ListIfItemExpr)
    assert item.if_cond.node.dotted_name() == "a"
    assert item.exprs[0].node == int_literal(1)
    # `orelse` is a whole nested list expression, not a list of them.
    assert isinstance(item.orelse.node, ListExpr)
    assert item.orelse.node.elts[0].node == int_literal(2)


def test_starred_expr_unwraps_to_its_value():
    lst = assigned_expr("starred")
    assert isinstance(lst, ListExpr)
    assert isinstance(lst.elts[0].node, StarredExpr)
    assert lst.elts[0].node.value.node.dotted_name() == "list_lit"
    assert len(lst.elts) == 2


def test_quant_variables_are_identifiers():
    q = assigned_expr("quant")
    assert isinstance(q, QuantExpr)
    assert q.op == "All"
    assert q.target.node.dotted_name() == "list_lit"
    assert isinstance(q.variables[0].node, Identifier)
    assert q.variables[0].node.dotted_name() == "v"
    assert q.if_cond is None


# --- config entries -----------------------------------------------------


def test_config_entry_operation_and_shorthand_flag():
    cfg = assigned_expr("config")
    assert isinstance(cfg, ConfigExpr)
    assert [e.node.operation for e in cfg.items] == [
        ConfigEntryOperation.Override.value,
        ConfigEntryOperation.Union.value,
    ]
    # `{a = 1, b: 2}` is explicit on both sides, so the shorthand flag is
    # absent on the wire (`skip_serializing_if = "is_false"`).
    assert all(e.node.is_shorthand is False for e in cfg.items)
    assert "is_shorthand" not in cfg.items[0].node.to_dict()


def test_config_shorthand_entries_set_the_flag():
    cfg = assigned_expr("config_shorthand")
    assert isinstance(cfg, ConfigExpr)
    assert [e.node.key.node.dotted_name() for e in cfg.items] == ["lit_int", "lit_str"]
    assert all(e.node.is_shorthand for e in cfg.items)
    assert cfg.items[0].node.to_dict()["is_shorthand"] is True


def test_config_if_entry_owns_its_branch_items():
    cfg = assigned_expr("config_if")
    assert isinstance(cfg, ConfigExpr)
    # The `if` is wrapped in a key-less entry, then the real branch follows.
    wrapper = cfg.items[0].node
    assert wrapper.key is None
    branch = wrapper.value.node
    assert isinstance(branch, ConfigIfEntryExpr)
    assert branch.if_cond.node.dotted_name() == "a"
    assert len(branch.items) == 1
    assert branch.items[0].node.key.node.dotted_name() == "c"
    # `orelse` is a whole config expression, not a second branch object.
    assert isinstance(branch.orelse.node, ConfigExpr)
    assert branch.orelse.node.items[0].node.key.node.dotted_name() == "c"


def test_ternary_is_the_if_expression_not_the_if_statement():
    e = assigned_expr("tern")
    assert isinstance(e, IfExpr)
    assert e.body.node.dotted_name() == "a"
    assert e.cond.node.dotted_name() == "a"
    assert e.orelse.node == int_literal(2)


# --- statements ---------------------------------------------------------


def test_import_stmt_is_a_flat_struct_with_the_real_field_names():
    imports = find_import()
    assert len(imports) == 2
    first, second = imports
    # Not `as_name` / `pkg_root`, and no `{"node": ...}` wrapper.
    assert first.rawpath == "data.cloud"
    assert first.path.node == "data.cloud"
    assert first.name == "cloud"
    assert first.asname is None
    assert first.pkg_name == "__main__"
    # `asname` is `Option<Node<String>>` — an alias still carries a position.
    assert second.asname is not None
    assert second.asname.node == "fb"
    assert second.asname.pos.line == 17
    assert second.name == "fb"


def test_type_alias_uses_type_name_and_ty():
    alias = find_type_alias("TUnion")
    assert isinstance(alias.type_name.node, Identifier)
    assert isinstance(alias.ty.node, UnionType)
    assert [e.node.name for e in alias.ty.node.type_elements] == ["Int", "Str"]


def test_assign_with_type_annotation():
    """`a: int = 3` sets `ty`, which is a `NodeRef<Type>` and not part of the
    two other `a = ...` assignments in the fixture."""
    annotated = [
        w.node for w in GOLDEN.body if isinstance(w.node, AssignStmt) and w.node.ty
    ]
    assert len(annotated) == 1
    assert isinstance(annotated[0].ty.node, BasicType)
    assert annotated[0].ty.node.name == "Int"
    assert annotated[0].targets[0].node.dotted_name() == "a"


def test_unification_value_is_a_schema_expr_with_no_tag():
    u = [w.node for w in GOLDEN.body if isinstance(w.node, UnificationStmt)]
    assert len(u) == 1
    assert isinstance(u[0].target.node, Identifier)
    assert isinstance(u[0].value.node, SchemaExpr)
    assert isinstance(u[0].value.node.name.node, Identifier)
    assert isinstance(u[0].value.node.config.node, ConfigExpr)


def test_if_statement_orelse_is_a_flat_sibling_list():
    st = [w.node for w in GOLDEN.body if isinstance(w.node, IfStmt)]
    assert len(st) == 1
    assert len(st[0].body) == 1
    # `else:` is a sibling list, not a nested IfStmt — the elif chain lives
    # here too.
    assert len(st[0].orelse) == 1
    assert isinstance(st[0].orelse[0].node, AssignStmt)


def test_aug_assign_target_is_a_target_struct():
    a = [w.node for w in GOLDEN.body if type(w.node).__name__ == "AugAssignStmt"]
    assert len(a) == 1
    assert a[0].op == "Add"
    assert isinstance(a[0].target.node, Target)
    assert a[0].target.node.dotted_name() == "a"


def test_member_and_index_paths_on_an_assignment_target():
    """`x.name.deep = ...` and `x[0] = ...` — `paths` is `Vec<MemberOrIndex>`,
    an adjacently-tagged enum whose payload is a NodeRef."""
    dotted = None
    indexed = None
    for wrapped in GOLDEN.body:
        s = wrapped.node
        if not isinstance(s, AssignStmt) or not s.targets:
            continue
        t = s.targets[0].node
        if not isinstance(t, Target):
            continue
        if len(t.paths) == 2:
            dotted = t
        elif len(t.paths) == 1 and t.paths[0].kind == "Index":
            indexed = t
    assert dotted is not None
    assert [p.kind for p in dotted.paths] == ["Member", "Member"]
    assert dotted.paths[0].node.node == "name"
    assert dotted.paths[1].node.node == "deep"
    assert indexed is not None
    assert indexed.paths[0].node.node == int_literal(0)


# --- schemas ------------------------------------------------------------


def test_schema_stmt_decorators_are_flat_call_expressions():
    """`SchemaAttr.decorators` (and `SchemaStmt.decorators`) is
    `Vec<NodeRef<CallExpr>>`, so a decorator has no `"type":"Call"` tag — it
    is the same `CallExpr` class, untagged."""
    person = find_schema("Person")
    assert person.is_protocol is False
    # The `@deprecated` / `@info` in the fixture are on the `name` attribute,
    # not on the schema itself, so the schema's own list is empty.
    assert person.decorators == []
    name_attr = next(
        w.node for w in person.body if isinstance(w.node, SchemaAttr)
    )
    assert [d.node.func.node.dotted_name() for d in name_attr.decorators] == [
        "deprecated",
        "info",
    ]
    assert all(isinstance(d.node, Decorator) for d in name_attr.decorators)
    # `Decorator is CallExpr` — one class, two positions.
    assert Decorator is CallExpr
    assert name_attr.decorators[1].node.keywords[0].node.arg.node.dotted_name() == "kwargs"


def test_schema_checks_are_flat_check_expressions():
    """`SchemaStmt.checks` is `Vec<NodeRef<CheckExpr>>`, so a check has no
    `"type":"Check"` tag — same `CheckExpr` class, untagged."""
    person = find_schema("Person")
    assert len(person.checks) == 2
    assert all(isinstance(c.node, CheckExpr) for c in person.checks)
    # `age >= 0, "..."` — a message but no condition.
    assert person.checks[0].node.if_cond is None
    assert person.checks[0].node.msg.node.value == "age must be non-negative"
    # `age < 200 if age, "..."` — both.
    assert person.checks[1].node.if_cond is not None
    assert isinstance(person.checks[1].node.msg.node, StringLit)


def test_schema_attr_carries_its_type_optionality_and_decorators():
    person = find_schema("Person")
    attrs = {w.node.name.node: w.node for w in person.body if isinstance(w.node, SchemaAttr)}
    assert set(attrs) == {"name", "age"}
    name = attrs["name"]
    assert isinstance(name.ty.node, BasicType)
    assert name.ty.node.name == "Str"
    assert name.is_optional is False
    assert name.doc == ""
    assert [d.node.func.node.dotted_name() for d in name.decorators] == [
        "deprecated",
        "info",
    ]
    age = attrs["age"]
    assert age.is_optional is True
    assert isinstance(age.ty.node, BasicType)
    assert age.ty.node.name == "Int"


def test_schema_index_signature_types_are_node_refs():
    bag = find_schema("Bag")
    assert bag.index_signature is not None
    sig = bag.index_signature.node
    assert isinstance(sig, SchemaIndexSignature)
    assert sig.key_name.node == "k"
    assert sig.any_other is False
    # `value` is an Expr (the index default), while key_ty/value_ty are Types.
    assert isinstance(sig.value.node, NumberLit)
    assert isinstance(sig.key_ty.node, BasicType) and sig.key_ty.node.name == "Str"
    assert isinstance(sig.value_ty.node, BasicType) and sig.value_ty.node.name == "Int"


def test_rule_statement_checks_and_parent_rules():
    rules = [w.node for w in GOLDEN.body if isinstance(w.node, RuleStmt)]
    assert len(rules) == 1
    assert rules[0].name.node == "R"
    assert rules[0].parent_rules == []
    assert len(rules[0].checks) == 1
    assert isinstance(rules[0].checks[0].node, CheckExpr)


def test_schema_expr_instantiation():
    """`Person { ... }` is `Expr::Schema`; the braces are a *config*, not
    call keywords — `kwargs` stays empty and the entries land in `config`."""
    x = assigned_expr("x")
    assert isinstance(x, SchemaExpr)
    assert x.name.node.dotted_name() == "Person"
    assert x.args == []
    assert x.kwargs == []
    assert isinstance(x.config.node, ConfigExpr)
    assert [e.node.key.node.dotted_name() for e in x.config.node.items] == [
        "name",
        "age",
    ]

    # `Person(1, name = "Bob")` uses the call syntax, so it is a plain
    # `Expr::Call` — a different variant entirely.
    y = assigned_expr("y")
    assert isinstance(y, CallExpr)
    assert y.func.node.dotted_name() == "Person"
    assert len(y.args) == 1
    assert [k.node.arg.node.dotted_name() for k in y.keywords] == ["name"]


# --- Type: adjacently tagged, and the tag names the shape --------------


def test_type_is_adjacently_tagged_with_the_tag_naming_the_shape():
    assert isinstance(find_type_alias("TAny").ty.node, AnyType)
    assert isinstance(find_type_alias("TBasic").ty.node, BasicType)
    assert isinstance(find_type_alias("TList").ty.node, ListType)
    assert isinstance(find_type_alias("TDict").ty.node, DictType)
    assert isinstance(find_type_alias("TUnion").ty.node, UnionType)
    assert isinstance(find_type_alias("TFunc").ty.node, FunctionType)
    assert isinstance(find_type_alias("TNamed").ty.node, NamedType)
    assert isinstance(find_type_alias("TLitInt").ty.node, LiteralType)

    # `Any` is the only unit variant: serde emits the bare tag, with no
    # `value` key at all.
    assert _types.type_to_dict(AnyType()) == {"type": "Any"}


def test_basic_type_value_is_a_bare_string():
    """`BasicType` is a fieldless enum, so the payload is `"Int"`, not
    `{"Int": ...}` — keying a registry on `"Int"` yields nothing."""
    t = find_type_alias("TBasic").ty.node
    assert t.name == "Str"
    assert _types.type_to_dict(t) == {"type": "Basic", "value": "Str"}


def test_list_type_inner_is_a_node_ref():
    t = find_type_alias("TList").ty.node
    assert t.inner_type is not None
    assert isinstance(t.inner_type.node, BasicType)
    assert t.inner_type.node.name == "Int"
    # The field is `inner_type`, not `elem_type`.
    assert "elem_type" not in _types.type_to_dict(t)["value"]


def test_union_type_field_is_type_elements():
    t = find_type_alias("TUnion").ty.node
    assert len(t.type_elements) == 2
    # The field is `type_elements`, not `types`.
    assert "type_elements" in _types.type_to_dict(t)["value"]


def test_dict_type_key_and_value():
    t = find_type_alias("TDict").ty.node
    assert t.key_type.node.name == "Str"
    assert t.value_type.node.name == "Int"


def test_function_type_params_and_ret():
    t = find_type_alias("TFunc").ty.node
    assert t.params_ty is not None
    assert [p.node.name for p in t.params_ty] == ["Int", "Str"]
    assert t.ret_ty.node.name == "Bool"


def test_named_type_payload_is_a_bare_identifier():
    """`Type::Named(Identifier)` inlines the newtype into `value` — there is
    no extra wrapper key."""
    t = find_type_alias("TNamed").ty.node
    assert isinstance(t.identifier, Identifier)
    assert t.identifier.dotted_name() == "Cloud"
    assert _types.type_to_dict(t)["value"] == {
        "names": _types.type_to_dict(t)["value"]["names"],
        "pkgpath": "",
        "ctx": "Load",
    }


def test_literal_type_nests_a_second_tagged_document():
    """`LiteralType` is itself `tag/content`, so `Type::Literal` wraps another
    tagged enum. The inner shape has no fixed field set — `Int` inlines an
    `IntLiteralType { value, suffix }` while the others are bare scalars —
    which is why it is kept verbatim instead of split per literal kind."""
    for name, kind in [
        ("TLitInt", "Int"),
        ("TLitStr", "Str"),
        ("TLitBool", "Bool"),
        ("TLitFloat", "Float"),
    ]:
        assert find_type_alias(name).ty.node.inner_tag == kind
    assert find_type_alias("TLitInt").ty.node.value["value"] == {"value": 1, "suffix": None}
    assert find_type_alias("TLitStr").ty.node.value["value"] == "s"
    assert find_type_alias("TLitBool").ty.node.value["value"] is True
    assert find_type_alias("TLitFloat").ty.node.value["value"] == 1.5


def test_unknown_type_tag_survives_a_round_trip():
    """A tag this build has never heard of must be preserved, not dropped —
    otherwise a newer parser's output is silently mangled."""
    raw = {"type": "SomeFutureType", "value": {"weird": [1, 2]}}
    decoded = _types.type_from_dict(raw)
    assert isinstance(decoded, UnknownType)
    assert decoded.tag == "SomeFutureType"
    assert _types.type_to_dict(decoded) == raw


def test_unknown_expr_and_stmt_tags_survive_a_round_trip():
    for raw, cls in [
        ({"type": "FutureExpr", "op": "?"}, UnknownExpr),
        ({"type": "FutureStmt", "x": 1}, UnknownStmt),
    ]:
        decoded = (
            _expr.expr_from_dict(raw) if cls is UnknownExpr else stmt_from_dict(raw)
        )
        assert isinstance(decoded, cls)
        out = (
            _expr.expr_to_dict(decoded)
            if cls is UnknownExpr
            else _stmt.stmt_to_dict(decoded)
        )
        assert out == raw


# --- module and round trip ----------------------------------------------


def test_module_has_no_pkg_field():
    assert not hasattr(GOLDEN, "pkg")
    assert "pkg" not in GOLDEN.to_dict()
    assert GOLDEN.filename.endswith("alignment.k")
    assert GOLDEN.doc is None
    assert GOLDEN.body


def test_filter_schemas_finds_both_schemas():
    assert [s.schema_name() for s in GOLDEN.filter_schemas()] == ["Person", "Bag"]


def test_comment_payload_is_an_object_not_the_bare_text():
    """`Comment` is a plain struct with one `String` field, so the object under
    `node` is `{"text": "…"}` — one level in from the wrapper.

    Getting this wrong is silent in both directions and neither shows up in a
    name-and-type cross-check: a decoder that unwraps `node` again reads a key
    the payload does not have, and one that reads the payload as the text gets
    an object where it promised a string. Both yield `""` for every comment in
    the file. Hence the non-empty assertion, not just the shape.
    """
    comments = GOLDEN.comments
    assert comments, "the golden module carries comments"
    for wrapped, raw in zip(comments, _GOLDEN_JSON["comments"]):
        # The wrapper is one level out; the payload is a dict, not a str.
        assert isinstance(raw["node"], dict), f"expected a payload object, got {raw['node']!r}"
        assert isinstance(wrapped.node, Comment)
        assert wrapped.node.text == raw["node"]["text"]
        assert wrapped.node.text, "a comment must not decode to the empty string"
        assert wrapped.node.text.lstrip().startswith("#")


def test_comment_round_trip_is_a_fixed_point():
    assert GOLDEN.to_dict()["comments"] == _GOLDEN_JSON["comments"]


def test_bare_expression_statement():
    """The bare `a + 1` is `Stmt::Expr`.

    Found by shape rather than by position: `alignment.k` is shared with every
    other binding's alignment test and keeps growing at the end, so pinning this
    to `body[-1]` makes it fail each time a new trailing section is appended.
    """
    bare = [w.node for w in GOLDEN.body if isinstance(w.node, ExprStmt)]
    assert len(bare) == 1, f"expected exactly one bare expression statement, got {len(bare)}"
    (stmt,) = bare
    assert len(stmt.exprs) == 1
    assert isinstance(stmt.exprs[0].node, _expr.BinaryExpr)


def test_round_trip_is_a_fixed_point():
    """dump -> parse -> dump must be stable. Any field the decoder drops shows
    up here as a difference, which is why this catches omissions a targeted
    field assertion would miss."""
    once = GOLDEN.to_dict()
    twice = parse_module(json.dumps(once)).to_dict()
    assert twice == once
    thrice = parse_module(json.dumps(twice)).to_dict()
    assert thrice == twice


def test_round_trip_preserves_every_statement_tag():
    def tags(module):
        # `to_dict()["body"]` is a list of `Node` wrappers; the tag lives on
        # the payload inside each one.
        return [stmt["node"]["type"] for stmt in module.to_dict()["body"]]

    # Re-serialising must not invent a tag for the positions that are flat on
    # the wire, nor drop one from the positions that have it.
    assert tags(GOLDEN) == [s["node"]["type"] for s in _GOLDEN_JSON["body"]]
    assert tags(parse_module(json.dumps(_GOLDEN_JSON))) == tags(GOLDEN)

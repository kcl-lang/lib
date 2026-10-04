-- ast.lua — Typed AST package for the Lua binding.
--
-- Wire shape follows `kcl-lang/kcl crates/ast/src/ast.rs`. There are three
-- serde shapes, and getting any of them wrong fails *silently* — an object
-- with no `type` key decodes to nil rather than raising — so they are spelled
-- out here and pinned by `spec/ast_contract_spec.lua` against the shared
-- fixture in `lib/testdata/ast/`:
--
--   - `Stmt` / `Expr` are `#[serde(tag = "type")]` — internally tagged — and
--     every variant is a *newtype over a struct*, so serde flattens the
--     struct's fields into the tagged object. An identifier arrives as
--     `{"type": "Identifier", "names": [...]}`: there is no `identifier`
--     wrapper key to descend through.
--   - `Type` is `#[serde(tag = "type", content = "value")]` — adjacently
--     tagged. The tag names the *shape*, not the type, so a basic type is
--     `{"type": "Basic", "value": "Int"}` and never `{"type": "Int"}`.
--     There are exactly eight variants: Any, Named, Basic, List, Dict, Union,
--     Literal, Function.
--   - Plain structs carry no tag at all — `Identifier`, `Target`, `Keyword`,
--     `Arguments`, `ConfigEntry`, `CheckExpr`, `CallExpr`, `CompClause`,
--     `SchemaIndexSignature`, `SchemaExpr` — so they cannot be dispatched on
--     and each needs its own loader. `MemberOrIndex` is the exception: its own
--     `tag + content` enum whose `value` is itself a `NodeRef`.
--
-- Lua has no `serde` analogue, so this decodes with `dkjson` (already a
-- dependency — see the rockspec) and walks the dict tree. AST nodes are plain
-- tables: Lua has no classes, and metatables on every property access would
-- cost more than they are worth. Each node keeps the wire's `type` string
-- verbatim, so a caller dispatches with `node.type == "Schema"` and the same
-- spelling every other binding uses.
--
-- Two Lua-specific notes:
--
--   * `dkjson` maps a JSON `null` to `nil`, which a table cannot hold — and a
--     `nil` inside an array makes `ipairs` stop early, silently truncating
--     `Vec<Option<...>>` fields such as `Arguments.defaults`, whose elements
--     are index-aligned with `args`. So decoding passes `json.null` as the
--     null sentinel, which keeps the array dense.
--   * Absent elements in a decoded list are reported as `false` rather than
--     `nil` for the same reason: `nil` would punch a hole. `false` is falsy,
--     so `if item then` still reads correctly.

local json = require("dkjson")

local M = {}

-- ---------------------------------------------------------------------------
-- Generic NodeRef / Node helpers
-- ---------------------------------------------------------------------------

---Whether `v` is an absent value: either a Lua `nil` or a decoded JSON null.
local function is_null(v)
  return v == nil or v == json.null
end

---Whether `v` is a JSON object.
local function is_dict(v)
  return type(v) == "table" and not is_null(v)
end

local function as_string(v, default)
  if type(v) == "string" then
    return v
  end
  return default
end

local function as_int(v, default)
  if type(v) == "number" then
    return v
  end
  return default
end

local function as_bool(v, default)
  if is_null(v) then
    return default
  end
  return v and true or false
end

---Coerce a JSON array. Arrays and objects are both plain Lua tables, so this
---is just a guard against a missing or null value.
local function as_list(v)
  if not is_dict(v) then
    return {}
  end
  return v
end

---Decode a `NodeRef<T>`. `loader` receives the inner `node` payload, which
---is `nil` for a present-but-empty ref (serde writes `"node": null` rather
---than dropping the key).
local function node_ref(any_value, loader)
  if not is_dict(any_value) then
    return nil
  end
  local payload = any_value.node
  local node
  if not is_null(payload) then
    node = loader(payload)
  end
  return {
    node = node,
    filename = any_value.filename,
    line = any_value.line,
    column = any_value.column,
    endLine = any_value.end_line,
    endColumn = any_value.end_column,
  }
end

---Decode a `Vec<NodeRef<T>>`.
---
---The length always matches the wire. An element that is absent becomes
---`false` rather than being dropped, because dropping it would shift every
---later element one slot to the left.
local function node_ref_list(any_value, loader)
  local out = {}
  local i = 0
  for _, item in ipairs(as_list(any_value)) do
    i = i + 1
    out[i] = node_ref(item, loader) or false
  end
  return out
end

---Loader for a `NodeRef<String>` / `NodeRef<bool>`.
local function scalar_loader(default)
  return function(v)
    if is_null(v) then
      return default
    end
    return v
  end
end

-- Forward declarations for the polymorphic dispatchers and the mutually
-- recursive loaders. The loader graph is recursive in several places:
-- Stmt -> SchemaStmt.body -> Stmt, Expr -> Lambda.body -> Stmt, and
-- Expr <-> Stmt through `If`.
local parse_stmt
local parse_expr
local parse_type
local parse_schema_expr

-- ---------------------------------------------------------------------------
-- Flat DTOs — plain structs with no tag of their own
-- ---------------------------------------------------------------------------

---`ast::ConfigEntry` — one `key = value` / `key: value` / `key += value`.
local function parse_config_entry(d)
  if not is_dict(d) then
    return nil
  end
  return {
    key = node_ref(d.key, parse_expr),
    value = node_ref(d.value, parse_expr),
    operation = as_string(d.operation, nil),
    -- `is_shorthand` is `skip_serializing_if(is_false)`, so it is absent
    -- rather than false on the wire. Here it is always a real boolean.
    isShorthand = as_bool(d.is_shorthand, false),
  }
end

---`ast::Identifier` — `a`, `_c`, `pkg.a`. A plain struct with no tag.
---Declared before the loaders below because `Keyword.arg` and
---`Arguments.args` are `NodeRef<Identifier>`, not `NodeRef<Expr>`.
local function parse_identifier(d)
  if not is_dict(d) then
    return nil
  end
  return {
    names = node_ref_list(d.names, scalar_loader("")),
    pkgpath = as_string(d.pkgpath, ""),
    ctx = as_string(d.ctx, nil),
  }
end

---`ast::Keyword` — `arg=value`.
local function parse_keyword(d)
  if not is_dict(d) then
    return nil
  end
  return {
    -- `Keyword.arg` is a `NodeRef<Identifier>`, not a `NodeRef<Expr>`.
    arg = node_ref(d.arg, parse_identifier),
    value = node_ref(d.value, parse_expr),
  }
end

---`ast::Arguments` — a lambda's parameter list. `defaults` and `ty_list` are
---`Vec<Option<...>>` the same length as `args`, so the nulls are kept.
local function parse_arguments(d)
  if not is_dict(d) then
    return nil
  end
  return {
    args = node_ref_list(d.args, parse_identifier),
    defaults = node_ref_list(d.defaults, parse_expr),
    -- The Rust field is `ty_list`.
    tyList = node_ref_list(d.ty_list, parse_type),
  }
end

---`ast::Comment` — a single `#` line. Rust declares it as a plain struct with
---one `String` field, so the wire object is `{"text": "..."}` and not the
---string the text itself is. Reading it with `scalar_loader` yields `""` for
---every comment in the file and drops them all.
local function parse_comment(d)
  if not is_dict(d) then
    return nil
  end
  return {
    text = as_string(d.text, ""),
  }
end

---`ast::CheckExpr` — `len(attr) > 3 if attr, "message"`.
local function parse_check(d)
  if not is_dict(d) then
    return nil
  end
  return {
    test = node_ref(d.test, parse_expr),
    -- The Rust fields are `if_cond` and `msg`.
    ifCond = node_ref(d.if_cond, parse_expr),
    msg = node_ref(d.msg, parse_expr),
  }
end

---`ast::CallExpr`. A decorator (`@deprecated(strict=True)`) is one of these:
---`SchemaStmt.decorators` is `Vec<NodeRef<CallExpr>>`, and only the *enum* is
---tagged, so each element arrives as a bare `{func, args, keywords}`.
local function parse_call_expr(d)
  if not is_dict(d) then
    return nil
  end
  return {
    func = node_ref(d.func, parse_expr),
    args = node_ref_list(d.args, parse_expr),
    keywords = node_ref_list(d.keywords, parse_keyword),
  }
end

---`ast::CompClause` — one `for x in y if z` leg of a comprehension.
local function parse_comp_clause(d)
  if not is_dict(d) then
    return nil
  end
  return {
    -- `CompClause.targets` is `Vec<NodeRef<Identifier>>`.
    targets = node_ref_list(d.targets, parse_identifier),
    iter = node_ref(d.iter, parse_expr),
    ifs = node_ref_list(d.ifs, parse_expr),
  }
end

---`ast::SchemaIndexSignature` — the `[k: str]: int` statement in a schema
---body. Note it is a *body statement*, not part of the `schema` header:
---`schema Bag[k: str]` is a generic schema whose `args` is an `Arguments`.
local function parse_schema_index_signature(d)
  if not is_dict(d) then
    return nil
  end
  return {
    keyName = node_ref(d.key_name, scalar_loader("")),
    value = node_ref(d.value, parse_expr),
    anyOther = as_bool(d.any_other, false),
    keyTy = node_ref(d.key_ty, parse_type),
    valueTy = node_ref(d.value_ty, parse_type),
  }
end

---`ast::MemberOrIndex` — the `tag + content` enum behind a `Target`'s paths.
---Its `value` is itself a `NodeRef`, so `Member` wraps a `NodeRef<String>`
---and `Index` a `NodeRef<Expr>`.
local function parse_member_or_index(d)
  if not is_dict(d) then
    return nil
  end
  if d.type == "Member" then
    return { type = "Member", member = node_ref(d.value, scalar_loader("")) }
  end
  if d.type == "Index" then
    return { type = "Index", index = node_ref(d.value, parse_expr) }
  end
  return {}
end

---`ast::Target` — `a.b[0].c`. `paths` is a `Vec<MemberOrIndex>`, *not* a
---`Vec<NodeRef<MemberOrIndex>>`, so the elements carry no `NodeRef` wrapper.
local function parse_target(d)
  if not is_dict(d) then
    return nil
  end
  local paths = {}
  local i = 0
  for _, p in ipairs(as_list(d.paths)) do
    i = i + 1
    paths[i] = parse_member_or_index(p) or false
  end
  return {
    name = node_ref(d.name, scalar_loader("")),
    paths = paths,
    pkgpath = as_string(d.pkgpath, ""),
  }
end

---`ast::SchemaExpr` — the payload of both the `Schema` expression variant
---and `UnificationStmt.value`. Being a plain struct, it arrives with no
---`type` tag when it appears *outside* the `Expr` enum (as the right-hand
---side of `s: Person { ... }`) and cannot go through `parse_expr`.
local function parse_schema_expr_inner(d)
  if not is_dict(d) then
    return nil
  end
  return {
    -- `SchemaExpr.name` is a `NodeRef<Identifier>`.
    name = node_ref(d.name, parse_identifier),
    args = node_ref_list(d.args, parse_expr),
    kwargs = node_ref_list(d.kwargs, parse_keyword),
    config = node_ref(d.config, parse_expr),
  }
end

parse_schema_expr = parse_schema_expr_inner

-- ---------------------------------------------------------------------------
-- Stmt variants
-- ---------------------------------------------------------------------------

local function parse_type_alias_stmt(d)
  return {
    typeName = node_ref(d.type_name, parse_identifier),
    typeValue = node_ref(d.type_value, scalar_loader("")),
    ty = node_ref(d.ty, parse_type),
  }
end

local function parse_expr_stmt(d)
  return { exprs = node_ref_list(d.exprs, parse_expr) }
end

local function parse_unification_stmt(d)
  return {
    target = node_ref(d.target, parse_identifier),
    value = node_ref(d.value, parse_schema_expr),
  }
end

local function parse_assign_stmt(d)
  return {
    targets = node_ref_list(d.targets, parse_target),
    ty = node_ref(d.ty, parse_type),
    value = node_ref(d.value, parse_expr),
  }
end

local function parse_aug_assign_stmt(d)
  return {
    -- Note the singular `target` — `Assign` uses plural `targets`.
    target = node_ref(d.target, parse_target),
    value = node_ref(d.value, parse_expr),
    op = as_string(d.op, nil),
  }
end

local function parse_assert_stmt(d)
  return {
    test = node_ref(d.test, parse_expr),
    ifCond = node_ref(d.if_cond, parse_expr),
    msg = node_ref(d.msg, parse_expr),
  }
end

local function parse_if_stmt(d)
  return {
    body = node_ref_list(d.body, parse_stmt),
    cond = node_ref(d.cond, parse_expr),
    -- The Rust field is `orelse`, and it is a `Vec`, not a single node.
    orelse = node_ref_list(d.orelse, parse_stmt),
  }
end

local function parse_import_stmt(d)
  -- `ImportStmt` is flat: `path` is a `Node<String>`, and `rawpath`, `name`,
  -- `asname` and `pkg_name` are plain strings sitting next to it. There is
  -- no `node` wrapper object and no `as_name` / `pkg_root` field.
  return {
    path = node_ref(d.path, scalar_loader("")),
    rawpath = as_string(d.rawpath, nil),
    name = as_string(d.name, nil),
    asname = node_ref(d.asname, scalar_loader("")),
    pkgName = as_string(d.pkg_name, nil),
  }
end

local function parse_schema_stmt(d)
  return {
    doc = node_ref(d.doc, scalar_loader("")),
    name = node_ref(d.name, scalar_loader("")),
    parentName = node_ref(d.parent_name, parse_identifier),
    forHostName = node_ref(d.for_host_name, parse_identifier),
    isMixin = as_bool(d.is_mixin, false),
    isProtocol = as_bool(d.is_protocol, false),
    args = node_ref(d.args, parse_arguments),
    mixins = node_ref_list(d.mixins, parse_identifier),
    body = node_ref_list(d.body, parse_stmt),
    decorators = node_ref_list(d.decorators, parse_call_expr),
    -- `checks` is `Vec<NodeRef<CheckExpr>>` — a plain struct, not a tagged
    -- `Expr`, so the element must be decoded as a `Check`.
    checks = node_ref_list(d.checks, parse_check),
    indexSignature = node_ref(d.index_signature, parse_schema_index_signature),
  }
end

local function parse_schema_attr(d)
  return {
    doc = as_string(d.doc, ""),
    name = node_ref(d.name, scalar_loader("")),
    op = as_string(d.op, nil),
    value = node_ref(d.value, parse_expr),
    isOptional = as_bool(d.is_optional, false),
    decorators = node_ref_list(d.decorators, parse_call_expr),
    ty = node_ref(d.ty, parse_type),
  }
end

local function parse_rule_stmt(d)
  return {
    doc = node_ref(d.doc, scalar_loader("")),
    name = node_ref(d.name, scalar_loader("")),
    parentRules = node_ref_list(d.parent_rules, parse_identifier),
    decorators = node_ref_list(d.decorators, parse_call_expr),
    checks = node_ref_list(d.checks, parse_check),
    args = node_ref(d.args, parse_arguments),
    forHostName = node_ref(d.for_host_name, parse_identifier),
  }
end

local STMT_REGISTRY = {
  TypeAlias = parse_type_alias_stmt,
  Expr = parse_expr_stmt,
  Unification = parse_unification_stmt,
  Assign = parse_assign_stmt,
  AugAssign = parse_aug_assign_stmt,
  Assert = parse_assert_stmt,
  If = parse_if_stmt,
  Import = parse_import_stmt,
  SchemaAttr = parse_schema_attr,
  Schema = parse_schema_stmt,
  Rule = parse_rule_stmt,
}

---Polymorphic `Stmt` loader. Returns nil for a payload with no `type`.
parse_stmt = function(d)
  if not is_dict(d) then
    return nil
  end
  local variant = d.type
  if is_null(variant) then
    return nil
  end
  local loader = STMT_REGISTRY[variant]
  local out = loader and loader(d) or {}
  out.type = variant
  if not loader then
    out.unknown = true
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Expr variants
-- ---------------------------------------------------------------------------

local function parse_target_expr(d)
  -- `Expr::Target(Target)` carries the same fields as the bare `ast::Target`
  -- struct, so delegate and let `parse_target` read them off the wire object.
  return parse_target(d)
end

local function parse_unary_expr(d)
  return {
    op = as_string(d.op, nil),
    operand = node_ref(d.operand, parse_expr),
  }
end

local function parse_binary_expr(d)
  return {
    left = node_ref(d.left, parse_expr),
    op = as_string(d.op, nil),
    right = node_ref(d.right, parse_expr),
  }
end

local function parse_if_expr(d)
  return {
    body = node_ref(d.body, parse_expr),
    cond = node_ref(d.cond, parse_expr),
    orelse = node_ref(d.orelse, parse_expr),
  }
end

local function parse_selector_expr(d)
  return {
    value = node_ref(d.value, parse_expr),
    -- `SelectorExpr.attr` is a `NodeRef<Identifier>`.
    attr = node_ref(d.attr, parse_identifier),
    ctx = as_string(d.ctx, nil),
    hasQuestion = as_bool(d.has_question, false),
  }
end

local function parse_call_expr_variant(d)
  return parse_call_expr(d)
end

local function parse_paren_expr(d)
  return { expr = node_ref(d.expr, parse_expr) }
end

local function parse_quant_expr(d)
  return {
    target = node_ref(d.target, parse_expr),
    -- `QuantExpr.variables` is `Vec<NodeRef<Identifier>>`.
    variables = node_ref_list(d.variables, parse_identifier),
    op = as_string(d.op, nil),
    test = node_ref(d.test, parse_expr),
    ifCond = node_ref(d.if_cond, parse_expr),
    ctx = as_string(d.ctx, nil),
  }
end

local function parse_list_expr(d)
  return {
    elts = node_ref_list(d.elts, parse_expr),
    ctx = as_string(d.ctx, nil),
  }
end

local function parse_list_if_item_expr(d)
  return {
    ifCond = node_ref(d.if_cond, parse_expr),
    exprs = node_ref_list(d.exprs, parse_expr),
    orelse = node_ref(d.orelse, parse_expr),
  }
end

local function parse_list_comp(d)
  return {
    elt = node_ref(d.elt, parse_expr),
    -- `generators` is `Vec<NodeRef<CompClause>>`, and `CompClause` is a plain
    -- struct — its elements carry no `type` tag.
    generators = node_ref_list(d.generators, parse_comp_clause),
  }
end

local function parse_starred_expr(d)
  return {
    value = node_ref(d.value, parse_expr),
    ctx = as_string(d.ctx, nil),
  }
end

local function parse_dict_comp(d)
  return {
    -- A `DictComp` has exactly one `entry: ConfigEntry` — not separate
    -- key/value/entry_key fields. It is a bare struct, not a `NodeRef`.
    entry = parse_config_entry(d.entry),
    generators = node_ref_list(d.generators, parse_comp_clause),
  }
end

local function parse_config_if_entry_expr(d)
  return {
    ifCond = node_ref(d.if_cond, parse_expr),
    items = node_ref_list(d.items, parse_config_entry),
    orelse = node_ref(d.orelse, parse_expr),
  }
end

local function parse_schema_expr_variant(d)
  return parse_schema_expr(d)
end

local function parse_config_expr(d)
  return { items = node_ref_list(d.items, parse_config_entry) }
end

local function parse_check_expr_variant(d)
  -- `Expr::Check(CheckExpr)` — flattened, no `check` wrapper key.
  return parse_check(d)
end

local function parse_keyword_expr(d)
  -- `Expr::Keyword(Keyword)` — flattened, no `keyword` wrapper key.
  return parse_keyword(d)
end

local function parse_arguments_expr(d)
  -- `Expr::Arguments(Arguments)` — flattened, no `arguments` wrapper key.
  return parse_arguments(d)
end

local function parse_lambda_expr(d)
  return {
    args = node_ref(d.args, parse_arguments),
    -- A lambda body is `Vec<NodeRef<Stmt>>`, not a list of expressions.
    body = node_ref_list(d.body, parse_stmt),
    returnTy = node_ref(d.return_ty, parse_type),
  }
end

local function parse_subscript(d)
  return {
    value = node_ref(d.value, parse_expr),
    -- A slice is `lower`/`upper`/`step`; `index` is only set for `a[0]`.
    index = node_ref(d.index, parse_expr),
    lower = node_ref(d.lower, parse_expr),
    upper = node_ref(d.upper, parse_expr),
    step = node_ref(d.step, parse_expr),
    ctx = as_string(d.ctx, nil),
    hasQuestion = as_bool(d.has_question, false),
  }
end

local function parse_compare(d)
  return {
    left = node_ref(d.left, parse_expr),
    ops = as_list(d.ops),
    comparators = node_ref_list(d.comparators, parse_expr),
  }
end

local function parse_number_lit(d)
  return {
    binarySuffix = as_string(d.binary_suffix, nil),
    -- `NumberLitValue` is its own `tag + content` enum, so the value is an
    -- object — `{"type": "Int", "value": 0}` — and not a bare number.
    value = is_dict(d.value) and d.value or nil,
  }
end

local function parse_string_lit(d)
  return {
    isLongString = as_bool(d.is_long_string, false),
    rawValue = as_string(d.raw_value, '""'),
    value = as_string(d.value, ""),
  }
end

local function parse_name_constant_lit(d)
  -- `NameConstant` is an enum with no `#[serde]` tag at all, so serde writes
  -- it as a bare JSON string -- `"True"`, `"False"`, `"None"`,
  -- `"Undefined"`. All four are truthy in Lua, so reading this with `as_bool`
  -- collapses every one of them to `true` and no parse reports it.
  return { value = as_string(d.value, "") }
end

local function parse_joined_string(d)
  return {
    isLongString = as_bool(d.is_long_string, false),
    values = node_ref_list(d.values, parse_expr),
    rawValue = as_string(d.raw_value, ""),
  }
end

local function parse_formatted_value(d)
  return {
    isLongString = as_bool(d.is_long_string, false),
    value = node_ref(d.value, parse_expr),
    -- `format_spec` is a plain `Option<String>`, not a `NodeRef<Expr>`.
    formatSpec = as_string(d.format_spec, nil),
  }
end

local function parse_missing_expr(_d)
  -- `Expr::Missing` has no fields. The parser only emits it during error
  -- recovery, so it never appears in a clean parse.
  return {}
end

local EXPR_REGISTRY = {
  Target = parse_target_expr,
  Identifier = parse_identifier,
  Unary = parse_unary_expr,
  Binary = parse_binary_expr,
  If = parse_if_expr,
  Selector = parse_selector_expr,
  Call = parse_call_expr_variant,
  Paren = parse_paren_expr,
  Quant = parse_quant_expr,
  List = parse_list_expr,
  ListIfItem = parse_list_if_item_expr,
  ListComp = parse_list_comp,
  Starred = parse_starred_expr,
  DictComp = parse_dict_comp,
  ConfigIfEntry = parse_config_if_entry_expr,
  CompClause = parse_comp_clause,
  Schema = parse_schema_expr_variant,
  Config = parse_config_expr,
  Check = parse_check_expr_variant,
  Lambda = parse_lambda_expr,
  Subscript = parse_subscript,
  Keyword = parse_keyword_expr,
  Arguments = parse_arguments_expr,
  Compare = parse_compare,
  NumberLit = parse_number_lit,
  StringLit = parse_string_lit,
  NameConstantLit = parse_name_constant_lit,
  JoinedString = parse_joined_string,
  FormattedValue = parse_formatted_value,
  Missing = parse_missing_expr,
}

---Polymorphic `Expr` loader. Returns nil for a payload with no `type`.
parse_expr = function(d)
  if not is_dict(d) then
    return nil
  end
  local variant = d.type
  if is_null(variant) then
    return nil
  end
  local loader = EXPR_REGISTRY[variant]
  local out = loader and loader(d) or {}
  out.type = variant
  if not loader then
    out.unknown = true
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Type variants
-- ---------------------------------------------------------------------------

---`Type::Basic(BasicType)`. The payload is a bare string, not an object.
local function parse_basic_type(v)
  return { type = "Basic", name = as_string(v, "") }
end

---`Type::Named(Identifier)`.
local function parse_named_type(v)
  return { type = "Named", identifier = parse_identifier(v) }
end

---`Type::List(ListType)`.
local function parse_list_type(v)
  local t = is_dict(v) and v or {}
  return {
    type = "List",
    innerType = node_ref(t.inner_type, parse_type),
  }
end

---`Type::Dict(DictType)`.
local function parse_dict_type(v)
  local t = is_dict(v) and v or {}
  return {
    type = "Dict",
    keyType = node_ref(t.key_type, parse_type),
    valueType = node_ref(t.value_type, parse_type),
  }
end

---`Type::Union(UnionType)`. The Rust field is `type_elements`.
local function parse_union_type(v)
  local t = is_dict(v) and v or {}
  return {
    type = "Union",
    types = node_ref_list(t.type_elements, parse_type),
  }
end

---Copy a raw wire payload, mapping dkjson's null sentinel back to a Lua
---`nil`.
---
---The only payload passed through verbatim is a `LiteralType`, and handing a
---caller `json.null` would leak the decoder's internals — worse, `if
---lit.suffix then` would take the wrong branch. The payload is always a flat
---object (`{type, value, suffix}`), so dropping null-valued keys cannot punch
---a hole in an array.
local function strip_nulls(v)
  if not is_dict(v) then
    return nil
  end
  local out = {}
  for k, item in pairs(v) do
    if not is_null(item) then
      out[k] = is_dict(item) and strip_nulls(item) or item
    end
  end
  return out
end

---`Type::Literal(LiteralType)`. `LiteralType` is *itself* tagged, so the
---payload is doubly nested: `{"type":"Int","value":{"value":1,"suffix":null}}`.
local function parse_literal_type(v)
  return {
    type = "Literal",
    value = strip_nulls(v) or {},
    -- Record the inner tag so a caller does not have to reach into `value`
    -- to find out which literal it is.
    innerTag = is_dict(v) and as_string(v.type, nil) or nil,
  }
end

---`Type::Function(FunctionType)`.
local function parse_function_type(v)
  local t = is_dict(v) and v or {}
  return {
    type = "Function",
    paramsTy = node_ref_list(t.params_ty, parse_type),
    retTy = node_ref(t.ret_ty, parse_type),
  }
end

parse_type = function(d)
  if not is_dict(d) then
    return nil
  end
  local tag = d.type
  if is_null(tag) then
    return nil
  end
  local value = d.value
  if tag == "Any" then
    return { type = "Any" }
  elseif tag == "Basic" then
    return parse_basic_type(value)
  elseif tag == "Named" then
    return parse_named_type(value)
  elseif tag == "List" then
    return parse_list_type(value)
  elseif tag == "Dict" then
    return parse_dict_type(value)
  elseif tag == "Union" then
    return parse_union_type(value)
  elseif tag == "Literal" then
    return parse_literal_type(value)
  elseif tag == "Function" then
    return parse_function_type(value)
  end
  -- A tag this build does not know about. Keep the raw payload so a caller
  -- can still reach the data a future parser emitted.
  return { type = "Unknown", tag = tag, value = value }
end

-- ---------------------------------------------------------------------------
-- Module / Program
-- ---------------------------------------------------------------------------

local function parse_module_dict(d)
  return {
    filename = as_string(d.filename, ""),
    doc = node_ref(d.doc, scalar_loader("")),
    body = node_ref_list(d.body, parse_stmt),
    comments = node_ref_list(d.comments, parse_comment),
  }
end

---Decode a JSON string with `json.null` as the null sentinel, so that a
---`null` inside an array keeps its slot instead of becoming a `nil` hole.
local function decode(ast_json)
  local dict, err = json.decode(ast_json, 1, json.null)
  if dict == nil then
    error("invalid JSON: " .. tostring(err))
  end
  return dict
end

---Parse the `ast_json` field of a `ParseFileResult` into a typed
---`Module` table.
---@param ast_json string The JSON string returned by ParseFile.
---@return table A Module AST.
function M.parse_module(ast_json)
  local dict = decode(ast_json)
  if not is_dict(dict) then
    error("expected JSON object at ast_json root")
  end
  return parse_module_dict(dict)
end

---Parse the `ast_json` field of a `ParseProgramResult` into a list of
---typed `Module` tables. Accepts both wire shapes:
---  - `{"root": ".", "pkgs": {"__main__": [Module, …]}}` (current)
---  - `[Module, …]` (older rustc ABI)
---@param ast_json string The JSON string returned by ParseProgram.
---@return table A list of Module ASTs.
function M.parse_program(ast_json)
  local root = decode(ast_json)
  if not is_dict(root) then
    error("expected JSON object or array at ast_json root")
  end
  -- Legacy wire shape: root is a list of modules.
  if root[1] ~= nil or root.filename ~= nil then
    if root.filename ~= nil and root.body ~= nil then
      return { parse_module_dict(root) }
    end
    local modules = {}
    for _, m in ipairs(root) do
      modules[#modules + 1] = parse_module_dict(m)
    end
    return modules
  end
  local pkgs = root.pkgs
  if not is_dict(pkgs) then
    error("missing field `pkgs` in program envelope")
  end
  local modules = {}
  for _, m in ipairs(pkgs.__main__ or {}) do
    modules[#modules + 1] = parse_module_dict(m)
  end
  return modules
end

---Exported for the contract spec, which asserts the DTO loaders directly.
M.parse_config_entry = parse_config_entry
M.parse_keyword = parse_keyword
M.parse_arguments = parse_arguments
M.parse_check = parse_check
M.parse_call_expr = parse_call_expr
M.parse_comp_clause = parse_comp_clause
M.parse_schema_index_signature = parse_schema_index_signature
M.parse_member_or_index = parse_member_or_index
M.parse_target = parse_target
M.parse_identifier = parse_identifier
M.parse_type = parse_type
M.parse_expr = parse_expr
M.parse_stmt = parse_stmt

return M

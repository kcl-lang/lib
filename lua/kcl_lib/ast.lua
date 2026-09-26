-- ast.lua — Typed AST package for the Lua binding.
--
-- Mirrors the work already merged for Java (#322), Go, Python (#328),
-- Node.js (#329), .NET (#330), WASM (#330), Swift (#331), and Kotlin
-- (#331). Wire shape follows `kcl-lang/kcl crates/ast/src/ast.rs`:
--
--   - `#[serde(tag = "type")]` polymorphic dispatch — every `Stmt` /
--     `Expr` / `Type` variant carries a `"type"` discriminator.
--   - Flat DTOs (`Decorator`, `SchemaConfig`, `ConfigEntry`, `Keyword`,
--     `Arguments`, `MemberOrIndex`, `Target`) where the `NodeRef<T>`
--     payload lacks the polymorphic tag — see AST_DRIFT.md note A.
--
-- Lua doesn't have a `serde` analogue, so we parse with `dkjson`
-- (already a dependency of the Lua binding — see rockspec) and walk
-- the dict tree, dispatching each `Stmt` / `Expr` / `Type` on its
-- `"type"` discriminator. This mirrors how the Java/Python/Node.js
-- bindings walk serde-tagged JSON without writing a custom decoder.
--
-- AST nodes are plain Lua tables (Lua has no classes; we'd otherwise
-- pay for metatables on every property access). The `type` field is
-- preserved on each node so callers can dispatch on it (`node.type ==
-- "Schema"`), and where the discriminator differs from the Rust case
-- (notably `"NumberLit"` / `"StringLit"` / `"NameConstantLit"`) the
-- wire tag is used verbatim to round-trip through `dkjson`.

local json = require("dkjson")

local M = {}

-- ---------------------------------------------------------------------------
-- Generic NodeRef / Node helpers
-- ---------------------------------------------------------------------------

-- A `Node<T>` in Rust serializes as `{node: <T>, filename, line, column,
-- end_line, end_column, id?}` and `NodeRef<T>` is just `Box<Node<T>>`,
-- so the JSON shape is identical. Hand the loader either:
--   - the inner `node` dict when the payload is a polymorphic record
--     (`Stmt`, `Expr`, `KclTypeNode`) so the `type` tag lands at the
--     top of the dict the loader sees;
--   - the outer dict when the payload is a primitive (`String`, `Int`,
--     …) — loaders like `parse_string_node` then pull `dict.node`.
local function parse_node_ref(any_value, loader)
  if type(any_value) ~= "table" then
    return nil
  end
  local payload = any_value
  if type(any_value.node) == "table" then
    payload = any_value.node
  end
  local node = loader(payload)
  local pos = nil
  if any_value.filename ~= nil then
    pos = {
      filename = any_value.filename,
      line = any_value.line,
      column = any_value.column,
      end_line = any_value.end_line,
      end_column = any_value.end_column,
    }
  end
  return { node = node, position = pos, id = any_value.id }
end

local function parse_node_ref_list(any_value, loader)
  local out = {}
  if type(any_value) ~= "table" then
    return out
  end
  for _, item in ipairs(any_value) do
    local ref = parse_node_ref(item, loader)
    if ref ~= nil then
      out[#out + 1] = ref
    end
  end
  return out
end

local function parse_string_node(dict)
  if type(dict) == "string" then
    return dict
  end
  if type(dict) == "table" then
    return dict.node or ""
  end
  return ""
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
  if v == nil then
    return default
  end
  return v and true or false
end

local function as_list(v)
  if type(v) ~= "table" then
    return {}
  end
  return v
end

local function as_dict(v)
  if type(v) ~= "table" then
    return {}
  end
  return v
end

-- Forward declarations for the polymorphic dispatchers (the loader
-- graph is recursive: Stmt → SchemaStmt.body → Stmt).
local parse_stmt
local parse_expr
local parse_kcl_type_node

-- ---------------------------------------------------------------------------
-- Stmt variants
-- ---------------------------------------------------------------------------

local function parse_expr_stmt(d)
  return { type = "ExprStmt", exprs = parse_node_ref_list(d.exprs, parse_expr) }
end

local function parse_target(d)
  local paths = {}
  for _, p in ipairs(as_list(d.paths)) do
    if type(p) == "table" then
      local t = p.type
      if t == "Member" then
        paths[#paths + 1] = { kind = "member", value = parse_node_ref(p.value, parse_string_node) }
      elseif t == "Index" then
        paths[#paths + 1] = { kind = "index", value = parse_node_ref(p.value, parse_expr) }
      else
        -- Legacy shape (no `type` discriminator): string → member,
        -- anything else → index expression.
        local v = p.value
        if type(v) == "string" then
          paths[#paths + 1] = { kind = "member", value = { node = v } }
        elseif type(v) == "table" then
          paths[#paths + 1] = { kind = "index", value = parse_node_ref(v, parse_expr) }
        end
      end
    end
  end
  return {
    name = parse_node_ref(d.name, parse_string_node),
    paths = paths,
    pkgpath = as_string(d.pkgpath, ""),
  }
end

local function parse_schema_config(d)
  return {
    name = parse_node_ref(d.name, parse_expr),
    args = parse_node_ref_list(d.args, parse_expr),
    kwargs = parse_node_ref_list(d.kwargs, function(kw)
      return {
        arg = parse_node_ref(kw.arg, parse_expr),
        value = parse_node_ref(kw.value, parse_expr),
      }
    end),
    config = parse_node_ref(d.config, parse_expr),
  }
end

local function parse_identifier(d)
  return {
    names = parse_node_ref_list(d.names, parse_string_node),
    pkgpath = as_list(d.pkgpath),
  }
end

local function parse_aug_op(any_value)
  local op = as_string(any_value, nil)
  if op == nil then
    return nil
  end
  return op
end

local function parse_decorator(d)
  return {
    func = parse_node_ref(d.func, parse_expr),
    args = parse_node_ref_list(d.args, parse_expr),
    keywords = parse_node_ref_list(d.keywords, function(kw)
      return {
        arg = parse_node_ref(kw.arg, parse_expr),
        value = parse_node_ref(kw.value, parse_expr),
      }
    end),
  }
end

local function parse_schema_attr(d)
  return {
    doc = as_string(d.doc, ""),
    name = parse_node_ref(d.name, parse_string_node),
    op = parse_aug_op(d.op),
    value = parse_node_ref(d.value, parse_expr),
    is_optional = as_bool(d.is_optional, false),
    decorators = parse_node_ref_list(d.decorators, parse_decorator),
    ty = parse_node_ref(d.ty, parse_kcl_type_node),
  }
end

local function parse_schema_index_signature(d)
  return {
    key_type = parse_node_ref(d.key_type, parse_kcl_type_node),
    value_type = parse_node_ref(d.value_type, parse_kcl_type_node),
  }
end

local function parse_check_expr(d)
  return {
    test = parse_node_ref(d.test, parse_expr),
    if_cond = parse_node_ref(d.if_cond, parse_expr),
    msg = parse_node_ref(d.msg, parse_string_node),
  }
end

local function parse_quant_operation(d)
  return {
    target = parse_node_ref(d.target, parse_target),
    op = as_string(d.op, "filter"),
  }
end

local function parse_quant_operation_any(any_value)
  if type(any_value) == "table" then
    return parse_quant_operation(any_value)
  end
  -- Some wire shapes encode the op as a plain string (e.g. "all").
  return {
    target = { node = { name = { node = "" }, paths = {}, pkgpath = "" } },
    op = as_string(any_value, "filter"),
  }
end

local function parse_comp_clause(d)
  return {
    targets = parse_node_ref_list(d.targets, parse_target),
    iter = parse_node_ref(d.iter, parse_expr),
    ifs = parse_node_ref_list(d.ifs, parse_expr),
  }
end

local function parse_arguments(d)
  return {
    args = parse_node_ref_list(d.args, parse_expr),
    defaults = parse_node_ref_list(d.defaults, parse_expr),
    ty_list = parse_node_ref_list(d.ty_list, parse_kcl_type_node),
  }
end

local function parse_assign_stmt(d)
  return {
    type = "AssignStmt",
    targets = parse_node_ref_list(d.targets, parse_target),
    ty = parse_node_ref(d.ty, parse_kcl_type_node),
    value = parse_node_ref(d.value, parse_expr),
  }
end

local function parse_schema_stmt(d)
  return {
    type = "SchemaStmt",
    doc = parse_node_ref(d.doc, parse_string_node),
    name = parse_node_ref(d.name, parse_string_node),
    parent_name = parse_node_ref(d.parent_name, parse_identifier),
    for_host_name = parse_node_ref(d.for_host_name, parse_identifier),
    is_mixin = as_bool(d.is_mixin, false),
    is_protocol = as_bool(d.is_protocol, false),
    args = parse_node_ref(d.args, parse_arguments),
    mixins = parse_node_ref_list(d.mixins, parse_identifier),
    body = parse_node_ref_list(d.body, parse_stmt),
    decorators = parse_node_ref_list(d.decorators, parse_decorator),
    checks = parse_node_ref_list(d.checks, parse_check_expr),
    index_signature = parse_node_ref(d.index_signature, parse_schema_index_signature),
  }
end

local function parse_rule_stmt(d)
  return {
    type = "RuleStmt",
    doc = parse_node_ref(d.doc, parse_string_node),
    name = parse_node_ref(d.name, parse_string_node),
    parent_rules = parse_node_ref_list(d.parent_rules, parse_identifier),
    decorators = parse_node_ref_list(d.decorators, parse_decorator),
    checks = parse_node_ref_list(d.checks, parse_check_expr),
    args = parse_node_ref(d.args, parse_arguments),
    for_host_name = parse_node_ref(d.for_host_name, parse_identifier),
  }
end

local function parse_import_stmt(d)
  local node = d.node
  if type(node) ~= "table" then
    return {
      type = "ImportStmt",
      path = "",
      as_name = nil,
      pkg_name = nil,
      pkg_root = nil,
    }
  end
  return {
    type = "ImportStmt",
    path = as_string(node.path, ""),
    as_name = node.as_name,
    pkg_name = node.pkg_name,
    pkg_root = node.pkg_root,
  }
end

local function parse_type_alias_stmt(d)
  return {
    type = "TypeAliasStmt",
    name = parse_node_ref(d.name, parse_string_node),
    ty = parse_node_ref(d.ty, parse_kcl_type_node),
  }
end

local function parse_assert_stmt(d)
  return {
    type = "AssertStmt",
    source = parse_node_ref(d.source, parse_expr),
    assert_msg = parse_node_ref(d.assert_msg, parse_string_node),
  }
end

local function parse_if_stmt(d)
  return {
    type = "IfStmt",
    cond = parse_node_ref(d.cond, parse_expr),
    body = parse_node_ref_list(d.body, parse_stmt),
    or_else = parse_node_ref(d.or_else, parse_expr),
  }
end

local function parse_unification_stmt(d)
  return {
    type = "UnificationStmt",
    target = parse_node_ref(d.target, parse_target),
    value = parse_node_ref(d.value, parse_schema_config),
  }
end

parse_stmt = function(d)
  local t = as_string(d.type, nil)
  if t == nil or t == "" then
    return { type = "Unknown" }
  end
  if t == "Expr" then return parse_expr_stmt(d) end
  if t == "Unification" then return parse_unification_stmt(d) end
  if t == "Assign" then return parse_assign_stmt(d) end
  if t == "Schema" then return parse_schema_stmt(d) end
  if t == "SchemaAttr" then return parse_schema_attr(d) end
  if t == "Rule" then return parse_rule_stmt(d) end
  if t == "Import" then return parse_import_stmt(d) end
  if t == "TypeAlias" then return parse_type_alias_stmt(d) end
  if t == "Assert" then return parse_assert_stmt(d) end
  if t == "If" then return parse_if_stmt(d) end
  return { type = "Unknown", wire_tag = t }
end

-- ---------------------------------------------------------------------------
-- Expr variants
-- ---------------------------------------------------------------------------

local function parse_target_expr(d)
  return { type = "TargetExpr", name = parse_node_ref(d.name, parse_string_node) }
end

local function parse_identifier_expr(d)
  return {
    type = "IdentifierExpr",
    names = parse_node_ref_list(d.names, parse_string_node),
    pkgpath = as_list(d.pkgpath),
  }
end

local function parse_unary_expr(d)
  return {
    type = "UnaryExpr",
    op = as_string(d.op, "Not"),
    operand = parse_node_ref(d.operand, parse_expr),
  }
end

local function parse_binary_expr(d)
  return {
    type = "BinaryExpr",
    op = as_string(d.op, "Add"),
    left = parse_node_ref(d.left, parse_expr),
    right = parse_node_ref(d.right, parse_expr),
  }
end

local function parse_if_expr(d)
  return {
    type = "IfExpr",
    cond = parse_node_ref(d.cond, parse_expr),
    body = parse_node_ref(d.body, parse_expr),
    or_else = parse_node_ref(d.or_else, parse_expr),
  }
end

local function parse_selector_expr(d)
  return {
    type = "SelectorExpr",
    value = parse_node_ref(d.value, parse_expr),
    attr_name = parse_node_ref(d.attr_name, parse_string_node),
  }
end

local function parse_call_expr(d)
  return {
    type = "CallExpr",
    func = parse_node_ref(d.func, parse_expr),
    args = parse_node_ref_list(d.args, parse_expr),
    keywords = parse_node_ref_list(d.keywords, function(kw)
      return {
        arg = parse_node_ref(kw.arg, parse_expr),
        value = parse_node_ref(kw.value, parse_expr),
      }
    end),
  }
end

local function parse_paren_expr(d)
  return { type = "ParenExpr", expr = parse_node_ref(d.expr, parse_expr) }
end

local function parse_quant_expr(d)
  return {
    type = "QuantExpr",
    target = parse_node_ref(d.target, parse_target),
    variables = parse_node_ref_list(d.variables, parse_quant_operation),
    op = parse_quant_operation_any(d.op),
    cond = parse_node_ref(d.cond, parse_expr),
  }
end

local function parse_list_expr(d)
  return { type = "ListExpr", elts = parse_node_ref_list(d.elts, parse_expr) }
end

local function parse_list_if_item_expr(d)
  return {
    type = "ListIfItemExpr",
    if_expr = parse_node_ref(d.if_expr, parse_expr),
    or_else = parse_node_ref(d.or_else, parse_expr),
  }
end

local function parse_list_comp(d)
  return {
    type = "ListComp",
    elt = parse_node_ref(d.elt, parse_expr),
    generators = parse_node_ref_list(d.generators, parse_comp_clause),
    cond = parse_node_ref(d.cond, parse_expr),
  }
end

local function parse_starred_expr(d)
  return {
    type = "StarredExpr",
    value = parse_node_ref(d.value, parse_expr),
    ctx = as_string(d.ctx, "Load"),
  }
end

local function parse_dict_comp(d)
  return {
    type = "DictComp",
    key = parse_node_ref(d.key, parse_expr),
    value = parse_node_ref(d.value, parse_expr),
    generators = parse_node_ref_list(d.generators, parse_comp_clause),
    cond = parse_node_ref(d.cond, parse_expr),
  }
end

local function parse_config_if_entry_expr(d)
  return {
    type = "ConfigIfEntryExpr",
    if_expr = parse_node_ref(d.if_expr, parse_expr),
  }
end

local function parse_schema_expr(d)
  return {
    type = "SchemaExpr",
    name = parse_node_ref(d.name, parse_expr),
    args = parse_node_ref_list(d.args, parse_expr),
    kwargs = parse_node_ref_list(d.kwargs, function(kw)
      return {
        arg = parse_node_ref(kw.arg, parse_expr),
        value = parse_node_ref(kw.value, parse_expr),
      }
    end),
    config = parse_node_ref(d.config, parse_expr),
  }
end

local function parse_config_entry(d)
  return {
    key = parse_node_ref(d.key, parse_expr),
    value = parse_node_ref(d.value, parse_expr),
    operation = d.operation,
    is_shorthand = as_bool(d.is_shorthand, false),
  }
end

local function parse_config_expr(d)
  return {
    type = "ConfigExpr",
    items = parse_node_ref_list(d.items, parse_config_entry),
  }
end

local function parse_lambda_expr(d)
  return {
    type = "LambdaExpr",
    args = parse_node_ref(d.args, parse_arguments),
    body = parse_node_ref_list(d.body, parse_stmt),
    return_ty = parse_node_ref(d.return_ty, parse_kcl_type_node),
  }
end

local function parse_subscript(d)
  return {
    type = "Subscript",
    value = parse_node_ref(d.value, parse_expr),
    index = parse_node_ref(d.index, parse_expr),
  }
end

local function parse_compare(d)
  return {
    type = "Compare",
    left = parse_node_ref(d.left, parse_expr),
    ops = as_list(d.ops),
    comparators = parse_node_ref_list(d.comparators, parse_expr),
  }
end

local function parse_number_lit(d)
  local value_dict = as_dict(d.value)
  local raw_value = as_string(value_dict.raw_value, "")
  local value = as_int(value_dict.value, 0)
  local binary_suffix = d.binary_suffix
  if binary_suffix == nil then
    binary_suffix = value_dict.binary_suffix
  end
  return {
    type = "NumberLit",
    binary_suffix = binary_suffix,
    value = {
      raw_value = raw_value,
      value = value,
      binary_suffix = value_dict.binary_suffix,
    },
  }
end

local function parse_string_lit(d)
  return {
    type = "StringLit",
    is_long_string = as_bool(d.is_long_string, false),
    raw_value = as_string(d.raw_value, '""'),
    value = as_string(d.value, ""),
  }
end

local function parse_name_constant_lit(d)
  return { type = "NameConstantLit", value = as_string(d.value, "Undefined") }
end

local function parse_joined_string(d)
  return {
    type = "JoinedString",
    values = parse_node_ref_list(d.values, parse_expr),
    is_long_string = as_bool(d.is_long_string, false),
    raw_value = as_string(d.raw_value, ""),
  }
end

local function parse_formatted_value(d)
  return {
    type = "FormattedValue",
    value = parse_node_ref(d.value, parse_expr),
    spec = d.spec,
  }
end

local function parse_missing_expr()
  return { type = "MissingExpr" }
end

parse_expr = function(d)
  local t = as_string(d.type, nil)
  if t == nil or t == "" then
    return { type = "Unknown" }
  end
  if t == "Target" then return parse_target_expr(d) end
  if t == "Identifier" then return parse_identifier_expr(d) end
  if t == "Unary" then return parse_unary_expr(d) end
  if t == "Binary" then return parse_binary_expr(d) end
  if t == "If" then return parse_if_expr(d) end
  if t == "Selector" then return parse_selector_expr(d) end
  if t == "Call" then return parse_call_expr(d) end
  if t == "Paren" then return parse_paren_expr(d) end
  if t == "Quant" then return parse_quant_expr(d) end
  if t == "List" then return parse_list_expr(d) end
  if t == "ListIfItem" then return parse_list_if_item_expr(d) end
  if t == "ListComp" then return parse_list_comp(d) end
  if t == "Starred" then return parse_starred_expr(d) end
  if t == "DictComp" then return parse_dict_comp(d) end
  if t == "ConfigIfEntry" then return parse_config_if_entry_expr(d) end
  if t == "CompClause" then return parse_comp_clause(d) end
  if t == "Schema" then return parse_schema_expr(d) end
  if t == "Config" then return parse_config_expr(d) end
  if t == "Lambda" then return parse_lambda_expr(d) end
  if t == "Subscript" then return parse_subscript(d) end
  if t == "Compare" then return parse_compare(d) end
  if t == "NumberLit" then return parse_number_lit(d) end
  if t == "StringLit" then return parse_string_lit(d) end
  if t == "NameConstantLit" then return parse_name_constant_lit(d) end
  if t == "JoinedString" then return parse_joined_string(d) end
  if t == "FormattedValue" then return parse_formatted_value(d) end
  if t == "Missing" then return parse_missing_expr() end
  if t == "CheckExpr" then return parse_check_expr(d) end
  return { type = "Unknown", wire_tag = t }
end

-- ---------------------------------------------------------------------------
-- KclTypeNode variants
-- ---------------------------------------------------------------------------

local function parse_any_type()
  return { type = "AnyType" }
end

local function parse_basic_type(d)
  return { type = "BasicType", kind = as_string(d.kind, "") }
end

local function parse_list_type(d)
  return {
    type = "ListType",
    inner_type = parse_node_ref(d.inner_type, parse_kcl_type_node),
  }
end

local function parse_dict_type(d)
  return {
    type = "DictType",
    key_type = parse_node_ref(d.key_type, parse_kcl_type_node),
    value_type = parse_node_ref(d.value_type, parse_kcl_type_node),
  }
end

local function parse_schema_ref_type(d)
  return {
    type = "SchemaRefType",
    schema_name = parse_node_ref(d.schema_name, parse_string_node),
    pkgpath = as_list(d.pkgpath),
  }
end

local function parse_literal_type(d)
  local raw = d.value
  if type(raw) ~= "table" then
    return { type = "LiteralType", value = { kind = "string", value = "" } }
  end
  if raw.string ~= nil then
    return { type = "LiteralType", value = { kind = "string", value = raw.string } }
  elseif raw.int ~= nil then
    return { type = "LiteralType", value = { kind = "int", value = raw.int } }
  elseif raw.float ~= nil then
    return { type = "LiteralType", value = { kind = "float", value = raw.float } }
  elseif raw.bool ~= nil then
    return { type = "LiteralType", value = { kind = "bool", value = raw.bool and true or false } }
  end
  return { type = "LiteralType", value = { kind = "string", value = "" } }
end

local function parse_function_type(d)
  return {
    type = "FunctionType",
    params = parse_node_ref_list(d.params, parse_kcl_type_node),
    ret = parse_node_ref(d.ret, parse_kcl_type_node),
  }
end

local function parse_union_type(d)
  return {
    type = "UnionType",
    any = as_bool(d.any, false),
    types = parse_node_ref_list(d.types, parse_kcl_type_node),
  }
end

local function parse_named_type(d)
  return {
    type = "NamedType",
    name = parse_node_ref(d.name, parse_identifier),
  }
end

local function parse_str_literal_type(d)
  return { type = "StrLiteralType", value = as_string(d.value, "") }
end

local function parse_int_literal_type(d)
  return { type = "IntLiteralType", value = as_int(d.value, 0) }
end

local function parse_float_literal_type(d)
  return { type = "FloatLiteralType", value = tonumber(d.value) or 0 }
end

local function parse_bool_literal_type(d)
  return { type = "BoolLiteralType", value = as_bool(d.value, false) }
end

local function parse_key_value_type(d)
  return {
    type = "KeyValueType",
    key = parse_node_ref(d.key, parse_kcl_type_node),
    value = parse_node_ref(d.value, parse_kcl_type_node),
  }
end

parse_kcl_type_node = function(d)
  local t = as_string(d.type, nil)
  if t == nil or t == "" then
    return { type = "Unknown" }
  end
  if t == "Any" then return parse_any_type() end
  if t == "Basic" then return parse_basic_type(d) end
  if t == "List" then return parse_list_type(d) end
  if t == "Dict" then return parse_dict_type(d) end
  if t == "SchemaRef" then return parse_schema_ref_type(d) end
  if t == "Literal" then return parse_literal_type(d) end
  if t == "Function" then return parse_function_type(d) end
  if t == "Union" then return parse_union_type(d) end
  if t == "Named" then return parse_named_type(d) end
  if t == "StrLiteral" then return parse_str_literal_type(d) end
  if t == "IntLiteral" then return parse_int_literal_type(d) end
  if t == "FloatLiteral" then return parse_float_literal_type(d) end
  if t == "BoolLiteral" then return parse_bool_literal_type(d) end
  if t == "KeyValue" then return parse_key_value_type(d) end
  return { type = "Unknown", wire_tag = t }
end

-- ---------------------------------------------------------------------------
-- Module / Program
-- ---------------------------------------------------------------------------

local function parse_module_dict(d)
  return {
    filename = as_string(d.filename, ""),
    doc = parse_node_ref(d.doc, parse_string_node),
    body = parse_node_ref_list(d.body, parse_stmt),
    comments = parse_node_ref_list(d.comments, parse_string_node),
  }
end

---Parse the `ast_json` field of a `ParseFileResult` into a typed
---`Module` table.
---@param ast_json string The JSON string returned by ParseFile.
---@return table A Module AST.
function M.parse_module(ast_json)
  local dict, err = json.decode(ast_json)
  if dict == nil then
    error("invalid JSON: " .. tostring(err))
  end
  if type(dict) ~= "table" then
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
  local root, err = json.decode(ast_json)
  if root == nil then
    error("invalid JSON: " .. tostring(err))
  end
  if type(root) == "table" then
    -- Legacy wire shape: root is a list of modules.
    if root[1] ~= nil or root.filename ~= nil then
      -- Detected list of dicts OR a single module dict.
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
    if type(pkgs) ~= "table" then
      error("missing field `pkgs` in program envelope")
    end
    local main_modules = pkgs.__main__ or {}
    local modules = {}
    for _, m in ipairs(main_modules) do
      modules[#modules + 1] = parse_module_dict(m)
    end
    return modules
  end
  error("expected JSON object or array at ast_json root")
end

return M
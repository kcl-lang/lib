-- ast_contract_spec.lua — The AST wire contract, asserted.
--
-- The typed AST in `kcl_lib/ast.lua` is a hand-written decoder for the JSON
-- the KCL parser emits, and a wrong guess about that JSON fails *silently*:
-- an object with no `type` key decodes to nil rather than raising, so a
-- binding that keys the `Type` registry on `"Int"` instead of `"Basic"`
-- still returns a plausible-looking tree full of empty types.
--
-- These tests decode `testdata/ast/alignment.json` — the real parser's output
-- for `testdata/ast/alignment.k`, which exercises every node shape — and
-- assert the contract documented in that directory's README. Decoding the
-- captured JSON rather than calling `parseFile` keeps this a pure test of the
-- decoder: it needs only `dkjson`, so it runs without the compiled FFI and
-- without depending on parser output staying byte-identical.

package.path = "./?.lua;./?/init.lua;" .. package.path

local ast = require("kcl_lib.ast")

local GOLDEN = "../testdata/ast/alignment.json"

local function read_file(path)
  local f = assert(io.open(path, "r"), "cannot open " .. path)
  local content = f:read("*a")
  f:close()
  return content
end

local module_ast = ast.parse_module(read_file(GOLDEN))
local stmts = {}
for _, ref in ipairs(module_ast.body) do
  stmts[#stmts + 1] = ref.node
end

---The top-level statement whose assignment target is `name`.
local function assigned(name)
  for _, s in ipairs(stmts) do
    if s.type == "Assign" and s.targets[1] ~= nil and s.targets[1].node ~= nil then
      local target = s.targets[1].node
      if target.name ~= nil and target.name.node == name then
        return s
      end
    end
  end
  return nil
end

---The top-level schema named `name`.
local function schema(name)
  for _, s in ipairs(stmts) do
    if s.type == "Schema" and s.name ~= nil and s.name.node == name then
      return s
    end
  end
  return nil
end

---The top-level type alias named `name`.
local function type_alias(name)
  for _, s in ipairs(stmts) do
    if s.type == "TypeAlias" and s.typeName ~= nil and s.typeName.node ~= nil then
      local n = s.typeName.node.names[1]
      if n ~= nil and n.node == name then
        return s
      end
    end
  end
  return nil
end

---Collect every distinct `type` string reachable from `root`.
local function collect_tags(root)
  local seen = {}
  local function walk(o)
    if type(o) ~= "table" then
      return
    end
    if type(o.type) == "string" then
      seen[o.type] = true
    end
    for _, v in pairs(o) do
      walk(v)
    end
  end
  walk(root)
  return seen
end

---`stmt.type` for every top-level statement, as a lookup set.
local function top_level_types()
  local seen = {}
  for _, s in ipairs(stmts) do
    seen[s.type] = true
  end
  return seen
end

describe("kcl_lib.ast contract", function()
  describe("coverage", function()
    it("decodes every Stmt variant", function()
      local seen = top_level_types()
      for _, tag in ipairs({ "TypeAlias", "Unification", "Assign", "AugAssign", "Assert", "If", "Import", "Rule" }) do
        assert.is_true(seen[tag])
      end
      assert.is_not_nil(schema("Person"))
      local has_attr = false
      for _, b in ipairs(schema("Person").body) do
        if b.node.type == "SchemaAttr" then
          has_attr = true
        end
      end
      assert.is_true(has_attr)
      assert.is_true(seen["Expr"])
    end)

    it("decodes every tagged Expr variant", function()
      -- `Target`, `CompClause`, `Check`, `Keyword` and `Arguments` are absent
      -- on purpose: they are plain structs, so the wire carries no tag for
      -- them and they are decoded through their DTO loaders instead.
      local seen = collect_tags(stmts)
      for _, tag in ipairs({
        "Identifier", "Unary", "Binary", "If", "Selector", "Call", "Paren",
        "Quant", "List", "ListIfItem", "ListComp", "Starred", "DictComp",
        "ConfigIfEntry", "Schema", "Config", "Lambda", "Subscript", "Compare",
        "NumberLit", "StringLit", "NameConstantLit", "JoinedString", "FormattedValue",
      }) do
        assert.is_true(seen[tag] == true, "no " .. tag .. " expression decoded")
      end
    end)

    it("decodes every Type variant", function()
      local kinds = {}
      for _, n in ipairs({ "TAny", "TList", "TDict", "TUnion", "TFunc", "TNamed", "TLitInt", "TBasic" }) do
        kinds[type_alias(n).ty.node.type] = true
      end
      local count = 0
      for _ in pairs(kinds) do
        count = count + 1
      end
      assert.are.equal(8, count)
      assert.is_true(kinds["Basic"] and kinds["Literal"] and kinds["Union"])
    end)
  end)

  describe("the three serde shapes", function()
    it('tags a Type with the shape, not the type, so basic is {"type":"Basic","value":"Int"}', function()
      -- The trap: keying a registry on `"Int"` / `"Str"` silently yields no
      -- type at all.
      local basic = type_alias("TBasic").ty.node
      assert.are.equal("Basic", basic.type)
      assert.are.equal("Str", basic.name)
      assert.are.same({ type = "Any" }, ast.parse_type({ type = "Any" }))
      assert.are.same({ type = "Basic", name = "Int" }, ast.parse_type({ type = "Basic", value = "Int" }))
      assert.are.equal("", ast.parse_type({ type = "Basic", value = 42 }).name)
    end)

    it("nests Type payloads under `value`", function()
      local list = type_alias("TList").ty.node
      assert.are.equal("List", list.type)
      assert.are.equal("Int", list.innerType.node.name)

      local dict = type_alias("TDict").ty.node
      assert.are.equal("Str", dict.keyType.node.name)
      assert.are.equal("Int", dict.valueType.node.name)

      local union = type_alias("TUnion").ty.node
      assert.are.equal("Union", union.type)
      local names = {}
      for i, x in ipairs(union.types) do
        names[i] = x.node.name
      end
      assert.are.same({ "Int", "Str" }, names)

      local fn = type_alias("TFunc").ty.node
      assert.are.equal("Function", fn.type)
      local params = {}
      for i, p in ipairs(fn.paramsTy) do
        params[i] = p.node.name
      end
      assert.are.same({ "Int", "Str" }, params)
      assert.are.equal("Bool", fn.retTy.node.name)

      local named = type_alias("TNamed").ty.node
      assert.are.equal("Cloud", named.identifier.names[1].node)
    end)

    it("tags LiteralType itself, so the payload is doubly nested", function()
      local lit = type_alias("TLitInt").ty.node
      assert.are.equal("Literal", lit.type)
      assert.are.equal("Int", lit.innerTag)
      assert.are.equal(1, lit.value.value.value)
      assert.is_nil(lit.value.value.suffix)
    end)

    it("degrades an unrecognised Type tag instead of raising", function()
      local got = ast.parse_type({ type = "Void", value = nil })
      assert.are.equal("Unknown", got.type)
      assert.are.equal("Void", got.tag)
    end)

    it("flattens newtype variants rather than wrapping them", function()
      -- `Expr::Identifier(Identifier)` is `{"type":"Identifier","names":[...]}`
      -- — there is no `identifier` wrapper key. Reading through one yields an
      -- empty identifier, silently.
      local ident = assigned("paren").value.node.expr.node
      assert.are.equal("Identifier", ident.type)
      assert.are.equal("a", ident.names[1].node)

      -- Same for `Expr::Target(Target)`, `Expr::Check`, `Expr::Keyword`,
      -- `Expr::Arguments` and `Expr::CompClause`.
      assert.are.equal("a", ast.parse_target(assigned("a").targets[1].node).name.node)
      assert.are.equal("Identifier", assigned("quant").value.node.target.node.type)
      assert.is_not_nil(assigned("call").value.node.keywords[1].node.arg.node.names)
    end)

    it("nests NumberLit.value as a tagged object, not a bare number", function()
      local num = assigned("lit_int").value.node
      assert.are.equal("NumberLit", num.type)
      assert.are.equal("Int", num.value.type)
      assert.are.equal(1, num.value.value)
      assert.are.equal("Float", assigned("lit_float").value.node.value.type)
    end)

    it("reads a NameConstantLit as the string it is, not as a boolean", function()
      -- `NameConstant` is an enum with no serde tag at all, so serde writes it
      -- as a bare JSON string. All four spellings -- "True", "False", "None",
      -- "Undefined" -- are truthy in Lua, so reading this with `as_bool`
      -- returned `true` for every one of them and the tree looked plausible:
      -- no parse reported it and no other assertion noticed.
      local lit = assigned("lit_name").value.node
      assert.are.equal("NameConstantLit", lit.type)
      assert.are.equal("True", lit.value)

      for _, spelling in ipairs({ "False", "None", "Undefined" }) do
        local decoded = ast.parse_expr({ type = "NameConstantLit", value = spelling })
        assert.are.equal(spelling, decoded.value)
      end
    end)
  end)

  describe("per-statement field names", function()
    it("reads ImportStmt flat: a path plus plain strings, no `node` wrapper", function()
      local imports = {}
      for _, s in ipairs(stmts) do
        if s.type == "Import" then
          imports[#imports + 1] = s
        end
      end
      local imp = imports[1]
      assert.are.equal("data.cloud", imp.path.node)
      assert.are.equal("data.cloud", imp.rawpath)
      assert.are.equal("cloud", imp.name)
      assert.are.equal("__main__", imp.pkgName)
      assert.is_nil(imp.asname)
      assert.are.equal("fb", imports[2].asname.node)
    end)

    it("gives AugAssign a singular target and Assign a plural one", function()
      local aug
      for _, s in ipairs(stmts) do
        if s.type == "AugAssign" then
          aug = s
        end
      end
      assert.are.equal("a", aug.target.node.name.node)
      assert.are.equal("Add", aug.op)
      assert.are.equal(2, aug.value.node.value.value)
      assert.is_true(#assigned("a").targets >= 1)
    end)

    it("wraps UnificationStmt.value in a SchemaExpr, not a bespoke config DTO", function()
      local uni
      for _, s in ipairs(stmts) do
        if s.type == "Unification" then
          uni = s
        end
      end
      assert.are.equal("u", uni.target.node.names[1].node)
      -- `SchemaExpr` is a plain struct, so it arrives with no `"type":"Schema"`
      -- tag here and has to be decoded by `parse_schema_expr` directly.
      assert.are.equal("Person", uni.value.node.name.node.names[1].node)
    end)

    it("reads test / if_cond / msg on an Assert", function()
      local asserts = {}
      for _, s in ipairs(stmts) do
        if s.type == "Assert" then
          asserts[#asserts + 1] = s
        end
      end
      assert.are.equal("Compare", asserts[1].test.node.type)
      assert.is_nil(asserts[1].ifCond)
      assert.are.equal("Identifier", asserts[2].ifCond.node.type)
      assert.are.equal("a must be positive", asserts[2].msg.node.value)
    end)

    it("gives IfStmt branches that are lists of statements", function()
      local stmt
      for _, s in ipairs(stmts) do
        if s.type == "If" then
          stmt = s
        end
      end
      assert.are.equal("Assign", stmt.body[1].node.type)
      assert.are.equal("Assign", stmt.orelse[1].node.type)
    end)

    it("reads SchemaExpr.name as an Identifier, not an Expr", function()
      local x = assigned("x")
      assert.are.equal("Schema", x.value.node.type)
      assert.are.equal("Person", x.value.node.name.node.names[1].node)
    end)

    it("reads Selector.attr and Quant.variables as Identifiers", function()
      -- `x.name.deep` is a single dotted Identifier; a Selector only appears
      -- once a subscript or a `?` breaks the chain.
      local sel = assigned("selector").value.node
      assert.are.equal("Selector", sel.type)
      assert.are.equal("Subscript", sel.value.node.type)
      assert.are.equal("name", sel.attr.node.names[1].node)
      assert.is_false(sel.hasQuestion)
      assert.is_true(assigned("optional").value.node.hasQuestion)
      assert.are.equal("v", assigned("quant").value.node.variables[1].node.names[1].node)
    end)

    it("reads lower / upper / step for a Subscript slice", function()
      local plain = assigned("subscript").value.node
      assert.is_not_nil(plain.index.node)
      assert.is_nil(plain.lower)

      local slice = assigned("subscript_slice").value.node
      assert.is_nil(slice.index)
      assert.are.equal(0, slice.lower.node.value.value)
      assert.are.equal(2, slice.upper.node.value.value)

      assert.is_not_nil(assigned("subscript_step").value.node.step.node)
    end)

    it("reads a Lambda body as statements and its args as Identifiers", function()
      local lam = assigned("lambda_expr").value.node
      assert.are.equal("Lambda", lam.type)
      assert.are.equal("p", lam.args.node.args[1].node.names[1].node)
      assert.are.equal("Int", lam.returnTy.node.name)
      assert.are.equal("Expr", lam.body[1].node.type)
    end)

    it("reads ListComp and DictComp generators as untagged CompClauses", function()
      local lc = assigned("list_if").value.node
      assert.are.equal("ListComp", lc.type)
      local gen = lc.generators[1].node
      assert.are.equal("i", gen.targets[1].node.names[1].node)
      assert.are.equal("Identifier", gen.iter.node.type)
      assert.are.equal("Compare", gen.ifs[1].node.type)

      local dc = assigned("dict_comp").value.node
      assert.are.equal("DictComp", dc.type)
      -- A DictComp has exactly one `entry: ConfigEntry` — not key/value/entry_key.
      assert.are.equal("Identifier", dc.entry.key.node.type)
      assert.are.equal("Union", dc.entry.operation)
    end)
  end)

  describe("flat DTOs", function()
    it("decodes SchemaStmt.checks as untagged Checks, not tagged Exprs", function()
      local checks = schema("Person").checks
      assert.are.equal("Compare", checks[1].node.test.node.type)
      assert.is_nil(checks[1].node.ifCond)
      assert.are.equal("Identifier", checks[2].node.ifCond.node.type)
      assert.are.equal("age must be a sane number", checks[2].node.msg.node.value)
    end)

    it("decodes a decorator as a CallExpr, not a bespoke Decorator DTO", function()
      local name_attr
      for _, b in ipairs(schema("Person").body) do
        if b.node.type == "SchemaAttr" and b.node.name ~= nil and b.node.name.node == "name" then
          name_attr = b.node
        end
      end
      assert.are.equal(2, #name_attr.decorators)
      assert.are.equal("Identifier", name_attr.decorators[1].node.func.node.type)
      assert.are.equal("deprecated", name_attr.decorators[1].node.func.node.names[1].node)
      -- The keyword arg is a Keyword whose `arg` is an Identifier.
      assert.are.equal("kwargs", name_attr.decorators[2].node.keywords[1].node.arg.node.names[1].node)
    end)

    it("reads SchemaIndexSignature off the schema body, not the header", function()
      local sig = schema("Bag").indexSignature.node
      assert.are.equal("k", sig.keyName.node)
      assert.are.equal("Str", sig.keyTy.node.name)
      assert.are.equal("Int", sig.valueTy.node.name)
      assert.is_false(sig.anyOther)
      assert.are.equal(0, sig.value.node.value.value)
    end)

    it("tags MemberOrIndex and keeps its value as a NodeRef", function()
      local paths
      for _, s in ipairs(stmts) do
        if s.type == "Assign" and s.targets[1] ~= nil and s.targets[1].node ~= nil then
          local t = s.targets[1].node
          if t.name ~= nil and t.name.node == "x" and #t.paths == 2 then
            paths = t.paths
          end
        end
      end
      assert.are.equal("Member", paths[1].type)
      assert.are.equal("name", paths[1].member.node)
      assert.are.equal("Member", paths[2].type)
      assert.are.equal("deep", paths[2].member.node)

      for _, s in ipairs(stmts) do
        if s.type == "Assign" and s.targets[1] ~= nil and s.targets[1].node ~= nil then
          for _, p in ipairs(s.targets[1].node.paths) do
            if p.type == "Index" then
              assert.is_not_nil(p.index.node)
            end
          end
        end
      end
    end)

    it("makes ConfigEntry.isShorthand a real boolean even when the key is absent", function()
      -- The wire omits `is_shorthand` when false (skip_serializing_if).
      local plain = assigned("config").value.node.items[1].node
      assert.is_false(plain.isShorthand)
      local shorthand = assigned("config_shorthand").value.node.items[1].node
      assert.is_true(shorthand.isShorthand)
      assert.are.equal("Override", shorthand.operation)
    end)

    it("keeps Arguments defaults and tyList aligned positionally", function()
      local args = assigned("lambda_expr").value.node.args.node
      assert.are.equal(1, #args.args)
      -- A Lua `nil` here would punch a hole and make `ipairs` stop, which is
      -- why the decoder substitutes `false` and why dkjson is asked to keep
      -- the null sentinel.
      assert.are.equal(1, #args.defaults)
      assert.is_false(args.defaults[1])
      assert.are.equal("Int", args.tyList[1].node.name)
    end)
  end)

  describe("direct loader checks", function()
    it("round-trips the wire shape the DTO loaders are given", function()
      assert.are.equal("Store", ast.parse_identifier({ names = {}, pkgpath = "p", ctx = "Store" }).ctx)
      assert.are.equal("a", ast.parse_target({ name = { node = "a" }, paths = {}, pkgpath = "" }).name.node)
      assert.is_nil(ast.parse_keyword({ arg = { node = { names = {} } }, value = nil }).value)
      assert.are.equal(0, #ast.parse_arguments({ args = {}, defaults = {}, ty_list = {} }).args)
      assert.is_nil(ast.parse_check({ test = { node = {} }, if_cond = nil, msg = nil }).msg)
      assert.are.equal(0, #ast.parse_call_expr({ func = { node = {} }, args = {}, keywords = {} }).args)
      assert.are.equal(0, #ast.parse_comp_clause({ targets = {}, iter = nil, ifs = {} }).ifs)
      assert.is_nil(ast.parse_schema_index_signature({ key_name = nil, any_other = false }).keyName)
      assert.is_false(ast.parse_config_entry({ key = nil, value = nil, operation = "Union" }).isShorthand)
      assert.are.same({}, ast.parse_member_or_index({ type = "Unknown" }))
    end)

    it("flags an unrecognised Expr or Stmt tag rather than dropping it", function()
      assert.are.same({ type = "Future", unknown = true }, ast.parse_expr({ type = "Future" }))
      assert.are.same({ type = "Future", unknown = true }, ast.parse_stmt({ type = "Future" }))
      assert.is_nil(ast.parse_expr({ names = {} }))
      assert.is_nil(ast.parse_stmt(nil))
    end)
  end)
end)

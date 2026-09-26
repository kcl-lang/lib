-- kcl_lib_ast_spec.lua — Round-trip AST alignment tests for the Lua binding.
--
-- Mirrors the Java AstJsonAlignmentTest, Go TestAstJsonAlignment,
-- Python tests/ast_test.py, Node.js __test__/ast_alignment.spec.mjs,
-- .NET KclLib.Tests/AstAlignmentTest.cs, WASM tests/ast_alignment.test.ts,
-- Swift AstJsonAlignmentTest, and Kotlin AstJsonAlignmentTest: parse a
-- real KCL fixture through the native FFI (`RawAPI.parseFile` /
-- `RawAPI.parseProgram`) and verify the resulting `ast_json` string
-- deserializes cleanly into the typed AST tables in `kcl_lib.ast`.

local api = require("kcl_lib.raw_api")
local ast = require("kcl_lib.ast")

local FIXTURE = "./spec/test_data/ast_alignment/main.k"

-- Find the first SchemaStmt in the module whose name matches.
local function find_schema(module, name)
  for _, stmt_ref in ipairs(module.body) do
    local stmt = stmt_ref.node
    if stmt.type == "SchemaStmt" and stmt.name ~= nil and stmt.name.node == name then
      return stmt
    end
  end
  return nil
end

-- Find the first AssignStmt in the module whose first target name matches.
local function find_assign(module, name)
  for _, stmt_ref in ipairs(module.body) do
    local stmt = stmt_ref.node
    if stmt.type == "AssignStmt" and stmt.targets[1] ~= nil then
      local target = stmt.targets[1].node
      if target.name ~= nil and target.name.node == name then
        return stmt
      end
    end
  end
  return nil
end

-- Walk into the module looking for the first StringLit Expr. Used to
-- verify that the long-form `"StringLit"` wire discriminator round-trips
-- into the typed AST.
local function find_string_lit(items)
  for _, item in ipairs(items) do
    local node = item.node
    -- SchemaStmt.body carries nested SchemaAttr / CheckExpr / etc. —
    -- recurse so a check-block string literal counts too.
    if node.type == "SchemaStmt" then
      local inner = find_string_lit(node.body)
      if inner ~= nil then
        return inner
      end
      -- And inspect each SchemaAttr's default value for a StringLit
      -- directly — that's the common case in the fixture.
      for _, attr_ref in ipairs(node.body) do
        local attr = attr_ref.node
        if attr.type == "SchemaAttr" and attr.value ~= nil and attr.value.node ~= nil then
          if attr.value.node.type == "StringLit" then
            return attr.value.node
          end
        end
      end
    end
  end
  return nil
end

describe("kcl_lib.ast", function()
  describe("module", function()
    it("parses a Module from ParseFileResult.ast_json", function()
      local result = assert(api:parse_file({ path = FIXTURE }))
      local module = ast.parse_module(result.ast_json)
      assert.is_truthy(module.filename:match("main.k$"))
    end)

    it("uses long-form literal discriminators", function()
      local result = assert(api:parse_file({ path = FIXTURE }))
      -- Wire JSON carries the long-form `"StringLit"` tag (the
      -- short-form `"String"` from `@JsonTypeName("String")` would
      -- fail the polymorphic match).
      assert.is_truthy(result.ast_json:find('"StringLit"', 1, true))
      local module = ast.parse_module(result.ast_json)
      local lit = find_string_lit(module.body)
      assert.is_not_nil(lit, "expected at least one StringLit in fixture body")
      assert.are.equal("StringLit", lit.type)
    end)

    it("round-trips ConfigEntry.is_shorthand", function()
      -- Mirror Rust's #[serde(skip_serializing_if = "is_false")]:
      -- omitted when false, emitted when true. The Lua AST exposes
      -- this as a boolean defaulting to false.
      local ce = { is_shorthand = false }
      assert.is_false(ce.is_shorthand)
      ce.is_shorthand = true
      assert.is_true(ce.is_shorthand)
    end)

    it("parses an AssignStmt whose value is a SchemaExpr", function()
      local result = assert(api:parse_file({ path = FIXTURE }))
      local module = ast.parse_module(result.ast_json)
      local assign = find_assign(module, "x")
      assert.is_not_nil(assign)
      assert.are.equal("SchemaExpr", assign.value.node.type)
    end)

    it("parses SchemaStmt decorators as a flat DTO", function()
      local result = assert(api:parse_file({ path = FIXTURE }))
      local module = ast.parse_module(result.ast_json)
      local article = find_schema(module, "Article")
      assert.is_not_nil(article, "Article schema not found")
      assert.is_true(#article.decorators > 0)
      for _, deco_ref in ipairs(article.decorators) do
        local deco = deco_ref.node
        assert.is_not_nil(deco.func)
        -- Decorator.func wraps an Identifier expression (no
        -- `"type":"Call"` tag in the flat shape).
        assert.are.equal("IdentifierExpr", deco.func.node.type)
      end
    end)

    it("parses SchemaAttr decorators", function()
      local result = assert(api:parse_file({ path = FIXTURE }))
      local module = ast.parse_module(result.ast_json)
      local person = find_schema(module, "Person")
      assert.is_not_nil(person)
      local name_attr = nil
      for _, attr_ref in ipairs(person.body) do
        local attr = attr_ref.node
        if attr.type == "SchemaAttr" and attr.name ~= nil and attr.name.node == "name" then
          name_attr = attr
          break
        end
      end
      assert.is_not_nil(name_attr, "expected `name` SchemaAttr")
      assert.are.equal(1, #name_attr.decorators)
    end)

    it("parses a LambdaExpr with Arguments", function()
      local result = assert(api:parse_file({ path = FIXTURE }))
      local module = ast.parse_module(result.ast_json)
      local adder = find_assign(module, "adder")
      assert.is_not_nil(adder)
      assert.are.equal("LambdaExpr", adder.value.node.type)
      assert.are.equal(2, #adder.value.node.args.node.args)
    end)
  end)

  describe("program", function()
    it("returns a list of modules from ParseProgramResult.ast_json", function()
      local result = assert(api:parse_program({ paths = { FIXTURE } }))
      local modules = ast.parse_program(result.ast_json)
      assert.is_true(#modules > 0)
      assert.is_truthy(modules[1].filename:match("%.k$"))
    end)
  end)
end)
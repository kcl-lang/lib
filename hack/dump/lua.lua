-- Cross-language AST dump for the Lua binding.
--
--   lua hack/dump/lua.lua <golden.json> <out.json>
--
-- Runs the binding's real decoder (`kcl_lib.ast.parse_module`) over the shared
-- capture and writes the tree in the shape `hack/ast_diff/canonical.rb`
-- compares.
--
-- Lua has no classes, so the walk has no class name to record and no `@cls`:
-- the decoder's own claim is the `type` string it keeps verbatim, and that is
-- mirrored into `@tag`. The report says the class cross-check was unavailable
-- for this binding.
--
-- Two Lua-specific things the walk has to get right:
--
--   * `dkjson` maps a JSON `null` to `nil`, and a table cannot hold `nil`, so
--     the binding decodes with a `json.null` sentinel. The comparator's R14
--     reads a `false` element as an absent one; here a `json.null` is written
--     as JSON `null` so the golden and the dump agree on the shape and the
--     rule is the only thing reading between them.
--   * An absent element in a decoded list is `false` rather than `nil`, or
--     `ipairs` would stop early. Written out as `null` for the same reason.

local json = require("dkjson")

-- The binding's own spec (`lua/spec/ast_contract_spec.lua`) runs with `lua/` as
-- the working directory, so its `package.path` is relative to that. This
-- dumper runs from the repository root like every other one here, so the
-- prefix has to name the binding's directory explicitly. `dkjson` is
-- installed by luarocks and is already on the default path.
package.path = "./?.lua;./?/init.lua;lua/?.lua;lua/?/init.lua;" .. package.path
local ast = require("kcl_lib.ast")

---Recursively copy a decoded Lua value into something `dkjson` can write.
--@param v any
--@return any
local function dump(v)
  if v == nil or v == json.null then
    return json.null
  end
  local t = type(v)
  if t ~= "table" then
    return v
  end

  -- A Lua table is either an array or an object, and dkjson decides which by
  -- looking for a `[1]`. The decoder never mixes the two, so neither do we.
  local out = {}
  if v[1] ~= nil or next(v) == nil then
    for i, item in ipairs(v) do
      out[i] = dump(item)
    end
    -- `ipairs` stops at the first nil, but a list built by `node_ref_list`
    -- never has one: absent elements are `false`. An array with holes would
    -- silently lose its tail here, so say so rather than write a short one.
    local n = 0
    for k in pairs(v) do
      if type(k) == "number" and k > n then
        n = k
      end
    end
    for i = #out + 1, n do
      out[i] = json.null
    end
    return out
  end

  for k, item in pairs(v) do
    if k == "type" and type(item) == "string" then
      out["@tag"] = item
    end
    out[k] = dump(item)
  end
  return out
end

local golden_path, out_path = arg[1], arg[2]
if golden_path == nil or out_path == nil then
  io.stderr:write("usage: lua hack/dump/lua.lua <golden.json> <out.json>\n")
  os.exit(2)
end

local fh = assert(io.open(golden_path, "r"), "cannot open " .. golden_path)
local golden = fh:read("*a")
fh:close()

local module_ast = ast.parse_module(golden)

local doc = {
  schema = "kcl-ast-canonical/1",
  binding = "lua",
  mode = "reflect",
  root = dump(module_ast),
}

local ofh = assert(io.open(out_path, "w"), "cannot write " .. out_path)
ofh:write(json.encode(doc, { indent = true, sort_keys = false }))
ofh:write("\n")
ofh:close()

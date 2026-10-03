local json = require("dkjson")

local kcl_lib = require("kcl_lib")
local api = require("kcl_lib.api")

describe("kcl_lib plugins", function()
  after_each(function()
    kcl_lib.disable_plugins()
  end)

  it("routes a KCL call into a registered Lua function", function()
    kcl_lib.register_plugin("strings", "join", function()
      return json.encode("KCL.KCL.123")
    end)
    local result = api:run([[import kcl_plugin.strings
result = strings.join("KCL", "KCL", 123)]])
    assert.are.equal("KCL.KCL.123", result:get("result"))
  end)

  it("passes the arguments as JSON strings", function()
    local seen_args, seen_kwargs
    kcl_lib.register_plugin("strings", "args", function(args, kwargs)
      seen_args, seen_kwargs = args, kwargs
      return json.encode({ args = json.decode(args), kwargs = json.decode(kwargs) })
    end)
    local result = api:run([[import kcl_plugin.strings
result = strings.args("a", b = 2)]])
    assert.are.same({ "a" }, seen_args and json.decode(seen_args) or nil)
    assert.are.same({ b = 2 }, seen_kwargs and json.decode(seen_kwargs) or nil)
    assert.are.same({ "a" }, result:get("result.args"))
    assert.are.equal(2, result:get("result.kwargs.b"))
  end)

  it("reports an unknown method as a KCL error rather than crashing", function()
    kcl_lib.register_plugin("strings", "join", function()
      return json.encode("unused")
    end)
    local ok, err = pcall(function()
      api:run([[import kcl_plugin.strings
result = strings.nope()]])
    end)
    assert.is_false(ok)
    assert.is_truthy(tostring(err):find("nope"))
  end)

  it("keeps working after the registry is cleared", function()
    kcl_lib.register_plugin("strings", "join", function()
      error("must not be called")
    end)
    kcl_lib.disable_plugins()
    local result = api:run("a = 1\n")
    assert.are.equal(1, result:get("a"))
  end)
end)

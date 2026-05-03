local io = require("io")
local os = require("os")

local kcl_lib = require("kcl_lib")

describe("kcl_lib", function()
  describe("run", function()
    it("should take a single path, run it, and return the result", function()
      local expected = [[app:
  replicas: 2]]
      local result = assert(kcl_lib.run("./spec/test_data/schema.k"))
      assert.are.equal(expected, result.yaml_result)
    end)

    it(
      "should take an array of paths, run them, and return the result",
      function()
        local expected = [[app:
  replicas: 2
app2:
  replicas: 4]]
        local result = assert(kcl_lib.run({
          "./spec/test_data/schema.k",
          "./spec/test_data/data.k",
        }))
        assert.are.equal(expected, result.yaml_result)
      end
    )
  end)

  describe("format", function()
    local unformated_file = "/tmp/unformated.k"
    local unformated_content = [[
schema AppConfig:
    replicas: int

app: AppConfig {
        replicas: 2
}]]
    local expected_content = [[schema AppConfig:
    replicas: int

app: AppConfig {
    replicas: 2
}
]]

    it(
      "should take a single path to unformated code, properly format it, and the path",
      function()
        local file = assert(
          io.open(unformated_file, "w"),
          "failed to open test file for formatting"
        )
        file:write(unformated_content)
        file:close()
        local result = assert(kcl_lib.format(unformated_file))
        assert.are.same({ unformated_file }, result)
        file = assert(
          io.open(unformated_file, "r"),
          "failed to open formatted file for reading"
        )
        local data = file:read("*a")
        file:close()
        assert.are.equal(expected_content, data)
        os.execute("rm " .. unformated_file)
      end
    )

    it(
      "should take a single path to formated code, do nothing, and return an empty table",
      function()
        local file = assert(
          io.open(unformated_file, "w"),
          "failed to open test file for formatting"
        )
        file:write(expected_content)
        file:close()
        local result = assert(kcl_lib.format(unformated_file))
        assert.are.same({}, result)
        os.execute("rm " .. unformated_file)
      end
    )
  end)
end)

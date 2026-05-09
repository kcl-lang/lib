local io = require("io")
local os = require("os")

local api = require("kcl_lib.raw_api")

describe("kcl_lib.raw_api", function()
  describe("exec_program", function()
    it("can call the native function", function()
      local expected = [[app:
  replicas: 2
app2:
  replicas: 4]]
      local args = {
        k_filename_list = {
          "./spec/test_data/schema.k",
          "./spec/test_data/data.k",
        },
      }
      local result = assert(api:exec_program(args))
      assert.are.equal(expected, result.yaml_result)
    end)
  end)

  describe("format_path", function()
    it("can call the native function", function()
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
      local file = assert(
        io.open(unformated_file, "w"),
        "failed to open test file for formatting"
      )
      file:write(unformated_content)
      file:close()
      local args = { path = unformated_file }
      local result = assert(api:format_path(args))
      assert.are.same({ unformated_file }, result.changed_paths)
      file = assert(
        io.open(unformated_file, "r"),
        "failed to open formatted file for reading"
      )
      local data = file:read("*a")
      file:close()
      assert.are.equal(expected_content, data)
      assert(os.remove(unformated_file))
    end)
  end)
end)

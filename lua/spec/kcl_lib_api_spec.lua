local api = require("kcl_lib.api")

describe("kcl_lib.api", function()
  describe("run", function()
    it("takes a file to run and returns its output", function()
      local expected = [[app:
  replicas: 2]]
      local result = api:run("./spec/test_data/schema.k")
      assert.are.equal(expected, result:yaml())
    end)

    it("can take a list of files to run", function()
      local result =
        api:run({ "./spec/test_data/schema.k", "./spec/test_data/data.k" })
      local tbl = result:object()
      assert.are.equal(2, tbl.app.replicas)
      assert.are.equal(4, tbl.app2.replicas)
    end)
  end)
end)

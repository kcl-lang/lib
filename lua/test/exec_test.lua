local kcl_lib = require("kcl_lib")

describe("kcl lua lib unit test", function()
  describe("exec_program", function()
    it("operator function in fs schema", function()
      local result, err = kcl_lib.exec_program({k_filename_list=["./test_data/schema.k"]})
      assert.is_nil(err)
      assert.are.equal(result.yaml_result, "app:\n  replicas: 2")
    end)
  end)
end)

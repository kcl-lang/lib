local kcl_lib = require("kcl_lib")

describe("kcl_lib", function()
  describe("new_client", function()
    it("creates a new client", function()
      assert(kcl_lib.new_client())
    end)
  end)
end)

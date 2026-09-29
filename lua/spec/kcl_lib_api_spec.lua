local json = require("dkjson")

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

    it("takes a code string to run and returns its output", function()
      local result = api:run("a = 1\nb = 2")
      assert.are.equal([[a: 1
b: 2]], result:yaml())
    end)

    it("reads values via a dotted path with get", function()
      local result = api:run("app = {replicas = 2, metadata = {name = \"x\"}}")
      assert.are.equal(2, result:get("app.replicas"))
      assert.are.equal("x", result:get("app.metadata.name"))
    end)

    it("returns nil from get for missing paths", function()
      local result = api:run("app = {replicas = 2}")
      assert.is_nil(result:get("app.missing"))
      assert.is_nil(result:get("missing.replicas"))
      assert.is_nil(result:get("app.replicas.deeper"))
    end)

    it("applies -D args as option values", function()
      local result = api:run('name = option("name", default = "d")', {
        args = { "name=hello" },
      })
      assert.are.equal("hello", result:get("name"))
    end)

    it("skips -D args specs without a name", function()
      local result = api:run('name = option("name", default = "d")', {
        args = { "=noname", "name=hello" },
      })
      assert.are.equal("hello", result:get("name"))
    end)

    it("applies overrides", function()
      local result = api:run("a = 1\nb = 2", {
        overrides = { "b=3" },
      })
      assert.are.equal(1, result:get("a"))
      assert.are.equal(3, result:get("b"))
    end)

    it("applies overrides to files", function()
      local result = api:run("./spec/test_data/schema.k", {
        overrides = { "app.replicas=5" },
      })
      assert.are.equal(5, result:get("app.replicas"))
    end)

    it("selects output paths with selectors", function()
      local result = api:run({
        "./spec/test_data/schema.k",
        "./spec/test_data/data.k",
      }, { selectors = { "app2" } })
      assert.are.equal([[replicas: 4]], result:yaml())
    end)

    it("requests json output with format", function()
      local result = api:run("a = 1", { format = "json" })
      assert.are.equal("", result:yaml())
      assert.are.equal(1, result:get("a"))
    end)

    it("omits none values with disable_none", function()
      local result = api:run("a = None\nb = 1", { disable_none = true })
      assert.are.equal("b: 1", result:yaml())
    end)

    it("shows hidden attributes with show_hidden", function()
      local result = api:run("_hidden = 1", { show_hidden = true })
      assert.are.equal("_hidden: 1", result:yaml())
    end)

    it("raises an error with a non-empty err_message", function()
      local ok, err = pcall(function()
        api:run("a =")
      end)
      assert.is_false(ok)
      assert.is_not_nil(string.find(tostring(err), "InvalidSyntax", 1, true))
    end)

    it("returns the error in the response with strict = false", function()
      local result = api:run("a =", { strict = false })
      assert.is_not_nil(
        string.find(result:err_message(), "InvalidSyntax", 1, true)
      )
    end)

    it("takes explicit code via opts", function()
      local result = api:run(nil, { code = "x = 1" })
      assert.are.equal(1, result:get("x"))
    end)

    it("takes explicit files via opts", function()
      local result = api:run(nil, {
        files = { "./spec/test_data/schema.k" },
      })
      assert.are.equal(2, result:get("app.replicas"))
    end)

    describe("settings", function()
      it("merges kcl_options from a settings file", function()
        local result = api:run('v = option("key")', {
          settings = { "./spec/test_data/kcl-settings.yaml" },
        })
        assert.are.equal("value", result:get("v"))
      end)

      it("runs files listed in a settings file", function()
        local result = api:run(nil, {
          settings = { "./spec/test_data/kcl-settings-with-files.yaml" },
          work_dir = "./spec/test_data",
        })
        assert.are.equal(2, result:get("app.replicas"))
      end)

      it("lets explicit opts take precedence over settings", function()
        local result = api:run('v = option("key")', {
          settings = { "./spec/test_data/kcl-settings.yaml" },
          args = { "key=override" },
        })
        assert.are.equal("override", result:get("v"))
      end)
    end)

    describe("schema type path", function()
      it("rewrites _type attributes to the short name", function()
        local result = api:run("./spec/test_data/typepath/main.k", {
          include_schema_type_path = true,
        })
        assert.are.equal("AppConfig", result:get("app._type"))
        assert.is_not_nil(
          string.find(result:yaml(), "_type: AppConfig", 1, true)
        )
      end)

      it("keeps the full type path with full_schema_type_path", function()
        local result = api:run("./spec/test_data/typepath/main.k", {
          full_schema_type_path = true,
        })
        assert.are.equal("sub.AppConfig", result:get("app._type"))
        assert.is_not_nil(
          string.find(result:yaml(), "_type: sub.AppConfig", 1, true)
        )
      end)
    end)
  end)

  describe("validate", function()
    it("validates data against a schema", function()
      local result = api:validate({
        code = "schema Person:\n  name: str",
        data = "name: Alice",
      })
      assert.is_true(result.success)
    end)

    it("validates json data against a schema", function()
      local result = api:validate({
        code = "schema Person:\n  name: str",
        data = '{"name": "Alice"}',
        format = "json",
      })
      assert.is_true(result.success)
    end)

    it("raises an error when validation fails", function()
      local ok, err = pcall(function()
        api:validate({
          code = "schema Person:\n  name: str",
          data = '{"name": 123}',
          format = "json",
        })
      end)
      assert.is_false(ok)
      assert.is_not_nil(string.find(tostring(err), "expected str", 1, true))
    end)
  end)

  describe("format_code", function()
    it("formats an in-memory source string", function()
      local formatted = api:format_code("a   =   1")
      assert.are.equal("a = 1\n", formatted)
    end)
  end)

  describe("format_path", function()
    it("formats files under a path and returns the changed paths", function()
      local filename = os.tmpname() .. ".k"
      local file = assert(
        io.open(filename, "w"),
        "failed to open test file for formatting"
      )
      file:write("a   =   1\n")
      file:close()
      local changed = api:format_path(filename)
      assert.are.same({ filename }, changed)
      assert(os.remove(filename))
    end)

    it("reports changes without rewriting them with dry_run", function()
      local filename = os.tmpname() .. ".k"
      local unformatted = "a   =   1\n"
      local file = assert(
        io.open(filename, "w"),
        "failed to open test file for formatting"
      )
      file:write(unformatted)
      file:close()
      local changed = api:format_path(filename, { dry_run = true })
      assert.are.same({ filename }, changed)
      file = assert(
        io.open(filename, "r"),
        "failed to open unformatted file for reading"
      )
      local data = file:read("*a")
      file:close()
      assert.are.equal(unformatted, data)
      assert(os.remove(filename))
    end)
  end)

  describe("lint_path", function()
    it("returns lint diagnostics for a list of paths", function()
      local results = api:lint_path({ "./spec/test_data/lint_err.k" })
      assert.are.equal("Module 'math' imported but unused", results[1])
    end)

    it("accepts a single path string and returns an empty list when clean",
      function()
        local results = api:lint_path("./spec/test_data/schema.k")
        assert.are.same({}, results)
      end)
  end)

  describe("test", function()
    it("runs KCL unit tests and returns the case info", function()
      local result = api:test({ pkg_list = { "./spec/test_data/test/..." } })
      assert.are.equal(3, #result.info)
    end)
  end)

  describe("rename", function()
    it("renames a symbol across files", function()
      local filename = os.tmpname()
      assert(
        os.execute("cp ./spec/test_data/options.k " .. filename),
        "failed to copy options.k to temporary file"
      )
      local result = api:rename({
        package_root = filename:match("^(.*)/[^/]*$") or ".",
        symbol_path = "a",
        file_paths = { filename },
        new_name = "z",
      })
      -- The runtime canonicalizes paths (/tmp -> /private/tmp on macOS),
      -- so only the number of changed files is asserted here.
      assert.are.equal(1, #result.changed_files)
      local file = assert(
        io.open(filename, "r"),
        "failed to open renamed file for reading"
      )
      local data = file:read("*a")
      file:close()
      local expected_content = [[z = option("key1")
b = option("key2", required=True)
c = {
    metadata.key = option("metadata-key")
}]]
      assert.are.equal(expected_content, data)
      assert(os.remove(filename))
    end)
  end)

  describe("rename_code", function()
    it("renames a symbol in in-memory sources", function()
      local result = api:rename_code({
        package_root = "/tmp",
        symbol_path = "a",
        source_codes = { ["/tmp/rename.k"] = "a = 1" },
        new_name = "z",
      })
      assert.are.equal("z = 1", result.changed_codes["/tmp/rename.k"])
    end)
  end)

  describe("parse_file", function()
    it("parses a file into an AST", function()
      local result = api:parse_file("./spec/test_data/schema.k")
      assert(json.decode(result.ast_json))
    end)
  end)
end)

local io = require("io")
local os = require("os")

local json = require("dkjson")
local pl_path = require("pl.path")

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

    it("accepts format and sourcemap_output fields", function()
      local args = {
        k_filename_list = {
          "./spec/test_data/schema.k",
          "./spec/test_data/data.k",
        },
        format = "json",
        sourcemap_output = os.tmpname() .. ".map",
      }
      local result = assert(api:exec_program(args))
      assert.are.equal("", result.yaml_result)
      local parsed = assert(json.decode(result.json_result))
      assert.are.equal(2, parsed.app.replicas)
      assert.are.equal(4, parsed.app2.replicas)
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

  describe("ping", function()
    it("can call the native function", function()
      local args = { value = "test" }
      local result = assert(api:ping(args))
      assert.are.equal("test", result.value)
    end)
  end)

  describe("get_version", function()
    it("can call the native function", function()
      local args = {}
      local result = assert(api:get_version(args))
      assert.is.match("%d+%.%d+%.%d+", result.version)
    end)
  end)

  describe("parse_program", function()
    it("can call the native function", function()
      local args = { paths = { "./spec/test_data/schema.k" } }
      local result = assert(api:parse_program(args))
      assert(json.decode(result.ast_json))
    end)
  end)

  describe("parse_file", function()
    it("can call the native function", function()
      local args = { path = "./spec/test_data/schema.k" }
      local result = assert(api:parse_file(args))
      assert(json.decode(result.ast_json))
    end)
  end)

  describe("load_package", function()
    it("can call the native function", function()
      local args = {
        parse_args = { paths = { "./spec/test_data/schema.k" } },
        resolve_ast = true,
      }
      local result = assert(api:load_package(args))
      assert(json.decode(result.program))
    end)
  end)

  describe("list_options", function()
    it("can call the native function", function()
      local args = { paths = { "./spec/test_data/options.k" } }
      local result = assert(api:list_options(args))
      assert.are.equal(3, #result.options)
    end)
  end)

  describe("list_variables", function()
    it("can call the native function", function()
      local args = { files = { "./spec/test_data/schema.k" } }
      local result = assert(api:list_variables(args))
      assert.are.equal("AppConfig", result.variables.app.variables[1].type_name)
    end)
  end)

  describe("format_code", function()
    it("can call the native function", function()
      local args = { source = "a   =   1" }
      local result = assert(api:format_code(args))
      assert.are.equal("a = 1\n", result.formatted)
    end)
  end)

  describe("lint_path", function()
    it("can call the native function", function()
      local args = { paths = { "./spec/test_data/lint_err.k" } }
      local result = assert(api:lint_path(args))
      assert.are.equal("Module 'math' imported but unused", result.results[1])
    end)
  end)

  describe("override_file", function()
    it("can call the native function", function()
      local filename = os.tmpname()
      assert(
        os.execute("cp ./spec/test_data/schema.k " .. filename),
        "failed to copy schema.k to temporary file"
      )
      local args = { file = filename, specs = { "a=1" } }
      local result = assert(api:override_file(args))
      assert.is.truthy(result.result)
      local file = assert(
        io.open(filename, "r"),
        "failed to open temporary file for reading"
      )
      local data = file:read("*a")
      file:close()
      local expected_content = [[schema AppConfig:
    replicas: int

app: AppConfig {
    replicas: 2
}
a = 1
]]
      assert.are.equal(expected_content, data)
      assert(os.remove(filename))
    end)
  end)

  describe("get_schema_type_mapping", function()
    it("can call the native function", function()
      local args =
        { exec_args = { k_filename_list = { "./spec/test_data/schema.k" } } }
      local result = assert(api:get_schema_type_mapping(args))
      assert.are.equal(
        "int",
        result.schema_type_mapping["app"].properties.replicas.type
      )
    end)
  end)

  describe("get_schema_type_mapping_under_path", function()
    it("keeps external dependency schemas in their own package", function()
      -- The runtime resolves package paths against the work dir, so the
      -- fixture paths must be absolute (mirrors the python/go tests).
      local root = pl_path.abspath("./spec/test_data/get_schema_ty_under_path")
      local args = {
        exec_args = {
          k_filename_list = { root .. "/aaa" },
          external_pkgs = {
            { pkg_name = "bbb", pkg_path = root .. "/bbb" },
          },
        },
      }
      local result = assert(api:get_schema_type_mapping_under_path(args))
      local mapping = result.schema_type_mapping
      assert.is_not_nil(mapping["__main__"])
      assert.is_not_nil(mapping["bbb"])
      local schemas = {}
      for _, sty in ipairs(mapping["bbb"].schema_type) do
        schemas[sty.schema_name] = sty
      end
      assert.is_not_nil(schemas["Base"])
      assert.is_not_nil(schemas["B"])
      assert.are.equal("bbb", schemas["Base"].pkg_path)
      assert.are.equal("bbb", schemas["B"].pkg_path)
      -- Regression test for https://github.com/kcl-lang/kcl/issues/1546:
      -- the base schema must resolve across the package boundary.
      assert.are.equal("Base", schemas["B"].base_schema.schema_name)
      assert.are.equal("bbb", schemas["B"].base_schema.pkg_path)
    end)
  end)

  describe("validate_code", function()
    it("can call the native function", function()
      local args = {
        code = "schema Person:\n  name: str",
        data = '{"name": "Alice"}',
        format = "json",
      }
      local result = assert(api:validate_code(args))
      assert.are.equal(true, result.success)
    end)
  end)

  describe("load_settings_files", function()
    it("can call the native function", function()
      local args =
        { work_dir = ".", files = { "./spec/test_data/kcl-settings.yaml" } }
      local result = assert(api:load_settings_files(args))
      assert.are.equal("key", result.kcl_options[1].key)
    end)
  end)

  describe("rename", function()
    it("can call the native function", function()
      local filename = os.tmpname()
      assert(
        os.execute("cp ./spec/test_data/options.k " .. filename),
        "failed to copy options.k to temporary file"
      )
      local args = {
        package_root = pl_path.dirname(filename),
        symbol_path = "a",
        file_paths = { filename },
        new_name = "z",
      }
      local result = assert(api:rename(args))
      assert.are.equal(1, #result.changed_files)
      local file = assert(
        io.open(filename, "r"),
        "failed to open temporary file for reading"
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
    it("can call the native function", function()
      local args = {
        package_root = "/tmp",
        symbol_path = "a",
        source_codes = { ["/tmp/rename.k"] = "a = 1" },
        new_name = "z",
      }
      local result = assert(api:rename_code(args))
      assert.are.equal("z = 1", result.changed_codes["/tmp/rename.k"])
    end)
  end)

  describe("test", function()
    it("can call the native function", function()
      local args = { pkg_list = { "./spec/test_data/test/..." } }
      local result = assert(api:test(args))
      assert.are.equal(3, #result.info)
    end)
  end)

  describe("format_test_report", function()
    -- The pinned `kcl-api` git revision predates this RPC: the dispatcher
    -- panics with "unknown method name" and answers with an empty payload,
    -- so the wrapper decodes an empty `report`. Skip in that case, the way
    -- `list_method` below tolerates its unregistered RPC, and assert the
    -- documented report whenever the runtime does implement it.
    it("renders a test result as a pretty-printed report", function()
      -- `duration` is microseconds; the report truncates it to whole
      -- milliseconds by integer division, so 1500 renders as `1ms`.
      local args = {
        result = {
          info = {
            { name = "test_case_1", duration = 1500 },
            {
              name = "test_case_2",
              error = "Error: assert failed",
              duration = 2500,
            },
          },
        },
      }
      local result = assert(api:format_test_report(args))
      if result.report == "" then
        pending(
          "the native runtime does not implement KclService.FormatTestReport"
        )
        return
      end
      local expected = table.concat({
        "test_case_1: PASS (1ms)",
        "test_case_2: FAIL (2ms)",
        "Error: assert failed",
        string.rep("-", 80),
        "PASS: 1/2",
        "FAIL: 1/2",
      }, "\n") .. "\n"
      assert.are.equal(expected, result.report)
    end)

    it("renders an empty result as the no-test-files line", function()
      local result = assert(api:format_test_report({}))
      if result.report == "" then
        pending(
          "the native runtime does not implement KclService.FormatTestReport"
        )
        return
      end
      assert.are.equal("no test files\n", result.report)
    end)
  end)

  describe("update_dependencies", function()
    it("can call the native function", function()
      local args = { manifest_path = "./spec/test_data/module" }
      assert(api:update_dependencies(args))
    end)
  end)

  describe("list_method", function()
    -- Prebuilt libkcl v0.13.0 predates the `BuiltinService` registration
    -- (mirrors the Julia and Zig bindings): the dispatcher either answers
    -- with an empty payload (decoded as `method_name_list == {}`) or
    -- surfaces an `ERROR:`-prefixed string that the raw wrapper raises as
    -- a Lua error. Tolerate both and, when the runtime implements the RPC,
    -- assert it advertises the documented KclService RPCs.
    it("can call the native function", function()
      local ok, result = pcall(api.list_method, api, {})
      if not ok then
        return
      end
      assert.is_table(result.method_name_list)
      if #result.method_name_list == 0 then
        return
      end
      local found_exec, found_ping = false, false
      for _, name in ipairs(result.method_name_list) do
        if name == "KclService.ExecProgram" then
          found_exec = true
        end
        if name == "KclService.Ping" then
          found_ping = true
        end
      end
      assert.is_true(found_exec)
      assert.is_true(found_ping)
    end)
  end)
end)

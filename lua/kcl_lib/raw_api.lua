local kcl_lib = require("kcl_lib")
local schema = require("kcl_lib.schema")

---@class kcl_lib.RawAPI
local RawAPI = {}

---Create a new API object.
---@return kcl_lib.RawAPI
function RawAPI:new()
  local pb = require("pb")
  pb.clear()
  assert(pb.load(schema))
  local o = {
    pb = pb,
    client = assert(kcl_lib.new_client(), "failed to create native KCL client"),
  }
  setmetatable(o, self)
  self.__index = self
  o.overrides = {}
  return o
end

---Add a method to the raw API.
---@param name string The KCL service function name to call.
---@param arg_name string The name of the argument type that the method accepts.
---@param return_name string The name of the return type that the method returns.
---@return function
local function add_method(name, arg_name, return_name)
  return function(self, args)
    local arg_type = ".com.kcl.api." .. arg_name
    args = assert(
      self.pb.encode(arg_type, args),
      "failed to encode argument into " .. arg_type
    )
    local res = assert(
      self.client:call(name, args),
      "failed to perform native call for method " .. name
    )
    -- The native FFI service reports failures as plain-text responses
    -- prefixed with "ERROR:" rather than a protobuf message; surface them
    -- as a Lua error here (mirrors the Go native client's protocol check).
    if res:sub(1, 6) == "ERROR:" then
      error(res:sub(7), 0)
    end
    local return_type = ".com.kcl.api." .. return_name
    return assert(
      self.pb.decode(return_type, res),
      "failed to decode buffer into " .. return_type
    )
  end
end

RawAPI.ping = add_method("KclService.Ping", "PingArgs", "PingResult")

RawAPI.get_version =
  add_method("KclService.GetVersion", "GetVersionArgs", "GetVersionResult")

RawAPI.parse_program = add_method(
  "KclService.ParseProgram",
  "ParseProgramArgs",
  "ParseProgramResult"
)

RawAPI.parse_file =
  add_method("KclService.ParseFile", "ParseFileArgs", "ParseFileResult")

RawAPI.load_package =
  add_method("KclService.LoadPackage", "LoadPackageArgs", "LoadPackageResult")

RawAPI.list_options =
  add_method("KclService.ListOptions", "ParseProgramArgs", "ListOptionsResult")

RawAPI.list_variables = add_method(
  "KclService.ListVariables",
  "ListVariablesArgs",
  "ListVariablesResult"
)

RawAPI.exec_program =
  add_method("KclService.ExecProgram", "ExecProgramArgs", "ExecProgramResult")

RawAPI.format_code =
  add_method("KclService.FormatCode", "FormatCodeArgs", "FormatCodeResult")

RawAPI.format_path =
  add_method("KclService.FormatPath", "FormatPathArgs", "FormatPathResult")

RawAPI.lint_path =
  add_method("KclService.LintPath", "LintPathArgs", "LintPathResult")

RawAPI.override_file = add_method(
  "KclService.OverrideFile",
  "OverrideFileArgs",
  "OverrideFileResult"
)

RawAPI.get_schema_type_mapping = add_method(
  "KclService.GetSchemaTypeMapping",
  "GetSchemaTypeMappingArgs",
  "GetSchemaTypeMappingResult"
)

RawAPI.get_schema_type_mapping_under_path = add_method(
  "KclService.GetSchemaTypeMappingUnderPath",
  "GetSchemaTypeMappingArgs",
  "GetSchemaTypeMappingUnderPathResult"
)

RawAPI.validate_code = add_method(
  "KclService.ValidateCode",
  "ValidateCodeArgs",
  "ValidateCodeResult"
)

RawAPI.load_settings_files = add_method(
  "KclService.LoadSettingsFiles",
  "LoadSettingsFilesArgs",
  "LoadSettingsFilesResult"
)

RawAPI.rename = add_method("KclService.Rename", "RenameArgs", "RenameResult")

RawAPI.rename_code =
  add_method("KclService.RenameCode", "RenameCodeArgs", "RenameCodeResult")

RawAPI.test = add_method("KclService.Test", "TestArgs", "TestResult")

-- `KclService.FormatTestReport`: renders a `TestResult` — typically the one
-- `RawAPI.test` just returned — into a human-readable report. The output is
-- byte-identical to the kcl-go `PrettyReporter` format, deterministic for a
-- given result, and every line (including the last) ends with a newline:
-- one `{name}: {PASS|FAIL} ({ms}ms)` line per case in result order, then a
-- separator of exactly 80 `-`, then the non-zero `PASS:`/`FAIL:`/`SKIPPED:`
-- counts. An empty result renders as `no test files\n`. The `ms` value is the
-- case duration in microseconds truncated to whole milliseconds.
RawAPI.format_test_report = add_method(
  "KclService.FormatTestReport",
  "FormatTestReportArgs",
  "FormatTestReportResult"
)

RawAPI.update_dependencies = add_method(
  "KclService.UpdateDependencies",
  "UpdateDependenciesArgs",
  "UpdateDependenciesResult"
)

-- The five `KclService.Generate*` RPCs below synthesize source in one
-- representation from another. They are declared after `UpdateDependencies` in
-- `spec/spec.proto` and are grouped here in the same order.
--
-- None of them is implemented by the pinned `kcl-api` revision this binding
-- compiles against (see the `list_method` note below): the dispatcher answers
-- with an empty payload, which decodes to an empty result field, or raises
-- `ERROR: unknown method name`. Callers should `pcall` and treat an empty
-- result as "this core is too old", the way `list_method` does.

-- `GenerateTomlArgs.exec_args` carries the program to evaluate; the rendered
-- document comes back in `GenerateTomlResult.toml`.
RawAPI.generate_toml = add_method(
  "KclService.GenerateToml",
  "GenerateTomlArgs",
  "GenerateTomlResult"
)

-- `GenerateKclArgs.format` selects the source dialect of `source`; when it is
-- empty the extension of `filename` is used, defaulting to JSON. The KCL
-- source comes back in `GenerateKclResult.kcl`.
RawAPI.generate_kcl =
  add_method("KclService.GenerateKcl", "GenerateKclArgs", "GenerateKclResult")

-- `GenerateOpenAPIArgs.version` is `"v3"` (default) or `"v2"` for Swagger 2.0;
-- the OpenAPI document comes back in `GenerateOpenAPIResult.spec`.
RawAPI.generate_openapi = add_method(
  "KclService.GenerateOpenAPI",
  "GenerateOpenAPIArgs",
  "GenerateOpenAPIResult"
)

-- `GenerateProtoArgs.package` is the protobuf package to declare; the
-- `.proto` source comes back in `GenerateProtoResult.proto`.
RawAPI.generate_proto = add_method(
  "KclService.GenerateProto",
  "GenerateProtoArgs",
  "GenerateProtoResult"
)

-- `GenerateDocArgs.format` is `"md"` (default), `"openapi"` or
-- `"json-schema"`; `"html"` is not supported yet. The rendered document comes
-- back in `GenerateDocResult.content`.
RawAPI.generate_doc =
  add_method("KclService.GenerateDoc", "GenerateDocArgs", "GenerateDocResult")

-- `BuiltinService.ListMethod`: lists every method exposed by the native
-- dispatcher. `ListMethodArgs` is an empty protobuf message, so callers pass
-- `{}` as the request.
--
-- The `BuiltinService.*` names are the exception to the "everything is
-- `KclService.*`" rule: the core registers `BuiltinService.Ping` and
-- `BuiltinService.ListMethod` under exactly those names, and there is no
-- `KclService.ListMethod` alias. The registry has 28 entries; it grew in
-- v0.13.1, which added `FormatTestReport` and the five `Generate*` RPCs and
-- dropped `KclService.ListDepFiles` (dependency data now rides on
-- `LoadPackageResult.imports` / `kcl_mod` / `apps`).
RawAPI.list_method =
  add_method("BuiltinService.ListMethod", "ListMethodArgs", "ListMethodResult")

return RawAPI:new()

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

RawAPI.update_dependencies = add_method(
  "KclService.UpdateDependencies",
  "UpdateDependenciesArgs",
  "UpdateDependenciesResult"
)

return RawAPI:new()

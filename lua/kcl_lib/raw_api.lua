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

RawAPI.exec_program =
  add_method("KclService.ExecProgram", "ExecProgramArgs", "ExecProgramResult")

RawAPI.format_path =
  add_method("KclService.FormatPath", "FormatPathArgs", "FormatPathResult")

return RawAPI:new()

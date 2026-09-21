local api = require("kcl_lib.raw_api")
local types = require("kcl_lib.types")

---@class kcl_lib.API
---@field private raw kcl_lib.RawAPI The object to access the raw API.
local API = {}

---Create a new API object.
---@return kcl_lib.RawAPI
function API:new()
  local o = {
    raw = api,
  }
  setmetatable(o, self)
  self.__index = self
  o.overrides = {}
  return o
end

---Run a KCL program or set of programs and its output.
---@param file string|string[] The file or list of files to run.
---@return kcl_lib.types.RunResponse
function API:run(file)
  if type(file) == "string" then
    file = { file }
  end
  local args = {
    k_filename_list = file,
  }
  local res = self.raw:exec_program(args)
  return types.RunResponse:from_exec_program_result(res)
end

return API:new()

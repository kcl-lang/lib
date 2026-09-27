local json = require("dkjson")

local M = {}

---@class kcl_lib.types.RunResponse
---@field private inner table The inner ExecProgramResult object this is wrapping.
local RunResponse = {}

---Create a RunResponse from an ExecProgramResult.
---@param result table The ExecProgramResult to use as the source.
---@return kcl_lib.types.RunResponse
function RunResponse:from_exec_program_result(result)
  local o = {
    inner = result,
  }
  setmetatable(o, self)
  self.__index = self
  o.overrides = {}
  return o
end

---Return the YAML output from the program execution as a string.
---@return string
function RunResponse:yaml()
  return self.inner.yaml_result
end

---Return the JSON output from the program execution as a string.
---@return string
function RunResponse:json()
  return self.inner.json_result
end

---Return the program execution output as a Lua object.
---@return table
function RunResponse:object()
  if self._object_cache == nil then
    self._object_cache = json.decode(self.inner.json_result) or {}
  end
  return self._object_cache
end

---Return the error message from the program execution, or an empty string.
---@return string
function RunResponse:err_message()
  return self.inner.err_message
end

---Look up a value in the decoded output using a dotted path
---(e.g. `"app.replicas"`). Returns nil when any segment is missing.
---@param path string
---@return any
function RunResponse:get(path)
  local value = self:object()
  for part in string.gmatch(path, "[^%.]+") do
    if type(value) ~= "table" then
      return nil
    end
    value = value[part]
    if value == nil then
      return nil
    end
  end
  return value
end

M.RunResponse = RunResponse

return M

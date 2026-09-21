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
  return json.decode(self.inner.json_result)
end

M.RunResponse = RunResponse

return M

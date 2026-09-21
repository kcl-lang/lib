local io = require("io")

local protoc = require("protoc")

local function main()
  local p = protoc.new()
  p.proto3_optional = true
  local fh = assert(io.open("../spec/spec.proto", "r"))
  local content = fh:read("*a")
  fh:close()
  local dump = p:compile(content, "spec.proto")
  fh = assert(io.open("./kcl_lib/schema.lua", "w"))
  assert(fh:write("return "))
  assert(fh:write(string.format("%q", dump)))
  fh:close()
end

main()

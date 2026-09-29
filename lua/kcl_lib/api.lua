local dkjson = require("dkjson")
local api = require("kcl_lib.raw_api")
local types = require("kcl_lib.types")

---@class kcl_lib.API
---@field private raw kcl_lib.RawAPI The object to access the raw API.
local API = {}

---Create a new API object.
---@return kcl_lib.API
function API:new()
  local o = {
    raw = api,
  }
  setmetatable(o, self)
  self.__index = self
  o.overrides = {}
  return o
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---Normalize a string or list of strings into a list.
---@param value string|string[]|nil
---@return string[]|nil
local function as_list(value)
  if value == nil then
    return nil
  end
  if type(value) == "string" then
    return { value }
  end
  return value
end

---Check whether `path` names a readable file on disk.
---@param path any
---@return boolean
local function file_exists(path)
  if type(path) ~= "string" then
    return false
  end
  local f = io.open(path, "r")
  if f == nil then
    return false
  end
  f:close()
  return true
end

---Parse a "name=value" spec into its two parts. Specs without a "="
---separator or with an empty name are skipped, matching kcl-go's
---``strings.Index(kv, "=") > 0`` guard.
---@param spec string
---@return string|nil name
---@return string|nil value
local function split_kv(spec)
  local idx = string.find(spec, "=", 1, true)
  if idx == nil or idx == 1 then
    return nil, nil
  end
  return spec:sub(1, idx - 1), spec:sub(idx + 1)
end

---Build the protobuf ``Argument`` list from ``-D name=value`` specs.
---@param specs string[]
---@return table[]
local function build_arguments(specs)
  local arguments = {}
  for _, spec in ipairs(specs) do
    local name, value = split_kv(tostring(spec))
    if name ~= nil then
      arguments[#arguments + 1] = { name = name, value = value }
    end
  end
  return arguments
end

---Build the protobuf ``ExternalPkg`` list from ``-E name=path`` specs
---(or ``{pkg_name=..., pkg_path=...}`` tables).
---@param specs (string|table)[]
---@return table[]
local function build_external_pkgs(specs)
  local pkgs = {}
  for _, spec in ipairs(specs) do
    if type(spec) == "table" then
      pkgs[#pkgs + 1] = { pkg_name = spec.pkg_name, pkg_path = spec.pkg_path }
    else
      local name, path = split_kv(tostring(spec))
      if name ~= nil then
        pkgs[#pkgs + 1] = { pkg_name = name, pkg_path = path }
      end
    end
  end
  return pkgs
end

-- ---------------------------------------------------------------------------
-- Minimal YAML emitter (used by the type attribute hook)
-- ---------------------------------------------------------------------------

---Whether a string can be emitted as a plain YAML scalar.
---@param s string
---@return boolean
local function is_plain_string(s)
  if s == "" then
    return false
  end
  if s:match("^%s") or s:match("%s$") then
    return false
  end
  -- Reserved scalars and numbers would re-parse as non-strings.
  local lower = s:lower()
  if lower == "true" or lower == "false" or lower == "null" or lower == "~" then
    return false
  end
  if tonumber(s) ~= nil then
    return false
  end
  return s:match("^[%w_%.%-%/ ]+$") ~= nil
end

---Encode one value as a YAML scalar. JSON double-quoted strings are valid
---YAML double-quoted scalars, so they are reused for anything that is not
---safe to emit plainly.
---@param value any
---@return string
local function yaml_scalar(value)
  local t = type(value)
  if t == "boolean" then
    return value and "true" or "false"
  end
  if t == "number" then
    if value == math.floor(value) and math.abs(value) < 2 ^ 53 then
      return string.format("%.0f", value)
    end
    return tostring(value)
  end
  if t ~= "string" then
    return "null"
  end
  if is_plain_string(value) then
    return value
  end
  return dkjson.encode(value)
end

local emit_yaml

---@param t table
---@return boolean
local function is_empty_table(t)
  return next(t) == nil
end

---Emit `value` as indented YAML lines into `out`.
---@param value any
---@param indent integer
---@param out string[]
emit_yaml = function(value, indent, out)
  local pad = string.rep("  ", indent)
  if type(value) ~= "table" then
    out[#out + 1] = pad .. yaml_scalar(value)
    return
  end
  if is_empty_table(value) then
    out[#out + 1] = pad .. "{}"
    return
  end
  if #value > 0 then
    for _, item in ipairs(value) do
      if type(item) == "table" then
        if is_empty_table(item) then
          out[#out + 1] = pad .. "- {}"
        else
          local sub = {}
          emit_yaml(item, indent + 1, sub)
          local child_pad = string.rep("  ", indent + 1)
          out[#out + 1] = pad .. "- " .. sub[1]:sub(#child_pad + 1)
          for i = 2, #sub do
            out[#out + 1] = sub[i]
          end
        end
      else
        out[#out + 1] = pad .. "- " .. yaml_scalar(item)
      end
    end
    return
  end
  -- Mapping; sort keys like Go's yaml.Marshal does for maps.
  local keys = {}
  for k in pairs(value) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  for _, k in ipairs(keys) do
    local v = value[k]
    local key = tostring(k)
    if not is_plain_string(key) then
      key = dkjson.encode(key)
    end
    if type(v) == "table" and not is_empty_table(v) then
      out[#out + 1] = pad .. key .. ":"
      emit_yaml(v, indent + 1, out)
    elseif type(v) == "table" then
      out[#out + 1] = pad .. key .. ": {}"
    else
      out[#out + 1] = pad .. key .. ": " .. yaml_scalar(v)
    end
  end
end

---Serialize a decoded JSON value to the YAML subset KCL emits.
---@param value any
---@return string
local function to_yaml(value)
  local out = {}
  emit_yaml(value, 0, out)
  return table.concat(out, "\n") .. "\n"
end

-- ---------------------------------------------------------------------------
-- Type attribute hook (mirrors kcl-go's hook.go)
-- ---------------------------------------------------------------------------

---Rewrite full schema type paths in ``_type`` attributes to their last
---segment (``pkg.sub.AppConfig`` -> ``AppConfig``).
---@param node any
local function rewrite_type_paths(node)
  if type(node) ~= "table" then
    return
  end
  for key, value in pairs(node) do
    if key == "_type" and type(value) == "string" then
      node[key] = value:match("[^%.]+$") or value
    elseif type(value) == "table" then
      rewrite_type_paths(value)
    end
  end
end

---Apply the ``_type`` attribute rewrite to an ExecProgramResult in place.
---@param result table
local function apply_type_attribute_hook(result)
  if result.json_result == nil or result.json_result == "" then
    return
  end
  local obj = dkjson.decode(result.json_result)
  if type(obj) ~= "table" then
    return
  end
  rewrite_type_paths(obj)
  result.json_result = dkjson.encode(obj)
  if result.yaml_result ~= nil and result.yaml_result ~= "" then
    result.yaml_result = to_yaml(obj)
  end
end

-- ---------------------------------------------------------------------------
-- Settings merging (via the LoadSettingsFiles RPC)
-- ---------------------------------------------------------------------------

---Merge ``kcl.yaml`` settings files into `args` using the
---LoadSettingsFiles RPC. The runtime resolves relative ``files`` entries
---against `work_dir` and expands ``kcl_options`` values to their wire
---form, so the results are used as-is. Settings values act as defaults:
---explicit ``opts`` fields applied afterwards take precedence.
---@param args table The ExecProgramArgs under construction.
---@param files string[] Settings file paths.
---@param work_dir string|nil
function API:_merge_settings(args, files, work_dir)
  local res = self.raw:load_settings_files({
    work_dir = work_dir or ".",
    files = files,
  })
  local cfg = res.kcl_cli_configs
  if cfg == nil then
    return
  end
  if #cfg.files > 0 then
    args.k_filename_list = cfg.files
  end
  if cfg.output ~= "" then
    args.format = cfg.output
  end
  if #cfg.overrides > 0 then
    args.overrides = cfg.overrides
  end
  if #cfg.path_selector > 0 then
    args.path_selector = cfg.path_selector
  end
  if cfg.strict_range_check then
    args.strict_range_check = true
  end
  if cfg.disable_none then
    args.disable_none = true
  end
  if cfg.sort_keys then
    args.sort_keys = true
  end
  if cfg.show_hidden then
    args.show_hidden = true
  end
  if cfg.include_schema_type_path then
    args.include_schema_type_path = true
  end
  if cfg.fast_eval then
    args.fast_eval = true
  end
  if cfg.verbose > 0 then
    args.verbose = cfg.verbose
  end
  if cfg.debug then
    args.debug = 1
  end
  local arguments = {}
  for _, kv in ipairs(res.kcl_options or {}) do
    arguments[#arguments + 1] = { name = kv.key, value = kv.value }
  end
  if #arguments > 0 then
    args.args = arguments
  end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Run a KCL program and return its output.
---
---`source` may be a KCL source string, a file path, or a list of file
---paths. A string is treated as a file path when it names an existing
---file and as in-memory code otherwise; pass `opts.files` or `opts.code`
---to be explicit.
---
---Supported `opts` (all optional, mirroring kcl-go's functional options):
---* `files` / `code`: file paths / in-memory sources
---* `work_dir`: working directory for the evaluation
---* `args`: list of ``-D name=value`` option specs
---* `overrides`: list of ``-O`` override specs
---* `selectors`: list of ``-S`` path selectors
---* `settings`: ``kcl.yaml`` settings file path(s), parsed and merged via
---  the LoadSettingsFiles RPC; explicit opts take precedence
---* `external_pkgs`: list of ``-E name=path`` external package specs
---* `disable_none`, `sort_keys`, `show_hidden`, `strict_range_check`,
---  `print_override_ast`, `disable_yaml_result`, `compile_only`,
---  `fast_eval`: boolean flags
---* `include_schema_type_path`: emit schema type paths in the result
---* `full_schema_type_path`: keep full type paths (implies
---  `include_schema_type_path` and disables the ``_type`` rewrite)
---* `verbose`, `debug`: integer log verbosity levels
---* `error_format`: diagnostic format ("pretty", "short", "arcanist",
---  "sarif")
---* `format`: output format selector ("json" or "yaml")
---* `strict`: raise on a non-empty ``err_message`` (default; pass
---  ``strict = false`` to get the response back and inspect
---  ``:err_message()`` instead)
---
---@param source string|string[]|nil
---@param opts table|nil
---@return kcl_lib.types.RunResponse
function API:run(source, opts)
  opts = opts or {}
  local args = {}

  if opts.settings ~= nil then
    self:_merge_settings(args, as_list(opts.settings) or {}, opts.work_dir)
  end

  -- Resolve the positional source.
  local source_files, source_code
  if type(source) == "table" then
    source_files = source
  elseif type(source) == "string" then
    if file_exists(source) then
      source_files = { source }
    else
      source_code = { source }
    end
  elseif source ~= nil then
    error("run: source must be a string or a list of strings", 2)
  end

  if opts.work_dir ~= nil then
    args.work_dir = opts.work_dir
  end
  if source_files ~= nil then
    args.k_filename_list = source_files
  end
  local files = as_list(opts.files)
  if files ~= nil and #files > 0 then
    args.k_filename_list = files
  end
  if source_code ~= nil then
    args.k_code_list = source_code
  end
  local code = as_list(opts.code)
  if code ~= nil and #code > 0 then
    args.k_code_list = code
  end
  if opts.args ~= nil and #opts.args > 0 then
    args.args = build_arguments(opts.args)
  end
  local overrides = as_list(opts.overrides)
  if overrides ~= nil and #overrides > 0 then
    args.overrides = overrides
  end
  local selectors = as_list(opts.selectors)
  if selectors ~= nil and #selectors > 0 then
    args.path_selector = selectors
  end
  if opts.external_pkgs ~= nil and #opts.external_pkgs > 0 then
    args.external_pkgs = build_external_pkgs(opts.external_pkgs)
  end

  local bool_flags = {
    "disable_none",
    "sort_keys",
    "show_hidden",
    "strict_range_check",
    "print_override_ast",
    "disable_yaml_result",
    "compile_only",
    "fast_eval",
  }
  for _, flag in ipairs(bool_flags) do
    if opts[flag] ~= nil then
      args[flag] = not not opts[flag]
    end
  end

  -- Mirrors kcl-go's WithFullTypePath: the full schema type path implies
  -- include_schema_type_path and opts out of the `_type` rewrite below.
  local full_type_path = not not opts.full_schema_type_path
  if opts.include_schema_type_path ~= nil then
    args.include_schema_type_path = not not opts.include_schema_type_path
  end
  if full_type_path then
    args.include_schema_type_path = true
  end

  if opts.verbose ~= nil then
    args.verbose = opts.verbose
  end
  if opts.debug ~= nil then
    if type(opts.debug) == "number" then
      args.debug = opts.debug
    else
      args.debug = opts.debug and 1 or 0
    end
  end
  if opts.error_format ~= nil then
    args.error_format = opts.error_format
  end
  if opts.format ~= nil then
    args.format = opts.format
  end

  local res
  if opts.strict == false then
    -- Non-raising mode: hand the response back so callers can inspect
    -- :err_message() themselves.
    local ok, out = pcall(self.raw.exec_program, self.raw, args)
    if ok then
      res = out
    else
      res = {
        json_result = "",
        yaml_result = "",
        log_message = "",
        err_message = tostring(out),
      }
    end
  else
    res = self.raw:exec_program(args)
  end

  if args.include_schema_type_path and not full_type_path then
    apply_type_attribute_hook(res)
  end

  -- must_run semantics: a non-empty err_message is an error.
  if opts.strict ~= false and res.err_message ~= nil and res.err_message ~= "" then
    error(res.err_message, 2)
  end

  return types.RunResponse:from_exec_program_result(res)
end

---Validate data against a schema via the ValidateCode RPC.
---
---`opts` accepts `code` / `file` (the schema) and `data` / `datafile`
---(the document), plus optional `format` ("yaml" by default, or "json"),
---`schema`, `attribute_name` and `external_pkgs`.
---
---@param opts table
---@return table The decoded ValidateCodeResult (`success`, `err_message`).
function API:validate(opts)
  if type(opts) ~= "table" then
    error("validate: opts must be a table", 2)
  end
  local res = self.raw:validate_code({
    code = opts.code or "",
    data = opts.data or "",
    format = opts.format or "yaml",
    file = opts.file,
    datafile = opts.datafile,
    schema = opts.schema,
    attribute_name = opts.attribute_name,
    external_pkgs = opts.external_pkgs ~= nil
        and build_external_pkgs(opts.external_pkgs)
      or nil,
  })
  if res.err_message ~= nil and res.err_message ~= "" then
    error(res.err_message, 2)
  end
  return res
end

---Format an in-memory KCL source string via the FormatCode RPC.
---@param source string
---@return string The formatted code.
function API:format_code(source)
  if type(source) ~= "string" then
    error("format_code: source must be a string", 2)
  end
  return self.raw:format_code({ source = source }).formatted
end

---Format KCL file(s) under `path` via the FormatPath RPC.
---`opts.dry_run` reports the files that would be reformatted without
---rewriting them.
---@param path string
---@param opts table|nil
---@return string[] changed_paths
function API:format_path(path, opts)
  if type(path) ~= "string" then
    error("format_path: path must be a string", 2)
  end
  opts = opts or {}
  return self.raw:format_path({
    path = path,
    dry_run = not not opts.dry_run,
  }).changed_paths
end

---Lint KCL file(s) via the LintPath RPC and return the list of
---diagnostics. An empty list means the files passed every lint rule.
---@param paths string|string[]
---@return string[] results
function API:lint_path(paths)
  local list = as_list(paths)
  if list == nil then
    error("lint_path: paths must be a string or a list of strings", 2)
  end
  return self.raw:lint_path({ paths = list }).results
end

---Run KCL unit tests via the Test RPC.
---`opts` accepts `pkg_list`, `run_regexp`, `fail_fast` and `coverage`;
---each `info[i].error` is empty exactly when that case passed.
---@param opts table|nil
---@return table The decoded TestResult (`info`).
function API:test(opts)
  opts = opts or {}
  return self.raw:test({
    pkg_list = as_list(opts.pkg_list),
    run_regexp = opts.run_regexp,
    fail_fast = opts.fail_fast,
    coverage = opts.coverage,
  })
end

---Rename `symbol_path` across `file_paths` via the Rename RPC.
---`opts` accepts `package_root`, `symbol_path`, `file_paths` and
---`new_name`.
---@param opts table
---@return table The decoded RenameResult (`changed_files`).
function API:rename(opts)
  if type(opts) ~= "table" then
    error("rename: opts must be a table", 2)
  end
  return self.raw:rename({
    package_root = opts.package_root,
    symbol_path = opts.symbol_path,
    file_paths = as_list(opts.file_paths),
    new_name = opts.new_name,
  })
end

---Rename a symbol inside in-memory sources via the RenameCode RPC; no
---files on disk are touched. `opts` accepts `package_root`,
---`symbol_path`, `source_codes` (a map of file path to code) and
---`new_name`.
---@param opts table
---@return table The decoded RenameCodeResult (`changed_codes`).
function API:rename_code(opts)
  if type(opts) ~= "table" then
    error("rename_code: opts must be a table", 2)
  end
  return self.raw:rename_code({
    package_root = opts.package_root,
    symbol_path = opts.symbol_path,
    source_codes = opts.source_codes,
    new_name = opts.new_name,
  })
end

---Parse a KCL file (or in-memory source) into its AST via the ParseFile
---RPC.
---@param path string|nil
---@param opts table|nil `source` for in-memory code, `external_pkgs`.
---@return table The decoded ParseFileResult (`ast_json`, `deps`, `errors`).
function API:parse_file(path, opts)
  if path ~= nil and type(path) ~= "string" then
    error("parse_file: path must be a string", 2)
  end
  opts = opts or {}
  return self.raw:parse_file({
    path = path,
    source = opts.source,
    external_pkgs = opts.external_pkgs ~= nil
        and build_external_pkgs(opts.external_pkgs)
      or nil,
  })
end

return API:new()

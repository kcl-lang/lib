# KCL language core bindings for Julia.
#
# This module is a pure FFI consumer of the prebuilt `libkcl` shared library
# (the same binary the Go binding ships in `../go/lib/<platform>/`). It never
# builds Rust code. Messages are protobuf-encoded; the generated structs are
# vendored under `src/pb/` and can be regenerated with `make proto`.
#
# The native entry point is the universal dispatcher (see
# `c/include/kcl_ffi.h`):
#
#     uintptr_t call_native(const uint8_t *name_ptr, uintptr_t name_len,
#                           const uint8_t *args_ptr, uintptr_t args_len,
#                           uint8_t *result_ptr);
#
# `name` is the fully-qualified RPC name (e.g. "KclService.ExecProgram"),
# `args` the protobuf-encoded request, and the response is copied into the
# caller-owned buffer whose size cannot be queried up front, so every binding
# (C, C++, dotnet, Zig, and this one) passes the same 4 MiB scratch buffer.
# Error replies are the UTF-8 message prefixed with "ERROR:".

module KclLib

import Libdl
import ProtoBuf

# ---------------------------------------------------------------------------
# Vendored protobuf messages generated from ../spec/spec.proto (make proto).
# The generator namespaces them by the proto package, so the module is
# `com.kcl.api`; `KclLib.pb` is the shorthand alias.
# ---------------------------------------------------------------------------

include("pb/com/com.jl")

const pb = com.kcl.api

using .com.kcl.api

# Re-export every generated message type so callers can write
# `ExecProgramArgs(...)` instead of `KclLib.pb.ExecProgramArgs`. `Symbol` is
# the one clash with Base (the LoadPackage semantic-model message) and stays
# reachable as `KclLib.pb.Symbol`.
for name in names(com.kcl.api)
    name === :Symbol && continue
    @eval export $name
end
export pb

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

# Error thrown when the native dispatcher answers with an "ERROR:"-prefixed
# payload (the convention every KCL language binding relies on; the Rust
# source of truth is `crates/api/src/service/capi.rs`).
struct KclError <: Exception
    message::String
end

Base.showerror(io::IO, e::KclError) = print(io, e.message)

const ERROR_PREFIX = codeunits("ERROR:")

function _has_error_prefix(bytes::AbstractVector{UInt8})::Bool
    length(bytes) < length(ERROR_PREFIX) && return false
    @inbounds for i in eachindex(ERROR_PREFIX)
        bytes[i] == ERROR_PREFIX[i] || return false
    end
    return true
end

# ---------------------------------------------------------------------------
# LibKcl: dlopen + ccall binding of the universal dispatcher
# ---------------------------------------------------------------------------

module LibKcl

import Libdl

# Same 4 MiB scratch buffer as the C, C++ and dotnet bindings: the C side
# copies the whole response unconditionally and its length can exceed the
# request size unpredictably (e.g. ExecProgram JSON results).
const CALL_BUFFER_SIZE = 4 * 1024 * 1024

const _libkcl_path = Ref{Union{Nothing,String}}(nothing)

# go/lib layout produced by the KCL release pipeline. `KCL_JL_LIB` overrides
# the search: point it either at the shared library itself or at a directory
# that contains (or is) the platform subdirectory.
const PLATFORM_KEYS = (
    ("darwin", "aarch64") => ("darwin-arm64", "dylib"),
    ("darwin", "x86_64") => ("darwin-amd64", "dylib"),
    ("linux", "x86_64") => ("linux-amd64", "so"),
    ("linux", "aarch64") => ("linux-arm64", "so"),
    ("windows", "x86_64") => ("windows-amd64", "dll"),
    ("windows", "aarch64") => ("windows-arm64", "dll"),
)

function _platform_key()
    os = Sys.isapple() ? "darwin" : Sys.islinux() ? "linux" : Sys.iswindows() ? "windows" : nothing
    os === nothing && error("KclLib: unsupported operating system $(Sys.MACHINE)")
    arch = String(Sys.ARCH)
    for ((kos, karch), v) in PLATFORM_KEYS
        kos == os && karch == arch && return v
    end
    error("KclLib: unsupported platform $(Sys.MACHINE); set KCL_JL_LIB to the libkcl binary")
end

function _candidates()
    dir, ext = _platform_key()
    libname = "libkcl.$ext"
    candidates = String[]
    if haskey(ENV, "KCL_JL_LIB")
        env = ENV["KCL_JL_LIB"]
        if isfile(env)
            push!(candidates, env)
        elseif isdir(env)
            push!(candidates, joinpath(env, dir, libname))
            push!(candidates, joinpath(env, libname))
        else
            error("KclLib: KCL_JL_LIB is set but does not exist: $env")
        end
    end
    # Repository layout: julia/src/KclLib.jl -> <repo>/go/lib/<platform>/.
    push!(candidates, joinpath(@__DIR__, "..", "..", "go", "lib", dir, libname))
    return candidates
end

function _resolve_path()::String
    for candidate in _candidates()
        isfile(candidate) && return abspath(candidate)
    end
    throw(ErrorException(
        "KclLib: could not locate libkcl. Tried:\n  " * join(_candidates(), "\n  ") *
        "\nSet KCL_JL_LIB to the libkcl shared library (see go/lib/<platform>)."
    ))
end

"Path of the libkcl shared library this binding will dlopen."
function lib_path()::String
    _libkcl_path[] === nothing && (_libkcl_path[] = _resolve_path())
    return _libkcl_path[]
end

# dlopen the library, failing fast with a descriptive error, and cache the
# resolved `call_native` entry point (dlsym once per process).
const _call_native_sym = Ref{Ptr{Cvoid}}(C_NULL)

function _symbol()::Ptr{Cvoid}
    if _call_native_sym[] == C_NULL
        path = lib_path()
        handle = try
            Libdl.dlopen(path)
        catch err
            ErrorException("KclLib: failed to dlopen $path: $err") |> throw
        end
        _call_native_sym[] = Libdl.dlsym(handle, :call_native)
    end
    return _call_native_sym[]
end

include("plugin.jl")

function call_native(name::Vector{UInt8}, args::Vector{UInt8})::Vector{UInt8}
    # A bound plugin agent can only travel with a service handle, so once one
    # is registered every call routes through it. `plugin_call` returns
    # `nothing` while nothing is bound, which keeps the stateless path intact
    # for programs that do not use plugins.
    routed = plugin_call(name, args)
    routed === nothing || return routed

    buf = Vector{UInt8}(undef, CALL_BUFFER_SIZE)
    written = ccall(_symbol(), UInt,
                    (Ptr{UInt8}, UInt, Ptr{UInt8}, UInt, Ptr{UInt8}),
                    name, length(name), args, length(args), buf)
    written > CALL_BUFFER_SIZE &&
        error("KclLib: native response ($(written) bytes) exceeds the $(CALL_BUFFER_SIZE) byte scratch buffer")
    return resize!(buf, written)
end

end # module LibKcl

# The plugin registry lives inside `LibKcl` next to the FFI declarations it
# depends on; these are the names callers use.
const register_plugin = LibKcl.register_plugin
const plugin_registered = LibKcl.plugin_registered
const disable_plugins = LibKcl.disable_plugins
const has_plugins = LibKcl.has_plugins
const PluginMethod = LibKcl.PluginMethod

# ---------------------------------------------------------------------------
# Universal dispatcher escape hatch
# ---------------------------------------------------------------------------

"""
    call(name::AbstractString, args_bytes::AbstractVector{UInt8}) -> Vector{UInt8}

Call any KCL service RPC by name with a protobuf-encoded request and return
the raw protobuf response bytes. `name` is the fully-qualified RPC name, e.g.
`"KclService.ExecProgram"` or `"BuiltinService.ListMethod"`.

This mirrors the universal dispatcher exposed by every other KCL language
binding (`call` in Python/Go/C/C++, `callNative` in Swift/dotnet) and lets
Julia callers reach the full spec surface even when no typed wrapper exists.

Throws a [`KclError`](@ref) when the native side answers with the
`"ERROR:"`-prefixed error convention.
"""
function call(name::AbstractString, args::AbstractVector{UInt8}=UInt8[])::Vector{UInt8}
    isempty(name) && throw(ArgumentError("KclLib.call: RPC name must not be empty"))
    result = LibKcl.call_native(Vector{UInt8}(codeunits(name)), Vector{UInt8}(args))
    _has_error_prefix(result) &&
        throw(KclError(String(@view result[(length(ERROR_PREFIX) + 1):end])))
    return result
end

# ---------------------------------------------------------------------------
# Typed wrappers over the 20 KclService RPCs + BuiltinService.ListMethod
# ---------------------------------------------------------------------------

_encode(msg) = let io = IOBuffer()
    ProtoBuf.encode(ProtoBuf.ProtoEncoder(io), msg)
    take!(io)
end

_decode(::Type{T}, bytes::AbstractVector{UInt8}) where {T} =
    ProtoBuf.decode(ProtoBuf.ProtoDecoder(IOBuffer(bytes)), T)

function _rpc(name::AbstractString, request, ::Type{T}) where {T}
    response_bytes = call(name, _encode(request))
    return _decode(T, response_bytes)
end

"""
    ping(args::PingArgs) -> PingResult

Ping the KCL service; the result echoes back `args.value`. Equivalent to
`call("KclService.Ping", bytes)`.
"""
ping(args::PingArgs) = _rpc("KclService.Ping", args, PingResult)

"""
    get_version() -> GetVersionResult

Return the KCL version, checksum, git SHA and detailed version information.
Equivalent to `call("KclService.GetVersion", bytes)`.
"""
get_version() = _rpc("KclService.GetVersion", GetVersionArgs(), GetVersionResult)

"""
    parse_program(args::ParseProgramArgs) -> ParseProgramResult

Parse KCL program with entry files and return the AST JSON string, the
compile order of files and parse errors. Equivalent to
`call("KclService.ParseProgram", bytes)`.
"""
parse_program(args::ParseProgramArgs) = _rpc("KclService.ParseProgram", args, ParseProgramResult)

"""
    parse_file(args::ParseFileArgs) -> ParseFileResult

Parse a single KCL file to a Module AST JSON string with import dependencies
and parse errors. Equivalent to `call("KclService.ParseFile", bytes)`.
"""
parse_file(args::ParseFileArgs) = _rpc("KclService.ParseFile", args, ParseFileResult)

"""
    load_package(args::LoadPackageArgs) -> LoadPackageResult

Parse the KCL program and return its semantic model: symbols, scopes,
definitions, node mappings, etc. Equivalent to
`call("KclService.LoadPackage", bytes)`.
"""
load_package(args::LoadPackageArgs) = _rpc("KclService.LoadPackage", args, LoadPackageResult)

"""
    list_options(args::ParseProgramArgs) -> ListOptionsResult

Parse the KCL program and get all `option(...)` help information. Equivalent
to `call("KclService.ListOptions", bytes)`.
"""
list_options(args::ParseProgramArgs) = _rpc("KclService.ListOptions", args, ListOptionsResult)

"""
    list_variables(args::ListVariablesArgs) -> ListVariablesResult

Parse the KCL program and get all variables by specs, keyed by file.
Equivalent to `call("KclService.ListVariables", bytes)`.
"""
list_variables(args::ListVariablesArgs) = _rpc("KclService.ListVariables", args, ListVariablesResult)

"""
    exec_program(args::ExecProgramArgs) -> ExecProgramResult

Execute KCL files or inline code and return the JSON/YAML results.
**Note that it is not thread safe**, mirroring the spec. Equivalent to
`call("KclService.ExecProgram", bytes)`.
"""
exec_program(args::ExecProgramArgs) = _rpc("KclService.ExecProgram", args, ExecProgramResult)

"""
    override_file(args::OverrideFileArgs) -> OverrideFileResult

Override a KCL file with the given specs; the file is rewritten in place.
Equivalent to `call("KclService.OverrideFile", bytes)`.
"""
override_file(args::OverrideFileArgs) = _rpc("KclService.OverrideFile", args, OverrideFileResult)

"""
    get_schema_type_mapping(args::GetSchemaTypeMappingArgs) -> GetSchemaTypeMappingResult

Get the schema type mapping of the program selected by `exec_args`. Equivalent
to `call("KclService.GetSchemaTypeMapping", bytes)`.
"""
get_schema_type_mapping(args::GetSchemaTypeMappingArgs) =
    _rpc("KclService.GetSchemaTypeMapping", args, GetSchemaTypeMappingResult)

"""
    get_schema_type_mapping_under_path(args::GetSchemaTypeMappingArgs) -> GetSchemaTypeMappingUnderPathResult

Get the schema type mapping under the input paths, including all external
dependency packages, keyed by package name (e.g. `"__main__"`). Equivalent to
`call("KclService.GetSchemaTypeMappingUnderPath", bytes)`.
"""
get_schema_type_mapping_under_path(args::GetSchemaTypeMappingArgs) =
    _rpc("KclService.GetSchemaTypeMappingUnderPath", args, GetSchemaTypeMappingUnderPathResult)

"""
    format_code(args::FormatCodeArgs) -> FormatCodeResult

Format KCL source code. Equivalent to `call("KclService.FormatCode", bytes)`.
"""
format_code(args::FormatCodeArgs) = _rpc("KclService.FormatCode", args, FormatCodeResult)

"""
    format_path(args::FormatPathArgs) -> FormatPathResult

Format the KCL file or directory at `path` and return the changed file paths.
Equivalent to `call("KclService.FormatPath", bytes)`.
"""
format_path(args::FormatPathArgs) = _rpc("KclService.FormatPath", args, FormatPathResult)

"""
    lint_path(args::LintPathArgs) -> LintPathResult

Lint files and return error messages including errors and warnings. Equivalent
to `call("KclService.LintPath", bytes)`.
"""
lint_path(args::LintPathArgs) = _rpc("KclService.LintPath", args, LintPathResult)

"""
    validate_code(args::ValidateCodeArgs) -> ValidateCodeResult

Validate data against a schema given as code strings. **Note that it is not
thread safe**, mirroring the spec. Equivalent to
`call("KclService.ValidateCode", bytes)`.
"""
validate_code(args::ValidateCodeArgs) = _rpc("KclService.ValidateCode", args, ValidateCodeResult)

"""
    load_settings_files(args::LoadSettingsFilesArgs) -> LoadSettingsFilesResult

Build the setting file config from the work dir and setting files. Equivalent
to `call("KclService.LoadSettingsFiles", bytes)`.
"""
load_settings_files(args::LoadSettingsFilesArgs) =
    _rpc("KclService.LoadSettingsFiles", args, LoadSettingsFilesResult)

"""
    rename(args::RenameArgs) -> RenameResult

Rename all occurrences of the target symbol in the files; files that contain
the symbol are rewritten on disk. Equivalent to `call("KclService.Rename", bytes)`.
"""
rename(args::RenameArgs) = _rpc("KclService.Rename", args, RenameResult)

"""
    rename_code(args::RenameCodeArgs) -> RenameCodeResult

Rename all occurrences of the target symbol in the given source codes and
return the modified code without touching the file system. Equivalent to
`call("KclService.RenameCode", bytes)`.
"""
rename_code(args::RenameCodeArgs) = _rpc("KclService.RenameCode", args, RenameCodeResult)

"""
    test(args::TestArgs) -> TestResult

Run the KCL unit tests of the given packages. Equivalent to
`call("KclService.Test", bytes)`.
"""
test(args::TestArgs) = _rpc("KclService.Test", args, TestResult)

"""
    format_test_report(args::FormatTestReportArgs) -> FormatTestReportResult

Format a test result into a human-readable report. Equivalent to
`call("KclService.FormatTestReport", bytes)`.

The report is byte-identical to the kcl-go `PrettyReporter` format and is
deterministic for a given result. Every line, including the last one, ends
with `\\n`:

- One line per case in result order: `{name}: {STATUS} ({duration_ms}ms)` where
  STATUS is `PASS` or `FAIL` and the duration is the case duration in
  microseconds truncated to whole milliseconds (integer division, so 1500µs
  renders as `1ms`). A case with a non-empty log message gets the log on the
  next line; otherwise a failed case appends its error string as-is.
- A separator line of exactly 80 `-` characters.
- Only for non-zero counts, in this order: `PASS: {p}/{total}`,
  `FAIL: {f}/{total}`, `SKIPPED: {s}/{total}`.
- An empty result (no cases, no coverage) renders exactly `no test files`.
"""
format_test_report(args::FormatTestReportArgs) =
    _rpc("KclService.FormatTestReport", args, FormatTestReportResult)

"""
    update_dependencies(args::UpdateDependenciesArgs) -> UpdateDependenciesResult

Download and update the dependencies declared in the `kcl.mod` file at
`manifest_path`. Equivalent to `call("KclService.UpdateDependencies", bytes)`.
"""
update_dependencies(args::UpdateDependenciesArgs) =
    _rpc("KclService.UpdateDependencies", args, UpdateDependenciesResult)

"""
    list_method() -> ListMethodResult

List the methods exposed by the native KCL dispatcher. Equivalent to
`call("BuiltinService.ListMethod", bytes)`.

Note: prebuilt libkcl v0.13.0 predates the `BuiltinService` registration, so
its dispatcher answers with an empty payload; the wrapper therefore tolerates
an empty `method_name_list`.
"""
list_method() = _rpc("BuiltinService.ListMethod", ListMethodArgs(), ListMethodResult)

# ---------------------------------------------------------------------------
# High-level facade
#
# Mirrors the Python facade (python/kcl_lib/kcl.py) and kcl-go's `kcl`
# package: `run`/`run_files` assemble [`ExecProgramArgs`](@ref) from keyword
# arguments, call [`exec_program`](@ref), raise [`KclError`](@ref) when the
# runtime reports an error and return a [`KCLResult`](@ref). Note that unlike
# kcl-go's `kcl.Run` (which returns an error value), Julia's `run` raises on
# failure; `must_run` exists for API parity and additionally accepts the
# file list positionally.
# ---------------------------------------------------------------------------

"""
    KCLResult

Ergonomic wrapper around an [`ExecProgramResult`](@ref) in the spirit of
kcl-go's `kcl.KCLResult`: keeps the raw JSON/YAML output and offers
dotted-path `get` access over the parsed JSON document.

Normally produced by [`run`](@ref), [`run_files`](@ref) or [`must_run`](@ref);
`KCLResult(raw)` wraps any raw result returned by [`exec_program`](@ref).
"""
struct KCLResult
    raw::ExecProgramResult
end

"Raw YAML document emitted by the runtime (`raw.yaml_result`)."
yaml_string(r::KCLResult) = r.raw.yaml_result

"Raw JSON document emitted by the runtime (`raw.json_result`)."
json_string(r::KCLResult) = r.raw.json_result

"""
    to_dict(r::KCLResult) -> Dict{String,Any}

Parse `json_result` into a plain dictionary; the runtime always emits a JSON
mirror alongside the YAML. Returns an empty dict when the result carries no
JSON object.
"""
function to_dict(r::KCLResult)::Dict{String,Any}
    text = strip(r.raw.json_result)
    isempty(text) && return Dict{String,Any}()
    value = _json_parse(text)
    return value isa AbstractDict ? Dict{String,Any}(value) : Dict{String,Any}()
end

"""
    get(r::KCLResult, path::AbstractString, default=nothing)

Look up `path` (`.`-separated keys, e.g. `"app.replicas"`) in the parsed JSON
document. Returns `default` as soon as any segment is missing.

```julia
result = KclLib.run(code="a = {b = {c = 42}}")
get(result, "a.b.c")   # 42
get(result, "a.x", 0)  # 0
```
"""
function Base.get(r::KCLResult, path::AbstractString, default=nothing)
    value = to_dict(r)
    for part in split(path, '.')
        if value isa AbstractDict && haskey(value, part)
            value = value[part]
        else
            return default
        end
    end
    return value
end

# Minimal JSON reader covering exactly what the runtime emits in
# `json_result`: objects, arrays, strings with escapes (including `\\uXXXX`
# surrogate pairs), numbers, booleans and null. The facade deliberately
# keeps the dependency footprint at zero instead of pulling in JSON.jl.

const _JSON_ESCAPES = Dict{UInt8,UInt8}(
    UInt8('"') => 0x22,
    UInt8('\\') => 0x5c,
    UInt8('/') => 0x2f,
    UInt8('b') => 0x08,
    UInt8('f') => 0x0c,
    UInt8('n') => 0x0a,
    UInt8('r') => 0x0d,
    UInt8('t') => 0x09,
)

mutable struct _JsonCursor
    data::Vector{UInt8}
    pos::Int
end

_json_at_end(p::_JsonCursor) = p.pos > length(p.data)

_json_fail(p::_JsonCursor, msg::AbstractString) =
    throw(ArgumentError("KclLib: invalid JSON document at byte $(p.pos): $msg"))

_json_parse(text::AbstractString) = _json_value!(_JsonCursor(Vector{UInt8}(String(text)), 1))

function _json_skip_ws!(p)
    while !_json_at_end(p)
        b = p.data[p.pos]
        (b == 0x20 || b == 0x09 || b == 0x0a || b == 0x0d) || return
        p.pos += 1
    end
end

function _json_value!(p)
    _json_skip_ws!(p)
    _json_at_end(p) && _json_fail(p, "unexpected end of input")
    b = p.data[p.pos]
    if b == UInt8('{')
        return _json_object!(p)
    elseif b == UInt8('[')
        return _json_array!(p)
    elseif b == UInt8('"')
        return _json_string!(p)
    elseif b == UInt8('t')
        _json_literal!(p, "true")
        return true
    elseif b == UInt8('f')
        _json_literal!(p, "false")
        return false
    elseif b == UInt8('n')
        _json_literal!(p, "null")
        return nothing
    end
    return _json_number!(p)
end

function _json_literal!(p, word::AbstractString)
    for c in codeunits(word)
        (_json_at_end(p) || p.data[p.pos] != c) && _json_fail(p, "expected '$word'")
        p.pos += 1
    end
end

function _json_object!(p)
    p.pos += 1  # consume '{'
    obj = Dict{String,Any}()
    _json_skip_ws!(p)
    if !_json_at_end(p) && p.data[p.pos] == UInt8('}')
        p.pos += 1
        return obj
    end
    while true
        _json_skip_ws!(p)
        (_json_at_end(p) || p.data[p.pos] != UInt8('"')) && _json_fail(p, "expected an object key")
        key = _json_string!(p)
        _json_skip_ws!(p)
        (_json_at_end(p) || p.data[p.pos] != UInt8(':')) && _json_fail(p, "expected ':' after an object key")
        p.pos += 1
        obj[key] = _json_value!(p)
        _json_skip_ws!(p)
        _json_at_end(p) && _json_fail(p, "unterminated object")
        b = p.data[p.pos]
        p.pos += 1
        if b == UInt8(',')
            continue
        elseif b == UInt8('}')
            return obj
        else
            _json_fail(p, "expected ',' or '}' in an object")
        end
    end
end

function _json_array!(p)
    p.pos += 1  # consume '['
    arr = Any[]
    _json_skip_ws!(p)
    if !_json_at_end(p) && p.data[p.pos] == UInt8(']')
        p.pos += 1
        return arr
    end
    while true
        push!(arr, _json_value!(p))
        _json_skip_ws!(p)
        _json_at_end(p) && _json_fail(p, "unterminated array")
        b = p.data[p.pos]
        p.pos += 1
        if b == UInt8(',')
            continue
        elseif b == UInt8(']')
            return arr
        else
            _json_fail(p, "expected ',' or ']' in an array")
        end
    end
end

function _json_string!(p)
    p.pos += 1  # consume opening quote
    buf = UInt8[]
    while !_json_at_end(p)
        b = p.data[p.pos]
        if b == UInt8('"')
            p.pos += 1
            return String(buf)
        elseif b == UInt8('\\')
            p.pos += 1
            _json_at_end(p) && _json_fail(p, "unterminated escape sequence")
            esc = p.data[p.pos]
            p.pos += 1
            if esc == UInt8('u')
                append!(buf, Vector{UInt8}(string(Char(_json_unicode!(p)))))
            else
                decoded = get(_JSON_ESCAPES, esc, nothing)
                decoded === nothing && _json_fail(p, "invalid escape sequence")
                push!(buf, decoded)
            end
        else
            push!(buf, b)
            p.pos += 1
        end
    end
    _json_fail(p, "unterminated string")
end

function _json_hex4(p)::UInt16
    value = 0x0000
    for _ in 1:4
        _json_at_end(p) && _json_fail(p, "truncated unicode escape")
        d = tryparse(UInt8, string(Char(p.data[p.pos])); base=16)
        d === nothing && _json_fail(p, "invalid hex digit in unicode escape")
        value = (value << 4) | d
        p.pos += 1
    end
    return value
end

function _json_unicode!(p)::UInt32
    cp = UInt32(_json_hex4(p))
    if 0xd800 <= cp <= 0xdbff
        # High surrogate: a "\\uXXXX" low surrogate must immediately follow.
        if p.pos + 1 <= length(p.data) && p.data[p.pos] == UInt8('\\') && p.data[p.pos + 1] == UInt8('u')
            p.pos += 2
            lo = UInt32(_json_hex4(p))
            (0xdc00 <= lo <= 0xdfff) || _json_fail(p, "invalid low surrogate")
            return 0x10000 + ((cp - 0xd800) << 10) + (lo - 0xdc00)
        end
        _json_fail(p, "lone high surrogate")
    end
    return cp
end

function _json_number!(p)
    start = p.pos
    while !_json_at_end(p)
        b = p.data[p.pos]
        if (UInt8('0') <= b <= UInt8('9')) || b == UInt8('-') || b == UInt8('+') ||
           b == UInt8('.') || b == UInt8('e') || b == UInt8('E')
            p.pos += 1
        else
            break
        end
    end
    p.pos == start && _json_fail(p, "expected a JSON value")
    s = String(p.data[start:p.pos - 1])
    int_val = tryparse(Int64, s)
    int_val !== nothing && return int_val
    float_val = tryparse(Float64, s)
    (float_val === nothing) && _json_fail(p, "malformed number '$s'")
    return float_val
end

# `run` accepts `Argument`s or plain "key=value" strings (the kcl `-D`
# spelling) for its `args` keyword.
_to_arguments(list::AbstractVector{Argument}) = Argument[item for item in list]
_to_arguments(list::Tuple) = _to_arguments(collect(list))
_to_arguments(s::AbstractString) = _to_arguments([s])
function _to_arguments(list::AbstractVector{<:AbstractString})
    out = Argument[]
    for kv in list
        eq = findfirst('=', kv)
        (eq === nothing || eq == 1) && continue  # the Go guard: Index(kv, "=") > 0
        push!(out, Argument(String(kv[1:eq - 1]), String(kv[eq + 1:end])))
    end
    return out
end
_to_arguments(list) = Argument[item for item in list]

_file_list(files::AbstractString) = [String(files)]
_file_list(files::AbstractVector{<:AbstractString}) = String.(files)

"""
    run(; code=nothing, files=nothing, kwargs...) -> KCLResult

Evaluate KCL from in-memory `code` and/or `files` and return a
[`KCLResult`](@ref). Convenience keywords `code` and `files` append to the
lower-level `k_code_list` / `k_filename_list`; the remaining keywords mirror
the `ExecProgramArgs` fields (`args`, `overrides`, `path_selector`,
`sort_keys`, `disable_none`, `show_hidden`, `include_schema_type_path`,
`work_dir`, `format`, `error_format`, `strict_range_check`, `compile_only`,
`verbose`, `debug`, `external_pkgs`, ...).

Raises [`KclError`](@ref) when the runtime reports an error — unlike
kcl-go's `kcl.Run`, no error value is returned.

`run` is deliberately **not exported**: `Base.run` already owns the name and
`using KclLib` would leave every reference ambiguous. Call it qualified as
`KclLib.run(...)` or bring it in explicitly with `import KclLib: run`.

```julia
KclLib.run(code="a = 1")
KclLib.run(files=["main.k", "base.k"], overrides=["replicas=3"])
KclLib.run(code="env = option(\\"env\\")", args=["env=prod"])
```
"""
function run(; code::Union{AbstractString,Nothing}=nothing,
               files::Union{AbstractString,AbstractVector{<:AbstractString},Nothing}=nothing,
               k_filename_list::AbstractVector{<:AbstractString}=String[],
               k_code_list::AbstractVector{<:AbstractString}=String[],
               args=Argument[],
               overrides::AbstractVector{<:AbstractString}=String[],
               path_selector::AbstractVector{<:AbstractString}=String[],
               work_dir::AbstractString="",
               format::AbstractString="",
               error_format::AbstractString="",
               sort_keys::Bool=false,
               disable_none::Bool=false,
               show_hidden::Bool=false,
               include_schema_type_path::Bool=false,
               disable_yaml_result::Bool=false,
               strict_range_check::Bool=false,
               compile_only::Bool=false,
               print_override_ast::Bool=false,
               verbose::Integer=0,
               debug::Integer=0,
               external_pkgs::AbstractVector{ExternalPkg}=ExternalPkg[])::KCLResult
    filenames = String[]
    files !== nothing && append!(filenames, _file_list(files))
    append!(filenames, String.(k_filename_list))
    codes = String[]
    code !== nothing && push!(codes, String(code))
    append!(codes, String.(k_code_list))
    isempty(filenames) && isempty(codes) &&
        throw(ArgumentError("KclLib.run: at least one of `code` or `files` must be provided"))
    result = exec_program(ExecProgramArgs(
        work_dir=String(work_dir),
        k_filename_list=filenames,
        k_code_list=codes,
        args=_to_arguments(args),
        overrides=String.(overrides),
        path_selector=String.(path_selector),
        sort_keys=sort_keys,
        disable_none=disable_none,
        show_hidden=show_hidden,
        include_schema_type_path=include_schema_type_path,
        disable_yaml_result=disable_yaml_result,
        strict_range_check=strict_range_check,
        compile_only=compile_only,
        print_override_ast=print_override_ast,
        verbose=Int32(verbose),
        debug=Int32(debug),
        external_pkgs=ExternalPkg[external_pkgs...],
        error_format=String(error_format),
        format=String(format),
    ))
    isempty(result.err_message) || throw(KclError(result.err_message))
    return KCLResult(result)
end

"""
    run_files(files; kwargs...) -> KCLResult

Multi-file variant of [`run`](@ref): `run_files(files; kwargs...)` is
`run(; files=files, kwargs...)`. Not exported, like the rest of the
`run` family: call it as `KclLib.run_files(...)` or
`import KclLib: run_files`.
"""
run_files(files::Union{AbstractString,AbstractVector{<:AbstractString}}; kwargs...) =
    run(; files=files, kwargs...)

"""
    must_run(; kwargs...) -> KCLResult
    must_run(files; kwargs...) -> KCLResult

Like [`run`](@ref), additionally accepting the file list positionally
(mirroring kcl-go's `kcl.MustRun(path)`). Since Julia's `run` already raises
[`KclError`](@ref) on failure instead of returning an error value, this is
purely API parity. Not exported: call it as `KclLib.must_run(...)` or
`import KclLib: must_run`.
"""
must_run(; kwargs...) = run(; kwargs...)
must_run(files::Union{AbstractString,AbstractVector{<:AbstractString}}; kwargs...) =
    run_files(files; kwargs...)

"""
    validate_code(data::AbstractString, code::AbstractString; format::AbstractString="json") -> Bool

Convenience wrapper around `validate_code(::ValidateCodeArgs)`: validate
`data` against the schema given as a `code` string, entirely in memory.
Returns `true` when the runtime reports success; when it returns `false`,
the detailed message is available from the raw wrapper.
"""
function validate_code(data::AbstractString, code::AbstractString;
                       format::AbstractString="json")::Bool
    result = validate_code(ValidateCodeArgs(
        data=String(data), code=String(code), format=String(format)))
    return result.success
end

# ---------------------------------------------------------------------------
# Typed AST. `ast.jl` sits on top of `parse_file` / `parse_program` and the
# internal JSON reader above, so it is included last.
# ---------------------------------------------------------------------------

include("ast.jl")

export call, KclError,
    ping, get_version, parse_program, parse_file, load_package, list_options,
    list_variables, exec_program, override_file, get_schema_type_mapping,
    get_schema_type_mapping_under_path, format_code, format_path, lint_path,
    validate_code, load_settings_files, rename, rename_code, test,
    format_test_report, update_dependencies, list_method,
    register_plugin, plugin_registered, disable_plugins, has_plugins,
    PluginMethod,
    KCLResult, yaml_string, json_string, to_dict

# Typed AST (src/ast.jl). Every struct and abstract type is exported - callers
# dispatch with `isa` / `node_type`, so the variant names are the API. The
# `*_from_wire` decoders stay unexported: callers go through `parse_module` /
# `parse_program_ast` rather than poking at the wire format directly.
#
# The names follow the Java binding's vocabulary (`Compare`, `ListComp`,
# `SchemaConfig`, `Decorator`, ...), which is the one the cross-binding
# checkers and docs key on. `KclModule` is the one exception that is exported
# as well, kept as an alias so the pre-rename name still resolves.
export parse_module, parse_program_ast, node_type,
    Pos, Node, Comment,
    AstType, AnyType, BasicType, NamedType, ListType, DictType,
    UnionType, LiteralType, FunctionType, UnknownType,
    Identifier, MemberOrIndex, Member, Index, Target, Keyword, Arguments,
    ConfigEntry, Decorator, SchemaConfig, SchemaIndexSignature,
    KclExpr, TargetExpr, IdentifierExpr, UnaryExpr, BinaryExpr, IfExpr,
    SelectorExpr, CallExpr, ParenExpr, QuantExpr, ListExpr, ListIfItemExpr,
    CompClause, ListComp, StarredExpr, DictComp, ConfigIfEntryExpr,
    SchemaExpr, ConfigExpr, CheckExpr, LambdaExpr, Subscript, KeywordExpr,
    ArgumentsExpr, Compare, NumberLit, StringLit,
    NameConstantLit, JoinedString, FormattedValue, MissingExpr,
    UnknownExpr,
    KclStmt, TypeAliasStmt, ExprStmt, UnificationStmt, AssignStmt, AugAssignStmt,
    AssertStmt, IfStmt, ImportStmt, SchemaAttr, SchemaStmt, RuleStmt, UnknownStmt,
    Module, KclModule

end # module KclLib

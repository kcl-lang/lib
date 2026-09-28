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

function call_native(name::Vector{UInt8}, args::Vector{UInt8})::Vector{UInt8}
    buf = Vector{UInt8}(undef, CALL_BUFFER_SIZE)
    written = ccall(_symbol(), UInt,
                    (Ptr{UInt8}, UInt, Ptr{UInt8}, UInt, Ptr{UInt8}),
                    name, length(name), args, length(args), buf)
    written > CALL_BUFFER_SIZE &&
        error("KclLib: native response ($(written) bytes) exceeds the $(CALL_BUFFER_SIZE) byte scratch buffer")
    return resize!(buf, written)
end

end # module LibKcl

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

export call, KclError,
    ping, get_version, parse_program, parse_file, load_package, list_options,
    list_variables, exec_program, override_file, get_schema_type_mapping,
    get_schema_type_mapping_under_path, format_code, format_path, lint_path,
    validate_code, load_settings_files, rename, rename_code, test,
    update_dependencies, list_method

end # module KclLib

# KCL plugin support, included from inside the `LibKcl` submodule of
# KclLib.jl.
#
# KCL source reaches a plugin by importing the plugin module and calling the
# method unqualified:
#
# ```kcl
# import kcl_plugin.strings
# result = strings.join("KCL", "KCL", 123)
# ```
#
# The runtime resolves that to a `kcl_plugin.strings.join` call into the host
# (docs/abi.md §7), so `register_plugin` only ever sees the two halves.
#
# ```julia
# using KclLib
#
# KclLib.register_plugin("strings", "join", (args, kwargs) -> "\"KCL.KCL.123\"")
# result = KclLib.run(code = "import kcl_plugin.strings\nresult = strings.join(\"KCL\", \"KCL\", 123)\n")
# ```
#
# `call_native` is the stateless universal dispatcher and cannot carry a plugin
# agent, so the first `register_plugin` binds a service handle and every
# subsequent call routes through it. `plugin_call` returns `nothing` while no
# plugin is bound, which is the cue to fall back to `call_native`.

const _PLUGIN_PREFIX = "kcl_plugin."

"""
    KclLib.PluginMethod

A plugin method: called with the JSON-encoded positional arguments and the
JSON-encoded keyword arguments (either may be an empty string), and expected
to return a JSON-encoded result. Throwing is allowed — the exception is
reported to the runtime as a `__kcl_PanicInfo__` object rather than unwinding
into the native frames underneath.
"""
const PluginMethod = Function

# The KCL runtime is explicitly single-threaded, matching every other binding,
# and it releases its own dispatch lock before calling a handler, so a method
# may trigger nested KCL evaluation.
const _PLUGIN_REGISTRY = Dict{String,PluginMethod}()

# Reused for every reply handed back to the runtime. The runtime copies the
# bytes into a KCL value as soon as the agent returns and never frees the
# pointer, so one buffer is enough — and a plugin method must not hold on to
# the previous result. A nested evaluation (a method that itself calls
# `KclLib.run`) re-enters this agent, but it does so *before* the outer
# invocation writes its own reply, so the outer pointer is never stale.
const _PLUGIN_REPLY = UInt8[]

# `Ptr{Cvoid}` handle from `kcl_service_new`; `C_NULL` while nothing is bound.
const _PLUGIN_SERVICE = Ref{Ptr{Cvoid}}(C_NULL)

# `ccall` needs its callee to be a constant expression, so the service entry
# points are resolved with `dlsym` once each rather than through
# `ccall((:name, lib_path()), ...)` the way a literal library path would allow.
const _SERVICE_SYMS = Dict{Symbol,Ptr{Cvoid}}()

function _service_symbol(name::Symbol)::Ptr{Cvoid}
    ptr = get(_SERVICE_SYMS, name, C_NULL)
    if ptr == C_NULL
        ptr = Libdl.dlsym(Libdl.dlopen(lib_path()), name)
        _SERVICE_SYMS[name] = ptr
    end
    return ptr
end

# Build `{"__kcl_PanicInfo__":"<message>"}`, the same shape Go's
# `plugin.JSONError` and Python's `_call_py_method` produce.
function _panic_info(message::AbstractString)
    io = IOBuffer()
    print(io, "{\"__kcl_PanicInfo__\":\"")
    for ch in message
        if ch == '"'
            print(io, "\\\"")
        elseif ch == '\\'
            print(io, "\\\\")
        elseif ch == '\n'
            print(io, "\\n")
        elseif ch == '\r'
            print(io, "\\r")
        elseif ch == '\t'
            print(io, "\\t")
        elseif ch < ' '
            # `\u` needs four hex digits; the control characters a Julia
            # exception message can realistically carry are all below 0x20.
            print(io, "\\u", lpad(string(UInt32(ch); base = 16), 4, '0'))
        else
            print(io, ch)
        end
    end
    print(io, "\"}")
    return String(take!(io))
end

# Write `text` into the shared reply buffer and hand back a C string pointing
# at it. The trailing NUL is what makes the pointer usable as a C string, and
# taking the pointer after `resize!` keeps it valid across a reallocation.
function _set_reply!(text::AbstractString)
    bytes = codeunits(text)
    resize!(_PLUGIN_REPLY, length(bytes) + 1)
    copyto!(_PLUGIN_REPLY, 1, bytes, 1, length(bytes))
    _PLUGIN_REPLY[end] = 0x00
    return Ptr{Cchar}(pointer(_PLUGIN_REPLY))
end

"""
The C entry point the KCL runtime calls: `method` is the fully-qualified plugin
name, `args` / `kwargs` the JSON arguments. Every failure path returns a
`__kcl_PanicInfo__` object so a missing method or a throwing one surfaces as an
ordinary KCL diagnostic — matching Go's `plugin.JSONError` and Python's
`_call_py_method` — instead of unwinding a Julia exception through Rust frames.
"""
function _plugin_agent(method::Cstring, args::Cstring, kwargs::Cstring)::Ptr{Cchar}
    name = method == C_NULL ? "" : unsafe_string(method)
    # `get` returns `nothing` for a missing key, which is also the value of an
    # unset Dict slot — either way the method is unknown.
    target = get(_PLUGIN_REGISTRY, name, nothing)
    if target === nothing
        return _set_reply!(_panic_info("invalid method: $name is not found"))
    end
    result = try
        target(unsafe_string(args), unsafe_string(kwargs))
    catch err
        return _set_reply!(_panic_info(sprint(showerror, err)))
    end
    return _set_reply!(result === nothing ? "" : String(result))
end

# A stable native pointer to `_plugin_agent`, taken once per process. It has to
# be resolved lazily rather than stored in a module-level `const`: this module
# is precompiled, and a `@cfunction` address baked into the cache image is
# stale by the time the process starts — calling it segfaults. Building it on
# first use emits a fresh trampoline at a valid address, and the `Ref` keeps
# the process from re-resolving on every call.
const _PLUGIN_AGENT = Ref{Ptr{Cvoid}}(C_NULL)

function _plugin_agent_ptr()::Ptr{Cvoid}
    _PLUGIN_AGENT[] == C_NULL &&
        (_PLUGIN_AGENT[] = @cfunction(_plugin_agent, Ptr{Cchar}, (Cstring, Cstring, Cstring)))
    return _PLUGIN_AGENT[]
end

"""
    register_plugin(plugin::AbstractString, method::AbstractString, fn) -> PluginMethod

Register `fn` as `kcl_plugin.<plugin>.<method>`, binding the KCL service handle
on the first registration. Register methods at start-up: nothing evaluated
before the first registration can reach the plugin. Re-registering the same
name replaces the previous method.

`fn` is called as `fn(args::String, kwargs::String) -> String` where both
arguments are the raw JSON the runtime sends, and it must return a JSON-encoded
result. See [`PluginMethod`](@ref).
"""
function register_plugin(plugin::AbstractString, method::AbstractString, fn::PluginMethod)
    (isempty(plugin) || isempty(method)) &&
        throw(ArgumentError("KclLib.register_plugin: plugin and method names must not be empty"))
    _PLUGIN_REGISTRY[_PLUGIN_PREFIX * plugin * "." * method] = fn
    if _PLUGIN_SERVICE[] == C_NULL
        _PLUGIN_SERVICE[] = ccall(_service_symbol(:kcl_service_new), Ptr{Cvoid},
                                  (UInt64,), UInt64(UInt(_plugin_agent_ptr())))
    end
    return fn
end

"""
    plugin_registered(plugin::AbstractString, method::AbstractString) -> Bool

Whether `kcl_plugin.<plugin>.<method>` resolves to a registered method.
"""
plugin_registered(plugin::AbstractString, method::AbstractString) =
    haskey(_PLUGIN_REGISTRY, _PLUGIN_PREFIX * plugin * "." * method)

"""
    disable_plugins()

Drop every registered method and release the service handle, returning the
binding to the stateless `call_native` path.
"""
function disable_plugins()
    if _PLUGIN_SERVICE[] != C_NULL
        ccall(_service_symbol(:kcl_service_delete), Cvoid, (Ptr{Cvoid},), _PLUGIN_SERVICE[])
        _PLUGIN_SERVICE[] = C_NULL
    end
    empty!(_PLUGIN_REGISTRY)
    resize!(_PLUGIN_REPLY, 0)
    return nothing
end

"""
    has_plugins() -> Bool

Whether any plugin method is currently registered.
"""
has_plugins() = !isempty(_PLUGIN_REGISTRY)

"""
    plugin_call(name, args) -> Union{Vector{UInt8},Nothing}

Call `name` through the bound service handle, or return `nothing` when no
plugin is registered so the caller falls back to `call_native`.
"""
function plugin_call(name::Vector{UInt8}, args::Vector{UInt8})
    svc = _PLUGIN_SERVICE[]
    svc == C_NULL && return nothing
    # The runtime reads the RPC name as a C string, and `name` is a plain byte
    # vector with no terminator of its own.
    cname = Vector{UInt8}(undef, length(name) + 1)
    copyto!(cname, 1, name, 1, length(name))
    cname[end] = 0x00
    out_len = Ref{Csize_t}(0)
    reply = ccall(_service_symbol(:kcl_service_call_with_length), Ptr{Cchar},
                  (Ptr{Cvoid}, Ptr{Cchar}, Ptr{UInt8}, Csize_t, Ptr{Csize_t}),
                  svc, pointer(cname), args, length(args), out_len)
    reply == C_NULL && return nothing
    try
        # The reply is always NUL-terminated, but the runtime only writes
        # `out_len` on the success path — its panic branch returns an
        # "ERROR:..." string without setting it. Recover the length from the
        # terminator in that case so the error still reaches the caller.
        bytes = unsafe_wrap(Array, reply, out_len[] == 0 ? strlen(reply) : out_len[])
        return copy(bytes)
    finally
        ccall(_service_symbol(:kcl_service_free_string), Cvoid, (Ptr{Cchar},), reply)
    end
end

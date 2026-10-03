#!/usr/bin/env julia
# Cross-language AST dump for the Julia binding.
#
#   julia --project=julia hack/dump/julia.jl <golden.json> <out.json>
#
# Runs the binding's real decoder (`KclLib.parse_module`) over the shared
# capture and writes the tree in the shape `hack/ast_diff/canonical.rb`
# compares.
#
# Julia's decoder is a set of immutable structs, so the walk is reflective:
# `fieldnames` for the structure, `nameof(typeof(v))` for `@cls`, and the
# package's own `node_type` method for `@tag`. That gives the comparator three
# independent claims to cross-check at every tagged node — the struct name,
# the tag the package says the struct has, and the golden — which is the same
# discipline as the Ruby and Python dumpers.
#
# `Node{T}` nests its `Pos` under `pos`, so the comparator's R2 hoists it; the
# rest of the position is flat. `UnknownExpr` / `UnknownStmt` / `UnknownType`
# keep the wire payload in a field called `raw`, and it is written out as
# `@raw` so the comparator can check it against the golden — a binding that
# keeps the payload is checked, and a binding that drops it is a diff by name
# (R11), which is the bug class this harness was built to find.
#
# The package has no JSON dependency: it ships its own parser (`KclLib
# ._json_parse`, used by `parse_module` itself), so reading the golden needs
# nothing extra, and writing it needs a writer, which is below.

using KclLib

# ---------------------------------------------------------------------------
# A minimal JSON writer.
#
# Only the value kinds a decoded AST can hold: nothing, booleans, integers,
# floats, strings, arrays and objects. No dependency, and nothing here decides
# what a node means — it only prints what the decoder produced.
# ---------------------------------------------------------------------------

_json_escape(s::AbstractString) = replace(s,
    "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r",
    "\t" => "\\t", "\b" => "\\b", "\f" => "\\f")

function _write_json(io::IO, v, indent::Int)
    pad = repeat("  ", indent)
    inner = repeat("  ", indent + 1)
    if v === nothing
        print(io, "null")
    elseif v isa Bool
        print(io, v ? "true" : "false")
    elseif v isa Integer
        print(io, string(v))
    elseif v isa AbstractFloat
        print(io, isfinite(v) ? string(v) : "null")
    elseif v isa AbstractString
        print(io, '"', _json_escape(v), '"')
    elseif v isa AbstractVector
        isempty(v) && return print(io, "[]")
        println(io, "[")
        for (i, item) in enumerate(v)
            print(io, inner)
            _write_json(io, item, indent + 1)
            println(io, i == length(v) ? "" : ",")
        end
        print(io, pad, "]")
    elseif v isa AbstractDict
        ks = sort!(collect(keys(v)))
        isempty(ks) && return print(io, "{}")
        println(io, "{")
        for (i, k) in enumerate(ks)
            print(io, inner, '"', _json_escape(string(k)), "\": ")
            _write_json(io, v[k], indent + 1)
            println(io, i == length(ks) ? "" : ",")
        end
        print(io, pad, "}")
    else
        error("hack/dump/julia.jl: cannot serialise a $(typeof(v))")
    end
end

# ---------------------------------------------------------------------------
# The walk.
# ---------------------------------------------------------------------------

"""The struct name, unqualified: `KclLib.SchemaStmt` -> `SchemaStmt`."""
shortname(v) = String(nameof(typeof(v)))

"""The package's own tag for this value, or `nothing` when it has none.

`node_type` is defined for every variant and for nothing else, so a plain
DTO answers `nothing` and the comparator reads that as "this object claims no
tag", which is exactly right.
"""
function tag_of(v)
    applicable(KclLib.node_type, v) ? KclLib.node_type(v) : nothing
end

"""`UnknownExpr` / `UnknownStmt` / `UnknownType` keep the wire payload in `raw`.

It is emitted as `@raw` so the comparator can compare it with the golden
(R11). Anything else is dumped structurally.
"""
is_unknown(v) = v isa Union{KclLib.UnknownExpr, KclLib.UnknownStmt, KclLib.UnknownType}

function dump(v)
    v === nothing && return nothing
    v isa Bool && return v
    v isa Integer && return v
    v isa AbstractFloat && return v
    v isa AbstractString && return String(v)
    v isa AbstractVector && return Any[dump(x) for x in v]
    v isa AbstractDict && return Dict{String,Any}(String(k) => dump(x) for (k, x) in v)

    if v isa KclLib.Pos
        out = Dict{String,Any}("@cls" => shortname(v))
        for f in fieldnames(typeof(v))
            out[String(f)] = dump(getfield(v, f))
        end
        return out
    end

    if v isa KclLib.Node
        out = Dict{String,Any}("@cls" => "Node", "node" => dump(v.node))
        v.pos === nothing || (out["pos"] = dump(v.pos))
        return out
    end

    if is_unknown(v)
        out = Dict{String,Any}("@cls" => shortname(v), "@raw" => dump(v.raw))
        tag = tag_of(v)
        tag === nothing || (out["@tag"] = tag)
        return out
    end

    out = Dict{String,Any}("@cls" => shortname(v))
    tag = tag_of(v)
    tag === nothing || (out["@tag"] = tag)
    # `fieldnames` takes a *type*. `fieldnames(v)` is a MethodError that reads
    # as "this binding's struct has no fields", which is a confusing way to
    # learn that Julia wants `typeof`.
    for f in fieldnames(typeof(v))
        out[String(f)] = dump(getfield(v, f))
    end
    return out
end

# ---------------------------------------------------------------------------

if length(ARGS) != 2
    println(stderr, "usage: julia --project=julia hack/dump/julia.jl <golden.json> <out.json>")
    exit(2)
end

golden_path, out_path = ARGS
module_ast = KclLib.parse_module(read(golden_path, String))

doc = Dict{String,Any}(
    "schema" => "kcl-ast-canonical/1",
    "binding" => "julia",
    "mode" => "reflect",
    "root" => dump(module_ast),
)

open(out_path, "w") do io
    _write_json(io, doc, 0)
    println(io)
end

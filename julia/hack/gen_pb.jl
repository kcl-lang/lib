# Regenerate the vendored protobuf bindings in src/pb from ../spec/spec.proto.
#
# ProtoBuf.jl's code generator does not implement proto `service` definitions
# (see the "Services & RPC" TODO in ProtoBuf.jl), and spec.proto declares the
# KclService/BuiltinService RPC tables. The services are irrelevant for this
# binding — the native dispatcher routes by the fully-qualified RPC name string
# — so we strip the top-level `service Foo { ... }` blocks (matched by their
# column-0 delimiters) into a scratch copy and generate from that.

using ProtoBuf

const SPEC = joinpath(@__DIR__, "..", "..", "spec", "spec.proto")
const OUT = joinpath(@__DIR__, "..", "src", "pb")

function strip_services(text::AbstractString)::String
    lines = split(text, '\n')
    out = String[]
    depth = 0
    in_service = false
    for line in lines
        if !in_service
            if match(r"^service\s+\w+\s*\{\s*$", line) !== nothing
                in_service = true
            else
                push!(out, line)
            end
        else
            # inside a service block: the closing brace is at column 0
            if line == "}"
                in_service = false
            end
        end
    end
    in_service && error("unbalanced service block in $(SPEC)")
    return join(out, '\n')
end

mktempdir() do tmp
    stripped = joinpath(tmp, "spec.proto")
    write(stripped, strip_services(read(SPEC, String)))
    isdir(OUT) && rm(OUT; recursive=true)
    mkpath(OUT)
    protojl("spec.proto", tmp, OUT; add_kwarg_constructors=true)
end

# ProtoBuf.jl escapes Julia-keyword field names as `var"#name"`. Rewrite the
# two occurrences in spec.proto to the conventional trailing-underscore names
# (`type_`, `function_`) so callers can write `kty.type_ == "int"` instead of
# `kty.var"#type"`. Purely textual and deterministic; `make proto` reproduces
# it.
function postprocess_keyword_fields!()
    specpb = joinpath(OUT, "com", "kcl", "api", "spec_pb.jl")
    content = read(specpb, String)
    for (old, new) in ("var\"#type\"" => "type_", "var\"#function\"" => "function_")
        content = replace(content, old => new)
    end
    write(specpb, content)
end
postprocess_keyword_fields!()

# ProtoBuf.jl names the module after the proto package (com.kcl.api); make the
# generated tree includable as KclLib's pb submodule.
println("Generated Julia protobuf bindings in $(abspath(OUT))")

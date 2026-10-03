# ast.jl — typed AST for the Julia binding.
#
# Decodes the `ast_json` string returned by `parse_file` / `parse_program`
# into typed objects matching Rust's AST in `../kcl/crates/ast/src/ast.rs`.
# The same split the C, C++, Dart, Java, Kotlin, Node.js, .NET, WASM, Lua,
# Swift, Zig and Python bindings use applies here:
#
#   * `Stmt` / `Expr` are `#[serde(tag = "type")]`, so each node carries a
#     `type` discriminator and decodes to its own struct.
#   * `Type` is `#[serde(tag = "type", content = "value")]`, so a type node is a
#     two-key object whose `value` holds the variant's payload.
#   * The plain structs nested inside `NodeRef<T>` — `Identifier`, `Target`,
#     `MemberOrIndex`, `Keyword`, `Arguments`, `ConfigEntry`, `CheckExpr`,
#     `CallExpr` — carry no tag of their own.
#
#     module KclLib
#     using KclLib
#
#     m = KclLib.parse_module(KclLib.parse_file(ParseFileArgs(
#         path="main.k", source="schema Person:\n    name: str\n")).ast_json)
#     for ref in m.body
#         s = ref.node
#         s isa SchemaStmt && println(s.name.node, " ", s.body)
#     end
#     end
#
# The JSON is read with the binding's own zero-dependency reader
# (`KclLib._json_parse`), the same one `to_dict` uses.

# ---------------------------------------------------------------------------
# Pos / Node{T} / Comment
# ---------------------------------------------------------------------------

"""A source position, as attached to every parsed node (`ast::Pos`)."""
struct Pos
    filename::String
    line::Int
    column::Int
    end_line::Int
    end_column::Int
end

"""
A value of type `T` together with its source position — `NodeRef<T>` in Rust.
`NodeRef<T>` is a boxed `Node<T>`, so the two share a JSON shape.
"""
struct Node{T}
    node::T
    pos::Union{Pos,Nothing}
end

"""A `#` comment — `ast::Comment { text }`."""
struct Comment
    text::String
end

Base.show(io::IO, p::Pos) = print(io, p.filename, ":", p.line, ":", p.column,
                                   "-", p.end_line, ":", p.end_column)
Base.show(io::IO, c::Comment) = print(io, "Comment(", c.text, ")")
Base.show(io::IO, n::Node) = print(io, "Node(", n.node,
                                   n.pos === nothing ? "" : string(", ", n.pos), ")")

# ---------------------------------------------------------------------------
# Wire helpers — the snake_case mapping and null handling live here only.
# ---------------------------------------------------------------------------

_asobj(v) = v isa AbstractDict{String,Any} ? v : nothing
_obj(v) = (_o = _asobj(v); _o === nothing ? Dict{String,Any}() : _o)

"""`true` only when the key is literally `true`.

`ConfigEntry.is_shorthand` carries
`#[serde(skip_serializing_if = "is_false")]`, so a `false` never reaches the
wire and this reproduces the Rust default.
"""
_flag(w, key) = get(w, key, false) === true

_str(w, key) = (v = get(w, key, nothing); v isa AbstractString ? String(v) : "")

function _strlist(w, key)
    v = get(w, key, nothing)
    v isa AbstractVector || return String[]
    return String[x for x in v if x isa AbstractString]
end

_int(v) = v isa Integer ? Int(v) : 0

_pos_of(w) = haskey(w, "filename") ?
             Pos(_str(w, "filename"), _int(get(w, "line", nothing)),
                 _int(get(w, "column", nothing)), _int(get(w, "end_line", nothing)),
                 _int(get(w, "end_column", nothing))) : nothing

"""Decode a `NodeRef{String}` — the payload is a bare JSON string."""
_string_node(w) = begin
    o = _asobj(w)
    o === nothing ? nothing : Node{String}(_str(o, "node"), _pos_of(o))
end

"""
The element type a `*_from_wire` loader produces.

`Node{T}` is invariant in `T`, so a payload that decodes to a `BasicType`
cannot be stored in a `Node{AstType}` on its own. The widening happens at
construction - `Node{AstType}(basic, pos)` converts the payload up to the
hierarchy - which keeps every container as narrow as the hierarchy while the
concrete variant still drives dispatch through `node_type`.
"""
_loader_type(load) = Any

"""Decode a `NodeRef{T}` whose payload is a JSON object."""
function _node_of(w::Any, load::Function)
    o = _asobj(w)
    o === nothing && return nothing
    inner = _asobj(get(o, "node", nothing))
    inner === nothing && return nothing
    return Node{_loader_type(load)}(load(inner), _pos_of(o))
end

"""Decode a JSON array of `NodeRef{T}`, dropping the nulls the parser emits."""
function _node_list(w::Any, load::Function)
    w isa AbstractVector || return Node{_loader_type(load)}[]
    out = Node{_loader_type(load)}[]
    for item in w
        n = _node_of(item, load)
        n === nothing || push!(out, n)
    end
    return out
end

"""Decode an array of `NodeRef{String}`, e.g. `Identifier.names`."""
function _string_node_list(w::Any)
    w isa AbstractVector || return Node{String}[]
    out = Node{String}[]
    for item in w
        n = _string_node(item)
        n === nothing || push!(out, n)
    end
    return out
end

"""Decode an array of `NodeRef{Union{}}` — `Vec<Option<NodeRef<T>>>`, where the
nulls line up positionally with `Arguments.args` and must be preserved."""
function _nullable_node_list(w::Any, load::Function)
    w isa AbstractVector || return Union{Node{_loader_type(load)},Nothing}[]
    return Union{Node{_loader_type(load)},Nothing}[_node_of(item, load) for item in w]
end

"""Decode a bare list of payload objects (no `NodeRef` wrapper)."""
function _plain_list(w::Any, load::Function)
    w isa AbstractVector || return _loader_type(load)[]
    out = _loader_type(load)[]
    for item in w
        o = _asobj(item)
        o === nothing || push!(out, load(o))
    end
    return out
end

# ---------------------------------------------------------------------------
# Forward declarations. Julia resolves a struct's field types when the struct is
# defined, so the three abstract hierarchies have to exist before the DTOs
# below — `Target` and `Keyword` mention `KclExpr`, `Arguments` mentions
# `AstType` — even though their variants are defined further down. Dispatch is
# dynamic, so the bodies of the `*_from_wire` helpers can stay here too.
# ---------------------------------------------------------------------------

abstract type AstType end

"""An expression (`ast::Expr`).

Named `KclExpr`, not `Expr`: `Expr` is `Base.Expr`, the type of every literal
in a Julia program, and shadowing it here would also make `using KclLib` report
an ambiguous binding for anyone who wrote `Expr` themselves. The Rust name
`AstType` keeps the same problem — `ast::Type` is spelled `AstType` for the
same reason.
"""
abstract type KclExpr end

"""A statement (`ast::Stmt`). `Stmt` is free in Julia, but the pair reads as one
naming convention, so it stays `KclStmt` beside [`KclExpr`](@ref)."""
abstract type KclStmt end

# ---------------------------------------------------------------------------
# Flat DTOs — plain structs the AST nests inside `NodeRef<T>`
# ---------------------------------------------------------------------------

"""`ast::Identifier` — a dotted name plus how it is being used.

`ctx` is `ast::ExprContext`, serialized as the bare string `"Load"` or
`"Store"`.
"""
struct Identifier
    names::Vector{Node{String}}
    pkgpath::String
    ctx::String
end
Identifier() = Identifier(Node{String}[], "", "")
identifier_from_wire(w) = Identifier(_string_node_list(get(w, "names", nothing)),
                                     _str(w, "pkgpath"), _str(w, "ctx"))
Base.show(io::IO, i::Identifier) = print(io, "Identifier(",
    join([n.node for n in i.names], "."), ")")

"""
Decode the payload of a `NodeRef<Comment>`.

A named function rather than an inline lambda, so `_loader_type` can be
specialised for it: the fallback is `Any`, and `Vector{Node{Comment}}` rejects
a `Node{Any}` outright.
"""
comment_from_wire(w) = Comment(_str(w, "text"))

"""`ast::MemberOrIndex` — `a.b` or `a[0]`.

Declared `#[serde(tag = "type", content = "value")]`, so it *is* tagged even
though the variants hold a `NodeRef`.
"""
abstract type MemberOrIndex end

"""`ast::MemberOrIndex::Member` — the `a.b` step of a `Target`."""
struct Member <: MemberOrIndex
    member::Node{String}
end

"""`ast::MemberOrIndex::Index` — the `a[0]` step of a `Target`."""
struct Index <: MemberOrIndex
    index::Node{KclExpr}
end

function member_or_index_from_wire(w)
    value = get(w, "value", nothing)
    if get(w, "type", nothing) == "Member"
        # `value` is a `NodeRef<String>`, so it carries its own position.
        return Member(something(_string_node(value), Node{String}("", nothing)))
    elseif get(w, "type", nothing) == "Index"
        # `value` is a `NodeRef<Expr>`, so the wrapper has to be unwrapped
        # before the tagged `Expr` decoder sees it.
        return Index(something(_node_of(value, expr_from_wire),
                              Node{KclExpr}(MissingExpr(), nothing)))
    end
    return Member(Node{String}("", nothing))
end

"""`ast::Target` — `a.b.c` on the left of an assignment."""
struct Target
    name::Union{Node{String},Nothing}
    paths::Vector{MemberOrIndex}
    pkgpath::String
end
target_from_wire(w) = Target(_string_node(get(w, "name", nothing)),
                              _plain_list(get(w, "paths", nothing),
                                          member_or_index_from_wire),
                              _str(w, "pkgpath"))
Base.show(io::IO, t::Target) = print(io, "Target(",
    t.name === nothing ? "" : t.name.node, ")")

"""`ast::Keyword` — `arg = value` in a call or a schema instantiation.

`arg` is a `NodeRef{Identifier}`, not an expression.
"""
struct Keyword
    arg::Union{Node{Identifier},Nothing}
    value::Union{Node{KclExpr},Nothing}
end
keyword_from_wire(w) = Keyword(_node_of(get(w, "arg", nothing), identifier_from_wire),
                               _node_of(get(w, "value", nothing), expr_from_wire))

"""`ast::Arguments` — a parameter list.

`defaults` and `ty_list` are `Vec<Option<...>>`, so they are the same length
as `args` with a null for every parameter that has no default and no
annotation. Both keep their nulls for that reason.
"""
struct Arguments
    args::Vector{Node{Identifier}}
    defaults::Vector{Union{Node{KclExpr},Nothing}}
    ty_list::Vector{Union{Node{AstType},Nothing}}
end
function arguments_from_wire(w)
    Arguments(_node_list(get(w, "args", nothing), identifier_from_wire),
              _nullable_node_list(get(w, "defaults", nothing), expr_from_wire),
              _nullable_node_list(get(w, "ty_list", nothing), type_from_wire))
end
Base.length(a::Arguments) = length(a.args)
Base.show(io::IO, a::Arguments) = print(io, "Arguments(",
    join([x.node.names[1].node for x in a.args if !isempty(x.node.names)], ", "), ")")

"""`ast::ConfigEntry` — one `key = value` pair inside a config expression."""
struct ConfigEntry
    key::Union{Node{KclExpr},Nothing}
    value::Union{Node{KclExpr},Nothing}
    operation::String
    is_shorthand::Bool
end
config_entry_from_wire(w) =
    ConfigEntry(_node_of(get(w, "key", nothing), expr_from_wire),
                _node_of(get(w, "value", nothing), expr_from_wire),
                _str(w, "operation"), _flag(w, "is_shorthand"))

"""`ast::CheckExpr` — `test if cond, "message"`.

`CheckExpr` is a plain struct, so it arrives untagged in a schema `check:`
body — `SchemaStmt.checks` is `Vec<NodeRef<CheckExpr>>` and the `Expr` enum is
the only thing in the AST that carries a `type` tag. The `Expr::Check` variant
is the *same* struct reached through that tag, so one type serves both here,
which is how the Java binding draws it too. That is why a check is not a
`KclExpr` field to descend into and why it is not tagged on the wire.
"""
struct CheckExpr <: KclExpr
    test::Union{Node{KclExpr},Nothing}
    if_cond::Union{Node{KclExpr},Nothing}
    msg::Union{Node{KclExpr},Nothing}
end
node_type(::CheckExpr) = "Check"
check_from_wire(w) = CheckExpr(_node_of(get(w, "test", nothing), expr_from_wire),
                               _node_of(get(w, "if_cond", nothing), expr_from_wire),
                               _node_of(get(w, "msg", nothing), expr_from_wire))

"""`ast::SchemaIndexSignature` — `[str]: int`."""
struct SchemaIndexSignature
    key_name::Union{Node{String},Nothing}
    value::Union{Node{KclExpr},Nothing}
    any_other::Bool
    key_ty::Union{Node{AstType},Nothing}
    value_ty::Union{Node{AstType},Nothing}
end
schema_index_signature_from_wire(w) =
    SchemaIndexSignature(_string_node(get(w, "key_name", nothing)),
                         _node_of(get(w, "value", nothing), expr_from_wire),
                         _flag(w, "any_other"),
                         _node_of(get(w, "key_ty", nothing), type_from_wire),
                         _node_of(get(w, "value_ty", nothing), type_from_wire))


# ---------------------------------------------------------------------------
# Type hierarchy — `ast::Type`
# ---------------------------------------------------------------------------

"""`ast::Type::Any`. A unit variant, so serde emits `{"type": "Any"}` with no
`value` key at all."""
struct AnyType <: AstType end

"""`ast::Type::Basic(BasicType)` — one of `Bool`, `Int`, `Float`, `Str`.

`BasicType` is a fieldless enum, so serde writes it as a bare string. A basic
type therefore reads back as `{"type": "Basic", "value": "Int"}`, *not*
`{"type": "Int"}` — the discriminator names the outer `Type` variant, and the
inner enum name is the payload.
"""
struct BasicType <: AstType
    name::String
end

"""`ast::Type::Named(Identifier)` — a schema or alias name."""
struct NamedType <: AstType
    identifier::Identifier
end

"""`ast::Type::List(ListType)`."""
struct ListType <: AstType
    inner_type::Union{Node{AstType},Nothing}
end

"""`ast::Type::Dict(DictType)`."""
struct DictType <: AstType
    key_type::Union{Node{AstType},Nothing}
    value_type::Union{Node{AstType},Nothing}
end

"""`ast::Type::Union(UnionType)`. The Rust field is `type_elements`."""
struct UnionType <: AstType
    types::Vector{Node{AstType}}
end

"""`ast::Type::Literal(LiteralType)`.

The nested `LiteralType` is itself tagged, so the payload arrives as
`{"type": "Int", "value": {"value": 1, "suffix": null}}`. The payload is kept
verbatim rather than re-modelled — it has four different shapes depending on
the inner tag.
"""
struct LiteralType <: AstType
    value::Any
    inner_tag::Union{String,Nothing}
end

"""`ast::Type::Function(FunctionType)`."""
struct FunctionType <: AstType
    params_ty::Union{Vector{Node{AstType}},Nothing}
    ret_ty::Union{Node{AstType},Nothing}
end

"""A `Type` variant this package does not know about yet.

Same deliberate divergence from Java as [`UnknownExpr`](@ref): Jackson raises on
an unregistered subtype, this decoder degrades. `ast::Type` is adjacently
tagged, so an unknown tag leaves the payload under `value` untouched for the
caller.
"""
struct UnknownType <: AstType
    tag::String
    value::Any
end

function type_from_wire(w::AbstractDict{String,Any})::AstType
    tag = get(w, "type", nothing)
    tag isa AbstractString || return AnyType()
    value = get(w, "value", nothing)
    if tag == "Any"
        return AnyType()
    elseif tag == "Basic"
        return BasicType(value isa AbstractString ? String(value) : "")
    elseif tag == "Named"
        return NamedType(identifier_from_wire(_obj(value)))
    elseif tag == "List"
        return ListType(_node_of(_obj(value)["inner_type"], type_from_wire))
    elseif tag == "Dict"
        o = _obj(value)
        return DictType(_node_of(o["key_type"], type_from_wire),
                            _node_of(o["value_type"], type_from_wire))
    elseif tag == "Union"
        return UnionType(_node_list(_obj(value)["type_elements"], type_from_wire))
    elseif tag == "Literal"
        return LiteralType(value, get(_asobj(value), "type", nothing))
    elseif tag == "Function"
        o = _obj(value)
        params = get(o, "params_ty", nothing)
        return FunctionType(params isa AbstractVector ?
                                _node_list(params, type_from_wire) : nothing,
                                _node_of(o["ret_ty"], type_from_wire))
    end
    return UnknownType(String(tag), value)
end

# ---------------------------------------------------------------------------
# Expression hierarchy — `ast::Expr`
# ---------------------------------------------------------------------------

"""The `type` tag the parser emitted."""
node_type(::KclExpr) = "?"

struct TargetExpr <: KclExpr
    target::Target
end
node_type(::TargetExpr) = "Target"

struct IdentifierExpr <: KclExpr
    identifier::Identifier
end
node_type(::IdentifierExpr) = "Identifier"

struct UnaryExpr <: KclExpr
    op::String
    operand::Union{Node{KclExpr},Nothing}
end
node_type(::UnaryExpr) = "Unary"

struct BinaryExpr <: KclExpr
    left::Union{Node{KclExpr},Nothing}
    op::String
    right::Union{Node{KclExpr},Nothing}
end
node_type(::BinaryExpr) = "Binary"

struct IfExpr <: KclExpr
    body::Union{Node{KclExpr},Nothing}
    cond::Union{Node{KclExpr},Nothing}
    orelse::Union{Node{KclExpr},Nothing}
end
node_type(::IfExpr) = "If"

struct SelectorExpr <: KclExpr
    value::Union{Node{KclExpr},Nothing}
    attr::Union{Node{Identifier},Nothing}
    ctx::String
    has_question::Bool
end
node_type(::SelectorExpr) = "Selector"

"""`ast::CallExpr` — the payload of `Expr::Call`.

`ast::CallExpr` is a plain struct, and the `Expr` enum is the only thing in the
AST that is `#[serde(tag = "type")]`, so the *same* struct appears untagged
wherever a `NodeRef<CallExpr>` sits outside the enum. `SchemaStmt.decorators`,
`RuleStmt.decorators` and `SchemaAttr.decorators` are the three such places,
and a decorator is a call — which is why the Java binding gives the untagged
twin its own name, [`Decorator`](@ref), and this binding does too.
"""
struct CallExpr <: KclExpr
    func::Union{Node{KclExpr},Nothing}
    args::Vector{Node{KclExpr}}
    keywords::Vector{Node{Keyword}}
end
node_type(::CallExpr) = "Call"

"""`ast::CallExpr` as it appears *untagged* — what a `decorator` decodes to.

Field-for-field the same as [`CallExpr`](@ref), which is the point: the parser
emits one struct and serde tags it only inside the `Expr` enum. The two types
are kept apart so `SchemaAttr.decorators` says what it holds, and
`CallExpr(d::Decorator)` is the promotion back into the tagged hierarchy.
"""
struct Decorator
    func::Union{Node{KclExpr},Nothing}
    args::Vector{Node{KclExpr}}
    keywords::Vector{Node{Keyword}}
end
CallExpr(d::Decorator) = CallExpr(d.func, d.args, d.keywords)

call_expr_from_wire(w) = Decorator(_node_of(get(w, "func", nothing), expr_from_wire),
                                   _node_list(get(w, "args", nothing), expr_from_wire),
                                   _node_list(get(w, "keywords", nothing), keyword_from_wire))

struct ParenExpr <: KclExpr
    expr::Union{Node{KclExpr},Nothing}
end
node_type(::ParenExpr) = "Paren"

struct QuantExpr <: KclExpr
    target::Union{Node{KclExpr},Nothing}
    variables::Vector{Node{Identifier}}
    op::String
    test::Union{Node{KclExpr},Nothing}
    if_cond::Union{Node{KclExpr},Nothing}
    ctx::String
end
node_type(::QuantExpr) = "Quant"

struct ListExpr <: KclExpr
    elts::Vector{Node{KclExpr}}
    ctx::String
end
node_type(::ListExpr) = "List"

struct ListIfItemExpr <: KclExpr
    if_cond::Union{Node{KclExpr},Nothing}
    exprs::Vector{Node{KclExpr}}
    orelse::Union{Node{KclExpr},Nothing}
end
node_type(::ListIfItemExpr) = "ListIfItem"

"""`ast::Expr::CompClause` — the `x in xs if cond` half of a comprehension."""
struct CompClause <: KclExpr
    targets::Vector{Node{Identifier}}
    iter::Union{Node{KclExpr},Nothing}
    ifs::Vector{Node{KclExpr}}
end
node_type(::CompClause) = "CompClause"

struct ListComp <: KclExpr
    elt::Union{Node{KclExpr},Nothing}
    generators::Vector{Node{CompClause}}
end
node_type(::ListComp) = "ListComp"

struct StarredExpr <: KclExpr
    value::Union{Node{KclExpr},Nothing}
    ctx::String
end
node_type(::StarredExpr) = "Starred"

"""`ast::Expr::DictComp`.

The Rust field is a single `entry: ConfigEntry`, not the
`entry_key` / `key` / `value` triple some bindings model.
"""
struct DictComp <: KclExpr
    entry::Union{ConfigEntry,Nothing}
    generators::Vector{Node{CompClause}}
end
node_type(::DictComp) = "DictComp"

struct ConfigIfEntryExpr <: KclExpr
    if_cond::Union{Node{KclExpr},Nothing}
    items::Vector{Node{ConfigEntry}}
    orelse::Union{Node{KclExpr},Nothing}
end
node_type(::ConfigIfEntryExpr) = "ConfigIfEntry"

"""`ast::Expr::Schema` — inline instantiation, `Person { name = "x" }`.

`name` is a `NodeRef{Identifier}`, not an expression.
"""
struct SchemaExpr <: KclExpr
    name::Union{Node{Identifier},Nothing}
    args::Vector{Node{KclExpr}}
    kwargs::Vector{Node{Keyword}}
    config::Union{Node{KclExpr},Nothing}
end
node_type(::SchemaExpr) = "Schema"

"""`ast::SchemaExpr` as it appears *untagged* — a schema body.

`UnificationStmt.value` is a `NodeRef<SchemaExpr>`, and `SchemaExpr` is a plain
struct, so the right-hand side of `s: Person { … }` arrives with no `type` tag
and cannot go through `expr_from_wire` — running it through the tagged loader
would produce an `UnknownExpr`. That is what `UnificationStmt.value` is
annotated with.

Java calls this position `SchemaConfig` and gives it a class distinct from the
tagged `SchemaExpr`, because a JVM binding can. Here the two are the same
struct, so this is an alias rather than a second type: one object, two names,
exactly as the Node.js binding draws it with its `SchemaConfig` / `SchemaExpr`
typedefs. `hack/test_check_ast_field_types.rb` pins
`schema_expr_from_wire` to construct `SchemaExpr`, which is the other reason
this is not a separate struct.
"""
const SchemaConfig = SchemaExpr

struct ConfigExpr <: KclExpr
    items::Vector{Node{ConfigEntry}}
end
node_type(::ConfigExpr) = "Config"

struct LambdaExpr <: KclExpr
    args::Union{Node{Arguments},Nothing}
    body::Vector{Node{KclStmt}}
    return_ty::Union{Node{AstType},Nothing}
end
node_type(::LambdaExpr) = "Lambda"

struct Subscript <: KclExpr
    value::Union{Node{KclExpr},Nothing}
    index::Union{Node{KclExpr},Nothing}
    lower::Union{Node{KclExpr},Nothing}
    upper::Union{Node{KclExpr},Nothing}
    step::Union{Node{KclExpr},Nothing}
    ctx::String
    has_question::Bool
end
node_type(::Subscript) = "Subscript"

struct KeywordExpr <: KclExpr
    keyword::Keyword
end
node_type(::KeywordExpr) = "Keyword"

struct ArgumentsExpr <: KclExpr
    arguments::Arguments
end
node_type(::ArgumentsExpr) = "Arguments"

struct Compare <: KclExpr
    left::Union{Node{KclExpr},Nothing}
    ops::Vector{String}
    comparators::Vector{Node{KclExpr}}
end
node_type(::Compare) = "Compare"

"""`ast::Expr::NumberLit`.

`value` is a `NumberLitValue`, itself tagged
`#[serde(tag = "type", content = "value")]` — so `0` arrives as
`{"type": "Int", "value": 0}`.
"""
struct NumberLit <: KclExpr
    binary_suffix::Union{String,Nothing}
    value_tag::Union{String,Nothing}
    value::Union{Real,Nothing}
end
node_type(::NumberLit) = "NumberLit"

struct StringLit <: KclExpr
    is_long_string::Bool
    raw_value::String
    value::String
end
node_type(::StringLit) = "StringLit"

"""`ast::Expr::NameConstantLit` — `True`, `False` or `Undefined`."""
struct NameConstantLit <: KclExpr
    value::String
end
node_type(::NameConstantLit) = "NameConstantLit"

raw"""`ast::Expr::JoinedString` — an f-string, `"a${b}c"`."""
struct JoinedString <: KclExpr
    is_long_string::Bool
    values::Vector{Node{KclExpr}}
    raw_value::String
end
node_type(::JoinedString) = "JoinedString"

raw"""`ast::Expr::FormattedValue` — the `${x:>10}` part of an f-string."""
struct FormattedValue <: KclExpr
    is_long_string::Bool
    value::Union{Node{KclExpr},Nothing}
    format_spec::Union{String,Nothing}
end
node_type(::FormattedValue) = "FormattedValue"

"""`ast::Expr::Missing` — the parser's placeholder for a syntax error."""
struct MissingExpr <: KclExpr end
node_type(::MissingExpr) = "Missing"

"""An `Expr` tag this package does not know about — kept verbatim so a newer
`libkcl` degrades to a readable node instead of throwing.

The raw payload is attached, so a caller can still see what the parser emitted.
Java has no equivalent: it drives Jackson off `@JsonSubTypes`, and Jackson
raises on an unregistered subtype rather than inventing one. Julia has no way
to raise from inside a decoder and still return something a caller can walk, so
a newer parser degrades here instead of throwing. This is a deliberate
divergence from the Java vocabulary, in the same place the Node.js binding makes
it.
"""
struct UnknownExpr <: KclExpr
    variant::String
    raw::AbstractDict{String,Any}
end
node_type(u::UnknownExpr) = u.variant

"""Decode an *untagged* `CompClause`.

`ListComp.generators` and `DictComp.generators` are `Vec<NodeRef<CompClause>>`
and only the `Expr` enum is tagged, so inside a comprehension a clause arrives
as a bare `{targets, iter, ifs}`.
"""
comp_clause_from_wire(w) =
    CompClause(_node_list(get(w, "targets", nothing), identifier_from_wire),
               _node_of(get(w, "iter", nothing), expr_from_wire),
               _node_list(get(w, "ifs", nothing), expr_from_wire))

"""Decode an *untagged* `SchemaExpr`, as used by `UnificationStmt.value`.

`UnificationStmt.value` is a `NodeRef{SchemaExpr>` and `SchemaExpr` is a plain
struct, so the payload arrives as a bare `{name, args, kwargs, config}` with
**no `type` key**. Routing it through `expr_from_wire` would land on
`MissingExpr` instead — and because `UnificationStmt.value` is statically typed
as a `Node{SchemaConfig}`, that turned into a `TypeError` rather than a silently
wrong tree. The untagged decoder has to be reachable on its own.
"""
schema_expr_from_wire(w) =
    SchemaExpr(_node_of(get(w, "name", nothing), identifier_from_wire),
               _node_list(get(w, "args", nothing), expr_from_wire),
               _node_list(get(w, "kwargs", nothing), keyword_from_wire),
               _node_of(get(w, "config", nothing), expr_from_wire))

function expr_from_wire(w::AbstractDict{String,Any})::KclExpr
    v = get(w, "type", nothing)
    v isa AbstractString || return MissingExpr()
    v = String(v)
    if v == "Target"
        return TargetExpr(target_from_wire(w))
    elseif v == "Identifier"
        return IdentifierExpr(identifier_from_wire(w))
    elseif v == "Unary"
        return UnaryExpr(_str(w, "op"),
                         _node_of(get(w, "operand", nothing), expr_from_wire))
    elseif v == "Binary"
        return BinaryExpr(_node_of(get(w, "left", nothing), expr_from_wire),
                          _str(w, "op"),
                          _node_of(get(w, "right", nothing), expr_from_wire))
    elseif v == "If"
        return IfExpr(_node_of(get(w, "body", nothing), expr_from_wire),
                      _node_of(get(w, "cond", nothing), expr_from_wire),
                      _node_of(get(w, "orelse", nothing), expr_from_wire))
    elseif v == "Selector"
        return SelectorExpr(_node_of(get(w, "value", nothing), expr_from_wire),
                            _node_of(get(w, "attr", nothing), identifier_from_wire),
                            _str(w, "ctx"), _flag(w, "has_question"))
    elseif v == "Call"
        # A tagged `Call` and a `Decorator` are the same struct; the tag is the
        # only difference, so promote the untagged decode into the hierarchy.
        return CallExpr(call_expr_from_wire(w))
    elseif v == "Paren"
        return ParenExpr(_node_of(get(w, "expr", nothing), expr_from_wire))
    elseif v == "Quant"
        return QuantExpr(_node_of(get(w, "target", nothing), expr_from_wire),
                         _node_list(get(w, "variables", nothing), identifier_from_wire),
                         _str(w, "op"),
                         _node_of(get(w, "test", nothing), expr_from_wire),
                         _node_of(get(w, "if_cond", nothing), expr_from_wire),
                         _str(w, "ctx"))
    elseif v == "List"
        return ListExpr(_node_list(get(w, "elts", nothing), expr_from_wire),
                        _str(w, "ctx"))
    elseif v == "ListIfItem"
        return ListIfItemExpr(_node_of(get(w, "if_cond", nothing), expr_from_wire),
                              _node_list(get(w, "exprs", nothing), expr_from_wire),
                              _node_of(get(w, "orelse", nothing), expr_from_wire))
    elseif v == "ListComp"
        return ListComp(_node_of(get(w, "elt", nothing), expr_from_wire),
                            _node_list(get(w, "generators", nothing), comp_clause_from_wire))
    elseif v == "Starred"
        return StarredExpr(_node_of(get(w, "value", nothing), expr_from_wire),
                           _str(w, "ctx"))
    elseif v == "DictComp"
        entry = _asobj(get(w, "entry", nothing))
        return DictComp(entry === nothing ? nothing : config_entry_from_wire(entry),
                            _node_list(get(w, "generators", nothing), comp_clause_from_wire))
    elseif v == "ConfigIfEntry"
        return ConfigIfEntryExpr(_node_of(get(w, "if_cond", nothing), expr_from_wire),
                                 _node_list(get(w, "items", nothing), config_entry_from_wire),
                                 _node_of(get(w, "orelse", nothing), expr_from_wire))
    elseif v == "CompClause"
        return comp_clause_from_wire(w)
    elseif v == "Schema"
        return schema_expr_from_wire(w)
    elseif v == "Config"
        return ConfigExpr(_node_list(get(w, "items", nothing), config_entry_from_wire))
    elseif v == "Check"
        return check_from_wire(w)
    elseif v == "Lambda"
        return LambdaExpr(_node_of(get(w, "args", nothing), arguments_from_wire),
                          _node_list(get(w, "body", nothing), stmt_from_wire),
                          _node_of(get(w, "return_ty", nothing), type_from_wire))
    elseif v == "Subscript"
        return Subscript(_node_of(get(w, "value", nothing), expr_from_wire),
                             _node_of(get(w, "index", nothing), expr_from_wire),
                             _node_of(get(w, "lower", nothing), expr_from_wire),
                             _node_of(get(w, "upper", nothing), expr_from_wire),
                             _node_of(get(w, "step", nothing), expr_from_wire),
                             _str(w, "ctx"), _flag(w, "has_question"))
    elseif v == "Keyword"
        return KeywordExpr(keyword_from_wire(w))
    elseif v == "Arguments"
        return ArgumentsExpr(arguments_from_wire(w))
    elseif v == "Compare"
        return Compare(_node_of(get(w, "left", nothing), expr_from_wire),
                           _strlist(w, "ops"),
                           _node_list(get(w, "comparators", nothing), expr_from_wire))
    elseif v == "NumberLit"
        inner = _asobj(get(w, "value", nothing))
        suffix = get(w, "binary_suffix", nothing)
        value = inner === nothing ? nothing : get(inner, "value", nothing)
        tag = inner === nothing ? nothing : get(inner, "type", nothing)
        return NumberLit(suffix isa AbstractString ? String(suffix) : nothing,
                             tag isa AbstractString ? String(tag) : nothing,
                             value isa Real ? value : nothing)
    elseif v == "StringLit"
        return StringLit(_flag(w, "is_long_string"), _str(w, "raw_value"),
                             _str(w, "value"))
    elseif v == "NameConstantLit"
        return NameConstantLit(_str(w, "value"))
    elseif v == "JoinedString"
        return JoinedString(_flag(w, "is_long_string"),
                                _node_list(get(w, "values", nothing), expr_from_wire),
                                _str(w, "raw_value"))
    elseif v == "FormattedValue"
        spec = get(w, "format_spec", nothing)
        return FormattedValue(_flag(w, "is_long_string"),
                                  _node_of(get(w, "value", nothing), expr_from_wire),
                                  spec isa AbstractString ? String(spec) : nothing)
    elseif v == "Missing"
        return MissingExpr()
    end
    return UnknownExpr(v, w)
end

# ---------------------------------------------------------------------------
# Statement hierarchy — `ast::Stmt`
# ---------------------------------------------------------------------------

node_type(::KclStmt) = "?"

struct TypeAliasStmt <: KclStmt
    type_name::Union{Node{Identifier},Nothing}
    type_value::Union{Node{String},Nothing}
    ty::Union{Node{AstType},Nothing}
end
node_type(::TypeAliasStmt) = "TypeAlias"

struct ExprStmt <: KclStmt
    exprs::Vector{Node{KclExpr}}
end
node_type(::ExprStmt) = "Expr"

"""`ast::Stmt::Unification` — the `Name { ... }` form inside a schema body.

`target` is a `NodeRef{Identifier}` and the value is a `NodeRef{SchemaExpr>`,
not a generic expression. `SchemaExpr` is a plain struct, so what lands in
`value` is a [`SchemaConfig`](@ref), the untagged twin of the `Schema`
expression variant.
"""
struct UnificationStmt <: KclStmt
    target::Union{Node{Identifier},Nothing}
    value::Union{Node{SchemaConfig},Nothing}
end
node_type(::UnificationStmt) = "Unification"

struct AssignStmt <: KclStmt
    targets::Vector{Node{Target}}
    value::Union{Node{KclExpr},Nothing}
    ty::Union{Node{AstType},Nothing}
end
node_type(::AssignStmt) = "Assign"

struct AugAssignStmt <: KclStmt
    target::Union{Node{Target},Nothing}
    value::Union{Node{KclExpr},Nothing}
    op::String
end
node_type(::AugAssignStmt) = "AugAssign"

struct AssertStmt <: KclStmt
    test::Union{Node{KclExpr},Nothing}
    if_cond::Union{Node{KclExpr},Nothing}
    msg::Union{Node{KclExpr},Nothing}
end
node_type(::AssertStmt) = "Assert"

struct IfStmt <: KclStmt
    body::Vector{Node{KclStmt}}
    cond::Union{Node{KclExpr},Nothing}
    orelse::Vector{Node{KclStmt}}
end
node_type(::IfStmt) = "If"

"""`ast::Stmt::Import` — `import a.b.c as d`.

`path` and `asname` are `Node{String}`, so they carry their own position;
`rawpath`, `name` and `pkg_name` are plain strings on the same node.
"""
struct ImportStmt <: KclStmt
    path::Union{Node{String},Nothing}
    rawpath::String
    name::String
    as_name::Union{Node{String},Nothing}
    pkg_name::String
end
node_type(::ImportStmt) = "Import"

"""`ast::Stmt::SchemaAttr` — one attribute inside a schema body."""
struct SchemaAttr <: KclStmt
    doc::String
    name::Union{Node{String},Nothing}
    op::Union{String,Nothing}
    value::Union{Node{KclExpr},Nothing}
    is_optional::Bool
    decorators::Vector{Node{Decorator}}
    ty::Union{Node{AstType},Nothing}
end
node_type(::SchemaAttr) = "SchemaAttr"

"""`ast::Stmt::Schema` — `schema`, `protocol` and `mixin` all land here."""
struct SchemaStmt <: KclStmt
    doc::Union{Node{String},Nothing}
    name::Union{Node{String},Nothing}
    parent_name::Union{Node{Identifier},Nothing}
    for_host_name::Union{Node{Identifier},Nothing}
    is_mixin::Bool
    is_protocol::Bool
    args::Union{Node{Arguments},Nothing}
    mixins::Vector{Node{Identifier}}
    body::Vector{Node{KclStmt}}
    decorators::Vector{Node{Decorator}}
    checks::Vector{Node{CheckExpr}}
    index_signature::Union{Node{SchemaIndexSignature},Nothing}
end
node_type(::SchemaStmt) = "Schema"

struct RuleStmt <: KclStmt
    doc::Union{Node{String},Nothing}
    name::Union{Node{String},Nothing}
    parent_rules::Vector{Node{Identifier}}
    decorators::Vector{Node{Decorator}}
    checks::Vector{Node{CheckExpr}}
    args::Union{Node{Arguments},Nothing}
    for_host_name::Union{Node{Identifier},Nothing}
end
node_type(::RuleStmt) = "Rule"

"""A `Stmt` tag this package does not know about. Same deliberate divergence from
Java as [`UnknownExpr`](@ref): Jackson raises on an unregistered subtype, this
decoder degrades."""
struct UnknownStmt <: KclStmt
    variant::String
    raw::AbstractDict{String,Any}
end
node_type(u::UnknownStmt) = u.variant

function stmt_from_wire(w::AbstractDict{String,Any})::KclStmt
    v = get(w, "type", nothing)
    v isa AbstractString || return ExprStmt(Node{KclExpr}[])
    v = String(v)
    if v == "TypeAlias"
        return TypeAliasStmt(_node_of(get(w, "type_name", nothing), identifier_from_wire),
                             _string_node(get(w, "type_value", nothing)),
                             _node_of(get(w, "ty", nothing), type_from_wire))
    elseif v == "Expr"
        return ExprStmt(_node_list(get(w, "exprs", nothing), expr_from_wire))
    elseif v == "Unification"
        # `value` is a `NodeRef{SchemaExpr>` and `SchemaExpr` is a plain struct,
        # so the payload has no `type` key — it must go through the untagged
        # decoder, not `expr_from_wire`.
        return UnificationStmt(_node_of(get(w, "target", nothing), identifier_from_wire),
                               _node_of(get(w, "value", nothing), schema_expr_from_wire))
    elseif v == "Assign"
        return AssignStmt(_node_list(get(w, "targets", nothing), target_from_wire),
                          _node_of(get(w, "value", nothing), expr_from_wire),
                          _node_of(get(w, "ty", nothing), type_from_wire))
    elseif v == "AugAssign"
        return AugAssignStmt(_node_of(get(w, "target", nothing), target_from_wire),
                             _node_of(get(w, "value", nothing), expr_from_wire),
                             _str(w, "op"))
    elseif v == "Assert"
        return AssertStmt(_node_of(get(w, "test", nothing), expr_from_wire),
                          _node_of(get(w, "if_cond", nothing), expr_from_wire),
                          _node_of(get(w, "msg", nothing), expr_from_wire))
    elseif v == "If"
        return IfStmt(_node_list(get(w, "body", nothing), stmt_from_wire),
                      _node_of(get(w, "cond", nothing), expr_from_wire),
                      _node_list(get(w, "orelse", nothing), stmt_from_wire))
    elseif v == "Import"
        return ImportStmt(_string_node(get(w, "path", nothing)),
                          _str(w, "rawpath"), _str(w, "name"),
                          _string_node(get(w, "asname", nothing)),
                          _str(w, "pkg_name"))
    elseif v == "SchemaAttr"
        op = get(w, "op", nothing)
        return SchemaAttr(_str(w, "doc"),
                          _string_node(get(w, "name", nothing)),
                          op isa AbstractString ? String(op) : nothing,
                          _node_of(get(w, "value", nothing), expr_from_wire),
                          _flag(w, "is_optional"),
                          _node_list(get(w, "decorators", nothing), call_expr_from_wire),
                          _node_of(get(w, "ty", nothing), type_from_wire))
    elseif v == "Schema"
        return SchemaStmt(_string_node(get(w, "doc", nothing)),
                          _string_node(get(w, "name", nothing)),
                          _node_of(get(w, "parent_name", nothing), identifier_from_wire),
                          _node_of(get(w, "for_host_name", nothing), identifier_from_wire),
                          _flag(w, "is_mixin"), _flag(w, "is_protocol"),
                          _node_of(get(w, "args", nothing), arguments_from_wire),
                          _node_list(get(w, "mixins", nothing), identifier_from_wire),
                          _node_list(get(w, "body", nothing), stmt_from_wire),
                          _node_list(get(w, "decorators", nothing), call_expr_from_wire),
                          _node_list(get(w, "checks", nothing), check_from_wire),
                          _node_of(get(w, "index_signature", nothing),
                                   schema_index_signature_from_wire))
    elseif v == "Rule"
        return RuleStmt(_string_node(get(w, "doc", nothing)),
                        _string_node(get(w, "name", nothing)),
                        _node_list(get(w, "parent_rules", nothing), identifier_from_wire),
                        _node_list(get(w, "decorators", nothing), call_expr_from_wire),
                        _node_list(get(w, "checks", nothing), check_from_wire),
                        _node_of(get(w, "args", nothing), arguments_from_wire),
                        _node_of(get(w, "for_host_name", nothing), identifier_from_wire))
    end
    return UnknownStmt(v, w)
end

# ---------------------------------------------------------------------------
# `_loader_type` methods. Declared here rather than next to each loader so the
# whole contract is visible in one place: every loader that feeds `_node_of` /
# `_node_list` / `_plain_list` and the hierarchy it widens to.
# ---------------------------------------------------------------------------

_loader_type(::typeof(identifier_from_wire)) = Identifier
_loader_type(::typeof(member_or_index_from_wire)) = MemberOrIndex
_loader_type(::typeof(target_from_wire)) = Target
_loader_type(::typeof(keyword_from_wire)) = Keyword
_loader_type(::typeof(arguments_from_wire)) = Arguments
_loader_type(::typeof(config_entry_from_wire)) = ConfigEntry
_loader_type(::typeof(check_from_wire)) = CheckExpr
_loader_type(::typeof(schema_index_signature_from_wire)) = SchemaIndexSignature
_loader_type(::typeof(type_from_wire)) = AstType
_loader_type(::typeof(expr_from_wire)) = KclExpr
_loader_type(::typeof(comp_clause_from_wire)) = CompClause
_loader_type(::typeof(call_expr_from_wire)) = Decorator
_loader_type(::typeof(schema_expr_from_wire)) = SchemaConfig  # == SchemaExpr
_loader_type(::typeof(stmt_from_wire)) = KclStmt
_loader_type(::typeof(comment_from_wire)) = Comment

# ---------------------------------------------------------------------------
# Module — `ast::Module` and the public entry points
# ---------------------------------------------------------------------------

"""`ast::Module` — the top-level AST node of a single KCL file.

The Rust struct has no `pkg` field: the Java and Go bindings used to expose one
and were aligned to drop it, so this struct has none either.
"""
struct Module
    filename::String
    doc::Union{Node{String},Nothing}
    body::Vector{Node{KclStmt}}
    comments::Vector{Node{Comment}}
end

# The name this binding shipped before the cross-binding vocabulary was
# settled on the Java one. Kept so existing `KclModule` code still resolves.
const KclModule = Module

function module_from_wire(w)
    return Module(_str(w, "filename"),
                  _string_node(get(w, "doc", nothing)),
                  _node_list(get(w, "body", nothing), stmt_from_wire),
                  _node_list(get(w, "comments", nothing), comment_from_wire))
end
Base.show(io::IO, m::Module) =
    print(io, "Module(", m.filename, ", ", length(m.body), " stmts)")

"""
    parse_module(ast_json::AbstractString) -> Module

Decode the `ast_json` string returned by [`parse_file`](@ref).

    julia> m = parse_module(parse_file(ParseFileArgs(
    #            path="main.k", source="schema Person:\\n    name: str\\n")).ast_json)
    julia> [r.node.name.node for r in m.body if r.node isa SchemaStmt]
    1-element Vector{String}:
     "Person"
"""
function parse_module(ast_json::AbstractString)::Module
    w = _asobj(_json_parse(ast_json))
    w === nothing && throw(ArgumentError("KclLib: expected a KCL Module object"))
    return module_from_wire(w)
end

"""
    parse_program_ast(program_json::AbstractString) -> Vector{Module}

Decode the `ast_json` string returned by [`parse_program`](@ref). Named with an
`Ast` suffix because `parse_program` is the RPC wrapper that takes a
`ParseProgramArgs`.

The service serializes a program either as a bare array of modules or as a
`{"root": ..., "pkgs": {"__main__": [...]}}` envelope; both are accepted.
"""
function parse_program_ast(program_json::AbstractString)::Vector{Module}
    decoded = _json_parse(program_json)
    if decoded isa AbstractVector
        return Module[module_from_wire(_obj(m)) for m in decoded]
    end
    envelope = _asobj(decoded)
    envelope === nothing && return Module[]
    main = get(_obj(get(envelope, "pkgs", nothing)), "__main__", nothing)
    main isa AbstractVector || return Module[]
    return Module[module_from_wire(_obj(m)) for m in main]
end

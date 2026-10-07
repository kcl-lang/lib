# ast_ctors.jl — the AST node constructors, asserted.
#
# `src/ast.jl` declares every AST struct `Base.@kwdef` and gives every field
# whose `ast.rs` counterpart is a `Vec` / `Option<Vec>` the empty collection as
# its default, so a caller can build a node without spelling `[]` at every
# level of the tree. That is ergonomics, and ergonomics rot silently: nothing
# about a missing default fails a build or a decode, it only shows up as a
# caller writing `Node{ConfigEntry}[]` by hand forever. `docs/architecture.md`
# rule 2 makes the shape machine-checkable against `ast.rs`, which is what
# `hack/check_ast_constructors.rb` does; these tests pin the *runtime* half,
# which no static check can see.
#
# Two things are load-bearing and easy to break, so they get their own cases:
#
#   * the positional constructor is unchanged. `@kwdef` adds a keyword method;
#     it does not reshape the inner one, which still takes every field in
#     declaration order. `*_from_wire` builds every node positionally, so a
#     `@kwdef` that quietly changed the positional signature would show up
#     here as a decode failure long after it was written.
#   * the default is evaluated per call. Hoisting `X[]` into a `const` to save
#     an allocation is the classic `@kwdef` trap: every node built afterwards
#     shares one array, so a caller that pushes onto it corrupts the next
#     caller's node.
#
# The third thing worth pinning is the boundary: a *scalar* and a *required
# node reference* stay required. A default there would let a caller build a
# node the parser can never produce, which is a worse bug than typing `[]`.

# ---------------------------------------------------------------------------
# A collection a caller no longer has to spell
# ---------------------------------------------------------------------------

@testset "AST constructors: a defaulted collection can be omitted" begin
    # `ConfigExpr` has one field and it is a `Vec`, so the whole constructor is
    # the empty one. Before this, the only spelling was `ConfigExpr(Node{ConfigEntry}[])`.
    @test ConfigExpr().items == Node{ConfigEntry}[]
    @test isempty(ConfigExpr().items)

    # `Arguments` is three parallel `Vec`s — `defaults` and `ty_list` keep a
    # `nothing` per element, which is why their element type is the union.
    empty_args = Arguments()
    @test empty_args.args == Node{Identifier}[]
    @test empty_args.defaults == Union{Node{KclExpr},Nothing}[]
    @test empty_args.ty_list == Union{Node{AstType},Nothing}[]

    @test UnionType().types == Node{AstType}[]

    # `Module.body` and `Module.comments` sit after two non-collection fields,
    # so this is the case a trailing-only positional default could not reach.
    # Qualified as `KclLib.Module` because `Base` exports a `Module` too and
    # `using KclLib` leaves the bare name ambiguous — `KclModule` is the
    # clash-free alias, and this is what `parse_module` hands back.
    m = KclLib.Module(filename = "main.k", doc = nothing)
    @test m.filename == "main.k"
    @test m.body == Node{KclStmt}[]
    @test m.comments == Node{Comment}[]

    # A defaulted field that is *not* first: `Target.paths` sits between two
    # required fields.
    t = Target(name = Node{String}("a.b", nothing), pkgpath = "")
    @test t.name.node == "a.b"
    @test t.paths == MemberOrIndex[]
    @test t.pkgpath == ""

    # `FunctionType.params_ty` is `Option<Vec<NodeRef<Type>>>` in `ast.rs`, so
    # its default is `nothing` — the value serde writes for an absent one —
    # and not an empty list.
    ft = FunctionType(ret_ty = nothing)
    @test ft.params_ty === nothing
end

@testset "AST constructors: a node with real content still builds" begin
    # The point of a default is not that everything is empty: it is that the
    # fields a caller *does* care about can be named, by keyword, without
    # counting the ones they do not.
    name = Node{String}("Person", nothing)
    schema = SchemaExpr(name = Node{Identifier}(Identifier([Node{String}("Person", nothing)], "", "Load"), nothing),
                        config = nothing)
    @test schema.name.node.names[1].node == "Person"
    @test schema.args == Node{KclExpr}[]
    @test schema.kwargs == Node{Keyword}[]
    @test schema.config === nothing

    # `name` and `config` are `NodeRef`s and stay required keywords; the two
    # collections in between them do not.
    @test_throws UndefKeywordError SchemaExpr(name = nothing, args = Node{KclExpr}[])
    @test node_type(SchemaExpr(name = nothing, config = nothing)) == "Schema"
end

# ---------------------------------------------------------------------------
# The positional constructor is untouched
# ---------------------------------------------------------------------------

"""
A `SchemaStmt` written the way a caller now writes one: every field that is
not a collection named, the four collections omitted.

`SchemaStmt` is the widest node in the AST — twelve fields, four of them
`Vec`s — so it is where the rule earns its keep. The eight that stay are
`doc`, `name`, `parent_name`, `for_host_name`, `is_mixin`, `is_protocol`,
`args` and `index_signature`, and every one of them is a scalar or a
`NodeRef`.
"""
_schema_stmt(name) = SchemaStmt(doc = nothing, name = name,
                                parent_name = nothing, for_host_name = nothing,
                                is_mixin = false, is_protocol = false,
                                args = nothing, index_signature = nothing)

@testset "AST constructors: the positional constructor is unchanged" begin
    # Exactly the call `stmt_from_wire` makes in `ast.jl` for a `"Schema"` tag,
    # spelled positionally. If this stops working, the decoder is broken.
    positional = SchemaStmt(nothing,
                            Node{String}("Person", nothing),
                            nothing, nothing, false, false, nothing,
                            Node{Identifier}[], Node{KclStmt}[], Node{Decorator}[],
                            Node{CheckExpr}[], nothing)
    @test positional.name.node == "Person"
    @test positional.mixins == Node{Identifier}[]

    # …and the two spellings agree, field for field.
    keyword = _schema_stmt(Node{String}("Person", nothing))
    @test keyword.doc == positional.doc
    @test keyword.name == positional.name
    @test keyword.parent_name == positional.parent_name
    @test keyword.for_host_name == positional.for_host_name
    @test keyword.is_mixin == positional.is_mixin
    @test keyword.is_protocol == positional.is_protocol
    @test keyword.args == positional.args
    @test keyword.mixins == positional.mixins
    @test keyword.body == positional.body
    @test keyword.decorators == positional.decorators
    @test keyword.checks == positional.checks
    @test keyword.index_signature == positional.index_signature

    # `CallExpr(d::Decorator)` is the untagged-to-tagged promotion and is not a
    # `@kwdef`, so it is worth pinning that it survived the change.
    promoted = CallExpr(Decorator(nothing, Node{KclExpr}[], Node{Keyword}[]))
    @test promoted isa CallExpr
    @test promoted.args == Node{KclExpr}[]
end

# ---------------------------------------------------------------------------
# The boundary: only collections are defaulted
# ---------------------------------------------------------------------------

"""
The fields of `S` a caller may *not* omit, found by trying.

Built by probing rather than by reading a list: every field of `S` is dropped
from an otherwise-complete keyword call in turn, and the ones that make the
call raise `UndefKeywordError` are the required ones. That way the assertion
below is about the behaviour a caller meets rather than about a hand-written
copy of the field list, which is exactly the kind of list that rots.
"""
function _required_fields(S, complete)
    required = Symbol[]
    for name in keys(complete)
        partial = copy(complete)
        delete!(partial, name)
        try
            S(; partial...)
        catch e
            e isa UndefKeywordError && push!(required, name)
        end
    end
    sort!(required)
end

@testset "AST constructors: a scalar or a required node is still required" begin
    # Every field of `SchemaStmt`, with the value a caller would pass for it.
    complete = Dict{Symbol,Any}(
        :doc => nothing, :name => Node{String}("Person", nothing),
        :parent_name => nothing, :for_host_name => nothing,
        :is_mixin => false, :is_protocol => false, :args => nothing,
        :mixins => Node{Identifier}[], :body => Node{KclStmt}[],
        :decorators => Node{Decorator}[], :checks => Node{CheckExpr}[],
        :index_signature => nothing)

    # Exactly the four `Vec`s, no more and no fewer. `doc`, `parent_name`,
    # `for_host_name`, `args` and `index_signature` are `Option<NodeRef<…>>` and
    # `is_mixin` / `is_protocol` are `bool` in `ast.rs`; `name` is the
    # `NodeRef` the node cannot exist without. A default on any of them would
    # let a caller build a node the parser can never emit.
    @test _required_fields(SchemaStmt, complete) ==
          [:args, :doc, :for_host_name, :index_signature, :is_mixin,
           :is_protocol, :name, :parent_name]

    # …and `ConfigExpr`, whose only field is a `Vec`, needs nothing at all.
    @test isempty(_required_fields(ConfigExpr, Dict{Symbol,Any}(:items => Node{ConfigEntry}[])))

    @test_throws UndefKeywordError SchemaStmt(name = Node{String}("Person", nothing))
    @test_throws UndefKeywordError KclLib.Module(filename = "main.k")
    @test_throws UndefKeywordError Target(name = nothing)

    # A `Union{…,Nothing}` field is `Option<…>` in `ast.rs` and still has to be
    # named: nullable is not the same as optional, and this binding spells
    # absent as `nothing` rather than as an omitted argument.
    @test_throws UndefKeywordError SchemaExpr()
end

# ---------------------------------------------------------------------------
# Defaults are per call, not shared
# ---------------------------------------------------------------------------

@testset "AST constructors: each defaulted collection is a fresh array" begin
    # A shared default is the bug `@kwdef` invites: `const EMPTY = Node{ConfigEntry}[]`
    # is one array for the whole process, and one caller's `push!` is then
    # visible in every node built afterwards.
    first = ConfigExpr()
    second = ConfigExpr()
    @test first.items !== second.items

    push!(first.items, Node{ConfigEntry}(ConfigEntry(nothing, nothing, "=", false), nothing))
    @test length(first.items) == 1
    @test isempty(second.items)
    @test isempty(ConfigExpr().items)

    # The same for a struct with several: touching one field's default must not
    # be observable through another's.
    s1 = _schema_stmt(nothing)
    s2 = _schema_stmt(nothing)
    push!(s1.mixins, Node{Identifier}(Identifier(Node{String}[], "", "Load"), nothing))
    @test length(s1.mixins) == 1
    @test isempty(s2.mixins)
    @test isempty(s2.body)
    @test isempty(s2.decorators)
    @test isempty(s2.checks)
end

# ---------------------------------------------------------------------------
# Defaults do not leak into decoding
# ---------------------------------------------------------------------------

@testset "AST constructors: a decoded node is not a defaulted one" begin
    # The other half of the boundary. If a default ever leaked into
    # `*_from_wire` — say a decoder stopped passing a field it used to pass —
    # the field would quietly become empty and a tree would lose structure with
    # nothing failing. So decode a real schema and check the collections are
    # populated, next to a hand-built one where they are empty by construction.
    m = parse_module("""
    {"filename":"a.k","body":[{"node":{"type":"Schema","name":{"node":"Person"},
    "body":[{"node":{"type":"SchemaAttr","name":{"node":"name"},"ty":{"type":"Basic","value":"Str"}}}],
    "decorators":[{"node":{"func":{"node":{"type":"Identifier","names":[{"node":"deprecated"}]}},"args":[],"keywords":[]}}],
    "checks":[{"node":{"test":{"node":{"type":"NumberLit","value":{"type":"Int","value":1}}},"if_cond":null,"msg":null}}]}}]}
    """)

    decoded = m.body[1].node
    @test decoded isa SchemaStmt
    @test length(decoded.body) == 1
    @test length(decoded.decorators) == 1
    @test length(decoded.checks) == 1

    built = _schema_stmt(Node{String}("Person", nothing))
    @test isempty(built.body)
    @test isempty(built.decorators)
    @test isempty(built.checks)
end
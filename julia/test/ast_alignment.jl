# ast_alignment.jl — the Julia AST wire contract, asserted.
#
# `src/ast.jl` is a hand-written decoder for the JSON the KCL parser emits, and
# a wrong guess about that JSON fails *silently*. A tag the `if/elseif` chain
# in `expr_from_wire` does not know falls through to `UnknownExpr`, so a
# decoder keyed on `"CheckExpression"` — the spelling `Expr::get_expr_name()`
# returns, which is a diagnostic name and not the serde tag — still returns a
# plausible-looking tree full of unknowns. A `NodeRef<Identifier>` read as a
# `Node{KclExpr}` returns a zero-valued node rather than an error.
#
# These tests decode `testdata/ast/alignment.json`, the real parser's output for
# `testdata/ast/alignment.k` — a file written to exercise every node shape —
# and assert the invariants documented in that directory's README. Decoding the
# captured JSON rather than calling `parse_file` keeps this a pure test of the
# decoder: it needs no native runtime, and it does not depend on the parser
# staying byte-identical.
#
# The `AST` testset in `runtests.jl` is the other half of the pair. That one
# parses a live fixture through the FFI, proving the parser emits something the
# loader accepts; this one proves the loader understands the shapes the parser
# is *specified* to emit.
#
# `testdata/ast/alignment.json` lives outside this package, two directories up.

# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------

"""Locate the shared golden capture.

`Pkg.test` runs with the package root as the working directory; the candidate
list keeps this working from `test/` too.
"""
function _alignment_fixture()
    candidates = [
        normpath(joinpath(@__DIR__, "..", "..", "testdata", "ast", "alignment.json")),
        normpath(joinpath(@__DIR__, "..", "testdata", "ast", "alignment.json")),
        "testdata/ast/alignment.json",
    ]
    for c in candidates
        isfile(c) && return c
    end
    error("could not locate testdata/ast/alignment.json (tried $candidates)")
end

const ALIGNMENT = parse_module(read(_alignment_fixture(), String))

# ---------------------------------------------------------------------------
# Lookups
# ---------------------------------------------------------------------------

"""The first top-level statement satisfying `pred`, or `nothing`."""
function _find_stmt(f::Type{T}) where {T <: KclStmt}
    for ref in ALIGNMENT.body
        ref.node isa T && return ref.node
    end
    return nothing
end

"""The top-level `name = …`, as `(target, value)` or `nothing`."""
function _assign(name::AbstractString)
    for ref in ALIGNMENT.body
        s = ref.node
        s isa AssignStmt || continue
        isempty(s.targets) && continue
        t = first(s.targets).node
        t.name !== nothing && t.name.node == name && return t
    end
    return nothing
end

"""The RHS of the top-level `name = …`."""
function _assigned_value(name::AbstractString)
    for ref in ALIGNMENT.body
        s = ref.node
        s isa AssignStmt || continue
        isempty(s.targets) && continue
        t = first(s.targets).node
        t.name !== nothing && t.name.node == name && return s.value.node
    end
    error("alignment.k assigns nothing named $name")
end

"""The top-level `Target` for `name = …` whose paths match `npaths`."""
function _target_with_paths(name::AbstractString, npaths::Int)
    for ref in ALIGNMENT.body
        s = ref.node
        s isa AssignStmt || continue
        isempty(s.targets) && continue
        t = first(s.targets).node
        t.name !== nothing && t.name.node == name &&
            length(t.paths) == npaths && return t
    end
    error("alignment.k has no $name assignment with $npaths path(s)")
end

"""The named type alias's `ty` payload, e.g. `TLitInt` -> a `LiteralType`."""
function _alias_type(name::AbstractString)
    for ref in ALIGNMENT.body
        s = ref.node
        s isa TypeAliasStmt || continue
        s.type_name === nothing && continue
        s.type_name.node.names[1].node == name && return s.ty.node
    end
    error("alignment.k has no type alias named $name")
end

"""The top-level `ImportStmt` whose `as_name` is (or is not) present."""
function _import(as_name::Union{Nothing,AbstractString})
    for ref in ALIGNMENT.body
        s = ref.node
        s isa ImportStmt || continue
        if s.as_name === nothing
            as_name === nothing && return s
        elseif as_name !== nothing && s.as_name.node == as_name
            return s
        end
    end
    error("alignment.k has no import with as_name = $(repr(as_name))")
end

"""The named schema, or `nothing`."""
function _schema_named(name::AbstractString)
    for ref in ALIGNMENT.body
        s = ref.node
        s isa SchemaStmt || continue
        s.name !== nothing && s.name.node == name && return s
    end
    return nothing
end

"""The named attribute of the named schema."""
function _schema_attr(schema_name::AbstractString, attr::AbstractString)
    for ref in ALIGNMENT.body
        s = ref.node
        s isa SchemaStmt || continue
        s.name === nothing || s.name.node == schema_name || continue
        for a in s.body
            n = a.node
            n isa SchemaAttr || continue
            n.name !== nothing && n.name.node == attr && return n
        end
    end
    error("alignment.k has no $attr attribute on $schema_name")
end

# ---------------------------------------------------------------------------
# The unresolved-tag walk
# ---------------------------------------------------------------------------
#
# A tag this decoder does not recognise becomes an `UnknownExpr` rather than an
# error, so this walk is the only thing standing between a stale dispatch table
# and a silently empty AST. It is the assertion the rest of this file leans on:
# an `Unknown*` here means every other assertion below would still "pass" on a
# tree full of placeholders.
#
# Mutually recursive — `expr` reaches `stmt` through `LambdaExpr.body` while
# `stmt` reaches `expr` through every value field — so these are top-level
# functions rather than local closures.

function _walk_type!(t::AstType, unknown::Vector{String})
    if t isa UnknownType
        push!(unknown, "Type.$(t.tag)")
    elseif t isa ListType
        _walk_type_opt!(t.inner_type, unknown)
    elseif t isa DictType
        _walk_type_opt!(t.key_type, unknown)
        _walk_type_opt!(t.value_type, unknown)
    elseif t isa UnionType
        foreach(n -> _walk_type!(n.node, unknown), t.types)
    elseif t isa FunctionType
        t.params_ty === nothing || foreach(n -> _walk_type!(n.node, unknown), t.params_ty)
        _walk_type_opt!(t.ret_ty, unknown)
    end
    return nothing
end

"""Walk an optional `NodeRef`, or nothing at all."""
function _walk_type_opt!(ref, unknown::Vector{String})
    ref === nothing || _walk_type!(ref.node, unknown)
    return nothing
end

"""Walk an optional `NodeRef`, or nothing at all."""
function _walk_expr_opt!(ref, unknown::Vector{String})
    ref === nothing || _walk_expr!(ref.node, unknown)
    return nothing
end

function _walk_expr!(e::KclExpr, unknown::Vector{String})
    if e isa UnknownExpr
        push!(unknown, "Expr.$(e.variant)")
    elseif e isa TargetExpr
        _walk_target!(e.target, unknown)
    elseif e isa IdentifierExpr
        nothing
    elseif e isa UnaryExpr
        _walk_expr_opt!(e.operand, unknown)
    elseif e isa BinaryExpr
        _walk_expr_opt!(e.left, unknown)
        _walk_expr_opt!(e.right, unknown)
    elseif e isa IfExpr
        _walk_expr_opt!(e.body, unknown)
        _walk_expr_opt!(e.cond, unknown)
        _walk_expr_opt!(e.orelse, unknown)
    elseif e isa SelectorExpr
        _walk_expr_opt!(e.value, unknown)
    elseif e isa CallExpr
        _walk_expr_opt!(e.func, unknown)
        foreach(n -> _walk_expr!(n.node, unknown), e.args)
        foreach(n -> _walk_keyword!(n.node, unknown), e.keywords)
    elseif e isa ParenExpr
        _walk_expr_opt!(e.expr, unknown)
    elseif e isa QuantExpr
        _walk_expr_opt!(e.target, unknown)
        _walk_expr_opt!(e.test, unknown)
        _walk_expr_opt!(e.if_cond, unknown)
    elseif e isa ListExpr
        foreach(n -> _walk_expr!(n.node, unknown), e.elts)
    elseif e isa ListIfItemExpr
        _walk_expr_opt!(e.if_cond, unknown)
        foreach(n -> _walk_expr!(n.node, unknown), e.exprs)
        _walk_expr_opt!(e.orelse, unknown)
    elseif e isa ListComp
        _walk_expr_opt!(e.elt, unknown)
        foreach(n -> _walk_clause!(n.node, unknown), e.generators)
    elseif e isa StarredExpr
        _walk_expr_opt!(e.value, unknown)
    elseif e isa DictComp
        e.entry === nothing || _walk_entry!(e.entry, unknown)
        foreach(n -> _walk_clause!(n.node, unknown), e.generators)
    elseif e isa ConfigIfEntryExpr
        _walk_expr_opt!(e.if_cond, unknown)
        foreach(n -> _walk_entry!(n.node, unknown), e.items)
        _walk_expr_opt!(e.orelse, unknown)
    elseif e isa CompClause
        _walk_expr_opt!(e.iter, unknown)
        foreach(n -> _walk_expr!(n.node, unknown), e.ifs)
    elseif e isa SchemaExpr
        foreach(n -> _walk_expr!(n.node, unknown), e.args)
        foreach(n -> _walk_keyword!(n.node, unknown), e.kwargs)
        _walk_expr_opt!(e.config, unknown)
    elseif e isa ConfigExpr
        foreach(n -> _walk_entry!(n.node, unknown), e.items)
    elseif e isa CheckExpr
        _walk_expr_opt!(e.test, unknown)
        _walk_expr_opt!(e.if_cond, unknown)
        _walk_expr_opt!(e.msg, unknown)
    elseif e isa LambdaExpr
        e.args === nothing || _walk_arguments!(e.args.node, unknown)
        foreach(n -> _walk_stmt!(n.node, unknown), e.body)
        _walk_type_opt!(e.return_ty, unknown)
    elseif e isa Subscript
        _walk_expr_opt!(e.value, unknown)
        _walk_expr_opt!(e.index, unknown)
        _walk_expr_opt!(e.lower, unknown)
        _walk_expr_opt!(e.upper, unknown)
        _walk_expr_opt!(e.step, unknown)
    elseif e isa KeywordExpr
        _walk_keyword!(e.keyword, unknown)
    elseif e isa ArgumentsExpr
        _walk_arguments!(e.arguments, unknown)
    elseif e isa Compare
        _walk_expr_opt!(e.left, unknown)
        foreach(n -> _walk_expr!(n.node, unknown), e.comparators)
    elseif e isa JoinedString
        foreach(n -> _walk_expr!(n.node, unknown), e.values)
    elseif e isa FormattedValue
        _walk_expr_opt!(e.value, unknown)
    end
    # NumberLit / StringLit / NameConstantLit / MissingExpr hold no nested node.
    return nothing
end

function _walk_stmt!(s::KclStmt, unknown::Vector{String})
    if s isa UnknownStmt
        push!(unknown, "Stmt.$(s.variant)")
    elseif s isa TypeAliasStmt
        _walk_type_opt!(s.ty, unknown)
    elseif s isa ExprStmt
        foreach(n -> _walk_expr!(n.node, unknown), s.exprs)
    elseif s isa UnificationStmt
        s.value === nothing || _walk_config!(s.value.node, unknown)
    elseif s isa AssignStmt
        foreach(n -> _walk_target!(n.node, unknown), s.targets)
        _walk_expr_opt!(s.value, unknown)
        _walk_type_opt!(s.ty, unknown)
    elseif s isa AugAssignStmt
        s.target === nothing || _walk_target!(s.target.node, unknown)
        _walk_expr_opt!(s.value, unknown)
    elseif s isa AssertStmt
        _walk_expr_opt!(s.test, unknown)
        _walk_expr_opt!(s.if_cond, unknown)
        _walk_expr_opt!(s.msg, unknown)
    elseif s isa IfStmt
        foreach(n -> _walk_stmt!(n.node, unknown), s.body)
        _walk_expr_opt!(s.cond, unknown)
        foreach(n -> _walk_stmt!(n.node, unknown), s.orelse)
    elseif s isa SchemaAttr
        _walk_expr_opt!(s.value, unknown)
        foreach(n -> _walk_decorator!(n.node, unknown), s.decorators)
        _walk_type_opt!(s.ty, unknown)
    elseif s isa SchemaStmt
        s.args === nothing || _walk_arguments!(s.args.node, unknown)
        foreach(n -> _walk_stmt!(n.node, unknown), s.body)
        foreach(n -> _walk_decorator!(n.node, unknown), s.decorators)
        foreach(n -> _walk_check!(n.node, unknown), s.checks)
    elseif s isa RuleStmt
        foreach(n -> _walk_decorator!(n.node, unknown), s.decorators)
        foreach(n -> _walk_check!(n.node, unknown), s.checks)
        s.args === nothing || _walk_arguments!(s.args.node, unknown)
    end
    # ImportStmt holds no nested node.
    return nothing
end

function _walk_target!(t::Target, unknown::Vector{String})
    for p in t.paths
        p isa Index && _walk_expr!(p.index.node, unknown)
    end
    return nothing
end

function _walk_entry!(c::ConfigEntry, unknown::Vector{String})
    _walk_expr_opt!(c.key, unknown)
    _walk_expr_opt!(c.value, unknown)
    return nothing
end

function _walk_keyword!(k::Keyword, unknown::Vector{String})
    # `arg` is a `NodeRef<Identifier>`, so it holds no nested expression.
    _walk_expr_opt!(k.value, unknown)
    return nothing
end

function _walk_clause!(c::CompClause, unknown::Vector{String})
    _walk_expr_opt!(c.iter, unknown)
    foreach(n -> _walk_expr!(n.node, unknown), c.ifs)
    return nothing
end

function _walk_arguments!(a::Arguments, unknown::Vector{String})
    foreach(n -> n === nothing || _walk_expr!(n.node, unknown), a.defaults)
    foreach(n -> n === nothing || _walk_type!(n.node, unknown), a.ty_list)
    return nothing
end

"""A `Decorator` is a `CallExpr` reached untagged, so it walks as a call."""
function _walk_decorator!(d::Decorator, unknown::Vector{String})
    _walk_expr_opt!(d.func, unknown)
    foreach(n -> _walk_expr!(n.node, unknown), d.args)
    return nothing
end

"""A `SchemaConfig` (an alias of `SchemaExpr`) reached untagged."""
function _walk_config!(c::SchemaConfig, unknown::Vector{String})
    foreach(n -> _walk_expr!(n.node, unknown), c.args)
    _walk_expr_opt!(c.config, unknown)
    return nothing
end

function _walk_check!(c::CheckExpr, unknown::Vector{String})
    _walk_expr_opt!(c.test, unknown)
    _walk_expr_opt!(c.if_cond, unknown)
    _walk_expr_opt!(c.msg, unknown)
    return nothing
end

# ---------------------------------------------------------------------------

@testset "AST alignment" begin

    @testset "the golden capture is the shape the README documents" begin
        # Deliberately not a byte count: the golden is regenerated whenever the
        # fixture gains a case, and README.md asks for invariants, not a diff.
        @test endswith(ALIGNMENT.filename, "alignment.k")
        @test ALIGNMENT.doc === nothing
        @test !isempty(ALIGNMENT.body)
        @test !isempty(ALIGNMENT.comments)
        # It does claim to cover every variant, so the floor is well above a
        # happy-path sample: 11 `Stmt` variants, 8 `Type` variants, 24 tagged
        # `Expr` variants and the untagged DTOs.
        @test length(ALIGNMENT.body) >= 60
        @test length(ALIGNMENT.comments) >= 25
    end

    @testset "every tag in the tree resolves" begin
        unknown = String[]
        for ref in ALIGNMENT.body
            _walk_stmt!(ref.node, unknown)
        end
        if !isempty(unknown)
            for u in unknown
                println("    unresolved: ", u)
            end
        end
        @test isempty(unknown)
    end

    @testset "Comment is a struct, not a bare string" begin
        # `ast::Comment` is a plain struct with one `String` field, so the
        # object under `node` is `{"text": "..."}`. A decoder that reads the
        # `node` wrapper as the text itself is silently wrong - and this exact
        # bug existed in four bindings.
        @test all(ref -> ref.node isa Comment, ALIGNMENT.comments)
        @test all(ref -> !isempty(ref.node.text), ALIGNMENT.comments)
        @test ALIGNMENT.comments[1].node.text ==
              "# Every AST node shape the language bindings model, in one file."
        @test ALIGNMENT.comments[1].pos.line == 1
    end

    @testset "Type is tagged `type` with the payload in `value`" begin
        # `ast::Type` is `#[serde(tag = "type", content = "value")]`, and
        # `BasicType` is a fieldless enum, so `str` reads back as
        # {"type": "Basic", "value": "Str"} and NOT {"type": "Str"}.
        @test _alias_type("TBasic") isa BasicType
        @test _alias_type("TBasic").name == "Str"
        @test _alias_type("TAny") isa AnyType
        @test _alias_type("TList") isa ListType
        @test _alias_type("TList").inner_type.node isa BasicType
        @test _alias_type("TList").inner_type.node.name == "Int"
        @test _alias_type("TDict") isa DictType
        @test _alias_type("TDict").key_type.node.name == "Str"
        @test _alias_type("TDict").value_type.node.name == "Int"
        @test _alias_type("TUnion") isa UnionType
        @test Set(t.node.name for t in _alias_type("TUnion").types) == Set(["Int", "Str"])
        @test _alias_type("TFunc") isa FunctionType
        @test [t.node.name for t in _alias_type("TFunc").params_ty] == ["Int", "Str"]
        @test _alias_type("TFunc").ret_ty.node.name == "Bool"
        @test _alias_type("TNamed") isa NamedType
        @test _alias_type("TNamed").identifier.names[1].node == "Cloud"
        # `FunctionType.params_ty` is `Option<Vec<...>>` and the parser only
        # ever builds `None` or `Some(non-empty)`, so `() -> bool` arrives as
        # `params_ty: null` and never as `[]`. Mapping the null to an empty
        # vector is normalising rather than losing information, but nothing
        # else pins it.
        @test _alias_type("TFuncNoArgs") isa FunctionType
        @test _alias_type("TFuncNoArgs").params_ty === nothing
        @test _alias_type("TFuncNoArgs").ret_ty.node.name == "Bool"
    end

    @testset "a literal type is doubly nested" begin
        # `LiteralType` is *itself* tagged, so
        # {"type": "Literal", "value": {"type": "Int", "value": {"value": 1,
        # "suffix": null}}} - the tag names the shape and the payload is
        # nested one level deeper again.
        for (name, inner) in (("TLitInt", "Int"), ("TLitStr", "Str"),
                              ("TLitBool", "Bool"), ("TLitFloat", "Float"))
            ty = _alias_type(name)
            @test ty isa LiteralType
            @test ty.inner_tag == inner
        end
        # `LiteralType.value` keeps the whole adjacently-tagged content object
        # rather than reaching through to the scalar, and `inner_tag` is the
        # tag of the *inner* enum. The inner content is not uniform either:
        # `NumberLitValue::Int` carries a `{value, suffix}` struct while the
        # other three are the bare JSON scalar, so the depth really does depend
        # on the tag.
        int_lit = _alias_type("TLitInt")
        @test int_lit.value["value"]["value"] == 1
        @test int_lit.value["value"]["suffix"] === nothing
        @test _alias_type("TLitStr").value["value"] == "s"
        @test _alias_type("TLitFloat").value["value"] == 1.5
        @test _alias_type("TLitBool").value["value"] == true
    end

    @testset "serde flattens a newtype variant into the same object" begin
        # `Expr::Identifier(Identifier)` arrives as
        # {"type": "Identifier", "names": [...], "pkgpath": "", "ctx": "Load"} -
        # there is no `identifier` wrapper key to descend through, and a
        # decoder that looks for one silently returns an empty tree.
        chain = _assigned_value("compare_chain")
        @test chain isa Compare
        @test length(chain.ops) == 2
        @test chain.ops == ["Lt", "LtE"]
        @test chain.left.node isa NumberLit
        @test chain.comparators[1].node isa IdentifierExpr
        @test chain.comparators[1].node.identifier.names[1].node == "a"
        @test chain.comparators[1].node.identifier.ctx == "Load"
        @test chain.comparators[2].node isa NumberLit
    end

    @testset "a call is a CallExpr, a decorator is an untagged Decorator" begin
        call = _assigned_value("call")
        @test call isa CallExpr
        @test call.func.node isa IdentifierExpr
        @test length(call.args) == 2
        @test length(call.keywords) == 1
        # `Keyword.arg` is a `NodeRef<Identifier>`, not a `NodeRef<Expr>`.
        @test call.keywords[1].node.arg.node isa Identifier
        @test call.keywords[1].node.arg.node.names[1].node == "k"
        @test call.keywords[1].node.value.node isa NumberLit

        name_attr = _schema_attr("Person", "name")
        @test length(name_attr.decorators) == 2
        @test all(d -> d.node isa Decorator, name_attr.decorators)
        @test name_attr.decorators[1].node.func.node.identifier.names[1].node == "deprecated"
        # The second one carries a keyword argument, which also proves a
        # decorator's `keywords` is a `Vec<NodeRef<Keyword>>`.
        @test name_attr.decorators[2].node.func.node.identifier.names[1].node == "info"
        @test length(name_attr.decorators[2].node.keywords) == 1
        @test isempty(name_attr.decorators[2].node.args)
    end

    @testset "schema checks decode to CheckExpr, the untagged struct" begin
        person = _schema_named("Person")
        @test length(person.checks) == 2
        first_check = person.checks[1].node
        @test first_check isa CheckExpr
        # Same struct, so the `Expr::Check` variant keeps the same name and the
        # `Check` tag is the only thing that distinguishes the two positions.
        @test node_type(first_check) == "Check"
        @test first_check.test.node isa Compare
        @test first_check.test.node.ops == ["GtE"]
        # `test if cond, msg` - the first check is unguarded, the second is not.
        @test first_check.if_cond === nothing
        @test first_check.msg.node isa StringLit
        @test first_check.msg.node.value == "age must be non-negative"
        guarded = person.checks[2].node
        @test guarded.if_cond.node isa IdentifierExpr
        @test guarded.if_cond.node.identifier.names[1].node == "age"
    end

    @testset "a unification value is an untagged SchemaConfig" begin
        # `UnificationStmt.value` is a `NodeRef<SchemaExpr>`, and `SchemaExpr`
        # is a plain struct, so it has no `type` key and cannot go through the
        # tagged `Expr` loader. `SchemaConfig` is the name the field carries,
        # the way the Java binding annotates the same position.
        unif = _find_stmt(UnificationStmt)
        @test unif !== nothing
        @test unif.target.node.names[1].node == "u"
        @test unif.value.node isa SchemaConfig
        @test unif.value.node isa SchemaExpr
        @test unif.value.node.name.node.names[1].node == "Person"
        @test unif.value.node.config.node isa ConfigExpr
        @test length(unif.value.node.config.node.items) == 1
        # The tagged twin is the same struct with a `type` beside it.
        inline = _assigned_value("x")
        @test inline isa SchemaExpr
        @test node_type(inline) == "Schema"
        @test inline.name.node.names[1].node == "Person"
        @test length(inline.config.node.items) == 2
    end

    @testset "Arguments keeps its positional nulls" begin
        # `Arguments.defaults` and `ty_list` are `Vec<Option<...>>`: the same
        # length as `args`, with a null for every parameter that has neither a
        # default nor an annotation. The nulls occupy a slot and must survive.
        plain = _assigned_value("lambda_plain")
        @test plain isa LambdaExpr
        # `lambda { a }` has no parameter list at all, so `args` is null.
        @test plain.args === nothing
        @test length(plain.body) == 1
        # A lambda body is `Vec<NodeRef<Stmt>>`, not a list of expressions.
        @test plain.body[1].node isa ExprStmt

        args = _assigned_value("lambda_expr").args.node
        @test length(args.args) == 1
        @test args.args[1].node.names[1].node == "p"
        @test length(args.defaults) == 1
        @test isnothing(args.defaults[1])
        @test length(args.ty_list) == 1
        @test args.ty_list[1].node.name == "Int"
    end

    @testset "a number literal carries a nested tagged value" begin
        # `NumberLitValue` is its own `tag + content` enum, so `value` is
        # {"type": "Int", "value": 1} and not a bare number.
        lit = _assigned_value("lit_int")
        @test lit isa NumberLit
        @test lit.value_tag == "Int"
        @test lit.value == 1
        @test lit.binary_suffix === nothing
        @test _assigned_value("lit_float").value_tag == "Float"
        @test _assigned_value("lit_name") isa NameConstantLit
        @test _assigned_value("lit_name").value == "True"
        @test _assigned_value("lit_str") isa StringLit
        @test _assigned_value("lit_long").is_long_string
        joined = _assigned_value("joined")
        @test joined isa JoinedString
        @test any(v -> v.node isa FormattedValue, joined.values)
    end

    @testset "a target's paths are MemberOrIndex, both arms" begin
        # `MemberOrIndex` is the one `tag + content` enum inside the AST: its
        # `value` is itself a `NodeRef`, so the arm has to be unwrapped before
        # the tagged `Expr` decoder can see it.
        dotted = _target_with_paths("x", 2)
        @test dotted.paths[1] isa Member
        @test dotted.paths[1].member.node == "name"
        @test dotted.paths[2] isa Member
        @test dotted.paths[2].member.node == "deep"

        indexed = _target_with_paths("x", 1)
        @test indexed.paths[1] isa Index
        @test indexed.paths[1].index.node isa NumberLit
        @test indexed.paths[1].index.node.value == 0
        @test indexed.paths[1].index.pos.line == 67
    end

    @testset "every node carries its source position" begin
        @test all(ref -> ref.pos !== nothing, ALIGNMENT.body)
        @test all(ref -> ref.pos.filename == "testdata/ast/alignment.k", ALIGNMENT.body)
        person = only(filter(r -> r.node isa SchemaStmt &&
                                   r.node.name.node == "Person", ALIGNMENT.body))
        @test person.pos.line == 32
        @test person.pos.column == 0
        @test person.pos.end_line > person.pos.line
    end

    @testset "an index signature is a statement in the schema body" begin
        # `SchemaIndexSignature` is a plain struct, and it is a `NodeRef` of
        # the schema body rather than part of the `schema` header.
        bag = _schema_named("Bag")
        @test bag.index_signature !== nothing
        @test bag.index_signature.node.key_name.node == "k"
        @test bag.index_signature.node.key_ty.node isa BasicType
        @test bag.index_signature.node.key_ty.node.name == "Str"
        @test bag.index_signature.node.value_ty.node.name == "Int"
        @test bag.index_signature.node.any_other == false
        @test bag.index_signature.node.value.node isa NumberLit
        @test bag.args === nothing
    end

    @testset "an import is flat" begin
        # `path` and `asname` are `Node<String>` with their own positions;
        # `rawpath`, `name` and `pkg_name` are plain strings on the same node.
        plain = _import(nothing)
        @test plain.rawpath == "data.cloud"
        @test plain.name == "cloud"
        @test plain.pkg_name == "__main__"
        @test plain.as_name === nothing
        @test plain.path.node == "data.cloud"
        @test plain.path.pos.line == 16
        aliased = _import("fb")
        @test aliased.rawpath == "foo.bar"
        @test aliased.name == "fb"
        @test aliased.as_name.node == "fb"
        @test aliased.path.pos.line == 17
    end

    @testset "config entries round-trip operation and shorthand" begin
        config = _assigned_value("config")
        @test config isa ConfigExpr
        @test length(config.items) == 2
        @test [i.node.operation for i in config.items] == ["Override", "Union"]
        @test config.items[1].node.key.node isa IdentifierExpr
        # `is_shorthand` is `skip_serializing_if = "is_false"`, so the key is
        # absent on the wire when false and the decoder reproduces the default.
        @test all(i -> i.node.is_shorthand == false, config.items)
        shorthand = _assigned_value("config_shorthand")
        @test all(i -> i.node.is_shorthand, shorthand.items)
        @test shorthand.items[1].node.key.node isa IdentifierExpr
        # A shorthand entry repeats its key as the value.
        @test shorthand.items[1].node.value.node isa IdentifierExpr
        @test shorthand.items[1].node.value.node.identifier.names[1].node == "lit_int"
        # A `{a = 1, b: 2}` merges with `<<>>`-style union semantics on the
        # second entry, and `ConfigIfEntry` nests an untagged item list.
        config_if = _assigned_value("config_if")
        @test config_if.items[1].node.key === nothing
        @test config_if.items[1].node.value.node isa ConfigIfEntryExpr
    end

    @testset "a quantifier and a dict comp walk their untagged clauses" begin
        quant = _assigned_value("quant")
        @test quant isa QuantExpr
        @test quant.op == "All"
        @test [n.node.names[1].node for n in quant.variables] == ["v"]
        dict_comp = _assigned_value("dict_comp")
        @test dict_comp isa DictComp
        # A `DictComp` has exactly one `entry: ConfigEntry` - not a
        # key/value/entry-key triple.
        @test dict_comp.entry.key.node isa IdentifierExpr
        @test dict_comp.entry.value.node isa IdentifierExpr
        @test dict_comp.entry.value.node.identifier.names[1].node == "v"
        @test length(dict_comp.generators) == 1
        @test length(dict_comp.generators[1].node.targets) == 2
        @test length(dict_comp.generators[1].node.ifs) == 0
    end

    @testset "a slice is lower/upper/step, not index" begin
        plain = _assigned_value("subscript")
        @test plain isa Subscript
        @test plain.index.node isa NumberLit
        @test plain.lower === nothing
        @test plain.upper === nothing
        sliced = _assigned_value("subscript_slice")
        @test sliced isa Subscript
        @test sliced.index === nothing
        @test sliced.lower.node.value == 0
        @test sliced.upper.node.value == 2
        @test sliced.step === nothing
        stepped = _assigned_value("subscript_step")
        @test stepped.step.node.value == 1
    end
end

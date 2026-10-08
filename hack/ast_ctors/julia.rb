# frozen_string_literal: true

# Constructors for the Julia binding.
#
# `julia/src/ast.jl` is hand-written, and unlike Kotlin's `AstBuild.kt` — the
# form this checker was built around — it has no builder layer at all. It does
# not need one: in Julia a `struct`'s generated inner constructor *is* its
# constructor. `SchemaStmt(doc, name, parent_name, …)` is both what a caller
# writes and what `stmt_from_wire` calls at ast.jl:1019, so a node's parameters
# are its fields, in declaration order, and this collector is a parse of the
# field declarations rather than a scan for call syntax — the same argument
# `check_python` makes about a dataclass's generated `__init__` and `check_go`
# makes about a keyed composite literal.
#
#   julia> fieldnames(KclLib.SchemaStmt)
#   (:doc, :name, :parent_name, :for_host_name, :is_mixin, :is_protocol,
#    :args, :mixins, :body, :decorators, :checks, :index_signature)
#
# That was read at runtime rather than trusted off the page: `using KclLib`
# under `julia --project=julia`, then `fieldnames` and `methods` for all 65
# structs. `methods` is what settled the two questions below that a regex would
# have guessed at — every struct is `Base.@kwdef`, and exactly one struct has an
# outer constructor.
#
# The `@kwdef` layer is this binding's answer to rule 1, and `defaulted` means
# what it says there:
#
#   * Every node struct is declared `Base.@kwdef`, which generates a keyword
#     constructor alongside the positional one. The positional inner constructor
#     is untouched — `stmt_from_wire` still builds every node positionally — so
#     a node's parameters are still its fields, in declaration order.
#   * A field whose `ast.rs` counterpart is a `Vec<`, `Option<Vec<`, `HashMap<`
#     or `Option<HashMap<` carries the empty collection as its default:
#     `Vector{…} = X[]`, and `Union{Vector{…},Nothing} = nothing` for the
#     `Option<Vec<…>>` case, where `nothing` is the empty spelling of the
#     union. Such a field lands in `defaulted`.
#   * Nothing else is omittable. A scalar and a required node reference stay
#     required keyword arguments: `Keyword.arg::Union{Node{Identifier},Nothing}`
#     has no default, and neither does `Module.filename`. `nothing` is a value
#     the caller passes there, not an omission — a default would let a caller
#     build a node the parser can never produce.
#
# Four shapes decide what counts, and each is a place a naive scan gets it wrong:
#
#   * `struct X … end` — the constructor. Its fields are the parameters, in
#     declaration order. Nearly every struct spells the declaration
#     `Base.@kwdef struct X … end`; the prefix is optional in the scan because
#     `AnyType` and `MissingExpr` stay plain — a unit struct cannot carry a
#     default. A `struct X <: Y … end` carries its supertype after the name
#     and is still a struct; `struct X <: Y end` is a unit struct with no
#     parameters at all, which is how those two are built.
#   * `abstract type X end` is *not* a constructor. `AstType`, `KclExpr`,
#     `KclStmt` and `MemberOrIndex` cannot be instantiated — `methods(KclExpr)`
#     is empty at runtime — so returning one would claim a constructor the
#     binding does not have. They are dropped, and said about here instead.
#   * `const SchemaConfig = SchemaExpr` and `const KclModule = Module` are
#     Julia aliases, one type under a second name: a caller writing
#     `SchemaConfig(…)` is writing `SchemaExpr(…)`. Dropped for the reason
#     `check_go` drops `type X = Y` — `STRUCT_ALIASES` is for a binding that
#     *renames* a struct, and an alias renames nothing.
#   * `Decorator` is not dropped even though it is field-for-field `CallExpr`.
#     Unlike the `const` above it is a genuinely separate Julia type — it exists
#     so `SchemaAttr.decorators` can say it holds an untagged call rather than
#     the tagged `Expr::Call` variant — so it is returned under its own name and
#     arrives in `unmapped`, which is what it is. Dropping it would hide a type
#     the binding has; keeping it costs nothing, since `CallExpr` has its own
#     inner constructor over the same three fields.
#
# Outer constructors are matched against the struct names collected in a first
# pass, which is what keeps `node_type(::CheckExpr) = "Check"` and the six
# call-shaped `*_from_wire` loaders out of the results: they are column-0
# assignments with a call-shaped head, and only a name that is a declared struct
# is a constructor.
#
# Three things this collector does not see, stated here rather than left for a
# reader to assume.
#
#   * `SerializeProgram` (ast.rs:386) has no Julia type. `parse_program_ast`
#     returns `Vector{Module}` after unwrapping the `{"root": …, "pkgs": …}`
#     envelope, so the document a Julia caller receives has no struct to build
#     and `root` never becomes a field. `check_go` reports the same gap for Go
#     for the same reason.
#   * `IntLiteralType` (ast.rs:1909) has no Julia type either, and here the
#     blind spot is the kind the README reserves `WRAPPED_PAYLOADS` for. Kotlin
#     reaches it through `literalIntType`, whose return type is the tagged
#     `LiteralType` wrapper rather than the `Int` payload it fills in — the
#     struct it builds is never named in the signature. Julia has no such
#     function at all: `LiteralType` is modelled verbatim as
#     `LiteralType(value::Any, inner_tag)`, so the `Int` arm's `{value, suffix}`
#     payload is never given a type of its own and there is nothing to register.
#     Neither struct is registered: both are recorded in
#     `check_ast_constructors.rb`'s `NOT_MODELED` table for julia, and the
#     report names them as deliberately not modeled rather than as missing.
#   * `ast.rs` spells two fields differently from this binding, and the join
#     needs a name it does not have: `ImportStmt.as_name` against `pub asname`
#     (ast.rs:681), and `UnionType.types` against `pub type_elements`
#     (ast.rs:1895). The camelCase→snake_case pass is a no-op for both —
#     `as_name` is already snake_case and `types` has no underscore to split —
#     so `PARAM_ALIASES` is where a rename belongs, and Node.js is already in
#     that table for the second pair. The constructor is returned under its
#     best-guess `ast.rs` name either way; `UnionType` will read as unreached
#     because none of its parameters join, which is the honest reading of a
#     field the binding calls something else.

def check_julia(path)
  file = if File.directory?(path)
           candidates = [File.join(path, "ast.jl"), File.join(path, "src", "ast.jl")]
           found = candidates.find { |c| File.exist?(c) }
           abort "check_julia: no ast.jl under #{path} (looked in #{candidates.join(', ')})" if found.nil?
           found
         else
           path
         end
  lines = File.read(file).lines

  # `<`/`>` count as brackets because Julia's generics are angle-bracketed and
  # its own types use `{}`; `->` and `>=` appear in no field declaration or
  # parameter list in this file, which is the same assumption `split_params` in
  # the checker already makes.
  depth = lambda do |text|
    d = 0
    text.each_char { |ch| d += 1 if "<([{".include?(ch); d -= 1 if ">])}".include?(ch) }
    d
  end

  # A `=` at bracket depth 0 is a default — `f(a, b::Int = 1)`. None of this
  # binding's two outer constructors has one; the branch exists because the next
  # one to be written might, and it is the only place a Julia constructor can
  # default a positional parameter at all.
  has_default = lambda do |param|
    d = 0
    param.each_char do |ch|
      case ch
      when "<([{" then d += 1
      when ">])}" then d -= 1
      when "=" then return true if d.zero?
      end
    end
    false
  end

  # Whether a caller may leave the field out, which is what `defaulted` means.
  # `Base.@kwdef` makes the answer purely syntactic: a field is omittable
  # exactly when its declaration carries `= default` at bracket depth 0 —
  # `names::Vector{Node{String}} = Node{String}[]`, or
  # `params_ty::Union{Vector{Node{AstType}},Nothing} = nothing`. Every default
  # in the file is the empty collection (or `nothing`, the empty spelling of an
  # `Option<Vec<…>>` union); a field without one, nullable or not, is a
  # required keyword argument.
  omittable = lambda do |ty, field|
    has_default.call(ty)
  end

  # The index of the `)` closing the call that opens at `open`, so a nested
  # `CallExpr(d::Decorator) = CallExpr(d.func, d.args, d.keywords)` is not cut
  # at its first `)`.
  matching_paren = lambda do |line, open|
    d = 0
    k = open
    while k < line.length
      d += 1 if line[k] == "("
      if line[k] == ")"
        d -= 1
        return k if d.zero?
      end
      k += 1
    end
    nil
  end

  # Every column-0 `struct`, collected before anything is returned so an outer
  # constructor can be attached to a struct declared later in the file and a
  # same-shaped call that is not a constructor (`node_type(::CheckExpr) = …`)
  # can be told from one that is. Julia declares a type with no other spelling,
  # so this is the whole concrete type namespace.
  structs = []
  lines.each do |line|
    m = /\A(?:Base\.@kwdef )?struct (\w+)\b/.match(line)
    structs << m[1] if m
  end

  ctors = []

  i = 0
  while i < lines.length
    line = lines[i]
    header = /\A(?:Base\.@kwdef )?struct (\w+)\b([^\n]*)\n?\z/.match(line)

    if header
      # `struct X <: Y end` closes on its own line; `struct X <: Y … end` does
      # not. Splitting on that is what keeps the two unit structs out of the
      # body scan, where the next column-0 `end` would be some later function's.
      unless /\bend\s*\n?\z/.match?(header[2])
        name = header[1]
        params = []
        defaulted = []
        pending = nil
        j = i + 1

        # Every line in the block has to be a field, a comment or blank:
        # anything else aborts, which is what turns a `struct` whose `end` was
        # renamed into a loud failure instead of a parse that quietly swallowed
        # the rest of the file. A field annotation that wraps onto the next line
        # is the one thing that makes a field span lines, and unbalanced
        # brackets are how Julia spells it, so the depth is tracked per field
        # rather than per line.
        while j < lines.length && !/\Aend\b/.match?(lines[j])
          raw = lines[j]
          j += 1
          next if raw.strip.empty? || raw.lstrip.start_with?("#")

          if pending
            pending[1] << " " << raw.strip
          elsif (m = /\A[ \t]+(\w+)::(.*)\n?\z/.match(raw))
            pending = [m[1], +m[2].strip]
          else
            abort "check_julia: cannot read this line of `struct #{name}` as a field: #{raw.strip} (#{file}:#{j})"
          end

          next unless depth.call(pending[1]).zero?

          params << pending[0]
          defaulted << pending[0] if omittable.call(pending[1], "#{name}.#{pending[0]}")
          pending = nil
        end

        # A field whose annotation never closed is a parse that lost its default,
        # not one that has none. Recording it as required is the loud reading:
        # it can make rule 1 fire on a field that was in fact defaulted, and it
        # cannot hide one that was not.
        abort "check_julia: `struct #{name}` (#{file}:#{i + 1}) has an unterminated field declaration: #{pending[0]}" if pending

        ctors << [name, params, defaulted]
        i = j
      else
        ctors << [header[1], [], []]
      end

    elsif /\Aconst (\w+) = (\w+)\s*\n?\z/.match(line)
      # An alias renames nothing, so the struct it points at is already in
      # `ctors` under the name `ast.rs` uses. A `const` that is not one is a
      # type declaration this scan would otherwise drop in silence.
      m = /\Aconst (\w+) = (\w+)\s*\n?\z/.match(line)
      abort "check_julia: #{file}:#{i + 1} is a `const` that is not a plain alias: #{line.strip}" unless structs.include?(m[2])

    elsif /\A(\w+)\(/.match(line) && structs.include?(Regexp.last_match(1))
      # An outer constructor. `CallExpr(d::Decorator)` is the only one in the
      # file, and it is returned: `compare` judges a struct over the union of
      # its constructors, so a convenience that forwards is free and one that
      # is dropped is a field reported unreachable that is in fact reachable.
      m = /\A(\w+)\(/.match(line)
      open = line.index("(")
      close = matching_paren.call(line, open)

      # Only the value half of the definition: `f(a, b) = …` is a constructor,
      # `f(a, b)::X` alone is not one.
      if close && /\A\s*(?:::[^=]*)?=/.match?(line[(close + 1)..])
        op = split_params(line[(open + 1)...close])
        named = ->(p) { p[/\A\w+/] }
        ctors << [m[1], op.map(&named), op.select { |p| has_default.call(p) }.map(&named)]
      end
    end

    i += 1
  end

  ctors
end
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
# have guessed at — there is no keyword constructor anywhere in the binding, and
# exactly two structs have an outer constructor.
#
# What `defaulted` means here is the one place Julia's answer is not a
# precedent, so it is spelled out rather than left to be inferred:
#
#   * There is no `@kwdef` and no keyword constructor in `ast.jl`, so a `struct`
#     has exactly one inner constructor and it takes every field, positionally.
#     No field of any struct has a default value.
#   * `Union{Node{KclExpr},Nothing}` is nonetheless the README's "a nullable
#     type" — the exact item on its list — and in Julia it is the language's own
#     spelling of "absent": a caller leaves such a field out by passing
#     `nothing`, and Julia stores that as the field's undefined value rather
#     than as data. So a nullable field lands in `defaulted` and nothing else
#     does.
#   * A `Vector{…}` field is *not* omittable. Julia has no zero-value fill:
#     `SchemaStmt(nothing, name, nothing, nothing, false, false, nothing,
#     Identifier[], KclStmt[], Decorator[], CheckExpr[], nothing)` is what a
#     caller writes for a schema with no body, and there is no shorter spelling.
#     That is a real ergonomics gap and rule 1 exists to say so, so it is left
#     to fire rather than softened with a default the language does not have.
#
# Four shapes decide what counts, and each is a place a naive scan gets it wrong:
#
#   * `struct X … end` — the constructor. Its fields are the parameters, in
#     declaration order. A `struct X <: Y … end` carries its supertype after the
#     name and is still a struct; `struct X <: Y end` is a unit struct with no
#     parameters at all, which is how `AnyType` and `MissingExpr` are built.
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
#     Neither struct is registered, so both stay in the report's missing list.
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
  # Two shapes answer yes and they are not the same shape:
  #
  #   * `Union{X,Nothing}` — the field itself is nullable, so `nothing` is what
  #     a caller passes when there is nothing to pass. Julia's spelling of the
  #     README's "a nullable type", and the whole of it: the union has to be the
  #     *outermost* type, so `Union{Vector{…},Nothing}` counts and
  #     `Vector{Union{…,Nothing}}` does not.
  #   * `Vector{Union{…,Nothing}}` — the field is a list and it is *required*.
  #     The nulls are per element and they line up positionally with a sibling
  #     list (`Arguments.defaults` and `ty_list` against ast.rs:1356's
  #     `Vec<Option<NodeRef<Expr>>>`), so a caller still has to pass the vector;
  #     `[]` is its empty spelling, not an omission. Reading the `Nothing` here
  #     as an omission would let rule 1 pass on a field nobody can leave out.
  #
  # A `Nothing` anywhere else is a spelling this scan has not seen, and reading
  # it as either would be a guess in one direction or the other, so it aborts.
  omittable = lambda do |ty, field|
    return false unless /\bNothing\b/.match?(ty)

    if ty.start_with?("Union{")
      # Depth 1 is the union's own brace; the scan starts *inside* it and is
      # asking whether that brace is the last thing in the type, i.e. whether
      # the nullable union is the whole field and not an element of a list.
      d = 1
      ("Union{".length...ty.length).each do |k|
        d += 1 if "<([{".include?(ty[k])
        d -= 1 if ">])}".include?(ty[k])
        break if d.zero?
      end
      abort "check_julia: #{field} is nullable in a way this scan does not model: #{ty}" unless d.zero?
      true
    elsif ty.start_with?("Vector{Union{")
      false
    else
      abort "check_julia: #{field} is nullable in a way this scan does not model: #{ty}"
    end
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
    m = /\Astruct (\w+)\b/.match(line)
    structs << m[1] if m
  end

  ctors = []

  i = 0
  while i < lines.length
    line = lines[i]
    header = /\Astruct (\w+)\b([^\n]*)\n?\z/.match(line)

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
      # An outer constructor. `Identifier()` (ast.jl:197) and
      # `CallExpr(d::Decorator)` (ast.jl:507) are the only two in the file, and
      # both are returned: `compare` judges a struct over the union of its
      # constructors, so a convenience that forwards is free and one that is
      # dropped is a field reported unreachable that is in fact reachable.
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
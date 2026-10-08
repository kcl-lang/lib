# frozen_string_literal: true

# Constructors for the C++ binding.
#
# The C++ AST is hand-written and lives in one header, `cpp/include/kcl_ast.hpp`
# — no generator, no `.gen` files, no second file a node is split across. The
# directory around it is not walked on purpose: `kcl_facade.hpp` declares
# `Options`, `KclResult` and `Kcl`, and `kcl_ast_json.hpp` declares a small JSON
# parser, none of which is a node, so a glob over `cpp/include` would report
# constructors for a command-line options struct.
#
# What a C++ caller has
# ---------------------
# None of the three shapes a binding usually offers. There are no builder
# methods and no constructor with default arguments anywhere in the header —
# the one `explicit` constructor in it is `AstError`'s, and this collector
# returns a triple for that too rather than filtering it out by name, because
# it is the evidence for the claim below: if a node type declared a
# constructor, it would show up here the same way.
#
# What a caller has instead is C++'s implicit default constructor plus public
# data members, which is the same route Go's keyed struct literal provides:
#
# ```cpp
# kcl::ast::CallExpr call;
# call.func = ...;
# call.args = {a, b};
# ```
#
# `defaulted` is that default constructor, and it is why every answer here is
# "every member": because no AST type declares a constructor, `T x;` compiles
# for all of them and fills every member in — `{}` for a `std::vector`, a null
# `shared_ptr`, an empty `optional`, and the in-class initialiser's `0` for a
# `long long`. Rule 1 therefore cannot fire, which is the right outcome:
# `args: {}` is not something a caller should have to spell at every level of
# the tree.
#
# The aggregate rule the other bindings do not have
# --------------------------------------------------
# Brace initialisation is a second route, and it is narrower: C++ omits only
# *trailing* members, so `Pos{"main.k"}` sets `filename` and leaves `line`,
# `column`, `end_line` and `end_column`, while reaching `column` costs
# `Pos{"main.k", 1, 1}` — the members before it have to be spelled even when
# they are not the ones being set. That restriction decides nothing here,
# because the default constructor already lets a caller skip *any* member.
# Which is why this is the one binding where `defaulted` is not "the trailing
# run of parameters" the way an aggregate-only language would read it: no
# member is ever required, not just the tail.
#
# And the restriction is mostly moot in practice: 53 of the 68 types the
# header declares are not aggregates at all. `Expr`, `Stmt` and `Type` each
# declare a pure virtual `tag()`, so every class deriving from them has
# virtual functions, which [dcl.init.aggr]/1 rules out in C++17 — for those,
# `CallExpr call{...}` does not compile ("no matching constructor") and
# default construction is the *only* route a caller has. The 15 that are
# aggregates are the ones with no base class at all. The collector records
# the members either way, because a caller writing `call.func = ...` is
# passing a value named `func`, which is the question this checker asks.
#
# The three abstract roots are the one thing dropped here, and by rule rather
# than by name: a class with a pure virtual function has no constructor a
# caller can invoke, so `Expr`, `Stmt` and `Type` produce no triple. They name
# no struct in `ast.rs` either — they are the `Stmt` (ast.rs:573), `Expr`
# (ast.rs:852) and `Type` (ast.rs:1858) enums — so returning them could only
# have added a zero-argument "constructor" claim that is false.
#
# What this collector does not see, stated rather than assumed:
#
#   * `SerializeProgram` (ast.rs:386) has no C++ type at all.
#     `parse_program_json` returns `std::vector<Module>` after accepting either
#     a bare array or the `{"root":…, "pkgs":{…}}` envelope, so the document a
#     caller receives has no struct to build and `root` is dropped on the
#     floor — the same gap Go's `ParseProgram` has.
#   * `IntLiteralType` (ast.rs:1909) is the one ast.rs struct with a payload
#     that reaches a C++ caller only through a tagged wrapper. `Type::Literal`
#     is `{"type":"Literal","value":{"type":"Int","value":{…}}}` and the header
#     models the inner tag+content enum as one `LiteralValue` struct with a
#     `kind` discriminator, so `suffix` keeps its name and `value` arrives as
#     `int_value` under `kind == Kind::Int` — reachable, but never as the
#     struct that declares them. This is the blind spot `WRAPPED_PAYLOADS`
#     exists for: `IntLiteralType` appears zero times under `cpp/`, so there is
#     no function whose return type or body names it and nothing to register.
#     `SerializeProgram` and `IntLiteralType` are both recorded in
#     `check_ast_constructors.rb`'s `NOT_MODELED` table for cpp, and the report
#     names them as deliberately not modeled rather than as missing.
#   * `Decorator`, `SchemaConfig`, `TargetExpr`, `IdentifierExpr`,
#     `KeywordExpr` and `ArgumentsExpr` are C++ names for payloads `ast.rs`
#     reaches under another name (`CallExpr`, `SchemaExpr`, `Target`,
#     `Identifier`, `Keyword`, `Arguments`), and `AnyType`, `BasicType`,
#     `NamedType`, `LiteralType`, `LiteralValue`, `MemberOrIndex` and
#     `NumberLitValue` are C++ names for `ast.rs` *enums* — `Type`
#     (ast.rs:1858), `BasicType` (ast.rs:1876), `LiteralType` (ast.rs:1901),
#     `Literal` (ast.rs:1400), `MemberOrIndex` (ast.rs:950) and
#     `NumberLitValue` (ast.rs:1464). All fourteen are returned under their own
#     names and land in the report's `unmapped` list, which is what they are.
#     Each one's ast.rs counterpart is reachable in its own right — `CallExpr`
#     and `SchemaExpr` are separate C++ classes, and an enum has no struct to
#     reach — so no `STRUCT_ALIASES` entry is needed for coverage; a rename
#     table here would be a claim about vocabulary, not about a gap.

def check_cpp(path)
  # One header, named rather than globbed — see the note above.
  header = File.directory?(path) ? File.join(path, "kcl_ast.hpp") : path
  raise "check_cpp: no such header: #{header}" unless File.exist?(header)

  src = File.read(header)
  # Comments and string literals go before anything is counted. The file
  # comment quotes wire documents (`{"type":"Call","func":…}`) and the decoder
  # bodies build strings, so brace matching or member scanning over the raw
  # text would start and stop in the wrong place on both.
  src = src.gsub(%r{/\*.*?\*/}m, " ").gsub(%r{//[^\n]*}, " ")
  src = src.gsub(/"(?:\\.|[^"\\])*"/, '""')

  # One class body, split into the declarations it holds. Brace depth does the
  # work a line-oriented scan cannot: a member function body and an
  # `enum class {…}` both contain `;` and `}` that belong to neither, and
  # `Identifier::name()` declares a local `std::string out;` that is a member
  # of no type at all.
  declarations = lambda do |body|
    out = []
    buffer = +""
    depth = 0
    body.each_char do |ch|
      case ch
      when "{"
        depth += 1
        buffer << ch
      when "}"
        depth -= 1
        buffer << ch
        # A definition with a body has no trailing `;`, so the closing brace
        # of the innermost block ends the declaration.
        if depth.zero?
          out << buffer.strip
          buffer = +""
        end
      when ";"
        if depth.zero?
          out << buffer.strip
          buffer = +""
        else
          buffer << ch
        end
      else
        buffer << ch
      end
    end
    out << buffer.strip unless buffer.strip.empty?
    out
  end

  ctors = []
  seen = {}

  # `enum class ExprContext {` and the three nested `enum class Kind {` blocks
  # would otherwise reach this scan as classes — `class` is a word inside
  # `enum class`, and `enum` is the word in front of it.
  src.scan(/\b(?:class|struct)\s+(\w+)\s*[^{;]*\{/) do
    decl = Regexp.last_match
    name = decl[1]
    prefix = src[0...decl.begin(0)]
    next if prefix.match?(/(?:\A|[^\w])enum\s\z/)

    # Two definitions of one name do not compile, so a repeat is the same type
    # reached twice; `compare` unions a struct's constructors anyway.
    next if seen.key?(name)
    seen[name] = true

    body = +""
    depth = 0
    index = decl.end(0) - 1
    while (ch = src[index])
      body << ch
      depth += 1 if ch == "{"
      if ch == "}"
        depth -= 1
        break if depth.zero?
      end
      index += 1
    end
    raise "#{header}: the body of `#{name}` does not close" unless depth.zero?

    params = []
    defaulted = []
    abstract = false

    declarations.call(body[1...-1]).each do |decl|
      text = decl.gsub(/\s+/, " ").strip
      # `public:` is glued to the declaration that follows it on the next line.
      text = text.sub(/\A(?:public|private|protected)\s*:\s*/, "")
      next if text.empty?
      next if text.match?(/\A(?:enum|union|using|typedef|template|friend|static_assert)\b/)
      # A pure virtual function makes the class abstract: there is no `T x;`
      # a caller can write, so there is no constructor to return. The splitter
      # above consumes the `;`, so the `= 0` runs to the end of the text.
      if text.match?(/\bvirtual\b.*=\s*0\s*\z/)
        abstract = true
        next
      end

      # A `(` in the declarator is a function. No data member in this header
      # has one — `std::vector<std::optional<ExprRef>> defaults;` has brackets
      # and no parentheses — and a function definition keeps its body, so the
      # test holds for both the declared and the defined forms.
      if text.include?("(")
        ctor = text[/\A(?:explicit\s+|constexpr\s+|inline\s+)*#{name}\s*\(/]
        next if ctor.nil?

        # A real constructor supersedes the members: it replaces the implicit
        # default one, so `defaulted` has to come from its default arguments
        # and not from `T x;`. No AST type takes this branch — `AstError` is
        # the header's only constructor — but it is what keeps the reading of
        # "every member is optional" honest if one is ever added.
        #
        # The parameter list runs from the opening parenthesis to the one that
        # balances it: a constructor carries a member-initializer list after it
        # (`AstError(…) : std::runtime_error(message)`) which is not a
        # parameter.
        open = text.index("(")
        close = open
        inner = 0
        while (ch = text[close])
          inner += 1 if ch == "("
          if ch == ")"
            inner -= 1
            break if inner.zero?
          end
          close += 1
        end
        list = text[(open + 1)...close].to_s
        pieces = []
        depth = 0
        current = +""
        list.each_char do |ch|
          case ch
          when "(", "<", "[", "{" then depth += 1
          when ")", ">", "]", "}" then depth -= 1
          when ","
            if depth.zero?
              pieces << current
              current = +""
              next
            end
          end
          current << ch
        end
        pieces << current

        pieces.map(&:strip).reject(&:empty?).each do |piece|
          arg = piece[/\b(\w+)\s*(?:=|\z)/, 1] || piece[/\b(\w+)\s*\z/, 1]
          raise "#{header}: cannot read this parameter of `#{name}`: #{piece}" if arg.nil?

          params << arg
          # C++ only lets a caller leave a *trailing* argument out, so an `=`
          # anywhere in the list is the whole story — a default in front of a
          # required argument is a declaration no compiler accepts.
          defaulted << arg if piece.include?("=")
        end
        next
      end

      # A data member: the declarator-id is the last word before the initialiser.
      left = text.split("=", 2).first.to_s.strip
      field = left[/(\w+)\s*\z/, 1]
      raise "#{header}: cannot read this line of `#{name}` as a declaration: #{decl.strip}" if field.nil?

      params << field
      # Nothing in `kcl::ast` declares a constructor, so `T x;` compiles for
      # every type here and fills every member in — which is what makes a
      # `std::vector` field omittable rather than something a caller has to
      # spell as `{}` at every level of the tree.
      defaulted << field
    end

    next if abstract

    ctors << [name, params, defaulted]
  end

  ctors
end

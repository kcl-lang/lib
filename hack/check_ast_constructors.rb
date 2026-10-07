# frozen_string_literal: true

# Cross-check every binding's AST *constructors* against the Rust struct
# definitions in ../../kcl/crates/ast/src/ast.rs.
#
# `check_ast_field_types.rb` already holds every binding to the wire shape of
# its AST DTOs: every field of every struct is read with the right decoder. That
# leaves one question it cannot ask, which is the one a caller actually runs
# into — *how do I build a node?* A DTO whose fields are all required is
# mechanically correct and ergonomically useless: constructing a
# `NodeRef<Identifier>` means spelling five position fields at every level of
# the tree, which is what `kotlin/.../AstBuild.kt` exists to stop.
#
# So this checker holds each binding to three things, per node struct in
# `ast.rs`:
#
#   1. a constructor exists;
#   2. every field of the struct is reachable through it, by name;
#   3. the constructor's parameters correspond to fields `ast.rs` declares —
#      a parameter with no field behind it is drift in the other direction, and
#      is how a binding ends up shipping a constructor the core never calls.
#
# Rule 2 is the one with teeth. A constructor that covers only some of a
# struct's fields cannot build a fully-populated node, and the case nobody
# writes a test for is the one field that was forgotten.
#
# Every rule lives in `compare`, applied to whatever a per-language collector
# produces, so a binding cannot be held to a laxer standard than its neighbours
# by accident. A collector only has to answer one question per constructor:
# which Rust struct does this build, and what are its parameters called.
#
# A collector that stops matching reports success, which is worse than
# useless, so every run prints how many constructors it actually compared and
# which structs it never reached, and refuses to call zero "ok".
# `test_check_ast_constructors.rb` breaks the constructors on purpose and
# asserts the rules fire.
#
# Usage: ruby hack/check_ast_constructors.rb [binding ...]

# The struct definitions live in the `kcl` repo, which sits *next to* this one
# rather than inside it. CI checks both out side by side, which is not the
# layout this default assumes, so the path is overridable — and a wrong one has
# to be loud. Comparing against an empty set of structs passes every rule.
AST_RS = ENV.fetch("KCL_AST_RS") { File.expand_path("../../kcl/crates/ast/src/ast.rs", __dir__) }
abort "ast.rs not found at #{AST_RS} - set KCL_AST_RS to the kcl repo's crates/ast/src/ast.rs" \
  unless File.exist?(AST_RS)

# ---------------------------------------------------------------------------
# Parse the Rust source into {StructName => {field => type}}
# ---------------------------------------------------------------------------

STRUCTS = {}
File.read(AST_RS).scan(/pub struct (\w+) \{(.*?)\n\}/m) do |name, body|
  STRUCTS[name] = body.scan(/pub (\w+): ([^,\n]+),/).to_h { |f, t| [f, t.strip] }
end
# `pub struct MissingExpr;` — a unit struct with no body, so the scan above
# cannot see it. It is the payload of `Expr::Missing`, so it is a node type and
# a constructor has to exist for it; it simply has no fields to cover.
STRUCTS["MissingExpr"] ||= {}

# The four structs that are AST infrastructure rather than nodes a caller
# builds. `Pos` is a position, `AstIndex` is a byte range, `Node<T>` is the
# wrapper every node travels in, and `Spanned` is a blanket trait. Demanding a
# constructor for the wrapper would be demanding a constructor for
# `NodeRef<Identifier>` and `NodeRef<String>` under the same name, which is
# exactly the ambiguity the bindings resolve by suffix (`nodeRef` / `nodeStr`).
NOT_NODES = %w[Pos AstIndex Node Spanned].freeze

# Every struct a caller can build: the AST nodes plus the four top-level
# messages the loader hands back. `Program` and `SerializeProgram` are what
# `parseProgram` returns, `Module` is what `parseModule` returns, so they are
# as much a caller-facing constructor target as `BinaryExpr` is.
NODE_TYPES = (STRUCTS.keys - NOT_NODES).sort.freeze

# ---------------------------------------------------------------------------
# Coverage bookkeeping
# ---------------------------------------------------------------------------

# How many constructors each checker actually compared, and which structs it
# reached versus actually judged. The difference is the gap list, and computing
# it as a set difference rather than a running delete keeps it free of ordering
# artefacts: a struct reached twice, once with fields and once delegating, is
# covered.
COMPARED = Hash.new(0)
# `h[k] = []` and not just `[]`: a default block that returns a fresh array
# without storing it hands every caller a new list, so every append is lost and
# the coverage report comes back empty while the rules still pass.
REACHED = Hash.new { |h, k| h[k] = [] }
CHECKED = Hash.new { |h, k| h[k] = [] }

# Constructors the collector found that map to no struct in `ast.rs`, and
# constructors that map to a struct but set none of its fields — `memberOrIndexOf`
# and `argumentsOf` are conveniences over a real constructor, not constructors
# of their own. Like the unresolved counter in the field checker, `compare` has
# to treat both as "nothing to say", which is the right default and a terrible
# place to be wrong: a collector whose naming table has stopped matching its own
# source reports every constructor as a helper and the binding comes out clean.
# Counting them makes that visible.
UNMAPPED = Hash.new { |h, k| h[k] = [] }

# The one place a binding says "these two names mean the same field". A binding
# is free to rename a field — idiomatics are binding-local — but a rename costs
# the join this checker is built on, so it has to be written down somewhere a
# reviewer will see it rather than inferred. Every entry is a constructor
# parameter name that is *not* a field of `ast.rs` but does set one.
#
# Kotlin's `unionType(elements)` sets `type_elements`, and `UnionType`'s own DTO
# field is `typeElements`; `elements` is the ergonomic spelling the constructor
# takes. Nothing else is allowed in here without the same justification: an
# entry that hides a field nobody can set is worse than the failure it silences.
PARAM_ALIASES = {
  "kotlin" => { "elements" => "type_elements" }
}.freeze

# ---------------------------------------------------------------------------
# The rules
# ---------------------------------------------------------------------------

# A node-shaped field is one holding a child node, a list of them, or an
# optional of either. The same predicate `check_ast_field_types.rb` uses to
# decide which fields its two rules can say anything about, and for the same
# reason: `String`, `bool` and the enum leaves have obvious literals, so a
# constructor that requires one is asking for a value, not for ceremony.
NODE_SHAPED = /\A(?:Option<)?(?:Node|NodeRef|Vec|Option<Vec)/

# Bindings spell a field in their own language's convention — `ifCond`,
# `if_cond`, `IfCond`, `if_cond`, `ifCond` — so a constructor parameter is
# matched to a Rust field by exact name first, by the binding's declared alias
# second, and by convention third. The convention fallback is one pass of the
# standard camelCase split, which is enough because `ast.rs` is snake_case
# throughout and every binding derives from it.
def rust_field_for(lang, param, rust)
  return param if rust.key?(param)

  aliased = PARAM_ALIASES.dig(lang, param)
  return aliased if aliased && rust.key?(aliased)

  snake = param.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
  rust.key?(snake) ? snake : nil
end

# A constructor is `{struct, params, defaulted}`:
#
#   struct     — the Rust node struct it builds, or nil when the collector could
#                not name one
#   params     — the parameter names, in declaration order, with any `type: T`
#                annotation or `= default` suffix already stripped
#   defaulted  — the subset of `params` a caller may omit: the parameters with
#                a default value, or marked optional. Rule 1 uses it.
#
# A struct is judged once, over the *union* of its constructors, because that
# is the question a caller asks: "can I build a full `NumberLit`?" — not "can
# this one overload?". Kotlin answers it by splitting the job across
# `numberLit(value, binarySuffix)` and the `intNumberLit(value)` shortcut that
# delegates to it, and judging either one alone reports a field uncovered that
# is in fact covered. Overloads are common; a struct with no reachable route to
# a field is not.
def compare(lang, ctors)
  problems = []
  by_struct = Hash.new { |h, k| h[k] = [] }

  ctors.each do |struct, params, defaulted|
    struct = STRUCT_ALIASES.dig(lang, struct) || struct
    # A struct `ast.rs` does not declare is a helper, not a node — `nodeRef`
    # returns a `NodeRef<T>`, `basicIntType` returns one arm of the `Type`
    # content-tagged enum, which has no struct of its own. Counting it as
    # coverage of nothing is the honest reading, and it is why the report prints
    # the ones a collector could not place at all.
    if struct.nil? || !STRUCTS.key?(struct)
      UNMAPPED[lang] << (struct || params.first)
      next
    end
    by_struct[struct] << [params, defaulted]
  end

  by_struct.each do |struct, group|
    rust = STRUCTS[struct]
    settable = group.flat_map { |params, _| params.filter_map { |p| rust_field_for(lang, p, rust) } }.uniq

    # A constructor that sets none of the struct's fields is a convenience over
    # a real one — `argumentsOf(vararg names)` builds `Arguments` from names,
    # it does not take `args`/`defaults`/`ty_list`. It is not evidence the
    # struct is buildable, so it is not recorded as reaching it: a struct whose
    # only constructors are helpers belongs in the report's missing list, which
    # is the failure a caller would hit.
    #
    # A struct with no fields at all is the other case, and the opposite one:
    # `MissingExpr` has none, so `missingExpr()` takes no parameters and is
    # still the only way to build it.
    real = group.select { |params, _| params.any? { |p| rust_field_for(lang, p, rust) } || rust.empty? }
    next if real.empty?

    REACHED[lang] << struct
    CHECKED[lang] << struct

    # Rule 2: every field of the struct is settable through some constructor.
    uncovered = rust.keys - settable
    unless uncovered.empty?
      problems << "#{struct}: no constructor sets #{uncovered.join(', ')} " \
                  "— a caller cannot build a fully-populated node"
    end

    # Rule 3: every parameter is a field the core declares. A parameter naming
    # nothing in `ast.rs` at all is drift in the other direction — a constructor
    # the core has no field for. `KNOWN_HELPERS` covers the two answers that
    # are not fields of the node: where it is (the position shorthand) and
    # which spelling of the tag it carries.
    #
    # Judged per constructor, and only for one that sets a field of *this*
    # struct: a convenience like `argumentsOf(vararg names)` takes the fields of
    # an `Identifier` and forwards them to the real `arguments(…)`, so holding
    # its parameters against `Arguments` would flag every convenience overload
    # in every binding.
    group.each do |params, _|
      next if params.none? { |p| rust_field_for(lang, p, rust) }

      unknown = params.reject { |p| KNOWN_HELPERS.include?(p) || rust_field_for(lang, p, rust) }
      next if unknown.empty?

      problems << "#{struct}: constructor parameter #{unknown.join(', ')} " \
                  "names no field of the struct in ast.rs"
    end

    # Rule 1: a list field must never be a *required* parameter. Rust writes a
    # `Vec` field as `[]` when it is empty — the field is never absent — so a
    # constructor demanding one is making the caller type an empty collection at
    # every level of the tree, which is the ceremony this file exists to catch.
    #
    # A required `Option<NodeRef<T>>` is deliberately not included: `Keyword.arg`
    # and `ListType.inner_type` are children a node cannot exist without, and a
    # default that let a caller omit them would build a node the parser can never
    # produce. Asking for a child is asking for a value; asking for `[]` is not.
    forced_lists = group.flat_map { |params, defaulted| (params - defaulted).filter_map { |p| rust_field_for(lang, p, rust) } }
                       .uniq.select { |f| rust[f].start_with?("Vec<", "Option<Vec<") }
    if forced_lists.empty?
      COMPARED[lang] += 1
    else
      problems << "#{struct}: constructor requires #{forced_lists.join(', ')}, " \
                  "which Rust always writes as a list — default it to empty instead"
    end
  end
  problems.uniq
end

# Parameters that are legitimately not fields of the node they build: the
# position shorthand every binding's node wrapper takes, and the tag a tagged
# enum variant stamps onto its payload. Both are answers to "where" and "which
# spelling", not to "which field", so a constructor that takes them is not
# inventing a field.
KNOWN_HELPERS = %w[
  filename line column end_line end_column endLine endColumn tag type kind
].freeze

# A binding may name a struct something other than `ast.rs` does. Kotlin calls
# `SchemaExpr` `SchemaConfig` as well, because `UnificationStmt.value` reaches
# the same struct and both spellings are in use. Same discipline as
# `PARAM_ALIASES`: an alias is a claim a reviewer can check, so it is written
# down rather than guessed.
STRUCT_ALIASES = {
  "kotlin" => { "SchemaConfig" => "SchemaExpr" }
}.freeze

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

# The shape of the report is shared by every binding, and each of its three
# failing guards has bitten at least once:
#
#   compared == 0      a collector that stopped matching
#   missing            a struct no constructor reaches
#   gaps               a struct reached but never judged
#
# `unmapped` is printed but does not fail. It counts constructors whose return
# type names no struct in `ast.rs`, and every binding legitimately has some:
# `nodeRef` returns a wrapper, `basicIntType` returns one arm of the `Type`
# content-tagged enum, which has no struct of its own. Failing on that would
# mean a permanent allowlist of names, and an allowlist nobody reads catches
# nothing. The failure it was standing in for — a collector whose naming has
# stopped matching its own source — is already caught twice over, by `compared`
# dropping to zero and by every struct arriving in `missing`.
def report(lang, problems)
  compared = COMPARED[lang]
  missing = NODE_TYPES.reject { |s| REACHED[lang].include?(s) }.sort
  gaps = (REACHED[lang].uniq - CHECKED[lang].uniq).select { |g| STRUCTS.key?(g) }.sort
  unmapped = UNMAPPED[lang].uniq.sort

  code = 0
  if compared.zero? && problems.empty?
    puts "#{lang}: 0 constructors compared - the checker matched nothing"
    code = 1
  elsif problems.empty?
    if missing.any? || gaps.any?
      puts "#{lang}: ok (#{compared} constructors), but"
      puts "  #{missing.length} node type(s) no constructor reaches: #{missing.join(' ')}" unless missing.empty?
      puts "  #{gaps.length} struct(s) reached but never judged: #{gaps.join(' ')}" unless gaps.empty?
      code = 1
    else
      puts "#{lang}: ok (#{compared} constructors)"
    end
  else
    puts "#{lang}: #{problems.length} problem(s) out of #{compared} constructors"
    problems.sort.each { |p| puts "  #{p}" }
    code = 1
  end
  puts "  #{unmapped.length} constructor(s) return a non-struct and are not counted: #{unmapped.join(' ')}" unless unmapped.empty?
  code
end

# ---------------------------------------------------------------------------
# Collectors
# ---------------------------------------------------------------------------

# Split a parameter list on the commas that separate parameters, ignoring the
# ones inside a generic's angle brackets or a default value's own brackets — a
# `List<NodeRef<Expr>>` and a default of `emptyList()` between them carry two
# commas that mean nothing.
def split_params(text)
  params = []
  depth = 0
  current = +""
  text.each_char do |ch|
    case ch
    when "<", "(", "[", "{"
      depth += 1
    when ">", ")", "]", "}"
      depth -= 1
    when ","
      if depth.zero?
        params << current.strip
        current = +""
        next
      end
    end
    current << ch
  end
  params << current.strip
  params.reject(&:empty?)
end

# One `name: Type = default` parameter, as `[name, defaulted?]`.
#
# A `vararg` (Kotlin), `...args` (C/Go) or `*names` (Python) is omittable by
# construction, so it counts as defaulted even without a `=`.
def parse_param(param)
  vararg = param.match?(/\A(?:vararg\s|\.\.\.|\*)/)
  body = param.sub(/\A(?:vararg\s+|\.\.\.|\*)/, "")
  name = body[/\A(\w+)\s*:/, 1] || body[/\A(\w+)\s*=/, 1]
  return nil if name.nil?

  [name, vararg || body.include?("=")]
end

# `kotlin/src/main/kotlin/com/kcl/ast/AstBuild.kt` is the reference form: one
# top-level `fun <name>(<params>): <Struct> = <Struct>().apply { … }` per node,
# every parameter defaulted to the value the Rust parser produces for it.
#
# The return type is what identifies the struct, not the function name — the
# names are ergonomic (`schemaExpr`, `memberOrIndexOf`) and will not survive
# being used as the join key. The helpers that return something other than a
# node (`nodeRef`, `emptyNodeRef`, `checkExpr`'s enum arms) hand back a type
# `ast.rs` does not declare a struct for, so `compare` counts them as reached
# and judged nothing, which is what they are.
def check_kotlin(path)
  src = File.read(path)
  src.scan(/^fun\s+\w+\s*\((.*?)\)\s*:\s*([A-Za-z0-9_.<>]+)\s*=/m).map do |params_text, ret|
    parsed = split_params(params_text).filter_map { |p| parse_param(p) }
    [ret, parsed.map(&:first), parsed.select { |(_, d)| d }.map(&:first)]
  end
end

CHECKS = {
  "kotlin" => -> { check_kotlin(File.expand_path("../kotlin/src/main/kotlin/com/kcl/ast/AstBuild.kt", __dir__)) }
}.freeze

# `CHECKS` is a registry; the loop below is the CLI. Requiring this file from a
# scratch checker or from the self-test has to get the former without the latter.
if $PROGRAM_NAME == __FILE__
  wanted = ARGV.empty? ? CHECKS.keys : ARGV
  abort "unknown binding(s): #{(wanted - CHECKS.keys).join(', ')}" unless (wanted - CHECKS.keys).empty?

  exit_code = 0
  wanted.each do |name|
    ctors = CHECKS[name].call
    exit_code |= report(name, compare(name, ctors))
  end
  exit(exit_code)
end
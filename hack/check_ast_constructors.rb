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
File.read(AST_RS).scan(/^pub struct (\w+)(?:<[^>]*>)? \{(.*?)\n\}/m) do |name, body|
  STRUCTS[name] = body.scan(/pub (\w+): ([^,\n]+),/).to_h { |f, t| [f, t.strip] }
end
# The two other spellings, and they are not edge cases: `Pos` and `AstIndex` are
# tuple structs and `MissingExpr` is a unit struct, so a braced-only scan cannot
# see them at all — and a struct the scan cannot see is a struct neither the
# rules nor the exclusion tables below can reason about, which makes every
# exclusion a claim about nothing. A tuple struct's five positional fields have
# no names, so the body is recorded under a synthetic key: no rule can demand a
# parameter be settable, which is the correct outcome for something no binding
# names its fields after anyway.
File.read(AST_RS).scan(/^pub struct (\w+)\(([^)]*)\);/).each do |name, body|
  STRUCTS[name] = { "(tuple)" => body.strip }
end
File.read(AST_RS).scan(/^pub struct (\w+);/).flatten.each { |name| STRUCTS[name] = {} }

# The four structs that are AST infrastructure rather than nodes a caller
# builds. `Pos` is a position, `AstIndex` is a byte range, `Node<T>` is the
# wrapper every node travels in, and `Spanned` is a blanket trait. Demanding a
# constructor for the wrapper would be demanding a constructor for
# `NodeRef<Identifier>` and `NodeRef<String>` under the same name, which is
# exactly the ambiguity the bindings resolve by suffix (`nodeRef` / `nodeStr`).
#
# This exempts them from the rules as well as from the coverage list, and that
# is the point: a struct we have declared is not a node a caller builds cannot
# also be one we hold to "every field settable". Python does expose a `Node`
# constructor, and it is a complete one — `Node(node=…, id=…, pos=Pos(…))`
# builds a fully-populated wrapper, spelling the five position members as the
# `Pos` they already are a class for and re-flattening them in `to_dict`. Rule 2
# would report four of `Node`'s five members unset, which is the checker reading
# Rust's field layout as an API requirement. `check_ast_field_types.rb` is where
# the wire shape of a wrapper is held to account, and it holds every binding to
# that already.
NOT_NODES = %w[Pos AstIndex Node Spanned].freeze

# Structs that sit in `ast.rs` beside the nodes but cannot appear in the
# document a binding decodes. A binding is not behind on these; they are not on
# the wire, so there is nothing to be behind about.
#
#   Argument            one `--override-key=value` pair from the exec API
#   ExternalPkg         one entry of the runner's resolved `external_pkgs`
#   OverrideSpec        the parsed form of `alice.age=10`
#   SymbolSelectorSpec  the parsed form of `pkg:a.b`
#   Program             the resolution index
#
# The first four are fields of nothing in `ast.rs` — they are inputs and
# outputs of other APIs that happen to be declared beside the nodes, so serde
# can never reach them from a node.
#
# `Program` is the one that looks like the root of the tree and is not. It
# derives only `Debug, Clone, Default`, so it is never serialised; `parse_program`
# sends `SerializeProgram` instead (`service_impl.rs`, `let ast_json =
# serde_json::to_string(&serialize_program)?`). Its `pkgs` is `Vec<String>`
# where `SerializeProgram`'s is `Vec<Module>`, and it holds `Arc<RwLock<Module>>`
# maps that have no JSON spelling. What a binding receives is `SerializeProgram`,
# which is in the set below.
NOT_ON_THE_WIRE = %w[Argument ExternalPkg OverrideSpec SymbolSelectorSpec Program].freeze

# Every struct a caller can build: the AST nodes plus the top-level documents
# the loader hands back. `SerializeProgram` is what `parseProgram` returns,
# `Module` is what `parseModule` returns, so they are as much a caller-facing
# constructor target as `BinaryExpr` is.
NODE_TYPES = (STRUCTS.keys - NOT_NODES - NOT_ON_THE_WIRE).sort.freeze

# Node types a named binding deliberately does not give a caller a constructor
# for. Unlike `NOT_ON_THE_WIRE` these are on the wire; the exemption is a
# per-binding API design decision, and each one is argued in that binding's
# collector header, which is where a reviewer should look before adding an
# entry here. Two decisions cover every entry:
#
#   SerializeProgram — the binding's `parseProgram` unwraps the
#     `{"root": …, "pkgs": …}` envelope and hands back the modules of
#     `pkgs.__main__`, so the document a caller receives has no type to
#     build and `root` is dropped. Changing this is a public API break,
#     not an ergonomics tweak.
#   IntLiteralType — the payload of `LiteralType::Int`, the one literal
#     variant that is a struct. These bindings model `LiteralType` verbatim
#     (`value` rides through undecoded, the arm recorded separately), so the
#     payload is never a type a caller spells. Kotlin's `literalIntType` is
#     the other answer, registered in `WRAPPED_PAYLOADS`.
#
# A binding that reaches everything — kotlin, java, swift, c — has no
# entry, and an entry is a claim a reviewer can check, so the same load-bearing
# guard as the global tables below applies: a struct here that `ast.rs` no
# longer declares, or one that is not a node type at all, aborts the run.
NOT_MODELED = {
  "cpp" => %w[SerializeProgram IntLiteralType],
  "python" => %w[SerializeProgram],
  "go" => %w[SerializeProgram],
  "julia" => %w[SerializeProgram IntLiteralType],
  "dotnet" => %w[SerializeProgram],
  "lua" => %w[SerializeProgram IntLiteralType],
  "nodejs" => %w[SerializeProgram IntLiteralType],
  "zig" => %w[IntLiteralType],
  "dart" => %w[SerializeProgram IntLiteralType]
}.freeze

# Every struct `ast.rs` declares has to be either a node the rules judge or a
# named exclusion, and both halves of that are checked rather than trusted. A
# struct in neither set is one the report would quietly never mention, and a
# struct in an exclusion table that `ast.rs` does not declare is a claim about a
# struct that has since been renamed or deleted — which is how an exclusion list
# rots into a list of names that no longer mean anything. This is the guard that
# makes those tables load-bearing rather than decorative: `Pos` and `AstIndex`
# are tuple structs, so a braced-only scan could not see them and `NOT_NODES`
# removed nothing, which is exactly the drift this catches.
STALE_EXCLUSIONS = (NOT_NODES + NOT_ON_THE_WIRE).reject { |n| STRUCTS.key?(n) }
abort "exclusion table names a struct ast.rs does not declare: #{STALE_EXCLUSIONS.join(' ')}" unless STALE_EXCLUSIONS.empty?
NOT_MODELED.each do |lang, names|
  stale = names.reject { |n| NODE_TYPES.include?(n) }
  abort "NOT_MODELED[#{lang}] names a struct that is not a node type: #{stale.join(' ')}" unless stale.empty?
end

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
# takes.
#
# The two `ImportStmt` names are `ast.rs` being internally inconsistent, not a
# binding's renaming: `CallExpr.keywords` (ast.rs:1055) and `SchemaExpr.kwargs`
# (ast.rs:1199) are the same wire field under two spellings, and
# `ImportStmt.rawpath` / `.asname` (ast.rs:681) drop the separator their
# neighbours keep. Swift unifies the first pair under `keywords` and .NET the
# second under `rawPath` / `asName`. That Swift's `keywords` means `kwargs` for
# one struct and `keywords` for the other is not an ambiguity the join has to
# resolve: an exact match is tried before the table, so `CallExpr` takes the
# exact one and only `SchemaExpr` ever reaches the alias.
#
# A general "squash the underscores" fallback was the obvious way to avoid the
# second pair and was rejected: `ast.rs` declares both `pkg_path` (ast.rs:350,
# `OverrideSpec`) and `pkgpath` (ast.rs:935, `Target`), so `pkgPath` would join
# to whichever the squash happened to reach first.
#
# Zig's two underscore pairs are not a rename at all — `test` and `orelse` are
# Zig builtins and keywords, so `test_` and `orelse_` are the only legal
# spelling of an ast.rs field. Zig's `modules` for `pkgs` is a genuine rename
# and the weakest claim here: Zig flattens `HashMap<String, Vec<Module>>` into
# the `__main__` list alone, so `modules` is defensible rather than merely
# necessary. It is written down for that reason.
#
# Nothing else is allowed in here without the same justification: an entry that
# hides a field nobody can set is worse than the failure it silences.
PARAM_ALIASES = {
  "kotlin" => { "elements" => "type_elements" },
  "nodejs" => { "types" => "type_elements" },
  "julia" => { "as_name" => "asname", "types" => "type_elements" },
  "dart" => { "types" => "type_elements", "asName" => "asname" },
  "swift" => { "keywords" => "kwargs" },
  "zig" => { "test_" => "test", "orelse_" => "orelse", "modules" => "pkgs" },
  "cpp" => { "as_name" => "asname" },
  "c" => { "main_package" => "pkgs" },
  "dotnet" => { "rawPath" => "rawpath", "asName" => "asname" }
}.freeze

# Field types Rust writes whether or not they have a value: an empty `Vec` is
# `[]` and an empty map is `{}`, never absent, so a constructor demanding one
# is making the caller spell the empty collection.
#
# `Option<Vec<…>>` and `Option<HashMap<…>>` are deliberately not here. serde
# writes `None` as `null`, so the wire itself spells absence for them —
# `FunctionType.params_ty` (ast.rs:1871) arrives as `"params_ty": null` for
# `() -> T` and the parser never builds `[]` — which means requiring the
# caller to pass an explicit `null` is a faithful modelling of the wire, not
# the ceremony rule 1 exists to catch. Julia's `params_ty = nothing` default
# and C#'s required `paramsTy` are both right, and the rule has no opinion.
ALWAYS_WRITTEN = ["Vec<", "HashMap<"].freeze

# ---------------------------------------------------------------------------
# The rules
# ---------------------------------------------------------------------------

# A node-shaped field is one holding a child node, a list of them, or an
# optional of either. The same predicate `check_ast_field_types.rb` uses to
# decide which fields its two rules can say anything about, and for the same
# reason: `String`, `bool` and the enum leaves have obvious literals, so a
# constructor that requires one is asking for a value, not for ceremony.
NODE_SHAPED = /\A(?:Option<)?(?:Node|NodeRef|Vec|Option<Vec)/

# A binding with no sum types and no length-carrying arrays cannot name a
# field the way `ast.rs` does, so it writes the field's *storage* instead. Two
# of the three idioms are derivable, and deriving them is strictly better than
# listing them: the base name still has to be a real field of this struct, so
# the rule can be silenced by a real field or not at all, and a member that
# stands alone — `has_foo` where `foo` is not a field — still fails.
#
#   `has_op` + `op`         `Option<T>` has no zero value in C, so
#                           `SchemaAttr.op: Option<AugOp>` (ast.rs:817)
#                           becomes a pointer plus a presence flag.
#   `ops_count` + `ops`     an array carries no length, so `Compare.ops:
#                           Vec<CmpOp>` (ast.rs:1387) becomes the pointer and
#                           its count.
#
# The third — splitting a tagged enum's payload into one member per arm — is not
# derivable, because `int_value` says nothing mechanical about `value`. That
# one is `ENUM_ARM_MEMBERS` below.
DERIVED_TWIN = /\A(?:has_(.+)|(.+)_count)\z/.freeze

# A parameter name to the `ast.rs` field it sets, by every route but the twin
# rule below. Split out so the twin rule can resolve its base through the same
# tables without recursing back into itself: C's `main_package_count` is a twin
# of `main_package`, which is itself only a field by way of `PARAM_ALIASES`.
def resolve_field(lang, name, rust, struct)
  return name if rust.key?(name)

  aliased = PARAM_ALIASES.dig(lang, name)
  return aliased if aliased && rust.key?(aliased)

  arm = ENUM_ARM_MEMBERS.dig(lang, struct, name)
  return arm if arm && rust.key?(arm)

  snake = name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
  snake if rust.key?(snake)
end

def rust_field_for(lang, param, rust, struct = nil)
  direct = resolve_field(lang, param, rust, struct)
  return direct if direct

  m = DERIVED_TWIN.match(param)
  m && resolve_field(lang, m[1] || m[2], rust, struct)
end

# The one place a binding says "these members together are this field", for the
# case no naming convention reaches.
#
# C has no sum type, so `NumberLit.value: NumberLitValue` (ast.rs:1478) — whose
# arms are `Int(i64)` and `Float(f64)` (ast.rs:1464) — becomes a `value_kind`
# discriminator plus one member per arm. `value_kind` is the tag and joins
# `KNOWN_HELPERS` with `valueTag` and `value_tag`, which is the same answer;
# the two arm members have no mechanical relationship to `value`, so the claim
# is written down here rather than guessed at.
#
# Keyed by lang and struct because the answer is per-struct: `int_value` means
# something about `NumberLit` and nothing about any other node, and a flat list
# would let one struct's claim excuse another's.
ENUM_ARM_MEMBERS = {
  "c" => { "NumberLit" => { "int_value" => "value", "float_value" => "value" } }
}.freeze

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
    # Infrastructure, not a node — see `NOT_NODES`. Exempt from the rules and
    # from the coverage list alike, so a binding that does expose one is not
    # then held to a rule the exemption already disclaims.
    next if NOT_NODES.include?(struct)

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
    settable = group.flat_map { |params, _| params.filter_map { |p| rust_field_for(lang, p, rust, struct) } }.uniq

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
    real = group.select { |params, _| params.any? { |p| rust_field_for(lang, p, rust, struct) } || rust.empty? }
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
      next if params.none? { |p| rust_field_for(lang, p, rust, struct) }

      unknown = params.reject { |p| KNOWN_HELPERS.include?(p) || rust_field_for(lang, p, rust, struct) }
      next if unknown.empty?

      problems << "#{struct}: constructor parameter #{unknown.join(', ')} " \
                  "names no field of the struct in ast.rs"
    end

    # Rule 1: a collection field must never be a *required* parameter. Rust
    # writes a `Vec` field as `[]` and a `HashMap` field as `{}` when it is
    # empty — the field is never absent — so a constructor demanding one is
    # making the caller type an empty collection at every level of the tree,
    # which is the ceremony this file exists to catch.
    #
    # A required `Option<NodeRef<T>>` is deliberately not included: `Keyword.arg`
    # and `ListType.inner_type` are children a node cannot exist without, and a
    # default that let a caller omit them would build a node the parser can never
    # produce. Asking for a child is asking for a value; asking for `[]` is not.
    forced_lists = group.flat_map { |params, defaulted| (params - defaulted).filter_map { |p| rust_field_for(lang, p, rust, struct) } }
                       .uniq.select { |f| ALWAYS_WRITTEN.any? { |t| rust[f].start_with?(t) } }
    if forced_lists.empty?
      COMPARED[lang] += 1
    else
      problems << "#{struct}: constructor requires #{forced_lists.join(', ')}, " \
                  "which Rust always writes as a collection — default it to empty instead"
    end
  end
  problems.uniq
end

# Parameters that are legitimately not fields of the node they build: the
# position shorthand every binding's node wrapper takes, and the tag a tagged
# enum variant stamps onto its payload. Both are answers to "where" and "which
# spelling", not to "which field", so a constructor that takes them is not
# inventing a field.
#
# Each name is listed under every spelling a binding actually uses rather than
# matched case-insensitively, because case is the one convention that is not
# worth guessing: Go exports both members of a serde tag — 41 of its 73 AST
# structs carry `Type string` for `#[serde(tag = "type")]` on `pub enum Stmt`
# (`ast.rs:572`) — and a case-insensitive match would also fold `ID` into `id`
# and `Raw` into `raw`, which are field names and would then be exempted from
# rule 3 for the wrong reason.
KNOWN_HELPERS = %w[
  filename line column end_line end_column endLine endColumn
  tag type kind Type Kind
  valueTag value_tag value_kind
].freeze

# A binding may name a struct something other than `ast.rs` does. Kotlin calls
# `SchemaExpr` `SchemaConfig` as well, because `UnificationStmt.value` reaches
# the same struct and both spellings are in use. Kotlin's `Program` class is
# `SerializeProgram` — it holds `root` and `pkgs: Map<String, List<Module>>`,
# which is the serialised projection, not the resolution index `ast.rs` calls
# `Program`. Same discipline as `PARAM_ALIASES`: an alias is a claim a
# reviewer can check, so it is written down rather than guessed.
STRUCT_ALIASES = {
  "kotlin" => { "SchemaConfig" => "SchemaExpr", "Program" => "SerializeProgram" }
}.freeze

# A constructor whose return type is a tagged-enum wrapper, so the struct it
# fills in is never named in the signature: `literalIntType` returns
# `LiteralType`, because `{"type":"Int","value":{…}}` is what the tree holds,
# and the `IntLiteralType` payload is constructed inside. Registering the same
# constructor for the payload is the honest reading — a caller asking "can I
# build an `IntLiteralType`?" is answered yes — and it is opt-in per function
# rather than inferred, so a body that merely *mentions* a struct cannot
# quietly claim it.
#
# `LiteralType::Int` is the only variant in `ast.rs` whose payload is a struct
# rather than a scalar (`Bool(bool)`, `Float(f64)`, `Str(String)`), so this is
# the only entry there is.
WRAPPED_PAYLOADS = {
  "kotlin" => { "literalIntType" => "IntLiteralType" }
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
  modeled = NODE_TYPES - NOT_MODELED.fetch(lang, [])
  missing = modeled.reject { |s| REACHED[lang].include?(s) }.sort
  not_modeled = NOT_MODELED.fetch(lang, []).reject { |s| REACHED[lang].include?(s) }.sort
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
  puts "  #{not_modeled.length} node type(s) deliberately not modeled: #{not_modeled.join(' ')} (see the collector header)" if not_modeled.any?
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
  found = src.scan(/^fun\s+(\w+)\s*\((.*?)\)\s*:\s*([A-Za-z0-9_.<>]+)\s*=/m).map do |name, params_text, ret|
    parsed = split_params(params_text).filter_map { |p| parse_param(p) }
    [[ret, parsed.map(&:first), parsed.select { |(_, d)| d }.map(&:first)], name]
  end

  ctors = found.map(&:first)
  # A constructor registered for the enum payload it fills in. If the function
  # is not in the file the entry is silently a no-op and the payload stays in
  # the report's missing list, which is the right outcome: a claim about a
  # function that no longer exists should not keep a struct looking covered.
  WRAPPED_PAYLOADS.fetch("kotlin", {}).each do |name, payload|
    entry = found.find { |(_, n)| n == name }
    ctors << [payload, entry.first[1], entry.first[2]] if entry
  end
  ctors
end

# Per-language collectors live in their own file under `ast_ctors/` so that two
# of them can be written without either having to know about the other, and so
# that a binding's collector can be read on its own. Each defines one method,
# `check_<lang>(path_or_dir)`, returning `[struct, params, defaulted]` triples —
# the same shape `check_kotlin` returns above.
#
# `require` rather than `load` so that a collector with a syntax error stops
# the run instead of being silently skipped, and so a second require of the
# same file is free.
Dir[File.expand_path("ast_ctors/*.rb", __dir__)].sort.each { |f| require f }

CHECKS = {
  "kotlin" => -> { check_kotlin(File.expand_path("../kotlin/src/main/kotlin/com/kcl/ast/AstBuild.kt", __dir__)) },
  "python" => -> { check_python(File.expand_path("../python/kcl_lib/ast", __dir__)) },
  "go" => -> { check_go(File.expand_path("../go/ast", __dir__)) },
  "java" => -> { check_java(File.expand_path("../java/src/main/java/com/kcl/ast", __dir__)) },
  "nodejs" => -> { check_nodejs(File.expand_path("../nodejs/src/ast", __dir__)) },
  "dotnet" => -> { check_dotnet(File.expand_path("../dotnet/KclLib.AST", __dir__)) },
  "swift" => -> { check_swift(File.expand_path("../swift/Sources/KclLibAST", __dir__)) },
  "zig" => -> { check_zig(File.expand_path("../zig/src/ast", __dir__)) },
  "julia" => -> { check_julia(File.expand_path("../julia/src", __dir__)) },
  "dart" => -> { check_dart(File.expand_path("../dart/lib/src/ast", __dir__)) },
  "lua" => -> { check_lua(File.expand_path("../lua/kcl_lib/ast.lua", __dir__)) },
  "c" => -> { check_c(File.expand_path("../c/include/kcl_lib_ast.h", __dir__)) },
  "cpp" => -> { check_cpp(File.expand_path("../cpp/include", __dir__)) }
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
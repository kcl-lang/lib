# frozen_string_literal: true

# Constructors for the Lua binding.
#
# `lua/kcl_lib/ast.lua` is hand-written and — unlike `nodejs/src/ast/*.mjs` —
# there is nothing in the binding that even tries to be a type contract: no
# `.d.lua`, no `---@class` for a node, no generated DTO module. It says so
# itself, at ast.lua:25-30: "AST nodes are plain tables: Lua has no classes, and
# metatables on every property access would cost more than they are worth."
# So the question is not what shape the binding declares but what a caller
# actually holds, and the answer is unique to this language.
#
# **The exported `parse_*` loaders are the only construction path.** The module
# publishes thirteen of them on `M` (ast.lua:921-934, "Exported for the contract
# spec, which asserts the DTO loaders directly"), and every one of them takes a
# single argument: the table the node is built from. `spec/ast_contract_spec.lua`
# then calls them exactly as a builder is called —
#
#     ast.parse_identifier({ names = {}, pkgpath = "p", ctx = "Store" })
#     ast.parse_arguments({ args = {}, defaults = {}, ty_list = {} })
#     ast.parse_schema_index_signature({ key_name = nil, any_other = false })
#     (ast_contract_spec.lua:444-453)
#
# — which is the `M.identifier{ names = {...} }` factory the brief predicted,
# spelled `parse_` and taking the wire spelling. It is not a decoder-only
# function by accident: it is a factory whose parameter happens to be a
# wire-shaped table, so `parse_x{…}` builds an `x` with every field spelled the
# way `ast.rs` spells it. The other forty-odd loaders are not on `M`, but all
# of them are reached through `M.parse_stmt` / `M.parse_expr` / `M.parse_type`
# with the tag the `Stmt` / `Expr` / `Type` registry uses, so the whole set is
# reachable the same way.
#
# That is also why this collector reads the *wire* keys rather than the
# camelCase keys the loaders emit. `parse_arguments` takes `ty_list` and emits
# `tyList`; `parse_union_type` takes `type_elements` and emits `types`. The
# parameter is the name on the way **in**, and reporting the emitted name would
# put `types` where `ast.rs` has `type_elements` (ast.rs:1895) — a `ParamAliases`
# entry to paper over a question that was never open. `compare` resolves
# `tyList` to `ty_list` on its own if a future loader reads that way; nothing
# here needs a table entry, and no name in this file is ambiguous.
#
# **Every parameter is `defaulted`, and that is derived, not assumed.** Lua
# cannot hold a `nil` in a table, so an omitted key and a key set to `nil` are
# the same node — `{ ctx = nil }` *is* `{}`. Every read in these loaders goes
# through one of the module's nil-safe accessors, and each substitutes a value
# for an absent key: `as_string(d.x, "")` (ast.lua:61-67), `as_bool(d.x, false)`
# (ast.lua:75-81), `as_list(d.x)` (ast.lua:84-86), `node_ref(d.x, load)`
# returning `nil` (ast.lua:94-111), `node_ref_list(d.x, load)` returning `{}`
# (ast.lua:118-126). So `M.parse_identifier{}` is a complete `Identifier` —
# `names = {}`, `pkgpath = ""`, `ctx = nil` — and no caller is asked to type
# `{}` at any level of the tree, which is the ceremony `AstBuild.kt` exists to
# stop. Rule 1 therefore cannot fire for Lua, and that is the language's answer
# rather than a generous reading of one, for the same reason it cannot for Go:
# something in the language fills the value in. What Go fills in is a zero value,
# what Lua fills in is a decode helper's default.
#
# The difference from `check_nodejs` is the whole point and it is not a
# difference of opinion. There, the constructor is an object literal the caller
# types, `{}` is not a `CallExpr`, and `args: []` is written out at every level.
# Here the caller *calls* something, and the callee fills the keys in.
# `defaulted` here is not `params.dup` written down lazily either: it is
# recomputed per key from the accessor the read went through, so a loader that
# ever copied a field with a bare `value = d.x` would report that key as
# required and rule 1 would fire on it. Two guards keep that claim honest: a read
# through a callee this file does not recognise counts as *required*, which can
# only ever under-claim, and a read off a receiver the scan cannot account for
# raises rather than silently shrinking `params`.
#
# Nine loaders do not name their struct by convention: the payload/alias pair
# (`parse_check` is `CheckExpr`, whose serde payload is `check`;
# `parse_module_dict` is `Module`, `parse_module` being the JSON-string entry
# point), and the seven `Expr::…` tagged twins and their inner payloads —
# `parse_check_expr_variant` / `parse_keyword_expr` / `parse_arguments_expr` /
# `parse_schema_expr_inner` / `parse_schema_expr_variant` /
# `parse_call_expr_variant` / `parse_target_expr`. Each is mapped to the struct
# it actually builds, which is what `compare` judges. Mapping a twin to its
# payload is not `WRAPPED_PAYLOADS`: that table exists for a struct *only* a
# wrapper builds (Kotlin's `literalIntType`), and here every one of these
# payloads is independently constructible through its own exported loader, so
# `CheckExpr` and `Keyword` are reached twice over and neither is a blind spot.
# Six of the twins are pure delegates (`parse_target_expr`,
# `parse_call_expr_variant`, `parse_check_expr_variant`, `parse_keyword_expr`,
# `parse_arguments_expr`, `parse_schema_expr_variant`) and record no parameters
# of their own, as do `parse_basic_type` and `parse_named_type`, which take the
# arm's payload whole; all eight are returned anyway — `compare` unions a
# struct's constructors, so a convenience that forwards is free and one that is
# dropped is a gap the report would not see.
#
# Nothing is filtered by name. `parse_stmt` / `parse_expr` / `parse_type` are
# the polymorphic dispatchers and `parse_member_or_index` / `parse_basic_type`
# / `parse_named_type` / `parse_literal_type` are tagged-enum arms; none names a
# struct `ast.rs` declares, so all seven arrive in `unmapped` — which is what
# they are, and which is the count this file is expected to keep honest. A
# loader renamed out of the convention would also arrive in `unmapped` and take
# its struct with it, so the collector raises on any returned name `ast.rs`
# declares no struct for rather than letting that happen quietly. And
# `M.parse_module(ast_json)` is deliberately *not* returned: its one parameter is
# a JSON string, not a field of `Module`, and `Module` is already constructed
# by `parse_module_dict`.
#
# Two `ast.rs` structs this binding cannot reach at all, both real gaps rather
# than blind spots in the parse, and both recorded in `NOT_MODELED` rather than
# closed here — the report prints them as deliberately not modeled:
#
#   * `SerializeProgram` (ast.rs:386, `root` / `pkgs`) — `M.parse_program`
#     unwraps the envelope and returns the modules of `pkgs.__main__`
#     (ast.lua:915, `for _, m in ipairs(pkgs.__main__ or {}) do`), so `root` is
#     dropped on the floor, exactly as in Go and Node.js.
#   * `IntLiteralType` (ast.rs:1909, `value` / `suffix`) — the payload of
#     `LiteralType::Int`, the only variant whose payload is a struct rather than
#     a scalar. `parse_literal_type` (ast.lua:802-810) does not decode it: it
#     hands the wire object to `strip_nulls` (ast.lua:787-798) and records the
#     arm's tag in `innerTag`, so the payload rides through as an anonymous
#     table and `strip_nulls` *drops* `suffix` whenever it is null — a field no
#     caller can set. There is nothing to put in `WRAPPED_PAYLOADS` either:
#     unlike Kotlin's `literalIntType`, no function here builds one, not even a
#     convenience.

def check_lua(path)
  src = File.read(path)

  # Comments go first. Every key this collector reports is a wire key named in a
  # `d.<key>` read, and a comment is prose that quotes `ast.rs` — the loaders
  # carry lines like "-- The Rust field is `ty_list`" (ast.lua:201) and
  # "`Identifier.ctx` is `ExprContext`", either of which a laxer scan would read
  # as a field. The long form first, because `--[[` opens one that `--` would
  # only take the first line of. Neither form appears inside a string literal in
  # this file, which is the one thing that would make this lossy.
  src = src.gsub(/--\[\[.*?\]\]/m, "").gsub(%r{--[^\n]*}, "")

  # The nine loaders whose name is not their struct's. See the note above.
  struct_of = {
    # The serde payload of `CheckExpr` is `check`, and the file says so at
    # ast.lua:219 rather than in the name.
    "parse_check" => "CheckExpr",
    # `parse_module` is the JSON-string entry point, so the name-derived lookup
    # would land on `ModuleDict`, which is not a struct, and `filename` / `doc`
    # / `body` / `comments` would go unjudged.
    "parse_module_dict" => "Module",
    # The `Expr::…` tagged twins and their inner payloads. Each returns the
    # payload's fields, and `parse_expr` adds the tag on top afterwards
    # (ast.lua:730), so the struct built is the untagged one.
    "parse_target_expr" => "Target",
    "parse_call_expr_variant" => "CallExpr",
    "parse_check_expr_variant" => "CheckExpr",
    "parse_keyword_expr" => "Keyword",
    "parse_arguments_expr" => "Arguments",
    "parse_schema_expr_inner" => "SchemaExpr",
    "parse_schema_expr_variant" => "SchemaExpr"
  }.freeze

  # Every decoder helper a field read may be passed through, and the value each
  # substitutes when the key is absent. This list *is* the claim that Lua's
  # `defaulted` is full, so a read handed to a callee that is *not* on it counts
  # as required: an unknown helper could hand the key's raw value back, and
  # claiming it was omittable would hide a field the caller has to pass. The
  # failure is one-directional — this list can make a key look required that is
  # not, never the reverse — which is the direction to be wrong in.
  helpers = %w[node_ref node_ref_list as_string as_bool as_int as_list
                is_dict is_null strip_nulls]
  # `parse_*` is included because one loader is handed another whole payload —
  # `DictComp.entry` goes to `parse_config_entry(d.entry)` (ast.lua:572), which
  # returns `nil` for anything that is not a dict, like every other helper.
  nil_safe = /\b(?:#{(helpers + ['parse_\w+']).join('|')})\([ \t]*\z/

  # The seven names this binding builds that `ast.rs` does not declare a struct
  # for: the three polymorphic dispatchers and the four tagged-enum arms. They
  # are returned, not dropped — a collector that filters what it cannot classify
  # is a collector that reports success after it has stopped matching — and
  # `compare` puts all seven in `unmapped`, which is what they are.
  not_structs = {
    "Stmt" => "the `#[serde(tag = \"type\")]` enum, dispatched by STMT_REGISTRY",
    "Expr" => "the `#[serde(tag = \"type\")]` enum, dispatched by EXPR_REGISTRY",
    "Type" => "the `#[serde(tag = \"type\", content = \"value\")]` enum",
    "MemberOrIndex" => "the `tag + content` enum behind `Target.paths`",
    "BasicType" => "the `Type::Basic` arm; its payload is a bare string",
    "NamedType" => "the `Type::Named` arm; its payload is an `Identifier`",
    "LiteralType" => "the `Type::Literal` arm, itself tagged (ast.rs:1901)"
  }.freeze

  ctors = []

  # `local function parse_x(a)` … `end`, and the three forward-declared
  # dispatchers spelled `parse_x = function(a)` … `end` (ast.lua:457, 720, 822).
  # The body runs to a `^end` and not to the first `end`: every nested block in
  # these functions is indented, so the only `end` at column 0 closes the
  # function. Dotall rather than `.`: `[^\n]*` for the header would have to
  # cross the body to reach the closing `end` anyway.
  src.scan(/^(?:local function (parse_\w+)|(parse_\w+) = function)\((\w+)\)(.*?)^end/m) do
    fn = Regexp.last_match[1] || Regexp.last_match[2]
    arg = Regexp.last_match[3]
    body = Regexp.last_match[4]

    # `parse_` + each `_`-separated word capitalised. `w[0].upcase + w[1..]`
    # rather than `capitalize`, which downcases the tail — the file is all
    # lowercase today so the two agree, and this one keeps agreeing.
    derived = fn.sub(/\Aparse_/, "").split("_").map { |w| w[0].upcase + w[1..] }.join
    struct = struct_of.fetch(fn, derived)

    # A name that is neither a struct `ast.rs` declares nor one of the seven
    # enums above is a loader this collector mis-named — a rename, or a
    # convention the file no longer follows. It would arrive as `unmapped`, and
    # `unmapped` does not fail the run, so the struct whose constructor just
    # disappeared would only show up as a line in the report. Raised here
    # instead, where it names the function.
    unless STRUCTS.key?(struct) || not_structs.key?(struct)
      raise "#{path}: `#{fn}` derives the struct name `#{derived}`, which ast.rs " \
            "declares no struct for - rename it, or say in `struct_of` which " \
            "struct it builds"
    end

    # The payload variable names. The argument, plus any local bound to it
    # alone: the four `Type` payload loaders take `v` and immediately rebind it
    # as `local t = is_dict(v) and v or {}` (ast.lua:753, 762, 772, 814), so
    # `t.inner_type` reads the same key `v.inner_type` would. "Bound to the
    # argument alone" is the test that keeps this from swallowing `local out =
    # loader and loader(d) or {}` in the two dispatchers (ast.lua:466, 729),
    # which is a table the function *writes*, not a second name for the payload —
    # reading `out.type` as a field of `Stmt` would be a field the struct does
    # not have.
    payload = [arg]
    locals_here = []

    params = []
    # A key read at least once without going through a nil-safe accessor. Kept
    # separate from `defaulted` so the two lists cannot alias, and a key that is
    # read bare *anywhere* is required even if another read wraps it.
    bare = []

    body.each_line do |raw|
      if (m = raw.match(/\A[ \t]*local\s+(\w+)[ \t]*=[ \t]*(.+?)\s*\z/))
        locals_here << m[1]
        # The identifiers the initializer mentions once the decoder helpers and
        # Lua's own glue words are gone. `is_dict(v) and v or {}` leaves `v`
        # alone, so `t` is a second name for the payload; `loader and
        # loader(d) or {}` leaves `loader` as well, and that is not the payload.
        bound = m[2].scan(/\b\w+\b/) - %w[and or true false nil] - helpers
        payload << m[1] if bound.uniq == [arg]
      end

      raw.scan(/\b(\w+)\.(\w+)\b/) do |recv, key|
        # Every read has to be a read of the payload. A receiver this scan
        # cannot place is a field it may have lost, and a lost field is a caller
        # who cannot build the node — the failure this checker exists to catch —
        # so it is raised rather than passed over. `locals_here` is the one
        # other answer: the result table a loader writes (`out.type`,
        # `out.unknown`), which is not a read of anything.
        next if payload.include?(recv) || locals_here.include?(recv)

        raise "#{path}: `#{fn}` reads `#{recv}.#{key}` off a receiver that is " \
              "neither its argument nor a local it declares — a field this " \
              "collector cannot account for"
      end

      raw.scan(/\b(\w+)\.(\w+)\b/) do |recv, key|
        next unless payload.include?(recv)

        params << key unless params.include?(key)
        # A read is nil-safe when it is handed to one of the decoder helpers:
        # what precedes it is that helper's name and an open paren.
        bare << key unless raw[0...raw.index("#{recv}.#{key}").to_i].match?(nil_safe)
      end
    end

    ctors << [struct, params, params - bare]
  end

  ctors
end
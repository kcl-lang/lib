# frozen_string_literal: true

# Self-test for check_ast_constructors.rb.
#
# A checker that reports "ok" on a deliberately broken binding is worse than
# no checker at all, so every rule it claims to enforce is verified by
# re-introducing a bug that actually happened and asserting the checker names
# the right struct.
#
# The mutations run against kotlin's `AstBuild.kt`, which is the reference
# form, so a rule that only fires on a synthetic fixture is not evidence the
# rule is right. Each case writes the mutated source to a scratch file, points
# the collector at it, and looks for the struct in the problem list.
#
# Usage: ruby hack/test_check_ast_constructors.rb

require "stringio"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path(__dir__))
require "check_ast_constructors"

KOTLIN_SRC = File.expand_path("../kotlin/src/main/kotlin/com/kcl/ast/AstBuild.kt", __dir__)

# Each case is [label, the correct line, the line with the bug swapped in, the
# struct the report must name, :problem or :missing].
#
# `:problem` means the struct has to be named in `compare`'s output; `:missing`
# means it has to show up in the report's unreachable list; `:silent` means the
# struct must NOT be named. All three matter: a rule that fires on the wrong
# struct, a coverage gap that goes unreported, and an exemption that has quietly
# stopped exempting are failures in three different directions, and each case
# names which one it is testing.
#
# Rule 2 (a field nothing can set) is the one with real teeth: the case nobody
# writes a test for is the one field a constructor forgot, and a constructor
# that drops a field silently produces a node the parser would never emit.
KOTLIN_CASES = [
  ["rule 2: `stringLit` stops accepting `rawValue`",
   "fun stringLit(value: String, isLongString: Boolean = false, rawValue: String? = null): StringLit = StringLit().apply {",
   "fun stringLit(value: String, isLongString: Boolean = false): StringLit = StringLit().apply {",
   "StringLit", :problem],

  # `schemaExpr` is deliberately not used here. It has a sibling constructor,
  # `schemaConfig`, taking the same four parameters, and the rules judge a
  # struct over the *union* of its constructors — so dropping `config` from one
  # of them is not a gap a caller can hit, and the checker is right to stay
  # quiet. The case has to be a struct with a single constructor.
  ["rule 2: `ifExpr` stops accepting `orelse`",
   "fun ifExpr(body: NodeRef<Expr>? = null, cond: NodeRef<Expr>? = null, orelse: NodeRef<Expr>? = null): IfExpr = IfExpr().apply {",
   "fun ifExpr(body: NodeRef<Expr>? = null, cond: NodeRef<Expr>? = null): IfExpr = IfExpr().apply {",
   "IfExpr", :problem],

  # Rule 1: `Vec` is never absent on the wire, so a constructor that demands
  # one is making the caller type `[]` at every level of the tree. This is the
  # exact shape a DTO's own required memberwise initialiser has.
  ["rule 1: `configExpr` requires its items list",
   "fun configExpr(items: List<NodeRef<ConfigEntry>> = emptyList()): ConfigExpr = ConfigExpr().apply { this.items = items }",
   "fun configExpr(items: List<NodeRef<ConfigEntry>>): ConfigExpr = ConfigExpr().apply { this.items = items }",
   "ConfigExpr", :problem],

  ["rule 1: `module` requires its body list",
   "fun module(\n    filename: String,\n    doc: NodeRef<String>? = null,\n    body: List<NodeRef<Stmt>> = emptyList(),",
   "fun module(\n    filename: String,\n    doc: NodeRef<String>? = null,\n    body: List<NodeRef<Stmt>>,",
   "Module", :problem],

  # Rule 1 on a map, and rule 3's alias in one case: `program` is the
  # `SerializeProgram` projection, so the report has to name the struct
  # `ast.rs` uses, not the one the binding does.
  ["rule 1: `program` requires its `pkgs` map, reported as `SerializeProgram`",
   "fun program(root: String = \"\", pkgs: Map<String, List<Module>> = emptyMap()): Program = Program().apply {",
   "fun program(root: String = \"\", pkgs: Map<String, List<Module>>): Program = Program().apply {",
   "SerializeProgram", :problem],

  # Rule 3: a parameter naming a field the core does not declare is drift in
  # the other direction — a constructor argument that goes nowhere.
  ["rule 3: `comment` grows a parameter `ast.rs` does not declare",
   "fun comment(text: String): Comment = Comment().apply { this.text = text }",
   "fun comment(text: String, colour: String = \"\"): Comment = Comment().apply { this.text = text }",
   "Comment", :problem],

  # The other side of the same rule, and the only thing pinning `KNOWN_HELPERS`.
  # `tag` is the serde discriminator a tagged-enum variant stamps onto its
  # payload: no `ast.rs` struct declares it, but a constructor that takes it is
  # not inventing a field — it is saying which spelling of the node this is.
  # Kotlin's 9 and Go's 41 `Type` members are the same claim in two languages, so
  # if this ever starts firing the report turns into noise nobody reads, and if
  # the list were widened without an `ast.rs` line to justify it, a real gap goes
  # quiet. Between this case and `colour` above the boundary is exact: `tag` is
  # exempt, `colour` is not.
  ["rule 3: a `KNOWN_HELPERS` parameter is not reported as drift",
   "fun comment(text: String): Comment = Comment().apply { this.text = text }",
   "fun comment(text: String, tag: String = \"\"): Comment = Comment().apply { this.text = text }",
   "Comment", :silent],

  # The one claim that is not visible in a signature. `literalIntType` returns
  # the `LiteralType` wrapper and fills the `IntLiteralType` payload inside, so
  # only the written-down entry in `WRAPPED_PAYLOADS` says the struct is
  # buildable. Rename the function and that entry stops matching — the struct
  # has to fall back into the unreachable list rather than staying quietly
  # covered.
  ["coverage: renaming `literalIntType` un-covers `IntLiteralType`",
   "fun literalIntType(value: Long, suffix: NumberBinarySuffix? = null): LiteralType = literalType(",
   "fun literalIntTypeRenamed(value: Long, suffix: NumberBinarySuffix? = null): LiteralType = literalType(",
   "IntLiteralType", :missing]
].freeze

# The PHP binding's constructors are generated (`php/src/Ast/AstBuild.php`),
# so a mutation is a scratch copy of that one file — `check_php` reads only
# it, not a directory of siblings. The same four rules are exercised:
# rule 2 (a field no constructor sets), rule 1 (a collection demanded
# instead of defaulted), rule 3 in both directions (a parameter naming no
# field, and a `KNOWN_HELPERS` spelling that must stay quiet), and the
# coverage direction (a renamed constructor un-reaches its struct).
PHP_SRC = File.read(File.expand_path("../php/src/Ast/AstBuild.php", __dir__))

PHP_CASES = [
  ["rule 2: `stringLit` stops accepting `rawValue`",
   "        bool $isLongString = false,\n        /** @var string */\n        string $rawValue = '',\n        /** @var string */\n        string $value = '',",
   "        bool $isLongString = false,\n        /** @var string */\n        string $value = '',",
   "StringLit", :problem],

  # Rule 1: `Vec` is never absent on the wire, so a constructor that demands
  # one is making the caller type `[]` at every level of the tree. The
  # generated default `= []` is the whole claim, and dropping it has to fire.
  ["rule 1: `configExpr` requires its items list",
   "        array $items = [],\n    ): ConfigExpr {",
   "        array $items,\n    ): ConfigExpr {",
   "ConfigExpr", :problem],

  # Rule 3: a parameter naming a field the core does not declare is drift in
  # the other direction — a constructor argument that goes nowhere.
  ["rule 3: `comment` grows a parameter `ast.rs` does not declare",
   "        string $text = '',\n    ): Comment {",
   "        string $text = '',\n        string $colour = '',\n    ): Comment {",
   "Comment", :problem],

  # The other side of the same rule, and the case pinning `KNOWN_HELPERS`:
  # `tag` is the serde discriminator a tagged-enum variant stamps onto its
  # payload, so a constructor that takes it is not inventing a field. Between
  # this and `colour` above the boundary is exact.
  ["rule 3: a `KNOWN_HELPERS` parameter is not reported as drift",
   "        string $text = '',\n    ): Comment {",
   "        string $text = '',\n        string $tag = '',\n    ): Comment {",
   "Comment", :silent],

  # The coverage direction. PHP's collector joins constructor to struct on
  # the *return type*, not the function name — renaming `missingExpr` would
  # still reach `MissingExpr` — so the mutation that un-reaches the struct
  # here is the constructor's deletion, which has to drop `MissingExpr` into
  # the unreachable list rather than leave it covered.
  ["coverage: deleting `missingExpr` un-reaches `MissingExpr`",
   "    public static function missingExpr(): MissingExpr\n    {\n        return new MissingExpr();\n    }\n",
   "",
   "MissingExpr", :missing]
].freeze

# The counters are globals that accumulate across every `compare`, so a case
# that asserted on `missing` would see whatever the cases before it reached.
# Each case starts from the full list or a coverage case proves nothing.
def reset_coverage(lang)
  COMPARED[lang] = 0
  REACHED[lang] = []
  CHECKED[lang] = []
  UNMAPPED[lang] = []
end

# The one case that is not a source mutation: a collector that stops matching
# its own binding must not be able to report "ok". `compared == 0` is the
# guard, and it is the reason the report prints a count at all.
#
# It runs under a name no binding uses, so the counters the mutations above
# filled are not the ones this asserts on. Sharing `kotlin` would make the case
# pass for the wrong reason: `report` would exit non-zero on a gap the mutated
# source left behind, and `compared.zero?` — the guard under test — would never
# be reached. The returned message is checked too, so a refusal for any other
# reason does not read as a pass.
def check_silent_binding
  lang = "no_such_binding"
  captured = StringIO.new
  original, $stdout = $stdout, captured
  begin
    code = report(lang, compare(lang, []))
  ensure
    $stdout = original
  end

  said = captured.string
  if code.zero?
    [false, "a collector that matched nothing was reported as ok"]
  elsif said.include?("0 constructors compared")
    [true, said.lines.first.strip]
  else
    [false, "refused, but not for `compared == 0`: #{said.lines.first.strip}"]
  end
end

# The exemption rules are the one place this checker could go wrong quietly:
# each one silences a parameter that `ast.rs` does not declare, so each has to
# be shown to silence *only* what it is entitled to. `DERIVED_TWIN` stands in
# for C's `Option` presence flag and list-length twin, and `ENUM_ARM_MEMBERS` for
# splitting a tagged enum into one member per arm — the first derives its base
# field, so it is only entitled to speak when that base really is a field of the
# same struct, and the second is keyed per struct so one node's claim cannot
# excuse another's.
#
# The failure these guard against is the rule 3 report going quiet because
# someone widened an exemption, which is exactly the kind of drift the README
# says the tables exist to prevent.
EXEMPTION_CASES = [
  # The twin of a real field resolves — this is the exemption working.
  ["DERIVED_TWIN silences a twin of a real field",
   -> { rust_field_for("c", "has_text", STRUCTS["Comment"], "Comment") == "text" }],

  # …and a twin of a field the struct does not have does not. If this resolved,
  # any binding could invent `has_anything` and rule 3 would never see it.
  ["DERIVED_TWIN stays quiet when the base is not a field",
   -> { rust_field_for("c", "has_colour", STRUCTS["Comment"], "Comment").nil? }],

  ["DERIVED_TWIN applies to the `_count` twin too",
   -> { rust_field_for("c", "colour_count", STRUCTS["Comment"], "Comment").nil? &&
         rust_field_for("c", "text_count", STRUCTS["Comment"], "Comment") == "text" }],

  # The twin's base resolves through the alias table, not just by exact name:
  # C's `main_package_count` is a twin of `main_package`, which is only a field
  # by way of `PARAM_ALIASES["c"]["main_package"]`.
  ["DERIVED_TWIN resolves its base through PARAM_ALIASES",
   -> { rust_field_for("c", "main_package_count", STRUCTS["SerializeProgram"], "SerializeProgram") == "pkgs" }],

  # `ENUM_ARM_MEMBERS` is keyed per struct: `int_value` means something about
  # `NumberLit` and nothing about any other node.
  ["ENUM_ARM_MEMBERS does not leak across structs",
   -> { rust_field_for("c", "int_value", STRUCTS["NumberLit"], "NumberLit") == "value" &&
         rust_field_for("c", "int_value", STRUCTS["SchemaAttr"], "SchemaAttr").nil? }],

  # And it is an allowlist, not a pattern: `colour` spells no field of
  # `NumberLit` and must still be reported.
  ["ENUM_ARM_MEMBERS exempts only what it names",
   -> { rust_field_for("c", "colour", STRUCTS["NumberLit"], "NumberLit").nil? }]
].freeze

def check_exemptions
  misses = 0
  puts "\nexemption self-tests:"
  EXEMPTION_CASES.each do |label, assertion|
    if assertion.call
      puts "  ok   #{label}"
    else
      puts "  MISS #{label}"
      misses += 1
    end
  end
  misses
end

# The outcome assertion shared by the kotlin and php mutation loops: which
# shape "the checker caught it" takes depends on the case's expectation, and
# all three matter — a rule that fires on the wrong struct, a coverage gap
# that goes unreported, and an exemption that has quietly stopped exempting
# are failures in three different directions.
def case_hit?(label, expect, struct, problems, lang)
  hit = case expect
        when :problem then problems.find { |p| p.start_with?("#{struct}:") }
        when :missing then (NODE_TYPES - REACHED[lang]).include?(struct) ? "#{struct}: no constructor reaches it" : nil
        when :silent then problems.none? { |p| p.start_with?("#{struct}:") } ? "#{struct}: correctly left alone" : nil
        end

  if hit
    puts "  ok   #{label}"
    puts "         -> #{hit}"
    return true
  end

  seen = if expect == :missing
           unreached = NODE_TYPES - REACHED[lang]
           unreached.include?(struct) ? "unreachable list is empty" : "reachable anyway: #{REACHED[lang].include?(struct)}"
         elsif expect == :silent
           named = problems.find { |p| p.start_with?("#{struct}:") }
           named ? "reported anyway: #{named}" : "the mutation did not land"
         elsif problems.empty?
           "ok"
         else
           "#{problems.length} unrelated: #{problems.first}"
         end
  puts "  MISS #{label}"
  puts "         -> checker said: #{seen}"
  false
end

def run
  misses = 0
  Dir.mktmpdir("ast-constructors") do |dir|
    scratch = File.join(dir, "AstBuild.kt")

    puts "rule self-tests (kotlin/AstBuild.kt):"
    KOTLIN_CASES.each do |label, good, bad, struct, expect|
      src = File.read(KOTLIN_SRC)
      unless src.include?(good)
        puts "  MISS #{label}"
        puts "         -> the constructor it mutates is not in AstBuild.kt any more"
        misses += 1
        next
      end

      File.write(scratch, src.sub(good, bad))
      reset_coverage("kotlin")
      ctors = check_kotlin(scratch)
      problems = compare("kotlin", ctors)
      misses += 1 unless case_hit?(label, expect, struct, problems, "kotlin")
    end

    php_scratch = File.join(dir, "AstBuild.php")

    puts "\nrule self-tests (php/AstBuild.php):"
    PHP_CASES.each do |label, good, bad, struct, expect|
      unless PHP_SRC.include?(good)
        puts "  MISS #{label}"
        puts "         -> the constructor it mutates is not in AstBuild.php any more"
        misses += 1
        next
      end

      File.write(php_scratch, PHP_SRC.sub(good, bad))
      reset_coverage("php")
      ctors = check_php(php_scratch)
      problems = compare("php", ctors)
      misses += 1 unless case_hit?(label, expect, struct, problems, "php")
    end
  end

  puts "\nreport self-test:"
  passed, why = check_silent_binding
  if passed
    puts "  ok   a collector that matched nothing is refused"
    puts "         -> #{why}"
  else
    puts "  MISS #{why}"
    misses += 1
  end

  misses + check_exemptions
end

misses = run
if misses.zero?
  puts "\nall self-tests passed"
  exit 0
end
puts "\n#{misses} self-test(s) missed"
exit 1
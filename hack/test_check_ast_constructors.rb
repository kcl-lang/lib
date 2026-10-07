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
# struct the report must name].
#
# Rule 2 (a field nothing can set) is the one with real teeth: the case nobody
# writes a test for is the one field a constructor forgot, and a constructor
# that drops a field silently produces a node the parser would never emit.
KOTLIN_CASES = [
  ["rule 2: `stringLit` stops accepting `rawValue`",
   "fun stringLit(value: String, isLongString: Boolean = false, rawValue: String? = null): StringLit = StringLit().apply {",
   "fun stringLit(value: String, isLongString: Boolean = false): StringLit = StringLit().apply {",
   "StringLit"],

  # `schemaExpr` is deliberately not used here. It has a sibling constructor,
  # `schemaConfig`, taking the same four parameters, and the rules judge a
  # struct over the *union* of its constructors — so dropping `config` from one
  # of them is not a gap a caller can hit, and the checker is right to stay
  # quiet. The case has to be a struct with a single constructor.
  ["rule 2: `ifExpr` stops accepting `orelse`",
   "fun ifExpr(body: NodeRef<Expr>? = null, cond: NodeRef<Expr>? = null, orelse: NodeRef<Expr>? = null): IfExpr = IfExpr().apply {",
   "fun ifExpr(body: NodeRef<Expr>? = null, cond: NodeRef<Expr>? = null): IfExpr = IfExpr().apply {",
   "IfExpr"],

  # Rule 1: `Vec` is never absent on the wire, so a constructor that demands
  # one is making the caller type `[]` at every level of the tree. This is the
  # exact shape a DTO's own required memberwise initialiser has.
  ["rule 1: `configExpr` requires its items list",
   "fun configExpr(items: List<NodeRef<ConfigEntry>> = emptyList()): ConfigExpr = ConfigExpr().apply { this.items = items }",
   "fun configExpr(items: List<NodeRef<ConfigEntry>>): ConfigExpr = ConfigExpr().apply { this.items = items }",
   "ConfigExpr"],

  ["rule 1: `module` requires its body list",
   "fun module(\n    filename: String,\n    doc: NodeRef<String>? = null,\n    body: List<NodeRef<Stmt>> = emptyList(),",
   "fun module(\n    filename: String,\n    doc: NodeRef<String>? = null,\n    body: List<NodeRef<Stmt>>,",
   "Module"],

  # Rule 3: a parameter naming a field the core does not declare is drift in
  # the other direction — a constructor argument that goes nowhere.
  ["rule 3: `comment` grows a parameter `ast.rs` does not declare",
   "fun comment(text: String): Comment = Comment().apply { this.text = text }",
   "fun comment(text: String, colour: String = \"\"): Comment = Comment().apply { this.text = text }",
   "Comment"]
].freeze

# The one case that is not a source mutation: a collector that stops matching
# its own binding must not be able to report "ok". `compared == 0` is the
# guard, and it is the reason the report prints a count at all.
#
# It runs under a name no binding uses, so the counters the five mutations above
# filled are not the ones this asserts on. Sharing `kotlin` would make the case
# pass for the wrong reason: `report` would exit non-zero on the seven gaps
# still missing from the mutated source, and `compared.zero?` — the guard under
# test — would never be reached. The returned message is checked too, so a
# refusal for any other reason does not read as a pass.
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

def run
  misses = 0
  Dir.mktmpdir("ast-constructors") do |dir|
    scratch = File.join(dir, "AstBuild.kt")

    puts "rule self-tests (kotlin/AstBuild.kt):"
    KOTLIN_CASES.each do |label, good, bad, struct|
      src = File.read(KOTLIN_SRC)
      unless src.include?(good)
        puts "  MISS #{label}"
        puts "         -> the constructor it mutates is not in AstBuild.kt any more"
        misses += 1
        next
      end

      File.write(scratch, src.sub(good, bad))
      ctors = check_kotlin(scratch)
      problems = compare("kotlin", ctors)
      hit = problems.find { |p| p.start_with?("#{struct}:") }
      if hit
        puts "  ok   #{label}"
        puts "         -> #{hit}"
      else
        seen = problems.empty? ? "ok" : "#{problems.length} unrelated: #{problems.first}"
        puts "  MISS #{label}"
        puts "         -> checker said: #{seen}"
        misses += 1
      end
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

  misses
end

misses = run
if misses.zero?
  puts "\nall self-tests passed"
  exit 0
end
puts "\n#{misses} self-test(s) missed"
exit 1
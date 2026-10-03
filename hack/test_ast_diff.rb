# frozen_string_literal: true

# Self-test for ast_diff.rb.
#
# The harness's whole claim is "these decoders agree". That claim is worthless
# if the harness says it about a decoder that was never run, a dump that came
# back empty, or a comparator that quietly accepts a shape it does not
# understand — a harness in that state reports "8 agreed" for a run in which
# eight dumpers wrote nothing.
#
# So every guarantee the harness makes is verified by breaking something on
# purpose and asserting the harness notices. Nothing here touches a binding in
# the repository. Same discipline as hack/test_check_ast_field_types.rb, and
# for the same reason: a checker that reports "ok" on a deliberately broken
# binding is worse than no checker.
#
# Usage: ruby hack/test_ast_diff.rb
#        ruby hack/test_ast_diff.rb ruby     # only the cases that need ruby
#
# Exit status is 0 only when every case was exercised and caught.

require "fileutils"
require "open3"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
$LOAD_PATH.unshift(File.join(ROOT, "hack"))
require "ast_diff/canonical"
require "ast_diff/bindings"

# `Canonical` and `bindings` live under `AstDiff`, and the real harness gets
# the short names by mixing the module into Object. A self-test that spelled
# them out in full would be a *different* set of names from the one under
# test, which is the sort of small divergence that lets a rename slip past.
include AstDiff # rubocop:disable Style/MixinUsage

GOLDEN = File.join(ROOT, "testdata/ast", "alignment.json")

# ---------------------------------------------------------------------------
# The cases
#
# There are two kinds, and the difference is the whole point of the second one.
#
# A MUTATION proves the harness can see a bug that was put there on purpose.
# That is the non-vacuity proof, but on its own it is a weak claim: a
# comparator that reports a difference for *any* input satisfies every
# mutation case, including the ones where the mutation did nothing. So each
# mutation is paired with a control — the identical scratch layout, the
# identical command, the identical comparator, with the one line left alone —
# which has to come back clean. The pair is the claim: *this* difference, and
# nothing else.
#
# An IN_TREE case needs no mutation at all, because the bug is genuinely in
# the repository right now. One of the findings this harness produced was that
# `lua`'s `NameConstantLit` coerced a string to a boolean, and that finding was
# worth more than any mutation because nobody told the harness where to look —
# it now lives in MUTATIONS instead, guarding the fix rather than the bug, which
# is what an IN_TREE case turns into the moment the decoder is corrected.
# ---------------------------------------------------------------------------

RUBY_AST  = "lib/kcl_lib/ast.rb"
LUA_AST   = "kcl_lib/ast.lua"
NODE_BASE = "src/ast/_types.mjs"

# [label, binding, source path relative to the binding's own directory, the
# correct line, the line that breaks it, and a matcher for the difference that
# must be reported]
MUTATIONS = [
  # -- the five-times-shipped Comment bug ------------------------------------
  # `ast::Comment` is a plain struct with a single `String` field, so the
  # object under `node` is `{"text": "…"}` and not the text. A decoder that
  # never looks inside it turns every comment in the file into the empty
  # string without raising. Five bindings shipped this.
  ["comment payload never looked into (the 5x bug)",
   "ruby", RUBY_AST,
   'Comment.new(text: AST.str(w, "text"))',
   'Comment.new(text: "")',
   %r{comments\[0\].*expected "# Every AST node shape.*got ""}],

  ["comment payload never looked into (the 5x bug)",
   "lua", LUA_AST,
   "    text = as_string(d.text, \"\"),",
   "    text = \"\",",
   %r{comments\[0\].*expected "# Every AST node shape.*got ""}],

  # -- a payload one nesting level too deep ----------------------------------
  # `ast::Identifier` is a plain struct `{names, pkgpath, ctx}`. Reading
  # `names` off the wrapper instead of off the payload yields nothing at all,
  # because the wrapper has no `names` key — which is the point: a wrong
  # lookup returns absent rather than raising.
  ["payload read one nesting level too deep",
   "nodejs", NODE_BASE,
   "    names: (w.names || []).map((/** @type {any} */ n) => " \
   "nodeFromWire(n, (x) => /** @type {string} */ x)),",
   "    names: [],",
   /module\.body\[\d+\]\.node\.typename\.node\.names: expected an array of 1, got an array of 0/],

  # -- a tag one variant off ------------------------------------------------
  # A `String` field that is declared but never assigned: the shape is right,
  # the tag is right, and every value is empty. This is the third of the three
  # bug classes, and it is the one that cannot be caught by reading a
  # comparator's output for a *missing* key — nothing is missing, it is just
  # blank.
  ["a field the decoder declares and never fills",
   "ruby", RUBY_AST,
   'ctx: AST.str(wire, "ctx")',
   'ctx: ""',
   /module\.body\[2\]\.node\.typename\.node\.ctx: expected "Load", got ""/],

  # -- the bug this harness found, now guarded --------------------------------
  # `NameConstant` is an enum with no serde tag, so serde writes it as a bare
  # JSON string, and all four spellings are truthy in Lua. Reading the field
  # with `as_bool` turned every one of them into `true`. This started as an
  # IN_TREE case — the bug was in the repository, asserted at its exact path —
  # and became a mutation when it was fixed, which is the better form: it says
  # the decoder has to keep reading a string, whether or not it currently does.
  ["untagged NameConstant coerced to a boolean",
   "lua", LUA_AST,
   'return { value = as_string(d.value, "") }',
   'return { value = as_bool(d.value, false) }',
   /module\.body\[32\]\.node\.value\.node\.value: expected "True", got true/],
].freeze

# [label, binding, matcher] — the difference is already there to be found.
#
# Empty, and deliberately so: this is where a bug that is in the repository
# right now gets pinned at its exact path, so that the only thing which can make
# it pass is the decoder being fixed rather than a comparison rule being
# widened until the difference stops being reported. `ast_diff.rb` reported one
# — lua's `NameConstant` above — and it was fixed, which emptied this list. The
# mechanism stays because the next finding will want it, and a binding that
# disagrees with the golden should not wait for someone to notice.
IN_TREE = [].freeze

# ---------------------------------------------------------------------------
# The scratch layout
#
# Every dumper finds its binding by a path relative to *something*, and the
# three answers are not the same answer:
#
#   * `hack/dump/lua.lua`  sets `package.path` relative to the *working
#     directory*, so `chdir` alone redirects it.
#   * `bindings.rb` passes `-Iruby/lib`, likewise working-directory relative.
#   * `hack/dump/nodejs.mjs` *imports* `../../nodejs/src/ast/index.mjs`, and an
#     ESM specifier resolves against the importing module's own URL — so
#     `chdir` does nothing at all and only moving the dumper moves the tree
#     it reads.
#
# So the scratch directory mirrors the repository's own layout, `hack/` and
# the binding both under it, and the dumper is run from inside it. One layout
# satisfies all three, and a case can then be written against any binding
# without knowing which of the three it is.
#
# The binding is *copied*, not linked, and that is not an accident of
# implementation. A symlink farm would be far smaller — nodejs is 3.7 GB, and
# almost all of it is `target/` — but Node's ESM loader resolves every
# specifier against the *realpath* of the importing module. A symlinked
# `nodejs/src/ast/index.mjs` therefore sends its own `./_types.mjs` import
# straight back to the real tree, and a mutation placed behind a symlink is
# never read at all. That is not hypothetical: it is how the first run of the
# nodejs case here reported "AGREED — the bug was not caught" against a
# mutation that was sitting in the scratch directory, correct and unread.
#
# So the copy is whole, minus the build outputs and vendored dependency trees
# below. They are excluded by name rather than by size, because a dumper that
# needed one of them would fail to start — and the control run says so before
# any case can pass on a broken premise. `node_modules` and `.dart_tool` are
# deliberately *not* on the list: they are dependencies a dumper genuinely
# loads, and at 84 MB and 34 MB they are cheaper than being wrong.
# ---------------------------------------------------------------------------

SKIP_DIRS = %w[target dist build venv __pycache__ .build .zig-cache zig-out
               .pytest_cache .mypy_cache .git].freeze

def copy_binding(src, dst)
  FileUtils.mkdir_p(dst)
  Dir.each_child(src) do |child|
    from = File.join(src, child)
    to = File.join(dst, child)
    if File.directory?(from)
      copy_binding(from, to) unless SKIP_DIRS.include?(child)
    else
      FileUtils.cp(from, to)
    end
  end
end

# Lay out `<dir>/hack` and `<dir>/<binding>`. `rel` is the path of the file a
# case mutates, relative to the binding's own directory, and `broken` is the
# whole replacement *file*, not the replacement line — a case that wrote the
# line over the file would leave a source that does not parse, which is a
# different failure and an uninteresting one. Both nil for the control run.
def lay_out(dir, binding_name, rel = nil, broken = nil)
  FileUtils.mkdir_p(dir)
  FileUtils.cp_r(File.join(ROOT, "hack", "."), File.join(dir, "hack"))
  copy_binding(File.join(ROOT, binding_name), File.join(dir, binding_name))
  File.write(File.join(dir, binding_name, rel), broken) if broken
end

# Splice `bad` over `good` in the whole of `src`. Both the single-occurrence
# and the changed-something assertions live here, and both are load-bearing: a
# target that matches nothing leaves the binding untouched and the case passes
# over a bug that was never introduced, and a second copy further down is a
# line the dumper may read instead of the one that was broken.
def splice(src, good, bad)
  offset = src.index(good)
  return [nil, :missing] if offset.nil?
  return [nil, :ambiguous] if src.index(good, offset + good.length)
  return [nil, :identical] if good == bad

  [src[0...offset] + bad + src[(offset + good.length)..], :ok]
end

# ---------------------------------------------------------------------------

def binding_named(name) = AstDiff.bindings.find { |b| b.name == name }

# The reason a binding cannot run *right now* is not a self-test failure — the
# point of `AstDiff.unrunnable` is that a missing toolchain is uninteresting.
# But silently passing every case because nothing ran would be exactly the
# vacuity this file exists to rule out, so a case whose binding cannot run
# here is reported and counted as not-exercised, never as a pass.
def skip_reason(name)
  b = binding_named(name)
  return "no such binding: #{name}" unless b

  b.probe.call
end

def run_dumper(dir, binding_name, tag)
  b = binding_named(binding_name)
  out = File.join(dir, "#{binding_name}-#{tag}.json")
  ok, err, status = Open3.capture3(
    *b.argv.call(GOLDEN, out), chdir: dir, unsetenv_others: false
  )
  return [nil, err] unless status.success? && File.file?(out) && !File.zero?(out)

  doc = JSON.parse(File.read(out))
  [doc["root"], err]
end

# The same Comparator the real harness builds, with the same per-binding
# renames and tolerated extras. A control run built any other way would
# disagree for reasons that have nothing to do with the case under test.
def compare(golden, root, binding_name)
  b = binding_named(binding_name)
  cmp = Canonical::Comparator.new(ignore_extra: b.extra_ok, renames: b.renames,
                                  class_renames: b.class_renames)
  cmp.compare(golden, root)
  cmp
end

# ---------------------------------------------------------------------------

puts "cross-language AST diff — self-test"
puts "  golden: #{GOLDEN.sub("#{ROOT}/", '')}"
puts

golden = JSON.parse(File.read(GOLDEN))
reference = Canonical.reference_counts(golden)
floor = (reference[:objects] * Canonical::Comparator::MIN_OBJECT_RATIO).floor

failures = 0
exercised = 0
not_exercised = 0

def report(label, binding_name, ok, detail)
  if ok
    puts "  ok             #{label} (#{binding_name})"
    puts "                -> #{detail}"
  else
    puts "  #{ok ? 'ok' : 'MISS'}           #{label} (#{binding_name})"
    puts "                -> #{detail}"
  end
end

# ---------------------------------------------------------------------------
# Control runs, one per binding a case needs.
#
# A mutation case says "the harness sees this difference". It does not say
# "the harness sees *only* this difference", and without the control it could
# not: a comparator broken enough to report a difference for everything would
# pass all four cases. So each binding's unmutated dump is run through the same
# scratch layout, the same command and the same comparator, and has to come
# back with no differences at all. The control also proves the scratch layout
# reaches a *real* decoder — a dumper that silently imported nothing would
# come back vacuous, and the vacuity guards would say so.
# ---------------------------------------------------------------------------

needed = (MUTATIONS.map { |c| c[1] } + IN_TREE.map { |c| c[1] }).uniq

# What each binding is *known* to differ by, right now, with no mutation.
# `lua` is not empty and must not be: it carries a real bug, and the report
# says so. A control that demanded a clean run would therefore be demanding
# that the bug be gone, which would make this file a fix-guard rather than a
# vacuity-guard — and would go red the moment somebody fixed `lua` for the
# wrong reason, by widening a comparison rule.
KNOWN = IN_TREE.group_by { |c| c[1] }.transform_values { |cs| cs.map { |c| c[2] } }

puts "controls — the unmutated tree, through the same scratch layout"
puts "  each must differ in exactly the ways this file claims, and no others"
needed.each do |name|
  reason = skip_reason(name)
  if reason
    puts "  NOT EXERCISED  control: #{name} — #{reason.lines.first.to_s.strip}"
    not_exercised += 1
    next
  end

  Dir.mktmpdir do |dir|
    lay_out(dir, name)
    root, err = run_dumper(dir, name, "control")
    if root.nil?
      puts "  SELF-TEST BUG  control: #{name} — the dumper did not run in the scratch layout"
      puts "                #{err.lines.last(3).join.strip}"
      failures += 1
      next
    end

    cmp = compare(golden, root, name)
    known = KNOWN.fetch(name, [])
    missing = known.reject { |m| cmp.diffs.any? { |d| m.match?(d.to_s) } }
    unexplained = cmp.diffs.reject { |d| known.any? { |m| m.match?(d.to_s) } }

    if missing.empty? && unexplained.empty? && cmp.unmapped.empty? &&
       cmp.counts[:objects] >= floor
      puts "  ok             control: #{name} — #{cmp.counts[:objects]}/#{reference[:objects]} " \
           "objects, #{cmp.diffs.size} known difference(s), 0 unexplained"
      exercised += 1
    else
      puts "  MISS           control: #{name} is not what this file claims, so its cases " \
           "prove nothing"
      puts "                #{if !cmp.unmapped.empty?
                               "unmapped: #{cmp.unmapped.uniq.join(', ')}"
                             elsif !missing.empty?
                               "expected but absent: #{missing.first.source}"
                             elsif !unexplained.empty?
                               "present but unexplained: #{unexplained.first}"
                             else
                               "only #{cmp.counts[:objects]}/#{reference[:objects]} objects"
                             end}"
      failures += 1
    end
  end
end

puts
puts "mutations — a bug put into a copy, and the harness has to see it"
MUTATIONS.each do |label, name, rel, good, bad, matcher|
  src_path = File.join(ROOT, name, rel)

  broken, why = splice(File.read(src_path), good, bad)
  case why
  when :ok then nil
  when :missing
    puts "  SELF-TEST BUG  #{label} (#{name})"
    puts "                #{good.inspect} no longer appears in #{name}/#{rel} —"
    puts "                the case is stale, not the harness"
    failures += 1
    next
  when :ambiguous
    puts "  SELF-TEST BUG  #{label} (#{name})"
    puts "                the correct line appears more than once, so the mutation"
    puts "                would not be the only broken copy the dumper can see"
    failures += 1
    next
  else
    raise "case substitutes an identical line"
  end

  reason = skip_reason(name)
  if reason
    puts "  NOT EXERCISED  #{label} (#{name})"
    puts "                #{reason.lines.first.to_s.strip}"
    not_exercised += 1
    next
  end

  Dir.mktmpdir do |dir|
    lay_out(dir, name, rel, broken)
    root, err = run_dumper(dir, name, "mutated")
    if root.nil?
      puts "  SELF-TEST BUG  #{label} (#{name})"
      puts "                the mutated binding did not run at all:"
      puts "                #{err.lines.last(3).join.strip}"
      failures += 1
      next
    end

    cmp = compare(golden, root, name)
    hit = cmp.diffs.find { |d| matcher.match?(d.to_s) }
    if hit
      report(label, name, true, hit.to_s)
      exercised += 1
    else
      seen = if !cmp.diffs.empty?
               cmp.diffs.first.to_s
             elsif !cmp.unmapped.empty?
               "unmapped: #{cmp.unmapped.uniq.join(', ')}"
             else
               "AGREED — the bug was not caught"
             end
      report(label, name, false, "comparator said: #{seen}")
      failures += 1
    end
  end
end

puts
puts "in the tree — bugs the harness found, asserted at the exact path"
IN_TREE.each do |label, name, matcher|
  reason = skip_reason(name)
  if reason
    puts "  NOT EXERCISED  #{label} (#{name})"
    puts "                #{reason.lines.first.to_s.strip}"
    not_exercised += 1
    next
  end

  Dir.mktmpdir do |dir|
    lay_out(dir, name)
    root, err = run_dumper(dir, name, "intree")
    if root.nil?
      puts "  SELF-TEST BUG  #{label} (#{name}) — the dumper did not run"
      puts "                #{err.lines.last(3).join.strip}"
      failures += 1
      next
    end

    cmp = compare(golden, root, name)
    hit = cmp.diffs.find { |d| matcher.match?(d.to_s) }
    if hit && cmp.counts[:objects] >= floor
      report(label, name, true, hit.to_s)
      exercised += 1
    else
      # The count matters as much as the difference here. A binding that
      # reported the right difference *and* decoded almost nothing would still
      # be a broken binding, and a case that only asserted the difference
      # would call it a pass.
      seen = hit ? "found #{hit}, but only #{cmp.counts[:objects]}/" \
                   "#{reference[:objects]} objects" \
                 : (cmp.diffs.empty? ? "AGREED — the bug was not caught" \
                                     : cmp.diffs.first.to_s)
      report(label, name, false, "comparator said: #{seen}")
      failures += 1
    end
  end
end

# ---------------------------------------------------------------------------
# The vacuity guards, asserted from both ends.
#
# A floor that has only ever been checked from above is a floor nobody has
# tested. These cases are the floor's two ends: a dump that resolved almost
# nothing must be refused as vacuous, and a dump that resolved everything must
# be accepted. Without both, `MIN_OBJECT_RATIO` could be raised until every
# binding was reported vacuous and the run would still "pass".
# ---------------------------------------------------------------------------

puts
puts "vacuity floor, asserted from both ends"

# The "everything" end: the golden compared against itself walks every object.
full = Canonical::Comparator.new
full.compare(golden, golden)
if full.counts[:objects] >= floor
  puts "  ok             the golden reaches #{full.counts[:objects]}/#{reference[:objects]} " \
       "objects, at or above the floor of #{floor}"
  exercised += 1
else
  puts "  MISS           the golden scores #{full.counts[:objects]}, under its own floor of " \
       "#{floor} — the floor cannot be met by anything"
  failures += 1
end

# The "nothing" end: a decoder that decoded no body at all. This is the shape
# the five-times-shipped bug takes when it truncates rather than blanks, and
# the harness must call it vacuous rather than agreeing with it.
empty = Canonical::Comparator.new
empty.compare(golden, { "body" => [], "comments" => [] })
if empty.counts[:objects] < floor
  puts "  ok             a dump with an empty body walks #{empty.counts[:objects]} objects, " \
       "under the floor of #{floor}"
  exercised += 1
else
  puts "  MISS           a dump with an empty body scores #{empty.counts[:objects]}, at or above " \
       "the floor of #{floor} — the floor does not exclude a decoder that decoded nothing"
  failures += 1
end

# The comment count, which is the guard that names the bug class by name.
comment_cmp = Canonical::Comparator.new
truncated = Marshal.load(Marshal.dump(golden))
truncated["comments"] = truncated["comments"].first(5)
comment_cmp.compare(golden, truncated)
if comment_cmp.counts[:objects] < reference[:objects]
  puts "  ok             a dump with 5 of #{golden['comments'].size} comments walks " \
       "#{comment_cmp.counts[:objects]}/#{reference[:objects]} objects — a truncated comment " \
       "list cannot pass unnoticed"
  exercised += 1
else
  puts "  MISS           a dump missing #{golden['comments'].size - 5} of " \
       "#{golden['comments'].size} comments still reaches " \
       "#{comment_cmp.counts[:objects]}/#{reference[:objects]} objects"
  failures += 1
end

puts
puts "#{exercised} exercised, #{not_exercised} not exercised (no toolchain), #{failures} failed"
exit(failures.zero? ? 0 : 1)

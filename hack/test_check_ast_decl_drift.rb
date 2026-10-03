#!/usr/bin/env ruby
# frozen_string_literal: true

# Self-test for check_ast_decl_drift.rb.
#
# `index.d.mts` is hand-written, `src/ast/*.mjs` is hand-written, and the only
# thing that notices when the two stop agreeing is the checker. A checker that
# prints "ok" over a broken pair is worse than no checker at all, so every claim
# it makes is verified here by breaking the pair on purpose and asserting the
# report names the right type *and* the right field.
#
# The check runs one way — what the loaders emit is what index.d.mts must
# contain — so the three kinds of drift are three different reports, and each is
# exercised on its own. The fourth case is the one that catches a checker that
# is quietly broken: the tree exactly as committed has to exit 0 and print its
# ok line. The last three exercise the guards, because a checker that skips its
# own input instead of failing on it reports "ok" for a binding it never read.
#
# The checker already takes a root override, `KCL_NODEJS_AST_DIR`, so every case
# lays a scratch copy of the binding out in a tmpdir and points the checker at
# that. Nothing under `nodejs/` is written to, so an interrupted run cannot
# leave the tree dirty. The loaders are read from the live tree at start-up, so
# the cases track it rather than going stale against it.
#
# Usage: ruby hack/test_check_ast_decl_drift.rb

require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
CHECKER = File.join(ROOT, "hack", "check_ast_decl_drift.rb")
AST_DIR = File.join(ROOT, "nodejs", "src", "ast")

# The checker's own MODULES list. The scratch tree has to hold exactly these six
# loaders — any more and tsc's common source directory moves, any fewer and the
# checker's `no such file` abort fires before the case under test does. The
# control case catches the list drifting under this one: if the checker starts
# reading a seventh loader, every scratch here is missing it and the control
# fails on the missing-file guard rather than quietly passing.
MODULES = %w[_base _types _dto _expr _stmt _module].freeze
LOADERS = MODULES.map { |m| "#{m}.mjs" }.freeze
DECLARATION = "index.d.mts"
FILES = (LOADERS + [DECLARATION]).freeze

COMMITTED = FILES.to_h { |f| [f, File.read(File.join(AST_DIR, f))] }.freeze

# The ok line is the checker's whole contract on success. `\d+` rather than a
# literal count because the loaders are under active development: pinning the
# number would make this test go red for somebody else's change, and the count
# is only ever read by the last case.
OK_LINE = /nodejs: ok \((\d+) declared types agree with the loaders\)/.freeze

# `Open3.capture3` answers `[stdout, stderr, status]`, and reading that as
# `[code, stdout, stderr]` leaves every assertion below comparing a Process::Status
# against a String — which fails confusingly rather than obviously. Named once,
# destructured never.
CheckResult = Struct.new(:code, :out, :err) do
  def text
    "#{out}#{err}"
  end
end

class DeclDriftSelfTest < Minitest::Test
  # `String#sub` replaces the first match and returns nil when nothing matched,
  # so a mutation that hit the wrong occurrence — or none — would look exactly
  # like a mutation that worked. Every anchor is therefore counted first, and a
  # count other than 1 is a bug in *this* file, reported as such.
  def rewrite(file, from, to)
    text = COMMITTED[file]
    count = text.scan(from).length
    assert_equal 1, count,
                 "self-test bug: #{from.inspect} occurs #{count} time(s) in #{file}, not 1 — " \
                 "the mutation below would not be the one its case claims to make"
    text.sub(from, to)
  end

  # Append `snippet` to a loader, proving first that the file does not already
  # contain it: an append needs no anchor, so without this it is the one
  # mutation here that could quietly do nothing.
  def append(file, snippet)
    text = COMMITTED[file]
    count = text.scan(snippet).length
    assert_equal 0, count,
                 "self-test bug: #{snippet.inspect} already occurs in #{file} — " \
                 "appending it would be a no-op rather than the break this case intends"
    text + snippet
  end

  # Lay the binding out the way the checker reads it — six loaders that import
  # each other by relative path, so they have to stay side by side, plus the
  # hand-written declaration — and return the directory to point it at. An
  # override of `nil` leaves the file out entirely, which is how the
  # missing-input guards are reached.
  def with_binding(overrides = {})
    Dir.mktmpdir("kcl-ast-decl-selftest") do |dir|
      FILES.each do |f|
        body = overrides.fetch(f, COMMITTED[f])
        File.write(File.join(dir, f), body) if body
      end
      yield dir
    end
  end

  def check(dir)
    stdout, stderr, status = Open3.capture3({ "KCL_NODEJS_AST_DIR" => dir }, RbConfig.ruby, CHECKER,
                                            chdir: ROOT)
    CheckResult.new(status.exitstatus, stdout, stderr)
  end

  # The ok line is printed on stdout and nothing else is, so "still says ok" is
  # decidable from stdout alone — and a drift report that also said ok would
  # mean the checker reported both, which is just as wrong as reporting neither.
  def refute_silently_ok(result)
    refute_equal 0, result.code,
                 "checker exited 0 on a deliberately broken binding — a silent pass is the " \
                 "exact failure this file exists to prevent.\n#{result.text}"
    refute_includes result.out, "nodejs: ok (",
                     "checker printed its ok line and a drift report at the same time.\n#{result.text}"
  end

  def report(label, hit)
    puts "  ok   #{label}"
    puts "         -> #{hit}"
  end

  # (a) A field the loaders produce is missing from the hand-written file. This
  # is the original bug the checker was written for: the loaders grew a field
  # and index.d.mts was not updated, so every caller read `undefined` off a
  # value the runtime always sets. `keyName` is unique in the file and belongs
  # to `SchemaIndexSignature` alone, so the report can only have come from here.
  def test_a_field_dropped_from_the_declaration_is_reported_as_missing
    broken = rewrite(DECLARATION, "  keyName?: Node<string>;\n", "")
    result = with_binding(DECLARATION => broken) { |dir| check(dir) }
    refute_silently_ok(result)
    hit = "SchemaIndexSignature: index.d.mts is missing keyName"
    assert_includes result.out, hit, "checker did not report the dropped field.\n#{result.text}"
    report "a field dropped from index.d.mts is reported as missing", hit
  end

  # (b) A field the hand-written file invents. The check is one-directional, so
  # this is the mirror of (a) and the only thing that catches it: a type whose
  # fields are all present but one invented still looks fine from the loaders'
  # side. `isADream` occurs nowhere in the file, so it is a field no loader
  # sets and no other case could produce.
  def test_a_field_no_loader_sets_is_reported_as_extra
    broken = rewrite(DECLARATION, "export interface Module {\n",
                     "export interface Module {\n  isADream?: boolean;\n")
    result = with_binding(DECLARATION => broken) { |dir| check(dir) }
    refute_silently_ok(result)
    hit = "Module: index.d.mts has isADream, which no loader sets"
    assert_includes result.out, hit, "checker did not report the invented field.\n#{result.text}"
    report "a field added to index.d.mts that no loader sets is reported as extra", hit
  end

  # (c) A type renamed on the handwritten side. Nothing is wrong with the fields
  # here — the whole type simply is not declared any more, so it is the name
  # comparison that has to fire. `export interface RuleStmt {` is the only place
  # the declaration is introduced; the second mention of the name is a member of
  # the `Stmt` union, which the rename deliberately leaves alone.
  def test_a_type_renamed_in_the_declaration_is_reported
    broken = rewrite(DECLARATION, "export interface RuleStmt {\n", "export interface RuleStatement {\n")
    result = with_binding(DECLARATION => broken) { |dir| check(dir) }
    refute_silently_ok(result)
    hit = "RuleStmt: the loaders produce it, index.d.mts never declares it"
    assert_includes result.out, hit, "checker did not report the renamed type.\n#{result.text}"
    report "a type renamed in index.d.mts is reported as undeclared", hit
  end

  # (d) The control. Every case above proves the checker fires; this one proves
  # it is not simply always firing. It is also the case that catches the two
  # ways this test could rot: a module the checker started reading that no
  # longer exists, and a loader the checker stopped reading.
  def test_the_binding_as_committed_is_clean
    result = with_binding { |dir| check(dir) }

    assert_empty result.err, "checker wrote to stderr on a clean tree.\n#{result.err}"
    assert_equal 0, result.code, "checker is red on the tree as committed.\n#{result.text}"
    match = OK_LINE.match(result.out)
    refute_nil match, "checker did not print its ok line.\n#{result.text}"
    assert_operator match[1].to_i, :>, 0,
                    "checker reported zero agreeing types, so `ok` is not saying anything"
    report "the binding as committed exits 0 and prints its ok line", match[0]
  end

  # (e) The guards. A checker whose own input has gone missing has to fail
  # loudly; the quiet alternative — an empty field set compared against an empty
  # field set — prints `ok` and is indistinguishable from a clean run. The first
  # two break the loaders the checker feeds to tsc, the last breaks the file it
  # compares them against.
  #
  # A syntax error is used rather than a deleted file so tsc is reached and
  # fails, which is the branch that matters: `npx tsc` also exits non-zero when
  # typescript is simply not installed, and that must not read as "no drift".
  def test_a_loader_tsc_cannot_compile_is_a_hard_failure
    broken = append("_types.mjs", "\n// self-test: deliberately unbalanced\nconst broken = (\n")
    result = with_binding("_types.mjs" => broken) { |dir| check(dir) }
    refute_silently_ok(result)
    hit = "check_ast_decl_drift: tsc failed while emitting the loaders' declarations"
    assert_includes result.err, hit, "a tsc failure was not reported as one.\n#{result.text}"
    report "a loader tsc cannot compile is a hard failure, not a clean run", hit
  end

  def test_a_missing_loader_is_a_hard_failure
    result = with_binding("_base.mjs" => nil) { |dir| check(dir) }
    refute_silently_ok(result)
    hit = "check_ast_decl_drift: no such file:"
    assert_includes result.err, hit, "a missing loader was not reported.\n#{result.text}"
    assert_includes result.err, "_base.mjs", "the report did not name the file.\n#{result.text}"
    report "a loader missing from the tree is a hard failure", "#{hit} …/_base.mjs"
  end

  def test_a_missing_declaration_is_a_hard_failure
    result = with_binding(DECLARATION => nil) { |dir| check(dir) }
    refute_silently_ok(result)
    hit = "check_ast_decl_drift: no such file:"
    assert_includes result.err, hit, "a missing index.d.mts was not reported.\n#{result.text}"
    assert_includes result.err, DECLARATION, "the report did not name the file.\n#{result.text}"
    report "a missing index.d.mts is a hard failure", "#{hit} …/index.d.mts"
  end

  # A loader that stops declaring anything used to shrink the comparison
  # instead of failing: `field_sets` folds every module into one namespace, so
  # gutting `_base.mjs` dropped the types it owned out of the run and the ok
  # line just reported a smaller number. An emptied or gutted loader is
  # precisely the shape of edit that would take `Node<T>` down with it, so the
  # checker now requires every module to own at least one type.
  #
  # tsc still emits a (near-empty) `_base.d.mts` for an empty input, so the
  # "tsc emitted no declaration" guard cannot see this — it is the per-module
  # contribution check that catches it.
  def test_an_emptied_loader_is_a_failure_not_a_shrunk_count
    clean_result = with_binding { |dir| check(dir) }
    assert_equal 0, clean_result.code,
                 "the unmutated tree is not clean, so there is nothing to compare against.\n" \
                 "#{clean_result.text}"

    result = with_binding("_base.mjs" => "") { |dir| check(dir) }
    refute_silently_ok result
    assert_includes result.out, "_base.mjs declares no AST type at all",
                    "the report did not name the module it lost.\n#{result.text}"
    report "an emptied loader fails and names the module", "_base.mjs declares no AST type at all"
  end

  # The guard above keys on "this module declares nothing". A module that still
  # declares *something* while having lost one of its types is the weaker edit,
  # and it must be caught by the ordinary field comparison instead — otherwise
  # the two cases would be the same test wearing different labels.
  # What this checker can and cannot see.
  #
  # It compares the *declaration* against the loaders' JSDoc, because that is
  # what tsc emits. It does not compare the JSDoc against the code — deleting
  # `orelse: …` from `ifStmtFromWire`'s returned literal leaves the `@property`
  # line standing, tsc still emits the field, and this check stays green. That
  # gap is closed by `tsc --checkJs` over `src/ast/*.mjs`, which is a separate
  # gate; asserting here that the field comparison catches a *code* edit would
  # be asserting something this checker does not claim to do.
  #
  # So the mutation is to the JSDoc, which is the surface this checker reads.
  def test_a_loader_whose_jsdoc_drops_a_field_is_caught
    gutted = rewrite("_stmt.mjs", / \* @property \{Array<MaybeNode<Stmt>>\} orelse\n/, "")

    result = with_binding("_stmt.mjs" => gutted) { |dir| check(dir) }
    refute_silently_ok result
    refute_includes result.out, "declares no AST type at all",
                    "the contribution guard fired even though _stmt.mjs still declares its types — " \
                    "this case is meant to prove the field comparison catches it on its own"
    assert_includes result.out, "IfStmt: index.d.mts has orelse, which no loader sets",
                    "the report did not name the type and the field.\n#{result.text}"
    report "a JSDoc field drop is caught and named", "IfStmt: index.d.mts has orelse, which no loader sets"
  end
end

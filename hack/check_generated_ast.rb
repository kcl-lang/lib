#!/usr/bin/env ruby
# frozen_string_literal: true

# check_generated_ast.rb — are the generated AST bindings still what the
# generator produces, and does the generator still believe what it emits?
#
# `python/kcl_lib/ast/`, `wasm/src/ast/`, `go/ast/` and `php/src/Ast/` used
# to be hand-written, and every binding's copy of the same declarations
# drifted from `ast.rs` on its own schedule. They are now generated from the
# Rust source by `tools/generate_ast.py`, which replaces them rather than
# sitting beside them. That solves the drift and creates one new way for it
# to come back: a generated file that nobody regenerates. A checked-in
# generated file is still a hand-written file the moment anyone edits it
# without re-running the tool, and nothing in any of the builds notices —
# `tsc` is perfectly happy with a stale interface, and so is `pytest`, and
# so is `php -l` and so is `go vet`.
#
# So this is a "regenerate and diff" check, run over the *bytes*:
#
#   1. `generate_ast.py --selftest` re-derives the load-bearing facts about the
#      wire format from `ast.rs` and asserts the model agrees, then generates
#      everything twice from two independent parses and compares the bytes. A
#      generator that is not deterministic is the failure mode that matters
#      most here, because it turns this very check into something that fails on
#      a clean tree — which is how contributors learn to ignore a checker.
#   2. `generate_ast.py --check` regenerates in memory and diffs against the
#      working tree, both ways: a file that is stale, and a file the generator
#      no longer emits at all (an orphan, which is what happens when a class is
#      renamed and the old file is left behind).
#
#   ruby hack/check_generated_ast.rb
#
# Exit status is 0 only if both pass. It does not check the generated code
# against the wire format — that is `hack/check_ast_field_types.rb`, which reads
# the *decoders* and compares them to the Rust field types, and
# `python/tests/ast_contract_test.py`, `wasm/tests/ast_contract.test.ts` and
# `go/ast/ast_contract_test.go`, which run them. This one asks a narrower
# question: does the checked-in text still match the tool that produced it.
#
# Set KCL_AST_RS to point at another checkout of `crates/ast/src/ast.rs`; the
# default is the `kcl` repository checked out as a sibling of this one, which is
# the layout `ast-shape-test.yaml` sets up.

require "open3"

ROOT = File.expand_path("..", __dir__)
GENERATOR = File.join("tools", "generate_ast.py")

def run(step, *args)
  puts "\n== #{step}"
  puts "   #{["python3", GENERATOR, *args].join(" ")}"
  ok = system("python3", GENERATOR, *args, chdir: ROOT)
  puts "   -> #{ok ? "ok" : "FAILED"}"
  ok
end

failures = []
failures << "self-test (model invariants + determinism)" unless run("self-test", "--selftest")
failures << "freshness (working tree vs generator)" unless run("freshness", "--check")

puts
if failures.empty?
  puts "generated AST bindings: ok (self-test, determinism, freshness)"
  exit 0
end

warn "generated AST bindings: #{failures.size} failing step(s):"
failures.each { |name| warn "  - #{name}" }
warn ""
warn "Run `python3 tools/generate_ast.py` and commit the result."
exit 1

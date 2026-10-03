#!/usr/bin/env ruby
# frozen_string_literal: true

# check_ast_decl_drift.rb — Is `nodejs/src/ast/index.d.mts` still telling the
# truth about `nodejs/src/ast/*.mjs`?
#
# The published declaration is hand-written, the loaders are hand-written, and
# nothing in the build ever compared them. That is not hypothetical: the file
# declared `Comment = Node<string>` while the loader returned the object under
# `node`, a `BasicType` with eight tags and an `isLiteral` flag that no code
# emits, and a `SchemaRefType` and `KeyValueType` that are not variants of
# `ast::Type` at all. A `tsc` run never caught any of it, because the repo's
# `tsconfig.json` includes `.` with the default extensions and `.d.mts` is not
# one of them — the file was not in the program.
#
# So the check works the other way round. `tsc` is perfectly good at turning
# the JSDoc into a declaration, and it already does: every module's `@typedef`
# is complete, so the emitted `_expr.d.mts` is the loaders' own account of what
# they return. Comparing the emitted field lists against the hand-written ones
# turns "somebody forgot to update the .d.mts" from an invisible bug into a
# non-zero exit.
#
# What it does *not* cover, because getting this wrong is how a checker starts
# lying: it compares the declaration against the JSDoc, not against the code.
# Delete a field from a loader's returned literal and the `@property` line is
# still there, tsc still emits it, and this check stays green. That leg is
# `tsc --checkJs` over `src/ast/*.mjs` — three descriptions, three checks:
#
#   index.d.mts  <-- this file            (declaration vs JSDoc)
#   JSDoc        <-- tsc --checkJs        (JSDoc vs code)
#   code         <-- the ava suite        (code vs the real parser)
#
#   ruby hack/check_ast_decl_drift.rb
#
# The comparison is on *field names*, per type. Types are matched by name, and
# the names are the ones `java/src/main/java/com/kcl/ast` uses — see the header
# of index.d.mts. Checking names rather than type text is deliberate: it is
# what actually drifts (a renamed field, a dropped one, a variant that stopped
# being decoded), and it does not break on a rewrite of the annotations.
#
# Set KCL_NODEJS_AST_DIR to point at another checkout of the nodejs binding.

require "open3"
require "tmpdir"
require "set"

ROOT = File.expand_path("..", __dir__)
AST_DIR = File.expand_path(ENV.fetch("KCL_NODEJS_AST_DIR", File.join(ROOT, "nodejs", "src", "ast")))
HANDWRITTEN = File.join(AST_DIR, "index.d.mts")
MODULES = %w[_base _types _dto _expr _stmt _module].freeze

# `export type Name = {` … `};` — a declaration this script can read. An
# intersection alias (`A & {type}`) is a different shape and is checked as a
# name only, which is all `CompClauseExpr` and friends are worth here.
DECL = /export type (\w+)\s*(?:<[^=]*?>)?\s*=\s*(\{.*?\n\};)/m
# The `?` is deliberately dropped. `x: T | undefined` (the key is always
# assigned, which is what these loaders do) and `x?: T` (the key may be absent)
# are different claims, and a `.mjs` JSDoc cannot cleanly express the second —
# `@property {T} [x]` reads as "absent", `@property {T|undefined} x` reads as
# "present but undefined", and the emitted `.d.mts` preserves that distinction
# while the hand-written file uses `?` throughout. Comparing names keeps the
# check about what actually drifts — a renamed, added or dropped field.
FIELD = /^\s{2,4}(\w+)\??[?:]/.freeze

# Collect `export type Name` regardless of the right-hand side, so a name that
# is only ever an alias still counts as present.
NAME = /^export type (\w+)/.freeze

def read(path)
  abort "check_ast_decl_drift: no such file: #{path}" unless File.file?(path)
  File.read(path)
end

# Emit the loaders' own declarations. If tsc is missing or unhappy this is a
# hard failure: a checker that quietly skips its own input is the exact bug
# class it exists to catch.
def emitted_declarations
  files = MODULES.map { |m| File.join(AST_DIR, "#{m}.mjs") }
  files.each { |f| abort "check_ast_decl_drift: no such file: #{f}" unless File.file?(f) }

  Dir.mktmpdir("kcl-ast-decl") do |out|
    cmd = [
      "npx", "--no-install", "tsc",
      "--allowJs", "--declaration", "--emitDeclarationOnly", "--strict",
      "--module", "node16", "--moduleResolution", "node16",
      "--target", "es2022", "--outDir", out, *files
    ]
    stdout, stderr, status = Open3.capture3(*cmd, chdir: File.join(ROOT, "nodejs"))
    unless status.success?
      warn "check_ast_decl_drift: tsc failed while emitting the loaders' declarations"
      warn stdout unless stdout.empty?
      warn stderr unless stderr.empty?
      exit 1
    end
    missing = MODULES.reject { |m| File.file?(File.join(out, "#{m}.d.mts")) }
    abort "check_ast_decl_drift: tsc emitted no declaration for: #{missing.join(' ')}" if missing.any?
    MODULES.to_h { |m| [m, read(File.join(out, "#{m}.d.mts"))] }
  end
end

# type name => [field, field, …]. A name emitted by two modules (`CheckExpr`
# was, until the duplicate was removed) contributes the union of both, so the
# check stays a statement about the whole API rather than about file order.
def field_sets(sources)
  sets = Hash.new { |h, k| h[k] = Set.new }
  sources.each_value do |src|
    src.scan(DECL) do |name, body|
      body.scan(FIELD) { |field, opt| sets[name] << "#{field}#{opt}" }
    end
  end
  sets
end

def declared_names(src)
  src.scan(NAME).flatten.to_set
end

# The hand-written file uses `interface` for object types and `type X = A | B`
# for the unions, so both spellings have to be read.
#
# `extends` matters: `interface TargetExpr extends Target` inherits `Target`'s
# fields rather than restating them, which is exactly how Java spells the same
# split. The base is recorded and folded in below, or every inherited type would
# read as having no fields at all.
def handwritten(src)
  names = src.scan(/^export (?:type|interface) (\w+)/).flatten.to_set
  own = Hash.new { |h, k| h[k] = Set.new }
  base = {}
  src.scan(/^export interface (\w+)(?: extends (\w+))?[^{]*\{(.*?)^\}/m) do |name, parent, body|
    base[name] = parent if parent
    body.scan(FIELD) { |field, opt| own[name] << "#{field}#{opt}" }
  end

  fields = Hash.new { |h, k| h[k] = Set.new }
  (names | own.keys).each do |name|
    seen = Set.new
    cur = name
    # A cycle cannot be written in TypeScript, but a malformed file should not
    # hang the checker either.
    while cur && !seen.include?(cur)
      seen << cur
      fields[name].merge(own[cur])
      cur = base[cur]
    end
  end
  [names, fields]
end

emitted_sources = emitted_declarations
emitted = field_sets(emitted_sources)
hand_names, hand_fields = handwritten(read(HANDWRITTEN))

problems = []

# `field_sets` folds every module into one namespace — a name two modules
# declare contributes the union — which is what makes it a statement about the
# whole API. The cost is that a loader which stops declaring anything drops
# silently out of the comparison: gut `_base.mjs` and the run still prints
# `ok`, just with a smaller number. Every module owning at least one type is
# the invariant that turns that back into a failure.
emitted_sources.each do |mod, src|
  next unless src.scan(DECL).flatten.empty?
  problems << "#{mod}.mjs declares no AST type at all — the comparison shrank instead of failing"
end

emitted.each do |name, fields|
  next if fields.empty?
  unless hand_names.include?(name)
    problems << "#{name}: the loaders produce it, index.d.mts never declares it"
    next
  end
  hand = hand_fields.fetch(name, Set.new)
  missing = fields - hand
  extra = hand - fields
  problems << "#{name}: index.d.mts is missing #{missing.to_a.sort.join(' ')}" if missing.any?
  problems << "#{name}: index.d.mts has #{extra.to_a.sort.join(' ')}, which no loader sets" if extra.any?
end

if problems.empty?
  puts "nodejs: ok (#{emitted.count { |_, f| f.any? }} declared types agree with the loaders)"
  exit 0
end

problems.each { |p| puts "  #{p}" }
puts "nodejs: #{problems.length} declaration drift(s) — index.d.mts no longer matches src/ast/*.mjs"
exit 1

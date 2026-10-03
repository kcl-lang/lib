#!/usr/bin/env ruby
# frozen_string_literal: true

# Cross-language AST consistency check.
#
# Every binding in this repository hand-rolls a decoder for the same parser
# output. `hack/check_ast_field_types.rb` reads those decoders' *source* and
# compares field names against the Rust struct definitions, which is the right
# check for a decoder that names a field wrongly — and blind to a decoder that
# names every field correctly and then reads the wrong one level of nesting.
# That second bug has shipped five times. Every occurrence produced `undefined`
# / `None` / `""` rather than raising, so every test in the tree passed:
# all 33 comments in the golden capture decoded to the empty string in nodejs,
# wasm, lua, .NET and later python, because Rust's `Comment` is a plain struct
# with one `String` field, so the object under `node` is `{"text": "…"}` and
# not the text itself.
#
# This runs each binding's real decoder over the same capture
# (`testdata/ast/alignment.json`) and diffs what comes out against the
# golden. See `hack/ast_diff/canonical.rb` for the canonical form and the six
# reductions applied to both sides.
#
#   ruby hack/ast_diff.rb                 # every binding whose toolchain is here
#   ruby hack/ast_diff.rb ruby lua         # only these
#   ruby hack/ast_diff.rb --keep          # keep the per-binding dump files
#   ruby hack/ast_diff.rb --out DIR       # write the dumps somewhere specific
#
# Exit status is 0 only when every binding that ran agreed with the golden.
# A binding that could not run is a skip, not a pass, and the summary says so
# in as many words: `4 agreed, 2 disagreed, 5 skipped, 0 vacuous`.

require "json"
require "fileutils"
require "open3"
require "tmpdir"

$LOAD_PATH.unshift(__dir__)
require "ast_diff/canonical"
require "ast_diff/bindings"

include AstDiff # rubocop:disable Style/MixinUsage

GOLDEN_REL = "testdata/ast/alignment.json"

# The number of top-level statements and comments the golden has. Both are
# cheap, exact, and load-bearing: a dumper that returned an empty tree, or a
# decoder that dropped the 33rd comment, lands here before the differ does
# any work at all.
EXPECTED_BODY = 63
EXPECTED_COMMENTS = 33

Result = Struct.new(:binding, :status, :detail, :diffs, :counts, :dump_path,
                    :payloads, :objects, :command, keyword_init: true)

def parse_argv(argv)
  only = []
  keep = false
  out = nil
  until argv.empty?
    case (a = argv.shift)
    when "--keep" then keep = true
    when "--out" then out = argv.shift
    when /\A-/ then abort "unknown flag #{a}"
    else only << a
    end
  end
  [only, keep, out]
end

only, keep, out_dir = parse_argv(ARGV)

golden_path = File.join(ROOT, GOLDEN_REL)
abort "golden capture not found at #{golden_path}" unless File.file?(golden_path)
GOLDEN = JSON.parse(File.read(golden_path))

# The reference is the golden, walked as-is: it needs no reduction of its own,
# because the differ reduces both sides by the same rules. What it does need
# is a count, so a dump that resolves nothing can be told apart from one that
# agrees.
base = Canonical.reference_counts(GOLDEN)
REFERENCE_OBJECTS = base[:objects]
REFERENCE_LEAVES = base[:leaves]


workdir = out_dir || Dir.mktmpdir("kcl-ast-diff")
FileUtils.mkdir_p(workdir)
at_exit { FileUtils.remove_entry(workdir) unless keep || out_dir }

puts "cross-language AST diff"
puts "  golden:    #{GOLDEN_REL} (#{GOLDEN['body'].size} body items, " \
     "#{GOLDEN['comments'].size} comments)"
puts "  reference: #{REFERENCE_OBJECTS} objects, #{REFERENCE_LEAVES} scalar leaves"
puts

# ---------------------------------------------------------------------------

def evaluate(b, dump_path)
  doc = JSON.parse(File.read(dump_path))

  unless doc["schema"] == Canonical::SCHEMA
    return Result.new(binding: b.name, status: :error, dump_path: dump_path,
                      detail: "dump declares schema #{doc['schema'].inspect}, " \
                              "expected #{Canonical::SCHEMA.inspect}")
  end

  root = doc["root"]
  unless root.is_a?(Hash)
    return Result.new(binding: b.name, status: :vacuous, dump_path: dump_path,
                      detail: "the dump has no root object")
  end

  # --- the vacuity guards, before anything is compared --------------------
  #
  # A comparator that reports "all bindings agree" about an empty file is
  # worse than no comparator, so these come first and they are exact rather
  # than statistical. Each of the three has actually fired during development:
  # a dumper that walked the wrong root, and a decoder that dropped every
  # comment.
  body = root["body"]
  comments = root["comments"]
  if !body.is_a?(Array) || body.size != EXPECTED_BODY
    return Result.new(binding: b.name, status: :vacuous, dump_path: dump_path,
                      detail: "the dump has #{body.is_a?(Array) ? body.size : 'no'} top-level " \
                              "statements; the golden has #{EXPECTED_BODY}")
  end
  if !comments.is_a?(Array) || comments.size != EXPECTED_COMMENTS
    return Result.new(binding: b.name, status: :vacuous, dump_path: dump_path,
                      detail: "the dump has #{comments.is_a?(Array) ? comments.size : 'no'} " \
                              "comments; the golden has #{EXPECTED_COMMENTS}. This is the " \
                              "shape the five-times-shipped Comment bug takes.")
  end

  cmp = Canonical::Comparator.new(ignore_extra: b.extra_ok, renames: b.renames,
                                   class_renames: b.class_renames)
  cmp.compare(GOLDEN, root)

  if !cmp.unmapped.empty?
    return Result.new(binding: b.name, status: :error, dump_path: dump_path,
                      detail: "unmapped class name(s): #{cmp.unmapped.uniq.sort.join(', ')}")
  end

  # A dump that walked far fewer objects than the golden cannot have agreed
  # about them; it agreed about the ones it happened to reach.
  floor = (REFERENCE_OBJECTS * Canonical::Comparator::MIN_OBJECT_RATIO).floor
  if cmp.counts[:objects] < floor
    return Result.new(binding: b.name, status: :vacuous, dump_path: dump_path,
                      counts: cmp.counts, objects: cmp.counts[:objects],
                      detail: "the dump walked #{cmp.counts[:objects]} objects; the golden has " \
                              "#{REFERENCE_OBJECTS} and the floor is #{floor} " \
                              "(#{Canonical::Comparator::MIN_OBJECT_RATIO} of that). A dump " \
                              "that resolved little cannot agree about much.")
  end

  Result.new(binding: b.name,
             status: cmp.diffs.empty? ? :agree : :disagree,
             diffs: cmp.diffs, counts: cmp.counts, dump_path: dump_path,
             payloads: cmp.payloads, objects: cmp.counts[:objects])
end

results = []

selected = AstDiff.bindings.reject { |b| !only.empty? && !only.include?(b.name) }
unknown = only - selected.map(&:name)
unless unknown.empty?
  abort "no such binding(s): #{unknown.join(', ')}\navailable: #{AstDiff.bindings.map(&:name).join(', ')}"
end

selected.each do |b|
  label = format("%-8s", b.name)
  reason = b.probe.call
  if reason
    results << Result.new(binding: b.name, status: :skipped, detail: reason)
    puts "#{label} SKIPPED  #{reason.lines.first.to_s.strip}"
    next
  end

  dump_path = File.join(workdir, "#{b.name}.json")
  begin
    argv = b.argv.call(GOLDEN_REL, dump_path)
    out, err, status = Open3.capture3(*argv, chdir: AstDiff::ROOT)
  rescue Errno::ENOENT => e
    results << Result.new(binding: b.name, status: :skipped, detail: "toolchain missing: #{e.message}")
    puts "#{label} SKIPPED  toolchain missing: #{e.message}"
    next
  end

  unless status.success?
    # The probe passed, so this is the decoder (or the dumper) failing, not
    # the toolchain. A decoder that raises on the golden is exactly the kind
    # of thing this harness exists to surface, so it is a failure.
    results << Result.new(binding: b.name, status: :error, command: argv.join(" "),
                          detail: "`#{argv.join(' ')}` exited #{status.exitstatus}\n#{err}")
    puts "#{label} FAILED   #{argv.join(' ')} exited #{status.exitstatus}"
    next
  end

  unless File.file?(dump_path)
    results << Result.new(binding: b.name, status: :error, command: argv.join(" "),
                          detail: "the dumper exited 0 but wrote nothing to #{dump_path}")
    puts "#{label} FAILED   dumper wrote no dump"
    next
  end

  r = evaluate(b, dump_path)
  r.command = argv.join(" ")
  results << r
end

# --- report ---------------------------------------------------------------

# What actually ran, and the exact command. A report that says "ten bindings
# agreed" and leaves the reader to guess what was executed is asking to be
# taken on trust, and this whole harness is about not asking for that. The
# command is the `argv` the run used, not a re-derivation of it, so it cannot
# drift from what happened.
puts "bindings run"
puts "-------------"
results.each do |r|
  next unless r.command

  b = AstDiff.bindings.find { |x| x.name == r.binding }
  # The per-binding dump path is a fresh temp directory on every run, so
  # printing it verbatim makes the line unreadable and changes on every run.
  # It is shown as `$OUT` and is reproducible: `--out DIR` puts the dumps
  # somewhere you chose, and the dumper takes the path as its second argument.
  cmd = r.command.gsub(workdir, "$OUT")
  puts "  #{format('%-8s', r.binding)} #{format('%-8s', b.mode)}  #{cmd}"
end
puts

agreeing = results.select { |r| r.status == :agree }
disagreeing = results.select { |r| r.status == :disagree }
failing = results.select { |r| r.status == :error }
skipped = results.select { |r| r.status == :skipped }
vacuous = results.select { |r| r.status == :vacuous }

# `&&`, not `||`: this section has to print when *either* list is non-empty.
# With `||` the common case — one binding disagrees, none crashed — prints
# nothing at all, which is the one case the reader most needs to see.
unless disagreeing.empty? && failing.empty?
  puts
  puts "disagreements"
  puts "-------------"
  disagreeing.each do |r|
    puts
    puts "#{r.binding} (#{r.diffs.size} difference(s)):"
    shown = r.diffs.first(12)
    shown.each { |d| puts "  #{d}" }
    puts "  … and #{r.diffs.size - shown.size} more" if r.diffs.size > shown.size
  end
end

unless vacuous.empty?
  puts
  puts "vacuous dumps"
  puts "------------"
  vacuous.each { |r| puts "  #{r.binding}: #{r.detail}" }
end

unless failing.empty?
  puts
  puts "run failures"
  puts "------------"
  failing.each do |r|
    puts
    puts "#{r.binding}: #{r.detail}"
  end
end

unless skipped.empty?
  puts
  puts "skipped (could not run here — not counted either way)"
  puts "--------------------------------------------------"
  skipped.each { |r| puts "  #{r.binding}: #{r.detail.to_s.lines.first.to_s.strip}" }
end

unrun = AstDiff.unrunnable
unless unrun.empty?
  puts
  puts "no dumper written"
  puts "---------------"
  unrun.each { |name, reason| puts "  #{name}: #{reason}" }
end

puts
puts "normalisations applied (count of times each rule fired)"
puts "----------------------------------------------------"
RULE_NAMES = {
  pos_hoisted: "R2  position hoisted out of a nested pos/position",
  empty_is_absent: "R4  empty sequence read as absent (includes the signed-off " \
                   "params_ty null→[] normalisation)",
  comment_as_bare_string: "R6  a Comment payload modelled as the bare text",
  adjacent_value_inlined: "R7  an adjacently-tagged `value` inlined into the class's fields",
  newtype_unwrapped: "R8  a newtype variant's single wrapper field compared through",
  newtype_payload_flattened: "R9  a newtype payload flattened into (tag, value) siblings",
  ambiguous_dto_tag: "R10 a class that is both a struct and a variant, used as the struct",
  raw_passthrough: "R12 a `type` key with no class behind it — the payload is the raw wire object",
  type_key_without_class_claim: "R12 a `type` key the class holds in a renamed field of its own",
  flattened_node_ref: "R13 a `NodeRef` whose payload the binding flattened onto the wrapper",
  null_element_as_false: "R14 a `null` list element read as `false` (Lua's json.null sentinel)",
  payload_fields_spread: "R15 an adjacently-tagged payload's fields spread as siblings of `value`"
}.freeze
ORDER = %i[pos_hoisted empty_is_absent comment_as_bare_string adjacent_value_inlined
           newtype_unwrapped newtype_payload_flattened ambiguous_dto_tag raw_passthrough
           type_key_without_class_claim flattened_node_ref null_element_as_false
           payload_fields_spread].freeze
(results.reject { |r| %i[skipped error].include?(r.status) }).each do |r|
  counts = r.counts || {}
  applied = ORDER.select { |k| counts[k].positive? }
  coverage = if r.objects
               "  [reached #{r.objects}/#{REFERENCE_OBJECTS} golden objects, " \
                 "#{counts[:leaves]} leaves]"
             else
               ""
             end
  if applied.empty?
    puts "  #{r.binding}: none#{coverage}"
  else
    puts "  #{r.binding}:#{coverage}"
    applied.each { |k| puts "      #{RULE_NAMES[k]} ×#{counts[k]}" }
  end
end

puts
puts "#{agreeing.size} agreed, #{disagreeing.size} disagreed, #{failing.size} failed to run, " \
     "#{skipped.size} skipped, #{vacuous.size} vacuous"
puts "(agreed + disagreed + failed + skipped must equal the number of bindings; " \
     "a binding that ran is never counted as skipped, and vice versa)"

exit(disagreeing.empty? && failing.empty? && vacuous.empty? && !agreeing.empty? ? 0 : 1)

# frozen_string_literal: true

# Cross-check every binding's AST field decoder against the Rust struct
# definitions in ../../kcl/crates/ast/src/ast.rs.
#
# Two shapes are checked, because both have bitten a binding at least once:
#
#   1. list vs single  — `Vec<T>` must be read with a list decoder. Reading a
#      list as a single node yields an empty result, silently.
#   2. payload type    — `NodeRef<Identifier>` and `NodeRef<String>` both
#      arrive as an object on the wire, but a decoder written for the wrong
#      one yields a zero-valued node rather than raising, because the string
#      reader substitutes "" for anything that is not a String.
#
# The two rules live in `compare` and are applied to whatever a per-language
# collector produces, so a binding cannot be held to a laxer standard than its
# neighbours by accident. A collector only has to answer three questions per
# field read: which Rust struct is this, which wire key, and is it a list
# decoded with what.
#
# A collector that stops matching reports success, which is worse than
# useless, so every run prints how many field decoders it actually compared
# and which structs it never reached. `test_check_ast_field_types.rb` breaks
# the decoders on purpose and asserts the rules fire.
#
# Usage: ruby hack/check_ast_field_types.rb [binding ...]

require "json"

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

# `struct` only, so an adjacently tagged enum is not here: `Type`,
# `NumberLitValue`, `StringLitValue` and `MemberOrIndex` are all
# `#[serde(tag = "type", content = "value")]` and all four are absent.
# `Type` is not a gap — it has its own tag registry and its own rules — and
# `NumberLitValue` is reached through the `NumberLit.value` field. `MemberOrIndex`
# is the one with nothing: its two payloads, `NodeRef<String>` under `Member` and
# `NodeRef<Expr>` under `Index`, are read by every binding and compared by none,
# because a read of a field Rust has no `struct` for is dropped by `compare`
# before it can be judged. Admitting it here would be a special case, and the
# general form — deriving fields from a content-tagged enum's newtype variants —
# asks every binding to read `Type` as six named fields, which none of them do.

# The wire name of each payload struct, so we can tell what a decoder should be
# reading. `NodeRef<Identifier>` and `NodeRef<String>` are the pair that
# matters most: both are objects on the wire, but they decode differently.
PAYLOAD_LOADER = {
  "Identifier" => "identifier",
  "String" => "string",
  "Expr" => "expr",
  "Type" => "type",
  "Stmt" => "stmt",
  "Target" => "target",
  "Keyword" => "keyword",
  "Arguments" => "arguments",
  "ConfigEntry" => "config_entry",
  "CheckExpr" => "check",
  "CallExpr" => "call_expr",
  "CompClause" => "comp_clause",
  "SchemaExpr" => "schema_expr",
  "SchemaIndexSignature" => "schema_index_signature",
  "Comment" => "comment",
  "MemberOrIndex" => "member_or_index"
}.freeze

# How many field decoders each checker actually compared, and which structs it
# resolved to versus actually inspected. The difference is the gap list, and
# computing it as a set difference rather than a running delete keeps it free
# of ordering artefacts: a struct reached twice, once with fields and once
# delegating, is covered.
COVERAGE = Hash.new(0)
REACHED = Hash.new { |h, k| h[k] = [] }
CHECKED = Hash.new { |h, k| h[k] = [] }

# Node-shaped reads for which the collector could name no payload at all, so
# rule 2 was skipped for want of information rather than because it passed.
# `compare` treats a nil payload as "nothing to say", which is the right default
# and a terrible place to be wrong: a collector whose loader table does not match
# its own source's spelling reports every read as nil and the binding comes out
# clean. Counting them makes that visible — it is the same instinct as the
# coverage count, applied to the payload half of the job.
UNRESOLVED = Hash.new(0)

def list?(type_string)
  type_string&.start_with?("Vec<", "Option<Vec<")
end

# Both rules are about node-shaped fields. A bare `String`, `bool` or enum is
# read the same way whatever its Rust type says, so `StringLit`
# (`{value: String, raw_value: String}`) is not something these rules can say
# anything useful about.
#
# This also decides which *structs* are worth walking and which fields are leaf
# payloads, so it stays narrow: widening it to admit bare structs made every
# all-scalar struct look unhandled and emptied the leaf rule. The narrow
# question it cannot answer — "is this one field a decoded value?" — is
# `node_payload_field?` below.
NODE_SHAPED = /\A(?:Option<)?(?:Node|NodeRef|Vec)</

def element_loader(type_string)
  return nil if type_string.nil?

  # Peel the wrappers before the lookup. `Option<Vec<NodeRef<T>>>` and
  # `Vec<Option<NodeRef<T>>>` both hide their payload behind a layer no flat
  # match can see, and optional node fields are common enough — every
  # `Option<NodeRef<Expr>>` in the tree — that leaving them wrapped would give
  # them a nil `want` and silence rule 2 on roughly a third of all reads, in
  # every binding at once.
  inner = type_string
  while (unwrapped = inner[/\A(?:Option|Vec)<(.+)>\z/, 1])
    inner = unwrapped
  end

  if (m = inner.match(/\ANodeRef<(.+)>\z/)) || (m = inner.match(/\ANode<(.+)>\z/))
    return PAYLOAD_LOADER[m[1]]
  end
  PAYLOAD_LOADER[inner]
end

# Whether the payload rule can say anything about *this one field*, which is a
# narrower question than `NODE_SHAPED` answers and has to be asked separately.
#
# `NODE_SHAPED` only admits wrappers, on the grounds that a bare `String` is
# read the same way whatever its type says. But a bare *struct* is not: Rust
# declares `DictComp.entry` as a plain `ConfigEntry`, so serde hands the
# `ConfigEntry` over whole and nodejs reads it with
# `configEntryFromWire(w.entry)` — no `node` hop at all. Reading that field
# with, say, the `Identifier` loader decodes it into the wrong shape and
# nothing notices, because the field type is not a wrapper.
#
# The two predicates are kept apart on purpose. `NODE_SHAPED` also decides which
# structs are worth walking and which fields are leaf payloads, and admitting
# bare structs there makes every all-scalar struct — `StringLit`, `Comment`,
# `Program` — look like one with no decoder, in every binding at once.
def node_payload_field?(type_string)
  return true if type_string.match?(NODE_SHAPED)

  inner = type_string.to_s
  inner = inner[/\A(?:Option|Vec)<(.+)>\z/, 1] while inner.match?(/\A(?:Option|Vec)</)
  # `STRUCTS`, not `PAYLOAD_LOADER`: the latter is keyed on `String` too, which
  # is exactly the scalar this is here to exclude.
  STRUCTS.key?(inner)
end

# A wire tag is not always unique: "If" is both `Expr::If(IfExpr)` and
# `Stmt::If(IfStmt)`, and "Schema" is both `Expr::Schema(SchemaExpr)` and
# `Stmt::Schema(SchemaStmt)`. The enclosing decoder is what disambiguates
# them, and without it every `IfStmt.body` is reported as a bug in
# `IfExpr.body` — which is a real list, read with a real list decoder.
#
# The keys are the bare stem of the decoder name, because that is what the
# per-language regexes capture: `/def self\.(\w+)_from_wire\(/` yields "expr",
# not "expr_from_wire". Keying on the full name matches nothing, and every
# tagged dispatch arm then goes unchecked without a word of complaint.
SCOPE_SUFFIX = { "expr" => "Expr", "stmt" => "Stmt", "type" => "Type" }.freeze

def resolve_tag(tag, scope)
  suffix = SCOPE_SUFFIX[scope]
  return tag if suffix.nil? || STRUCTS.key?(tag)

  named = "#{tag}#{suffix}"
  STRUCTS.key?(named) ? named : tag
end

def checkable?(struct)
  fields = STRUCTS[struct]
  return false if fields.nil?

  fields.each_value.any? { |t| t.match?(NODE_SHAPED) }
end

# ---------------------------------------------------------------------------
# The rules
# ---------------------------------------------------------------------------

# A field read is `{struct, key, is_list, payload}` where `payload` is the
# loader name the binding used, already mapped to the vocabulary above, or nil
# when the binding named no payload at all.
def compare(lang, reads)
  problems = []
  reads.each do |struct, key, is_list, payload|
    next unless checkable?(struct)

    rust = STRUCTS[struct]
    t = rust[key]
    next if t.nil?

    CHECKED[lang] << struct
    COVERAGE[lang] += 1

    if is_list != list?(t)
      problems << "#{struct}: `#{key}` read #{is_list ? 'as a list' : 'as a single node'} " \
                  "but Rust #{struct}.#{key} : #{t}"
      next
    end

    want = element_loader(t)
    # The payload rule is about what a node holds, so it says nothing about a
    # bare `String` or `bool` — those read the same way whatever they are read
    # into. A reader that hands back the raw JSON is only wrong for a
    # node-shaped field, and this is where that is decided.
    next if want.nil? || !node_payload_field?(t)
    if payload.nil?
      UNRESOLVED[lang] += 1
      next
    end

    # `payload` is a snippet of source, not a name, so the test is a substring
    # match. The comparison has to *skip on agreement*: falling through on a
    # match reports every correctly-decoded `Node<String>` field as a bug.
    next if want == "schema_expr" ? payload.include?("schema_expr") : payload.include?(want)

    problems << "#{struct}: `#{key}` is #{t} but is read with #{payload}"
  end
  problems
end

# ---------------------------------------------------------------------------
# Leaf payloads: the level between `node` and a scalar
#
# Every rule above asks *which* node a field holds. None of them asks what is
# inside it, and that is where the last binding bug was. `Comment` is a plain
# struct with one `String` field, so serde puts `{"text": "…"}` under `node`
# and the text is one level further in. A binding that reads the object under
# `node` as though it were the text gets `undefined` — or `""`, or `null`,
# depending on what its string reader substitutes for something that is not a
# string — for every comment in the file. Nothing it *declares* is wrong: the
# field set, the names and the types are all honest, which is precisely why a
# name-and-type cross-check calls it clean.
#
# So this rule is about the decoder's *body*, and it makes two demands:
#
#   1. it names one of the struct's fields as a key the wire supplies — a quoted
#      key, or a member that is read. A field name appearing only as the label
#      of the value being filled in is not evidence that it was read: Zig's
#      `.text = …` assignment target and every constructor argument named
#      `text:` are the same two tokens either way.
#   2. it unwraps `node` exactly once. Most `NodeRef` loaders call `load(inner)`
#      and hand the decoder the payload already lifted out; the `nodeFromWire`
#      family and C's `parse_comment_node` are handed the whole wrapper and
#      have to do it themselves. Unwrapping in the first case is the same bug
#      with the sign flipped — a key that is not there, read as though it were,
#      which is what Python's `Comment.from_dict` did while `Node.from_dict`
#      was already handing it the payload.
#
# `LEAF_POSITIONS` is derived rather than written down: a struct whose fields
# are all scalars is a leaf wherever it is read under a `node` wrapper. Today
# that is `Module.comments` and `Comment` and nothing else, so the second such
# struct in ast.rs needs no edit here.
# ---------------------------------------------------------------------------

def leaf_struct?(name)
  fields = STRUCTS[name]
  !fields.nil? && !fields.empty? && fields.each_value.none? { |t| t.match?(NODE_SHAPED) }
end

LEAF_POSITIONS = STRUCTS.flat_map do |struct, fields|
  fields.flat_map do |field, type|
    type.scan(/\b(?:NodeRef|Node)<(\w+)>/).flatten.uniq
        .select { |leaf| leaf_struct?(leaf) }
        .map { |leaf| [struct, field, type, leaf] }
  end
end.freeze

def pascalize(snake)
  snake.split("_").map { |w| w.sub(/\A./) { |c| c.upcase } }.join
end

def camelize(snake)
  words = snake.split("_")
  ([words.first] + words.drop(1).map { |w| w.sub(/\A./) { |c| c.upcase } }).join
end

# A decoder's *behaviour* is what is judged here, and a prose comment is not
# behaviour. Left in, a comment is enough to satisfy the rule — a decoder that
# only ever reads `""` passes as long as it explains itself — and one is enough
# to fail it: Python's `Comment.from_dict` carries five lines describing the
# double `node` unwrap it used to do, which is the exact token the rule looks
# for. The four comment syntaxes these bindings use cover every language here,
# and none of the decoders being read contains one inside a string literal.
LEAF_COMMENTS = [/\/\*.*?\*\//m, %r{//[^\n]*}, /--[^\n]*/, /#[^\n]*/].freeze

def leaf_code(body)
  LEAF_COMMENTS.reduce(body) { |src, re| src.gsub(re, " ") }
end

# A field name counts as read only as a *key the wire supplies* — quoted, or
# reached as a member that is not the assignment target. `text:` on the left of
# a constructor argument and `.text =` on the left of a Zig initialiser are the
# label of the value being filled in, and a decoder that never looks at the
# wire has both.
def leaf_reads_field(field)
  /(?:["':]\s*#{field}\b|\.\s*#{field}\b(?!\s*=(?!=)))/
end

# The wrapper's `node` key, named as one: a quoted key, `.node` off the wrapper,
# or a destructured `node`. `nodeFromWire` and `WireNode<…>` contain the word
# and mean nothing by it, which is why a bare `node` only counts when it is
# being bound.
LEAF_UNWRAPS = /(?:["':]\s*node\b|\.\s*node\b|(?<![.\w])node\s*[,}])/

# Which bindings hand their `Comment` decoder the whole `{"node": …}` wrapper
# rather than the payload with `node` already lifted out. Getting this backwards
# is not a weaker check, it is the wrong one — see demand 2 in `compare_leaf`.
#
# This is a property of the decoder's *call site*, not of the language, and
# nothing in this file can see the call site — so a binding listed here whose
# loader is actually invoked by `nodeFromWire` passes this rule while every
# comment in the tree decodes to `''`. That is not hypothetical: `typescript`
# sat here until its decoder was found reading `w.node` off a payload
# `nodeFromWire` had already lifted. The rule is a floor, not a proof; the
# proof is a decoder run against real output (`hack/ast_diff.rb`).
#
# `cpp` is not here and not absent for the usual reason. It is checked twice —
# once through the C header its C++ header wraps, once through its own decoder —
# and the two do not agree: `parse_comment_node` in C is handed the wrapper and
# lifts `node` itself, `parse_comment` in C++ is handed the payload. So the
# question is not per language; it is per decoder, and a `LEAF_DECODER` that
# returns a pair answers it directly.
LEAF_TAKES_WRAPPER = %i[nodejs c].freeze

# The decoder itself, per language. `src` is everything that binding's AST
# source concatenated, `leaf` the Rust struct name and `word` its payload name
# out of `PAYLOAD_LOADER`. Where a language's convention has a mechanical
# spelling it is derived from those two — `camelize(word)FromWire` for the JS
# pair, `parse_#{word}` for Lua — and where it does not the name is written out,
# as `SWIFT_LOADER` already writes out Swift's. Java has no decoder function at
# all: Jackson binds the field, so the annotation *is* the descent.
#
# Returning `[body, takes_wrapper]` overrides `LEAF_TAKES_WRAPPER` for that
# decoder. Only `:cpp` does, and only because it is the one language whose two
# decoders disagree about it.
LEAF_DECODER = {
  ruby:       ->(src, leaf, word) { src[/#{pascalize(word)}\.new\((.*?)\)/m, 1] },
  julia:      ->(src, leaf, word) { src[/^#{word}_from_wire\(w\) = #{leaf}\((.*)\)$/, 1] },
  lua:        ->(src, leaf, word) { src[/^local function parse_#{word}\(\w+\)(.*?)^end/m, 1] },
  dart:       ->(src, leaf, word) { src[/factory #{leaf}\.fromWire\([^)]*\)\s*=>\s*#{leaf}\((.*?)\);/m, 1] },
  python:     ->(src, leaf, word) { src[/(    def from_dict\(cls, d: Optional\[dict\]\) -> Optional\["#{leaf}"\]:)(.*?)\n\n/m, 2] },
  typescript: ->(src, leaf, word) { src[/export function #{camelize(word)}FromWire\((.*?)\n\}/m, 1] },
  dotnet:     ->(src, leaf, word) { src[/static #{leaf}\? #{leaf}FromWire\(JsonElement \w+\)(.*?)\n    \}/m, 1] },
  zig:        ->(src, leaf, word) { src[/pub fn parse\(alloc: Allocator, v: Value\) Error!#{leaf} \{(.*?)\n    \}/m, 1] },
  swift:      ->(src, leaf, word) { src[/^private func #{word}\(_ dict: \[String: Any\]\) -> #{leaf} \{(.*?)^}/m, 1] },
  nodejs:     ->(src, leaf, word) { src[/export function #{camelize(word)}FromWire\((.*?)\n\}/m, 1] },
  java:       ->(src, leaf, word) { src[/^public class #{leaf} \{(.*?)\n\}/m, 1] },
  c:          ->(src, leaf, word) { src[/static \w+\* parse_#{word}_node\(kcl_arena_t\* \w+, const kcl_json_value_t\* \w+\)(.*?)\n\}/m, 1] },
  # Kotlin compiles the same `com.kcl.ast` sources Java does, so it is the same
  # decoder as Java's under a different name. C++ used to sit here too, for the
  # same reason and no longer is: it has a decoder of its own in
  # `cpp/include/kcl_ast.hpp`, and that is the one its binding uses.
  kotlin:     ->(src, leaf, word) { src[/^public class #{leaf} \{(.*?)\n\}/m, 1] },
  # Go's `Comment` is reached through `CommentNode.UnmarshalJSON`, which lifts
  # `node` off the wrapper and hands the payload to `Comment.fromWire` -- so
  # the decoder is handed the payload, not the wrapper, and it must not unwrap
  # `node` a second time. That is `LEAF_TAKES_WRAPPER`'s default for Go, but
  # the slot is what makes it true: it is a per-decoder property, and here the
  # only decoder is a generated one whose call site is the slot's own
  # `UnmarshalJSON`.
  go:         ->(src, leaf, word) { src[/^func \(c \*#{leaf}\) fromWire\(d map\[string\]json\.RawMessage\) error \{(.*?)^\}/m, 1] },
  # C++ is checked through two headers, and each carries its own `Comment`
  # decoder with a different calling convention: the C one is handed the
  # `{"node": …}` wrapper and lifts `node` out of it, the C++ one is handed the
  # payload. The native spelling is tried first because it is the decoder the
  # binding actually uses — the C header is only reached through an `#include`.
  cpp: lambda { |src, leaf, word|
    native = src[/std::shared_ptr<#{leaf}> parse_#{word}\(const json::Value& value\)\n\{(.*?)\n\}/m, 1]
    next [native, false] unless native.nil?

    [src[/static \w+\* parse_#{word}_node\(kcl_arena_t\* \w+, const kcl_json_value_t\* \w+\)(.*?)\n\}/m, 1], true]
  },
  # PHP decodes with one generated `final class` per struct, one file each;
  # the class body runs to the closing brace at column 0. `Wire::nodeRef`
  # lifts `node` off the wrapper and hands the decoder the payload, so the
  # decoder must not unwrap again.
  php: ->(src, leaf, word) { src[/^final class #{leaf}\b.*?\n\{(.*?)^\}/m, 1] }
}.freeze

LEAF_CHECKED = Hash.new(0)

def compare_leaf(lang, src)
  problems = []
  LEAF_POSITIONS.each do |struct, field, type, leaf|
    fields = STRUCTS[leaf].keys.map { |f| "`#{f}`" }.join(" and ")
    word = PAYLOAD_LOADER[leaf]
    found = LEAF_DECODER[lang].call(src.to_s, leaf, word)
    body, takes_wrapper = found.is_a?(Array) ? found : [found, LEAF_TAKES_WRAPPER.include?(lang)]
    if body.nil?
      problems << "#{struct}: `#{field}` is #{type}, whose payload `#{leaf}` is a plain " \
                  "struct with #{fields}, and this binding has no decoder for it at all"
      next
    end

    LEAF_CHECKED[lang] += 1
    code = leaf_code(body)
    reads = STRUCTS[leaf].keys.any? { |f| leaf_reads_field(f).match?(code) }
    unwraps = LEAF_UNWRAPS.match?(code)
    unless reads
      problems << "#{struct}: `#{field}` is #{type}, whose payload `#{leaf}` is a plain " \
                  "struct with #{fields}: its decoder reads no field of it, so every " \
                  "one of them decodes to a zero value instead of raising"
      next
    end

    # Demand 2, both directions. A decoder that never unwraps is reading the
    # wrapper's own keys; one that unwraps when it was handed the payload is
    # reading a key that is not there. Both produce an empty value for every
    # entry, and neither is visible to anything above this line.
    if takes_wrapper
      next if unwraps

      problems << "#{struct}: `#{field}` is #{type} and its `#{leaf}` decoder is handed " \
                  "the whole wrapper, but it never looks under `node` — so the field it " \
                  "reads is the wrapper's own, and every value is empty"
    elsif unwraps
      problems << "#{struct}: `#{field}` is #{type}, whose `#{leaf}` decoder is handed " \
                  "the payload with `node` already lifted out, but it unwraps `node` " \
                  "again — so the field it reads is one that is not there"
    end
  end
  problems
end

# ---------------------------------------------------------------------------
# The captured parser output the leaf rule rests on
#
# `compare_leaf` asserts that a `Vec<NodeRef<Comment>>` decodes into a field of
# a struct rather than into the scalar itself. That is a claim about the *wire*,
# and it is checkable against what the parser actually emitted rather than only
# against a type declaration — which is the difference between this and a guess
# about serde. Every binding's alignment test decodes this same file, so a
# disagreement here is a disagreement with all of them at once.
# ---------------------------------------------------------------------------

ALIGNMENT_JSON = ENV.fetch("KCL_AST_ALIGNMENT") do
  File.expand_path("../testdata/ast/alignment.json", __dir__)
end
# The `.k` captures are read against, resolved relative to the repo root
# because every entry carries the `filename` it was parsed out of. A comment
# that is not verbatim in that file did not come from it.
ALIGNMENT_ROOT = File.expand_path("..", __dir__)

def alignment_sources(wire)
  names = wire.is_a?(Hash) ? wire.values.flat_map { |v|
    v.is_a?(Array) ? v.filter_map { |e| e.is_a?(Hash) ? e["filename"] : nil } : []
  } : []
  names.uniq.filter_map { |n|
    path = File.expand_path(n, ALIGNMENT_ROOT)
    File.read(path) if File.exist?(path)
  }
end

def comment_round_trip(path = ALIGNMENT_JSON)
  unless File.exist?(path)
    return [["#{path} not found - set KCL_AST_ALIGNMENT to the captured ast_json"], 0]
  end

  wire = JSON.parse(File.read(path))
  sources = alignment_sources(wire)
  problems = []
  seen = 0
  LEAF_POSITIONS.each do |struct, field, _type, leaf|
    # Only the one nesting the fixture spells out: a leaf read somewhere the
    # fixture does not carry is reported as unconfirmable rather than skipped
    # quietly, because a check that cannot look is not a passing check.
    entries = wire[field.to_s]
    unless entries.is_a?(Array) && !entries.empty?
      problems << "#{path}: no `#{field}` array to check `#{leaf}` against"
      next
    end

    entries.each_with_index do |entry, i|
      seen += 1
      payload = entry.is_a?(Hash) ? entry["node"] : nil
      unless payload.is_a?(Hash)
        problems << "#{path}: #{struct}.#{field}[#{i}] carries #{payload.inspect} " \
                    "under `node`; Rust #{leaf} is a plain struct, so serde puts a " \
                    "{#{STRUCTS[leaf].keys.map { |f| "#{f}: …" }.join(', ')}} object there"
        next
      end
      STRUCTS[leaf].each do |name, type|
        unless payload.key?(name)
          problems << "#{path}: #{struct}.#{field}[#{i}] has no `#{name}` on the " \
                      "object under `node`, which Rust #{leaf}.#{name} (#{type}) needs"
          next
        end
        # The round trip itself. What a decoder has to produce is the text the
        # parser saw, so a blank one is a decoder reading the wrong level even
        # when every key it looks for is spelled correctly, and a text that is
        # not verbatim in the source is not a round trip at all.
        value = payload[name]
        next unless value.is_a?(String)
        if value.strip.empty?
          problems << "#{path}: #{struct}.#{field}[#{i}].node.#{name} is blank, so " \
                      "a decoder that reads it turns a real comment into the empty string"
        elsif !sources.empty? && sources.none? { |src| src.include?(value) }
          problems << "#{path}: #{struct}.#{field}[#{i}].node.#{name} is not " \
                      "verbatim in #{entry['filename']}, so it does not round trip"
        end
      end
    end
  end
  [problems, seen]
end

# ---------------------------------------------------------------------------
# Ruby
# ---------------------------------------------------------------------------

RUBY_LOADERS = {
  "node_list" => nil, "nullable_node_list" => nil, "plain_list" => nil,
  "string_node_list" => "string", "string_node" => "string",
  "node_of" => nil, "string_list" => "string"
}.freeze

RUBY_PLAIN_STRUCT = {
  "Check" => "CheckExpr", "MemberOrIndex" => "Target",
  # `KclModule` is this binding's own name for Rust `Module`, the same rename
  # Dart and .NET made. Without it the AST root — `filename`, `doc`, `body`,
  # `comments` — is the one struct the collector cannot name, so it is the one
  # struct it never checks.
  "KclModule" => "Module"
}.freeze

# Ruby names a payload one of two ways: a snake_case helper
# (`expr_from_wire`, `schema_index_signature_from_wire`) or a constant's class
# method (`Identifier.from_wire`, `Check.from_wire`). Both are derived from
# `PAYLOAD_LOADER`, so Rust's `CheckExpr` reaches this binding as `check` and
# therefore as `Check.from_wire` with no alias to keep in step.
#
# Mapping the *name* rather than passing the call site through matters: the
# snippet `Identifier.from_wire(w)` does not contain the vocabulary word
# `identifier`, so `compare`'s substring test failed and every Ruby payload
# came through as nil — rule 2 silently never fired for this binding.
RUBY_PAYLOAD = PAYLOAD_LOADER.each_value.with_object({}) do |snake, acc|
  words = snake.split("_")
  acc["#{words.join('_')}_from_wire"] = snake
  acc["#{words.map { |w| w.sub(/\A./) { |c| c.upcase } }.join}.from_wire"] = snake
end.freeze

# `AST.` is required inside a `Struct.new` block, where `self` is the struct
# class rather than the module, so the qualifier is part of the shape. The
# snippet is the whole block body — `Identifier.from_wire(w)` — so the argument
# goes with it.
def ruby_payload(snippet)
  return nil if snippet.nil?

  name = snippet.strip.sub(/\AAST\./, "").sub(/\(.*\)\z/, "")
  return RUBY_PAYLOAD[name] if RUBY_PAYLOAD.key?(name)

  # A plain DTO is built inline rather than through a `*_from_wire` call —
  # `Module.comments` reads `Comment.new(text: str(w, "text"))` — so the
  # payload is named by the class the block constructs. `Comment` is the Rust
  # struct and `comment` is its payload word, so the same table resolves it.
  built = snippet[/(\w+)\.new\b/, 1]
  built && PAYLOAD_LOADER[ruby_struct_name(built.sub(/Expr\z/, ""))]
end

# Ruby spells the `Expr` variants `<Name>Expr`; Rust spells several of them
# `<Name>` (`Compare`, `JoinedString`, `Identifier`). Prefer an exact struct
# match, and only drop the suffix when the bare name is itself a struct —
# otherwise `IfExpr` would become `If`, which is not a struct at all.
def ruby_struct_name(klass)
  return nil if klass.nil?
  return klass if STRUCTS.key?(klass)

  bare = klass.sub(/Expr\z/, "")
  STRUCTS.key?(bare) ? bare : nil
end

def check_ruby(path)
  src = File.read(path)
  cur = nil
  scope = nil
  reads = []

  # A `when` arm names the class it builds on the next line, which is a far
  # more reliable link to the Rust struct than the tag: "If" is both
  # `IfExpr` and `IfStmt`, and "Identifier" is a struct *and* a variant.
  # Guessing from the tag alone silently attributes `IfStmt.body` to
  # `IfExpr.body`.
  expect_class = false

  # The plain DTOs are declared as `X = Struct.new(...) do def self.from_wire`
  # or `X = variant_class(...) do def self.from_wire`, so neither matches
  # `def self.<name>_from_wire`. Remember the constant being defined and use
  # it when the bare `from_wire` shows up.
  pending = nil
  # A wide declaration is wrapped, so `= Struct.new(` lands on the line after
  # the constant name: `SchemaIndexSignature =\n      Struct.new(...) do`. The
  # bare `Name =` holds the constant for exactly one line, and `held` is what
  # remembers it — folding this into `pending` would leave it set for the rest
  # of the file and swallow every read after the first wrapped declaration.
  held = nil

  src.each_line do |line|
    if held
      name, held = held, nil
      if line.match?(/^\s*(?:Struct\.new|variant_class)\(/)
        pending = name
        next
      end
    end
    if (m = line.match(/^\s*([A-Z]\w*)\s*=\s*$/))
      held = m[1]
      next
    end
    if (m = line.match(/^\s*([A-Z]\w*)\s*=\s*(?:Struct\.new|variant_class)\(/))
      pending = m[1]
      next
    end
    if (m = line.match(/def self\.from_wire\(w/))
      scope = nil
      cur = ruby_struct_name(RUBY_PLAIN_STRUCT.fetch(pending, pending))
      REACHED[:ruby] << cur unless cur.nil?
      next
    end
    if (m = line.match(/def self\.(\w+)_from_wire\(w/))
      scope = m[1]
      cur = { "identifier" => "Identifier", "target" => "Target", "keyword" => "Keyword",
              "arguments" => "Arguments", "config_entry" => "ConfigEntry",
              "check" => "CheckExpr", "schema_index_signature" => "SchemaIndexSignature",
              "member_or_index" => "Target", "comp_clause" => "CompClause",
              "call_expr" => "CallExpr", "schema_expr" => "SchemaExpr" }[m[1]]
      REACHED[:ruby] << cur unless cur.nil?
      next
    end
    if (m = line.match(/^\s*(?:when|elseif) "(\w+)"\s*$/))
      expect_class = true
      cur = resolve_tag(m[1], scope)
      next
    end
    if (m = line.match(/^\s*when "(\w+)" then (\w+)\.new/))
      expect_class = false
      cur = ruby_struct_name(m[2])
      REACHED[:ruby] << cur unless cur.nil?
      next
    end
    if expect_class && (m = line.match(/^\s*(\w+)\.new\(/))
      expect_class = false
      cur = ruby_struct_name(m[1])
      # A class name Rust does not know — `IdentifierExpr` — is a tagged
      # variant that delegates to a payload decoder checked elsewhere, so it
      # is not counted as reached. No `next`: `ParenExpr.new(expr: ...)` puts
      # its only field on this same line.
      REACHED[:ruby] << cur unless cur.nil?
    end
    # Not on any non-blank line: an arm may bind its payload to a local
    # first — `list = obj(value)` before `ListType.new` — and giving up at
    # the first such line is what left every `Type` variant unreached. Only a
    # line that starts a new construct ends the search.
    expect_class = false if line.strip.empty? || line.match?(/^\s*(?:when|else|case|def|end)\b/)
    next if cur.nil?

    # `AST.` is required inside a `Struct.new` block, where `self` is the
    # struct class rather than the module, so the qualifier is part of the
    # shape rather than noise.
    # The block is what names the payload, and it only comes into reach if the
    # call's own closing paren is consumed first: without the `\)` the optional
    # group starts on `)` and matches nothing, so every `node_of` / `node_list`
    # read arrived with no loader at all.
    #
    # The receiver is any identifier, not just `wire`: an adjacently tagged
    # `Type` arm binds its payload to a local first — `list = obj(value)` and
    # then `list["inner_type"]` — and requiring `wire` left all four `Type`
    # variants reached but not checked, which the gap list caught and the
    # "clean" line did not.
    m = line.match(/(\w+):\s*(?:AST\.)?(\w+)\(\w+\["(\w+)"\]\)(?:\s*\{\s*\|w\|\s*([^}]+))?/)
    next if m.nil? || !RUBY_LOADERS.key?(m[2])

    is_list = m[2].include?("list")
    payload = RUBY_LOADERS[m[2]] || ruby_payload(m[4])
    reads << [cur, m[3], is_list, payload]
  end
  compare(:ruby, reads) + compare_leaf(:ruby, src)
end

# ---------------------------------------------------------------------------
# Julia
# ---------------------------------------------------------------------------

JULIA_PLAIN_STRUCT = {
  "identifier" => "Identifier", "target" => "Target", "keyword" => "Keyword",
  "arguments" => "Arguments", "config_entry" => "ConfigEntry",
  "check" => "CheckExpr", "schema_index_signature" => "SchemaIndexSignature",
  "comp_clause" => "CompClause", "call_expr" => "CallExpr",
  "schema_expr" => "SchemaExpr", "comment" => "Comment"
}.freeze

JULIA_SCOPE_STRUCT = { "expr" => nil, "stmt" => nil, "type" => nil,
                      # `module_from_wire` builds a `KclModule`, this binding's
                      # own name for Rust `Module` — the rename Ruby, Dart and
                      # .NET made too. Left as nil, the AST root is the one
                      # struct the collector cannot name.
                      "module" => "Module",
                      "arguments" => "Arguments", "member_or_index" => "Target" }.freeze

# Julia names a decoder after the *payload*, not the Rust struct: Rust's
# `CheckExpr` is `check_from_wire`, and `SchemaIndexSignature` is
# `schema_index_signature_from_wire`. Both spellings reach the same table, so
# the payload is looked up rather than passed on as a raw source snippet —
# otherwise `target_from_wire` read into a `NodeRef<Expr>` field passes the
# substring test on the `expr` inside it.
JULIA_PAYLOAD = PAYLOAD_LOADER.flat_map { |rust, loader|
  snake = rust.gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase
  [["#{loader}_from_wire", loader], ["#{snake}_from_wire", loader]]
}.to_h.freeze

# Two receiver shapes. A tagged `Stmt`/`Expr` arm reads straight off `w` with
# a `get(w, "key", nothing)` default, because a missing key and a JSON `null`
# have to be told apart. An adjacently tagged `Type` arm cannot: its payload is
# under `value`, so it binds that to a local first and indexes it —
# `_obj(value)["inner_type"]` — and requiring `get(w, ...)` left all four
# `Type` variants reached but with no reads at all.
JULIA_FIELD = /
  _(\w+)\(get\(w,\s*"(\w+)",\s*nothing\)(?:,\s*(\w+))?
  | _(\w+)\(\w+(?:\([^)]*\))?\["(\w+)"\](?:,\s*(\w+))?
/x

# `entry = _asobj(get(w, "entry", nothing))` followed by
# `config_entry_from_wire(entry)` is a read whose key and loader are split
# across two statements — the one read in this binding that is not a wrapped
# node, so it has no `_node_of`/`_node_list` around it to carry the loader. The
# key is found and the loader is not, and rule 2 is then skipped for want of
# information rather than because it passed, which is reported as *unresolved*
# instead of as a gap. The pattern is in the file, it is just not adjacent, so
# the pairing is resolved over the whole source. The backreference is what ties
# them: the loader has to be the one consuming the local that was just bound,
# not some later call that happens to share a name.
JULIA_SPLIT_READ = /
  ^\s*(\w+)\s*=\s*_\w+\(\s*get\(\s*w\s*,\s*"(\w+)"\s*,\s*nothing\)\s*\)\s*\n
  \s*[^\n]*?\b([\w]+_from_wire)\(\s*\1\s*[,)]
/x

# A read can wrap: `_plain_list(get(w, "paths", nothing),\n
# member_or_index_from_wire)` puts the key on one line and the loader on the
# next, and a line-based scanner sees the first half with no loader and the
# second half with no key — so it reports the read as a `Vec` of strings and
# rule 2 is skipped. The scope is therefore collected as offset-anchored events
# in one pass and the reads scanned across the whole source in another, the
# same two-pass shape `check_python` uses.
def check_julia(path)
  src = File.read(path)
  reads = []
  scopes = []
  cur = nil
  scope = nil
  at = 0

  src.each_line do |line|
    start = at
    at += line.length
    if (m = line.match(/^function (\w+)_from_wire\(/))
      scope = m[1]
      cur = JULIA_SCOPE_STRUCT[m[1]]
      REACHED[:julia] << cur unless cur.nil?
      scopes << [start, cur]
      next
    end
    if (m = line.match(/^(\w+)_from_wire\(w\)/))
      scope = m[1]
      cur = JULIA_PLAIN_STRUCT[m[1]]
      REACHED[:julia] << cur unless cur.nil?
      scopes << [start, cur]
      # No `next`: the one-liner form puts every field on the defining line —
      # `identifier_from_wire(w) = Identifier(_string_node_list(get(w, "names",
      # nothing)), ...)` — and skipping it reports a struct as unchecked.
    end
    # `if v == "X"`, `elif tag == "X"` and `elseif tag == "X"` are the same
    # dispatch, and the `Type` decoder uses the third: matching only `if v ==`
    # left all four `Type` variants unreached, taking their fields with them.
    # `else?if` is not the three spellings — the `?` binds to the `e` — so the
    # optional parts are written out.
    if (m = line.match(/^\s*(?:el)?(?:se)?if \w+ == "(\w+)"/))
      cur = resolve_tag(m[1], scope)
      REACHED[:julia] << cur unless cur.nil?
      scopes << [start, cur]
    end
  end

  seen = 0
  # wire key -> loader, for the reads whose two halves are on different lines.
  split = src.scan(JULIA_SPLIT_READ).to_h { |_local, key, loader| [key, loader] }
  src.to_enum(:scan, JULIA_FIELD).each do
    pos = Regexp.last_match.begin(0)
    m = Regexp.last_match
    while seen < scopes.length && scopes[seen][0] <= pos
      seen += 1
    end
    cur = seen.zero? ? nil : scopes[seen - 1][1]
    next if cur.nil?

    helper, key, loader = m[1] ? ["_#{m[1]}", m[2], m[3]] : ["_#{m[4]}", m[5], m[6]]
    # `_string_node` on a `NodeRef<String>` is right; on anything else it is a
    # silent "". The helper names its own payload, so this covers the calls
    # that pass no loader argument.
    payload = helper.include?("string") ? "string" : JULIA_PAYLOAD[loader || split[key]]
    reads << [cur, key, helper.include?("list"), payload]
  end
  compare(:julia, reads) + compare_leaf(:julia, src)
end

# ---------------------------------------------------------------------------
# Lua
# ---------------------------------------------------------------------------

# `parse_x` -> the payload loader it delegates to, for the payload-type rule.
# The decoder is named after the *payload*, not the Rust struct — Rust's
# `CheckExpr` is `parse_check`, not `parse_check_expr` — so the table is keyed on
# the payload name. Deriving it from the Rust struct name instead produced a
# table whose one entry that mattered matched nothing, and `SchemaStmt.checks` /
# `RuleStmt.checks` came out with no payload at all.
LUA_PAYLOAD = PAYLOAD_LOADER.each_with_object({}) do |(_rust, loader), acc|
  acc["parse_#{loader}"] = loader
end.freeze

# Three decoders do not follow the `parse_<rust struct>` naming convention:
# `parse_check` is the `CheckExpr` DTO (Rust's struct is `CheckExpr`, the
# payload is `check`, and the name follows the payload), `parse_target_expr` is
# `Target`, and `parse_call_expr_variant` is the tagged `Expr` arm rather than
# the `CallExpr` DTO that `parse_call_expr` already decodes.
LUA_STRUCT = {
  "parse_check" => "CheckExpr",
  "parse_target_expr" => "Target",
  "parse_call_expr_variant" => "CallExpr",
  "parse_schema_expr_inner" => "SchemaExpr",
  # The AST root. `parse_module_dict` carries a `_dict` suffix because
  # `parse_module` is the JSON-string entry point, so the name-derived lookup
  # lands on `ModuleDict`, which is not a struct, and `filename` / `doc` /
  # `body` / `comments` go unchecked.
  "parse_module_dict" => "Module"
}.freeze

def lua_struct_name(fn)
  return LUA_STRUCT[fn] if LUA_STRUCT.key?(fn)

  name = fn.sub(/\Aparse_/, "").split("_").map(&:capitalize).join
  STRUCTS.key?(name) ? name : nil
end

def check_lua(path)
  src = File.read(path)
  cur = nil
  reads = []

  src.each_line do |line|
    if (m = line.match(/^local function (parse_\w+)\(/))
      cur = lua_struct_name(m[1])
      REACHED[:lua] << cur unless cur.nil?
      next
    end
    if (m = line.match(/^(\w+)\s*=\s*function\(/))
      cur = nil
      next
    end
    next if cur.nil?

    # `node_ref(x, scalar_loader(""))` reads a bare string payload, and the
    # type decoders take their argument as `t` rather than `d`, so neither the
    # receiver nor the argument list ends where a naive pattern expects.
    if (m = line.match(/=\s*node_ref_list\(\w+\.(\w+),\s*([\w.]+)/))
      # `scalar_loader` is the `NodeRef<String>` reader, so it names its own
      # payload. Comparing it rather than skipping it is how
      # `node_ref(d.attr, scalar_loader(""))` — an Identifier read as a String
      # — gets caught.
      payload = m[2] == "scalar_loader" ? "string" : LUA_PAYLOAD[m[2]]
      reads << [cur, m[1], true, payload]
    elsif (m = line.match(/=\s*node_ref\(\w+\.(\w+),\s*([\w.]+)/))
      payload = m[2] == "scalar_loader" ? "string" : LUA_PAYLOAD[m[2]]
      reads << [cur, m[1], false, payload]
    end
  end
  compare(:lua, reads) + compare_leaf(:lua, src)
end

# ---------------------------------------------------------------------------
# Dart
# ---------------------------------------------------------------------------

# `Check` is Dart's name for Rust `CheckExpr`; `AstFunctionType` is Dart's
# name for `FunctionType`. Neither follows the convention, and without the
# table their fields go unchecked — which is how a `Check` decoder reading
# `test` as a list would pass unnoticed. Declared before `DART_LOADER`, which
# derives one of its three loader spellings from it.
# `KclModule` is this binding's own name for Rust `Module`, the rename Ruby and
# .NET made too. Without it the AST root — `filename`, `doc`, `body`,
# `comments` — is the one struct the collector cannot name, and therefore the
# one struct it never checks.
DART_STRUCT = {
  "Check" => "CheckExpr", "AstFunctionType" => "FunctionType",
  "KclModule" => "Module"
}.freeze

# Dart spells a decoder three ways for the same payload: a top-level function
# named after the payload (`callExprFromWire`), a static method on the class
# named after the Rust struct (`Identifier.fromWire`), and a static method on
# the class named after *Dart's* name for it (`Check.fromWire`, where `Check` is
# Rust `CheckExpr`). The table that used to list only the second form left the
# other two unresolved — 9 reads, all of them the payload rule skipped. All
# three are derived here, so a payload added to Rust cannot be half-listed.
DART_LOADER = PAYLOAD_LOADER.each_with_object({}) do |(rust, payload), acc|
  words = payload.split("_")
  camel = ([words.first] + words.drop(1).map { |w| w.sub(/\A./) { |c| c.upcase } }).join
  acc["#{rust}.fromWire"] = payload
  acc["#{DART_STRUCT.key(rust) || rust}.fromWire"] = payload
  acc["#{camel}FromWire"] = payload
end.freeze

# Dart spreads the AST over several files, and the tagged dispatch lives in
# `expr.dart` / `stmt.dart` while the plain DTOs live in `dto.dart`. Only the
# dispatch files decide which class a tag builds, so they are the ones walked
# for arms; the rest contribute their `fromWire` factories.
DART_FILES = %w[expr.dart stmt.dart dto.dart types.dart module.dart].freeze

# Dart's class names follow the Rust struct names apart from the two in
# `DART_STRUCT`, and the `Expr` suffix is dropped when the bare name is itself a
# struct — so `SelectorExpr` resolves directly and `UnificationExpr` to
# `UnificationStmt`.
def dart_struct_name(klass)
  return nil if klass.nil?
  return DART_STRUCT[klass] if DART_STRUCT.key?(klass)
  return klass if STRUCTS.key?(klass)

  bare = klass.sub(/Expr\z/, "")
  STRUCTS.key?(bare) ? bare : nil
end

def check_dart(dir)
  reads = []
  blob = +""
  # `Comment` lives in `base.dart`, beside the wire helpers, and no field read
  # is anywhere near it — which is why it is not in `DART_FILES`. Reading it
  # here rather than widening that list keeps the field count honest: the file
  # is helper definitions, and letting it through the read collector would
  # count those definitions as decoders.
  base = File.join(dir, "base.dart")
  blob << "\n" << File.read(base) if File.exist?(base)
  DART_FILES.each do |name|
    path = File.join(dir, name)
    next unless File.exist?(path)

    src = File.read(path)
    blob << "\n" << src
    cur = nil
    src.each_line do |line|
      # `case 'Schema':` / `return SchemaStmt(` — the class on the `return` is
      # the one whose fields the following lines read.
      if (m = line.match(/^\s*case '(\w+)':/))
        cur = nil
        next
      end
      if (m = line.match(/^\s*return (\w+)\(/))
        cur = dart_struct_name(m[1])
        REACHED[:dart] << cur unless cur.nil?
        # No `next`: `return ParenExpr(expr: nodeOf<...>(...))` puts its only
        # field on this same line.
      end
      if (m = line.match(/^\s*(?:factory )?(\w+)\.fromWire\(/))
        cur = dart_struct_name(m[1])
        REACHED[:dart] << cur unless cur.nil?
        next
      end
      # A top-level DTO decoder written as a one-liner names the class on the
      # defining line — `SchemaExpr schemaExprFromWire(Map<..> w) => SchemaExpr(`.
      # No `next` for the same reason as `return`: its fields are on this line.
      if (m = line.match(/^\w[\w\s,<>]*\s+\w+FromWire\([^)]*\)\s*=>\s*(\w+)\(/))
        cur = dart_struct_name(m[1])
        REACHED[:dart] << cur unless cur.nil?
      end
      next if cur.nil?

      # The type decoders pull the payload into a local first
      # (`list['inner_type']`) and pass it positionally, so the receiver is
      # not always `w` and the `name:` prefix is not always there. The wire
      # key is in the bracket either way, which is what gets compared.
      m = line.match(/(?:(?:\w+):\s*)?(stringNode|nodeOf|nodeListOf|nullableNodeListOf|stringNodeListOf|plainListOf)(?:<[^>]*>)?\(\w+\['(\w+)'\](?:\s*,\s*([\w.]+))?\)?/)
      next if m.nil?

      is_list = m[1].include?("List") || m[1] == "plainListOf"
      payload = m[1].include?("string") ? "string" : DART_LOADER[m[3]]
      reads << [cur, m[2], is_list, payload]
    end
  end
  compare(:dart, reads) + compare_leaf(:dart, blob)
end

# ---------------------------------------------------------------------------
# Python
# ---------------------------------------------------------------------------

PYTHON_FILES = %w[_base.py _dto.py _expr.py _module.py _op.py _stmt.py _types.py].freeze

# `node_from_dict` with no loader is how this binding spells a `Node<String>`:
# `_base.py` documents it as "without one the raw dict is kept as-is (used for
# `Node<String>` and other scalar payloads)". So here the *absence* of a loader
# is the payload, and the opposite of the other bindings, where naming the
# string reader is what marks it.
PYTHON_LIST = %w[node_list_from_dict optional_node_list_from_dict].freeze

# The type decoders guard the lookup because the adjacently-tagged payload is
# not always a dict — `d.get("inner_type") if isinstance(d, dict) else None` —
# and that guard sits between the key and the loader. Left unconsumed, the
# optional loader group matches empty, and Python's "no loader means
# `Node<String>`" convention turns every such read into a false report.
PYTHON_GUARD = %r{\s+if\s+isinstance\([^)]*\)\s+else\s+\w+}
PYTHON_FIELD =
  /(\w+)\s*=\s*(node_from_dict|node_list_from_dict|optional_node_list_from_dict)\(\s*d\.get\("(\w+)"\)#{PYTHON_GUARD}?\s*(?:,\s*([\w.]+))?/

# Python names the payload in two ways, and a hand-written table of both is the
# third spelling trap in this file: `expr_from_dict` is a module-level function,
# `Identifier.from_dict` is a classmethod, and the table that mapped the first
# was fed the first component of the second, so every classmethod read arrived
# with a nil payload and rule 2 was skipped for all 32 of them. Deriving both
# spellings from `PAYLOAD_LOADER` leaves nothing to mistype: strip the
# `_from_dict` suffix, then either snake_case or the class name reaches the same
# table.
def python_loader(expr)
  return nil if expr.nil?

  name = expr.strip
  if name.end_with?(".from_dict")
    PAYLOAD_LOADER[name.delete_suffix(".from_dict")]
  elsif name.end_with?("_from_dict")
    words = name.delete_suffix("_from_dict").split("_")
    PAYLOAD_LOADER[words.map { |w| w.sub(/\A./) { |c| c.upcase } }.join]
  end
end

def python_struct_name(klass)
  return nil if klass.nil?
  return klass if STRUCTS.key?(klass)

  bare = klass.sub(/Expr\z/, "")
  STRUCTS.key?(bare) ? bare : nil
end

def check_python(dir)
  reads = []
  blob = +""
  PYTHON_FILES.each do |name|
    path = File.join(dir, name)
    next unless File.exist?(path)

    blob << "\n" << File.read(path)
    # Attribute each field read to the `def from_dict(...) -> "X":` above it.
    # Scanning the whole file rather than line by line is what makes a read
    # that wraps onto its continuation line — `index_signature=node_from_dict(`
    # and then `d.get("index_signature"), ...` — still one match: `\s*` spans
    # the newline, where a line-based scanner sees the two halves separately
    # and matches neither. The mirrored `*_to_dict` helpers cannot match, so
    # nothing is read out of a serializer by mistake.
    defs = src_defs(path)
    seen = 0
    File.read(path).to_enum(:scan, PYTHON_FIELD).each do
      at = Regexp.last_match.begin(0)
      m = Regexp.last_match
      # Advance to the last `from_dict` that opens above this read, recording
      # each struct as it is passed so the gap list can name the ones that
      # turned out to have no comparable fields.
      while seen < defs.length && defs[seen][0] < at
        REACHED[:python] << defs[seen][1] unless defs[seen][1].nil?
        seen += 1
      end
      next if seen.zero?

      cur = defs[seen - 1][1]
      next if cur.nil?

      # A missing loader is the payload: `_base.py` documents the bare
      # `node_from_dict` as how a `Node<String>` is read, so the absence has to
      # be told apart from a spelling the table does not know.
      payload = m[4].nil? ? "string" : python_loader(m[4])
      reads << [cur, m[3], PYTHON_LIST.include?(m[2]), payload]
    end
  end
  compare(:python, reads) + compare_leaf(:python, blob)
end

PYTHON_DEF = /^\s*def from_dict\([^)]*\) -> "(\w+)"/

def src_defs(path)
  File.read(path).to_enum(:scan, PYTHON_DEF).map do
    at = Regexp.last_match.begin(0)
    [at, python_struct_name(Regexp.last_match[1])]
  end
end

# ---------------------------------------------------------------------------
# TypeScript
# ---------------------------------------------------------------------------

TS_FILES = %w[_base.ts _dto.ts _expr.ts _module.ts _stmt.ts _types.ts].freeze

# The file a tagged dispatch lives in is what makes the tag unique — "If" is
# both `Expr::If(IfExpr)` and `Stmt::If(IfStmt)` — so the registry is read per
# file, with the same `SCOPE_SUFFIX` the other tagged bindings use.
TS_SCOPE = { "_expr.ts" => "expr", "_stmt.ts" => "stmt", "_types.ts" => "type" }.freeze

# `Type` is adjacently tagged, so a variant has no loader of its own to borrow a
# name from. `Any`, `Basic` and `Literal` are enums with no struct behind them
# and so have nothing to compare; the rest name theirs in the switch arm.
TS_TYPE = {
  "List" => "ListType", "Dict" => "DictType",
  "Union" => "UnionType", "Function" => "FunctionType"
}.freeze

TS_STRUCT = { "Check" => "CheckExpr" }.freeze

# `exprFromWire`, `schemaExprFromWire`, `_dto.callExprFromWire` … derived from
# the payload vocabulary rather than hand-listed, so a payload added to
# `PAYLOAD_LOADER` is spelled the same way here.
#
# The key is lowerCamel, which is the spelling the source actually calls — an
# earlier PascalCase key matched nothing, so 96 of the 107 reads below came
# through with no payload at all and rule 2 silently never fired for this
# binding.
TS_LOADER = PAYLOAD_LOADER.each_value.with_object({}) do |snake, acc|
  words = snake.split("_")
  camel = ([words.first] + words.drop(1).map { |w| w.sub(/\A./) { |c| c.upcase } }).join
  acc["#{camel}FromWire"] = snake
end.freeze

# A `Node<String>` is spelled as an inline arrow, in whichever of the forms the
# field's own type assertion happens to take: `(x: string) => x` where the input
# is already typed, `(x) => x as unknown as string` where it comes out of the
# `as unknown[]` array the list read cast the wire to, and `(x) => x` — a bare
# identity, with or without the parens an argument position forces on it. All
# three hand the payload back unchanged, which is what a `Node<String>` does, so
# the shape is what is matched: the arrow's body is its own parameter. The
# leading `\(*` and trailing `\)*` are what make the parenthesised spelling the
# same read rather than a fourth one, and `\z` after them is what keeps
# `(e) => stmtFromWire(e)` out — its body is a call, not the parameter.
TS_IDENTITY_ARROW = /\A\(*\(\s*(\w+)\s*(?::\s*[^()]*)?\)\s*=>\s*(\w+)\)*\z/.freeze

# A `Node<String>` is recognised by the assertion in the body, so an arrow that
# asserts to `string` is the string reader whatever its parameter is annotated.
def ts_payload(arg)
  arg = arg.to_s.strip.sub(/\s+as\s+never\z/, "")
  return "string" if arg.include?("(x: string") ||
                     arg.match?(/=>.*\bas\s+(?:unknown\s+as\s+)?string\b/)

  ident = arg.match(TS_IDENTITY_ARROW)
  return "string" if ident && ident[1] == ident[2]

  TS_LOADER[arg.split(".").last]
end

# A `nodeFromWire` call, with the module qualification the generated AST puts in
# front (`_base.nodeFromWire`) already allowed for. The keyed form is for the
# single read, which is the only shape that names the field in the call itself.
TS_CALL = /(?<![\w.])(?:[\w]+\.)*nodeFromWire\s*\(\s*\w+\.(\w+)/.freeze

# The list read cannot use that: its callback is handed the array element, not
# the wire object, so there is no `w.<key>` in the call to key off. That branch
# already has the key from the `((w.<key> as unknown[]) || [])` it starts at,
# and the first call after it *is* the callback's — matching the keyed form here
# skips the callback and names the next field's read instead, which is how
# `targets` came to be reported as read with `type`.
TS_ANY_CALL = /(?<![\w.])(?:[\w]+\.)*nodeFromWire\s*\(/.freeze

# The payload is the call's *second* argument, and taking it with a regex is what
# broke twice over. The call is module-qualified since the AST became generated,
# so an unanchored `nodeFromWire\(` optional group never matched and the
# "payload" came back as the literal text `_base.nodeFromWire`; and the second
# argument can be an inline arrow carrying parentheses of its own
# (`(x: string) => x as never`), so a lazy `(.+?)\)` stopped inside it and named
# no payload at all. Walking the balanced parens is what makes both spellings
# one read again, and a `Node<String>` is spelled one way or the other.
#
# `open` is the index of the call's own `(`, which is not the end of the match
# for the keyed form — that match ends on the key, and searching forward for a
# paren from there walks straight past this call into the next field's.
def ts_call_args(chunk, open)
  return [] unless chunk[open] == "("

  depth = 0
  args = [""]
  i = open
  while i < chunk.length
    case chunk[i]
    when "(", "[", "{" then depth += 1
    when ")", "]", "}" then depth -= 1
    when ","
      if depth == 1
        args << ""
        i += 1
        next
      end
    end
    args[-1] += chunk[i] if depth >= 1
    i += 1
    break if depth.zero?
  end
  args
end

# Where a `TS_CALL`/`TS_ANY_CALL` match's opening paren sits.
def ts_call_open(m) = m.begin(0) + m[0].index("(")

def ts_struct_name(klass)
  return nil if klass.nil?
  return TS_STRUCT[klass] if TS_STRUCT.key?(klass)
  return klass if STRUCTS.key?(klass)

  bare = klass.sub(/Expr\z/, "")
  STRUCTS.key?(bare) ? bare : nil
end

def check_typescript(dir)
  reads = []
  blob = +""
  TS_FILES.each do |name|
    path = File.join(dir, name)
    next unless File.exist?(path)

    src = File.read(path)
    blob << "\n" << src
    scope = TS_SCOPE[name]

    # `REGISTRY` maps a wire tag to the function that decodes it, and the tag
    # plus the file names the struct. The functions in `_dto.ts` are not in any
    # registry, so they fall back to their return type annotation, and
    # `schemaExprFromWire` — which returns `Record<string, unknown>` because it
    # decodes an untagged payload — falls back further to its own name. The
    # declaration is matched line by line rather than with `[^=]*=`: its type
    # annotation contains `=>`, so a `=` -anchored match stops in the middle of
    # it and the literal is never found.
    registry = src[/^const REGISTRY[^\n]*\n(.*?)\n\};/m].to_s.scan(/^\s*(\w+):\s*([\w.]+)/)
    by_fn = registry.to_h { |tag, fn| [fn.split(".").last, ts_struct_name(resolve_tag(tag, scope))] }

    # `_types.ts` is the one file with no `REGISTRY`: `Type` is a runtime
    # `switch (tag)`, and an adjacently tagged variant has no function of its
    # own to borrow a name from. Its arms are split out the same way the
    # Node.js collector splits `case` labels, or every one of `ListType`,
    # `DictType`, `UnionType` and `FunctionType` goes unreached and takes
    # their fields with it — invisible to the gap list, which only sees a
    # struct that was reached and not checked.
    src.split(/\n(?=(?:export )?function )|\n(?=\s*case ')/).each do |chunk|
      fn = chunk[/\A(?:export )?function (\w+FromWire)\b/, 1]
      tag = chunk[/\A\s*case '(\w+)'/, 1]
      next if fn.nil? && tag.nil?

      cur = (tag && TS_TYPE[tag]) || (fn && by_fn[fn]) ||
            ts_struct_name(chunk[/\):\s*(\w+)\s*\|/, 1]) ||
            (ts_struct_name(fn.sub(/FromWire\z/, "").sub(/\A[a-z]/, &:upcase)) if fn)
      next if cur.nil?

      REACHED[:typescript] << cur

      # A list read is spelled three ways, and they do not all name the key in
      # the same call: `mapNodes(w.args, ...)` names it in the first argument,
      # while `((w.args as unknown[]) || []).map(...)` names it in the array
      # and the loader only further along. Collect the array keys first so a
      # `nodeFromWire` on the same key is not also counted as a single node.
      lists = chunk.enum_for(:scan, /\(\(\w+\.(\w+) as unknown\[\]\) \|\| \[\]\)/)
                   .map { [Regexp.last_match[1], Regexp.last_match.begin(0)] }.to_h
      lists.each do |key, at|
        # `map(` and its callback are often split across lines — a long
        # `nodeFromWire` call inside a list literal is what pushes them apart —
        # so the arrow is allowed its own line. The call itself is then read by
        # walking its parens, which does not care how far apart they are.
        call = TS_ANY_CALL.match(chunk, at)
        reads << [cur, key, true, ts_payload(ts_call_args(chunk, ts_call_open(call))[1])] if call
      end
      chunk.scan(/mapNodes\(\s*\w+\.(\w+)[^,]*,\s*([\w.]+)/) do |key, loader|
        reads << [cur, key, true, ts_payload(loader)]
      end
      # The list read with no loader to call: `Compare.ops` is `Vec<CmpOp>`, a
      # list of bare JSON strings, so it is copied with a cast rather than
      # mapped. Nothing else in the tree is spelled this way, and a collector
      # with no pattern for it does not report a gap -- the field is simply not
      # among the reads, so the list rule has nothing to compare it against and
      # a change that made it a single node would pass unremarked. The payload
      # rule skips it anyway (`CmpOp` is not node-shaped), which is exactly why
      # only the list rule has anything to say here.
      #
      # `lists` holds the keys the `as unknown[]` form already claimed: the
      # inner `(w.x as unknown[]) || []` matches this pattern too, and claiming
      # it twice would hand the payload rule a second, wrong payload for a field
      # that is read correctly.
      chunk.enum_for(:scan, /\(\s*w\.(\w+) as ([\w.<>\[\]| ]+?)\[\]\s*\) \|\| \[\]/).each do
        m = Regexp.last_match
        next if lists.key?(m[1])

        reads << [cur, m[1], true, m[2].strip]
      end
      chunk.enum_for(:scan, TS_CALL).each do
        m = Regexp.last_match
        key = m[1]
        next if lists.key?(key)

        reads << [cur, key, false, ts_payload(ts_call_args(chunk, ts_call_open(m))[1])]
      end
    end
  end
  compare(:typescript, reads) + compare_leaf(:typescript, blob)
end

# ---------------------------------------------------------------------------
# C#
# ---------------------------------------------------------------------------

NET_FILES = %w[Base.cs Dto.cs Expr.cs Module.cs Stmt.cs Type.cs].freeze

# Same collision as everywhere else: "If" is both `Expr::If(IfExpr)` and
# `Stmt::If(IfStmt)`, and only the file the `switch` sits in tells them apart.
NET_SCOPE = { "Expr.cs" => "expr", "Stmt.cs" => "stmt", "Type.cs" => "type" }.freeze

# .NET names a decoder after the *Rust struct*, not the payload: Rust's
# `CheckExpr` is `DtoLoader.CheckExprFromWire`, and `MemberOrIndex` is
# `MemberOrIndexFromWire`. Deriving the table from the payload name instead
# produced `CheckFromWire`, which matches nothing — so every `CheckExpr` read and
# every `Decorator` read arrived with no payload and rule 2 was skipped for 5 of
# them. Both spellings are derived here.
#
# `Decorator` is .NET's own name for Rust `CallExpr`: it declares exactly Rust
# `CallExpr`'s `func`/`args`/`keywords` as a plain untagged struct, so the two are
# the same object on the wire and the alias is a naming choice, not a deviation.
# `SchemaConfig` is the same rename of Rust `SchemaExpr` that Ruby, Julia and Dart
# made — `name`/`args`/`kwargs`/`config`, field for field.
NET_ALIAS = { "Decorator" => "CallExpr", "SchemaConfig" => "SchemaExpr" }.freeze

def net_pascal(snake)
  snake.split("_").map { |w| w.sub(/\A./) { |c| c.upcase } }.join
end

NET_LOADER = PAYLOAD_LOADER.each_with_object({}) do |(rust, payload), acc|
  acc["#{net_pascal(payload)}FromWire"] = payload
  acc["#{rust}FromWire"] = payload
  acc["#{NET_ALIAS.key(rust) || rust}FromWire"] = payload
end.freeze

def net_payload(arg)
  arg = arg.to_s.strip.sub(/!\z/, "")
  return "string" if arg.start_with?("x =>")

  NET_LOADER[arg.split(".").last]
end

def net_struct_name(klass)
  return nil if klass.nil?
  return klass if STRUCTS.key?(klass)

  bare = klass.sub(/Expr\z/, "")
  STRUCTS.key?(bare) ? bare : nil
end

# The receiver is not always `el`/`o`: `MemberOrIndexFromWire` pulls the tagged
# payload into a local first and reads `NodeFromWire(value, ...)`, where the
# wire key *is* the receiver's name. The `Name:` label is optional because an
# inline switch arm passes its arguments positionally.
NET_FIELD = /(?:\w+:\s*)?WireHelpers\.(NodeFromWire|NodeListFromWire)<[^>]*>\(\s*(\w+)(?:\.GetProperty\("(\w+)"\))?\s*,\s*(.+?)\)/
# `OptList` is a list decoder too, and reading a single `Option<NodeRef<T>>`
# with it yields null without complaint: it only ever returns non-null for a
# JSON array. It is checked as a list so rule 1 applies, and it is given a
# payload that matches nothing, so a node-shaped field read through it is
# reported as well — it hands back the raw `JsonElement`s rather than nodes.
NET_OPT_LIST = /(\w+):\s*WireHelpers\.OptList<[^>]*>\(\s*\w+,\s*"(\w+)"\)/
# Same reasoning for the scalar readers: `path` is a `Node<String>`, and
# `OptString` on it reads the wrong object entirely rather than raising.
NET_OPT_STRING = /(\w+):\s*[^\n]*?WireHelpers\.OptString\(\s*\w+,\s*"(\w+)"\)/
NET_RAW = "raw json elements"
# A *delegating* arm — `"Schema" => SchemaStmtFromWire(el)`. The arms that
# construct a record inline are `NET_ARM`'s business, and one pattern trying to
# cover both could only match an inline arm narrow enough to fit on a single
# line, which is how `UnificationStmt` and `AssignStmt` went unreached: the wide
# ones put `"Unification",` on the line *after* the `(`.
NET_SWITCH_ARM = /^\s*"(\w+)" =>\s*(\w+)\(/
# An inline arm, in either of the two spellings this binding uses: `Type.cs`
# dispatches through a `Dictionary<string, Func<JsonElement, object>>` where
# every other file uses a `switch`. Neither puts its argument list on one line,
# so the body is taken by counting the parentheses rather than by matching to
# the first `)`.
#
# The dictionary key is matched as a bare word and nothing more, on purpose: the
# registry spells it `[ListType.Tag]`, a const, where this pattern was written
# against the string literal `["ListType"]`. Requiring the literal is what left
# `ListType`, `DictType`, `UnionType` and `FunctionType` with no decoder the
# collector could find. The key is only ever a fallback for the record name
# that follows it, so reading it as an arbitrary expression costs nothing.
NET_ARM = /(?:"(\w+)"\s*=>|\[\s*([\w.]+)\s*\]\s*=\s*\w+\s*=>)\s*new\s+(\w+)\s*\(/

def net_arm_bodies(src)
  arms = []
  src.to_enum(:scan, NET_ARM).each do
    m = Regexp.last_match
    at = m.end(0)
    depth = 1
    i = at
    quoted = false
    # The closing paren has to be counted rather than found, but a paren inside
    # a string literal is not a paren — `"Note: \"(\""` would otherwise close
    # the arm early.
    while i < src.length && depth.positive?
      ch = src[i]
      if ch == '"' && src[i - 1] != "\\"
        quoted = !quoted
      elsif !quoted
        depth += 1 if ch == "("
        depth -= 1 if ch == ")"
      end
      i += 1
    end
    arms << [m[1] || m[2], m[2].nil? ? nil : "type", m[3], src[at...(i - 1)]]
  end
  arms
end

def check_dotnet(dir)
  reads = []
  blob = +""
  NET_FILES.each do |name|
    path = File.join(dir, name)
    next unless File.exist?(path)

    src = File.read(path)
    blob << "\n" << src
    scope = NET_SCOPE[name]
    by_fn = {}

    # A delegating arm names the struct only in the function it hands off to;
    # the inline arms below name it in the record they construct. The tag is
    # the fallback, and the tag is the spelling most likely to be ambiguous.
    src.scan(NET_SWITCH_ARM) do |tag, fn|
      cur = net_struct_name(fn.sub(/FromWire\z/, "").sub(/\A[a-z]/, &:upcase))
      cur ||= net_struct_name(resolve_tag(tag, scope))
      REACHED[:dotnet] << cur unless cur.nil?
      next if cur.nil?

      # A delegating arm (`"Schema" => SchemaStmtFromWire(el)`) has no fields
      # of its own; the ones that do declare their own are read below by name.
      by_fn[fn] = cur
    end

    src.split(/\n(?=\s*(?:public|private|internal) static )/).each do |chunk|
      fn = chunk[/\A\s*(?:public|private|internal) static [\w<>,?\[\] ]*?(\w+FromWire)\s*\(/, 1]
      next if fn.nil?

      cur = by_fn[fn] ||
            net_struct_name(chunk[/\A\s*(?:public|private|internal) static [\w<>,?\[\] ]*?(\w+)\??\s+\w+FromWire\s*\(/, 1]) ||
            net_struct_name(fn.sub(/FromWire\z/, "").sub(/\A[a-z]/, &:upcase))
      next if cur.nil?

      REACHED[:dotnet] << cur
      chunk.scan(NET_FIELD) do |helper, recv, key, loader|
        reads << [cur, key || recv, helper == "NodeListFromWire", net_payload(loader)]
      end
      chunk.scan(NET_OPT_LIST) do |_name, key|
        reads << [cur, key, true, NET_RAW]
      end
      chunk.scan(NET_OPT_STRING) do |_name, key|
        reads << [cur, key, false, NET_RAW]
      end
    end

    # `"Expr" => new ExprStmt("Expr", WireHelpers.NodeListFromWire<object>(
    # el.GetProperty("exprs"), Loaders.ExprFromWire))` — the single expression
    # an inline arm can be, so the field reads are picked out of the arm. The
    # record names the struct outright, but a dictionary arm and a `switch` arm
    # can both fall back to the tag when the record is one this binding renamed.
    net_arm_bodies(src).each do |tag, arm_scope, record, body|
      cur = net_struct_name(record) || net_struct_name(resolve_tag(tag, arm_scope || scope))
      next if cur.nil?

      REACHED[:dotnet] << cur
      body.scan(NET_FIELD) do |helper, recv, key, loader|
        reads << [cur, key || recv, helper == "NodeListFromWire", net_payload(loader)]
      end
      body.scan(NET_OPT_LIST) do |_name, key|
        reads << [cur, key, true, NET_RAW]
      end
      body.scan(NET_OPT_STRING) do |_name, key|
        reads << [cur, key, false, NET_RAW]
      end
    end
  end
  compare(:dotnet, reads) + compare_leaf(:dotnet, blob)
end

# ---------------------------------------------------------------------------
# Zig
# ---------------------------------------------------------------------------

ZIG_FILES = %w[base.zig dto.zig expr.zig module.zig stmt.zig types.zig].freeze

# The payload is named as a Zig type, which is the Rust struct name in every
# case except the three that take a module alias (`expr`, `stmt`, `types`) and
# the string payload. `PAYLOAD_LOADER` is keyed on the struct name, so the
# aliases are all that has to be added.
ZIG_PAYLOAD = PAYLOAD_LOADER.merge(
  "expr" => "expr", "stmt" => "stmt", "types" => "type", "type" => "type",
  "[]const u8" => "string"
).freeze

ZIG_LIST = %w[parseNodeRefList parseOptionalNodeRefList].freeze

ZIG_STRUCT = /^pub const (\w+) = struct \{/
ZIG_READ = /^\s*\.(\w+) = try base\.(parse\w+)\((.*)\),\s*$/
ZIG_GET_FIELD = /getField\(\w+, "(\w+)"\)/
# The two arguments after the value expression: the payload type and the
# loader. Anchored at the end so the value expression's own commas cannot be
# mistaken for them, and without a closing paren because `ZIG_READ` has
# already consumed it.
ZIG_ARGS = /, ([\w.]+|\[\]const u8), [\w.]+\z/

def zig_struct_name(name)
  return name if STRUCTS.key?(name)

  bare = name.sub(/Expr\z/, "")
  STRUCTS.key?(bare) ? bare : nil
end

def check_zig(dir)
  reads = []
  blob = +""
  ZIG_FILES.each do |name|
    path = File.join(dir, name)
    next unless File.exist?(path)

    blob << "\n" << File.read(path)
    # Each `pub const X = struct {` owns everything up to the next one, so the
    # struct a field belongs to is whatever was declared most recently.
    cur = nil
    File.read(path).each_line do |line|
      cur = zig_struct_name(Regexp.last_match(1)) if line =~ ZIG_STRUCT
      next if cur.nil?

      REACHED[:zig] << cur
      m = line.match(ZIG_READ)
      next if m.nil?

      # `.field = try base.parseX(alloc, <value>, <Payload>, <loader>),` — the
      # value expression is a `getField(v, "key")` in every struct decoder, but
      # the type decoders go through a local holding the adjacently-tagged
      # payload, so the key is the last `getField` named on the line.
      payload = m[3][ZIG_ARGS, 1]
      key = m[3].scan(ZIG_GET_FIELD).flatten.last
      next if key.nil?

      name = payload.to_s.split(".").last
      reads << [cur, key, ZIG_LIST.include?(m[2]), ZIG_PAYLOAD[name]]
    end
  end
  compare(:zig, reads) + compare_leaf(:zig, blob)
end

# ---------------------------------------------------------------------------
# Swift
# ---------------------------------------------------------------------------

SWIFT_FILE = "swift/Sources/KclLibAST/AstJson.swift"

# Swift keeps every loader in one file and spells them like the payload rather
# than like a `*FromWire` convention, so the vocabulary is written out. The
# polymorphic decoders are `expr` / `stmt` / `kclType` — the last is named after
# `KclTypeNode`, so that one has no mechanical spelling to derive from.
SWIFT_LOADER = {
  "expr" => "expr", "stmt" => "stmt", "kclType" => "type",
  "identifierFrom" => "identifier", "target" => "target", "keyword" => "keyword",
  "arguments" => "arguments", "checkExpr" => "check", "compClause" => "comp_clause",
  "callExpr" => "call_expr", "configEntry" => "config_entry",
  "schemaExpr" => "schema_expr", "schemaIndexSignature" => "schema_index_signature",
  "comment" => "comment"
}.freeze

# `stringNode` is the `Node<String>` reader and `stringNodeList` its list form.
# Naming either is what marks the payload as a string, the same as in Ruby.
SWIFT_LIST = %w[nodeRefList optionalNodeRefList stringNodeList].freeze
SWIFT_STRING = %w[stringNode stringNodeList].freeze
SWIFT_HELPER = "nodeRef|nodeRefList|optionalNodeRefList|stringNode|stringNodeList"

# `return .<variant>(<Struct>(` — a tagged arm builds its struct by name, which
# is a more reliable link than the tag: "If" is both `IfExpr` and `IfStmt`.
SWIFT_CONSTRUCTOR = /return \.\w+\(\s*(\w+)[(,]/
# Only the decoders take a dictionary, and it is always the first parameter.
# Matching on it rather than on `func` keeps the generic helpers — whose
# parameter list holds a `([String: Any]) -> T` and would end the match early —
# from being read as decoders.
SWIFT_FUNC =
  /^\s*(?:public |private |internal )?func (\w+)\(\s*_\s+\w+:\s*\[String:\s*Any\]\s*\)(?:\s*throws)?\s*->\s*([\w?]+)/

SWIFT_DISPATCH = { "Stmt" => "stmt", "Expr" => "expr", "KclTypeNode" => "type" }.freeze

# `nodeRefList(dict["body"], stmt)` and its relatives.
SWIFT_DIRECT =
  /\b(nodeRef|nodeRefList|optionalNodeRefList|stringNode|stringNodeList)\(\s*\w+\["(\w+)"\]\s*(?:,\s*([\w.]+))?/
# `dict["index"].flatMap { nodeRef($0, expr) }` names the loader inside the
# closure, `dict["doc"].flatMap(stringNode)` passes it, and
# `payload["params_ty"].flatMap { optionalNodeRefList($0, kclType)… }` is a list
# read routed through `flatMap` — so the helper has to be captured, not assumed
# to be `nodeRef`.
SWIFT_CLOSURE =
  /\b\w+\["(\w+)"\]\.flatMap\s*(?:\{\s*(#{SWIFT_HELPER})\(\s*\$\w+\s*(?:,\s*([\w.]+))?\s*\)?|(\w+)\s*\))/

def swift_struct_name(klass)
  return nil if klass.nil?
  return klass if STRUCTS.key?(klass)

  bare = klass.sub(/Expr\z/, "")
  STRUCTS.key?(bare) ? bare : nil
end

def check_swift(path)
  reads = []
  cur = nil
  scope = nil
  pending = nil

  src = File.read(path)
  src.each_line do |line|
    if (m = line.match(SWIFT_FUNC))
      pending = nil
      scope = SWIFT_DISPATCH[m[2]]
      cur = scope.nil? ? swift_struct_name(m[2]) : nil
      REACHED[:swift] << cur unless cur.nil?
      next
    end
    # An arm's constructor is usually on the next line, so the tag is held until
    # it turns up rather than guessed from on the `case` itself — but not every
    # arm wraps: `case "Config": return .config(ConfigExpr(items: …))` is one
    # line, and skipping to the next line leaves it unresolved.
    if (m = line.match(/^\s*case "(\w+)":/))
      pending = m[1]
      cur = nil
    end
    if pending && (m = line.match(SWIFT_CONSTRUCTOR))
      cur = swift_struct_name(m[1]) || resolve_tag(pending, scope)
      REACHED[:swift] << cur unless cur.nil?
      pending = nil
      # No `next`: `return .paren(ParenExpr(expr: nodeRef(…)))` reads its only
      # field on the same line as the constructor.
    end
    next if cur.nil?

    if (m = line.match(SWIFT_DIRECT))
      helper = m[1]
      payload = SWIFT_STRING.include?(helper) ? "string" : SWIFT_LOADER[m[3]]
      reads << [cur, m[2], SWIFT_LIST.include?(helper), payload]
    elsif (m = line.match(SWIFT_CLOSURE))
      helper = m[2] || m[4]
      payload = SWIFT_STRING.include?(helper.to_s) ? "string" : SWIFT_LOADER[m[3]]
      reads << [cur, m[1], SWIFT_LIST.include?(helper.to_s), payload]
    end
  end
  compare(:swift, reads) + compare_leaf(:swift, src)
end

# ---------------------------------------------------------------------------

NODEJS_FILES = %w[_base.mjs _dto.mjs _expr.mjs _module.mjs _stmt.mjs _types.mjs].freeze

NODEJS_SCOPE = { "_expr.mjs" => "expr", "_stmt.mjs" => "stmt", "_types.mjs" => "type" }.freeze

NODEJS_TYPE = {
  "List" => "ListType", "Dict" => "DictType",
  "Union" => "UnionType", "Function" => "FunctionType"
}.freeze

# `identifierFromWire`, `schemaIndexSignatureFromWire` — lowerCamel, unlike the
# PascalCase the TypeScript sibling's table is keyed on. The vocabulary itself
# is derived from `PAYLOAD_LOADER` so a payload added to Rust needs no edit.
#
# Three of this binding's decoders are spelled its own way, and deriving is
# what makes the table fragile in the first place: `call_expr` derives to
# `callExprFromWire`, and no binding is obliged to use that name. Where one
# does not — `decoratorFromWire` for Rust `CallExpr`,
# `schemaConfigFromWire` for `SchemaExpr`, `checkExprFromWire` for `CheckExpr`,
# the last two being the names that separate the tagged wrapper from the plain
# DTO of the same payload — the read comes back with no payload, and `compare`
# counts that as *unresolved*, not as a pass. A silent gap, which is what
# Java's `JAVA_PAYLOAD` already spells out for the same reason.
NODEJS_LOADER = PAYLOAD_LOADER.each_value.with_object(
  "decoratorFromWire" => "call_expr",
  "schemaConfigFromWire" => "schema_expr",
  "checkExprFromWire" => "check"
) do |snake, acc|
  words = snake.split("_")
  camel = ([words.first] + words.drop(1).map { |w| w.sub(/\A./) { |c| c.upcase } }).join
  acc["#{camel}FromWire"] = snake
end.freeze

# `(x) => /** @type {string} */ x` is this binding's `Node<String>`; every
# other payload is a loader function. The identifier is matched rather than
# spelled `x` because nothing forces a callback to call its argument `x` — the
# loaders name it after the field — and it cannot be a backreference, because
# this is embedded in patterns whose own capture groups have to keep their
# numbers. The trailing lookahead is what keeps `(x) => someLoader(x)` out: a
# `Node<String>` read hands the value back, it does not call anything with it.
NODEJS_STRING = /\(\s*\w+\s*\)\s*=>\s*(?:\/\*\*\s*@type\s*\{string\}\s*\*\/\s*)?\w+\s*(?=[,);\n]|\s*$)/m
NODEJS_PAYLOAD = /(?:#{NODEJS_STRING}|[\w.]+FromWire)/

# A callback or call parameter, with or without a `/** @type {…} */` cast on
# it. The cast is why this is not `\w+`: `tsc --checkJs` needs one on the `any`
# that comes off the wire, and they landed in the `.map` callbacks —
# `(w.args || []).map((/** @type {any} */ a) => nodeFromWire(a, …))`. A pattern
# that did not allow for the comment read those fields as unread, so ten
# structs including `Arguments` and `ListExpr` were "reached but never
# compared": the field had quietly left the comparison rather than failed it.
NODEJS_PARAM = "(?:(?:/\\*\\*\\s*@type\\s*\\{[^}]*\\}\\s*\\*/)\\s*)?\\w+"

NODEJS_WRAPPED_LIST =
  /\(\s*#{NODEJS_PARAM}\.(\w+)\s*\|\|\s*\[\]\s*\)\s*\.map\(\s*\(?\s*#{NODEJS_PARAM}\s*\)?\s*=>\s*nodeFromWire\(\s*#{NODEJS_PARAM}\s*,\s*(#{NODEJS_PAYLOAD})/m

NODEJS_BARE_LIST =
  /\(\s*#{NODEJS_PARAM}\.(\w+)\s*\|\|\s*\[\]\s*\)\s*\.map\(\s*(?:\(?\s*#{NODEJS_PARAM}\s*\)?\s*=>\s*)?([\w.]+FromWire)\s*(?:\(\s*#{NODEJS_PARAM}\s*\))?\s*\)/m

NODEJS_SINGLE = /nodeFromWire\(\s*#{NODEJS_PARAM}\.(\w+)\s*,\s*(#{NODEJS_PAYLOAD})/m

# A single node read that skips the `NodeRef` wrapper: `entry:
# _dto.configEntryFromWire(w.entry)`. The field is a list if and only if the
# Rust type is, so there is nothing here to distinguish — but the callee is
# still captured, or the read would count as a payload the checker could not
# name. The wire key has to be behind a `.` so a call on a local
# (`helper(node)`) is not mistaken for a read, and the leading indentation is
# what keeps the one-line delegations in `_expr.mjs` out: those start with
# `return`, not with a label.
NODEJS_BARE_SINGLE = /^\s{4,}(\w+):\s*([\w.]+?)\(\s*[\w.]*?\.(\w+)\s*[,)]/m

def nodejs_payload(arg)
  arg = arg.to_s.strip
  return "string" if arg.match?(NODEJS_STRING)

  NODEJS_LOADER[arg.split(".").last]
end

NODEJS_STRUCT = { "Check" => "CheckExpr" }.freeze

def nodejs_struct_name(klass)
  return nil if klass.nil?
  return NODEJS_STRUCT[klass] if NODEJS_STRUCT.key?(klass)
  return klass if STRUCTS.key?(klass)

  bare = klass.sub(/Expr\z/, "")
  STRUCTS.key?(bare) ? bare : nil
end

def check_nodejs(dir)
  reads = []
  blob = +""
  sources = NODEJS_FILES.filter_map do |name|
    path = File.join(dir, name)
    next unless File.exist?(path)

    src = File.read(path)
    blob << "\n" << src
    [name, src]
  end

  # The registries are collected across all six files *before* any decoder is
  # walked, because the tag and the decoder it names are almost never in the
  # same file: `_expr.mjs` dispatches `Identifier -> identifierFromWire` and
  # `_types.mjs` is where that function is defined. Read per file, the tag
  # half and the decoder half each fell through — the dispatcher had no entry
  # for a function it does not define, and the real decoder was given no
  # struct name, so every variant came out "reached but never compared".
  by_fn = {}
  sources.each do |name, src|
    scope = NODEJS_SCOPE[name]
    # Anchored on a `}` in column 0: the object literal closes with a bare
    # brace here, and a lazy `\n\};` runs past it and swallows the rest of the
    # file (in the TypeScript sibling, to the next `};` further down).
    src[/^const REGISTRY[^\n]*\n(.*?)^\}/m].to_s.scan(/^\s*(\w+):\s*([\w.]+)/).each do |tag, fn|
      cur = nodejs_struct_name(resolve_tag(tag, scope))
      by_fn[fn.split(".").last] ||= cur if cur
    end
  end

  # `function callFromWire(w) { return _dto.decoratorFromWire(w) }` — for a
  # handful of variants the dispatcher's decoder is a one-line forward to a
  # decoder elsewhere (`_dto.decoratorFromWire` in another file, a local
  # `schemaConfigFromWire` in the same one), and the forward carries no
  # `nodeFromWire` call for the field patterns to find. Follow it, so the
  # variant's reads are collected from the decoder it forwards to. The two
  # targets it needs are the binding's own names for Rust structs —
  # `Decorator` for `CallExpr`, `SchemaConfig` for `SchemaExpr` — and neither
  # is a Rust struct name, so `nodejs_struct_name` returns nil for both and
  # the decoder behind the forward would be attributed to nothing.
  sources.each do |_name, src|
    src.split(/\n(?=(?:export )?function |\s*case ')/).each do |chunk|
      fn = chunk[/\A(?:export )?function (\w+FromWire)\b/, 1]
      next if fn.nil? || (cur = by_fn[fn]).nil?

      target = chunk[/\A(?:export )?function \w+FromWire\b[^{]*\{\s*return\s+[\w.]*?(\w+FromWire)\(/, 1]
      by_fn[target] ||= cur if target
    end
  end

  sources.each do |_name, src|
    src.split(/\n(?=(?:export )?function |\s*case ')/).each do |chunk|
      fn = chunk[/\A(?:export )?function (\w+FromWire)\b/, 1]

      cur = (by_fn[fn] if fn) ||
            NODEJS_TYPE[chunk[/\A\s*case '(\w+)'/, 1]] ||
            (nodejs_struct_name(fn.sub(/FromWire\z/, "").sub(/\A[a-z]/, &:upcase)) if fn)
      next if cur.nil?

      REACHED[:nodejs] << cur

      lists = {}
      chunk.scan(NODEJS_WRAPPED_LIST) do |key, payload|
        lists[key] = true
        reads << [cur, key, true, nodejs_payload(payload)]
      end
      chunk.scan(NODEJS_BARE_LIST) do |key, fn_or_loader|
        next if lists.key?(key)

        lists[key] = true
        reads << [cur, key, true, nodejs_payload(fn_or_loader)]
      end

      # Both single-node rules are keyed on the *wire* key, because
      # `func: nodeFromWire(w.func, …)` and `entry: configEntryFromWire(w.entry)`
      # have to agree on which field they are reading — and once a list rule has
      # claimed a label the wire key is a different name for the same field.
      singles = {}
      chunk.scan(NODEJS_SINGLE) do |key, payload|
        next if lists.key?(key)

        singles[key] = true
        reads << [cur, key, false, nodejs_payload(payload)]
      end
      chunk.scan(NODEJS_BARE_SINGLE) do |key, callee, wire_key|
        next if lists.key?(key) || singles.key?(wire_key)

        reads << [cur, key, false, nodejs_payload(callee)]
      end
    end
  end
  compare(:nodejs, reads) + compare_leaf(:nodejs, blob)
end

# ---------------------------------------------------------------------------
# Java
# ---------------------------------------------------------------------------

# Java deserialises with Jackson, so there is no `*FromWire` helper to name the
# payload: the generic argument of the field declaration *is* the loader, and
# `List<...>` *is* the list decoder. `Optional<...>` is Rust's
# `Option<NodeRef<T>>`.
JAVA_PAYLOAD = PAYLOAD_LOADER.merge(
  # Two Java-only aliases for Rust structs the binding never routes through a
  # tagged dispatcher, so no `type` key reaches them and the JSON is the same
  # either way. `Decorator` declares exactly Rust `CallExpr`'s
  # `func`/`args`/`keywords`; `SchemaConfig` exactly Rust `SchemaExpr`'s
  # `name`/`args`/`kwargs`/`config`.
  "Decorator" => "call_expr",
  "SchemaConfig" => "schema_expr"
).freeze

JAVA_LIST = /\A(?:List|Set|Collection)(?:<|\z)/

def java_struct_name(klass)
  return nil if klass.nil?
  return klass if STRUCTS.key?(klass)

  # `ListType.ListTypeValue` and friends: the payload of an adjacently tagged
  # `Type` variant is a nested class named after the Rust struct it carries.
  base = klass.sub(/Value\z/, "")
  STRUCTS.key?(base) ? base : nil
end

def java_unwrap(type)
  type.to_s.strip[/\AOptional<(.*)>\z/m, 1] || type.to_s.strip
end

def java_is_list(type)
  java_unwrap(type).match?(JAVA_LIST)
end

def java_payload(type)
  t = java_unwrap(type)
  # A bare struct counts, not just a wrapper. Jackson binds a field by its
  # declared type, so `private ConfigEntry entry;` — `DictComp.entry`, which
  # Rust declares as a plain `ConfigEntry` with no `NodeRef` — is read with the
  # `ConfigEntry` loader, and a nil here is the read going unchecked rather than
  # the field being a scalar.
  return nil unless t.match?(JAVA_LIST) || t.match?(/\A(?:Node|NodeRef)(?:<|\z)/) || JAVA_PAYLOAD.key?(t)

  t = t[/\A(?:List|Set|Collection)<(.*)>\z/m, 1] || t
  t = t[/\A(?:Node|NodeRef)<(.*)>\z/m, 1] || t
  JAVA_PAYLOAD[t]
end

def java_snake(name)
  # `'_'` as a gsub replacement consumes the match: the capital is what
  # separates the two words, so dropping it turned `innerType` into `inne_ype`
  # and the wire-key fallback below never once named a snake_case key.
  name.gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase
end

def check_java(dir, lang = :java)
  reads = []
  keys = []
  blob = +""
  Dir[File.join(dir, "*.java")].sort.each do |path|
    cur = nil
    key = nil
    source = File.read(path)
    blob << "\n" << source
    source.each_line do |line|
      if (m = line.match(/^\s*(?:public\s+|private\s+|protected\s+)?(?:static\s+)?(?:abstract\s+)?class (\w+)/))
        cur = java_struct_name(m[1])
        REACHED[lang] << cur unless cur.nil?
        key = nil
        next
      end
      # The wire key is the annotation when there is one; otherwise Jackson
      # binds the Java field name, so the field name *is* the wire key.
      if (m = line.match(/^\s*@JsonProperty\("(\w+)"\)/))
        key = m[1]
        next
      end
      next if cur.nil?
      # A field, not a method or an assignment: access modifier, type, name,
      # `;`. A setter body (`this.test = test;`) has no modifier, so it cannot
      # match; `static` fields are constants, which Jackson never binds.
      next unless (m = line.match(/^\s*(?:private|public|protected)\s+(?!static\b)((?:final\s+)*[\w.]+(?:\s*<[^;]*>)?)\s+(\w+)\s*(?:=[^;]*)?;\s*(?:\/\/.*)?$/))
      wire = key || m[2]
      key = nil

      rust = STRUCTS[cur]
      if rust && !rust.key?(wire)
        snake = java_snake(wire)
        if rust.key?(snake)
          keys << "#{cur}: `#{snake}` is read from JSON key `#{wire}` " \
                  "(no @JsonProperty, so Jackson binds the Java field name)"
          wire = snake
        elsif wire != "value" || java_struct_name(m[1].sub(/\s*<.*\z/m, "")) != cur
          # `ListType.value` and friends hold the payload of an adjacently
          # tagged `Type` variant, which serde puts under `value` and Rust
          # therefore does not declare as a field. Everything else is a key
          # nothing on the wire can fill.
          keys << "#{cur}: `#{wire}` is not a field of Rust #{cur}, " \
                  "so nothing Rust emits can fill it"
        end
      end

      reads << [cur, wire, java_is_list(m[1]), java_payload(m[1])]
    end
  end
  compare(lang, reads) + keys + compare_leaf(lang, blob)
end

# Java spreads the AST over 92 files, and the self-test's scratch copy has to
# reproduce all of them for a mutation in one of them to be seen.
JAVA_AST_DIR = "java/src/main/java/com/kcl/ast"
# Kotlin compiles the same `com.kcl.ast` Java sources and the two trees are
# kept byte-identical, so one collector checks both.
KOTLIN_AST_DIR = "kotlin/src/main/java/com/kcl/ast"

def java_ast_files(dir)
  Dir[File.join(dir, "*.java")].map { |p| File.basename(p) }.sort.freeze
end

# ---------------------------------------------------------------------------
# Go
# ---------------------------------------------------------------------------

# Go's AST is generated from `ast.rs` by `tools/astgen/emit_go.py`, so every
# field is a struct declaration. That is what this collector reads and all it
# reads: there is no hand-written loader name to grep for, so the declared type
# is the loader, in the same way Jackson's field type is Java's and a
# `_from_wire` suffix is Ruby's.
GO_AST_DIR = "go/ast"

# A field is `Name Type `json:"wire"`` on one line, and the tag's options
# (`omitempty`) are not part of the wire key. The `json:"-"` on
# `MemberOrIndex`'s per-variant fields does not match, which is right: those
# slots are placed by `MarshalJSON` rather than by the struct's own key set, so
# they are not wire keys and must not be compared as if they were.
GO_FIELD = /^\t(\w+)\s+(\S+)\s+`json:"([^",]+)(?:,[^"]*)?"`/

# `type Name struct { … }`, body included. The `Node[T]` wrapper and the fifteen
# slot types are structs as well; none of them is a Rust struct, so `checkable?`
# drops them and their reads never enter the comparison.
GO_STRUCT = /^type (\w+) struct \{\n(.*?)\n\}/m

# The payload a Go type names. `NodeRef<T>` is a generic struct in Rust and a
# named slot type in Go -- `ExprNode`, `StringNode` -- because a generic method
# cannot dispatch on its type parameter, so the mapping cannot live in `Node[T]`
# and the slot name has to be the Rust payload's name plus `Node`. Stripping
# that suffix is what makes the lookup a derivation rather than a hand-written
# list: `*ExprNode`, `[]*ExprNode` and `*ConfigEntry` all answer through
# `PAYLOAD_LOADER` the same way every other binding's loaders do, and a slot
# added to the emitter shows up here without this file being told.
def go_payload(type)
  PAYLOAD_LOADER[type.delete_prefix("[]").delete_prefix("*").sub(/Node\z/, "")]
end

def check_go(dir)
  reads = []
  blob = +""
  Dir[File.join(dir, "*_gen.go")].sort.each do |path|
    source = File.read(path)
    blob << "\n" << source
    source.scan(GO_STRUCT) do |name, body|
      cur = STRUCTS.key?(name) ? name : nil
      REACHED[:go] << cur unless cur.nil?
      next if cur.nil?

      body.each_line do |line|
        next unless (m = line.match(GO_FIELD))

        reads << [cur, m[3], m[2].start_with?("[]"), go_payload(m[2])]
      end
    end
  end
  compare(:go, reads) + compare_leaf(:go, blob)
end

# ---------------------------------------------------------------------------
# C
# ---------------------------------------------------------------------------

# `parse_expr_node` is the `NodeRef<Expr>` reader, `parse_expr_node_list` the
# `Vec` one and `parse_expr_node_opt` the `Option` one; the same three
# suffixes apply to every payload kind, and `parse_opt_expr_node_list` is the
# `Vec<Option<NodeRef<Expr>>>` form — the `opt` goes in *front* there, so the
# stem is looked up after stripping it.
#
# `type_ref` is the `NodeRef<Type>` family, which cannot be derived from the
# payload: Rust's `Type` has no C type of its own, so the stem is the
# wrapper's. `type` is the `Type` decoder itself, and the stem the
# `KCL_DEFINE_OPT_NODE_LIST_LOADER(type, ...)` macro is instantiated under.
# The bare DTO decoders belong in the same table because they decode a struct
# the wire carries with no wrapper at all — `DictComp.entry` is a bare
# `ConfigEntry`, and reading it through the `NodeRef` loader would look for a
# `node` key that is not on the wire.
#
# `copy_string_node` fills a `kcl_string_node_t` in place rather than
# returning one, so the `NodeRef<String>` reader is named by *two* functions.
C_LOADER = {
  "stmt" => "stmt", "expr" => "expr", "type_ref" => "type", "type" => "type",
  "target" => "target", "identifier" => "identifier", "arguments" => "arguments",
  "check_expr" => "check", "call_expr" => "call_expr",
  "comp_clause" => "comp_clause", "config_entry" => "config_entry",
  "keyword" => "keyword", "schema_expr" => "schema_expr",
  "schema_index_signature" => "schema_index_signature",
  "comment" => "comment", "string" => "string",
  # `parse_member_or_index` decodes a bare `MemberOrIndex` and is called from
  # the one hand-written array loop, never through a generated list loader.
  "member_or_index" => "member_or_index"
}.freeze

# The plain DTO decoders are named after the Rust struct they decode, so the
# struct a function's reads belong to is the function's own name. The three
# dispatchers (`parse_expr`, `parse_stmt`, `parse_type_node`) and the
# `NodeRef`/JSON helpers have no struct of their own — their reads are
# attributed to the branch they sit in instead.
C_STRUCT = {
  "parse_identifier" => "Identifier", "parse_target" => "Target",
  "parse_keyword" => "Keyword", "parse_arguments" => "Arguments",
  "parse_call_expr" => "CallExpr", "parse_check_expr" => "CheckExpr",
  "parse_config_entry" => "ConfigEntry", "parse_comp_clause" => "CompClause",
  "parse_schema_expr" => "SchemaExpr",
  "parse_schema_index_signature" => "SchemaIndexSignature",
  "parse_module_into" => "Module"
}.freeze

# `Type::Named(Identifier)` inlines a payload Rust names differently from the
# tag. `Literal` maps to nil on purpose: its `value` is serde's tag+content
# key, not a field of the `LiteralType` behind it, so attributing the branch
# to a struct would invent a read that is not there.
C_TYPE_STRUCT = { "Named" => "Identifier", "Literal" => nil }.freeze

# `resolve_tag` prefers the bare tag whenever Rust has a struct by that name,
# which is right for `Target` and `Identifier` and wrong for `Schema`, where
# `Schema` is the wire tag of both `SchemaExpr` and `SchemaStmt` and the
# enclosing decoder is the only thing that tells them apart. Trying the scoped
# name *first* resolves `If`, `Schema` and `Expr`, and falls back to the bare
# tag for everything Rust spells without a suffix.
def c_resolve_tag(tag, scope)
  suffix = SCOPE_SUFFIX[scope]
  return tag if suffix.nil?

  scoped = "#{tag}#{suffix}"
  STRUCTS.key?(scoped) ? scoped : tag
end

# A function definition is a `static` line at column 0 that is not a forward
# declaration, and its body runs to the `}` at column 0. Everything in the
# file is laid out that way, which is what lets a read be attributed by
# offset instead of by tracking state from line to line.
C_DEF = /^static\s/
C_BODY_END = /^}\r?\n?/

# The two dispatchers `switch` on the kind enum; `parse_type_node` compares
# the tag with `strcmp`, because serde's `content` key holds the payload
# rather than a variant name. `KCL_EXPR_KIND_LIST_IF_ITEM` is the enum's
# spelling of the wire tag `ListIfItem`.
C_BRANCH = [
  [/^    case KCL_EXPR_KIND_(\w+):/, "expr"],
  [/^    case KCL_STMT_KIND_(\w+):/, "stmt"],
  [/^    if \(strcmp\(tag, "(\w+)"\) == 0\)/, "type"]
].freeze

# `parse_expr_node(a, kcl_json_object_get(v, "left"))` and its relatives:
# every node read names its loader and its wire key in the same call. The
# optional leading `&dest,` covers the list form, and `\s*` spans the newline
# so a read that wraps onto its continuation line is still one match. `_node`
# is optional so the bare DTO decoders count as reads too, and it is captured
# because whether the `NodeRef` wrapper was used is what tells a wrapped read
# from a bare one.
C_KIND = Regexp.union(C_LOADER.keys).source
C_READ = Regexp.new(
  "\\b(?<fn>parse_(?:opt_)?(?:#{C_KIND})(?<wrapped>_node)?(?:_opt|_list)?|copy_string_node)\\(" \
  "\\s*(?:&[\\w.>-]+,\\s*)?a,\\s*kcl_json_object_get\\(\\s*[\\w>.]+,\\s*\"(?<key>\\w+)\"\\s*\\)"
)

# The three tagged dispatchers: they switch on a `"type"` key, so a payload
# that carries no tag decodes to an empty struct rather than raising.
C_TAGGED = %w[parse_expr parse_stmt parse_type_node].freeze

# The two reads that pull the wire value into a local first: `Target.paths` is
# a bare `Vec<MemberOrIndex>` with no loader of its own, and `Compare.ops` a
# `Vec<CmpOp>`. Whether the local came out as a list is decided by what the
# code does with it, not by a loader it does not have. The length expression is
# captured too, because a hand-written array is decoded in two steps that have
# to agree on which array they are talking about, and a mismatch there truncates
# a `Vec` with neither a compile error nor a crash.
C_LOCAL =
  /const kcl_json_value_t\* (\w+) = kcl_json_object_get\(\s*[\w>.]+,\s*"(\w+)"\s*\);\s*size_t\s+\w+\s*=\s*json_is_array\(\1\)\s*\?\s*(.+?)\s*:\s*0;/m

# Every wire key a fragment asks for, by any accessor, for the field census
# `C_READ` cannot do: a field the decoder never reads has no read to inspect.
# The three shapes are `kcl_json_object_get(v, "k")` and the scalar accessors
# `read_key_str(a, v, "k")` / `read_key_bool(v, "k", false)`, which take the
# arena in the first two and not in the third.
C_ANY_KEY = /
  kcl_json_object_get\(\s*\w+\s*,\s*"(\w+)"\s*\)
  | read_key_(?:str|bool|i64)\(\s*\w+\s*,\s*(?:\w+|\([^)]*\))\s*,\s*"(\w+)"
  | read_key_(?:str|bool|i64)\(\s*\w+\s*,\s*"(\w+)"\s*,
/x

def c_loader(fn)
  base = fn.sub(/\A(?:parse|copy)_/, "").sub(/\Aopt_/, "")
             .sub(/_(?:node_)?(?:opt|list)\z/, "").sub(/_node\z/, "")
  [C_LOADER[base], fn.end_with?("_list")]
end

def c_regions(src)
  regions = []
  lines = []
  at = 0
  src.each_line { |l| lines << [at, l]; at += l.length }

  lines.each_index do |i|
    next unless lines[i][1].match?(C_DEF) && !lines[i][1].strip.end_with?(";")
    next unless lines[i + 1] && lines[i + 1][1].strip == "{"

    last = ((i + 2)...lines.length).find { |j| lines[j][1].match?(C_BODY_END) }
    next if last.nil?

    base = C_STRUCT[lines[i][1][/(\w+)\(/, 1]]
    regions << [lines[i][0], lines[last][0] + lines[last][1].length, base] unless base.nil?

    # A branch runs to the next branch header of the same dispatcher, so a
    # read after the last `case` belongs to the function rather than being
    # inherited by whichever arm happened to be parsed last.
    heads = C_BRANCH.flat_map do |re, scope|
      lines[(i + 2)...last].filter_map do |offset, line|
        next unless (m = line.match(re))

        tag = m[1].split("_").map(&:capitalize).join
        [offset, C_TYPE_STRUCT.key?(tag) ? C_TYPE_STRUCT[tag] : c_resolve_tag(tag, scope)]
      end
    end.sort_by!(&:first)

    heads.each_with_index do |(start, struct), k|
      stop = heads[k + 1]&.first || (lines[last][0] + lines[last][1].length)
      regions << [start, stop, struct]
    end
  end
  regions
end

# A read belongs to the innermost region that contains it, which is what puts
# a field read inside a `case` arm on that arm's struct rather than on the
# enclosing decoder.
def c_struct_at(regions, at)
  hit = nil
  regions.each { |from, to, struct| hit = struct if struct && at >= from && at < to }
  hit
end

def c_reads(src)
  regions = c_regions(src)
  reads = []
  # The two rules that only C can need, kept out of `compare` because they are
  # about the *name* of a loader or a key rather than about list-vs-node.
  extras = []
  record = lambda do |cur, key, is_list, payload, fn, wrapped|
    reads << [cur, key, is_list, payload]
    rust = STRUCTS[cur]
    return if rust.nil?

    # A wire key is a bare string literal here rather than a property the
    # compiler checks, and `kcl_json_object_get` answers NULL for a key that
    # is not there — which every reader in the file turns into a zero value.
    # TypeScript gets this from a typed `o: Wire`; C gets nothing.
    unless rust.key?(key)
      extras << "#{cur}: reads `#{key}`, which Rust #{cur} has no field for"
      return
    end

    # A bare struct carries neither a tag nor a `node` wrapper, so
    # `DictComp.entry` through `parse_config_entry_node` looks for a `node`
    # key that is not on the wire, and `parse_expr` switches on a `"type"`
    # key that is not there and yields a zero-valued node. This is the .NET
    # bug family — an untagged payload handed to a tagged dispatcher — and in
    # C it is silent for the same reason it was silent there.
    bare = rust[key].sub(/\AOption</, "").sub(/>\z/, "")
    return unless STRUCTS.key?(bare)
    return if wrapped.nil? && !C_TAGGED.include?(fn)

    snake = bare.gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase
    extras << "#{cur}: `#{key}` is #{rust[key]}, which carries no tag and no " \
              "`node` wrapper, so it needs parse_#{snake} and not #{fn}"
  end
  src.to_enum(:scan, C_READ).each do
    at = Regexp.last_match.begin(0)
    m = Regexp.last_match
    cur = c_struct_at(regions, at)
    next if cur.nil?

    payload, is_list = c_loader(m[:fn])
    record.call(cur, m[:key], is_list, payload, m[:fn], m[:wrapped])
  end
  src.to_enum(:scan, C_LOCAL).each do
    at = Regexp.last_match.begin(0)
    m = Regexp.last_match
    cur = c_struct_at(regions, at)
    next if cur.nil?

    to = regions.map { |r| r[1] }.select { |end_at| end_at > at }.min || src.length
    body = src[at...to]
    # `Vec<MemberOrIndex>` is bare, so its element decoder is whatever the
    # hand-written loop calls and not one of the generated list loaders.
    # `Vec<CmpOp>` calls `decode_cmp_op` instead: the element is a scalar, so
    # the payload rule has nothing to say about it and only the list rule
    # applies. Naming the decoder is what tells those two apart.
    item = body[/parse_(\w+)\(a, kcl_json_array_get\(#{Regexp.escape(m[1])}, /, 1]
    reads << [cur, m[2], body.include?("kcl_json_array_get(#{m[1]},"),
              item && c_loader("parse_#{item}").first]
  end
  [reads, regions, extras]
end

# The mirror image of `compare`, and the part a statically typed binding needs
# that a dynamically typed one does not: `compare` can only judge a field that
# has a read, so a decoder that never asks for a key is invisible to it. This
# is about the *read* side where `check_c_header` is about the *declared* side
# — a member can be declared, checked against Rust, and still never be filled
# from the wire, which leaves a struct that looks right and decodes to zeroes.
def c_unread(src)
  seen = Hash.new { |h, k| h[k] = [] }
  regions = c_regions(src)
  src.to_enum(:scan, C_ANY_KEY).each do
    at = Regexp.last_match.begin(0)
    m = Regexp.last_match
    cur = c_struct_at(regions, at)
    next if cur.nil?

    key = m[1] || m[2] || m[3]
    seen[cur] << key unless seen[cur].include?(key)
  end

  seen.keys.sort.flat_map do |struct|
    next [] unless checkable?(struct)

    (STRUCTS[struct].keys - seen[struct]).sort.map do |field|
      "#{struct}: `#{field}` (:#{STRUCTS[struct][field]}) is never read by the " \
        "C loader, so the AST silently drops it"
    end
  end
end

# A hand-written array is decoded in two steps — pull the array into a local,
# then loop it to its length — and the two have to agree on which array. These
# are the only two arrays in the loader that no generated list loader covers.
def c_array_bound(src)
  regions = c_regions(src)
  src.to_enum(:scan, C_LOCAL).filter_map do
    at = Regexp.last_match.begin(0)
    m = Regexp.last_match
    struct = c_struct_at(regions, at)
    next if struct.nil? || !checkable?(struct)

    want = "kcl_json_array_length(#{m[1]})"
    next if m[3].strip == want

    "#{struct}: `#{m[2]}` is a hand-written array loop bounded by " \
      "#{m[3].strip}, not #{want} — the `Vec` is silently truncated"
  end
end

# The C AST is a file pair — a header of declared types and a loader that
# reads the wire — and the C++ binding is a header that `#include`s the C one
# and hands `ast_json` straight to the C entry point. One collector therefore
# serves both, and the only thing to resolve is which pair a caller named.
C_AST_HEADER = "c/include/kcl_lib_ast.h"
CPP_AST_HEADER = "cpp/include/kcl_lib_ast.hpp"

def c_pair(header)
  header = File.expand_path(header)
  return [header, File.join(File.dirname(header), "../lib/kcl_lib_ast.c")] if File.basename(header) == "kcl_lib_ast.h"

  # Follow the `#include` the C++ header declares rather than hard-coding the
  # path: the whole claim that C++ has no loader of its own is that this is
  # where its types come from, so the collector should take the claim's word
  # for nothing. The include is resolved against the build's own search path —
  # `CMakeLists.txt` puts `${PROJECT_SOURCE_DIR}/../c/include` on it — so the
  # header the checker reads is the one the compiler reads.
  inc = File.read(header)[/^#include\s+"([^"]+)"/m, 1]
  raise "#{header} does not include the C AST header" if inc.nil?

  root = File.expand_path("../..", File.dirname(header))
  base = File.join(root, "c/include", inc)
  raise "#{header} includes #{inc}, which is not the C AST header" unless File.exist?(base)

  [base, File.join(File.dirname(base), "../lib/kcl_lib_ast.c")]
end

def check_c(header, lang = :c, leaf: true)
  decl, source = c_pair(header)
  src = File.read(source)
  reads, regions, extras = c_reads(src)
  # Only structs Rust actually has: a branch that resolves to a wire tag with
  # no struct behind it (`Any`, `Basic`, `Missing`) is a decoder, not a gap.
  regions.each { |_from, _to, struct| REACHED[lang] << struct if STRUCTS.key?(struct) }

  compare(lang, reads) + extras + c_unread(src) + c_array_bound(src) +
    check_c_header(decl) + (leaf ? compare_leaf(lang, src) : [])
end

# ---------------------------------------------------------------------------
# C++'s own decoder
#
# `cpp/include/kcl_lib_ast.hpp` declares no fields of its own: it includes
# `c/include/kcl_lib_ast.h` and hands back the C loader's types, so `check_c`
# reaches C++ by following that `#include` and every one of its reads is C's.
# That is the right thing to check — but it means `cpp/include/kcl_ast.hpp`,
# a self-contained C++ decoder that does not go through C at all, was never
# looked at by anything. Two thousand lines of AST, unchecked, and invisible:
# the same silence as a decoder that stops matching, except nothing had to
# break for it.
#
# So C++ is checked twice, through the header it wraps and the decoder it has.
# They share the `:cpp` binding rather than getting a second name, so the
# counts add and the coverage sets union — a struct reached by either decoder
# is covered, which is what `REACHED`/`CHECKED` are for. The leaf is asked only
# of the native decoder, because `LEAF_CHECKED` is a fraction of a binding's
# leaf positions and C++ has one decoder per leaf position, not two.
# ---------------------------------------------------------------------------

CPP_NATIVE_HEADER = "cpp/include/kcl_ast.hpp"

# The header names its classes as Rust names its structs, which is the whole
# point of it, so the vocabulary needs no table. These two are the exceptions
# and they are the same two nodejs and java name differently: `Decorator` is
# this binding's name for `CallExpr` and `SchemaConfig` for `SchemaExpr`.
CPP_NATIVE_STRUCT = { "Decorator" => "CallExpr", "SchemaConfig" => "SchemaExpr" }.freeze

def cpp_native_struct(klass)
  CPP_NATIVE_STRUCT[klass] || (STRUCTS.key?(klass) ? klass : nil)
end

# `parse_node<T>` / `parse_node_list<T>` / `parse_opt_node_list<T>`: the
# template argument *is* the payload. The loader passed alongside it is not
# needed to judge the read — the compiler has already checked the two agree, so
# a mismatch here is a mismatch between the type the code asks for and the one
# Rust declares, which is the thing worth reporting.
CPP_NATIVE_LIST = /out->\w+\s*=\s*parse_(?:opt_)?node_list<([\w:]+)>\(\s*field\(\s*value\s*,\s*"(\w+)"/

CPP_NATIVE_SINGLE = /out->\w+\s*=\s*parse_node<([\w:]+)>\(\s*field\(\s*value\s*,\s*"(\w+)"/

# `parse_string_node` is this header's `Node<String>` and `string_field` is its
# bare `String`; the second reads the same way whatever its Rust type says, so
# only the first is a read the payload rule has anything to say about. The two
# are separate patterns rather than one with `(?:_list)?` because whether a
# read is a list is a property of the *read*, and answering it for the whole
# function body gets it wrong the moment a decoder has both — which
# `parse_identifier` does, with `names` a list and `ctx`/`pkgpath` not.
CPP_NATIVE_STRING_LIST =
  /out->\w+\s*=\s*parse_string_node_list\(\s*field\(\s*value\s*,\s*"(\w+)"/

CPP_NATIVE_STRING =
  /out->\w+\s*=\s*parse_string_node\(\s*field\(\s*value\s*,\s*"(\w+)"/

# A payload that is a plain struct with no template to read: `out->keyword =
# parse_keyword(field(value, "key"))`.
CPP_NATIVE_CALL = /out->\w+\s*=\s*parse_(\w+)\(\s*field\(\s*value\s*,\s*"(\w+)"/

# An optional single node bound before it is moved: `if (auto cond =
# parse_node<Expr>(field(value, "cond"), parse_expr)) { out->cond =
# std::move(*cond); }`. The struct field is spelled on the *next* line, so the
# wire key is what identifies the read — which is what `compare` wants anyway.
# Roughly half of this header's single-node reads are written this way, and
# matching only the `out->x = …` shape left all of them outside the comparison
# without one unresolved payload to show for it: a field nobody looked at and
# nobody reported.
CPP_NATIVE_IF_SINGLE = /if \(auto \w+ = parse_node<([\w:]+)>\(\s*field\(\s*value\s*,\s*"(\w+)"/

CPP_NATIVE_IF_STRING = /if \(auto \w+ = parse_string_node\(\s*field\(\s*value\s*,\s*"(\w+)/

# `Target.paths` is a bare `Vec<MemberOrIndex>`, so there is no
# `parse_node_list` to read it: the loop pushes the decoded element itself.
CPP_NATIVE_BARE_LIST = /out->(\w+)\.push_back\(\*parse_(\w+)\(item\)\)/

# Every decoder in the header opens the same way — `auto out =
# std::make_shared<X>();` — and every tagged arm inside `parse_expr` /
# `parse_stmt` does too, so the class is what says which struct the block that
# follows belongs to. Both shapes come out of one scan, which is why the
# dispatcher arms need no separate pass.
CPP_NATIVE_BLOCK = /auto out = std::make_shared<(\w+)>\(\);(.*?)return out;/m

def cpp_native_payload(name)
  # The alias belongs on the *payload* as much as on the struct being built.
  # This header spells a `Decorator` where Rust spells a `CallExpr` and a
  # `SchemaConfig` where Rust spells a `SchemaExpr`, and the read is named
  # after what the template argument says — so an unaliased `Decorator` finds
  # nothing in `PAYLOAD_LOADER` and every `decorators` field goes unchecked.
  rust = CPP_NATIVE_STRUCT[name] || name
  # Both spellings land in the same vocabulary and neither is assumed: the
  # template argument is spelled as Rust spells the struct (`Expr`,
  # `CheckExpr`) and `CPP_NATIVE_CALL` spells it as the loader (`keyword`,
  # `arguments`). The *value*, never the key — returning the key reports every
  # read as "read with Expr" rather than "read with expr".
  PAYLOAD_LOADER[rust] || (PAYLOAD_LOADER.value?(rust) ? rust : nil)
end

def cpp_claim(seen, reads, cur, m, key, list, payload)
  # The key is passed in rather than derived from the captures, because the
  # patterns do not agree on where it sits: seven of them name the payload
  # first and `CPP_NATIVE_BARE_LIST` names the field first. Taking the last
  # capture made `Target.paths` a read of a field called `member_or_index`,
  # which Rust does not have, so `compare` dropped it and the one bare `Vec` in
  # the header went unchecked with nothing to show for it.
  return if seen.key?([key, m[0]])

  seen[[key, m[0]]] = true
  reads << [cur, key, list, payload]
end

def check_cpp_native(path, lang = :cpp)
  src = File.read(path)
  reads = []
  src.to_enum(:scan, CPP_NATIVE_BLOCK).each do
    klass, body = Regexp.last_match[1], Regexp.last_match[2]
    cur = cpp_native_struct(klass)
    next if cur.nil?

    REACHED[lang] << cur
    seen = {}
    # One read per line, claimed by the first pattern that matches it. The
    # patterns are ordered specific-first and `CPP_NATIVE_CALL` is a catch-all
    # that also matches `parse_string_node(field(value, "doc"))`, naming it
    # `string_node` — a name no `PAYLOAD_LOADER` has — so without this the
    # field is read twice and it is the nameless second copy that decides the
    # verdict. The claim is on the matched *text* as well as the key: keying
    # on the key alone would drop `MemberOrIndex.index`, which reads the same
    # `"value"` as `.member` in the other arm of the tag.
    body.to_enum(:scan, CPP_NATIVE_LIST).each do
      m = Regexp.last_match
      cpp_claim(seen, reads, cur, m, m[2], true, cpp_native_payload(m[1]))
    end
    body.to_enum(:scan, CPP_NATIVE_SINGLE).each do
      m = Regexp.last_match
      cpp_claim(seen, reads, cur, m, m[2], false, cpp_native_payload(m[1]))
    end
    # `scan` hands a one-parameter block an *array* of the captures rather than
    # the first one, so a single-capture pattern is read off the match rather
    # than destructured — otherwise it is the array that lands in the read and
    # the lookup misses every time.
    body.to_enum(:scan, CPP_NATIVE_STRING_LIST).each do
      m = Regexp.last_match
      cpp_claim(seen, reads, cur, m, m[1], true, "string")
    end
    body.to_enum(:scan, CPP_NATIVE_STRING).each do
      m = Regexp.last_match
      cpp_claim(seen, reads, cur, m, m[1], false, "string")
    end
    body.to_enum(:scan, CPP_NATIVE_IF_SINGLE).each do
      m = Regexp.last_match
      cpp_claim(seen, reads, cur, m, m[2], false, cpp_native_payload(m[1]))
    end
    body.to_enum(:scan, CPP_NATIVE_IF_STRING).each do
      m = Regexp.last_match
      cpp_claim(seen, reads, cur, m, m[1], false, "string")
    end
    body.to_enum(:scan, CPP_NATIVE_CALL).each do
      m = Regexp.last_match
      cpp_claim(seen, reads, cur, m, m[2], false, cpp_native_payload(m[1]))
    end
    body.to_enum(:scan, CPP_NATIVE_BARE_LIST).each do
      m = Regexp.last_match
      cpp_claim(seen, reads, cur, m, m[1], true, cpp_native_payload(m[2]))
    end
  end
  compare(lang, reads) + compare_leaf(lang, src)
end

# ---------------------------------------------------------------------------
# PHP
# ---------------------------------------------------------------------------

# The `Wire` helper a read goes through decides both rules. `nodeRefList`
# against a `NodeRef<T>` is the list-versus-single bug; the third argument —
# the payload word — is the same vocabulary `PAYLOAD_LOADER` maps, so
# `nodeRef($w, 'attr', 'identifier')` reads an Identifier and
# `stringNode($w, 'doc')` reads a String. The string helpers name their own
# payload; `op`/`opList` read bare enum strings, which have no payload the
# payload rule could check (only the list rule applies to `Compare.ops`).
PHP_LIST = %w[nodeRefList optNodeRefList stringNodeList classList opList].freeze
PHP_STRING = %w[stringNode stringNodeList].freeze
PHP_HELPERS = %w[nodeRef nodeRefList optNodeRefList stringNode stringNodeList
                 classRef classList op opList].freeze

# PHP spreads the AST over one generated file per class in `php/src/Ast`, all
# in one namespace; a file's reads belong to the `final class` it declares,
# and the class is what the report names. The support files carry no class
# decoders — `Wire.php` defines the helpers and `AstBuild.php` constructs
# rather than decodes — so a read attributed to them has no class to reach
# and is raised rather than passed over.
def check_php(dir)
  reads = []
  blob = +""
  Dir[File.join(dir, "*.php")].sort.each do |path|
    src = File.read(path)
    blob << "\n" << src
    cur = nil
    File.read(path).each_line do |line|
      if (m = line.match(/^final class (\w+)/))
        cur = m[1]
        REACHED[:php] << cur if STRUCTS.key?(cur)
        next
      end
      if line.match?(/^abstract class /) || line.match?(/^final class /)
        cur = nil if line.match?(/^abstract class /)
        next
      end
      next if cur.nil?

      m = line.match(/Wire::(\w+)\(\$w,\s*'(\w+)'(?:\s*,\s*'(\w+)')?/)
      next if m.nil? || !PHP_HELPERS.include?(m[1])

      payload = if PHP_STRING.include?(m[1])
                  "string"
                elsif m[1] == "op" || m[1] == "opList"
                  nil
                else
                  m[3]
                end
      reads << [cur, m[2], PHP_LIST.include?(m[1]), payload]
    end
  end
  compare(:php, reads) + compare_leaf(:php, blob)
end


# ---------------------------------------------------------------------------
# The declared field types, which `compare` cannot see
#
# Both rules above look at reads that exist. A field C never reads at all is
# invisible to them, so the header is checked against the Rust definitions
# separately: every Rust field of every struct C models has to have a
# same-named member. Only the missing direction is checked — C legitimately
# carries members Rust has no field for (`paths_count`, `has_op`,
# `has_binary_suffix`, `kind`, `present`, `placeholder`, `_internals`), so
# flagging those would be all noise.
# ---------------------------------------------------------------------------

C_DECL = {
  "kcl_identifier" => "Identifier", "kcl_target" => "Target",
  "kcl_keyword" => "Keyword", "kcl_arguments" => "Arguments",
  "kcl_call_expr" => "CallExpr", "kcl_check_expr" => "CheckExpr",
  "kcl_config_entry" => "ConfigEntry", "kcl_comp_clause" => "CompClause",
  "kcl_schema_expr" => "SchemaExpr",
  "kcl_schema_index_signature" => "SchemaIndexSignature",
  "kcl_comment" => "Comment", "kcl_module" => "Module",
  "kcl_type_alias_stmt" => "TypeAliasStmt", "kcl_expr_stmt" => "ExprStmt",
  "kcl_unification_stmt" => "UnificationStmt", "kcl_assign_stmt" => "AssignStmt",
  "kcl_aug_assign_stmt" => "AugAssignStmt", "kcl_assert_stmt" => "AssertStmt",
  "kcl_if_stmt" => "IfStmt", "kcl_import_stmt" => "ImportStmt",
  "kcl_schema_attr" => "SchemaAttr", "kcl_schema_stmt" => "SchemaStmt",
  "kcl_rule_stmt" => "RuleStmt",
  "unary_expr" => "UnaryExpr", "binary_expr" => "BinaryExpr",
  "if_expr" => "IfExpr", "selector_expr" => "SelectorExpr",
  "paren_expr" => "ParenExpr", "quant_expr" => "QuantExpr",
  "list_expr" => "ListExpr", "list_if_item_expr" => "ListIfItemExpr",
  "list_comp" => "ListComp", "starred_expr" => "StarredExpr",
  "dict_comp" => "DictComp", "config_if_entry_expr" => "ConfigIfEntryExpr",
  "lambda_expr" => "LambdaExpr", "subscript_expr" => "Subscript",
  "compare_expr" => "Compare", "number_lit" => "NumberLit",
  "string_lit" => "StringLit", "name_constant_lit" => "NameConstantLit",
  "joined_string" => "JoinedString", "formatted_value" => "FormattedValue",
  "list_type" => "ListType", "dict_type" => "DictType",
  "union_type" => "UnionType", "function_type" => "FunctionType"
}.freeze

# A struct body is a list of declarations split on `;` at brace depth zero,
# which is what keeps `union { ... } u;` in one piece. `struct { ... }
# unary_expr;` is a member that happens to have its own definition, so it is
# registered under its trailing name; a `union` is how the enums are modelled,
# so its members are the *enclosing* struct's members rather than a member
# called `u`.
C_NAMED_BLOCK =
  /\A(?:typedef\s+)?(struct|union)(?:\s+(\w+))?\s*\{(.*)\}\s*(\w+)\s*\z/m

def c_decls(body)
  members = []
  named = {}
  depth = 0
  decl = +""
  body.each_char do |ch|
    if ch == "{" || ch == "}"
      depth += (ch == "{" ? 1 : -1)
      depth = 0 if depth.negative?
      decl << ch
    elsif ch == ";" && depth.zero?
      text = decl.strip
      decl = +""
      # An `enum` has no struct to register and closes with a brace of its
      # own, so the depth is rebased at every declaration boundary rather
      # than carried across the file.
      depth = 0
      next if text.empty?

      if (m = text.match(C_NAMED_BLOCK))
        sub_members, sub_named = c_decls(m[3])
        named.merge!(sub_named)
        if m[1] == "union"
          members.concat(sub_members)
        else
          members << (m[2] || m[4])
          named[m[2] || m[4]] = sub_members
        end
      else
        members << text[/\w+\s*\z/]&.strip
      end
    else
      decl << ch
    end
  end
  [members.compact, named]
end

def c_declared(header)
  # Comments carry braces and semicolons of their own — the header's opening
  # note is full of `{"type":"Identifier","names":[…]}` — so they go first.
  # `extern "C" {` goes too: it is a linkage block, not a declaration, and
  # leaving it would put every struct in the file one brace deep.
  src = File.read(header).gsub(%r{/\*.*?\*/}m, " ").gsub(/extern\s+"C"\s*\{/, " ")
  _members, named = c_decls(src)
  named
end

# `NumberLit.value` is a `NumberLitValue` — an adjacently tagged enum — and
# the header models it as a discriminator plus the two payloads rather than as
# one member, so it has no same-named member by design. Every other Rust field
# in `C_DECL` is expected to be a member of the same name.
C_RENAMED = { "NumberLit" => { "value" => %w[value_kind int_value float_value] } }.freeze

def check_c_header(header)
  declared = c_declared(header)
  C_DECL.filter_map do |c_struct, rust|
    members = declared[c_struct]
    next if members.nil? # not modelled, so not a defect
    next unless STRUCTS.key?(rust)

    missing = STRUCTS[rust].keys.reject do |field|
      members.include?(field) || C_RENAMED.dig(rust, field)&.any? { |m| members.include?(m) }
    end
    next if missing.empty?

    "#{rust}: `#{missing.join('` `')}` declared nowhere in `struct #{c_struct}` " \
      "of #{File.basename(header)}"
  end
end


CHECKS = {
  "ruby" => -> { check_ruby(File.expand_path("../ruby/lib/kcl_lib/ast.rb", __dir__)) },
  "julia" => -> { check_julia(File.expand_path("../julia/src/ast.jl", __dir__)) },
  "lua" => -> { check_lua(File.expand_path("../lua/kcl_lib/ast.lua", __dir__)) },
  "dart" => -> { check_dart(File.expand_path("../dart/lib/src/ast", __dir__)) },
  "python" => -> { check_python(File.expand_path("../python/kcl_lib/ast", __dir__)) },
  "typescript" => -> { check_typescript(File.expand_path("../wasm/src/ast", __dir__)) },
  "dotnet" => -> { check_dotnet(File.expand_path("../dotnet/KclLib.AST", __dir__)) },
  "zig" => -> { check_zig(File.expand_path("../zig/src/ast", __dir__)) },
  "swift" => -> { check_swift(File.expand_path("../#{SWIFT_FILE}", __dir__)) },
  "nodejs" => -> { check_nodejs(File.expand_path("../nodejs/src/ast", __dir__)) },
  "java" => -> { check_java(File.expand_path("../#{JAVA_AST_DIR}", __dir__)) },
  "kotlin" => -> { check_java(File.expand_path("../#{KOTLIN_AST_DIR}", __dir__), :kotlin) },
  "go" => -> { check_go(File.expand_path("../#{GO_AST_DIR}", __dir__)) },
  "php" => -> { check_php(File.expand_path("../php/src/Ast", __dir__)) },
  "c" => -> { check_c(File.expand_path("../#{C_AST_HEADER}", __dir__)) },
  # `cpp/include/kcl_lib_ast.hpp` declares no struct and reads no wire key:
  # it hands `ast_json` straight to `kcl_ast_parse_module` and wraps the
  # result in a `unique_ptr`. Every field a C++ caller can observe is
  # therefore the one the C loader reads, and the entry names the header a
  # C++ caller would name and follows the include it declares. It is a
  # second entry over the same loader on purpose: if C++ ever grows a loader
  # of its own, the include stops being where its types come from and this
  # entry fails rather than quietly re-reporting C's result.
  "cpp" => lambda {
    native = File.expand_path("../#{CPP_NATIVE_HEADER}", __dir__)
    # The C half contributes its reads and nothing else: the leaf is asked of
    # the native decoder, because C++ has one `Comment` decoder per leaf
    # position, not two, and `LEAF_CHECKED` is a count out of that number.
    check_c(File.expand_path("../#{CPP_AST_HEADER}", __dir__), :cpp, leaf: false) +
      check_cpp_native(native)
  },
}.freeze

# `CHECKS` is a registry; the loop below is the CLI. Requiring this file from a
# scratch checker or from the self-test has to get the former without the latter.
if $PROGRAM_NAME == __FILE__
  wanted = ARGV.empty? ? CHECKS.keys : ARGV
  exit_code = 0

  # The fixture the leaf rule is measured against, before any binding is
  # touched: it is what proves the wire carries a `{field: …}` object under
  # `node` at all. Reporting it separately keeps "every decoder reads into the
  # payload" from being taken on trust when the thing being read is unverified.
  round_trip_problems, comments = comment_round_trip
  if round_trip_problems.empty?
    puts "captured ast_json: #{comments} comment(s) carry a {field: …} object under `node`, " \
         "each field non-blank and verbatim in the source it was parsed from"
  else
    exit_code = 1
    puts "captured ast_json: #{round_trip_problems.length} problem(s)"
    round_trip_problems.each { |p| puts "  #{p}" }
  end

  wanted.each do |name|
    fn = CHECKS[name]
    if fn.nil?
      warn "no checker for #{name}"
      next
    end
    problems = fn.call.uniq
    seen = COVERAGE[name.to_sym]
    blind = UNRESOLVED[name.to_sym]
    leaves = LEAF_CHECKED[name.to_sym]
    # Three ways to be clean by not looking, and only the first of them is a
    # problem list. A struct no decoder reaches never becomes a read at all, so
    # `missing` is the only thing that can see it; a struct that is reached but
    # whose reads all resolve to fields Rust does not have is `gaps`; and a read
    # whose payload the payload table could not name skips rule 2 rather than
    # satisfying it, which is `blind`. All three were zero across every binding
    # once they were looked for, and each had hidden a real defect since — a
    # `Type` decoder that dropped every payload it was given, a `Type` registry
    # keyed on the tags of a different enum. Reporting them without failing left
    # CI green over all three.
    missing = STRUCTS.keys.select { |s| checkable?(s) && !REACHED[name.to_sym].include?(s) }.sort
    gaps = (REACHED[name.to_sym].uniq - CHECKED[name.to_sym].uniq).select { |g| checkable?(g) }.sort
    # A leaf decoder that stopped being found would drop `compare_leaf`'s half
    # of the job silently, which is the exact failure this file keeps guarding
    # against elsewhere: counted, and refused as "ok" at zero.
    leaf_blind = LEAF_POSITIONS.length - leaves
    # A checker that matched nothing is not a passing checker. Refusing to call
    # it "ok" is the whole point of counting.
    if seen.zero?
      puts "#{name}: 0 field decoders compared - the checker matched nothing"
      exit_code = 1
    elsif problems.empty?
      if missing.any? || gaps.any? || blind.positive? || leaf_blind.positive?
        puts "#{name}: ok (#{seen} field decoders), but"
        puts "  #{missing.length} struct(s) no decoder reaches: #{missing.join(' ')}" unless missing.empty?
        puts "  #{gaps.length} struct(s) reached but never compared: #{gaps.join(' ')}" unless gaps.empty?
        puts "  #{blind} payload(s) unresolved so unchecked" unless blind.zero?
        puts "  #{leaf_blind} leaf payload decoder(s) not found so unchecked" unless leaf_blind.zero?
        exit_code = 1
      else
        puts "#{name}: ok (#{seen} field decoders)"
      end
    else
      puts "#{name}: #{problems.length} problem(s) out of #{seen} field decoders"
      problems.sort.each { |p| puts "  #{p}" }
      exit_code = 1
    end
  end

  # How many leaf decoders were actually compared, per binding. It is one per
  # binding today and the rule is only worth anything if it stays one: a
  # language whose decoder stopped matching would otherwise report "ok" over a
  # `Comment` it is no longer looking at.
  counts = wanted.map { |n| "#{n} #{LEAF_CHECKED[n.to_sym]}/#{LEAF_POSITIONS.length}" }
  puts "leaf payload descent: #{counts.join(', ')}"
  exit(exit_code)
end


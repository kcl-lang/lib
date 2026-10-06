# frozen_string_literal: true

# The canonical form every AST dump is compared in, and the differ that reads
# it. Shared by `hack/ast_diff.rb` and `hack/test_ast_diff.rb`.
#
# ---------------------------------------------------------------------------
# What this is for
# ---------------------------------------------------------------------------
#
# `hack/check_ast_field_types.rb` reads each binding's decoder *source* and
# compares the field names it finds against the Rust struct definitions. It
# cannot see a decoder that is structurally right and behaviourally wrong.
# That bug class — a payload decoded one nesting level too deep or too shallow
# — has shipped five times, and every occurrence produced `undefined` / `None`
# / `""` rather than raising, so nothing failed.
#
# So: run each binding's real decoder over the same captured parser output
# (`testdata/ast/alignment.json`) and diff what comes out against the
# golden. The reference *is* the golden, walked alongside the dump. Any
# difference is either a real bug in one binding or a documented modelling
# difference, and the report says which.
#
# ---------------------------------------------------------------------------
# The canonical form
# ---------------------------------------------------------------------------
#
# The canonical form is the wire shape with six reductions applied to both
# sides at once. It is not a new schema: it is the golden with the incidental
# differences between fourteen languages removed, so a diff line always points
# at something a decoder got wrong rather than at a naming convention.
#
#   R1  key names        lowercase, drop `_`. `end_line` / `endLine` /
#                        `EndLine` all become `endline`. A binding that
#                        renames a field for its own idiom (Dart's `ifCond`
#                        for `if_cond`, Ruby's `as_name` for `asname`) is
#                        normalising, not mis-decoding.
#
#   R2  `Pos` hoisting   `Node<T>` flattens the five position keys onto the
#                        wrapper; a binding that nests them under `pos` /
#                        `position` is modelling the same wrapper
#                        differently. An object whose keys are all position
#                        keys is hoisted into its parent. No payload in
#                        `ast.rs` has a key set made only of position keys,
#                        so the rule cannot fire on one.
#
#   R3  null ≡ absent    serde writes an explicit `null` for every
#                        `Option::None`; a binding with a nullable field also
#                        writes `null`; a binding that omits the field is
#                        saying the same thing. This cannot hide a decode bug:
#                        a wrong value is never `null`, and `null` where the
#                        golden has a value is still a difference.
#
#   R4  empty ≡ absent   an empty sequence and an absent one carry the same
#                        information. This is what makes the trailing
#                        `TFuncNoArgs = () -> bool` — whose `params_ty` is
#                        `null` on the wire, not `[]` — comparable with a
#                        binding that normalises it to `[]`. That
#                        normalisation has been signed off, so the report
#                        names it rather than calling it a bug; see
#                        `counts[:empty_is_absent]`.
#
#   R5  `is_shorthand`   `#[serde(skip_serializing_if = "is_false")]` drops
#                        the key when false, so absent and `false` are the
#                        same value here too.
#
#   R6  lone `text`      `Comment` is a plain struct with one `String` field,
#                        so the object under `node` is `{"text": "…"}`. A
#                        binding that models the payload as the bare text is
#                        making the same statement differently, and is read
#                        as `{"text": <the text>}`. This is the only
#                        single-key object in `ast.rs` that has a scalar
#                        equivalent, and it is the shape behind the "every
#                        comment decodes to the empty string" bug that
#                        shipped five times, so it gets an explicit rule
#                        rather than a diff nobody reads.
#
#   R7  `value`          `ast::Type` is `#[serde(tag = "type", content =
#                        "value")]`, so the wire puts the variant's payload
#                        under `value`: `{"type":"List","value":{…}}`. A
#                        binding that models the variant as a class makes the
#                        payload the class's own fields — Ruby has
#                        `ListType(inner_type)` and `BasicType(name)` where
#                        the wire calls that scalar `value`. The wrapper key
#                        is a serde artifact, so it is removed from the golden
#                        side and the payload compared against the class's
#                        fields. Three shapes, each forced by the key sets:
#                        the payload's keys *are* the class's keys; the
#                        payload sits in a single wrapper field
#                        (`NamedType#identifier`); or the payload is a scalar
#                        and the class has exactly one field, in which case
#                        the two values must be equal for the rule to fire.
#
#   R8  newtype field    `Expr::Identifier(Identifier)` is an internally
#                        tagged *newtype* variant, so serde flattens the
#                        struct's fields into the variant and the wire is
#                        `{"type":"Identifier","names":[…],"pkgpath":"",
#                        "ctx":"Load"}`. A binding that keeps the field —
#                        Ruby, nodejs, wasm, python, C++, .NET all do — writes
#                        `IdentifierExpr(identifier: …)`. When the dump has
#                        exactly one field and its keys cover the golden's,
#                        the comparison goes through it. Forced: there is only
#                        one candidate, and a decoder that read the wrong one
#                        still produces a wrong value.
#
#   R9  flat newtype     `ast::NumberLitValue` is itself
#                        `#[serde(tag="type", content="value")]` over
#                        newtype arms, so the wire nests
#                        `{"type":"Int","value":0}` inside `NumberLit.value`.
#                        A binding that flattens the arm keeps `(value_tag,
#                        value)` as siblings — and says so in its own
#                        contract test ("Expr and Stmt newtype variants are
#                        flattened, not wrapped"). When the golden's value at a
#                        key is a tagged newtype and the dump's is a scalar,
#                        and exactly one sibling key holds that tag, the two
#                        are the same payload. The tag forces the sibling, so
#                        this cannot paper over a wrong read.
#
#   R10 ambiguous DTO    Seven names are both a plain struct and an enum
#                        variant (`Identifier`, `Target`, `CallExpr`,
#                        `CheckExpr`, `SchemaExpr`, …). A binding's own tag is
#                        not a diff when the golden object is untagged: the
#                        binding tagged its own DTO because the class serves
#                        both roles. Counted, not ignored.
#
#   R11 `Unknown` raw    A tag the binding does not know degrades to
#                        `UnknownExpr` / `UnknownStmt` / `UnknownType`. Some
#                        bindings keep the payload (`raw`), some drop it. The
#                        golden has the payload, so when a dump keeps it the
#                        two are compared — and when it does not, that is
#                        exactly the five-times-shipped bug and the diff says
#                        so by name. This rule is the reason the harness needs
#                        a `@raw` key at all.
#
#   R12 raw passthrough  The discriminator is a plain `type` key with no class
#                        claim behind it. Either a dump hands back the wire
#                        object instead of a decoded one — Ruby's
#                        `LiteralType#value` is the raw `LiteralTypeValue`
#                        hash, not a modelled variant — or the class keeps its
#                        tag in a field of its own, so there is nothing for
#                        CLASS_TAGS to key on (python's `NumberLitValue#kind`,
#                        `MemberOrIndex#kind`). The `type` key is still
#                        compared as an ordinary key, so a passthrough that
#                        dropped a field is still a diff; what is lost is the
#                        class cross-check at that node, and the report counts
#                        how many nodes that was.
#
#   R13 flattened        A `NodeRef` whose *payload* the binding flattened
#   `NodeRef`            onto the wrapper. `Comment` is a one-field struct
#                        behind `NodeRef<Comment>`, and Node.js returns
#                        `{...position, text}` rather than
#                        `{node: {text}, ...position}` — deliberately, with a
#                        comment saying so. The mirror image of R2: there the
#                        position is nested, here the payload is spread. Only
#                        fires when the dump actually carries the payload's
#                        keys, so a decoder that *dropped* the payload
#                        instead of flattening it still fails.
#
#   R14 `null` element    Lua's `dkjson` maps a JSON `null` to `nil`, and a
#                        `nil` inside an array makes `ipairs` stop early,
#                        silently truncating every `Vec<Option<…>>` field in
#                        the AST — `Arguments.defaults` and
#                        `Arguments.ty_list` among them, whose elements are
#                        index-aligned with `args`. The Lua binding decodes
#                        with a `json.null` sentinel instead and reports an
#                        absent element as `false` so the list stays dense.
#                        Both decisions are documented at the top of
#                        `lua/kcl_lib/ast.lua`. Only the *absent* element is
#                        read this way: a `false` where the golden has a
#                        number is still a diff.
#
# Two things the canonical form deliberately does *not* do: it never fills in
# a value the dump is missing, and it never drops one the golden has. Both
# would make the diff quiet in exactly the places it needs to be loud. Every
# rule above is *forced*: each one only fires when the two sides have exactly
# one shape in which they could be saying the same thing, so a decoder that
# read the wrong field never satisfies a rule — it produces a diff.
#
# ---------------------------------------------------------------------------
# Reflected dumps
# ---------------------------------------------------------------------------
#
# A binding whose decoder has no serializer cannot hand back the wire shape,
# so its dumper walks the decoded object graph by reflection and writes a tree
# in the same shape, with up to two extra keys per object:
#
#   "@cls"  the language's own class / struct / case name, verbatim. Present
#           on every object the dumper visits, so a binding that renames a
#           class away from Rust is caught even when the tag is retained.
#   "@tag"  the wire tag, when the binding keeps it as a *value*:
#           `Taggable#tag` in Ruby, the `type` property in Node.js and WASM,
#           the `tag` getter in Dart, `node_type(::IdentifierExpr)` in Julia,
#           the enum case in Swift.
#
# Both are cross-checked. `@tag` is the binding's own claim; CLASS_TAGS below
# is the harness's independent claim; the golden is the referee. A binding
# whose class name is in none of them is a hard failure naming the class, and
# a class name that resolves to a different tag than the binding claims is a
# difference, not a shrug.

require "json"

module AstDiff
  module Canonical
    SCHEMA = "kcl-ast-canonical/1"

    # The five keys of `ast::Pos`, already through R1.
    POS_KEYS = %w[column endcolumn endline filename line].freeze

    # Keys a binding uses for a nested position (R2).
    POS_CONTAINERS = %w[pos position].freeze

    # `#[serde(skip_serializing_if = "is_false")]` — see R5.
    SKIP_IF_FALSE = %w[isshorthand].freeze

    # Wire tags by the *normalised* class name a binding gives the type. R1
    # applied to a class name, so `SchemaStmt`, `schema_stmt` and `schemastmt`
    # all land on `schemastmt`.
    #
    #   "Identifier"  a variant: always carries the tag
    #   nil           a plain struct: never carries a tag
    #   :ambiguous    both — resolved by asking the golden, see `AMBIGUOUS`
    CLASS_TAGS = {
      # -- ast::Stmt --------------------------------------------------------
      "typealiasstmt" => "TypeAlias",
      "exprstmt" => "Expr",
      "unificationstmt" => "Unification",
      "assignstmt" => "Assign",
      "augassignstmt" => "AugAssign",
      "assertstmt" => "Assert",
      "ifstmt" => "If",
      "importstmt" => "Import",
      "schemastmt" => "Schema",
      "schemaattr" => "SchemaAttr",
      "rulestmt" => "Rule",
      "unknownstmt" => nil,

      # -- ast::Expr --------------------------------------------------------
      "targetexpr" => "Target",
      "identifierexpr" => "Identifier",
      "unaryexpr" => "Unary",
      "binaryexpr" => "Binary",
      "ifexpr" => "If",
      "selectorexpr" => "Selector",
      "parenexpr" => "Paren",
      "quantexpr" => "Quant",
      "listexpr" => "List",
      "listifitemexpr" => "ListIfItem",
      "listcomp" => "ListComp",
      "starredexpr" => "Starred",
      "dictcomp" => "DictComp",
      "configifentryexpr" => "ConfigIfEntry",
      "configexpr" => "Config",
      "lambdaexpr" => "Lambda",
      "subscript" => "Subscript",
      "keywordexpr" => "Keyword",
      "argumentsexpr" => "Arguments",
      "compare" => "Compare",
      # The C binding names these two arms after the union field they sit in
      # (`c/include/kcl_lib_ast.h`, `kcl_expr_data.u.subscript_expr` and
      # `.compare_expr`) rather than after the variant, so they arrive with
      # the `Expr` suffix the other bindings' class names carry. Same two
      # tags, spelled the way that binding spells them.
      "subscriptexpr" => "Subscript",
      "compareexpr" => "Compare",
      "numberlit" => "NumberLit",
      "stringlit" => "StringLit",
      "nameconstantlit" => "NameConstantLit",
      "joinedstring" => "JoinedString",
      "formattedvalue" => "FormattedValue",
      "missingexpr" => "Missing",
      "unknownexpr" => nil,

      # -- ast::Type --------------------------------------------------------
      "anytype" => "Any",
      "basictype" => "Basic",
      "namedtype" => "Named",
      "listtype" => "List",
      "dicttype" => "Dict",
      "uniontype" => "Union",
      "literaltype" => "Literal",
      "functiontype" => "Function",
      "unknowntype" => nil,
      "kcltypenode" => nil,
      "typenode" => nil,
      "asttype" => nil,

      # -- ast::MemberOrIndex arms ------------------------------------------
      # The tag is a value here, not a type: `MemberOrIndex` is
      # `#[serde(tag = "type", content = "value")]` over two payloads, so a
      # binding that keeps it as a string is the common case and `Member` /
      # `Index` are the fallback for one that models the arms as classes.
      "member" => "Member",
      "index" => "Index",
      "memberorindex" => nil,

      # -- plain structs: no tag on the wire ---------------------------------
      "module" => nil,
      "kclmodule" => nil,
      "node" => nil,
      "noderef" => nil,
      "pos" => nil,
      "comment" => nil,
      "configentry" => nil,
      "keyvaluepair" => nil,
      "compclause" => nil,
      "schemaindexsignature" => nil,
      "arguments" => nil,
      "keyword" => nil,
      "numberlitvalue" => nil,
      "literaltypevalue" => nil,
      # The C++ header calls the same union `LiteralValue`
      # (`cpp/include/kcl_ast.hpp`, `struct LiteralValue`) rather than
      # `LiteralTypeValue`, so its `@cls` arrives under this spelling. Same
      # shape and same reason as the two above it: it is one struct per
      # *union* with a `kind`, not one per arm, so the wire's tag sits in a
      # field of its own and there is nothing for CLASS_TAGS to key on.
      "literalvalue" => nil,
      # `ast.rs:1909` `pub struct IntLiteralType { value, suffix }` — the
      # payload of `LiteralType::Int`. The tag `Int` belongs to the *enum
      # variant* wrapping it, so the struct itself is untagged: the wire is
      # `{"type":"Int","value":{"value":1,"suffix":null}}` and the inner
      # object has no `type` key of its own. Swift is the one binding that
      # models it as a named struct (`Pos.swift:528`); the others keep the
      # payload raw.
      "intliteraltype" => nil,
      "exprcontext" => nil,
      "op" => nil,
      "unaryop" => nil,
      "binop" => nil,
      "cmpop" => nil,
      "augop" => nil,
      "configentryoperation" => nil,
      "quantoperation" => nil,
      "numberbinarysuffix" => nil,
      # The sealed base classes and the marker enums, which only ever appear
      # as a wrapper or a scalar and never as a payload object of their own.
      "kclstmt" => nil,
      "kclexpr" => nil,
      "stmt" => nil,
      "expr" => nil,
      "type" => nil,

      # -- names that are both a plain struct and an enum variant ----------
      # `Identifier` is an `Expr` variant *and* a plain struct;
      # `Target` / `Keyword` / `Arguments` likewise; `CallExpr` /
      # `CheckExpr` / `SchemaExpr` are the DTO spelling of `Expr::Call` /
      # `Expr::Check` / `Expr::Schema`. There is no signal in the value
      # itself, so the golden decides: if the object at this path carries a
      # `type`, it is the variant; if it does not, it is the plain struct.
      # Guessing wrong would put a spurious `type` on every DTO in the file.
      "identifier" => :ambiguous,
      "target" => :ambiguous,
      "callexpr" => :ambiguous,
      "checkexpr" => :ambiguous,
      "schemaexpr" => :ambiguous,
      "schemaconfig" => :ambiguous,
      "decorator" => :ambiguous
    }.freeze

    # The subset of CLASS_TAGS resolved by consulting the golden. Named so
    # the report can explain the rule rather than leaving a reader to find it.
    AMBIGUOUS = CLASS_TAGS.select { |_, v| v == :ambiguous }.keys.freeze

    # The tag each ambiguous name means when the golden says "variant".
    AMBIGUOUS_TAGS = {
      "identifier" => "Identifier",
      "target" => "Target",
      "callexpr" => "Call",
      "checkexpr" => "Check",
      "schemaexpr" => "Schema",
      "schemaconfig" => "Schema",
      "decorator" => "Call"
    }.freeze

    # The classes a binding falls back to for a tag it does not know. R11
    # needs them: a payload the binding did not keep is the bug this harness
    # was built to find, and it can only be named if the class is recognised
    # as the fallback rather than as a real variant.
    UNKNOWN_CLASSES = %w[unknownexpr unknownstmt unknowntype].freeze

    # R1. Class names and field names are both normalised this way, so
    # `EndLine`, `end_line` and `endline` are the same key.
    def self.norm_key(name)
      name.to_s.downcase.delete("_")
    end

    # CLASS_TAGS is keyed by the R1 normalisation of a class name, and a typo
    # in a key is invisible: the entry simply never matches and the class
    # arrives as unmapped. That happened once during development
    # (`"schemattr"` for `SchemaAttr`, whose normalisation is `schemaattr` —
    # no underscore, because `norm_key` only lowercases and deletes `_`).
    # So every key is checked against its own normalisation at load, and a
    # typo is a crash rather than a silent gap.
    CLASS_TAGS.each_key do |key|
      next if key == norm_key(key)

      raise ArgumentError, <<~MSG
        AstDiff::Canonical::CLASS_TAGS has a key that is not its own R1
        normalisation, so it could never match a class name:

            key:         #{key.inspect}
            normalised:  #{norm_key(key).inspect}

        Fix: rename the key to the normalised spelling, or to the class name
        it is meant to describe with the underscore removed.
      MSG
    end

    class UnmappedClass < StandardError; end

    # -------------------------------------------------------------------------
    # Comparing a dump against the golden
    # -------------------------------------------------------------------------

    Difference = Struct.new(:kind, :path, :expected, :actual, :note, keyword_init: true) do
      def to_s
        detail =
          case kind
          when :missing_key then "the golden has #{expected.inspect}, the dump has nothing"
          when :extra_key then "the golden has nothing, the dump has #{actual.inspect}"
          when :shape then "expected #{expected}, got #{actual}"
          when :tag then "the golden tags this #{expected.inspect}, the dump says #{actual.inspect}"
          else "expected #{expected.inspect}, got #{actual.inspect}"
          end
        "#{path}: #{detail}#{note ? " (#{note})" : ''}"
      end
    end

    # The number of objects and leaves the golden itself walks, which is what
    # every floor is measured against. `hack/ast_diff.rb` and
    # `hack/test_ast_diff.rb` both call this rather than each doing it
    # themselves: a floor checked against one reference in the report and a
    # second one in the self-test is not a floor, it is two numbers that agree
    # by coincidence until the golden changes.
    def self.reference_counts(root)
      cmp = Comparator.new
      cmp.compare(root, root)
      cmp.counts
    end

    class Comparator
      # How many objects a dump is allowed to reach relative to the golden's.
      # A binding that "agrees" because it resolved nothing comes in at a
      # small fraction of the reference; one that agrees because it agrees is
      # at 1.0. `hack/test_ast_diff.rb` asserts both ends of this.
      MIN_OBJECT_RATIO = 0.95

      attr_reader :diffs, :counts, :payloads, :unmapped

      # `ignore_extra` maps a key to a reason. A key the golden does not have
      # is only allowed through if it is on that list, and the reason is
      # printed, because a key that silently disappears is a hole in the diff.
      #
      # `renames` maps a dump-side key to the wire key it stands for, after R1
      # and before anything else; `class_renames` is the same table scoped to
      # one class, keyed by the class name, for a field whose *name* only
      # collides in one place. One entry per real rename, each with a comment
      # in `bindings.rb` naming the Rust field it is.
      def initialize(ignore_extra: {}, renames: {}, class_renames: {})
        @diffs = []
        @counts = Hash.new(0)
        @payloads = 0
        @ignore_extra = ignore_extra
        @renames = renames
        @class_renames = class_renames
        @unmapped = []
      end

      def compare(expected, actual, path = "module")
        case expected
        when Hash then compare_object(expected, actual, path)
        when Array then compare_array(expected, actual, path)
        else compare_scalar(expected, actual, path)
        end
      end

      def empty? = @diffs.empty?

      private

      def compare_scalar(expected, actual, path)
        @counts[:leaves] += 1
        return if expected == actual

        @diffs << Difference.new(kind: :value, path: path, expected: expected, actual: actual)
      end

      def compare_array(expected, actual, path)
        @counts[:arrays] += 1
        # R4 — an empty sequence and an absent one carry the same information.
        # This is the rule that lets a binding that normalises the golden's
        # `params_ty: null` to `[]` compare equal, and it is counted so the
        # report can name it as a normalisation rather than a pass.
        if expected.empty? && (actual.nil? || (actual.is_a?(Array) && actual.empty?))
          @counts[:empty_is_absent] += 1
          return
        end
        unless actual.is_a?(Array)
          @diffs << Difference.new(kind: :shape, path: path,
                                    expected: "an array of #{expected.size}",
                                    actual: describe(actual))
          return
        end
        if actual.size != expected.size
          @diffs << Difference.new(kind: :shape, path: path,
                                    expected: "an array of #{expected.size}",
                                    actual: "an array of #{actual.size}")
        end
        expected.each_with_index do |item, i|
          next if i >= actual.size

          # R14 — a `null` element read as `false`. Lua's `dkjson` maps a JSON
          # null to `nil`, and a `nil` inside an array makes `ipairs` stop
          # early, silently truncating every `Vec<Option<…>>` field in the
          # AST. The binding therefore decodes with a `json.null` sentinel and
          # reports an absent element as `false`; both decisions are spelled
          # out at the top of `lua/kcl_lib/ast.lua` and both preserve the slot
          # the golden has. The value is still checked: a `false` where the
          # golden has a number is a diff.
          if item.nil? && actual[i] == false
            @counts[:null_element_as_false] += 1
            next
          end

          compare(item, actual[i], "#{path}[#{i}]")
        end
      end

      # Objects are counted on the *golden* side only. A dump that models a
      # variant as a class has, by construction, one fewer object for it than
      # the wire has, so counting dump objects would make a correct decoder
      # look short. Counting golden objects makes the number mean what the
      # vacuity floor needs it to mean: how much of the golden this walk
      # actually reached. A dump that resolved nothing stops descending at
      # the first shape mismatch, and the count says so.
      #
      # R7 and R9 reconcile a golden object into its parent instead of walking
      # into it, so they add one back: an inlined object was reached and
      # compared, just not descended into. Without that, a binding that models
      # `Type` as classes would sit permanently a little under the floor
      # precisely because it is right.
      def compare_object(expected, actual, path)
        @counts[:objects] += 1

        # R6 — a lone `{text}` read as a bare string.
        if expected.size == 1 && expected.key?("text") && actual.is_a?(String)
          @counts[:comment_as_bare_string] += 1
          return compare_scalar(expected["text"], actual, "#{path}.text")
        end

        unless actual.is_a?(Hash)
          @diffs << Difference.new(kind: :shape, path: path,
                                    expected: "an object with #{expected.keys.sort.join(', ')}",
                                    actual: describe(actual))
          return
        end

        expected_tagged = expected.key?("type")
        wanted = expected["type"]

        e = keyed(expected)
        a = keyed(actual, actual["@cls"])
        e, a = unwrap_adjacent_value(e, a)    # R7
        e, a = inline_flattened_node(e, a)     # R13
        e, a = unwrap_newtype(e, a)            # R8
        e, a = flatten_newtype_payload(e, a)  # R9
        e, a = spread_payload_fields(e, a)     # R15

        tag = resolve_tag(wanted, expected_tagged, a, path)
        a = a.merge("type" => tag) if tag && !body(a).key?("type")

        e.each do |key, value|
          next if key.start_with?("@")
          next if a.key?(key)

          next if absent_equivalent?(value) # R3 / R4 / R5

          @diffs << Difference.new(kind: :missing_key, path: "#{path}.#{key}",
                                   expected: preview(value), actual: nil)
        end

        body(a).each do |key, value|
          next if e.key?(key)
          next if @ignore_extra.key?(key)
          # R4 / R5 — the golden omits `is_shorthand` when it is false, and
          # the trailing `TFuncNoArgs` has `params_ty: null` where a binding
          # that normalises null to `[]` writes an empty list. Both
          # normalisations are signed off, so neither is a difference; the
          # count is what the report names them by.
          if absent_equivalent?(value)
            @counts[:empty_is_absent] += 1
            next
          end

          @diffs << Difference.new(kind: :extra_key, path: "#{path}.#{key}",
                                   expected: nil, actual: preview(value),
                                   note: @ignore_extra[key])
        end

        e.each do |key, value|
          next if key.start_with?("@")
          next unless a.key?(key)

          compare(value, a[key], "#{path}.#{key}")
        end

        compare_raw(expected, a, path) # R11
      end

      # R7 — the `value` of an adjacently-tagged enum is a serde artifact.
      # See the header for the three shapes and why each is forced.
      def unwrap_adjacent_value(e, a)
        return [e, a] unless e.key?("value") && !body(a).key?("value")

        payload = e["value"]
        rest = body(a).reject { |k, _| k == "type" }

        if payload.is_a?(Hash)
          payload = keyed(payload)
          # (i) the payload's keys are the class's own keys.
          if !rest.empty? && (payload.keys - rest.keys).empty?
            @counts[:adjacent_value_inlined] += 1
            @counts[:objects] += 1 # the payload object, reconciled rather than walked
            return [inline_value(e, payload), a]
          end
          # (ii) the payload sits in one wrapper field — `NamedType#identifier`.
          if rest.size == 1
            inner = rest.values.first
            if inner.is_a?(Hash)
              inner = keyed(inner)
              if (payload.keys - inner.keys).empty?
                @counts[:adjacent_value_inlined] += 1
                @counts[:newtype_unwrapped] += 1
                @counts[:objects] += 1 # the payload object, reconciled rather than walked
                return [inline_value(e, payload), absorb(a, inner, rest.keys.first)]
              end
            end
          end
        elsif !payload.nil? && rest.size == 1
          # (iii) a scalar payload under a name of the binding's choosing —
          # `BasicType#name` for the wire's `{"type":"Basic","value":"Str"}`.
          # The rule only fires when the two values are equal, so a decoder
          # that read the wrong field does not satisfy it. Both keys go: the
          # wire's `value` and the field that stood in for it.
          if rest.values.first == payload
            @counts[:adjacent_value_inlined] += 1
            return [e.reject { |k, _| k == "value" }, a.reject { |k, _| k == rest.keys.first }]
          end
        end
        [e, a]
      end

      # R13 — a `NodeRef` whose payload the binding flattened onto the
      # wrapper. `Comment` is a one-field struct behind `NodeRef<Comment>`, and
      # Node.js returns `{...position, text}` rather than `{node: {text},
      # ...position}` — deliberately, and with a comment saying so
      # (`nodejs/src/ast/_base.mjs:commentFromWire`). Same class of modelling
      # difference as R2, one level in: the position instead of the payload.
      # Only fires when the dump actually carries the payload's keys, so a
      # decoder that dropped the payload instead of flattening it still fails.
      def inline_flattened_node(e, a)
        return [e, a] unless e["node"].is_a?(Hash) && !body(a).key?("node")

        payload = keyed(e["node"])
        rest = body(a).reject { |k, _| k == "type" }
        return [e, a] if rest.empty? || !(payload.keys - rest.keys).empty?

        @counts[:flattened_node_ref] += 1
        [e.reject { |k, _| k == "node" }.merge(payload) { |_k, outer, _i| outer }, a]
      end

      # R8 — an internally tagged *newtype* variant, flattened by serde into
      # the variant, and kept as a field by the binding. `Expr::Identifier
      # # (Identifier)` is the one the golden has 57 of.
      def unwrap_newtype(e, a)
        return [e, a] if e.key?("value") # R7 owns this shape

        rest = body(a).reject { |k, _| k == "type" }
        return [e, a] unless rest.size == 1

        inner = rest.values.first
        return [e, a] unless inner.is_a?(Hash)

        inner = keyed(inner, a["@cls"])
        # The wrapper has to actually cover the golden's fields, or this is
        # not a newtype — it is a payload in a differently-named field, which
        # is R7's business and only R7 may guess at.
        return [e, a] unless (e.keys - %w[type] - inner.keys).empty?

        @counts[:newtype_unwrapped] += 1
        [e, absorb(a, inner, rest.keys.first)]
      end

      # R9 — a newtype payload flattened into `(tag, value)` siblings.
      def flatten_newtype_payload(e, a)
        e.each do |key, value|
          next unless value.is_a?(Hash) && value.keys.sort == %w[type value]
          next unless a.key?(key) && !a[key].is_a?(Hash)

          tag = value["type"]
          holder = body(a).reject { |k, _| k == key || k == "type" }
          candidates = holder.select { |_, v| v == tag }
          next unless candidates.size == 1

          holder_key = candidates.keys.first
          @counts[:newtype_payload_flattened] += 1
          @counts[:objects] += 1 # the `{type, value}` object, reconciled rather than walked
          e = e.reject { |k, _| k == key }
          e = e.merge(key => value["value"], holder_key => tag)
          a = a.merge(key => a[key])
        end
        [e, a]
      end

      # R15 — an adjacently-tagged newtype whose payload's own fields the
      # binding spread as siblings of `value` instead of nesting them.
      #
      # `LiteralType::Int` is the one the golden has. The wire is
      # `{"type":"Int","value":{"value":1,"suffix":null}}`; the Swift binding
      # models the payload as `IntLiteralType { value: Int64, suffix: … }`
      # (`Pos.swift:528`), and `IntLiteralType` has its *own* field called
      # `value`. So the payload's `value` scalar lands on the wrapper's `value`
      # key and the rest of the payload sits beside it — the mirror image of
      # R7, which nests what this spreads.
      #
      # Forced, like every other rule: it fires only when the dump's own
      # non-`@` keys are *exactly* the payload's keys, so a binding that kept
      # the payload nested (which is what Ruby, Python, Node.js and Lua all
      # do) does not satisfy it, and a binding that spread the payload but
      # dropped a field from it does not either.
      def spread_payload_fields(e, a)
        return [e, a] unless e.keys.sort == %w[type value]
        # The dump must actually have *spread* the payload. A binding that kept
        # the wire object whole — `Ruby::NumberLit#value` is the raw
        # `NumberLitValue` hash, `ast.rs` `NumberLitValue` — has nothing to
        # normalise here, and rewriting the golden to match would destroy the
        # very nesting that object is evidence of. That case is R12's.
        return [e, a] if a["value"].is_a?(Hash)

        inner = e["value"]
        return [e, a] unless inner.is_a?(Hash)

        # R3 (`keyed` drops a nil-valued optional) has already run on the dump
        # side, so `suffix: null` is gone there while the golden's payload
        # still carries it. Dropping it here too is not a weakening: R3 is the
        # rule that says a nil optional may be absent, and this rule is about
        # *which* keys are siblings, not about whether a nil is present.
        inner = inner.reject { |k, v| v.nil? && !SKIP_IF_FALSE.include?(Canonical.norm_key(k)) }
        return [e, a] if inner.empty?
        return [e, a] unless body(a).keys.sort == inner.keys.sort

        @counts[:payload_fields_spread] += 1
        @counts[:objects] += 1 # the `{type, value}` object, reconciled rather than walked
        [e.reject { |k, _| k == "value" }.merge(inner), a]
      end

      # Work out the wire tag for a dump object and check it three ways: the
      # binding's own claim (`@tag`), the harness's independent claim from
      # CLASS_TAGS (`@cls`), and the golden. Records a difference when any
      # of the three disagree; returns the tag to compare under `type`, or
      # nil when the object is untagged.
      def resolve_tag(wanted, expected_tagged, a, path)
        cls = a["@cls"]
        tag = a["@tag"]

        mapped = nil
        if cls
          @payloads += 1
          key = Canonical.norm_key(cls)
          entry =
            if CLASS_TAGS.key?(key)
              CLASS_TAGS[key]
            else
              @unmapped << cls
              @diffs << Difference.new(kind: :tag, path: path,
                                       expected: "a class this harness knows",
                                       actual: cls.inspect,
                                       note: "add it to AstDiff::Canonical::CLASS_TAGS")
              nil
            end
          case entry
          when :ambiguous then mapped = expected_tagged ? AMBIGUOUS_TAGS[key] : nil
          when nil then nil
          else mapped = entry
          end
        end

        if expected_tagged
          claimed = tag || mapped
          if claimed.nil? && a.key?("type")
            # R12 — the discriminator is a plain key with no class claim
            # behind it. Either the dump hands back the wire object rather
            # than a decoded one (`Ruby::LiteralType#value` is the raw
            # `LiteralTypeValue` hash, `ast.rs:229`), or the class keeps its
            # tag in a renamed field so there is nothing for CLASS_TAGS to
            # key on (`python`'s `NumberLitValue#kind`). Either way the
            # `type` key is compared as an ordinary key below, so a
            # passthrough that dropped a field is still a diff; what is lost
            # is the class cross-check, and the count says how often.
            @counts[cls ? :type_key_without_class_claim : :raw_passthrough] += 1
            return nil
          end
          if claimed.nil?
            @diffs << Difference.new(kind: :missing_key, path: "#{path}.type",
                                     expected: wanted.inspect, actual: nil,
                                     note: cls ? "the class #{cls} carries no wire tag" : "no tag")
          elsif claimed != wanted
            @diffs << Difference.new(kind: :tag, path: path, expected: wanted,
                                     actual: claimed,
                                     note: cls ? "the class #{cls} claims #{cls}" : nil)
          end
          claimed
        elsif tag || mapped
          # R10 — an ambiguous name used as the plain struct. The binding
          # tagged its own DTO because one class serves both roles; the
          # golden is the referee and says there is no tag here.
          if cls && mapped.nil? && tag
            @counts[:ambiguous_dto_tag] += 1
          else
            @diffs << Difference.new(kind: :extra_key, path: "#{path}.type",
                                     expected: nil, actual: (tag || mapped).inspect,
                                     note: cls ? "the golden object is untagged, but #{cls} " \
                                                  "claims a tag" : nil)
          end
          nil
        end
      end

      # R11 — a binding that kept the payload of a tag it does not know. The
      # golden is the payload, so the two are compared; a binding that dropped
      # it produces this diff by name, which is the whole point.
      def compare_raw(expected, a, path)
        raw = a["@raw"]
        if raw.nil?
          cls = a["@cls"]
          return unless cls && UNKNOWN_CLASSES.include?(Canonical.norm_key(cls))
          return unless @counts[:unknown_payload_dropped].zero?

          @counts[:unknown_payload_dropped] += 1
          @diffs << Difference.new(kind: :missing_key, path: "#{path}.@raw",
                                   expected: preview(expected), actual: nil,
                                   note: "#{cls} kept no payload for an unknown tag")
          return
        end
        return unless raw.is_a?(Hash)

        @counts[:unknown_payload_kept] += 1
        compare(expected, keyed(raw), "#{path}.@raw")
      end

      # R1 (key names), R1b (per-binding renames), R3 (null ≡ absent) and R2
      # (`Pos` hoisting) all act here.
      #
      # R2 is applied here rather than in a dumper because a dumper doing it
      # would be a place for the harness to get the same nesting wrong the
      # decoder did. `keyed` is called on the golden too, where R2 is a
      # no-op: serde already flattens the position onto the wrapper, so there
      # is no `pos` key to hoist.
      def keyed(hash, cls = nil)
        renames = @renames
        scoped = cls && @class_renames[Canonical.norm_key(cls)]
        renames = renames.merge(scoped) if scoped

        out = {}
        hash.each do |k, v|
          key = Canonical.norm_key(k)
          next if v.nil? && !SKIP_IF_FALSE.include?(key) # R3

          out[renames.fetch(key, key)] = v
        end
        hoist_pos(out)
      end

      # Take the *fields* of `inner` into `outer` without letting the inner
      # object's `@cls` / `@tag` clobber the outer's. R7, R8 and R13 all
      # descend through a wrapper the binding kept, and the wrapper is the
      # object the golden's tag is about: `NamedType(identifier: Identifier)`
      # is tagged `Named`, not `Identifier`, and swapping the claims would
      # report a tag difference on a correct decoder.
      def absorb(outer, inner, drop)
        out = outer.reject { |k, _| k == drop }
        inner.each do |k, v|
          next if k.start_with?("@") && out.key?(k)

          out[k] = v
        end
        out
      end

      # A hash without the `@`-prefixed bookkeeping keys. The rules above all
      # look at the *fields* a binding exposes, and `@cls` / `@tag` / `@raw`
      # are this harness's, not the AST's.
      def body(hash) = hash.reject { |k, _| k.start_with?("@") }

      # R2. An object whose keys are all position keys is a `Pos`; merge it
      # into the parent so the bindings that nest it under `pos` / `position`
      # and the ones that flatten it compare equal. No payload in `ast.rs`
      # has a key set made only of position keys, so this cannot fire on one.
      def hoist_pos(hash)
        POS_CONTAINERS.each do |container|
          pos = hash[container]
          next unless pos.is_a?(Hash)

          # The position's own keys go through R1 too, so `end_line` and
          # `endLine` are recognised as the same key here. The `@`-prefixed
          # bookkeeping keys are not part of the position, so they neither
          # count towards the test nor come along for the ride.
          normed = pos.each_with_object({}) do |(k, v), h|
            next if k.start_with?("@")

            h[Canonical.norm_key(k)] = v
          end
          next if normed.empty? || !(normed.keys - POS_KEYS).empty?

          merged = hash.reject { |k, _| k == container }
          merged.merge!(normed)
          @counts[:pos_hoisted] += 1
          return merged
        end
        hash
      end

      # Inline an adjacently-tagged payload into the golden side: drop the
      # `value` wrapper, spread the payload in, and do not let the payload
      # clobber the outer discriminator. `{"type":"List","value":{…}}` must
      # keep saying `List` after the `value` is spread in.
      def inline_value(e, payload)
        e.reject { |k, _| k == "value" }.merge(payload) { |_key, outer, _inner| outer }
      end

      def absent_equivalent?(value)
        return true if value.nil? # R3
        return true if value.is_a?(Array) && value.empty? # R4
        return true if value == false # R5

        false
      end

      def describe(value)
        case value
        when nil then "nothing"
        when String then "the string #{value.inspect}"
        when Array then "an array of #{value.size}"
        when Hash then "an object with #{keyed(value).keys.sort.join(', ')}"
        else value.inspect
        end
      end

      def preview(value)
        case value
        when Hash then "{#{keyed(value).keys.sort.join(', ')}}"
        when Array then "…#{value.size} item(s)"
        else value.inspect
        end
      end
    end
  end
end

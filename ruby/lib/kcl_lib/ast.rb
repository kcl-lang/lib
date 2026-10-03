# frozen_string_literal: true

require "json"

module KclLib
  # Typed AST for the Ruby binding.
  #
  # Decodes the `ast_json` string returned by `API#parse_file` /
  # `API#parse_program` into typed objects mirroring Rust's AST in
  # `../kcl/crates/ast/src/ast.rs`. The same split the C, C++, Dart, Java,
  # Kotlin, Node.js, Python, .NET, WASM, Lua, Swift, Zig and Julia bindings use
  # applies here:
  #
  #   * `Stmt` / `Expr` are `#[serde(tag = "type")]`, so each node carries a
  #     `type` discriminator and decodes to its own struct.
  #   * `Type` is `#[serde(tag = "type", content = "value")]`, so a type node is
  #     a two-key object whose `value` holds the variant's payload.
  #   * The plain structs nested inside `NodeRef<T>` — `Identifier`, `Target`,
  #     `Keyword`, `Arguments`, `ConfigEntry`, `CheckExpr`, `Decorator`,
  #     `SchemaConfig`, `CompClause` — carry no tag of their own.
  #
  # ## Names
  #
  # The class names are the Java binding's (`java/src/main/java/com/kcl/ast/`),
  # so a table read from one binding is readable in the next:
  # `Compare`, `ListComp`, `DictComp`, `NumberLit`, `StringLit`,
  # `NameConstantLit`, `JoinedString`, `FormattedValue`, `Subscript`,
  # `SchemaExpr`, `CallExpr`, `CheckExpr`, `SchemaConfig`, `Decorator`,
  # `Module`, `Pos`, `Node`.
  #
  # Two of those are *twins* of a tagged variant, and both exist because the
  # wire has two shapes for them: `CallExpr` is the tagged `Expr::Call`, while
  # `Decorator` is the untagged `{func, args, keywords}` a `decorators:` list
  # holds; `SchemaExpr` is the tagged `Expr::Schema`, while `SchemaConfig` is
  # the untagged `{name, args, kwargs, config}` an `UnificationStmt.value`
  # holds. `CheckExpr` is the one exception — the payload is identical either
  # way, so one class serves both.
  #
  # ## Unknown tags
  #
  # A `type` tag this binding does not know degrades to `UnknownExpr` /
  # `UnknownStmt` / `UnknownType` with the raw payload kept, so a newer parser
  # does not take the whole file down. That is a deliberate divergence from
  # Java, whose Jackson configuration raises on an unregistered subtype; Ruby
  # can raise too, and the trade is forward compatibility against a loud
  # failure. A payload with **no** `type` key at all is a different thing and
  # does raise — see {.expr_from_wire}.
  #
  #   require "kcl_lib"
  #
  #   m = KclLib::AST.parse_module(KclLib::API.new.parse_file(
  #     KclLib::ParseFileArgs.new(path: "main.k",
  #                               source: "schema Person:\n    name: str\n")
  #   ).ast_json)
  #
  #   m.body.each do |ref|
  #     next unless ref.node.is_a?(KclLib::AST::SchemaStmt)
  #
  #     puts ref.node.name.node
  #     ref.node.body.each { |a| puts "  #{a.node.name.node}: #{a.node.ty.node}" }
  #   end
  module AST
    # A source position, as attached to every parsed node (`ast::Pos`).
    Pos = Struct.new(:filename, :line, :column, :end_line, :end_column, keyword_init: true) do
      def to_s
        "#{filename}:#{line}:#{column}-#{end_line}:#{end_column}"
      end
    end

    # A value together with the position it was parsed at — `NodeRef<T>` in
    # Rust. `NodeRef<T>` is a boxed `Node<T>`, so the two share a JSON shape.
    Node = Struct.new(:node, :pos, keyword_init: true) do
      def to_s
        pos.nil? ? "Node(#{node})" : "Node(#{node}, #{pos})"
      end
    end

    # A `#` comment — `ast::Comment { text }`.
    Comment = Struct.new(:text, keyword_init: true)

    # -------------------------------------------------------------------------
    # Wire helpers. The snake_case mapping and the null handling live here and
    # nowhere else, so every decoder below goes through the same path.
    # -------------------------------------------------------------------------

    def self.as_map(value)
      value.is_a?(Hash) ? value : nil
    end

    def self.obj(value)
      as_map(value) || {}
    end

    # A bool field, defaulting to `false` when absent.
    #
    # `ConfigEntry.is_shorthand` carries
    # `#[serde(skip_serializing_if = "is_false")]`, so a `false` is omitted
    # from the wire entirely — `hash[key] == true` reproduces that faithfully.
    def self.flag(wire, key)
      wire[key] == true
    end

    def self.str(wire, key)
      value = wire[key]
      value.is_a?(String) ? value : ""
    end

    def self.int(value)
      value.is_a?(Integer) ? value : 0
    end

    # The `Pos` of a `NodeRef` wire object, or nil when it carries no
    # position at all.
    def self.pos_of(wire)
      return nil unless wire.key?("filename")

      Pos.new(
        filename: str(wire, "filename"),
        line: int(wire["line"]),
        column: int(wire["column"]),
        end_line: int(wire["end_line"]),
        end_column: int(wire["end_column"])
      )
    end

    # Decode a `NodeRef<String>` — the payload is a bare JSON string.
    def self.string_node(wire)
      m = as_map(wire)
      return nil if m.nil?

      Node.new(node: str(m, "node"), pos: pos_of(m))
    end

    # Decode a `NodeRef<T>` whose payload is a JSON object.
    def self.node_of(wire, &block)
      m = as_map(wire)
      return nil if m.nil?

      inner = as_map(m["node"])
      return nil if inner.nil?

      Node.new(node: block.call(inner), pos: pos_of(m))
    end

    # Decode a JSON array of `NodeRef<T>`, dropping the nulls the parser emits
    # for `Vec<Option<NodeRef<T>>>` fields.
    def self.node_list(wire, &block)
      return [] unless wire.is_a?(Array)

      wire.filter_map { |item| node_of(item, &block) }
    end

    # Decode an array of `NodeRef<String>`, e.g. `Identifier.names`.
    def self.string_node_list(wire)
      return [] unless wire.is_a?(Array)

      wire.filter_map { |item| string_node(item) }
    end

    # Decode a JSON array of `NodeRef<T>` whose elements are themselves
    # nullable, keeping the `null`s so the list lines up with
    # `Arguments.defaults` and `Arguments.ty_list` (one slot per parameter).
    def self.nullable_node_list(wire, &block)
      return [] unless wire.is_a?(Array)

      wire.map { |item| node_of(item, &block) }
    end

    # Decode a bare list of payload objects (no `NodeRef` wrapper), e.g.
    # `Vec<MemberOrIndex>` inside `Target`.
    def self.plain_list(wire, &block)
      return [] unless wire.is_a?(Array)

      wire.filter_map { |item| as_map(item) && block.call(item) }
    end

    # Decode a list of bare payload strings, e.g. `Compare.ops`.
    def self.string_list(wire, key)
      value = wire[key]
      value.is_a?(Array) ? value.grep(String) : []
    end

    # -------------------------------------------------------------------------
    # Type hierarchy — `ast::Type`
    # -------------------------------------------------------------------------

    # `Type` is declared `#[serde(tag = "type", content = "value")]`, so every
    # type node on the wire is a two-key object. The payload is whatever the
    # variant holds; `BasicType` and `LiteralType` are fieldless enums with
    # no struct wrapper, so their payloads collapse to a bare scalar. That is
    # why a basic type reads back as the string `"Int"` and not as
    # `{"type": "Int"}`.
    def self.type_from_wire(wire)
      tag = wire["type"]
      # `Type::Any` serializes as `{"type": "Any"}` — the `value` key is
      # simply absent, not null. So a payload with no `type` at all is not
      # `Any`, it is a mis-routed object, and it says so rather than decoding
      # to a type that matches anything.
      raise ArgumentError, "KclLib: type payload has no `type` discriminator" if tag.nil?

      value = wire["value"]
      case tag
      when "Any" then AnyType.new
      when "Basic" then BasicType.new(name: value.is_a?(String) ? value : "")
      when "Named" then NamedType.new(identifier: Identifier.from_wire(obj(value)))
      when "List"
        list = obj(value)
        ListType.new(inner_type: node_of(list["inner_type"]) { |w| type_from_wire(w) })
      when "Dict"
        dict = obj(value)
        DictType.new(
          key_type: node_of(dict["key_type"]) { |w| type_from_wire(w) },
          value_type: node_of(dict["value_type"]) { |w| type_from_wire(w) }
        )
      when "Union"
        union = obj(value)
        UnionType.new(
          # The Rust field is `type_elements`, not `types`.
          types: node_list(union["type_elements"]) { |w| type_from_wire(w) }
        )
      when "Literal"
        inner = as_map(value)
        LiteralType.new(value: value, inner_tag: inner && str(inner, "type"))
      when "Function"
        fn = obj(value)
        FunctionType.new(
          params_ty: node_list(fn["params_ty"]) { |w| type_from_wire(w) },
          ret_ty: node_of(fn["ret_ty"]) { |w| type_from_wire(w) }
        )
      else UnknownType.new(tag: tag, value: value)
      end
    end

    # -------------------------------------------------------------------------
    # Flat DTOs — plain structs the AST nests inside `NodeRef<T>`
    # -------------------------------------------------------------------------

    # `ast::Identifier` — a dotted name plus how it is being used. `ctx` is
    # `ast::ExprContext`, serialized as the bare string `"Load"` or `"Store"`.
    Identifier = Struct.new(:names, :pkgpath, :ctx, keyword_init: true) do
      def self.from_wire(wire)
        new(
          names: AST.string_node_list(wire["names"]),
          pkgpath: AST.str(wire, "pkgpath"),
          ctx: AST.str(wire, "ctx")
        )
      end

      # The dotted name, e.g. `data.cloud`.
      def name
        names.map(&:node).join(".")
      end
    end

    # `ast::MemberOrIndex` — `a.b` or `a[0]`. Declared
    # `#[serde(tag = "type", content = "value")]`, so it *is* tagged even
    # though the variants hold a `NodeRef`.
    MemberOrIndex = Struct.new(:kind, :value, keyword_init: true) do
      # `AST.` qualifies every helper here: inside a `Struct.new` block
      # `self` is this class, not the `AST` module, so a bare `str` would
      # raise NoMethodError the first time a path target appears.
      def self.from_wire(wire)
        new(
          kind: AST.str(wire, "type"),
          value: wire["value"]
        )
      end

      # The member name for `Member` as a `Node<String>`, or nil. The
      # payload is a `NodeRef<String>`, so it carries its own position.
      def member
        kind == "Member" ? AST.string_node(value) : nil
      end

      # The index expression for `Index` as a `Node<Expr>`, or nil. The
      # payload is a `NodeRef<Expr>`, so the wrapper has to be unwrapped
      # before the tagged `Expr` decoder sees it — handing it the whole
      # `NodeRef` instead yields `UnknownExpr` with a nil tag.
      def index
        return nil unless kind == "Index"

        AST.node_of(value) { |w| AST.expr_from_wire(w) }
      end
    end

    # `ast::Target` — `a.b.c` on the left of an assignment.
    Target = Struct.new(:name, :paths, :pkgpath, keyword_init: true) do
      def self.from_wire(wire)
        new(
          name: AST.string_node(wire["name"]),
          paths: AST.plain_list(wire["paths"]) { |w| MemberOrIndex.from_wire(w) },
          pkgpath: AST.str(wire, "pkgpath")
        )
      end
    end

    # `ast::Keyword` — `arg = value` in a call or a schema instantiation.
    # `arg` is a `NodeRef<Identifier>`, not an expression.
    Keyword = Struct.new(:arg, :value, keyword_init: true) do
      def self.from_wire(wire)
        new(
          arg: AST.node_of(wire["arg"]) { |w| Identifier.from_wire(w) },
          value: AST.node_of(wire["value"]) { |w| AST.expr_from_wire(w) }
        )
      end
    end

    # `ast::Arguments` — a parameter list. `defaults` and `ty_list` are
    # `Vec<Option<...>>`, so they are the same length as `args` with a null
    # for every parameter that has no default and no annotation. Both keep
    # their nulls for that reason.
    Arguments = Struct.new(:args, :defaults, :ty_list, keyword_init: true) do
      def self.from_wire(wire)
        new(
          args: AST.node_list(wire["args"]) { |w| Identifier.from_wire(w) },
          defaults: AST.nullable_node_list(wire["defaults"]) { |w| AST.expr_from_wire(w) },
          ty_list: AST.nullable_node_list(wire["ty_list"]) { |w| AST.type_from_wire(w) }
        )
      end

      def length
        args.length
      end
    end

    # `ast::ConfigEntry` — one `key = value` pair inside a config expression.
    ConfigEntry = Struct.new(:key, :value, :operation, :is_shorthand, keyword_init: true) do
      def self.from_wire(wire)
        new(
          key: AST.node_of(wire["key"]) { |w| AST.expr_from_wire(w) },
          value: AST.node_of(wire["value"]) { |w| AST.expr_from_wire(w) },
          operation: AST.str(wire, "operation"),
          is_shorthand: AST.flag(wire, "is_shorthand")
        )
      end
    end

    # `ast::CheckExpr` — `test if cond, "message"`. One class, not two: the
    # tagged `Expr::Check` variant *is* a `CheckExpr`, and serde flattens the
    # struct's fields into the same object, so a schema `check:` body and a
    # `Check` expression decode from the same three keys. The class lives with
    # the other `Expr` variants below; {.check_from_wire} is its decoder.
    #
    # `ast::Decorator` — `@deprecated` above a schema or a schema attribute.
    #
    # `SchemaStmt.decorators`, `RuleStmt.decorators` and `SchemaAttr.decorators`
    # are all `Vec<NodeRef<CallExpr>>`, and only the `Expr` enum is tagged, so
    # a decorator arrives as a bare `{func, args, keywords}` with no
    # discriminator. `CallExpr` is the tagged `Expr::Call`; this is the
    # untagged twin of it, which is the distinction Java draws. Decoded by
    # {.call_expr_from_wire}, named for the Rust struct the wire holds.
    Decorator = Struct.new(:func, :args, :keywords, keyword_init: true)

    # `ast::SchemaExpr` as it appears without a tag — the `value` of a
    # `UnificationStmt`, i.e. `p = Person {…}` rather than `Person {…}`.
    #
    # `UnificationStmt.value` is a `NodeRef<SchemaExpr>` and `SchemaExpr` is a
    # plain struct, so the payload has no `type` key and cannot be dispatched
    # on. Decoded by {.schema_expr_from_wire}, which also feeds the tagged
    # `Expr::Schema` variant.
    SchemaConfig = Struct.new(:name, :args, :kwargs, :config, keyword_init: true) do
      # The same four fields, lifted into the tagged `Expr::Schema` variant.
      # The payloads are identical — the only difference on the wire is the
      # `type` key — so this is a copy, not a second decode.
      def to_expr
        SchemaExpr.new(name: name, args: args, kwargs: kwargs, config: config)
      end
    end

    # `ast::SchemaIndexSignature` — `[str]: int`.
    SchemaIndexSignature =
      Struct.new(:key_name, :value, :any_other, :key_ty, :value_ty, keyword_init: true) do
        def self.from_wire(wire)
          new(
            key_name: AST.string_node(wire["key_name"]),
            value: AST.node_of(wire["value"]) { |w| AST.expr_from_wire(w) },
            any_other: AST.flag(wire, "any_other"),
            key_ty: AST.node_of(wire["key_ty"]) { |w| AST.type_from_wire(w) },
            value_ty: AST.node_of(wire["value_ty"]) { |w| AST.type_from_wire(w) }
          )
        end
      end

    # -------------------------------------------------------------------------
    # Expression hierarchy — `ast::Expr`
    # -------------------------------------------------------------------------

    # Declares one variant of a tagged hierarchy. `name` is the Ruby
    # constant, `tag` the discriminator the parser emits, and `members` the
    # fields in Rust declaration order — passing an unknown one is an
    # `ArgumentError` rather than a silently dropped attribute.
    def self.variant_class(base, name, tag, members)
      Class.new(base) do
        @tag = tag
        define_method(:initialize) do |**kwargs|
          unknown = kwargs.keys - members
          raise ArgumentError, "unknown #{name} field(s): #{unknown.join(", ")}" unless unknown.empty?

          @fields = members.to_h { |m| [m, kwargs[m]] }
        end
      end
    end

    # Shared behaviour for the tagged hierarchies: the `type` tag the parser
    # emitted, and field access that keeps the wire names honest.
    module Taggable
      # The `type` tag the parser emitted.
      def tag
        self.class.instance_variable_get(:@tag)
      end

      def [](key)
        @fields[key]
      end

      # Fields are read as methods (`stmt.op`, `expr.left`) and the wire names
      # are preserved verbatim, so `to_h` round-trips back to the parser JSON.
      def method_missing(name, *args)
        return @fields[name] if args.empty? && @fields.key?(name)

        super
      end

      def respond_to_missing?(name, include_private = false)
        @fields.key?(name) || super
      end

      def to_h
        @fields.dup
      end

      def to_s
        fields = @fields.map { |k, v| "#{k}=#{v.inspect}" }.join(" ")
        "#<#{self.class.name&.split("::")&.last} #{fields}>"
      end
      alias inspect to_s
    end

    # Base class for `ast::Type`. Not tagged by the caller, but the variants
    # still carry the discriminator so an unknown type is readable.
    class TypeBase
      include Taggable
    end

    AnyType = variant_class(TypeBase, :AnyType, "Any", [])
    BasicType = variant_class(TypeBase, :BasicType, "Basic", %i[name])
    NamedType = variant_class(TypeBase, :NamedType, "Named", %i[identifier])
    ListType = variant_class(TypeBase, :ListType, "List", %i[inner_type])
    DictType = variant_class(TypeBase, :DictType, "Dict", %i[key_type value_type])
    UnionType = variant_class(TypeBase, :UnionType, "Union", %i[types])
    LiteralType = variant_class(TypeBase, :LiteralType, "Literal", %i[value inner_tag])
    FunctionType = variant_class(TypeBase, :FunctionType, "Function", %i[params_ty ret_ty])
    UnknownType = variant_class(TypeBase, :UnknownType, "Unknown", %i[tag value])

    # Base class for `ast::Expr`.
    class ExprBase
      include Taggable
    end

    TargetExpr = variant_class(ExprBase, :TargetExpr, "Target", %i[target])
    IdentifierExpr = variant_class(ExprBase, :IdentifierExpr, "Identifier", %i[identifier])
    UnaryExpr = variant_class(ExprBase, :UnaryExpr, "Unary", %i[op operand])
    BinaryExpr = variant_class(ExprBase, :BinaryExpr, "Binary", %i[left op right])
    IfExpr = variant_class(ExprBase, :IfExpr, "If", %i[body cond orelse])
    SelectorExpr = variant_class(ExprBase, :SelectorExpr, "Selector", %i[value attr ctx has_question])
    CallExpr = variant_class(ExprBase, :CallExpr, "Call", %i[func args keywords])
    ParenExpr = variant_class(ExprBase, :ParenExpr, "Paren", %i[expr])
    QuantExpr = variant_class(ExprBase, :QuantExpr, "Quant", %i[target variables op test if_cond ctx])
    ListExpr = variant_class(ExprBase, :ListExpr, "List", %i[elts ctx])
    ListIfItemExpr = variant_class(ExprBase, :ListIfItemExpr, "ListIfItem", %i[if_cond exprs orelse])
    CompClause = variant_class(ExprBase, :CompClause, "CompClause", %i[targets iter ifs])
    ListComp = variant_class(ExprBase, :ListComp, "ListComp", %i[elt generators])
    StarredExpr = variant_class(ExprBase, :StarredExpr, "Starred", %i[value ctx])
    DictComp = variant_class(ExprBase, :DictComp, "DictComp", %i[entry generators])
    ConfigIfEntryExpr = variant_class(ExprBase, :ConfigIfEntryExpr, "ConfigIfEntry", %i[if_cond items orelse])
    # The tagged `Expr::Schema`; the untagged shape is `SchemaConfig` above.
    SchemaExpr = variant_class(ExprBase, :SchemaExpr, "Schema", %i[name args kwargs config])
    ConfigExpr = variant_class(ExprBase, :ConfigExpr, "Config", %i[items])
    # The tagged `Expr::Check`, which is a `CheckExpr` with its fields
    # flattened in — see {.check_from_wire} for the untagged half.
    CheckExpr = variant_class(ExprBase, :CheckExpr, "Check", %i[test if_cond msg])
    LambdaExpr = variant_class(ExprBase, :LambdaExpr, "Lambda", %i[args body return_ty])
    Subscript =
      variant_class(ExprBase, :Subscript, "Subscript", %i[value index lower upper step ctx has_question])
    KeywordExpr = variant_class(ExprBase, :KeywordExpr, "Keyword", %i[keyword])
    ArgumentsExpr = variant_class(ExprBase, :ArgumentsExpr, "Arguments", %i[arguments])
    Compare = variant_class(ExprBase, :Compare, "Compare", %i[left ops comparators])
    NumberLit = variant_class(ExprBase, :NumberLit, "NumberLit", %i[binary_suffix value_tag value])
    StringLit = variant_class(ExprBase, :StringLit, "StringLit", %i[is_long_string raw_value value])
    NameConstantLit = variant_class(ExprBase, :NameConstantLit, "NameConstantLit", %i[value])
    JoinedString = variant_class(ExprBase, :JoinedString, "JoinedString", %i[is_long_string values raw_value])
    FormattedValue = variant_class(ExprBase, :FormattedValue, "FormattedValue", %i[is_long_string value format_spec])
    MissingExpr = variant_class(ExprBase, :MissingExpr, "Missing", [])

    # A `type` tag this binding does not know about. The raw payload is kept
    # so a newer parser degrades to something readable instead of raising.
    UnknownExpr = variant_class(ExprBase, :UnknownExpr, "Unknown", %i[variant raw])

    # Decode an *untagged* `CompClause`, as used by `ListComp.generators` and
    # `DictComp.generators` (`Vec<NodeRef<CompClause>>`).
    def self.comp_clause_from_wire(wire)
      CompClause.new(
        # `targets` is a `Vec<NodeRef<Identifier>>` — untagged, like
        # `Arguments.args`.
        targets: node_list(wire["targets"]) { |w| Identifier.from_wire(w) },
        iter: node_of(wire["iter"]) { |w| expr_from_wire(w) },
        ifs: node_list(wire["ifs"]) { |w| expr_from_wire(w) }
      )
    end

    # Decode an *untagged* `CallExpr`, as used by `decorators`. The
    # `decorators` fields are `Vec<NodeRef<CallExpr>>` and only the `Expr`
    # enum is tagged, so a decorator arrives as a bare
    # `{func, args, keywords}` object.
    #
    # The method is named for the Rust struct the field holds, and returns a
    # `Decorator` — the name Java and this binding give the untagged shape, and
    # the same split Java draws between `CallExpr` and `Decorator`.
    def self.call_expr_from_wire(wire)
      Decorator.new(
        func: node_of(wire["func"]) { |w| expr_from_wire(w) },
        args: node_list(wire["args"]) { |w| expr_from_wire(w) },
        keywords: node_list(wire["keywords"]) { |w| Keyword.from_wire(w) }
      )
    end

    # Decode a *`CheckExpr`*, in either of its two shapes.
    #
    # `Expr::Check(CheckExpr)` is an internally tagged newtype variant, so serde
    # flattens the struct's fields into the same object and the tagged arm is
    # this call. `SchemaStmt.checks` and `RuleStmt.checks` are
    # `Vec<NodeRef<CheckExpr>>` over a plain struct, so the payload is a bare
    # `{test, if_cond, msg}` with no `type` key. Same three keys either way,
    # hence one decoder and one class.
    def self.check_from_wire(wire)
      CheckExpr.new(
        test: node_of(wire["test"]) { |w| expr_from_wire(w) },
        if_cond: node_of(wire["if_cond"]) { |w| expr_from_wire(w) },
        msg: node_of(wire["msg"]) { |w| expr_from_wire(w) }
      )
    end

    # Decode an *untagged* `SchemaExpr`, as used by `UnificationStmt.value`.
    #
    # Rust types that field as `NodeRef<SchemaExpr>`, and `SchemaExpr` is a
    # plain struct, so the payload arrives as a bare `{name, args, kwargs,
    # config}` with **no `type` key**. Routing it through `expr_from_wire`
    # cannot work — there is no tag to dispatch on — so the untagged decoder
    # has to be reachable on its own.
    #
    # Named for the Rust struct the field holds, and returns a `SchemaConfig`,
    # which is what Java calls that untagged shape.
    def self.schema_expr_from_wire(wire)
      SchemaConfig.new(
        # `SchemaExpr.name` is a `NodeRef<Identifier>`, not an expression.
        name: node_of(wire["name"]) { |w| Identifier.from_wire(w) },
        args: node_list(wire["args"]) { |w| expr_from_wire(w) },
        kwargs: node_list(wire["kwargs"]) { |w| Keyword.from_wire(w) },
        config: node_of(wire["config"]) { |w| expr_from_wire(w) }
      )
    end

    # Decode the payload of a `NodeRef<Expr>`.
    def self.expr_from_wire(wire)
      case wire["type"]
      when "Target"
        # `Expr::Target(Target)` and friends are internally tagged newtype
        # variants, so serde flattens the struct's fields into the same
        # object - there is no `target` / `identifier` / `check` wrapper key.
        TargetExpr.new(target: Target.from_wire(wire))
      when "Identifier"
        IdentifierExpr.new(identifier: Identifier.from_wire(wire))
      when "Unary"
        UnaryExpr.new(
          op: str(wire, "op"),
          operand: node_of(wire["operand"]) { |w| expr_from_wire(w) }
        )
      when "Binary"
        BinaryExpr.new(
          left: node_of(wire["left"]) { |w| expr_from_wire(w) },
          op: str(wire, "op"),
          right: node_of(wire["right"]) { |w| expr_from_wire(w) }
        )
      when "If"
        IfExpr.new(
          body: node_of(wire["body"]) { |w| expr_from_wire(w) },
          cond: node_of(wire["cond"]) { |w| expr_from_wire(w) },
          orelse: node_of(wire["orelse"]) { |w| expr_from_wire(w) }
        )
      when "Selector"
        SelectorExpr.new(
          value: node_of(wire["value"]) { |w| expr_from_wire(w) },
          # `attr` is a `NodeRef<Identifier>`, so the payload is
          # `{names, pkgpath, ctx}` — decoding it as a bare string yields
          # "" rather than raising, because `string_node` only accepts a
          # String and quietly substitutes one.
          attr: node_of(wire["attr"]) { |w| Identifier.from_wire(w) },
          ctx: str(wire, "ctx"),
          has_question: flag(wire, "has_question")
        )
      when "Call"
        CallExpr.new(
          func: node_of(wire["func"]) { |w| expr_from_wire(w) },
          args: node_list(wire["args"]) { |w| expr_from_wire(w) },
          keywords: node_list(wire["keywords"]) { |w| Keyword.from_wire(w) }
        )
      when "Paren"
        ParenExpr.new(expr: node_of(wire["expr"]) { |w| expr_from_wire(w) })
      when "Quant"
        QuantExpr.new(
          target: node_of(wire["target"]) { |w| expr_from_wire(w) },
          variables: node_list(wire["variables"]) { |w| Identifier.from_wire(w) },
          op: str(wire, "op"),
          test: node_of(wire["test"]) { |w| expr_from_wire(w) },
          if_cond: node_of(wire["if_cond"]) { |w| expr_from_wire(w) },
          ctx: str(wire, "ctx")
        )
      when "List"
        ListExpr.new(
          elts: node_list(wire["elts"]) { |w| expr_from_wire(w) },
          ctx: str(wire, "ctx")
        )
      when "ListIfItem"
        ListIfItemExpr.new(
          if_cond: node_of(wire["if_cond"]) { |w| expr_from_wire(w) },
          exprs: node_list(wire["exprs"]) { |w| expr_from_wire(w) },
          orelse: node_of(wire["orelse"]) { |w| expr_from_wire(w) }
        )
      when "ListComp"
        ListComp.new(
          elt: node_of(wire["elt"]) { |w| expr_from_wire(w) },
          generators: node_list(wire["generators"]) { |w| comp_clause_from_wire(w) }
        )
      when "Starred"
        StarredExpr.new(
          value: node_of(wire["value"]) { |w| expr_from_wire(w) },
          ctx: str(wire, "ctx")
        )
      when "DictComp"
        DictComp.new(
          # The Rust field is a single `entry: ConfigEntry`, not an
          # `entry_key` / `key` / `value` triple.
          entry: as_map(wire["entry"]) && ConfigEntry.from_wire(as_map(wire["entry"])),
          generators: node_list(wire["generators"]) { |w| comp_clause_from_wire(w) }
        )
      when "ConfigIfEntry"
        ConfigIfEntryExpr.new(
          if_cond: node_of(wire["if_cond"]) { |w| expr_from_wire(w) },
          items: node_list(wire["items"]) { |w| ConfigEntry.from_wire(w) },
          orelse: node_of(wire["orelse"]) { |w| expr_from_wire(w) }
        )
      when "Schema"
        # Same four fields either way; only the `type` key differs, so the
        # untagged read is lifted into the tagged variant.
        schema_expr_from_wire(wire).to_expr
      when "Config"
        ConfigExpr.new(items: node_list(wire["items"]) { |w| ConfigEntry.from_wire(w) })
      when "Check"
        check_from_wire(wire)
      when "Lambda"
        LambdaExpr.new(
          args: node_of(wire["args"]) { |w| Arguments.from_wire(w) },
          # A lambda body holds statements, not expressions.
          body: node_list(wire["body"]) { |w| stmt_from_wire(w) },
          return_ty: node_of(wire["return_ty"]) { |w| type_from_wire(w) }
        )
      when "Subscript"
        Subscript.new(
          value: node_of(wire["value"]) { |w| expr_from_wire(w) },
          index: node_of(wire["index"]) { |w| expr_from_wire(w) },
          lower: node_of(wire["lower"]) { |w| expr_from_wire(w) },
          upper: node_of(wire["upper"]) { |w| expr_from_wire(w) },
          step: node_of(wire["step"]) { |w| expr_from_wire(w) },
          ctx: str(wire, "ctx"),
          has_question: flag(wire, "has_question")
        )
      when "Keyword"
        KeywordExpr.new(keyword: Keyword.from_wire(wire))
      when "Arguments"
        ArgumentsExpr.new(arguments: Arguments.from_wire(wire))
      when "Compare"
        Compare.new(
          left: node_of(wire["left"]) { |w| expr_from_wire(w) },
          ops: string_list(wire, "ops"),
          comparators: node_list(wire["comparators"]) { |w| expr_from_wire(w) }
        )
      when "NumberLit"
        # `NumberLit.value` is a `NumberLitValue`, itself tagged
        # `#[serde(tag = "type", content = "value")]` — so `0` arrives as
        # `{"type": "Int", "value": 0}`, not as a bare `0`.
        inner = as_map(wire["value"])
        NumberLit.new(
          binary_suffix: wire["binary_suffix"].is_a?(String) ? wire["binary_suffix"] : nil,
          value_tag: inner && str(inner, "type"),
          value: inner && inner["value"]
        )
      when "StringLit"
        StringLit.new(
          is_long_string: flag(wire, "is_long_string"),
          raw_value: str(wire, "raw_value"),
          value: str(wire, "value")
        )
      when "NameConstantLit"
        # The value is the *name* — `"True"`, `"False"`, `"Undefined"` — and
        # not a boolean, so it must not be read through `flag`.
        NameConstantLit.new(value: str(wire, "value"))
      when "JoinedString"
        JoinedString.new(
          is_long_string: flag(wire, "is_long_string"),
          values: node_list(wire["values"]) { |w| expr_from_wire(w) },
          raw_value: str(wire, "raw_value")
        )
      when "FormattedValue"
        FormattedValue.new(
          is_long_string: flag(wire, "is_long_string"),
          value: node_of(wire["value"]) { |w| expr_from_wire(w) },
          format_spec: wire["format_spec"].is_a?(String) ? wire["format_spec"] : nil
        )
      when "CompClause"
        comp_clause_from_wire(wire)
      when "Missing"
        MissingExpr.new
      else
        # No discriminator at all is not a variant this binding has not heard
        # of — it is a payload handed to the wrong decoder, which is the one
        # bug class nothing else in this file catches. An untagged
        # `{name, args, kwargs, config}` routed through `expr_from_wire`, or a
        # `NodeRef` handed to a payload decoder without unwrapping it, both
        # land here, and both used to yield a plausible-looking node whose tag
        # was nil. Raise instead. An unrecognised *tag* still degrades, so a
        # newer parser does not take the whole file down.
        raise ArgumentError, "KclLib: expression payload has no `type` discriminator" if wire["type"].nil?

        UnknownExpr.new(variant: wire["type"], raw: wire)
      end
    end

    # -------------------------------------------------------------------------
    # Statement hierarchy — `ast::Stmt`
    # -------------------------------------------------------------------------

    # Base class for `ast::Stmt`.
    class StmtBase
      include Taggable
    end

    TypeAliasStmt = variant_class(StmtBase, :TypeAliasStmt, "TypeAlias", %i[type_name type_value ty])
    ExprStmt = variant_class(StmtBase, :ExprStmt, "Expr", %i[exprs])
    UnificationStmt = variant_class(StmtBase, :UnificationStmt, "Unification", %i[target value])
    AssignStmt = variant_class(StmtBase, :AssignStmt, "Assign", %i[targets value ty])
    AugAssignStmt = variant_class(StmtBase, :AugAssignStmt, "AugAssign", %i[target value op])
    AssertStmt = variant_class(StmtBase, :AssertStmt, "Assert", %i[test if_cond msg])
    IfStmt = variant_class(StmtBase, :IfStmt, "If", %i[body cond orelse])
    ImportStmt = variant_class(StmtBase, :ImportStmt, "Import", %i[path rawpath name as_name pkg_name])
    SchemaAttr =
      variant_class(StmtBase, :SchemaAttr, "SchemaAttr", %i[doc name op value is_optional decorators ty])
    SchemaStmt = variant_class(StmtBase, 
      :SchemaStmt, "Schema",
      %i[doc name parent_name for_host_name is_mixin is_protocol args mixins body decorators
         checks index_signature]
    )
    RuleStmt =
      variant_class(StmtBase, :RuleStmt, "Rule", %i[doc name parent_rules decorators checks args for_host_name])
    UnknownStmt = variant_class(StmtBase, :UnknownStmt, "Unknown", %i[variant raw])

    # Decode the payload of a `NodeRef<Stmt>`.
    def self.stmt_from_wire(wire)
      case wire["type"]
      when "TypeAlias"
        TypeAliasStmt.new(
          type_name: node_of(wire["type_name"]) { |w| Identifier.from_wire(w) },
          type_value: string_node(wire["type_value"]),
          ty: node_of(wire["ty"]) { |w| type_from_wire(w) }
        )
      when "Expr"
        ExprStmt.new(exprs: node_list(wire["exprs"]) { |w| expr_from_wire(w) })
      when "Unification"
        # `value` is a `NodeRef<SchemaExpr>` and `SchemaExpr` is a plain struct,
        # so the payload has no `type` key — it must go through the untagged
        # decoder, not `expr_from_wire`.
        UnificationStmt.new(
          target: node_of(wire["target"]) { |w| Identifier.from_wire(w) },
          value: node_of(wire["value"]) { |w| schema_expr_from_wire(w) }
        )
      when "Assign"
        AssignStmt.new(
          targets: node_list(wire["targets"]) { |w| Target.from_wire(w) },
          value: node_of(wire["value"]) { |w| expr_from_wire(w) },
          ty: node_of(wire["ty"]) { |w| type_from_wire(w) }
        )
      when "AugAssign"
        AugAssignStmt.new(
          target: node_of(wire["target"]) { |w| Target.from_wire(w) },
          value: node_of(wire["value"]) { |w| expr_from_wire(w) },
          op: str(wire, "op")
        )
      when "Assert"
        AssertStmt.new(
          test: node_of(wire["test"]) { |w| expr_from_wire(w) },
          if_cond: node_of(wire["if_cond"]) { |w| expr_from_wire(w) },
          msg: node_of(wire["msg"]) { |w| expr_from_wire(w) }
        )
      when "If"
        IfStmt.new(
          body: node_list(wire["body"]) { |w| stmt_from_wire(w) },
          cond: node_of(wire["cond"]) { |w| expr_from_wire(w) },
          orelse: node_list(wire["orelse"]) { |w| stmt_from_wire(w) }
        )
      when "Import"
        # `ImportStmt` is a flat struct: `path` and `asname` are
        # `Node<String>` with their own positions, while `rawpath`, `name`
        # and `pkg_name` are plain strings on the same node. There is no
        # nested `node` object to read them from.
        ImportStmt.new(
          path: string_node(wire["path"]),
          rawpath: str(wire, "rawpath"),
          name: str(wire, "name"),
          as_name: string_node(wire["asname"]),
          pkg_name: str(wire, "pkg_name")
        )
      when "SchemaAttr"
        SchemaAttr.new(
          doc: str(wire, "doc"),
          name: string_node(wire["name"]),
          op: wire["op"].is_a?(String) ? wire["op"] : nil,
          value: node_of(wire["value"]) { |w| expr_from_wire(w) },
          is_optional: flag(wire, "is_optional"),
          decorators: node_list(wire["decorators"]) { |w| call_expr_from_wire(w) },
          # `SchemaAttr.ty` is a non-optional `NodeRef<Type>` in Rust.
          ty: node_of(wire["ty"]) { |w| type_from_wire(w) }
        )
      when "Schema"
        SchemaStmt.new(
          doc: string_node(wire["doc"]),
          name: string_node(wire["name"]),
          parent_name: node_of(wire["parent_name"]) { |w| Identifier.from_wire(w) },
          for_host_name: node_of(wire["for_host_name"]) { |w| Identifier.from_wire(w) },
          is_mixin: flag(wire, "is_mixin"),
          is_protocol: flag(wire, "is_protocol"),
          args: node_of(wire["args"]) { |w| Arguments.from_wire(w) },
          mixins: node_list(wire["mixins"]) { |w| Identifier.from_wire(w) },
          body: node_list(wire["body"]) { |w| stmt_from_wire(w) },
          decorators: node_list(wire["decorators"]) { |w| call_expr_from_wire(w) },
          checks: node_list(wire["checks"]) { |w| check_from_wire(w) },
          index_signature: node_of(wire["index_signature"]) { |w| SchemaIndexSignature.from_wire(w) }
        )
      when "Rule"
        RuleStmt.new(
          doc: string_node(wire["doc"]),
          name: string_node(wire["name"]),
          parent_rules: node_list(wire["parent_rules"]) { |w| Identifier.from_wire(w) },
          decorators: node_list(wire["decorators"]) { |w| call_expr_from_wire(w) },
          checks: node_list(wire["checks"]) { |w| check_from_wire(w) },
          args: node_of(wire["args"]) { |w| Arguments.from_wire(w) },
          for_host_name: node_of(wire["for_host_name"]) { |w| Identifier.from_wire(w) }
        )
      else
        # As in {.expr_from_wire}: an absent discriminator is a mis-routed
        # payload and raises, an unrecognised one degrades.
        raise ArgumentError, "KclLib: statement payload has no `type` discriminator" if wire["type"].nil?

        UnknownStmt.new(variant: wire["type"], raw: wire)
      end
    end

    # -------------------------------------------------------------------------
    # Module — `ast::Module` and the public entry points
    # -------------------------------------------------------------------------

    # `ast::Module` — the top-level AST node of a single KCL file.
    #
    # The Rust struct has no `pkg` field: the Java and Go bindings used to
    # expose one and were aligned to drop it, so this struct has none either.
    #
    # Named `Module` to match the Java binding. Inside `KclLib::AST` it shadows
    # Ruby's `::Module` for unqualified references in this namespace, which is
    # why nothing in this file writes a bare `Module`.
    Module = Struct.new(:filename, :doc, :body, :comments, keyword_init: true) do
      def self.from_wire(wire)
        new(
          filename: AST.str(wire, "filename"),
          doc: AST.string_node(wire["doc"]),
          body: AST.node_list(wire["body"]) { |w| AST.stmt_from_wire(w) },
          # `comments` is `Vec<NodeRef<Comment>>` and `Comment` is a plain
          # struct with one `String` field, so the payload under `node` is
          # `{"text": "…"}` and not the text itself. Reading the object as
          # though it were a string yields "" for every comment in the file
          # and nothing else goes wrong — this is the decode four bindings got
          # wrong.
          comments: AST.node_list(wire["comments"]) { |w| Comment.new(text: AST.str(w, "text")) }
        )
      end
    end

    # The name this binding used before the vocabulary was aligned with
    # Java's. Kept so existing callers keep working.
    KclModule = Module

  # Decode the `ast_json` string returned by `API#parse_file`.
  #
  #   m = AST.parse_module(api.parse_file(KclLib::ParseFileArgs.new(
  #     path: "main.k", source: "schema Person:\n    name: str\n")).ast_json)
  def self.parse_module(ast_json)
    wire = as_map(JSON.parse(ast_json))
    raise ArgumentError, "KclLib: expected a KCL Module object" if wire.nil?

    Module.from_wire(wire)
  end

  # Decode the `ast_json` string returned by `API#parse_program`.
  #
  # The service serializes a program either as a bare array of modules or
  # as a `{"root": ..., "pkgs": {"__main__": [...]}}` envelope; both are
  # accepted.
  def self.parse_program_ast(program_json)
    decoded = JSON.parse(program_json)
    return decoded.filter_map { |m| Module.from_wire(obj(m)) } if decoded.is_a?(Array)

    envelope = as_map(decoded)
    return [] if envelope.nil?

    main = obj(envelope["pkgs"])["__main__"]
    main.is_a?(Array) ? main.filter_map { |m| Module.from_wire(obj(m)) } : []
  end
  end
end
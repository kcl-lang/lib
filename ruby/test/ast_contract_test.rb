# frozen_string_literal: true

require "minitest/autorun"
require "json"

require "kcl_lib"

# Contract test for the typed AST.
#
# `ast_test.rb` parses a live fixture through the service, which proves the
# decoder accepts *something* the parser emits. This test pins the opposite
# direction: it decodes a captured golden parse
# (`testdata/ast/alignment.json`, the same one the C, C++, Dart, Java,
# Kotlin, Node.js, Python, .NET, WASM, Lua, Swift, Zig and Julia bindings
# use) and asserts the typed tree matches it field by field.
#
# The load-bearing case is `test_every_tag_in_the_golden_capture_resolves`.
# A decoder that mistypes one `type` tag does not raise — it falls through to
# the `Unknown*` variant and produces a zero-valued node. Field-by-field
# assertions on a handful of nodes would sail straight past that, so the walk
# visits every node in the capture and reports anything that did not resolve.
#
# A payload with *no* tag is a different failure and is not left to the walk:
# the decoder raises on a missing discriminator, so an untagged payload routed
# through a tagged decoder is a loud error rather than a node that looks fine.
# `test_unification_...` still asserts the value's class and not just its
# presence, because a `SchemaConfig` that arrived with a `type` key would
# decode just as quietly.
class AstContractTest < Minitest::Test
  AST = KclLib::AST

  # The golden capture lives at the repository root; `ruby/test` is two
  # levels down, but the other candidates let the file be run from anywhere
  # in the tree.
  FIXTURE_CANDIDATES = [
    File.expand_path("../../testdata/ast/alignment.json", __dir__),
    File.expand_path("../testdata/ast/alignment.json", __dir__),
    File.expand_path("testdata/ast/alignment.json", __dir__),
    File.expand_path("../../ruby/../testdata/ast/alignment.json", __dir__)
  ].freeze

  # `CmpOp` from `../kcl/crates/ast/src/ast.rs`. Listed so a typo in either
  # the parser or the fixture shows up as a failure rather than passing
  # through as an opaque string.
  CMP_OPS = %w[Eq NotEq Lt LtE Gt GtE Is In NotIn Not IsNot].freeze

  def self.fixture_path
    found = FIXTURE_CANDIDATES.find { |p| File.file?(p) }
    raise "could not locate testdata/ast/alignment.json (tried #{FIXTURE_CANDIDATES})" if found.nil?

    found
  end

  def self.golden
    @golden ||= AST.parse_module(File.read(fixture_path))
  end

  def setup
    @m = self.class.golden
  end

  # ------------------------------------------------------------------ #
  # Lookups
  # ------------------------------------------------------------------ #

  # The first top-level statement of the given class, or nil.
  def find_stmt(klass)
    @m.body.map(&:node).find { |n| n.is_a?(klass) }
  end

  def find_schema(name)
    @m.body.map(&:node).select { |n| n.is_a?(AST::SchemaStmt) }
          .find { |s| s.name&.node == name }
  end

  def find_assign(name)
    @m.body.map(&:node).select { |n| n.is_a?(AST::AssignStmt) }
          .find { |s| s.targets.first&.node&.name&.node == name }
  end

  def find_type_alias(name)
    @m.body.map(&:node).select { |n| n.is_a?(AST::TypeAliasStmt) }
          .find { |s| s.type_name&.node&.name == name }
  end

  def assigned_value(name)
    find_assign(name)&.value
  end

  def alias_type(name)
    find_type_alias(name)&.ty
  end

  # The first `body` entry of a schema whose name matches, as a node.
  def schema_attr(schema_name, attr_name)
    schema = find_schema(schema_name)
    refute_nil schema, "fixture has no schema named #{schema_name}"
    found = schema.body.map(&:node).select { |n| n.is_a?(AST::SchemaAttr) }
                        .find { |a| a.name&.node == attr_name }
    refute_nil found, "#{schema_name} has no attribute named #{attr_name}"
    found
  end

  # ------------------------------------------------------------------ #
  # Tests
  # ------------------------------------------------------------------ #

  def test_module_shape
    assert @m.filename.end_with?(".k"), "filename #{@m.filename.inspect} is not a .k file"
    refute_empty @m.body
    # `comments` is `Vec<NodeRef<Comment>>`, so the payload is `{text}`
    # rather than a bare string.
    refute_empty @m.comments, "module has no comments"
    assert_match(/\A#/, @m.comments.first.node.text)
    # Positions are flat on the wrapper, so a `pos` with a line number
    # proves the loader reads `line` and is not looking for a nested `pos`
    # object.
    refute_nil @m.body.first.pos, "statement 0 has no position"
    assert_operator @m.body.first.pos.line, :>, 0
    refute_empty @m.body.first.pos.filename
  end

  def test_import_is_flat
    imp = @m.body.first
    assert_instance_of AST::ImportStmt, imp.node
    # `path` is a `Node<String>`, so it carries a position of its own.
    refute_nil imp.node.path
    refute_nil imp.node.path.pos
    refute_empty imp.node.rawpath
    refute_empty imp.node.name
    refute_empty imp.node.pkg_name
  end

  def test_unification_target_is_a_store_identifier
    un = find_stmt(AST::UnificationStmt)
    refute_nil un, "no Unification statement in the fixture"
    # `target` is an `Identifier`, not a `Target` — so it has a `ctx`.
    assert_instance_of AST::Identifier, un.target.node
    assert_equal "Store", un.target.node.ctx
    # `value` is a `SchemaExpr` on the wire, and because it is a plain struct
    # it carries **no** `type` key. That untagged shape is a `SchemaConfig`
    # here, the way Java names it; routing it through the tagged `Expr`
    # decoder has nothing to dispatch on and now raises rather than yielding a
    # well-known variant by accident. Assert the class.
    assert_instance_of AST::SchemaConfig, un.value.node,
                     "unification value decoded as #{un.value.node.class}"
    assert_equal %i[name args kwargs config], un.value.node.members
    assert_equal "Person", un.value.node.name.node.name
  end

  def test_aug_assign_assert_and_if
    aug = find_stmt(AST::AugAssignStmt)
    refute_nil aug, "no AugAssign statement in the fixture"
    assert_equal "Add", aug.op
    assert_equal "a", aug.target.node.name.node

    # `AssertStmt` is `{test, if_cond, msg}` — all NodeRefs.
    as = find_stmt(AST::AssertStmt)
    refute_nil as, "no Assert statement in the fixture"
    refute_nil as.test

    # `orelse` is `Vec<NodeRef<Stmt>>`, not an expression.
    if_stmt = find_stmt(AST::IfStmt)
    refute_nil if_stmt, "no If statement in the fixture"
    refute_nil if_stmt.cond
  end

  def test_rule_stmt
    rule = find_stmt(AST::RuleStmt)
    refute_nil rule, "no Rule statement in the fixture"
    refute_nil rule.name
    # `decorators` and `checks` are `Vec<NodeRef<...>>` over plain structs, so
    # neither element carries a tag. The fixture's rule is undecorated, which
    # is itself the assertion: a decoder that invented a tag could not produce
    # an empty list here.
    assert_empty rule.decorators, "Rule should have no decorators"
    refute_empty rule.checks
    assert_instance_of AST::CheckExpr, rule.checks.first.node
    refute_nil rule.checks.first.node.test
  end

  def test_schema_decorators_are_untagged_decorators
    person = find_schema("Person")
    refute_nil person, "no Person schema in the fixture"
    # `@deprecated` and `@info` sit on the `name` attribute, not on the schema
    # header, so the schema's own list is empty.
    assert_empty person.decorators, "Person should have no schema decorators"
    refute_empty person.checks
    assert_instance_of AST::CheckExpr, person.checks.first.node
    refute_nil person.checks.first.node.test
    refute_nil person.checks.first.node.msg

    # The docstring is on the *schema*, and it keeps its `"""` delimiters:
    # `parse_doc` clones `StringLit::raw_value`, not the unquoted `value`.
    # A binding that strips the quotes here is reading the wrong field.
    refute_nil person.doc, "Person has no docstring"
    assert_equal '"""A person."""', person.doc.node

    name = schema_attr("Person", "name")
    assert_instance_of AST::SchemaAttr, name
    # `SchemaAttr.doc` is a plain `String`, not a `NodeRef<String>`, so an
    # attribute with no docstring decodes to "" rather than to nil.
    assert_equal "", name.doc
    assert_equal 2, name.decorators.length
    # `ty` is `NodeRef<Type>`, not an Option.
    refute_nil name.ty
    assert_instance_of AST::BasicType, name.ty.node
    assert_equal "Str", name.ty.node.name

    deco = name.decorators.first.node
    assert_instance_of AST::Decorator, deco
    # A decorator payload is a bare `{func,args,keywords}`; the `func` is a
    # `NodeRef<Expr>` that *does* carry a tag.
    assert_empty deco.args, "@deprecated should have no positional args"
    assert_instance_of AST::IdentifierExpr, deco.func.node
    assert_equal "deprecated", deco.func.node.identifier.name
  end

  def test_schema_expr_is_not_a_call
    # `x = Person {...}` puts its entries in `config` and leaves `keywords`
    # empty; `y = Person(1, name = "Bob")` is a plain Call.
    x = assigned_value("x")&.node
    refute_nil x, "no `x` assignment"
    assert_instance_of AST::SchemaExpr, x
    assert_empty x.kwargs, "`x` SchemaExpr has keywords"
    assert_instance_of AST::ConfigExpr, x.config.node

    y = assigned_value("y")&.node
    refute_nil y, "no `y` assignment"
    assert_instance_of AST::CallExpr, y
    assert_equal 1, y.args.length
    # `Keyword.arg` is a `NodeRef<Identifier>`, not an Expr.
    assert_equal 1, y.keywords.length
    assert_instance_of AST::Identifier, y.keywords.first.node.arg.node
    assert_equal "name", y.keywords.first.node.arg.node.name
    refute_nil y.keywords.first.node.value
  end

  def test_unary_and_compare_parallel_arrays
    # `-a` is `USub`, not a generic "negate".
    unary = assigned_value("unary")&.node
    refute_nil unary, "no `unary` assignment"
    assert_instance_of AST::UnaryExpr, unary
    assert_equal "USub", unary.op
    assert_instance_of AST::IdentifierExpr, unary.operand.node

    not_op = assigned_value("unary_not")&.node
    refute_nil not_op, "no `unary_not` assignment"
    assert_equal "Not", not_op.op

    # `ops` and `comparators` are parallel arrays.
    chain = assigned_value("compare_chain")&.node
    refute_nil chain, "no `compare_chain` assignment"
    assert_instance_of AST::Compare, chain
    assert_equal chain.ops.length, chain.comparators.length
    # `CmpOp` is {Eq,NotEq,Lt,LtE,Gt,GtE,Is,In,NotIn,Not,IsNot}.
    assert chain.ops.all? { |o| CMP_OPS.include?(o) },
           "unrecognised comparison operator in #{chain.ops.inspect}"
    refute_nil chain.left
  end

  def test_selector_and_subscript
    # `Selector.attr` is a `NodeRef<Identifier>`, so the payload is
    # `{names, pkgpath, ctx}` rather than a bare string, and
    # `has_question` is the optional-access flag — there is no `attr_name`
    # field. Asserting only that `attr` is non-nil is not enough: decoding an
    # Identifier payload as a `NodeRef<String>` yields `""` without raising.
    optional = assigned_value("optional")&.node
    refute_nil optional, "no `optional` assignment"
    assert_instance_of AST::SelectorExpr, optional
    assert optional.has_question, "`optional` has_question is false"
    assert_instance_of AST::Identifier, optional.attr.node
    assert_equal "name", optional.attr.node.name
    refute_nil optional.attr.pos

    # A slice puts its bounds in `lower`/`upper`/`step` and leaves `index`
    # null.
    slice = assigned_value("subscript_slice")&.node
    refute_nil slice, "no `subscript_slice` assignment"
    assert_instance_of AST::Subscript, slice
    assert_nil slice.index, "slice has a non-null index"
    refute_nil slice.lower
    refute_nil slice.upper

    step = assigned_value("subscript_step")&.node
    refute_nil step, "no `subscript_step` assignment"
    assert_instance_of AST::Subscript, step
    refute_nil step.step
    refute_nil step.lower
    refute_nil step.upper

    # `subscript_q` is `a?.b` — an optional *Selector*, not a Subscript. The
    # two are easy to confuse and `has_question` lives on both.
    q = assigned_value("subscript_q")&.node
    refute_nil q, "no `subscript_q` assignment"
    assert_instance_of AST::SelectorExpr, q
    assert q.has_question, "subscript_q has_question is false"

    plain = assigned_value("subscript")&.node
    refute_nil plain, "no `subscript` assignment"
    assert_instance_of AST::Subscript, plain
    refute_nil plain.index
  end

  def test_config_entries
    # `config = {a = 1, b: 2}` uses Override then Union.
    config = assigned_value("config")&.node
    refute_nil config, "no `config` assignment"
    assert_instance_of AST::ConfigExpr, config
    assert_equal 2, config.items.length
    assert_equal "Override", config.items[0].node.operation
    assert_equal "Union", config.items[1].node.operation
    # `skip_serializing_if = "is_false"`, so the key is absent rather than
    # explicitly false.
    refute config.items[0].node.is_shorthand

    # The ES6 shorthand sets the flag.
    shorthand = assigned_value("config_shorthand")&.node
    refute_nil shorthand, "no `config_shorthand` assignment"
    assert_instance_of AST::ConfigExpr, shorthand
    refute_empty shorthand.items
    shorthand.items.each do |ref|
      assert ref.node.is_shorthand, "config_shorthand entry is_shorthand is false"
    end

    # `config_if` wraps the `ConfigIfEntryExpr` in a `ConfigEntry` whose `key`
    # is null.
    config_if = assigned_value("config_if")&.node
    refute_nil config_if, "no `config_if` assignment"
    assert_instance_of AST::ConfigExpr, config_if
    assert_equal 1, config_if.items.length
    entry = config_if.items[0].node
    assert_instance_of AST::ConfigEntry, entry
    assert_nil entry.key, "config_if entry should have a null key"
    assert_instance_of AST::ConfigIfEntryExpr, entry.value.node
    refute_empty entry.value.node.items
  end

  def test_comprehensions
    quant = assigned_value("quant")&.node
    refute_nil quant, "no `quant` assignment"
    assert_instance_of AST::QuantExpr, quant
    # `QuantOperation` is {All,Any,Filter,Map} — a single value, not a list.
    assert_includes %w[All Any Filter Map], quant.op
    # `variables` is `Vec<NodeRef<Identifier>>`, not Targets.
    refute_empty quant.variables
    assert_instance_of AST::Identifier, quant.variables.first.node
    refute_empty quant.variables.first.node.name
    refute_nil quant.test

    # `DictComp.entry` is a bare ConfigEntry — there is no `key`/`value` pair
    # and no `cond`.
    dict_comp = assigned_value("dict_comp")&.node
    refute_nil dict_comp, "no `dict_comp` assignment"
    assert_instance_of AST::DictComp, dict_comp
    refute_nil dict_comp.entry.key
    refute_nil dict_comp.entry.value
    refute_empty dict_comp.generators
    # `CompClause.targets` are Identifiers.
    refute_empty dict_comp.generators.first.node.targets
    assert_instance_of AST::Identifier, dict_comp.generators.first.node.targets.first.node

    # `ListIfItemExpr` is `{if_cond, exprs, orelse}` — there is no `if_expr`.
    list = assigned_value("list_if_entry")&.node
    refute_nil list, "no `list_if_entry` assignment"
    assert_instance_of AST::ListExpr, list
    item = list.elts.first.node
    assert_instance_of AST::ListIfItemExpr, item
    refute_nil item.if_cond
    refute_empty item.exprs

    # The `*_if` forms are ListComp — there is no `cond` field.
    comp = assigned_value("list_if")&.node
    refute_nil comp, "no `list_if` assignment"
    assert_instance_of AST::ListComp, comp
    refute_empty comp.generators
  end

  def test_lambda_arguments_are_index_aligned
    # `lambda_expr`'s Arguments has `args: [p]`, `defaults: [null]` and
    # `ty_list: [Int]`. Dropping the positional null would leave an empty
    # list, which is the bug this checks for.
    lambda = assigned_value("lambda_expr")&.node
    refute_nil lambda, "no `lambda_expr` assignment"
    assert_instance_of AST::LambdaExpr, lambda
    refute_nil lambda.args
    args = lambda.args.node
    assert_instance_of AST::Arguments, args
    assert_equal 1, args.args.length
    assert_equal 1, args.defaults.length
    assert_nil args.defaults[0], "lambda's single default should be null"
    assert_equal 1, args.ty_list.length
    assert_instance_of AST::BasicType, args.ty_list[0].node
    assert_equal "Int", args.ty_list[0].node.name
    # The body is statements, not expressions.
    refute_empty lambda.body
    assert_instance_of AST::ExprStmt, lambda.body.first.node

    # `lambda_plain` has `args: null` — an absent Option.
    plain = assigned_value("lambda_plain")&.node
    refute_nil plain, "no `lambda_plain` assignment"
    assert_instance_of AST::LambdaExpr, plain
    assert_nil plain.args, "lambda_plain should have a null args"
  end

  def test_number_literals
    # `NumberLitValue` is tag+content, so the tag is the only thing telling an
    # int payload from a float one.
    int_lit = assigned_value("lit_int")&.node
    refute_nil int_lit, "no `lit_int` assignment"
    assert_instance_of AST::NumberLit, int_lit
    assert_equal "Int", int_lit.value_tag
    assert_nil int_lit.binary_suffix

    float_lit = assigned_value("lit_float")&.node
    refute_nil float_lit, "no `lit_float` assignment"
    assert_instance_of AST::NumberLit, float_lit
    assert_equal "Float", float_lit.value_tag
    refute_equal 0, float_lit.value

    refute_nil assigned_value("lit_name")&.node, "no `lit_name` assignment"
  end

  def test_string_and_joined
    str_lit = assigned_value("lit_str")&.node
    refute_nil str_lit, "no `lit_str` assignment"
    assert_instance_of AST::StringLit, str_lit
    refute_nil str_lit.value
    refute_nil str_lit.raw_value

    long_str = assigned_value("lit_long")&.node
    refute_nil long_str, "no `lit_long` assignment"
    assert_instance_of AST::StringLit, long_str
    assert long_str.is_long_string, "lit_long is_long_string is false"

    # The field is `format_spec`, not `spec`.
    joined = assigned_value("joined")&.node
    refute_nil joined, "no `joined` assignment"
    assert_instance_of AST::JoinedString, joined
    refute_nil joined.raw_value
    refute_empty joined.values
    # An f-string interleaves literal segments with the interpolated ones, so
    # the FormattedValue is not necessarily the first element.
    formatted = joined.values.map(&:node).grep(AST::FormattedValue)
    refute_empty formatted, "the f-string has no FormattedValue segment"
    # The fixture interpolates without a width, so `format_spec` is null.
    assert_nil formatted.first.format_spec
  end

  def test_target_paths
    # `Target.paths` is a bare `Vec<MemberOrIndex>` — no NodeRef, so no
    # position on the element itself.
    saw_paths = false
    saw_member = false
    saw_index = false
    @m.body.map(&:node).select { |n| n.is_a?(AST::AssignStmt) }.each do |stmt|
      stmt.targets.each do |ref|
        target = ref.node
        next if target.paths.empty?

        saw_paths = true
        target.paths.each do |path|
          if path.kind == "Member"
            saw_member = true
            # The payload is a `NodeRef<String>`, so it carries its own
            # position.
            refute_nil path.member
            refute_empty path.member.node
            refute_nil path.member.pos
          else
            saw_index = true
            assert_equal "Index", path.kind
            refute_nil path.index, "Index path has no expression"
            assert_instance_of AST::NumberLit, path.index.node
          end
        end
        # `pkgpath` is a single string, not a list.
        refute_nil target.pkgpath
      end
    end
    assert saw_paths, "no assignment carries a path target"
    assert saw_member, "no Member path in the fixture"
    assert saw_index, "no Index path in the fixture"
  end

  def test_starred_and_missing
    starred = assigned_value("starred")&.node
    refute_nil starred, "no `starred` assignment"
    elt = starred.is_a?(AST::ListExpr) ? starred.elts.first&.node : starred
    refute_nil elt
    assert_instance_of AST::StarredExpr, elt
    # `StarredExpr.ctx` is `ExprContext`, which has Load and Store — there is
    # no `Del`.
    assert_includes %w[Load Store], elt.ctx

    # The parser substitutes a placeholder `Identifier` for a missing
    # expression, so this decodes as an Identifier with a name rather than as
    # `Expr::Missing`.
    missing = assigned_value("missing_expr")&.node
    refute_nil missing, "no `missing_expr` assignment"
    assert_instance_of AST::IdentifierExpr, missing
    refute_empty missing.identifier.name
  end

  def test_type_is_adjacently_tagged
    # `Type` is `#[serde(tag = "type", content = "value")]`: the tag names the
    # shape and the payload is inlined under `value`. `Any` is the only unit
    # variant, so it has no `value` at all.
    any_t = alias_type("TAny")&.node
    refute_nil any_t, "no TAny type alias"
    assert_instance_of AST::AnyType, any_t
    assert_equal "Any", any_t.tag

    # `Basic` carries a bare string, not an object.
    basic_t = alias_type("TBasic")&.node
    refute_nil basic_t, "no TBasic type alias"
    assert_instance_of AST::BasicType, basic_t
    assert_includes %w[Bool Int Float Str], basic_t.name

    # `Named` inlines the Identifier newtype.
    named_t = alias_type("TNamed")&.node
    refute_nil named_t, "no TNamed type alias"
    assert_instance_of AST::NamedType, named_t
    assert_equal "Cloud", named_t.identifier.name

    # List / Dict / Union nest under `inner_type` etc.
    list_t = alias_type("TList")&.node
    refute_nil list_t, "no TList type alias"
    assert_instance_of AST::ListType, list_t
    refute_nil list_t.inner_type

    dict_t = alias_type("TDict")&.node
    refute_nil dict_t, "no TDict type alias"
    assert_instance_of AST::DictType, dict_t
    refute_nil dict_t.key_type
    refute_nil dict_t.value_type

    union_t = alias_type("TUnion")&.node
    refute_nil union_t, "no TUnion type alias"
    assert_instance_of AST::UnionType, union_t
    assert_operator union_t.types.length, :>=, 2
    # The Rust field is `type_elements`; this binding keeps the wire name
    # honest by exposing it as `types`, so assert the elements decoded as
    # types rather than as anything else.
    assert union_t.types.all? { |n| n.node.is_a?(AST::BasicType) }

    # `FunctionType` uses `params_ty` / `ret_ty`, both optional.
    func_t = alias_type("TFunc")&.node
    refute_nil func_t, "no TFunc type alias"
    assert_instance_of AST::FunctionType, func_t
    refute_empty func_t.params_ty
    refute_nil func_t.ret_ty

    # `LiteralType` is itself tag+content, so `Type::Literal`'s value is a
    # *second* tagged document. `LiteralType.value` keeps the payload verbatim
    # because it has three different shapes depending on the inner tag.
    lit_int = alias_type("TLitInt")&.node
    refute_nil lit_int, "no TLitInt type alias"
    assert_instance_of AST::LiteralType, lit_int
    assert_includes %w[Int Float Str Bool], lit_int.inner_tag
    assert_instance_of Hash, lit_int.value
    assert_equal "Int", lit_int.value["type"]

    lit_str = alias_type("TLitStr")&.node
    refute_nil lit_str, "no TLitStr type alias"
    assert_instance_of AST::LiteralType, lit_str
    assert_equal "Str", lit_str.value["type"]
    refute_empty lit_str.value["value"]

    # `TypeAliasStmt` names its fields `type_name` / `type_value`.
    refute_nil find_type_alias("TAny").type_value
  end

  # ------------------------------------------------------------------ #
  # The load-bearing case
  # ------------------------------------------------------------------ #

  def test_every_tag_in_the_golden_capture_resolves
    walk = TagWalk.new
    unknown = walk.run(@m)
    # Sanity-check the walk itself before trusting its verdict: a walk that
    # visits nothing reports "no unresolved tags" just as happily as a correct
    # one, and the capture is large enough that a silently broken walk is a
    # real risk. `seen` counts every tagged node the walk reached.
    assert_operator walk.seen, :>, 200,
                    "the walk only reached #{walk.seen} nodes — it is not traversing"
    assert_empty unknown.map { |u| "#{u[:where]} => #{u[:tag]}" },
                 "#{unknown.length} tag(s) in the golden capture failed to resolve"
  end

  # A recursive walk over the whole tree, recording any node that fell through
  # to `Unknown*`. It is written as an object rather than a nest of lambdas
  # because `walk_stmt` reaches `walk_expr` (through every value field) and
  # `walk_expr` reaches back (through `LambdaExpr#body`) — and Ruby locals do
  # not see each other that way any more than Dart's do.
  class TagWalk
    def initialize
      @unknown = []
      @seen = 0
    end

    attr_reader :unknown, :seen

    # `mod` rather than `module`: the latter is a keyword, so it cannot be a
    # parameter name.
    def run(mod)
      mod.body.each { |ref| stmt(ref.node, "body") }
      @unknown
    end

    def type(node_ref, where)
      return if node_ref.nil?

      t = node_ref.node
      return if t.nil?

      @seen += 1
      if t.is_a?(AST::UnknownType)
        @unknown << { where: where, tag: t.tag }
        return
      end

      case t
      when AST::ListType then type(t.inner_type, "#{where}.inner_type")
      when AST::DictType
        type(t.key_type, "#{where}.key_type")
        type(t.value_type, "#{where}.value_type")
      when AST::UnionType
        t.types.each_with_index { |el, i| type(el, "#{where}.type_elements[#{i}]") }
      when AST::FunctionType
        t.params_ty.each_with_index { |p, i| type(p, "#{where}.params_ty[#{i}]") }
        type(t.ret_ty, "#{where}.ret_ty")
      end
    end

    # `NodeRef<Expr>` — unwrap and hand the payload to `expr_node`.
    def expr(node_ref, where)
      return if node_ref.nil?

      expr_node(node_ref.node, where)
    end

    # A bare decoded `Expr`, i.e. one the binding exposes without its `Node`
    # wrapper. Nothing currently does — every field returns a `Node` — but
    # the split is kept so adding one is a one-line change rather than a
    # rewrite of the walk.
    def expr_node(e, where)
      return if e.nil?

      @seen += 1
      if e.is_a?(AST::UnknownExpr)
        @unknown << { where: where, tag: e.variant }
        return
      end

      case e
      when AST::UnaryExpr then expr(e.operand, "#{where}.operand")
      when AST::BinaryExpr
        expr(e.left, "#{where}.left")
        expr(e.right, "#{where}.right")
      when AST::IfExpr
        expr(e.body, "#{where}.body")
        expr(e.cond, "#{where}.cond")
        expr(e.orelse, "#{where}.orelse")
      when AST::SelectorExpr, AST::StarredExpr
        expr(e.value, "#{where}.value")
      when AST::ParenExpr
        # `Paren` wraps the parenthesised expression in a field called `expr`,
        # not `value`.
        expr(e.expr, "#{where}.expr")
      when AST::CallExpr
        expr(e.func, "#{where}.func")
        each(e.args, "#{where}.args") { |n| expr(n, where) }
      when AST::QuantExpr
        expr(e.target, "#{where}.target")
        expr(e.test, "#{where}.test")
        expr(e.if_cond, "#{where}.if_cond")
      when AST::ListExpr then each(e.elts, "#{where}.elts") { |n| expr(n, where) }
      when AST::ListIfItemExpr
        expr(e.if_cond, "#{where}.if_cond")
        each(e.exprs, "#{where}.exprs") { |n| expr(n, where) }
        # `orelse` is `Option<NodeRef<Expr>>` — a single optional expression,
        # unlike `IfStmt.orelse` which really is a list of statements.
        expr(e.orelse, "#{where}.orelse")
      when AST::ListComp
        expr(e.elt, "#{where}.elt")
        each(e.generators, "#{where}.generators") { |g| clause(g) }
      when AST::DictComp
        expr(e.entry.key, "#{where}.entry.key")
        expr(e.entry.value, "#{where}.entry.value")
        each(e.generators, "#{where}.generators") { |g| clause(g) }
      when AST::ConfigIfEntryExpr
        expr(e.if_cond, "#{where}.if_cond")
        config_entries(e.items, "#{where}.items")
        # Also a single optional expression, not a list.
        expr(e.orelse, "#{where}.orelse")
      when AST::ConfigExpr
        config_entries(e.items, "#{where}.items")
      # `CheckExpr` is the class for both shapes — the tagged `Expr::Check`
      # and the untagged `check:` body — and it holds the three fields
      # directly rather than nesting them behind a `check` key.
      when AST::CheckExpr then check(e, "#{where}.check")
      when AST::LambdaExpr
        # `Arguments.defaults` / `ty_list` are index-aligned, so walk by
        # position rather than by index into `args`.
        e.args&.node&.defaults&.each { |d, i| expr(d, "#{where}.args.defaults[#{i}]") }
        e.args&.node&.ty_list&.each { |t, i| type(t, "#{where}.args.ty_list[#{i}]") }
        each(e.body, "#{where}.body") { |s| stmt(s, where) }
        type(e.return_ty, "#{where}.return_ty")
      when AST::Subscript
        expr(e.value, "#{where}.value")
        expr(e.index, "#{where}.index")
        expr(e.lower, "#{where}.lower")
        expr(e.upper, "#{where}.upper")
        expr(e.step, "#{where}.step")
      when AST::KeywordExpr then expr(e.keyword.value, "#{where}.keyword.value")
      when AST::ArgumentsExpr
        e.arguments.defaults.each { |d, i| expr(d, "#{where}.arguments.defaults[#{i}]") }
        e.arguments.ty_list.each { |t, i| type(t, "#{where}.arguments.ty_list[#{i}]") }
      when AST::Compare
        expr(e.left, "#{where}.left")
        each(e.comparators, "#{where}.comparators") { |n| expr(n, where) }
      when AST::JoinedString then each(e.values, "#{where}.values") { |n| expr(n, where) }
      when AST::FormattedValue then expr(e.value, "#{where}.value")
      end
    end

    def clause(node_ref)
      return if node_ref.nil?

      c = node_ref.node
      return if c.nil?

      expr(c.iter, "comp_clause.iter")
      each(c.ifs, "comp_clause.ifs") { |n| expr(n, "comp_clause.ifs") }
    end

    def check(c, where)
      return if c.nil?

      expr(c.test, "#{where}.test")
      expr(c.if_cond, "#{where}.if_cond")
      expr(c.msg, "#{where}.msg")
    end

    # A `Target` is a plain struct with no tag; only its `paths` can hold a
    # tagged node, and only the `Index` arm of a `MemberOrIndex` is a
    # `NodeRef<Expr>` — the `Member` arm is a `NodeRef<String>`.
    def target(node_ref)
      return if node_ref.nil?

      t = node_ref.node
      return if t.nil?

      t.paths.each { |p| expr(p.index, "target.paths.index") }
    end

    # `ConfigExpr.items` is `Vec<NodeRef<ConfigEntry>>`, so each element is a
    # `Node` wrapping an untagged `ConfigEntry`. `key` is nullable — a
    # `ConfigIfEntryExpr` hangs off a null key.
    def config_entries(list, where)
      list.each { |ref| expr(ref.node.key, "#{where}.key"); expr(ref.node.value, "#{where}.value") }
    end

    def decorators(list, where)
      list.each_with_index do |d, i|
        # A `Decorator`, not a `CallExpr`: same three fields, no `type` key.
        deco = d.node
        next if deco.nil?

        expr(deco.func, "#{where}.decorators[#{i}].func")
        each(deco.args, "#{where}.decorators[#{i}].args") { |a| expr(a, where) }
        each(deco.keywords, "#{where}.decorators[#{i}].keywords") { |k| expr(k&.node&.value, where) }
      end
    end

    def stmt(node, where)
      return if node.nil?

      @seen += 1
      if node.is_a?(AST::UnknownStmt)
        @unknown << { where: where, tag: node.variant }
        return
      end

      case node
      when AST::TypeAliasStmt then type(node.ty, "#{where}.ty")
      when AST::ExprStmt then node.exprs.each { |n| expr(n, "#{where}.exprs") }
      when AST::UnificationStmt
        # `value` is a bare SchemaExpr — walk its config but not `name`, which
        # is an Identifier and carries no tag.
        expr(node.value&.node&.config, "#{where}.value.config")
      when AST::AssignStmt
        each(node.targets, "#{where}.targets") { |t| target(t) }
        expr(node.value, "#{where}.value")
        type(node.ty, "#{where}.ty")
      when AST::AugAssignStmt
        expr(node.value, "#{where}.value")
        target(node.target)
      when AST::AssertStmt
        expr(node.test, "#{where}.test")
        expr(node.if_cond, "#{where}.if_cond")
        expr(node.msg, "#{where}.msg")
      when AST::IfStmt
        each(node.body, "#{where}.body") { |s| stmt(s, "#{where}.body") }
        expr(node.cond, "#{where}.cond")
        each(node.orelse, "#{where}.orelse") { |s| stmt(s, "#{where}.orelse") }
      when AST::SchemaAttr
        expr(node.value, "#{where}.value")
        type(node.ty, "#{where}.ty")
        decorators(node.decorators, where)
      when AST::SchemaStmt
        node.args&.node&.defaults&.each { |d, i| expr(d, "#{where}.args.defaults[#{i}]") }
        node.args&.node&.ty_list&.each { |t, i| type(t, "#{where}.args.ty_list[#{i}]") }
        each(node.body, "#{where}.body") { |s| stmt(s, "#{where}.body") }
        decorators(node.decorators, where)
        node.checks.each { |c| check(c.node, "#{where}.checks") }
        sig = node.index_signature
        if sig
          expr(sig.node.value, "#{where}.index_signature.value")
          type(sig.node.key_ty, "#{where}.index_signature.key_ty")
          type(sig.node.value_ty, "#{where}.index_signature.value_ty")
        end
      when AST::RuleStmt
        node.args&.node&.defaults&.each { |d, i| expr(d, "#{where}.args.defaults[#{i}]") }
        node.args&.node&.ty_list&.each { |t, i| type(t, "#{where}.args.ty_list[#{i}]") }
        decorators(node.decorators, where)
        node.checks.each { |c| check(c.node, "#{where}.checks") }
      end
    end

    private

    def each(list, _where)
      list.each_with_index { |item, i| yield item, i }
    end
  end
end

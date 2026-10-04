# frozen_string_literal: true

require "minitest/autorun"

require "kcl_lib"

# Alignment tests for the typed AST.
#
# Parses a real KCL fixture through the service, decodes the resulting
# `ast_json`, and asserts the typed tree matches the wire. The point of these
# tests is the *shape*: which nodes carry a `type` discriminator and which are
# bare structs, and what the `Type` enum actually serializes to. Those are the
# details every binding has to get right and the ones most easily guessed
# wrong, so they are pinned here.
#
# The same fixture is used by the Python, Node.js, .NET, WASM, C, C++, Dart,
# Julia, Lua and Zig bindings so the bindings stay comparable.
class AstTest < Minitest::Test
  AST = KclLib::AST

  # Exercises every AST node shape the Ruby binding models: a type alias, a
  # docstring, a decorated optional attribute, a check, a schema
  # instantiation, a lambda with annotated parameters, a list comprehension, an
  # f-string, an aug-assign and an if-statement. Quoted heredoc so the KCL
  # f-string `${x.name}` survives without Ruby interpolation.
  FIXTURE = <<~'KCL'
    type StrOrInt = str | int

    schema Person:
        """A person."""

        @deprecated
        name: str = "anonymous"

        age: int = 0

        check:
            age >= 0 if age, "age must be non-negative"

    x = Person {name = "Alice", age = 30}
    adder = lambda a: int, b: int -> int {
        a + b
    }
    nums = [i * 2 for i in range(10) if i > 2]
    greeting = "hi ${x.name}"
    s: str = "a"
    s += "b"
    if s:
        y = 1
  KCL

  # An `import` of a package that is not on disk. `parse_file` reports a
  # `CannotFindModule` diagnostic for it, but it still produces the AST node,
  # which is what this fixture is for.
  IMPORT_FIXTURE = "import pkg1\n\na = 1\n"

  def setup
    @api = KclLib::API.new
  end

  def parse_fixture
    result = @api.parse_file(KclLib::ParseFileArgs.new(path: "main.k", source: FIXTURE))
    assert_empty result.errors, "fixture must parse cleanly"
    AST.parse_module(result.ast_json)
  end

  # The first top-level statement of the given class, or nil.
  def find_stmt(m, klass)
    m.body.map(&:node).find { |n| n.is_a?(klass) }
  end

  def find_stmt_named(m, klass, &block)
    m.body.map(&:node).select { |n| n.is_a?(klass) }.find(&block)
  end

  # The named schema attribute of the `Person` schema in the fixture.
  def person_attr(m, attr_name)
    person = find_stmt(m, AST::SchemaStmt)
    refute_nil person, "fixture has no schema"
    found = person.body.map(&:node).select { |a| a.is_a?(AST::SchemaAttr) }
                         .find { |a| a.name && a.name.node == attr_name }
    refute_nil found, "fixture has no attribute named #{attr_name}"
    found
  end

  # The value assigned to the top-level variable `name`.
  def assigned_value(m, name)
    m.body.map(&:node).select { |s| s.is_a?(AST::AssignStmt) }
         .find { |s| s.targets.first && s.targets.first.node.name&.node == name }&.value
  end

  def test_module_filename_and_no_pkg
    m = parse_fixture
    assert m.filename.end_with?("main.k")
    refute_empty m.body
    # The Rust `Module` struct has no `pkg` field; the Java and Go bindings
    # used to expose one and were aligned to drop it.
    assert_equal %i[filename doc body comments], m.members
  end

  def test_every_node_carries_its_source_position
    m = parse_fixture
    m.body.each do |ref|
      refute_nil ref.pos, "statement on line #{ref.pos&.line} has no position"
      assert_equal "main.k", ref.pos.filename
    end
    schema_ref = m.body.find { |r| r.node.is_a?(AST::SchemaStmt) }
    assert_equal 3, schema_ref.pos.line
    assert_equal "Person", find_stmt(m, AST::SchemaStmt).name.node
  end

  def test_type_is_tagged_with_the_payload_in_value
    # This is the shape that differs from what most other bindings assume.
    # `ast::Type` is `#[serde(tag = "type", content = "value")]` and
    # `BasicType` is a fieldless enum, so a basic type serializes as
    # {"type": "Basic", "value": "Str"} - NOT {"type": "Str"}.
    ty = person_attr(parse_fixture, "name").ty.node
    assert_instance_of AST::BasicType, ty
    assert_equal "Str", ty.name
    assert_equal "Basic", ty.tag
  end

  def test_union_type_lists_its_elements_under_type_elements
    alias_stmt = find_stmt(parse_fixture, AST::TypeAliasStmt)
    assert_equal "StrOrInt", alias_stmt.type_name.node.name
    ty = alias_stmt.ty.node
    assert_instance_of AST::UnionType, ty
    members = ty.types.map(&:node)
    assert_equal 2, members.length
    assert members.all?(AST::BasicType)
    assert_equal %w[Int Str], members.map(&:name).sort
  end

  def test_schema_decorators_decode_to_untagged_decorators
    # `SchemaStmt.decorators` is `Vec<NodeRef<CallExpr>>` and only the `Expr`
    # enum is `#[serde(tag = "type")]`, so a decorator arrives as a bare
    # {func, args, keywords} object with no discriminator. It is a
    # `Decorator`, not a `CallExpr` — the tagged `Expr::Call` is the other
    # shape of the same three fields.
    name = person_attr(parse_fixture, "name")
    assert_equal 1, name.decorators.length
    deco = name.decorators.first.node
    assert_instance_of AST::Decorator, deco
    refute_instance_of AST::CallExpr, deco
    assert_instance_of AST::IdentifierExpr, deco.func.node
    assert_equal "deprecated", deco.func.node.identifier.name
  end

  def test_schema_checks_decode_to_check_exprs
    person = find_stmt(parse_fixture, AST::SchemaStmt)
    assert_equal 1, person.checks.length

    check = person.checks.first.node
    # One class for both shapes: the untagged `check:` body and the tagged
    # `Expr::Check` carry the same three keys.
    assert_instance_of AST::CheckExpr, check
    assert_equal "Check", check.tag
    assert_instance_of AST::Compare, check.test.node
    assert_equal ["GtE"], check.test.node.ops
    assert_instance_of AST::IdentifierExpr, check.if_cond.node
    assert_instance_of AST::StringLit, check.msg.node
    assert_equal "age must be non-negative", check.msg.node.value
  end

  def test_is_optional_and_doc_survive_on_a_schema_attribute
    age = person_attr(parse_fixture, "age")
    refute age.is_optional
    assert_equal "", age.doc
    # `SchemaAttr.ty` is a non-optional NodeRef<Type> in Rust.
    refute_nil age.ty
  end

  def test_number_literal_carries_a_nested_tagged_value
    # NumberLit.value is a `NumberLitValue`, itself tagged
    # `#[serde(tag = "type", content = "value")]` - so `0` arrives as
    # {"type": "Int", "value": 0}.
    lit = person_attr(parse_fixture, "age").value.node
    assert_instance_of AST::NumberLit, lit
    assert_equal "Int", lit.value_tag
    assert_equal 0, lit.value
    assert_nil lit.binary_suffix
  end

  def test_config_entries_round_trip_operation_and_shorthand
    schema_expr = assigned_value(parse_fixture, "x").node
    assert_instance_of AST::SchemaExpr, schema_expr
    # SchemaExpr.name is a NodeRef<Identifier>, not an expression.
    assert_equal "Person", schema_expr.name.node.name

    config = schema_expr.config.node
    assert_instance_of AST::ConfigExpr, config
    assert_equal 2, config.items.length
    config.items.each do |item|
      assert_instance_of AST::IdentifierExpr, item.node.key.node
      # `ConfigEntryOperation` is Union | Override | Insert. A plain
      # `{name = ...}` inside a schema instantiation is an Override; the
      # Union form comes from a `<<>>`-style merge.
      assert_equal "Override", item.node.operation
      # `skip_serializing_if = "is_false"` - absent on the wire, so false.
      refute item.node.is_shorthand
    end
  end

  def test_lambda_args_are_untagged_identifiers_with_aligned_lists
    args = assigned_value(parse_fixture, "adder").node.args.node
    assert_equal 2, args.args.length
    assert_equal %w[a b], args.args.map { |a| a.node.name }
    # `defaults` and `ty_list` are Vec<Option<...>> - same length as args.
    assert_equal 2, args.defaults.length
    assert args.defaults.all? { |d| d.nil? }
    assert_equal %w[Int Int], args.ty_list.map { |t| t.node.name }
  end

  def test_lambda_body_holds_statements_not_expressions
    lambda = assigned_value(parse_fixture, "adder").node
    assert_instance_of AST::LambdaExpr, lambda
    assert_equal 1, lambda.body.length
    assert_instance_of AST::ExprStmt, lambda.body.first.node
    binary = lambda.body.first.node.exprs.first.node
    assert_instance_of AST::BinaryExpr, binary
    assert_equal "Add", binary.op
  end

  def test_list_comprehension_decodes_its_comp_clause
    comp = assigned_value(parse_fixture, "nums").node
    assert_instance_of AST::ListComp, comp
    assert_equal 1, comp.generators.length
    # targets is a Vec<NodeRef<Identifier>> - untagged, like Arguments.args.
    gen = comp.generators.first.node
    assert_equal 1, gen.targets.length
    assert_equal "i", gen.targets.first.node.name
    assert_equal 1, gen.ifs.length
    assert_instance_of AST::Compare, gen.ifs.first.node
  end

  def test_import_is_flat_with_path_and_asname_as_positioned_strings
    # `ImportStmt` is a flat struct: `path` and `asname` are `Node<String>`
    # with their own positions, while `rawpath`, `name` and `pkg_name` are
    # plain strings on the same node. Older bindings read them from a nested
    # `node` object, which the parser does not emit.
    result = @api.parse_file(KclLib::ParseFileArgs.new(path: "main.k", source: IMPORT_FIXTURE))
    imp = find_stmt(AST.parse_module(result.ast_json), AST::ImportStmt)
    assert_equal "pkg1", imp.rawpath
    assert_equal "pkg1", imp.name
    assert_equal "__main__", imp.pkg_name
    refute_nil imp.path
    refute_nil imp.path.pos
    assert_nil imp.as_name
  end

  def test_aug_assign_if_statement_and_fstring
    m = parse_fixture
    aug = find_stmt(m, AST::AugAssignStmt)
    assert_equal "Add", aug.op
    assert_equal "s", aug.target.node.name.node

    if_stmt = find_stmt(m, AST::IfStmt)
    refute_nil if_stmt.cond
    assert_equal 1, if_stmt.body.length

    joined = assigned_value(m, "greeting").node
    assert_instance_of AST::JoinedString, joined
    refute_empty joined.values
  end

  def test_an_unknown_tag_degrades_to_a_readable_node
    m = AST.parse_module('{"filename":"a.k","body":[{"node":{"type":"Nope"}}]}')
    assert_instance_of AST::UnknownStmt, m.body.first.node
    assert_equal "Nope", m.body.first.node.variant

    # An unknown *expression* tag degrades the same way, so a newer parser
    # does not take the whole file down.
    m2 = AST.parse_module('{"filename":"a.k","body":[{"node":{"type":"Assign","targets":[],' \
                          '"value":{"node":{"type":"Nope"}},"ty":null}}]}')
    assert_instance_of AST::UnknownExpr, m2.body.first.node.value.node
    assert_equal "Nope", m2.body.first.node.value.node.variant
  end

  def test_a_payload_with_no_type_at_all_raises
    # This is the failure the degradation path used to hide. An untagged
    # `{name, args, kwargs, config}` — the shape `UnificationStmt.value` really
    # has — routed through the tagged `Expr` path has no tag to dispatch on,
    # and it used to come back as an `UnknownExpr` whose `variant` was nil:
    # indistinguishable from a genuinely new variant, and silently wrong
    # rather than loud. So a missing discriminator raises and an unrecognised
    # one does not.
    untagged = '{"filename":"a.k","body":[{"node":{"type":"Assign","targets":[],' \
               '"value":{"node":{"name":null,"args":[],"kwargs":[],"config":null}},"ty":null}}]}'
    err = assert_raises(ArgumentError) { AST.parse_module(untagged) }
    assert_match(/no `type` discriminator/, err.message)

    # Same rule for a statement, and for a type.
    assert_raises(ArgumentError) do
      AST.parse_module('{"filename":"a.k","body":[{"node":{"name":null,"args":[],"kwargs":[],"config":null}}]}')
    end
    assert_raises(ArgumentError) do
      AST.parse_module('{"filename":"a.k","body":[{"node":{"type":"TypeAlias",' \
                       '"type_name":{"node":{"names":[{"node":"T"}],"pkgpath":"","ctx":"Load"}},' \
                       '"type_value":null,"ty":{"node":{"value":"Str"}}}}]}')
    end
  end

  def test_module_and_check_expr_use_the_java_vocabulary
    # The names are the Java binding's, so a table read from one binding is
    # readable in the next. `KclModule` is kept as an alias.
    m = parse_fixture
    assert_instance_of AST::Module, m
    assert_same AST::Module, AST::KclModule
    assert_equal %i[filename doc body comments], m.members
  end

  def test_parse_program_ast_returns_a_list_of_modules
    result = @api.parse_program(KclLib::ParseProgramArgs.new(sources: [FIXTURE]))
    assert_empty result.errors
    modules = AST.parse_program_ast(result.ast_json)
    refute_empty modules
    # parse_program synthesizes `__main__.k` for the entry-point module.
    assert modules.first.filename.end_with?(".k")
    refute_empty modules.first.body
  end

  def test_an_unknown_field_is_rejected
    err = assert_raises(ArgumentError) { AST::BasicType.new(nmae: "Str") }
    assert_match(/unknown BasicType field/, err.message)
  end
end

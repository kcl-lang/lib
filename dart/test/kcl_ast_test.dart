// kcl_ast_test.dart — Alignment tests for the typed AST package.
//
// Parses a real KCL fixture through `parseFile` / `parseProgram`, decodes the
// resulting `astJson`, and asserts the typed tree matches the wire. The point
// of these tests is the *shape*: which nodes carry a `type` discriminator and
// which are bare structs, and what the `Type` enum actually serializes to.
// Those are the details every binding has to get right and the ones most
// easily guessed wrong, so they are pinned here.
//
// The same fixture is used by the Python, Node.js, .NET, WASM, C, C++, Lua and
// Zig bindings so the bindings stay comparable.

import 'package:kcl_lib/kcl_lib.dart';
import 'package:test/test.dart';

/// Exercises every AST node shape the Dart package models: a docstring, a
/// decorated optional attribute, a check, a schema instantiation, a lambda
/// with annotated parameters, a type alias, a list comprehension, an
/// f-string, an import, an aug-assign and an if-statement.
// Raw string so the KCL f-string `${x.name}` survives Dart interpolation.
const String kFixture = r'''
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
''';

/// An `import` of a package that is not on disk. `parseFile` reports a
/// `CannotFindModule` diagnostic for it, but it still produces the AST node,
/// which is what this fixture is for.
const String kImportFixture = 'import pkg1\n\na = 1\n';

Module parseFixture() {
  final result =
      parseFile(ParseFileArgs(path: 'main.k', source: kFixture));
  expect(result.errors, isEmpty, reason: 'fixture must parse cleanly');
  return parseModule(result.astJson);
}

/// The first top-level statement matching [test], or null.
T? findStmt<T extends KclStmt>(Module m, bool Function(T) test) {
  for (final ref in m.body) {
    final stmt = ref.node;
    if (stmt is T && test(stmt)) return stmt;
  }
  return null;
}

void main() {
  group('AST', () {
    test('module.filename and no pkg', () {
      final m = parseFixture();
      expect(m.filename, endsWith('main.k'));
      expect(m.body, isNotEmpty);
      // The Rust `Module` struct has no `pkg` field; the Java and Go bindings
      // used to expose one and were aligned to drop it.
      expect(m.toString(), isNot(contains('pkg')));
    });

    test('every node carries its source position', () {
      final m = parseFixture();
      final schema = findStmt<SchemaStmt>(m, (s) => true)!;
      final ref = m.body.firstWhere((r) => r.node is SchemaStmt);
      expect(ref.pos, isNotNull);
      expect(ref.pos!.filename, 'main.k');
      expect(ref.pos!.line, 3);
      expect(schema.name!.pos!.line, 3);
    });

    test('Type is tagged `type` with the payload in `value`', () {
      // This is the shape that differs from what most other bindings assume.
      // `ast::Type` is `#[serde(tag = "type", content = "value")]` and
      // `BasicType` is a fieldless enum, so a basic type serializes as
      // {"type": "Basic", "value": "Int"} — NOT {"type": "Int"}.
      final m = parseFixture();
      final person =
          findStmt<SchemaStmt>(m, (s) => s.name?.node == 'Person')!;
      final name = person.body
          .map((r) => r.node)
          .whereType<SchemaAttr>()
          .firstWhere((a) => a.name?.node == 'name');

      final ty = name.ty!.node;
      expect(ty, isA<BasicType>());
      expect((ty as BasicType).name, 'Str');
    });

    test('union type lists its elements under type_elements', () {
      final m = parseFixture();
      final alias =
          findStmt<TypeAliasStmt>(m, (s) => s.typeName?.node.name == 'StrOrInt')!;
      final ty = alias.ty!.node;
      expect(ty, isA<UnionType>());
      final members = (ty as UnionType).types.map((t) => t.node).toList();
      expect(members.length, 2);
      expect(members.whereType<BasicType>().map((b) => b.name),
          containsAll(<String>['Str', 'Int']));
    });

    test('schema decorators decode to untagged CallExpr', () {
      // `SchemaStmt.decorators` is `Vec<NodeRef<CallExpr>>` and only the
      // `Expr` enum is `#[serde(tag = "type")]`, so a decorator arrives as a
      // bare {func, args, keywords} object with no discriminator.
      final m = parseFixture();
      final person =
          findStmt<SchemaStmt>(m, (s) => s.name?.node == 'Person')!;
      final name = person.body
          .map((r) => r.node)
          .whereType<SchemaAttr>()
          .firstWhere((a) => a.name?.node == 'name');

      expect(name.decorators, hasLength(1));
      final deco = name.decorators.first.node;
      expect(deco, isA<CallExpr>());
      expect(deco.func!.node, isA<IdentifierExpr>());
      expect((deco.func!.node as IdentifierExpr).identifier.name, 'deprecated');
    });

    test('schema checks decode to Check DTOs, not tagged expressions', () {
      final m = parseFixture();
      final person =
          findStmt<SchemaStmt>(m, (s) => s.name?.node == 'Person')!;
      expect(person.checks, hasLength(1));

      final check = person.checks.first.node;
      expect(check.test!.node, isA<Compare>());
      final compare = check.test!.node as Compare;
      expect(compare.ops, <String>['GtE']);
      expect(check.ifCond!.node, isA<IdentifierExpr>());
      expect(check.msg!.node, isA<StringLit>());
    });

    test('is_optional and doc survive on a schema attribute', () {
      final m = parseFixture();
      final person =
          findStmt<SchemaStmt>(m, (s) => s.name?.node == 'Person')!;
      final age = person.body
          .map((r) => r.node)
          .whereType<SchemaAttr>()
          .firstWhere((a) => a.name?.node == 'age');
      expect(age.isOptional, isFalse);
      expect(age.doc, isEmpty);
      // `SchemaAttr.ty` is a non-optional NodeRef<Type> in Rust.
      expect(age.ty, isNotNull);
    });

    test('number literal carries a nested tagged value', () {
      // NumberLit.value is a `NumberLitValue`, itself tagged
      // `#[serde(tag = "type", content = "value")]` — so `0` arrives as
      // {"type": "Int", "value": 0}.
      final m = parseFixture();
      final person =
          findStmt<SchemaStmt>(m, (s) => s.name?.node == 'Person')!;
      final age = person.body
          .map((r) => r.node)
          .whereType<SchemaAttr>()
          .firstWhere((a) => a.name?.node == 'age');
      final lit = age.value!.node;
      expect(lit, isA<NumberLit>());
      final num = lit as NumberLit;
      expect(num.valueTag, 'Int');
      expect(num.value, 0);
      expect(num.binarySuffix, isNull);
    });

    test('config entries round-trip operation and shorthand', () {
      final m = parseFixture();
      final assign = findStmt<AssignStmt>(
          m, (s) => s.targets.first.node.name?.node == 'x')!;
      final schemaExpr = assign.value!.node;
      expect(schemaExpr, isA<SchemaExpr>());
      // SchemaExpr.name is a NodeRef<Identifier>, not an expression.
      expect((schemaExpr as SchemaExpr).name!.node.name, 'Person');

      final config = schemaExpr.config!.node;
      expect(config, isA<ConfigExpr>());
      final items = (config as ConfigExpr).items;
      expect(items, hasLength(2));
      for (final item in items) {
        expect(item.node.key!.node, isA<IdentifierExpr>());
        // `ConfigEntryOperation` is Union | Override | Insert. A plain
        // `{name = ...}` inside a schema instantiation is an Override; the
        // Union form comes from a `<<>>`-style merge.
        expect(item.node.operation, 'Override');
        // `skip_serializing_if = "is_false"` — absent on the wire, so false.
        expect(item.node.isShorthand, isFalse);
      }
    });

    test('lambda args are untagged identifiers with aligned lists', () {
      final m = parseFixture();
      final assign = findStmt<AssignStmt>(
          m, (s) => s.targets.first.node.name?.node == 'adder')!;
      final lambda = assign.value!.node;
      expect(lambda, isA<LambdaExpr>());

      final args = (lambda as LambdaExpr).args!.node;
      expect(args.length, 2);
      expect(args.args.map((a) => a.node.name), <String>['a', 'b']);
      // `defaults` and `ty_list` are Vec<Option<...>> — same length as args.
      expect(args.defaults, hasLength(2));
      expect(args.defaults.every((d) => d == null), isTrue);
      expect(args.tyList.map((t) => (t!.node as BasicType).name),
          <String>['Int', 'Int']);
    });

    test('lambda body holds statements, not expressions', () {
      final m = parseFixture();
      final assign = findStmt<AssignStmt>(
          m, (s) => s.targets.first.node.name?.node == 'adder')!;
      final body = (assign.value!.node as LambdaExpr).body;
      expect(body, hasLength(1));
      expect(body.first.node, isA<ExprStmt>());
      final binary =
          (body.first.node as ExprStmt).exprs.first.node as BinaryExpr;
      expect(binary.op, 'Add');
    });

    test('list comprehension decodes its CompClause', () {
      final m = parseFixture();
      final assign = findStmt<AssignStmt>(
          m, (s) => s.targets.first.node.name?.node == 'nums')!;
      final comp = assign.value!.node;
      expect(comp, isA<ListComp>());
      final gens = (comp as ListComp).generators;
      expect(gens, hasLength(1));
      // targets is a Vec<NodeRef<Identifier>> — untagged, like Arguments.args.
      expect(gens.first.node.targets.single.node.name, 'i');
      expect(gens.first.node.ifs.single.node, isA<Compare>());
    });

    test('import is flat, with path and asname as positioned strings', () {
      // `ImportStmt` is a flat struct: `path` and `asname` are `Node<String>`
      // with their own positions, while `rawpath`, `name` and `pkg_name` are
      // plain strings on the same node. Older bindings read them from a nested
      // `node` object, which the parser does not emit.
      final result = parseFile(
          ParseFileArgs(path: 'main.k', source: kImportFixture));
      final m = parseModule(result.astJson);
      final imp = findStmt<ImportStmt>(m, (s) => true)!;
      expect(imp.rawpath, 'pkg1');
      expect(imp.name, 'pkg1');
      expect(imp.pkgName, '__main__');
      expect(imp.path, isNotNull);
      expect(imp.path!.pos, isNotNull);
      expect(imp.asName, isNull);
    });

    test('aug-assign, if-statement and f-string', () {
      final m = parseFixture();
      final aug = findStmt<AugAssignStmt>(m, (s) => s.op == 'Add')!;
      expect(aug.target!.node.name?.node, 's');

      final ifStmt = findStmt<IfStmt>(m, (s) => true)!;
      expect(ifStmt.cond, isNotNull);
      expect(ifStmt.body, hasLength(1));

      final assign = findStmt<AssignStmt>(
          m, (s) => s.targets.first.node.name?.node == 'greeting')!;
      final joined = assign.value!.node;
      expect(joined, isA<JoinedString>());
      expect((joined as JoinedString).values, isNotEmpty);
    });

    test('an unknown tag degrades to a readable node', () {
      final m = parseModule('{"filename":"a.k","body":[{"node":{"type":"Nope"}}]}');
      expect(m.body.single.node, isA<UnknownStmt>());
      expect(m.body.single.node.tag, 'Nope');
    });

    test('parseProgramAst returns a list of modules', () {
      final result = parseProgram(ParseProgramArgs(sources: [kFixture]));
      expect(result.errors, isEmpty);
      final modules = parseProgramAst(result.astJson);
      expect(modules, isNotEmpty);
      // parseProgram synthesizes `__main__.k` for the entry-point module.
      expect(modules.first.filename, endsWith('.k'));
      expect(modules.first.body, isNotEmpty);
    });
  });
}

// ast_contract_test.dart — The Dart AST wire contract, asserted.
//
// `kcl_lib.ast` is a hand-written decoder for the JSON the KCL parser emits,
// and a wrong guess about that JSON fails *silently*: a tag the switch in
// `exprFromWire` does not know falls through to `UnknownExpr`, so a decoder
// keyed on `"CheckExpression"` — the spelling `Expr::get_expr_name()` returns,
// which is a diagnostic name and not the serde tag — still returns a
// plausible-looking tree full of unknowns.
//
// These tests decode `testdata/ast/alignment.json` — the real parser's output
// for `testdata/ast/alignment.k`, which exercises every node shape — and
// assert the contract documented in that directory's README. Decoding the
// captured JSON rather than calling `parseFile` keeps this a pure test of the
// decoder: it needs no native runtime, and it does not depend on the parser
// staying byte-identical.
//
// `kcl_ast_test.dart` is the other half of the pair. That one parses a live
// fixture through the FFI, proving the parser emits something the loader
// accepts; this one proves the loader understands the shapes the parser is
// *specified* to emit.

import 'dart:io';

import 'package:kcl_lib/kcl_lib.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Fixture
// ---------------------------------------------------------------------------

/// Locate the shared golden capture. Tests run with `dart/` as the working
/// directory, but the candidate list keeps this working from `test/` too.
String findFixture() {
  const candidates = [
    '../testdata/ast/alignment.json',
    'testdata/ast/alignment.json',
    '../../testdata/ast/alignment.json',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  throw StateError('could not locate testdata/ast/alignment.json (tried $candidates)');
}

late final Module golden;

// ---------------------------------------------------------------------------
// Lookups
// ---------------------------------------------------------------------------

T? _findStmt<T extends KclStmt>(bool Function(T) test) {
  for (final ref in golden.body) {
    final s = ref.node;
    if (s is T && test(s)) return s;
  }
  return null;
}

SchemaStmt? schemaNamed(String name) =>
    _findStmt<SchemaStmt>((s) => s.name?.node == name);

/// The RHS of `name = …`, or null.
KclExpr? assignValue(String name) {
  final a = _findStmt<AssignStmt>(
      (s) => s.targets.isNotEmpty && s.targets.first.node.name?.node == name);
  return a?.value?.node;
}

TypeAliasStmt? aliasNamed(String name) => _findStmt<TypeAliasStmt>(
    (s) => s.typeName?.node.name == name);

AstType? aliasType(String name) => aliasNamed(name)?.ty?.node;

/// `a.b.c` for a `NodeRef<Identifier>`.
String dotted(Node<Identifier>? ref) => ref?.node.name ?? '';

/// Narrow a decoded node to [T], failing the test rather than returning null.
///
/// `expect(v, isA<T>())` does not promote in Dart — it is a plain function
/// call, not a type test the flow analyser recognises — so a `switch` or a
/// field access after it will not compile against the sealed base type. This
/// does the assertion *and* narrows in one step, so every `as` cast in these
/// tests is checked.
T expectAs<T>(Object? v, [String? reason]) {
  expect(v, isA<T>(), reason: reason);
  return v as T;
}

// ---------------------------------------------------------------------------
// The unresolved-tag walker
// ---------------------------------------------------------------------------
//
// A tag the decoder does not recognise becomes an `UnknownExpr` rather than an
// error, so this walk is the only thing standing between a stale switch and a
// silently empty AST.

/// Collect every tag in the tree that this package failed to resolve, as
/// `Expr.Foo` / `Stmt.Foo` / `Type.Foo` strings.
///
/// This is a class rather than a nest of local functions because the walk is
/// mutually recursive — `expr` reaches `stmt` through `LambdaExpr.body` while
/// `stmt` reaches `expr` through every value field — and Dart does not allow
/// two local functions to call each other.
class _TagWalk {
  final List<String> unknown = <String>[];

  void type(AstType? t) {
    if (t == null) return;
    if (t is UnknownType) {
      unknown.add('Type.${t.tag}');
      return;
    }
    if (t is ListType) {
      type(t.innerType?.node);
    } else if (t is DictType) {
      type(t.keyType?.node);
      type(t.valueType?.node);
    } else if (t is UnionType) {
      for (final n in t.types) {
        type(n.node);
      }
    } else if (t is FunctionType) {
      t.paramsTy?.forEach((n) => type(n.node));
      type(t.retTy?.node);
    }
  }

  void expr(KclExpr? e) {
    if (e == null) return;
    if (e is UnknownExpr) {
      unknown.add('Expr.${e.variant}');
      return;
    }
    if (e is TargetExpr) {
      // Target.paths is a bare Vec<MemberOrIndex>; only Index carries an Expr.
      for (final p in e.target.paths) {
        if (p is Index) expr(p.index.node);
      }
    } else if (e is UnaryExpr) {
      expr(e.operand?.node);
    } else if (e is BinaryExpr) {
      expr(e.left?.node);
      expr(e.right?.node);
    } else if (e is IfExpr) {
      expr(e.body?.node);
      expr(e.cond?.node);
      expr(e.orelse?.node);
    } else if (e is SelectorExpr) {
      expr(e.value?.node);
    } else if (e is CallExpr) {
      expr(e.func?.node);
      for (final n in e.args) {
        expr(n.node);
      }
      for (final n in e.keywords) {
        expr(n.node.value?.node);
      }
    } else if (e is ParenExpr) {
      expr(e.expr?.node);
    } else if (e is QuantExpr) {
      expr(e.target?.node);
      expr(e.test?.node);
      expr(e.ifCond?.node);
    } else if (e is ListExpr) {
      for (final n in e.elts) {
        expr(n.node);
      }
    } else if (e is ListIfItemExpr) {
      expr(e.ifCond?.node);
      for (final n in e.exprs) {
        expr(n.node);
      }
      expr(e.orelse?.node);
    } else if (e is ListComp) {
      expr(e.elt?.node);
      for (final n in e.generators) {
        clause(n.node);
      }
    } else if (e is StarredExpr) {
      expr(e.value?.node);
    } else if (e is DictComp) {
      expr(e.entry?.key?.node);
      expr(e.entry?.value?.node);
      for (final n in e.generators) {
        clause(n.node);
      }
    } else if (e is ConfigIfEntryExpr) {
      expr(e.ifCond?.node);
      for (final it in e.items) {
        expr(it.node.key?.node);
        expr(it.node.value?.node);
      }
      expr(e.orelse?.node);
    } else if (e is CompClause) {
      expr(e.iter?.node);
      for (final n in e.ifs) {
        expr(n.node);
      }
    } else if (e is SchemaExpr) {
      for (final n in e.args) {
        expr(n.node);
      }
      for (final n in e.kwargs) {
        expr(n.node.value?.node);
      }
      expr(e.config?.node);
    } else if (e is ConfigExpr) {
      for (final it in e.items) {
        expr(it.node.key?.node);
        expr(it.node.value?.node);
      }
    } else if (e is CheckExpr) {
      expr(e.test?.node);
      expr(e.ifCond?.node);
      expr(e.msg?.node);
    } else if (e is LambdaExpr) {
      for (final n in e.body) {
        stmt(n.node);
      }
      type(e.returnTy?.node);
      final args = e.args?.node;
      if (args != null) {
        for (final d in args.defaults) {
          expr(d?.node);
        }
        for (final t in args.tyList) {
          type(t?.node);
        }
      }
    } else if (e is Subscript) {
      expr(e.value?.node);
      expr(e.index?.node);
      expr(e.lower?.node);
      expr(e.upper?.node);
      expr(e.step?.node);
    } else if (e is KeywordExpr) {
      expr(e.keyword.value?.node);
    } else if (e is ArgumentsExpr) {
      for (final d in e.arguments.defaults) {
        expr(d?.node);
      }
      for (final t in e.arguments.tyList) {
        type(t?.node);
      }
    } else if (e is Compare) {
      expr(e.left?.node);
      for (final n in e.comparators) {
        expr(n.node);
      }
    } else if (e is JoinedString) {
      for (final n in e.values) {
        expr(n.node);
      }
    } else if (e is FormattedValue) {
      expr(e.value?.node);
    }
    // BasicType / NamedType / LiteralType / StringLit / NumberLit /
    // NameConstantLit / MissingExpr are leaves.;
  }

  /// The `x in xs if cond` half of a comprehension, shared by `ListComp` and
  /// `DictComp`.
  void clause(CompClause c) {
    expr(c.iter?.node);
    for (final f in c.ifs) {
      expr(f.node);
    }
  }

  /// `Vec<NodeRef<CallExpr>>` — the payload is a bare `{func,args,keywords}`
  /// with no tag, so only `func` and the positional args carry expressions.
  void decorators(List<Node<CallExpr>> ds) {
    for (final d in ds) {
      expr(d.node.func?.node);
      for (final n in d.node.args) {
        expr(n.node);
      }
    }
  }

  void stmt(KclStmt? s) {
    if (s == null) return;
    if (s is UnknownStmt) {
      unknown.add('Stmt.${s.variant}');
      return;
    }
    if (s is TypeAliasStmt) {
      type(s.ty?.node);
    } else if (s is ExprStmt) {
      for (final n in s.exprs) {
        expr(n.node);
      }
    } else if (s is UnificationStmt) {
      final se = s.value?.node;
      if (se != null) {
        for (final n in se.args) {
          expr(n.node);
        }
        for (final n in se.kwargs) {
          expr(n.node.value?.node);
        }
        expr(se.config?.node);
      }
    } else if (s is AssignStmt) {
      for (final t in s.targets) {
        for (final p in t.node.paths) {
          if (p is Index) expr(p.index.node);
        }
      }
      expr(s.value?.node);
      type(s.ty?.node);
    } else if (s is AugAssignStmt) {
      final t = s.target?.node;
      if (t != null) {
        for (final p in t.paths) {
          if (p is Index) expr(p.index.node);
        }
      }
      expr(s.value?.node);
    } else if (s is AssertStmt) {
      expr(s.test?.node);
      expr(s.ifCond?.node);
      expr(s.msg?.node);
    } else if (s is IfStmt) {
      expr(s.cond?.node);
      for (final n in s.body) {
        stmt(n.node);
      }
      for (final n in s.orelse) {
        stmt(n.node);
      }
    } else if (s is SchemaAttr) {
      expr(s.value?.node);
      type(s.ty?.node);
      decorators(s.decorators);
    } else if (s is SchemaStmt) {
      for (final n in s.body) {
        stmt(n.node);
      }
      decorators(s.decorators);
      for (final c in s.checks) {
        expr(c.node.test?.node);
        expr(c.node.ifCond?.node);
        expr(c.node.msg?.node);
      }
      type(s.indexSignature?.node.keyTy?.node);
      type(s.indexSignature?.node.valueTy?.node);
    } else if (s is RuleStmt) {
      decorators(s.decorators);
      for (final c in s.checks) {
        expr(c.node.test?.node);
        expr(c.node.ifCond?.node);
        expr(c.node.msg?.node);
      }
    }
    // ImportStmt has no expression children.;
  }

  /// Walk [golden] and return every tag this package failed to resolve.
  List<String> run(Module module) {
    for (final ref in module.body) {
      stmt(ref.node);
    }
    return unknown;
  }
}

List<String> unresolvedTags() => _TagWalk().run(golden);

// ---------------------------------------------------------------------------
// The contract
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    golden = parseModule(File(findFixture()).readAsStringSync());
  });

  group('AST wire contract', () {
    test('Module and Comment shape', () {
      expect(golden.filename, contains('.k'));
      expect(golden.body, isNotEmpty);
      // `comments` is `Vec<NodeRef<Comment>>`, so the payload is `{text}`
      // rather than a bare string.
      expect(golden.comments, isNotEmpty);
      expect(golden.comments.first.node.text, isNotEmpty);
      // Positions are flat on the wrapper, so a non-null pos on statement 0
      // proves the decoder reads `line` and not a nested `pos` object.
      final first = golden.body.first;
      expect(first.pos, isNotNull);
      expect(first.pos!.line, greaterThan(0));
      expect(first.pos!.filename, isNotEmpty);
    });

    test('ImportStmt flat fields', () {
      final imp = expectAs<ImportStmt>(golden.body.first.node);
      // `path` is a `Node<String>`, so it carries a position of its own.
      expect(imp.path, isNotNull);
      expect(imp.path!.pos, isNotNull);
      expect(imp.rawpath, isNotEmpty);
      expect(imp.name, isNotEmpty);
      // There is no `pkg_root` field on the wire.
      expect(imp.pkgName, isNotEmpty);
    });

    test('UnificationStmt target is a Store Identifier', () {
      final s = expectAs<UnificationStmt>(_findStmt<UnificationStmt>((_) => true));
      // `target` is an `Identifier`, not a `Target` — so it has a `ctx`.
      expect(s.target, isNotNull);
      expect(s.target!.node.ctx, 'Store');
      // `value` is a `SchemaExpr`, not an invented config struct.
      expect(s.value, isNotNull);
      expect(dotted(s.value!.node.name), 'Person');
    });

    test('AugAssign, Assert and If orelse', () {
      final aug = expectAs<AugAssignStmt>(_findStmt<AugAssignStmt>((_) => true));
      expect(aug.target?.node.name?.node, 'a');

      // `AssertStmt` is `{test, if_cond, msg}` — all NodeRefs.
      final assert_ = expectAs<AssertStmt>(_findStmt<AssertStmt>((_) => true));
      expect(assert_.test, isNotNull);

      // `orelse` is `Vec<NodeRef<Stmt>>`, not an expression.
      final if_ = expectAs<IfStmt>(_findStmt<IfStmt>((_) => true));
      expect(if_.cond, isNotNull);
      expect(if_.orelse, isA<List<Node<KclStmt>>>());
    });

    test('RuleStmt decorators and checks', () {
      final rule = expectAs<RuleStmt>(_findStmt<RuleStmt>((_) => true));
      expect(rule.name?.node, isNotEmpty);
      // `decorators` and `checks` are `Vec<NodeRef<…>>` over structs, so
      // neither element carries a tag. The fixture's rule is undecorated,
      // which is itself the assertion: a decoder that invented a tag would
      // not be able to produce an empty list here.
      expect(rule.decorators, isEmpty);
      expect(rule.checks, isNotEmpty);
      expect(rule.checks.first.node.test, isNotNull);
    });

    test('Schema decorators are flat CallExprs', () {
      final person = expectAs<SchemaStmt>(schemaNamed('Person'));
      // `@deprecated` and `@info` are on the `name` attribute, not on the
      // schema header, so the schema's own list is empty.
      expect(person.decorators, isEmpty);
      expect(person.checks, isNotEmpty);
      expect(person.checks.first.node.test, isNotNull);
      expect(person.checks.first.node.msg, isNotNull);

      final a = expectAs<SchemaAttr>(person.body.first.node);
      // `SchemaAttr.doc` is a plain String, not a `NodeRef<String>`.
      expect(a.doc, isNotNull);
      expect(a.decorators, hasLength(2));
      // `ty` is `NodeRef<Type>`, not an Option.
      expect(a.ty, isNotNull);
      expect((a.ty!.node as BasicType).name, 'Str');

      // A decorator payload is a bare `{func,args,keywords}`; the `func` is a
      // `NodeRef<Expr>` that *does* carry a tag.
      final d = a.decorators.first.node;
      expect(d.args, isEmpty);
      expect(d.func, isNotNull);
      expect((d.func!.node as IdentifierExpr).identifier.name, 'deprecated');
    });

    // ---------------------------------------------------------------
    // The three names this binding shares with the Java binding for a
    // payload that arrives without a `type` key: `CheckExpr`, `Decorator`
    // and `SchemaConfig`. All three are one wire object each, and each is
    // the same object the tagged `Expr` form produces.
    // ---------------------------------------------------------------

    test('a check is one CheckExpr, tagged or not', () {
      final person = expectAs<SchemaStmt>(schemaNamed('Person'));
      final check = person.checks.first.node;

      // `SchemaStmt.checks` is `Vec<NodeRef<CheckExpr>>` and the payload is a
      // bare `{test, if_cond, msg}` — three keys and no `type`. It decodes to
      // `CheckExpr`, which is a `KclExpr`, so `test` is one hop away rather
      // than `check.check.test`: that is what merging what used to be a `Check`
      // DTO underneath a `CheckExpr` wrapper buys.
      expect(check, isA<CheckExpr>());
      expect(check, isA<KclExpr>());
      expect(check.tag, 'Check');
      expect(check.test, isNotNull);
      expect(check.msg, isNotNull);
      expect(check.test!.node, isA<Compare>());

      // Every one of the three is an `Option<NodeRef<Expr>>`, and the first
      // check in the capture has no `if` clause — the key is present and its
      // value is `null`, which is not the same as the key being absent.
      expect(person.checks, hasLength(2));
      expect(check.ifCond, isNull);
      expect(person.checks[1].node.ifCond, isNotNull);
      expect(person.checks[1].node.ifCond!.node, isA<IdentifierExpr>());

      // The tagged form is the same struct with `"type": "Check"` in front.
      // No `Expr::Check` appears in `alignment.k`, so the tag is built by
      // hand here rather than pulled out of the capture.
      final tagged = exprFromWire({
        'type': 'Check',
        'if_cond': null,
        'msg': null,
        'test': {
          'node': {
            'type': 'NameConstantLit',
            'value': 'True',
          },
          'filename': 'x.k',
          'line': 1,
          'column': 0,
          'end_line': 1,
          'end_column': 4,
        },
      });
      expect(tagged, isA<CheckExpr>());
      final taggedCheck = tagged as CheckExpr;
      expect(taggedCheck.ifCond, isNull);
      expect(taggedCheck.msg, isNull);
      expect(taggedCheck.test!.node, isA<NameConstantLit>());
    });

    test('a decorator is a CallExpr under its Java name', () {
      final person = expectAs<SchemaStmt>(schemaNamed('Person'));
      final a = expectAs<SchemaAttr>(person.body.first.node);

      // `SchemaAttr.decorators` is `Vec<NodeRef<CallExpr>>`; `Decorator` is
      // the name Java gives that payload, and here it is the same type, so
      // the list is written in either spelling and mixes with neither.
      final Node<Decorator> first = a.decorators.first;
      final d = first.node;
      expect(d, isA<CallExpr>());
      expect(d.tag, 'Call');
      expect((d.func!.node as IdentifierExpr).identifier.name, 'deprecated');

      // It really is the one class: a decorator and an `Expr::Call` are the
      // same object under two names, which is what `typedef` means.
      final sameDecoder = callExprFromWire({'func': null, 'args': null, 'keywords': null});
      expect(sameDecoder, isA<Decorator>());
      expect(sameDecoder, isA<CallExpr>());
    });

    test('a unification value is a SchemaConfig', () {
      final s = expectAs<UnificationStmt>(_findStmt<UnificationStmt>((_) => true));

      // `UnificationStmt.value` is `NodeRef<SchemaExpr>` in Rust, spelled
      // `SchemaConfig` here because that is the one form of the payload with
      // no `type` key: `{"args":…,"config":…,"kwargs":…,"name":…}` and
      // nothing else. It is the same class as an `Expr::Schema`, so the
      // name is a spelling and not a second type.
      final Node<SchemaConfig> value = s.value!;
      final c = value.node;
      expect(c, isA<SchemaExpr>());
      expect(c.tag, 'Schema');
      expect(dotted(c.name), 'Person');

      // The decoder is shared: an untagged payload and a tagged one both go
      // through `schemaExprFromWire`, which ignores the discriminator.
      final tagged = exprFromWire({
        'type': 'Schema',
        'name': null,
        'args': [],
        'kwargs': [],
        'config': null,
      });
      expect(tagged, isA<SchemaConfig>());
      expect((tagged as SchemaConfig).name, isNull);
    });

    test('SchemaExpr vs Call, Keyword.arg is an Identifier', () {
      // `x = Person {…}` puts its entries in `config` and leaves `kwargs`
      // empty; `y = Person(1, name = "Bob")` is a plain Call.
      final x = expectAs<SchemaExpr>(assignValue('x'));
      expect(x.kwargs, isEmpty);
      expect(x.config?.node, isA<ConfigExpr>());

      final call = expectAs<CallExpr>(assignValue('y'));
      expect(call.args, hasLength(1));
      expect(call.keywords, hasLength(1));
      // `Keyword.arg` is a `NodeRef<Identifier>`, not an Expr.
      final kw = call.keywords.first.node;
      expect(kw.arg, isNotNull);
      expect(kw.arg!.node.name, 'name');
      expect(kw.value, isNotNull);
    });

    test('UnaryOp, BinOp and Compare parallel arrays', () {
      // `-a` is `USub`, not a generic "negate".
      expect(expectAs<UnaryExpr>(assignValue('unary')).op, 'USub');
      expect(expectAs<UnaryExpr>(assignValue('unary_not')).op, 'Not');

      // `ops` and `comparators` are parallel arrays.
      final cmp = expectAs<Compare>(assignValue('compare_chain'));
      expect(cmp.ops, hasLength(cmp.comparators.length));
      expect(cmp.ops, ['Lt', 'LtE']);
      for (final op in cmp.ops) {
        expect(const {
          'Eq', 'NotEq', 'Lt', 'LtE', 'Gt', 'GtE', 'Is', 'In', 'NotIn', 'Not', 'IsNot'
        }, contains(op), reason: '$op is not a CmpOp');
      }
    });

    test('Selector has_question and Subscript slices', () {
      // `Selector.attr` is an `Identifier`, and `has_question` is the
      // optional-access flag — there is no `attr_name` field.
      final optional = expectAs<SelectorExpr>(assignValue('optional'));
      expect(optional.hasQuestion, isTrue);
      // `Selector.attr` is a `NodeRef<Identifier>`, not an expression.
      expect(optional.attr, isA<Node<Identifier>>());
      expect(assignValue('selector'), isA<SelectorExpr>());

      // A slice puts its bounds in `lower`/`upper`/`step` and leaves `index`
      // null.
      final slice = expectAs<Subscript>(assignValue('subscript_slice'));
      expect(slice.index, isNull);
      expect(slice.lower, isNotNull);
      expect(slice.upper, isNotNull);

      final step = expectAs<Subscript>(assignValue('subscript_step'));
      expect(step.step, isNotNull);
      expect(step.lower, isNotNull);
      expect(step.upper, isNotNull);

      // `subscript_q` is `a?.b` — an optional *Selector*, not a Subscript.
      // The two are easy to confuse, and `has_question` lives on both.
      final q = expectAs<SelectorExpr>(assignValue('subscript_q'));
      expect(q.hasQuestion, isTrue);

      expect(expectAs<Subscript>(assignValue('subscript')).index, isNotNull);
    });

    test('ConfigEntry operations and is_shorthand', () {
      // `config = {a = 1, b: 2}` uses Override then Union.
      final items = expectAs<ConfigExpr>(assignValue('config')).items;
      expect(items, hasLength(2));
      expect(items[0].node.operation, 'Override');
      expect(items[1].node.operation, 'Union');
      // `skip_serializing_if = "is_false"`, so the key is absent rather than
      // explicitly false.
      expect(items[0].node.isShorthand, isFalse);

      // The ES6 shorthand sets the flag.
      final shorthand = expectAs<ConfigExpr>(assignValue('config_shorthand'));
      expect(shorthand.items, isNotEmpty);
      for (final e in shorthand.items) {
        expect(e.node.isShorthand, isTrue, reason: 'config_shorthand entry');
      }

      // `config_if` wraps the `ConfigIfEntryExpr` in a `ConfigEntry` whose
      // `key` is null.
      final configIf = expectAs<ConfigExpr>(assignValue('config_if'));
      expect(configIf.items, hasLength(1));
      final entry = configIf.items.first.node;
      expect(entry.key, isNull);
      expect(entry.value?.node, isA<ConfigIfEntryExpr>());
      expect((entry.value!.node as ConfigIfEntryExpr).items, isNotEmpty);
    });

    test('Quant, DictComp entry and CompClause targets', () {
      final q = expectAs<QuantExpr>(assignValue('quant'));
      // `op` is a single QuantOperation, not a list of them.
      expect(const {'All', 'Any', 'Filter', 'Map'}, contains(q.op));
      // `variables` is `Vec<NodeRef<Identifier>>`, not Targets.
      expect(q.variables, isNotEmpty);
      expect(q.variables.first.node.name, isNotEmpty);
      expect(q.test, isNotNull);

      // `DictComp.entry` is a bare ConfigEntry — there is no
      // `entry_key`/`key`/`value` triple and no `cond`.
      final comp = expectAs<DictComp>(assignValue('dict_comp'));
      expect(comp.entry, isNotNull);
      expect(comp.entry!.key, isNotNull);
      expect(comp.entry!.value, isNotNull);
      expect(comp.generators, isNotEmpty);
      // `CompClause.targets` are Identifiers.
      final clause = comp.generators.first.node;
      expect(clause.targets, isNotEmpty);
      expect(clause.targets.first.node, isA<Identifier>());

      // `ListIfItemExpr` is `{if_cond, exprs, orelse}` — there is no
      // `if_expr`.
      final item = expectAs<ListIfItemExpr>(
          expectAs<ListExpr>(assignValue('list_if_entry')).elts.first.node);
      expect(item.ifCond, isNotNull);
      expect(item.exprs, isNotEmpty);

      // The `*_if` forms are ListComp — there is no `cond` field.
      expect(expectAs<ListComp>(assignValue('list_if')).generators, isNotEmpty);
    });

    test('Arguments defaults are index-aligned', () {
      // `lambda_expr`'s Arguments has `args: [p]`, `defaults: [null]` and
      // `ty_list: [Int]`. Dropping the positional null would leave an empty
      // list, which is the bug this checks for.
      final l = expectAs<LambdaExpr>(assignValue('lambda_expr'));
      expect(l.args, isNotNull);
      final args = l.args!.node;
      expect(args.args, hasLength(1));
      expect(args.defaults, hasLength(1));
      // The slot is kept but empty — that is the whole point.
      expect(args.defaults.single, isNull);
      expect(args.tyList, hasLength(1));
      expect(args.tyList.single, isNotNull);
      expect(args.tyList.single!.node, isA<BasicType>());
      expect((args.tyList.single!.node as BasicType).name, 'Int');

      // The body is statements, not expressions.
      expect(l.body, isNotEmpty);
      expect(l.body.first.node, isA<ExprStmt>());

      // `lambda_plain` has `args: null` — an absent Option.
      expect(expectAs<LambdaExpr>(assignValue('lambda_plain')).args, isNull);
    });

    test('NumberLitValue tag+content', () {
      // `NumberLitValue` is tag+content, so the tag is the only thing telling
      // an int payload from a float one.
      final i = expectAs<NumberLit>(assignValue('lit_int'));
      expect(i.valueTag, 'Int');
      expect(i.value, isA<int>());
      expect(i.binarySuffix, isNull);

      final f = expectAs<NumberLit>(assignValue('lit_float'));
      expect(f.valueTag, 'Float');
      expect(f.value, isNot(0));

      expect(assignValue('lit_name'), isA<NameConstantLit>());
    });

    test('StringLit, JoinedString and format_spec', () {
      final str = expectAs<StringLit>(assignValue('lit_str'));
      expect(str.value, isNotEmpty);
      expect(str.rawValue, isNotEmpty);

      expect(expectAs<StringLit>(assignValue('lit_long')).isLongString, isTrue);

      // The field is `format_spec`, not `spec`. An f-string interleaves plain
      // `StringLit` segments with the interpolations, so the
      // `FormattedValue` is not necessarily the first element.
      final j = expectAs<JoinedString>(assignValue('joined'));
      expect(j.rawValue, isNotEmpty);
      expect(j.values.length, greaterThan(1));
      expect(j.values.first.node, isA<StringLit>());
      final fvs = j.values
          .map((n) => n.node)
          .whereType<FormattedValue>()
          .toList();
      expect(fvs, hasLength(1));
      expect(fvs.single.value?.node, isA<IdentifierExpr>());
      // The fixture interpolates without a width, so the spec is present as a
      // key but null — the field exists either way.
      expect(fvs.single.formatSpec, isNull);
    });

    test('Target.paths MemberOrIndex', () {
      // `Target.paths` is a bare `Vec<MemberOrIndex>` — no NodeRef, so no
      // position on the element itself.
      var sawPaths = false, sawMember = false, sawIndex = false;
      for (final ref in golden.body) {
        final s = ref.node;
        if (s is! AssignStmt) continue;
        for (final t in s.targets) {
          if (t.node.paths.isEmpty) continue;
          sawPaths = true;
          // `pkgpath` is a single string, not a list.
          expect(t.node.pkgpath, isNotNull);
          for (final p in t.node.paths) {
            if (p is Member) {
              sawMember = true;
              // The payload is a `NodeRef<String>`, so it carries its own
              // position.
              expect(p.member.node, isNotEmpty);
              expect(p.member.pos, isNotNull);
            } else if (p is Index) {
              sawIndex = true;
              expect(p.index.node, isNotNull);
            }
          }
        }
      }
      expect(sawPaths, isTrue, reason: 'no assignment carries a path target');
      expect(sawMember, isTrue, reason: 'no Member path in the fixture');
      expect(sawIndex, isTrue, reason: 'no Index path in the fixture');
    });

    test('StarredExpr ctx and the missing-expression placeholder', () {
      // `StarredExpr.ctx` is `ExprContext`, which has Load and Store — there
      // is no `Del`.
      var e = assignValue('starred');
      expect(e, isNotNull);
      if (e is ListExpr) {
        expect(e.elts, isNotEmpty);
        e = e.elts.first.node;
      }
      expect(const {'Load', 'Store'}, contains(expectAs<StarredExpr>(e).ctx));

      // The parser substitutes a placeholder `Identifier` for a missing
      // expression, so this decodes as an Identifier with a name rather than
      // as `Expr::Missing`.
      expect(expectAs<IdentifierExpr>(assignValue('missing_expr')).identifier.name,
          isNotEmpty);
    });

    test('Type is adjacently tagged', () {
      // `Type` is `#[serde(tag = "type", content = "value")]`. `Any` is the
      // only unit variant, so it has no `value` at all — a decoder that
      // hunted for one would land on the payload union by accident.
      final any = aliasType('TAny');
      expect(any, isA<AnyType>());
      expect(any, isNot(isA<BasicType>()));

      // `Basic` carries a bare string, not an object.
      expect(const {'Bool', 'Int', 'Float', 'Str'},
          contains(expectAs<BasicType>(aliasType('TBasic')).name));

      // `Named` inlines the Identifier newtype.
      expect(expectAs<NamedType>(aliasType('TNamed')).identifier.name, 'Cloud');

      // List / Dict / Union nest under `inner_type` / `key_type` /
      // `type_elements` (not `types`).
      expect(expectAs<ListType>(aliasType('TList')).innerType, isNotNull);
      final dict = expectAs<DictType>(aliasType('TDict'));
      expect(dict.keyType, isNotNull);
      expect(dict.valueType, isNotNull);
      expect(expectAs<UnionType>(aliasType('TUnion')).types, hasLength(2));

      // `FunctionType` uses `params_ty` / `ret_ty`, both optional.
      final func = expectAs<FunctionType>(aliasType('TFunc'));
      expect(func.paramsTy, isNotEmpty);
      expect(func.retTy, isNotNull);

      // `LiteralType` is itself tag+content, so `Type::Literal`'s value is a
      // *second* tagged document. `LiteralType.value` keeps that document
      // verbatim — it has four different shapes — so the inner payload is one
      // level further down than it looks.
      final litInt = expectAs<LiteralType>(aliasType('TLitInt'));
      expect(litInt.innerTag, 'Int');
      // `IntLiteralType { value, suffix }` — a third level of tagging, and the
      // value is an int rather than a string.
      expect(((litInt.value! as Map)['value'] as Map)['value'], 1);

      final litStr = expectAs<LiteralType>(aliasType('TLitStr'));
      expect(litStr.innerTag, 'Str');
      expect((litStr.value! as Map)['value'], isA<String>());

      final litBool = expectAs<LiteralType>(aliasType('TLitBool'));
      expect(litBool.innerTag, 'Bool');
      expect((litBool.value! as Map)['value'], isTrue);

      final litFloat = expectAs<LiteralType>(aliasType('TLitFloat'));
      expect(litFloat.innerTag, 'Float');
      expect((litFloat.value! as Map)['value'], isNot(0));

      // `TypeAliasStmt` names its fields `type_name` / `type_value`.
      expect(aliasNamed('TAny')!.typeValue, isNotNull);
    });

    test('every tag in the golden capture resolves', () {
      final unknown = unresolvedTags();
      for (final t in unknown) {
        print('    unresolved tag: $t');
      }
      expect(unknown, isEmpty);
    });

    test('an unknown tag still degrades to a readable node', () {
      // The escape hatch the previous test polices: a genuinely new variant
      // must not throw, it must produce something a caller can switch on.
      const e = UnknownExpr('BrandNewVariant', {});
      expect(e.tag, 'BrandNewVariant');
      expect(e.toString(), contains('BrandNewVariant'));

      const s = UnknownStmt('BrandNewStmt', {});
      expect(s.tag, 'BrandNewStmt');

      const t = UnknownType('BrandNewType');
      expect(t.tag, 'BrandNewType');
    });

    test('the sealed hierarchies are exhaustively switchable', () {
      // `KclExpr`, `KclStmt` and `AstType` are sealed, so a `switch` with no
      // `default` compiles only if this package models every variant the Rust
      // enums declare. If a variant is ever added here without a matching
      // arm, this stops compiling — which is the point.
      String describeExpr(KclExpr e) {
        switch (e) {
          case TargetExpr():
          case IdentifierExpr():
          case UnaryExpr():
          case BinaryExpr():
          case IfExpr():
          case SelectorExpr():
          case CallExpr():
          case ParenExpr():
          case QuantExpr():
          case ListExpr():
          case ListIfItemExpr():
          case ListComp():
          case StarredExpr():
          case DictComp():
          case ConfigIfEntryExpr():
          case CompClause():
          case SchemaExpr():
          case ConfigExpr():
          case CheckExpr():
          case LambdaExpr():
          case Subscript():
          case KeywordExpr():
          case ArgumentsExpr():
          case Compare():
          case NumberLit():
          case StringLit():
          case NameConstantLit():
          case JoinedString():
          case FormattedValue():
          case MissingExpr():
          case UnknownExpr():
            return e.tag;
        }
      }

      String describeStmt(KclStmt s) {
        switch (s) {
          case TypeAliasStmt():
          case ExprStmt():
          case UnificationStmt():
          case AssignStmt():
          case AugAssignStmt():
          case AssertStmt():
          case IfStmt():
          case ImportStmt():
          case SchemaAttr():
          case SchemaStmt():
          case RuleStmt():
          case UnknownStmt():
            return s.tag;
        }
      }

      String describeType(AstType t) {
        switch (t) {
          case AnyType():
          case BasicType():
          case NamedType():
          case ListType():
          case DictType():
          case UnionType():
          case LiteralType():
          case FunctionType():
          case UnknownType():
            return t.tag;
        }
      }

      // 30 Expr variants, 11 Stmt variants, 9 Type variants (8 Rust variants
      // plus the Unknown escape hatch).
      expect(describeExpr(const MissingExpr()), 'Missing');
      expect(describeStmt(const ExprStmt()), 'Expr');
      expect(describeType(const AnyType()), 'Any');
    });
  });
}

// dto.dart — The plain structs the AST nests inside `NodeRef<T>`.
//
// Every type here is a bare Rust struct with no `#[serde(tag = "type")]` of
// its own, so the parser emits it without a discriminator. That is the reason
// this layer exists separately from `expr.dart`: the `Expr` enum is tagged, but
// `SchemaStmt.decorators` holds a `CallExpr`, `AssignStmt.targets` holds a
// `Target`, and so on — the same payload, minus the tag.
//
// This is the same split the C, C++, Java, Kotlin, Node.js, .NET, WASM, Lua,
// Swift, Zig and Python bindings use. See the "flat DTO" note in each of
// their `dto` modules.

import 'base.dart';
import 'expr.dart';
import 'types.dart';

/// `ast::Identifier` — a dotted name plus how it is being used.
///
/// `ctx` is `ast::ExprContext`, serialized as the bare string `"Load"` or
/// `"Store"`.
class Identifier {
  const Identifier({
    this.names = const [],
    this.pkgpath = '',
    this.ctx = '',
  });

  factory Identifier.fromWire(Map<String, Object?> w) => Identifier(
        names: stringNodeListOf(w['names']),
        pkgpath: strOf(w, 'pkgpath'),
        ctx: strOf(w, 'ctx'),
      );

  final List<Node<String>> names;
  final String pkgpath;

  /// `"Load"` on the right of `=`, `"Store"` on the left.
  final String ctx;

  /// The identifier as it would be written in source, e.g. `a.b.c`.
  String get name => names.map((n) => n.node).join('.');

  @override
  String toString() => 'Identifier($name)';
}

// ---------------------------------------------------------------------------
// MemberOrIndex — `a.b` / `a[0]`
// ---------------------------------------------------------------------------

/// `ast::MemberOrIndex` — declared `#[serde(tag = "type", content = "value")]`,
/// so it *is* tagged even though the variants hold a `NodeRef`.
sealed class MemberOrIndex {
  const MemberOrIndex();
}

/// `a.b` — the member is a bare string node.
class Member extends MemberOrIndex {
  const Member(this.member);

  final Node<String> member;

  @override
  String toString() => 'Member(${member.node})';
}

/// `a[0]` — the index is an expression node.
class Index extends MemberOrIndex {
  const Index(this.index);

  final Node<KclExpr> index;

  @override
  String toString() => 'Index(${index.node})';
}

MemberOrIndex memberOrIndexFromWire(Map<String, Object?> w) {
  final value = w['value'];
  switch (w['type']) {
    case 'Member':
      return Member(
          stringNode(value) ?? const Node<String>(''));
    case 'Index':
      return Index(nodeOf<KclExpr>(value, exprFromWire) ??
          const Node<KclExpr>(MissingExpr()));
    default:
      return const Member(Node<String>(''));
  }
}

// ---------------------------------------------------------------------------
// Target — `a.b.c` on the left of an assignment
// ---------------------------------------------------------------------------

/// `ast::Target`.
class Target {
  const Target({this.name, this.paths = const [], this.pkgpath = ''});

  factory Target.fromWire(Map<String, Object?> w) => Target(
        name: stringNode(w['name']),
        paths: plainListOf<MemberOrIndex>(w['paths'], memberOrIndexFromWire),
        pkgpath: strOf(w, 'pkgpath'),
      );

  final Node<String>? name;
  final List<MemberOrIndex> paths;
  final String pkgpath;

  @override
  String toString() => 'Target(${name?.node}$paths)';
}

// ---------------------------------------------------------------------------
// Keyword / Arguments / ConfigEntry
// ---------------------------------------------------------------------------

/// `ast::Keyword` — `arg = value` in a call or a schema instantiation.
///
/// `arg` is a `NodeRef<Identifier>`, not an expression, so a keyword argument
/// can never be a keyword *expression* here.
class Keyword {
  const Keyword({this.arg, this.value});

  factory Keyword.fromWire(Map<String, Object?> w) => Keyword(
        arg: nodeOf<Identifier>(w['arg'], Identifier.fromWire),
        value: nodeOf<KclExpr>(w['value'], exprFromWire),
      );

  final Node<Identifier>? arg;
  final Node<KclExpr>? value;

  @override
  String toString() => 'Keyword(${arg?.node}, ${value?.node})';
}

/// `ast::Arguments` — a parameter list.
///
/// `defaults` and `ty_list` are `Vec<Option<...>>`, so they are the same
/// length as [args] with a `null` for every parameter that has no default and
/// no annotation. Both lists keep their nulls for that reason.
class Arguments {
  const Arguments({this.args = const [], this.defaults = const [], this.tyList = const []});

  factory Arguments.fromWire(Map<String, Object?> w) => Arguments(
        args: nodeListOf<Identifier>(w['args'], Identifier.fromWire),
        defaults: nullableNodeListOf<KclExpr>(w['defaults'], exprFromWire),
        tyList: nullableNodeListOf<AstType>(w['ty_list'], typeFromWire),
      );

  final List<Node<Identifier>> args;
  final List<Node<KclExpr>?> defaults;
  final List<Node<AstType>?> tyList;

  /// The number of declared parameters.
  int get length => args.length;

  @override
  String toString() => 'Arguments($args)';
}

/// `ast::ConfigEntry` — one `key = value` pair inside a config expression.
class ConfigEntry {
  const ConfigEntry({this.key, this.value, this.operation = '', this.isShorthand = false});

  factory ConfigEntry.fromWire(Map<String, Object?> w) => ConfigEntry(
        key: nodeOf<KclExpr>(w['key'], exprFromWire),
        value: nodeOf<KclExpr>(w['value'], exprFromWire),
        operation: strOf(w, 'operation'),
        isShorthand: flagOf(w, 'is_shorthand'),
      );

  final Node<KclExpr>? key;
  final Node<KclExpr>? value;

  /// `"Union"` or `"Override"`.
  final String operation;

  /// `true` for the ES6-style `{name}` shorthand, which is equivalent to
  /// `name = name`. The parser omits the field when false
  /// (`skip_serializing_if = "is_false"`).
  final bool isShorthand;

  @override
  String toString() =>
      'ConfigEntry(${key?.node} $operation ${value?.node}${isShorthand ? ' (shorthand)' : ''})';
}

// `CheckExpr` is *not* here even though the wire object it decodes is an
// untagged struct. It is a variant of the `Expr` enum as well — a schema
// `check:` body is `Vec<NodeRef<CheckExpr>>` and `Expr::Check` is the tagged
// form of the same thing — so it has to live in `expr.dart`, where `KclExpr`
// is declared. `sealed` restricts a subtype to the library that declares it,
// which a cross-file subclass is not.

// ---------------------------------------------------------------------------
// SchemaIndexSignature — `[str]: int`
// ---------------------------------------------------------------------------

/// `ast::SchemaIndexSignature`.
class SchemaIndexSignature {
  const SchemaIndexSignature({
    this.keyName,
    this.value,
    this.anyOther = false,
    this.keyTy,
    this.valueTy,
  });

  factory SchemaIndexSignature.fromWire(Map<String, Object?> w) =>
      SchemaIndexSignature(
        keyName: stringNode(w['key_name']),
        value: nodeOf<KclExpr>(w['value'], exprFromWire),
        anyOther: flagOf(w, 'any_other'),
        keyTy: nodeOf<AstType>(w['key_ty'], typeFromWire),
        valueTy: nodeOf<AstType>(w['value_ty'], typeFromWire),
      );

  final Node<String>? keyName;
  final Node<KclExpr>? value;
  final bool anyOther;
  final Node<AstType>? keyTy;
  final Node<AstType>? valueTy;

  @override
  String toString() => 'SchemaIndexSignature($keyName: $keyTy = $valueTy)';
}

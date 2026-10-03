// stmt.dart — The statement hierarchy. Mirrors `ast::Stmt` in
// `../kcl/crates/ast/src/ast.rs`.
//
// `Stmt` is `#[serde(tag = "type")]`, so every statement node carries a `type`
// discriminator and [stmtFromWire] dispatches on it. Sealed, so a `switch`
// over a [KclStmt] is exhaustive.

import 'base.dart';
import 'dto.dart';
import 'expr.dart';
import 'types.dart';

/// A statement.
sealed class KclStmt {
  const KclStmt();

  /// The `type` tag the parser emitted.
  String get tag;
}

/// `ast::Stmt::TypeAlias` — `type StrOrInt = str | int`.
class TypeAliasStmt extends KclStmt {
  const TypeAliasStmt({this.typeName, this.typeValue, this.ty});

  final Node<Identifier>? typeName;
  final Node<String>? typeValue;
  final Node<AstType>? ty;

  @override
  String get tag => 'TypeAlias';

  @override
  String toString() => 'TypeAliasStmt(${typeName?.node.name} = ${typeValue?.node})';
}

/// `ast::Stmt::Expr` — a bare expression statement.
class ExprStmt extends KclStmt {
  const ExprStmt({this.exprs = const []});

  final List<Node<KclExpr>> exprs;

  @override
  String get tag => 'Expr';

  @override
  String toString() => 'ExprStmt($exprs)';
}

/// `ast::Stmt::Unification` — the `Name { ... }` form inside a schema body.
///
/// [UnificationStmt.target] is a `NodeRef<Identifier>` and the value is a
/// `NodeRef<SchemaExpr>`, not a generic expression. It is spelled [SchemaConfig]
/// here — Java's name for the same payload — because that is the one form
/// whose wire object carries no `type` key: `{"args": …, "config": …,
/// "kwargs": …, "name": …}` and nothing else, so a `switch` over the tree
/// cannot confuse it with an `Expr::Schema`.
class UnificationStmt extends KclStmt {
  const UnificationStmt({this.target, this.value});

  final Node<Identifier>? target;
  final Node<SchemaConfig>? value;

  @override
  String get tag => 'Unification';

  @override
  String toString() => 'UnificationStmt(${target?.node.name} ${value?.node})';
}

/// `ast::Stmt::Assign` — `a = expr` or `a: expr`.
class AssignStmt extends KclStmt {
  const AssignStmt({this.targets = const [], this.value, this.ty});

  final List<Node<Target>> targets;
  final Node<KclExpr>? value;
  final Node<AstType>? ty;

  @override
  String get tag => 'Assign';

  @override
  String toString() => 'AssignStmt('
      '${targets.map((t) => t.node.name?.node).join(', ')} = ${value?.node})';
}

/// `ast::Stmt::AugAssign` — `a += 1`.
class AugAssignStmt extends KclStmt {
  const AugAssignStmt({this.target, this.value, this.op = ''});

  final Node<Target>? target;
  final Node<KclExpr>? value;

  /// `"Assign"`, `"Add"`, `"Sub"`, `"Mul"`, `"Div"`, `"Mod"`, `"Pow"`,
  /// `"FloorDiv"`, `"LShift"`, `"RShift"`, `"BitXor"`, `"BitAnd"`,
  /// `"BitOr"`. `Assign` is first because it is what `=` itself maps to.
  final String op;

  @override
  String get tag => 'AugAssign';

  @override
  String toString() => 'AugAssignStmt(${target?.node} $op= ${value?.node})';
}

/// `ast::Stmt::Assert` — `assert test, "message"`.
class AssertStmt extends KclStmt {
  const AssertStmt({this.test, this.ifCond, this.msg});

  final Node<KclExpr>? test;
  final Node<KclExpr>? ifCond;
  final Node<KclExpr>? msg;

  @override
  String get tag => 'Assert';

  @override
  String toString() => 'AssertStmt(${test?.node}, ${msg?.node})';
}

/// `ast::Stmt::If` — `if cond: ... else: ...`.
class IfStmt extends KclStmt {
  const IfStmt({this.body = const [], this.cond, this.orelse = const []});

  final List<Node<KclStmt>> body;
  final Node<KclExpr>? cond;
  final List<Node<KclStmt>> orelse;

  @override
  String get tag => 'If';

  @override
  String toString() => 'IfStmt($body if ${cond?.node} else $orelse)';
}

/// `ast::Stmt::Import` — `import a.b.c as d`.
///
/// [ImportStmt.path] and [ImportStmt.asName] are `Node<String>`, so they carry
/// their own position; [ImportStmt.rawpath], [ImportStmt.name] and
/// [ImportStmt.pkgName] are plain strings on the same node.
class ImportStmt extends KclStmt {
  const ImportStmt({
    this.path,
    this.rawpath = '',
    this.name = '',
    this.asName,
    this.pkgName = '',
  });

  /// The dotted path, e.g. `data.cloud`.
  final Node<String>? path;

  /// The path exactly as written.
  final String rawpath;

  /// The last segment, e.g. `cloud` for `data.cloud`.
  final String name;

  /// The `as` alias, or null.
  final Node<String>? asName;

  /// `__main__` for builtin/plugin imports, otherwise the package name.
  final String pkgName;

  @override
  String get tag => 'Import';

  @override
  String toString() => 'ImportStmt($rawpath as ${asName?.node}, $pkgName)';
}

/// `ast::Stmt::SchemaAttr` — one attribute inside a schema body.
///
/// [SchemaAttr.ty] is a non-optional `NodeRef<Type>` in Rust; it is optional
/// here only so a malformed tree cannot throw.
class SchemaAttr extends KclStmt {
  const SchemaAttr({
    this.doc = '',
    this.name,
    this.op,
    this.value,
    this.isOptional = false,
    this.decorators = const [],
    this.ty,
  });

  /// The `"""..."""` docstring, unquoted. A plain string, not a node.
  final String doc;
  final Node<String>? name;

  /// The `+=`/`-=` operator, or null for a plain `:` or `=`.
  final String? op;
  final Node<KclExpr>? value;

  /// `true` for `name?: T`.
  final bool isOptional;
  final List<Node<Decorator>> decorators;
  final Node<AstType>? ty;

  @override
  String get tag => 'SchemaAttr';

  @override
  String toString() =>
      'SchemaAttr(${name?.node}${isOptional ? '?' : ''}: ${ty?.node} = ${value?.node})';
}

/// `ast::Stmt::Schema` — `schema`, `protocol` and `mixin` all land here.
class SchemaStmt extends KclStmt {
  const SchemaStmt({
    this.doc,
    this.name,
    this.parentName,
    this.forHostName,
    this.isMixin = false,
    this.isProtocol = false,
    this.args,
    this.mixins = const [],
    this.body = const [],
    this.decorators = const [],
    this.checks = const [],
    this.indexSignature,
  });

  final Node<String>? doc;
  final Node<String>? name;
  final Node<Identifier>? parentName;
  final Node<Identifier>? forHostName;

  /// `true` for a `mixin` declaration.
  final bool isMixin;

  /// `true` for a `protocol` declaration.
  final bool isProtocol;
  final Node<Arguments>? args;
  final List<Node<Identifier>> mixins;
  final List<Node<KclStmt>> body;
  final List<Node<Decorator>> decorators;
  final List<Node<CheckExpr>> checks;
  final Node<SchemaIndexSignature>? indexSignature;

  @override
  String get tag => 'Schema';

  @override
  String toString() =>
      'SchemaStmt($isMixin$isProtocol ${name?.node} : $body)';
}

/// `ast::Stmt::Rule` — `rule Name: ...`.
class RuleStmt extends KclStmt {
  const RuleStmt({
    this.doc,
    this.name,
    this.parentRules = const [],
    this.decorators = const [],
    this.checks = const [],
    this.args,
    this.forHostName,
  });

  final Node<String>? doc;
  final Node<String>? name;
  final List<Node<Identifier>> parentRules;
  final List<Node<Decorator>> decorators;
  final List<Node<CheckExpr>> checks;
  final Node<Arguments>? args;
  final Node<Identifier>? forHostName;

  @override
  String get tag => 'Rule';

  @override
  String toString() => 'RuleStmt(${name?.node}: $checks)';
}

/// A `type` tag this package does not know about.
///
/// **A divergence from the Java binding, on purpose** — see [UnknownExpr].
/// Java's `Stmt` is deserialised through `@JsonSubTypes` and an unregistered
/// tag raises; a `switch` here has a default arm instead, so a KCL file using
/// syntax a newer `libkcl` adds stays traversable and the tag is on [variant].
class UnknownStmt extends KclStmt {
  const UnknownStmt(this.variant, this.raw);

  final String variant;
  final Map<String, Object?> raw;

  @override
  String get tag => variant;

  @override
  String toString() => 'UnknownStmt($variant)';
}

/// See [exprNodeOf].
SchemaExpr? asSchemaExpr(KclExpr e) => e is SchemaExpr ? e : null;

/// Decode the payload of a `NodeRef<Stmt>`.
KclStmt stmtFromWire(Map<String, Object?> w) {
  final variant = w['type'];
  if (variant is! String) {
    return const ExprStmt();
  }
  switch (variant) {
    case 'TypeAlias':
      return TypeAliasStmt(
        typeName: nodeOf<Identifier>(w['type_name'], Identifier.fromWire),
        typeValue: stringNode(w['type_value']),
        ty: nodeOf<AstType>(w['ty'], typeFromWire),
      );
    case 'Expr':
      return ExprStmt(exprs: nodeListOf<KclExpr>(w['exprs'], exprFromWire));
    case 'Unification':
      // `value` is a `NodeRef<SchemaConfig>` (Rust spells the struct
      // `SchemaExpr`; only the *tagged* form is an `Expr`), so the payload has
      // no `type` key — it must go through the untagged decoder, not
      // `exprFromWire`, which would answer `MissingExpr`.
      return UnificationStmt(
        target: nodeOf<Identifier>(w['target'], Identifier.fromWire),
        value: nodeOf<SchemaConfig>(w['value'], schemaExprFromWire),
      );
    case 'Assign':
      return AssignStmt(
        targets: nodeListOf<Target>(w['targets'], Target.fromWire),
        value: nodeOf<KclExpr>(w['value'], exprFromWire),
        ty: nodeOf<AstType>(w['ty'], typeFromWire),
      );
    case 'AugAssign':
      return AugAssignStmt(
        target: nodeOf<Target>(w['target'], Target.fromWire),
        value: nodeOf<KclExpr>(w['value'], exprFromWire),
        op: strOf(w, 'op'),
      );
    case 'Assert':
      return AssertStmt(
        test: nodeOf<KclExpr>(w['test'], exprFromWire),
        ifCond: nodeOf<KclExpr>(w['if_cond'], exprFromWire),
        msg: nodeOf<KclExpr>(w['msg'], exprFromWire),
      );
    case 'If':
      return IfStmt(
        body: nodeListOf<KclStmt>(w['body'], stmtFromWire),
        cond: nodeOf<KclExpr>(w['cond'], exprFromWire),
        orelse: nodeListOf<KclStmt>(w['orelse'], stmtFromWire),
      );
    case 'Import':
      return ImportStmt(
        path: stringNode(w['path']),
        rawpath: strOf(w, 'rawpath'),
        name: strOf(w, 'name'),
        asName: stringNode(w['asname']),
        pkgName: strOf(w, 'pkg_name'),
      );
    case 'SchemaAttr':
      return SchemaAttr(
        doc: strOf(w, 'doc'),
        name: stringNode(w['name']),
        op: w['op'] as String?,
        value: nodeOf<KclExpr>(w['value'], exprFromWire),
        isOptional: flagOf(w, 'is_optional'),
        decorators: nodeListOf<Decorator>(w['decorators'], callExprFromWire),
        ty: nodeOf<AstType>(w['ty'], typeFromWire),
      );
    case 'Schema':
      return SchemaStmt(
        doc: stringNode(w['doc']),
        name: stringNode(w['name']),
        parentName: nodeOf<Identifier>(w['parent_name'], Identifier.fromWire),
        forHostName: nodeOf<Identifier>(w['for_host_name'], Identifier.fromWire),
        isMixin: flagOf(w, 'is_mixin'),
        isProtocol: flagOf(w, 'is_protocol'),
        args: nodeOf<Arguments>(w['args'], Arguments.fromWire),
        mixins: nodeListOf<Identifier>(w['mixins'], Identifier.fromWire),
        body: nodeListOf<KclStmt>(w['body'], stmtFromWire),
        decorators: nodeListOf<Decorator>(w['decorators'], callExprFromWire),
        checks: nodeListOf<CheckExpr>(w['checks'], CheckExpr.fromWire),
        indexSignature: nodeOf<SchemaIndexSignature>(
            w['index_signature'], SchemaIndexSignature.fromWire),
      );
    case 'Rule':
      return RuleStmt(
        doc: stringNode(w['doc']),
        name: stringNode(w['name']),
        parentRules: nodeListOf<Identifier>(w['parent_rules'], Identifier.fromWire),
        decorators: nodeListOf<Decorator>(w['decorators'], callExprFromWire),
        checks: nodeListOf<CheckExpr>(w['checks'], CheckExpr.fromWire),
        args: nodeOf<Arguments>(w['args'], Arguments.fromWire),
        forHostName: nodeOf<Identifier>(w['for_host_name'], Identifier.fromWire),
      );
    default:
      return UnknownStmt(variant, w);
  }
}

/// Decode an *untagged* `CallExpr` — that is, a [Decorator].
///
/// `SchemaAttr.decorators`, `SchemaStmt.decorators` and `RuleStmt.decorators`
/// are all `Vec<NodeRef<CallExpr>>`, and only the `Expr` enum is tagged, so a
/// decorator arrives as a bare `{args, func, keywords}` with no `type` key —
/// the same three fields an `Expr::Call` carries, minus the discriminator.
/// The return type is spelled [Decorator] to say which of the two spellings
/// the caller is holding; the two names are one type (see [Decorator]).
CallExpr callExprFromWire(Map<String, Object?> w) => CallExpr(
      func: nodeOf<KclExpr>(w['func'], exprFromWire),
      args: nodeListOf<KclExpr>(w['args'], exprFromWire),
      keywords: nodeListOf<Keyword>(w['keywords'], Keyword.fromWire),
    );

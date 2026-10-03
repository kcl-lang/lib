// expr.dart — The expression hierarchy. Mirrors `ast::Expr` in
// `../kcl/crates/ast/src/ast.rs`.
//
// `Expr` is `#[serde(tag = "type")]`, so every expression node on the wire
// carries a `type` discriminator and [exprFromWire] dispatches on it. Each
// variant is a separate class here rather than a single record with an
// optional bag of fields, so a `switch` over a [KclExpr] is exhaustive.
//
// Note the asymmetry the parser produces: a variant that appears as a *bare*
// struct elsewhere in the tree (`CallExpr` under `SchemaStmt.decorators`,
// `Keyword`, `Arguments`, `CheckExpr`) is untagged there, but tagged when it
// is reached through the `Expr` enum. Both shapes decode through this file,
// and for the three that are used both ways there is one class under two
// names — [Decorator] for a `CallExpr` that is a decorator, [SchemaConfig]
// for a `SchemaExpr` that is a unification value, and [CheckExpr], which
// needs no second name because the payload is identical either way.

import 'base.dart';
import 'dto.dart';
import 'stmt.dart';
import 'types.dart';

/// Decode a single `NodeRef<Expr>` narrowed to one variant — e.g.
/// `UnificationStmt.value`, which Rust types as `NodeRef<SchemaExpr>` rather
/// than `NodeRef<Expr>`.
Node<T>? exprNodeOf<T extends KclExpr>(Object? w, T? Function(KclExpr) select) {
  final n = nodeOf<KclExpr>(w, exprFromWire);
  if (n == null) return null;
  final picked = select(n.node);
  return picked == null ? null : Node<T>(picked, n.pos);
}

/// An expression. Sealed so a `switch` over it is checked at compile time.
sealed class KclExpr {
  const KclExpr();

  /// The `type` tag the parser emitted, for round-tripping back to source.
  String get tag;
}

/// `ast::Expr::Target`.
class TargetExpr extends KclExpr {
  const TargetExpr(this.target);

  final Target target;

  @override
  String get tag => 'Target';

  @override
  String toString() => 'TargetExpr($target)';
}

/// `ast::Expr::Identifier`.
class IdentifierExpr extends KclExpr {
  const IdentifierExpr(this.identifier);

  final Identifier identifier;

  @override
  String get tag => 'Identifier';

  @override
  String toString() => 'IdentifierExpr(${identifier.name})';
}

/// `ast::Expr::Unary`.
class UnaryExpr extends KclExpr {
  const UnaryExpr({this.op = '', this.operand});

  /// `"UAdd"` for `+a`, `"USub"` for `-a`, `"Invert"` for `~a`, `"Not"` for
  /// `not a`. The Rust enum spells the arithmetic pair with a `U` prefix to
  /// distinguish them from the *unsigned* suffix; there is no bare `Sub`.
  final String op;
  final Node<KclExpr>? operand;

  @override
  String get tag => 'Unary';

  @override
  String toString() => 'UnaryExpr($op ${operand?.node})';
}

/// `ast::Expr::Binary`.
class BinaryExpr extends KclExpr {
  const BinaryExpr({this.left, this.op = '', this.right});

  final Node<KclExpr>? left;

  /// `"Add"`, `"Sub"`, `"Mul"`, `"Div"`, `"Mod"`, `"Pow"`, `"FloorDiv"`,
  /// `"LShift"`, `"RShift"`, `"BitXor"`, `"BitAnd"`, `"BitOr"`, `"And"`,
  /// `"Or"`, `"As"`. Note the shifts are `LShift`/`RShift`, not
  /// `LeftShift`/`RightShift`.
  final String op;
  final Node<KclExpr>? right;

  @override
  String get tag => 'Binary';

  @override
  String toString() => 'BinaryExpr(${left?.node} $op ${right?.node})';
}

/// `ast::Expr::If` — the conditional expression, `a if cond else b`.
class IfExpr extends KclExpr {
  const IfExpr({this.body, this.cond, this.orelse});

  final Node<KclExpr>? body;
  final Node<KclExpr>? cond;
  final Node<KclExpr>? orelse;

  @override
  String get tag => 'If';

  @override
  String toString() => 'IfExpr(${body?.node} if ${cond?.node} else ${orelse?.node})';
}

/// `ast::Expr::Selector` — `a.b` or `a?.b`.
///
/// [SelectorExpr.attr] is a `NodeRef<Identifier>`, not an expression.
class SelectorExpr extends KclExpr {
  const SelectorExpr({this.value, this.attr, this.ctx = '', this.hasQuestion = false});

  final Node<KclExpr>? value;
  final Node<Identifier>? attr;
  final String ctx;

  /// `true` for the `?.` form.
  final bool hasQuestion;

  @override
  String get tag => 'Selector';

  @override
  String toString() => 'SelectorExpr(${value?.node}.${attr?.node.name}${hasQuestion ? '?' : ''})';
}

/// `ast::Expr::Call` — `f(x)`.
class CallExpr extends KclExpr {
  const CallExpr({this.func, this.args = const [], this.keywords = const []});

  final Node<KclExpr>? func;
  final List<Node<KclExpr>> args;
  final List<Node<Keyword>> keywords;

  @override
  String get tag => 'Call';

  @override
  String toString() => 'CallExpr(${func?.node}($args, $keywords))';
}

/// The name Java gives the payload of `SchemaAttr.decorators`,
/// `SchemaStmt.decorators` and `RuleStmt.decorators`.
///
/// Rust types all three decorator fields as `Vec<NodeRef<CallExpr>>`, and the
/// object on the wire is byte-for-byte the one an `Expr::Call` decodes to —
/// three keys, `args` / `func` / `keywords`, and no `type` key. Java cannot
/// reuse its `CallExpr` for them because Jackson hands that class the `Expr`
/// subtype table and an untagged read would be ambiguous, so it declares a
/// second class with the same three fields. Dart's decoders are hand-written
/// and dispatch on the tag themselves, so there is nothing to disambiguate:
/// one class, and this is its second name.
///
/// That makes `SchemaAttr.decorators` readable as Java spells it while the
/// payload stays a single type, and a decorator is still usable anywhere a
/// [CallExpr] is:
///
/// ```dart
/// for (final d in attr.decorators) {
///   d.node.func;        // a Decorator, i.e. a CallExpr
///   final c = d.node as CallExpr;   // the same object, the Expr spelling
/// }
/// ```
typedef Decorator = CallExpr;

/// `ast::Expr::Paren`.
class ParenExpr extends KclExpr {
  const ParenExpr({this.expr});

  final Node<KclExpr>? expr;

  @override
  String get tag => 'Paren';

  @override
  String toString() => 'ParenExpr(${expr?.node})';
}

/// `ast::Expr::Quant` — `all x in xs { ... }`.
class QuantExpr extends KclExpr {
  const QuantExpr({this.target, this.variables = const [], this.op = '', this.test, this.ifCond, this.ctx = ''});

  final Node<KclExpr>? target;
  final List<Node<Identifier>> variables;

  /// `"All"`, `"Any"`, `"Filter"` or `"Map"`.
  final String op;
  final Node<KclExpr>? test;
  final Node<KclExpr>? ifCond;
  final String ctx;

  @override
  String get tag => 'Quant';

  @override
  String toString() => 'QuantExpr($op ${variables.map((v) => v.node.name).join(', ')} in ${target?.node})';
}

/// `ast::Expr::List`.
class ListExpr extends KclExpr {
  const ListExpr({this.elts = const [], this.ctx = ''});

  final List<Node<KclExpr>> elts;
  final String ctx;

  @override
  String get tag => 'List';

  @override
  String toString() => 'ListExpr($elts)';
}

/// `ast::Expr::ListIfItem` — a conditional branch inside a list literal.
class ListIfItemExpr extends KclExpr {
  const ListIfItemExpr({this.ifCond, this.exprs = const [], this.orelse});

  final Node<KclExpr>? ifCond;
  final List<Node<KclExpr>> exprs;
  final Node<KclExpr>? orelse;

  @override
  String get tag => 'ListIfItem';

  @override
  String toString() => 'ListIfItemExpr($exprs if ${ifCond?.node})';
}

/// `ast::Expr::ListComp` — `[x for x in xs if cond]`.
class ListComp extends KclExpr {
  const ListComp({this.elt, this.generators = const []});

  final Node<KclExpr>? elt;
  final List<Node<CompClause>> generators;

  @override
  String get tag => 'ListComp';

  @override
  String toString() => 'ListComp(${elt?.node} for $generators)';
}

/// `ast::Expr::Starred` — `*a`.
class StarredExpr extends KclExpr {
  const StarredExpr({this.value, this.ctx = ''});

  final Node<KclExpr>? value;
  final String ctx;

  @override
  String get tag => 'Starred';

  @override
  String toString() => 'StarredExpr(*${value?.node})';
}

/// `ast::Expr::DictComp` — `{k: v for ...}`.
///
/// The Rust field is a single `entry: ConfigEntry`, not the
/// `entry_key` / `key` / `value` triple some older bindings modelled.
class DictComp extends KclExpr {
  const DictComp({this.entry, this.generators = const []});

  final ConfigEntry? entry;
  final List<Node<CompClause>> generators;

  @override
  String get tag => 'DictComp';

  @override
  String toString() => 'DictComp($entry for $generators)';
}

/// `ast::Expr::ConfigIfEntry` — a conditional branch inside a config.
class ConfigIfEntryExpr extends KclExpr {
  const ConfigIfEntryExpr({this.ifCond, this.items = const [], this.orelse});

  final Node<KclExpr>? ifCond;

  /// Declared as `Vec<NodeRef<ConfigEntry>>`, so each item carries a position.
  final List<Node<ConfigEntry>> items;
  final Node<KclExpr>? orelse;

  @override
  String get tag => 'ConfigIfEntry';

  @override
  String toString() => 'ConfigIfEntryExpr($items if ${ifCond?.node})';
}

/// `ast::Expr::CompClause` — the `x in xs if cond` half of a comprehension.
class CompClause extends KclExpr {
  const CompClause({this.targets = const [], this.iter, this.ifs = const []});

  final List<Node<Identifier>> targets;
  final Node<KclExpr>? iter;
  final List<Node<KclExpr>> ifs;

  @override
  String get tag => 'CompClause';

  @override
  String toString() =>
      'CompClause(${targets.map((t) => t.node.name).join(', ')} in ${iter?.node} if $ifs)';
}

/// `ast::Expr::Schema` — inline instantiation, `Person { name = "x" }`.
///
/// [SchemaExpr.name] is a `NodeRef<Identifier>`, not an expression.
class SchemaExpr extends KclExpr {
  const SchemaExpr({this.name, this.args = const [], this.kwargs = const [], this.config});

  final Node<Identifier>? name;
  final List<Node<KclExpr>> args;
  final List<Node<Keyword>> kwargs;
  final Node<KclExpr>? config;

  @override
  String get tag => 'Schema';

  @override
  String toString() => 'SchemaExpr(${name?.node.name}($args, $kwargs) ${config?.node})';
}

/// The name Java gives the payload of `UnificationStmt.value`.
///
/// `SchemaStmt.body` mixes in two forms — `Name { attr = 1 }` (a
/// [SchemaExpr] reached through the `Expr` enum, so tagged `"Schema"`) and
/// the unification `Name: {attr = 1}`, which Rust types as
/// `NodeRef<SchemaExpr>` while the object itself carries **no `type` key**.
/// Java calls the untagged one `SchemaConfig` for the same reason it calls
/// the decorator payload `Decorator`: Jackson needs a class the `Expr`
/// subtype table does not own. Here the two are one class under two names, so
/// `UnificationStmt.value` reads as `Node<SchemaConfig>?` and
/// [schemaExprFromWire] — which is the decoder for both — returns whichever
/// name the caller wants to spell.
typedef SchemaConfig = SchemaExpr;

/// `ast::Expr::Config` — a `{ key = value }` block.
class ConfigExpr extends KclExpr {
  const ConfigExpr({this.items = const []});

  final List<Node<ConfigEntry>> items;

  @override
  String get tag => 'Config';

  @override
  String toString() => 'ConfigExpr($items)';
}

/// `ast::CheckExpr` — `test if cond, "message"`.
///
/// One class for both spellings, because the wire object is the same one.
/// `SchemaStmt.checks` and `RuleStmt.checks` are `Vec<NodeRef<CheckExpr>>` and
/// the payload is an untagged `{test, if_cond, msg}` with no `type` key; the
/// `Expr::Check` variant is the tagged form of the same struct, so a `check`
/// reached through the `Expr` enum carries `"type": "Check"` and nothing else
/// changes. Giving the tagged form its own wrapper class — as this package
/// used to, with a `Check` DTO underneath a `CheckExpr` — makes
/// `stmt.checks.first.node.test` a two-hop access for a field that is right
/// there, and it is not what the Java binding does either: Java has a single
/// `CheckExpr` and does not register a `Check` subtype at all.
class CheckExpr extends KclExpr {
  const CheckExpr({this.test, this.ifCond, this.msg});

  /// Decode the payload. Reads the same three keys whether or not the object
  /// arrived through the `Expr` enum, so the tag is simply ignored.
  factory CheckExpr.fromWire(Map<String, Object?> w) => CheckExpr(
        test: nodeOf<KclExpr>(w['test'], exprFromWire),
        ifCond: nodeOf<KclExpr>(w['if_cond'], exprFromWire),
        msg: nodeOf<KclExpr>(w['msg'], exprFromWire),
      );

  final Node<KclExpr>? test;
  final Node<KclExpr>? ifCond;
  final Node<KclExpr>? msg;

  @override
  String get tag => 'Check';

  @override
  String toString() => 'CheckExpr(${test?.node} if ${ifCond?.node}, ${msg?.node})';
}

/// `ast::Expr::Lambda`.
class LambdaExpr extends KclExpr {
  const LambdaExpr({this.args, this.body = const [], this.returnTy});

  final Node<Arguments>? args;

  /// Declared as `Vec<NodeRef<Stmt>>` — lambda bodies hold statements, not
  /// expressions.
  final List<Node<KclStmt>> body;
  final Node<AstType>? returnTy;

  @override
  String get tag => 'Lambda';

  @override
  String toString() => 'LambdaExpr(${args?.node} -> $body)';
}

/// `ast::Expr::Subscript` — `a[0]`, `a[1:2]`, `a[1:2:3]`.
class Subscript extends KclExpr {
  const Subscript({
    this.value,
    this.index,
    this.lower,
    this.upper,
    this.step,
    this.ctx = '',
    this.hasQuestion = false,
  });

  final Node<KclExpr>? value;
  final Node<KclExpr>? index;
  final Node<KclExpr>? lower;
  final Node<KclExpr>? upper;
  final Node<KclExpr>? step;
  final String ctx;
  final bool hasQuestion;

  @override
  String get tag => 'Subscript';

  @override
  String toString() => 'Subscript(${value?.node}[$index:$upper:$step])';
}

/// `ast::Expr::Keyword` — the tagged form of [Keyword].
class KeywordExpr extends KclExpr {
  const KeywordExpr(this.keyword);

  final Keyword keyword;

  @override
  String get tag => 'Keyword';

  @override
  String toString() => 'KeywordExpr($keyword)';
}

/// `ast::Expr::Arguments` — the tagged form of [Arguments].
class ArgumentsExpr extends KclExpr {
  const ArgumentsExpr(this.arguments);

  final Arguments arguments;

  @override
  String get tag => 'Arguments';

  @override
  String toString() => 'ArgumentsExpr($arguments)';
}

/// `ast::Expr::Compare` — a chained comparison such as `0 <= a < 10`.
class Compare extends KclExpr {
  const Compare({this.left, this.ops = const [], this.comparators = const []});

  final Node<KclExpr>? left;

  /// `"Eq"`, `"NotEq"`, `"Lt"`, `"LtE"`, `"Gt"`, `"GtE"`, `"Is"`, `"In"`,
  /// `"NotIn"`, `"Not"`, `"IsNot"`. `Not` is `!=`-as-identity (`not in` vs
  /// `is not`); it is a distinct arm from `NotEq`, which is `!=`.
  final List<String> ops;
  final List<Node<KclExpr>> comparators;

  @override
  String get tag => 'Compare';

  @override
  String toString() => 'Compare(${left?.node} ${ops.join(' ')} $comparators)';
}

/// `ast::Expr::NumberLit`.
///
/// [NumberLit.valueTag] and [NumberLit.value] decode the nested
/// `NumberLitValue`, which is itself tagged `{"type": "Int" | "Float"}`.
class NumberLit extends KclExpr {
  const NumberLit({this.binarySuffix, this.valueTag, this.value});

  /// `"n"`, `"u"`, `"m"`, `"k"`, `"K"`, `"M"`, `"G"`, `"T"`, `"P"`, `"Ki"`,
  /// `"Mi"`, `"Gi"`, `"Ti"`, `"Pi"`, or null.
  final String? binarySuffix;

  /// `"Int"` or `"Float"`.
  final String? valueTag;

  /// The numeric payload, an `int` or a `double`.
  final num? value;

  @override
  String get tag => 'NumberLit';

  @override
  String toString() => 'NumberLit($valueTag $value$binarySuffix)';
}

/// `ast::Expr::StringLit`.
class StringLit extends KclExpr {
  const StringLit({this.isLongString = false, this.rawValue = '""', this.value = ''});

  /// `true` for a `"""..."""` literal.
  final bool isLongString;

  /// The source text, quotes included.
  final String rawValue;

  /// The unquoted value.
  final String value;

  @override
  String get tag => 'StringLit';

  @override
  String toString() => 'StringLit($value)';
}

/// `ast::Expr::NameConstantLit` — `True`, `False` or `Undefined`.
class NameConstantLit extends KclExpr {
  const NameConstantLit({this.value = ''});

  final String value;

  @override
  String get tag => 'NameConstantLit';

  @override
  String toString() => 'NameConstantLit($value)';
}

/// `ast::Expr::JoinedString` — an f-string, `"a${b}c"`.
class JoinedString extends KclExpr {
  const JoinedString({this.isLongString = false, this.values = const [], this.rawValue = ''});

  final bool isLongString;
  final List<Node<KclExpr>> values;
  final String rawValue;

  @override
  String get tag => 'JoinedString';

  @override
  String toString() => 'JoinedString($rawValue)';
}

/// `ast::Expr::FormattedValue` — the `${x:>10}` part of an f-string.
class FormattedValue extends KclExpr {
  const FormattedValue({this.isLongString = false, this.value, this.formatSpec});

  final bool isLongString;
  final Node<KclExpr>? value;

  /// A bare format string such as `">10"`, without the interpolation braces.
  final String? formatSpec;

  @override
  String get tag => 'FormattedValue';

  @override
  String toString() => 'FormattedValue(${value?.node}:$formatSpec)';
}

/// `ast::Expr::Missing` — the parser's placeholder for a syntax error.
class MissingExpr extends KclExpr {
  const MissingExpr();

  @override
  String get tag => 'Missing';

  @override
  String toString() => 'MissingExpr()';
}

/// A `type` tag this package does not know about — kept verbatim so a newer
/// `libkcl` degrades to a readable node instead of throwing.
///
/// **A divergence from the Java binding, on purpose.** Java drives
/// deserialisation off `@JsonSubTypes` on `Expr`, so an unregistered tag is
/// an `InvalidTypeIdException` and the parse fails loudly. There is no such
/// mechanism here: [exprFromWire] is a plain `switch`, and the alternative to
/// a default arm is to throw from it. Keeping the payload means a KCL file
/// that uses a syntax a released `libkcl` adds is still traversable, and the
/// tag is on [variant] so a caller can tell exactly what it is looking at.
/// `UnknownStmt` in `stmt.dart` and `UnknownType` in `types.dart` are the
/// same call.
class UnknownExpr extends KclExpr {
  const UnknownExpr(this.variant, this.raw);

  final String variant;
  final Map<String, Object?> raw;

  @override
  String get tag => variant;

  @override
  String toString() => 'UnknownExpr($variant)';
}

/// Decode an *untagged* `CompClause`.
///
/// `ListComp.generators` and `DictComp.generators` are
/// `Vec<NodeRef<CompClause>>`, and only the `Expr` enum is tagged, so inside a
/// comprehension a clause arrives as a bare `{targets, iter, ifs}`.
CompClause compClauseFromWire(Map<String, Object?> w) => CompClause(
      targets: nodeListOf<Identifier>(w['targets'], Identifier.fromWire),
      iter: nodeOf<KclExpr>(w['iter'], exprFromWire),
      ifs: nodeListOf<KclExpr>(w['ifs'], exprFromWire),
    );

/// Decode a `SchemaExpr` / [SchemaConfig] payload — the same decoder for the
/// tagged `Expr::Schema` form and for [UnificationStmt.value].
///
/// Rust types `UnificationStmt.value` as `NodeRef<SchemaExpr>`, and
/// `SchemaExpr` is a plain struct, so *that* payload arrives as a bare
/// `{name, args, kwargs, config}` with **no `type` key**. Routing it through
/// [exprFromWire] would land on [MissingExpr] instead — a silent wrong answer
/// rather than an error — so `stmtFromWire` calls this directly for that
/// field. Through the `Expr` enum the same four keys arrive with a `type` key
/// in front, which this decoder ignores, so one function serves both.
///
/// The nested fields are a mix: `name` is a `NodeRef<Identifier>`, `args` and
/// `config` are `NodeRef<Expr>` (tagged), and `kwargs` is
/// `Vec<NodeRef<Keyword>>` (untagged struct, untagged elements).
SchemaExpr schemaExprFromWire(Map<String, Object?> w) => SchemaExpr(
      name: nodeOf<Identifier>(w['name'], Identifier.fromWire),
      args: nodeListOf<KclExpr>(w['args'], exprFromWire),
      kwargs: nodeListOf<Keyword>(w['kwargs'], Keyword.fromWire),
      config: nodeOf<KclExpr>(w['config'], exprFromWire),
    );

/// Decode the payload of a `NodeRef<Expr>`.
KclExpr exprFromWire(Map<String, Object?> w) {
  final variant = w['type'];
  if (variant is! String) {
    return const MissingExpr();
  }
  switch (variant) {
    case 'Target':
      return TargetExpr(Target.fromWire(w));
    case 'Identifier':
      return IdentifierExpr(Identifier.fromWire(w));
    case 'Unary':
      return UnaryExpr(
        op: strOf(w, 'op'),
        operand: nodeOf<KclExpr>(w['operand'], exprFromWire),
      );
    case 'Binary':
      return BinaryExpr(
        left: nodeOf<KclExpr>(w['left'], exprFromWire),
        op: strOf(w, 'op'),
        right: nodeOf<KclExpr>(w['right'], exprFromWire),
      );
    case 'If':
      return IfExpr(
        body: nodeOf<KclExpr>(w['body'], exprFromWire),
        cond: nodeOf<KclExpr>(w['cond'], exprFromWire),
        orelse: nodeOf<KclExpr>(w['orelse'], exprFromWire),
      );
    case 'Selector':
      return SelectorExpr(
        value: nodeOf<KclExpr>(w['value'], exprFromWire),
        attr: nodeOf<Identifier>(w['attr'], Identifier.fromWire),
        ctx: strOf(w, 'ctx'),
        hasQuestion: flagOf(w, 'has_question'),
      );
    case 'Call':
      return CallExpr(
        func: nodeOf<KclExpr>(w['func'], exprFromWire),
        args: nodeListOf<KclExpr>(w['args'], exprFromWire),
        keywords: nodeListOf<Keyword>(w['keywords'], Keyword.fromWire),
      );
    case 'Paren':
      return ParenExpr(expr: nodeOf<KclExpr>(w['expr'], exprFromWire));
    case 'Quant':
      return QuantExpr(
        target: nodeOf<KclExpr>(w['target'], exprFromWire),
        variables: nodeListOf<Identifier>(w['variables'], Identifier.fromWire),
        op: strOf(w, 'op'),
        test: nodeOf<KclExpr>(w['test'], exprFromWire),
        ifCond: nodeOf<KclExpr>(w['if_cond'], exprFromWire),
        ctx: strOf(w, 'ctx'),
      );
    case 'List':
      return ListExpr(
        elts: nodeListOf<KclExpr>(w['elts'], exprFromWire),
        ctx: strOf(w, 'ctx'),
      );
    case 'ListIfItem':
      return ListIfItemExpr(
        ifCond: nodeOf<KclExpr>(w['if_cond'], exprFromWire),
        exprs: nodeListOf<KclExpr>(w['exprs'], exprFromWire),
        orelse: nodeOf<KclExpr>(w['orelse'], exprFromWire),
      );
    case 'ListComp':
      return ListComp(
        elt: nodeOf<KclExpr>(w['elt'], exprFromWire),
        generators: nodeListOf<CompClause>(w['generators'], compClauseFromWire),
      );
    case 'Starred':
      return StarredExpr(
        value: nodeOf<KclExpr>(w['value'], exprFromWire),
        ctx: strOf(w, 'ctx'),
      );
    case 'DictComp':
      final entry = asMap(w['entry']);
      return DictComp(
        entry: entry == null ? null : ConfigEntry.fromWire(entry),
        generators: nodeListOf<CompClause>(w['generators'], compClauseFromWire),
      );
    case 'ConfigIfEntry':
      return ConfigIfEntryExpr(
        ifCond: nodeOf<KclExpr>(w['if_cond'], exprFromWire),
        items: nodeListOf<ConfigEntry>(w['items'], ConfigEntry.fromWire),
        orelse: nodeOf<KclExpr>(w['orelse'], exprFromWire),
      );
    case 'CompClause':
      return compClauseFromWire(w);
    case 'Schema':
      return schemaExprFromWire(w);
    case 'Config':
      return ConfigExpr(
          items: nodeListOf<ConfigEntry>(w['items'], ConfigEntry.fromWire));
    case 'Check':
      return CheckExpr.fromWire(w);
    case 'Lambda':
      return LambdaExpr(
        args: nodeOf<Arguments>(w['args'], Arguments.fromWire),
        body: nodeListOf<KclStmt>(w['body'], stmtFromWire),
        returnTy: nodeOf<AstType>(w['return_ty'], typeFromWire),
      );
    case 'Subscript':
      return Subscript(
        value: nodeOf<KclExpr>(w['value'], exprFromWire),
        index: nodeOf<KclExpr>(w['index'], exprFromWire),
        lower: nodeOf<KclExpr>(w['lower'], exprFromWire),
        upper: nodeOf<KclExpr>(w['upper'], exprFromWire),
        step: nodeOf<KclExpr>(w['step'], exprFromWire),
        ctx: strOf(w, 'ctx'),
        hasQuestion: flagOf(w, 'has_question'),
      );
    case 'Keyword':
      return KeywordExpr(Keyword.fromWire(w));
    case 'Arguments':
      return ArgumentsExpr(Arguments.fromWire(w));
    case 'Compare':
      return Compare(
        left: nodeOf<KclExpr>(w['left'], exprFromWire),
        ops: stringListOf(w, 'ops'),
        comparators: nodeListOf<KclExpr>(w['comparators'], exprFromWire),
      );
    case 'NumberLit':
      final inner = asMap(w['value']);
      return NumberLit(
        binarySuffix: w['binary_suffix'] as String?,
        valueTag: inner?['type'] as String?,
        value: inner?['value'] as num?,
      );
    case 'StringLit':
      return StringLit(
        isLongString: flagOf(w, 'is_long_string'),
        rawValue: w['raw_value'] as String? ?? '""',
        value: w['value'] as String? ?? '',
      );
    case 'NameConstantLit':
      return NameConstantLit(value: strOf(w, 'value'));
    case 'JoinedString':
      return JoinedString(
        isLongString: flagOf(w, 'is_long_string'),
        values: nodeListOf<KclExpr>(w['values'], exprFromWire),
        rawValue: strOf(w, 'raw_value'),
      );
    case 'FormattedValue':
      return FormattedValue(
        isLongString: flagOf(w, 'is_long_string'),
        value: nodeOf<KclExpr>(w['value'], exprFromWire),
        formatSpec: w['format_spec'] as String?,
      );
    case 'Missing':
      return const MissingExpr();
    default:
      return UnknownExpr(variant, w);
  }
}

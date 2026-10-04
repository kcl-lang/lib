// types.dart — The KCL type hierarchy. Mirrors `ast::Type` in
// `../kcl/crates/ast/src/ast.rs`.
//
// `Type` is declared `#[serde(tag = "type", content = "value")]`, so every
// type node on the wire is a two-key object:
//
//     {"type": "Basic", "value": "Int"}
//     {"type": "List",  "value": {"inner_type": <Type> | null}}
//
// The payload is whatever the variant holds. `BasicType` and `LiteralType` are
// themselves enums without a struct wrapper, so their payloads collapse to a
// bare scalar — that is why a basic type reads back as the string `"Int"`
// rather than an object.

import 'base.dart';
import 'dto.dart';

/// A type annotation. Sealed so a `switch` over it is checked at compile time.
sealed class AstType {
  const AstType();

  /// The `type` tag the parser emitted, for round-tripping back to source.
  String get tag;
}

/// `ast::Type::Any` — the `any` type. Serialized as `{"type": "Any"}` with no
/// `value` key, because it is a unit variant.
class AnyType extends AstType {
  const AnyType();

  @override
  String get tag => 'Any';
}

/// `ast::Type::Basic(BasicType)` — one of `Bool`, `Int`, `Float`, `Str`.
class BasicType extends AstType {
  const BasicType(this.name);

  @override
  String get tag => 'Basic';

  /// `"Bool"`, `"Int"`, `"Float"` or `"Str"`.
  final String name;

  @override
  String toString() => 'BasicType($name)';
}

/// `ast::Type::Named(Identifier)` — a schema or alias name.
class NamedType extends AstType {
  const NamedType(this.identifier);

  @override
  String get tag => 'Named';

  final Identifier identifier;

  @override
  String toString() => 'NamedType(${identifier.name})';
}

/// `ast::Type::List(ListType)`.
class ListType extends AstType {
  const ListType(this.innerType);

  @override
  String get tag => 'List';

  final Node<AstType>? innerType;

  @override
  String toString() => 'ListType($innerType)';
}

/// `ast::Type::Dict(DictType)`.
class DictType extends AstType {
  const DictType(this.keyType, this.valueType);

  @override
  String get tag => 'Dict';

  final Node<AstType>? keyType;
  final Node<AstType>? valueType;

  @override
  String toString() => 'DictType($keyType, $valueType)';
}

/// `ast::Type::Union(UnionType)`.
class UnionType extends AstType {
  const UnionType(this.types);

  @override
  String get tag => 'Union';

  /// The Rust field is `type_elements`, not `types`.
  final List<Node<AstType>> types;

  @override
  String toString() => 'UnionType($types)';
}

/// `ast::Type::Literal(LiteralType)` — a literal used as a type, e.g.
/// `LiteralType::Int { value: 1 }`.
///
/// The nested `LiteralType` is itself tagged, so the payload arrives as
/// `{"type": "Int", "value": {"value": 1, "suffix": null}}`. The raw payload
/// is kept verbatim rather than re-modelled, because it has three different
/// shapes depending on the inner tag.
class LiteralType extends AstType {
  const LiteralType(this.value, [this.innerTag]);

  @override
  String get tag => 'Literal';

  /// The decoded `LiteralType` payload, or null when the wire omitted it.
  final Object? value;

  /// `"Bool"`, `"Int"`, `"Float"` or `"Str"`, or null if the payload was not
  /// an object.
  final String? innerTag;

  @override
  String toString() => 'LiteralType($innerTag, $value)';
}

/// `ast::Type::Function(FunctionType)`.
class FunctionType extends AstType {
  const FunctionType(this.paramsTy, this.retTy);

  @override
  String get tag => 'Function';

  final List<Node<AstType>>? paramsTy;
  final Node<AstType>? retTy;

  @override
  String toString() => 'FunctionType($paramsTy, $retTy)';
}

/// The tag on a `Type` node, used when the runtime grows a variant this
/// package does not know about yet.
///
/// **A divergence from the Java binding, on purpose** — see [UnknownExpr].
/// Java reads `Type` through Jackson's `STANDARD_TYPE_RESOLVER` and an
/// unknown variant raises `InvalidTypeIdException`; [typeFromWire] is a plain
/// `switch` with a default arm, so a newer `libkcl` that adds a type variant
/// still yields a traversable tree.
class UnknownType extends AstType {
  const UnknownType(this.tag, [this.value]);

  /// The tag as it appeared on the wire — kept verbatim rather than mapped to
  /// a placeholder, so a caller can see which variant appeared.
  @override
  final String tag;
  final Object? value;

  @override
  String toString() => 'UnknownType($tag)';
}

/// Decode a `NodeRef<Type>` payload.
AstType typeFromWire(Map<String, Object?> w) {
  final tag = w['type'] as String?;
  if (tag == null) return const AnyType();
  final value = w['value'];
  switch (tag) {
    case 'Any':
      return const AnyType();
    case 'Named':
      final named = asMap(value);
      return NamedType(
          named == null ? const Identifier() : Identifier.fromWire(named));
    case 'Basic':
      return BasicType(value as String? ?? '');
    case 'List':
      final list = asMap(value);
      return ListType(
          list == null ? null : nodeOf<AstType>(list['inner_type'], typeFromWire));
    case 'Dict':
      final dict = asMap(value);
      return DictType(
        dict == null ? null : nodeOf<AstType>(dict['key_type'], typeFromWire),
        dict == null
            ? null
            : nodeOf<AstType>(dict['value_type'], typeFromWire),
      );
    case 'Union':
      final union = asMap(value);
      return UnionType(union == null
          ? const []
          : nodeListOf<AstType>(union['type_elements'], typeFromWire));
    case 'Literal':
      return LiteralType(value, asMap(value)?['type'] as String?);
    case 'Function':
      final fn = asMap(value);
      return FunctionType(
        fn == null ? null : nodeListOf<AstType>(fn['params_ty'], typeFromWire),
        fn == null ? null : nodeOf<AstType>(fn['ret_ty'], typeFromWire),
      );
    default:
      return UnknownType(tag, value);
  }
}

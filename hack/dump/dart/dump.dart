// Cross-language AST dump for the Dart binding.
//
//   dart run --packages=dart/.dart_tool/package_config.json \
//     hack/dump/dart/dump.dart <golden.json> <out.json>
//
// Runs the binding's real decoder (`parseModule` from
// `dart/lib/src/ast/module.dart`) over the shared capture and writes the tree
// in the shape `hack/ast_diff/canonical.rb` compares.
//
// Dart has no field reflection without `dart:mirrors`, so this uses it: the
// walk reads each object's declared fields off its `ClassMirror` rather than
// naming them here. That is the point — a dumper that listed the fields by
// hand would be a second list to keep in sync with the decoder, and it would
// go stale silently, which is the failure mode this harness exists to catch.
// `dart run` executes on the Dart VM, where `dart:mirrors` is available.
//
// Two Dart-specific things the walk has to get right:
//
//   * `Node<T>` and `Pos` are generic in the type but not in the reflection:
//     `MirrorSystem.getName(Node<String>)` is just `Node`, so a `Node<Body>`
//     and a `Node<Comment>` both report `@cls: "Node"`. The comparator hoists
//     the position out of `Node` (R2), so the type argument never matters.
//   * The sealed bases `KclExpr` / `KclStmt` / `AstType` declare `tag` as an
//     abstract getter and every variant overrides it. Reading it is the
//     binding's own claim about which variant it decoded, so it is mirrored
//     into `@tag` for the comparator's tag cross-check — the same third claim
//     the Ruby and Julia dumpers make. `MemberOrIndex` has no such getter
//     (it is a sealed class, not a tagged one), so a `Member` answers no tag
//     and the report says the check was unavailable for it.
//
// `UnknownExpr` / `UnknownStmt` / `UnknownType` keep the wire payload and are
// written out as `@raw` so the comparator can check it against the golden
// (R11). A binding that keeps the payload is checked; one that drops it is a
// diff by name, which is the bug class this harness was built to find.

import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:kcl_lib/src/ast/base.dart';
import 'package:kcl_lib/src/ast/expr.dart';
import 'package:kcl_lib/src/ast/module.dart';
import 'package:kcl_lib/src/ast/stmt.dart';
import 'package:kcl_lib/src/ast/types.dart';

/// The class name, unqualified. Dart has no package qualifier on a
/// `ClassMirror`, so this is just the declared name.
String shortName(dynamic value) =>
    MirrorSystem.getName(reflect(value).type.simpleName);

/// The binding's own tag for this value, or null when it has none.
///
/// `KclExpr` / `KclStmt` / `AstType` all declare a `tag` getter, so a plain
/// DTO — `Identifier`, `Target`, `ConfigEntry` — answers null and the
/// comparator reads that as "this object claims no tag", which is exactly
/// right for an untagged wire object.
String? tagOf(dynamic value) {
  if (value is KclExpr || value is KclStmt || value is AstType) {
    return (value as dynamic).tag as String;
  }
  return null;
}

/// `Node<T>`'s type argument is not part of the reflection, so this is the
/// declared name for every instantiation.
bool isNode(dynamic value) => value.runtimeType.toString().startsWith('Node');

bool isUnknown(dynamic value) =>
    value is UnknownExpr || value is UnknownStmt || value is UnknownType;

/// The declared instance fields of `value`'s class and every superclass,
/// nearest first. `ClassMirror.declarations` is the class's own members, so
/// walking `superclass` is what makes an inherited field show up; the sealed
/// bases declare no fields, but walking the chain means a dumper here does
/// not have to know that.
List<String> fieldNames(dynamic value) {
  final names = <String>[];
  ClassMirror? cls = reflect(value).type;
  while (cls != null) {
    for (final decl in cls.declarations.values) {
      if (decl is VariableMirror && decl.isFinal) {
        final n = MirrorSystem.getName(decl.simpleName);
        if (!names.contains(n)) names.add(n);
      }
    }
    cls = cls.superclass;
  }
  return names;
}

dynamic dump(dynamic v) {
  if (v == null || v is bool || v is int || v is double || v is String) {
    return v;
  }
  if (v is List) return v.map(dump).toList();
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries) e.key.toString(): dump(e.value),
    };
  }

  // `Node<T>` boxes its payload under `node` and its position under `pos`, so
  // the comparator's R2 hoists the position and the rest is the payload.
  if (isNode(v)) {
    final out = <String, dynamic>{'@cls': 'Node', 'node': dump(v.node)};
    if (v.pos != null) out['pos'] = dump(v.pos);
    return out;
  }

  // The Unknown* variants keep the wire payload; R11 checks it.
  if (isUnknown(v)) {
    final out = <String, dynamic>{
      '@cls': shortName(v),
      '@raw': dump(v is UnknownExpr || v is UnknownStmt ? v.raw : v.value),
    };
    final tag = tagOf(v);
    if (tag != null) out['@tag'] = tag;
    return out;
  }

  final out = <String, dynamic>{'@cls': shortName(v)};
  final tag = tagOf(v);
  if (tag != null) out['@tag'] = tag;
  for (final f in fieldNames(v)) {
    out[f] = dump(reflect(v).getField(Symbol(f)).reflectee);
  }
  return out;
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
        'usage: dart run --packages=dart/.dart_tool/package_config.json '
        'hack/dump/dart/dump.dart <golden.json> <out.json>');
    exit(2);
  }

  final moduleAst = parseModule(File(args[0]).readAsStringSync());

  final doc = <String, dynamic>{
    'schema': 'kcl-ast-canonical/1',
    'binding': 'dart',
    'mode': 'reflect',
    'root': dump(moduleAst),
  };

  File(args[1]).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(doc)}\n');
}

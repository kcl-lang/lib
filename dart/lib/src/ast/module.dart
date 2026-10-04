// module.dart — `ast::Module` and the `parseModule` / `parseProgram` entry
// points.
//
// A `Module` is the AST of one KCL file. `parseProgram` returns the AST of a
// whole program, which the service serializes either as a bare array of
// modules or as a `{"root": ..., "pkgs": {"__main__": [...]}}` envelope.

import 'dart:convert';

import 'base.dart';
import 'stmt.dart';

/// `ast::Module` — the top-level AST node of a single KCL file.
///
/// The Rust struct has no `pkg` field: the Java and Go bindings used to expose
/// one and were aligned to drop it, so this class has none either.
class Module {
  const Module({
    this.filename = '',
    this.doc,
    this.body = const [],
    this.comments = const [],
  });

  factory Module.fromWire(Map<String, Object?> w) => Module(
        filename: strOf(w, 'filename'),
        doc: stringNode(w['doc']),
        body: nodeListOf<KclStmt>(w['body'], stmtFromWire),
        comments: nodeListOf<Comment>(w['comments'], Comment.fromWire),
      );

  final String filename;
  final Node<String>? doc;
  final List<Node<KclStmt>> body;
  final List<Node<Comment>> comments;

  @override
  String toString() => 'Module($filename, ${body.length} stmts)';
}

/// Parse the `astJson` string returned by `parseFile` into a [Module].
///
/// Throws a [FormatException] if [astJson] is not a JSON object.
///
/// ```dart
/// final r = parseFile(ParseFileArgs(path: 'main.k', source: src));
/// final module = parseModule(r.astJson);
/// for (final ref in module.body) {
///   final stmt = ref.node;
///   if (stmt is SchemaStmt) print('schema ${stmt.name?.node}');
/// }
/// ```
Module parseModule(String astJson) {
  final decoded = jsonDecode(astJson);
  final w = asMap(decoded);
  if (w == null) {
    throw const FormatException('expected a KCL Module object');
  }
  return Module.fromWire(w);
}

/// Parse the `astJson` string returned by the `parseProgram` RPC into a
/// module list.
///
/// Named with an `Ast` suffix because the RPC wrapper `parseProgram` already
/// occupies that name in the `package:kcl_lib/kcl_lib.dart` barrel.
///
/// The service serializes a program either as a bare array of modules or as a
/// `{"root": ..., "pkgs": {"__main__": [...]}}` envelope; both are accepted.
List<Module> parseProgramAst(String programJson) {
  final decoded = jsonDecode(programJson);
  if (decoded is List) {
    return decoded
        .map((m) => Module.fromWire(asMap(m) ?? const {}))
        .toList(growable: false);
  }
  final envelope = asMap(decoded);
  if (envelope == null) return const [];
  final pkgs = asMap(envelope['pkgs']);
  final main = pkgs?['__main__'];
  if (main is! List) return const [];
  return main
      .map((m) => Module.fromWire(asMap(m) ?? const {}))
      .toList(growable: false);
}

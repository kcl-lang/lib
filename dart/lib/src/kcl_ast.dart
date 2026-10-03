// kcl_ast.dart — Typed AST for the Dart binding.
//
// Turns the `astJson` string that `parseFile` / `parseProgram` return into
// typed objects matching Rust's AST in `../kcl/crates/ast/src/ast.rs`. The
// same split the C, C++, Java, Kotlin, Node.js, .NET, WASM, Lua, Swift, Zig and
// Python bindings use applies here:
//
//   - `Stmt` / `Expr` are `#[serde(tag = "type")]`, so each node carries a
//     `type` discriminator and decodes to its own class.
//   - `Type` is `#[serde(tag = "type", content = "value")]`, so a type node is
//     a two-key object whose `value` holds the variant's payload.
//   - The plain structs nested inside `NodeRef<T>` — `Identifier`, `Target`,
//     `MemberOrIndex`, `Keyword`, `Arguments`, `ConfigEntry`, `CallExpr`,
//     `SchemaExpr` — carry no tag of their own, and live in `ast/dto.dart`
//     or, where they are also `Expr` variants, in `ast/expr.dart`.
//
// Class names follow the Java binding's `com.kcl.ast` vocabulary, so a name
// from `ast.rs` or from `java/src/main/java/com/kcl/ast/` is the name here:
// `Compare`, `ListComp`, `DictComp`, `NumberLit`, `StringLit`,
// `NameConstantLit`, `JoinedString`, `FormattedValue`, `Subscript`, `Module`,
// `Pos`, `Node`. Three payloads arrive untagged and Java gives each a second
// class for Jackson's sake; here each is one class under two names — see
// [Decorator], [SchemaConfig] and [CheckExpr] in `ast/expr.dart`.
//
// ```dart
// import 'package:kcl_lib/kcl_lib.dart';
//
// final r = parseFile(ParseFileArgs(path: 'main.k', source: src));
// final module = parseModule(r.astJson);
// for (final ref in module.body) {
//   switch (ref.node) {
//     case SchemaStmt(:final name?):
//       print('schema ${name.node} at ${ref.pos}');
//     case AssignStmt(:final targets):
//       print('assign ${targets.map((t) => t.node.name?.node).join(', ')}');
//     default:
//       break;
//   }
// }
// ```

export 'ast/base.dart';
export 'ast/dto.dart';
export 'ast/expr.dart';
export 'ast/module.dart';
export 'ast/stmt.dart';
export 'ast/types.dart';

// base.dart — Pos, Node<T>, Comment and the wire-decoding helpers that
// every other AST layer is built on.
//
// Mirrors `ast::Pos` / `ast::Node<T>` / `ast::NodeRef<T>` / `ast::Comment`
// in `../kcl/crates/ast/src/ast.rs`.
//
// A `NodeRef<T>` is a boxed `Node<T>`, so the two share a JSON shape:
//
//     {"node": <T>, "filename": "main.k", "line": 1, "column": 0,
//      "end_line": 3, "end_column": 1}
//
// [Node.pos] is null only when the object carries no `filename` key, which
// the parser never emits for a real node.

/// A source position as attached to every parsed node.
class Pos {
  const Pos({
    required this.filename,
    required this.line,
    required this.column,
    required this.endLine,
    required this.endColumn,
  });

  /// Decode the snake_case keys the parser emits.
  factory Pos.fromWire(Map<String, Object?> w) => Pos(
        filename: w['filename'] as String? ?? '',
        line: _asInt(w['line']),
        column: _asInt(w['column']),
        endLine: _asInt(w['end_line']),
        endColumn: _asInt(w['end_column']),
      );

  final String filename;
  final int line;
  final int column;
  final int endLine;
  final int endColumn;

  @override
  String toString() => '$filename:$line:$column-$endLine:$endColumn';
}

/// A value of type [T] together with its source position — `ast::Node<T>`.
///
/// Every `NodeRef<T>` in `ast.rs` serializes to this shape, so this is what
/// [nodeOf] and friends return and what every `…` field on a statement is
/// typed as. The name is the Rust struct's; `NodeRef` is a `Box<Node<T>>` on
/// the wire and there is nothing left of the boxing after deserialization.
class Node<T> {
  const Node(this.node, [this.pos]);

  /// The decoded payload.
  final T node;

  /// Where the payload starts, or null if the wire object had no position.
  final Pos? pos;
}

/// A `#` comment — `ast::Comment { text }`.
class Comment {
  const Comment(this.text);

  /// `Comment` is a plain struct with one `String` field, so the object under
  /// a comment's `node` key is `{"text": "…"}` and **not** the text itself.
  /// Reading it as a bare string yields an empty comment for every comment in
  /// the file, with nothing thrown and nothing logged — the field set, the
  /// names and the types are all honest, which is why a name-and-type
  /// cross-check calls such a decoder clean. Four bindings shipped exactly
  /// that decoder. `nodeOf` has already lifted `node` out by the time this
  /// runs, so the key to read is `text`; unwrapping a second time is the same
  /// bug with the sign flipped.
  factory Comment.fromWire(Map<String, Object?> w) =>
      Comment(w['text'] as String? ?? '');

  final String text;

  @override
  String toString() => 'Comment($text)';
}

// ---------------------------------------------------------------------------
// Wire helpers. Every decoder in this package goes through these, so the
// snake_case mapping and the null handling live in exactly one place.
// ---------------------------------------------------------------------------

/// Narrow an untyped `jsonDecode` value to a string-keyed object.
Map<String, Object?>? asMap(Object? v) =>
    v is Map<String, Object?> ? v : (v is Map ? v.cast<String, Object?>() : null);

int _asInt(Object? v) => v is num ? v.toInt() : 0;

/// A bool field, defaulting to `false` when absent.
///
/// `ConfigEntry.is_shorthand` carries
/// `#[serde(skip_serializing_if = "is_false")]`, so `false` is omitted from
/// the wire entirely — `w[key] == true` reproduces that faithfully.
bool flagOf(Map<String, Object?> w, String key) => w[key] == true;

String strOf(Map<String, Object?> w, String key) => w[key] as String? ?? '';

/// A list field, defaulting to the empty list when absent or null.
List<Object?> arrOf(Map<String, Object?> w, String key) =>
    w[key] is List ? w[key]! as List<Object?> : const [];

/// The [Pos] of a `NodeRef` wire object, or null when it carries no position.
Pos? posOf(Map<String, Object?> w) =>
    w['filename'] == null ? null : Pos.fromWire(w);

/// Decode a `NodeRef<String>` — the payload is a bare JSON string.
Node<String>? stringNode(Object? w) {
  final m = asMap(w);
  if (m == null) return null;
  return Node<String>(m['node'] as String? ?? '', posOf(m));
}

/// Decode a `NodeRef<T>` whose payload is a JSON object.
Node<T>? nodeOf<T>(Object? w, T Function(Map<String, Object?>) load) {
  final m = asMap(w);
  if (m == null) return null;
  final inner = asMap(m['node']);
  if (inner == null) return null;
  return Node<T>(load(inner), posOf(m));
}

/// Decode a JSON array of `NodeRef<T>`, dropping the nulls the parser emits
/// for `Vec<Option<NodeRef<T>>>` fields.
List<Node<T>> nodeListOf<T>(
    Object? w, T Function(Map<String, Object?>) load) {
  if (w is! List) return const [];
  final out = <Node<T>>[];
  for (final item in w) {
    final n = nodeOf<T>(item, load);
    if (n != null) out.add(n);
  }
  return out;
}

/// Decode a JSON array of `NodeRef<T>` whose elements are themselves
/// nullable, keeping the `null`s so the list lines up with `Arguments.defaults`
/// and `Arguments.tyList` (one slot per parameter).
List<Node<T>?> nullableNodeListOf<T>(
    Object? w, T Function(Map<String, Object?>) load) {
  if (w is! List) return const [];
  return w.map((item) => nodeOf<T>(item, load)).toList();
}

/// Decode a JSON array of `NodeRef<String>`, e.g. `Identifier.names`.
List<Node<String>> stringNodeListOf(Object? w) {
  if (w is! List) return const [];
  final out = <Node<String>>[];
  for (final item in w) {
    final n = stringNode(item);
    if (n != null) out.add(n);
  }
  return out;
}

/// Decode a bare list of payload objects (no `NodeRef` wrapper), e.g.
/// `Vec<MemberOrIndex>` inside [Target].
List<T> plainListOf<T>(Object? w, T Function(Map<String, Object?>) load) {
  if (w is! List) return const [];
  final out = <T>[];
  for (final item in w) {
    final m = asMap(item);
    if (m != null) out.add(load(m));
  }
  return out;
}

/// Decode a list of bare payload strings, e.g. `Compare.ops`.
List<String> stringListOf(Map<String, Object?> w, String key) {
  final raw = w[key];
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

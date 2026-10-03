// Cross-language AST dump for the Swift binding.
//
//   bash hack/dump/swift.sh <golden.json> <out.json>
//
// Runs the binding's real decoder (`parseModule` from
// `swift/Sources/KclLibAST`) over the shared capture and writes the tree in
// the shape `hack/ast_diff/canonical.rb` compares.
//
// Swift has no `serde`, so the binding hand-builds its types from
// `JSONSerialization` — but every AST node is a plain `struct` and every
// polymorphic node is a Swift `enum` with one case per variant, and `Mirror`
// reflects both. So the walk is reflective: `Mirror.children` for the fields,
// the enum's case label for the tag, and the payload's dynamic type for
// `@cls`. That gives the comparator the same three claims to cross-check that
// the Ruby, Python, Julia and Dart dumpers give it — the struct name, the
// variant the binding says it decoded, and the golden.
//
// Three Swift-specific things the walk has to get right:
//
//   * `NodeRef<T>` is `{node, position, id}`. `position` is nested, so the
//     comparator's R2 hoists it; `id` is Swift-only — the wire `NodeRef<T>`
//     is `{node, filename, line, column, end_line, end_column}` and carries
//     no `id`, so the binding's table lists it as an accepted extra.
//   * An `Optional<T>` reaches `Mirror` as `.some(x)` / `.none`, so the walk
//     has to unwrap it before deciding what a field holds. `nil` is written
//     as JSON `null`; a null that is *meant* is a null, and the wire's
//     absent-vs-null distinction is R4's job, not this walk's.
//   * The raw-value enums (`ExprContext`, `NameConstant`, `UnaryOp`, …) reach
//     `Mirror` as a `.enum` labelled `rawValue` wrapping a `String`. They are
//     scalar as far as the wire is concerned — `ctx: "Load"`, not an object —
//     so the walk unwraps them to the string rather than emitting a box.
//
// The `unknown` case of each polymorphic enum keeps only the tag
// (`case unknown(type: String)` — `Pos.swift:145`, `:184`, `:199`): there is no
// payload to check, so the comparator's R11 raw-payload check is unavailable
// for this binding, and the report says so.

import Foundation

// No `import KclLibAST`: `hack/dump/swift.sh` compiles this file *together
// with* `swift/Sources/KclLibAST/*.swift`, so the AST types are in this same
// module. That is deliberate — compiling the sources rather than linking a
// prebuilt `.build/` artifact is what makes this check the decoder as it is
// written today.

// ---------------------------------------------------------------------------
// A minimal JSON writer.
//
// Only the value kinds a decoded AST can hold. No dependency, and nothing here
// decides what a node means — it only prints what the decoder produced.
// ---------------------------------------------------------------------------

func jsonEscape(_ s: String) -> String {
    var out = ""
    for ch in s.unicodeScalars {
        switch ch {
        case "\\": out += "\\\\"
        case "\"": out += "\\\""
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        case "\u{08}": out += "\\b"
        case "\u{0C}": out += "\\f"
        default:
            if ch.value < 0x20 {
                out += String(format: "\\u%04x", ch.value)
            } else {
                out.unicodeScalars.append(ch)
            }
        }
    }
    return out
}

func writeJSON(_ value: Any, to out: String, indent: Int) -> String {
    let pad = String(repeating: "  ", count: indent)
    let inner = String(repeating: "  ", count: indent + 1)

    if value is NSNull { return "null" }
    if let b = value as? Bool { return b ? "true" : "false" }
    if let n = value as? Int { return String(n) }
    if let n = value as? Int64 { return String(n) }
    if let d = value as? Double {
        return d.isFinite ? String(d) : "null"
    }
    if let s = value as? String { return "\"\(jsonEscape(s))\"" }
    if let a = value as? [Any] {
        if a.isEmpty { return "[]" }
        let items = a.enumerated().map { i, item in
            inner + writeJSON(item, to: out, indent: indent + 1)
                + (i == a.count - 1 ? "" : ",")
        }
        return "[\n" + items.joined(separator: "\n") + "\n" + pad + "]"
    }
    if let d = value as? [String: Any] {
        if d.isEmpty { return "{}" }
        let keys = d.keys.sorted()
        let items = keys.enumerated().map { i, k in
            inner + "\"\(jsonEscape(k))\": " + writeJSON(d[k]!, to: out, indent: indent + 1)
                + (i == keys.count - 1 ? "" : ",")
        }
        return "{\n" + items.joined(separator: "\n") + "\n" + pad + "}"
    }
    fatalError("hack/dump/swift: cannot serialise a \(type(of: value))")
}

// ---------------------------------------------------------------------------
// The walk.
// ---------------------------------------------------------------------------

/// A short, stable class name. `KclLibAST.ExprStmt` has no module prefix at
/// runtime, but a type nested in a function would, so the module is stripped
/// if it ever appears.
///
/// The *generic argument* is stripped too: `String(describing: NodeRef<Stmt>)`
/// is `"NodeRef<Stmt>"`, and the wire has one `NodeRef` whatever it wraps, so
/// the type argument would be a difference the golden cannot referee. The
/// binding's own contract is that `NodeRef<T>` is `Box<Node<T>>` — the boxing
/// leaves nothing on the wire — so `NodeRef` alone is the honest class name.
func shortName(_ v: Any) -> String {
    var n = String(describing: type(of: v))
    if let lt = n.firstIndex(of: "<") { n = String(n[..<lt]) }
    if let dot = n.lastIndex(of: ".") { n = String(n[n.index(after: dot)...]) }
    return n
}

/// The polymorphic enum's case label, capitalised to the wire spelling.
///
/// Swift's case labels are lowerCamel (`typeAlias`, `listIfItem`, `if`) and
/// the wire tags are the Rust variant names verbatim (`TypeAlias`,
/// `ListIfItem`, `If`) — `Pos.swift` says so at the top: "no `rename_all`, so
/// the wire tag is the variant name verbatim". Capitalising the first letter
/// is therefore exact, not a guess. This is the only place the dumper maps
/// between the binding's spelling and the wire's, and it is checked against
/// the golden at every tagged node.
func wireTag(_ caseLabel: String) -> String {
    guard let first = caseLabel.first else { return caseLabel }
    return String(first).uppercased() + caseLabel.dropFirst()
}

/// `Optional<T>` reaches `Mirror` as `.some(x)` / `.none`. Unwrap it so a
/// field holding a value is walked as that value, and a field holding nothing
/// is `null` rather than a box the golden has no counterpart for.
///
/// Takes an `Any?` rather than an `Any` because the `nil` case is real: a
/// missing `NodeRef` is the argument itself, and a `Swift Optional` bridges to
/// an `Optional` rather than to a `Mirror`-able value.
func unwrapOptional(_ v: Any?) -> Any? {
    guard let v = v else { return nil }
    let m = Mirror(reflecting: v)
    if m.displayStyle == .optional {
        if let child = m.children.first { return child.value }
        return nil
    }
    return v
}

func dump(_ raw: Any?) -> Any? {
    guard let v = unwrapOptional(raw) else { return NSNull() }

    let m = Mirror(reflecting: v)
    switch m.displayStyle {
    case .optional:
        return dump(unwrapOptional(v))

    case .enum:
        // A raw-value enum (`ExprContext`, `NameConstant`, `BasicType`, the
        // operator enums) has *no* Mirror children at all — the raw value is
        // not a child, it is the value. `Mirror` reports `.enum` with
        // `children.isEmpty`, which is otherwise indistinguishable from a
        // payload-less case, so the protocol is what distinguishes them:
        // `RawRepresentable` is declared by exactly the enums whose wire
        // spelling *is* their raw value.
        //
        // This matters more than it looks: reading these as "a case with no
        // payload" would emit `null` for every `ctx`, every `op` and every
        // `BasicType` name, and the comparator would report 150+ differences
        // that all have the same uninformative cause.
        if m.children.isEmpty {
            guard let raw = v as? any RawRepresentable,
                let s = raw.rawValue as? String
            else {
                fatalError("""
                    hack/dump/swift: \(type(of: v)) is a payload-less enum case \
                    that is not RawRepresentable-with-String, so there is no way \
                    to write it. Name it in the walk rather than guessing.
                    """)
            }
            return s
        }
        // A polymorphic variant: the label names the variant and the single
        // child is its payload. `unknown` keeps only the tag.
        guard let label = m.children.first?.label, let payload = m.children.first?.value
        else {
            fatalError("""
                hack/dump/swift: \(type(of: v)) has \(m.children.count) children; \
                a variant is expected to have exactly one payload.
                """)
        }
        let tag = wireTag(label)
        if label == "unknown" {
            // `case unknown(type: String)` — the binding keeps the tag and
            // drops the payload, so there is nothing to check against the
            // golden. The tag itself is the whole claim.
            return ["@cls": "Unknown", "@tag": (payload as? String) ?? tag]
        }
        return taggedDump(payload, tag: tag, enumName: shortName(v))

    case .struct:
        var out: [String: Any] = ["@cls": shortName(v)]
        for child in m.children {
            out[child.label ?? "_"] = dump(child.value) ?? NSNull()
        }
        return out

    case .collection:
        var out: [Any] = []
        for child in m.children { out.append(dump(child.value) ?? NSNull()) }
        return out

    default:
        // A scalar: String, Bool, Int, Int64, Double. `Mirror` reports these
        // as `.struct` in some Swift versions and `.none`/`.class` in others,
        // so the switch falls through to here either way and the value is
        // returned as-is.
        return v
    }
}

/// A polymorphic variant's payload, with the variant's tag recorded.
///
/// The payload is normally a struct, so `@cls` is its own name and the fields
/// are its own — that is the "struct name" claim.
///
/// A payload that is *not* a struct is a bare associated value:
/// `NumberLitValue.int(1)` carries an `Int64` and `LiteralTypeValue.str("s")`
/// carries a `String`. There the *enum* is the class, not the payload's Swift
/// type — `Int64` is not a class in this AST, and claiming it was would be
/// reading a language primitive as if it were a decoder's own type. So `@cls`
/// is the enclosing enum's name and the payload goes under `value`, which is
/// also the wire's own `{type, value}` shape.
func taggedDump(_ payload: Any, tag: String, enumName: String) -> [String: Any] {
    let m = Mirror(reflecting: payload)
    if m.displayStyle == .struct {
        var out: [String: Any] = ["@cls": shortName(payload), "@tag": tag]
        for child in m.children {
            out[child.label ?? "_"] = dump(child.value) ?? NSNull()
        }
        return out
    }
    return ["@cls": enumName, "@tag": tag, "value": dump(payload) ?? NSNull()]
}

// ---------------------------------------------------------------------------

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write(
        "usage: bash hack/dump/swift.sh <golden.json> <out.json>\n".data(using: .utf8)!)
    exit(2)
}

let goldenPath = args[1]
let outPath = args[2]

let golden = try String(contentsOfFile: goldenPath, encoding: .utf8)
let moduleAst = try parseModule(golden)

let doc: [String: Any] = [
    "schema": "kcl-ast-canonical/1",
    "binding": "swift",
    "mode": "reflect",
    "root": dump(moduleAst) ?? NSNull(),
]

try writeJSON(doc, to: outPath, indent: 0).write(toFile: outPath, atomically: true, encoding: .utf8)

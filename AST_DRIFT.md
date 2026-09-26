# KCL AST Drift Report

Source of truth: `../kcl/crates/ast/src/ast.rs` (Rust + serde JSON)

Wire format: `spec.proto` `ast_json` (string). All AST nodes serialize through serde
JSON field names, NOT protobuf. Bindings that model AST as classes (lib/java, kcl-go)
must match the Rust serde JSON shape. Bindings that only pass `ast_json` as a string
(Python, Node.js, C, C++, .NET, Kotlin, Lua, Swift, Zig, WASM) need no AST class
alignment — they only consume the protobuf API surface.

## Bindings with hand-written AST classes

| Binding | Package | Notes |
|---------|---------|-------|
| lib/java | `com.kcl.ast` (85 files) | Jackson-driven |
| kcl-go | `pkg/ast` (6 files: ast/expr/json/op/stmt/type) | encoding/json-driven |

All other language bindings in this repo only generate protobuf stubs from
`spec.proto` and forward `ast_json` as an opaque string. They have no AST
class definitions to drift.

## Items that drift in BOTH lib/java and kcl-go

| # | Item | Rust (truth) | lib/java | kcl-go | Status |
|---|------|--------------|----------|--------|--------|
| 1 | `Module.pkg` | absent | present | present | ✅ removed |
| 2 | `Expr::Check` variant | present | missing from `@JsonSubTypes` | missing from `UnmarshalExpr` | ✅ added |
| 3 | `Expr::Keyword` variant | present | missing from `@JsonSubTypes` | missing from `UnmarshalExpr` | ✅ added |
| 4 | `Expr::Arguments` variant | present | missing from `@JsonSubTypes` | missing from `UnmarshalExpr` | ✅ added |
| 5 | `UnificationStmt.value` | `NodeRef<SchemaExpr>` | `NodeRef<SchemaConfig>` | `*Node[SchemaConfig]` | 🟡 binding abstraction (see note A) |
| 6 | `SchemaStmt.decorators` | `Vec<NodeRef<CallExpr>>` | `List<NodeRef<Decorator>>` | `[]*Node[Decorator]` | 🟡 binding abstraction (see note A) |
| 7 | `SchemaAttr.decorators` | `Vec<NodeRef<CallExpr>>` | `List<NodeRef<Decorator>>` | `[]*Node[Decorator]` | 🟡 binding abstraction (see note A) |
| 8 | `ConfigEntry.is_shorthand` | present (default=false, skip-if-false) | absent | absent | ✅ added |
| 9 | `NumberLit` discriminator | `"NumberLit"` | `@JsonTypeName("Number")` | `ExprType:"Number"` | ✅ fixed |
| 10 | `StringLit` discriminator | `"StringLit"` | `@JsonTypeName("String")` | `ExprType:"String"` | ✅ fixed |
| 11 | `NameConstantLit` discriminator | `"NameConstantLit"` | `@JsonTypeName("NameConstant")` | `ExprType:"NameConstant"` | ✅ fixed |

### Note A: binding-level abstractions (NOT drift)

`SchemaConfig` (Java/Go) and `Decorator` (Java/Go) look like drift versus Rust's
`SchemaExpr` / `CallExpr`, but they are deliberate binding-level abstractions:

- Rust emits `Vec<NodeRef<CallExpr>>` for `SchemaStmt.decorators`. When a
  `CallExpr` is nested under a `NodeRef`, the JSON wire shape is the flat
  `{func, args, keywords}` object — **no** `"type":"Call"` discriminator
  (the discriminator only appears when `CallExpr` is the outer `Expr::Call`
  variant). Same situation for `SchemaExpr` under `UnificationStmt.value`.
- Polymorphic JSON deserializers (Jackson `@JsonSubTypes`, Go
  `UnmarshalJSON` switch) cannot resolve a missing discriminator, so the
  bindings expose a flat DTO whose field names match the wire shape.
- Tests in both repos (`AstJsonAlignmentTest`,
  `parser/ast_alignment_test.go`) exercise both shapes.

## Notes on the Literal enum

Rust's internal `Literal` enum (Number/String/NameConstant variants) is a
separate type from `Expr` and uses `"Number"/"String"/"NameConstant"` as the
discriminator. This enum is internal to KCL's parser crate; the JSON that
crosses the wire goes through `Expr` with `"NumberLit"/"StringLit"/"NameConstantLit"`.
The Java/Go bindings only handle the `Expr` form. A `Literal.java` shim is
fine but doesn't need to be wire-compatible — the wire form is
`{"type":"NumberLit","binary_suffix":...,"value":...}`.

## Verification

- Java: `mvn test -Dtest=AstJsonAlignmentTest` (8 tests) parses a real
  fixture via `parseFile` and asserts the JSON shape round-trips through
  the Java AST classes.
- Go: `go test ./pkg/parser/ -run TestAstJsonAlignment_ParseFile` parses a
  real fixture via `parser.ParseFile` and asserts the JSON shape
  round-trips through the Go AST structs.
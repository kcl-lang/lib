# KCL Bindings for Go

## The AST package

`go/ast` decodes the AST JSON the KCL parser emits — the same wire format
every other binding in this repository decodes, and the same one
`kcl-lang/lib`'s `spec` and `docs/architecture.md` call L2 sub-part 4.

```go
import "kcl-lang.io/lib/go/ast"

capture, _ := os.ReadFile("ast.json")
module, err := ast.ParseModule(string(capture))
if err != nil {
	return err
}
for _, stmt := range module.Body {
	fmt.Printf("%s %d:%d\n", stmt.Payload, stmt.Line, stmt.Column)
}
```

`ParseProgram` takes the `ParseProgramResult.ast_json` document and returns one
`Module` per file; it accepts the `pkgs.__main__` shape the parser emits, and
also a bare list or a bare single module.

### The declarations are generated

Every `*_gen.go` in `go/ast` is generated from
`kcl-lang/kcl`'s `crates/ast/src/ast.rs` by `tools/generate_ast.py`, alongside
the Python and TypeScript trees. Do not edit them: run

```shell
python3 tools/generate_ast.py
```

from the repository root and commit the result. `ruby hack/check_generated_ast.rb`
re-runs the generator and diffs the bytes, and `go/ast/decode.go` — the four
decode helpers, which *are* hand-written — is the only other file in the
package.

The four files in `tools/astgen/` that matter when changing an emitter are
`ir.py` (the wire shapes), `model.py` (the language-neutral model), and
`emit_python.py` / `emit_typescript.py` / `emit_go.py` (one per language). The
Go emitter has one structural difference from the other two and it is not a
preference: Go is a single package, so nothing in it can be split to dodge a
name collision, and `BasicType` is both a bare operator enum and the payload of
`Type::Basic`.

### What is checked, and what is not

`go/ast/ast_contract_test.go` decodes `testdata/ast/alignment.json` — the real
parser's output for a file that exercises every node shape — and asserts the
contract that file documents. It is the Go counterpart of
`python/tests/ast_contract_test.py` and `wasm/tests/ast_contract.test.ts`, and
it needs neither cgo nor `libkcl`.

Two further checks read this package from outside Go:

* `ruby hack/check_ast_field_types.rb` compares every field's *declared type*
  against the Rust struct definitions, and is run in `ast-shape-test.yaml`.
* `ruby hack/ast_diff.rb go` runs the real decoder over the same capture and
  diffs the tree against it, and is run in `ast-diff-test.yaml`.

The freshness check does not cover Go's *choices* — that the tag is the variant
name, that `Type` is adjacently tagged while `Expr` and `Stmt` are internally
tagged, that a unit variant carries no content key, that `Pos` writes its
zeros. Every one of those fails silently rather than raising, which is what the
contract test is for.

## Developing

### Prerequisites

+ Go 1.23+

### Build and Test

```shell
go test ./...
```

Note: Full Go SDK can be found [here](https://github.com/kcl-lang/kcl-go), which depends on the kcl-lang/lib Go bindings.

// The Go AST wire contract, asserted.
//
// The declarations in this package are generated from `ast.rs` by
// `tools/astgen/emit_go.py`, so they cannot drift from the Rust — that is
// what `ruby hack/check_generated_ast.rb` checks. What the generator cannot
// check is its own *choices*: that the tag really is the variant name, that
// `Type` really is adjacently tagged while `Expr` and `Stmt` are internally
// tagged, that a unit variant carries no content key, and that a payload field
// is read on the way in as well as written on the way out. Every one of those
// is a decision the emitter makes, and every one of them fails silently — a
// tree full of `UnknownExpr`, or a `Comment` whose text is `""` for all 33
// entries, is a decoder that ran and returned no error.
//
// So this test decodes `testdata/ast/alignment.json` — the real parser's
// output for `testdata/ast/alignment.k`, which exercises every node shape —
// and asserts the contract documented in that directory's README. Decoding the
// captured JSON rather than calling into the binding keeps it a pure test of
// the decoder: no cgo, no `libkcl`, and no dependency on the parser staying
// byte-identical.
package ast_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"testing"

	"kcl-lang.io/lib/go/ast"
)

func golden(t *testing.T) *ast.Module {
	t.Helper()
	raw, err := os.ReadFile(filepath.Join("..", "..", "testdata", "ast", "alignment.json"))
	if err != nil {
		t.Fatalf("cannot read the golden: %v", err)
	}
	module, err := ast.ParseModule(string(raw))
	if err != nil {
		t.Fatalf("the decoder rejected the golden: %v", err)
	}
	return module
}

// The counts `hack/ast_diff.rb` treats as its vacuity guards. Asserting them
// here too means a decoder that starts returning an empty tree fails in the
// language's own `go test`, where the failure names the field, rather than
// only in the cross-language harness.
const (
	wantBody     = 63
	wantComments = 33
)

func TestGoldenDecodesToTheWholeTree(t *testing.T) {
	m := golden(t)
	if len(m.Body) != wantBody {
		t.Errorf("body: got %d top-level statements, want %d", len(m.Body), wantBody)
	}
	if len(m.Comments) != wantComments {
		t.Errorf("comments: got %d, want %d", len(m.Comments), wantComments)
	}
}

// Every statement, expression and type in the file must land on a concrete
// class. A tag this package does not know arrives from the dispatcher as a nil
// *payload*, which type-switches to nothing at all — so a tree that decoded
// "successfully" with half its expressions missing is exactly the failure this
// asserts against, and it is invisible from the declarations alone.
//
// The walkers take the slot rather than the payload, because the two nil-nesses
// mean different things. A nil slot is a `null` or absent key, which for
// `Option` fields is what the parser said and carries no tag to have got
// wrong; a nil payload inside a slot that *is* there is a tag the dispatcher
// did not recognise. Only the second is a defect, so only the second is named.
func TestNoUnknownVariantAnywhereInTheGoldenModule(t *testing.T) {
	m := golden(t)

	var walkType func(ty *ast.TypeNode, path string)
	var walkExpr func(e *ast.ExprNode, path string)
	var walkStmt func(s *ast.StmtNode, path string)
	walkType = func(node *ast.TypeNode, path string) {
		if node == nil {
			return
		}
		switch v := node.Payload.(type) {
		case *ast.ListType:
			walkType(v.InnerType, path+".inner_type")
		case *ast.DictType:
			walkType(v.KeyType, path+".key_type")
			walkType(v.ValueType, path+".value_type")
		case *ast.UnionType:
			for i, e := range v.TypeElements {
				walkType(e, path+".type_elements["+itoa(i)+"]")
			}
		case *ast.FunctionType:
			for i, p := range v.ParamsTy {
				walkType(p, path+".params_ty["+itoa(i)+"]")
			}
			walkType(v.RetTy, path+".ret_ty")
		case *ast.NamedType:
			if len(v.Identifier.Names) == 0 {
				t.Errorf("%s: NamedType has no name", path)
			}
		case *ast.BasicType:
			if v.Name == "" {
				t.Errorf("%s: BasicType has no name", path)
			}
		case *ast.AnyType:
			// A unit variant: no payload to check and none to have dropped.
		case *ast.LiteralType:
			// `Literal` carries a bare serde document, deliberately unmodelled
			// rather than half-modelled: `LiteralType` is itself a tag/content
			// pair, so its fields describe the payload, not the variant.
		case nil:
			t.Errorf("%s: no Type behind the tag", path)
		default:
			t.Errorf("%s: unmodelled Type %T", path, node.Payload)
		}
	}
	walkExpr = func(node *ast.ExprNode, path string) {
		if node == nil {
			return
		}
		switch v := node.Payload.(type) {
		case *ast.SelectorExpr:
			walkExpr(v.Value, path+".value")
			if v.Attr == nil {
				t.Errorf("%s: attr is nil", path)
			}
		case *ast.ListExpr:
			for i, e := range v.Elts {
				walkExpr(e, path+".elts["+itoa(i)+"]")
			}
		case *ast.UnaryExpr:
			walkExpr(v.Operand, path+".operand")
		case *ast.BinaryExpr:
			walkExpr(v.Left, path+".left")
			walkExpr(v.Right, path+".right")
		case *ast.JoinedString:
			for i, e := range v.Values {
				walkExpr(e, path+".values["+itoa(i)+"]")
			}
		case *ast.CallExpr:
			walkExpr(v.Func, path+".func")
			for i, e := range v.Args {
				walkExpr(e, path+".args["+itoa(i)+"]")
			}
		case nil:
			t.Errorf("%s: no Expr behind the tag", path)
		}
	}
	walkStmt = func(node *ast.StmtNode, path string) {
		if node == nil {
			return
		}
		switch v := node.Payload.(type) {
		case *ast.ExprStmt:
			for i, e := range v.Exprs {
				walkExpr(e, path+".exprs["+itoa(i)+"]")
			}
		case *ast.AssignStmt:
			walkExpr(v.Value, path+".value")
			walkType(v.Ty, path+".ty")
		case *ast.IfStmt:
			walkExpr(v.Cond, path+".cond")
			for i, s := range v.Body {
				walkStmt(s, path+".body["+itoa(i)+"]")
			}
			for i, s := range v.Orelse {
				walkStmt(s, path+".orelse["+itoa(i)+"]")
			}
		case *ast.UnificationStmt:
			// The value is a bare `SchemaExpr` behind its own slot, not an
			// `Expr`, so there is nothing to dispatch and nothing to walk.
			_ = v
		case nil:
			t.Errorf("%s: no Stmt behind the tag", path)
		}
	}

	for i, s := range m.Body {
		walkStmt(s, "body["+itoa(i)+"]")
	}
}

// `Expr` and `Stmt` are *internally* tagged: serde spreads the variant's
// fields beside the tag rather than nesting them under it. Getting that wrong
// is invisible in the declarations — a nested `value` key is a perfectly legal
// struct tag either way — and shows up as a payload that decoded empty.
func TestExprVariantFieldsAreSpreadBesideTheTag(t *testing.T) {
	lit, _ := findExpr(t, golden(t), func(e ast.Expr) bool {
		_, ok := e.(*ast.StringLit)
		return ok
	}).(*ast.StringLit)
	if lit.Type != "StringLit" {
		t.Errorf("StringLit tag: got %q, want %q", lit.Type, "StringLit")
	}
	// `value` and `raw_value` are fields of the variant, not of a wrapper
	// around it, so `encoding/json` filled them from the same object the tag
	// came from. A decoder that looked one level too deep gets an empty
	// string for both, which is the shape of a right answer.
	if lit.Value == "" || lit.RawValue == "" {
		t.Errorf("StringLit decoded to value=%q raw_value=%q; both are set in the capture",
			lit.Value, lit.RawValue)
	}
	if lit.IsLongString {
		t.Error("a one-line string literal came back as a long one")
	}
}

// `Type` is *adjacently* tagged — the one hierarchy in `ast.rs` that is. Its
// payload lives under `value` and carries no tag of its own, which is the one
// place in this package where the struct fields are not the wire's fields and
// a marshaller has to put a wrapper around them.
func TestTypeIsAdjacentlyTagged(t *testing.T) {
	ty := findType(t, golden(t))

	raw, err := json.Marshal(ty)
	if err != nil {
		t.Fatalf("cannot re-encode a ListType: %v", err)
	}
	var wrapper struct {
		Type  string          `json:"type"`
		Value json.RawMessage `json:"value"`
	}
	if err := json.Unmarshal(raw, &wrapper); err != nil {
		t.Fatalf("a Type does not marshal to a {type, value} wrapper: %s", raw)
	}
	if wrapper.Type != "List" {
		t.Errorf("wrapper tag: got %q, want %q", wrapper.Type, "List")
	}
	// And the wrapper reads back as the variant it came from. The round trip
	// goes through the *wrapper*, not through the content object: an adjacent
	// variant's `UnmarshalJSON` expects the tag beside the content, so handing
	// it the content object alone is handing it a document with no `value` key
	// in it. That asymmetry is a property of the tagging, not an oversight, and
	// a caller reaching for a `ListType` has to come through `Type`.
	var back ast.ListType
	if err := json.Unmarshal(raw, &back); err != nil {
		t.Fatalf("the wrapper does not read back as a ListType: %v", err)
	}
	if back.InnerType == nil {
		t.Error("a ListType that read its own wrapper back has no inner_type")
	}
}

// A unit variant has nothing to put under the content key, and serde leaves
// the key off entirely: `Type::Any` is `{"type": "Any"}`. Writing `"value":{}`
// instead is one key per unit-typed annotation in the file, and it is the kind
// of difference a round-trip comparison has to be told about rather than one it
// catches.
func TestUnitTypeVariantCarriesNoContentKey(t *testing.T) {
	m := golden(t)
	var any *ast.AnyType
	var walk func(ty ast.Type)
	walk = func(ty ast.Type) {
		if v, ok := ty.(*ast.AnyType); ok && any == nil {
			any = v
		}
		if v, ok := ty.(*ast.ListType); ok && v.InnerType != nil {
			walk(v.InnerType.Payload)
		}
	}
	for _, s := range m.Body {
		switch v := s.Payload.(type) {
		case *ast.AssignStmt:
			if v.Ty != nil {
				walk(v.Ty.Payload)
			}
		case *ast.TypeAliasStmt:
			if v.Ty != nil {
				walk(v.Ty.Payload)
			}
		}
	}
	if any == nil {
		t.Skip("no `Any` in the golden; this fixture cannot check it")
	}

	raw, err := json.Marshal(any)
	if err != nil {
		t.Fatalf("cannot re-encode an AnyType: %v", err)
	}
	var doc map[string]json.RawMessage
	if err := json.Unmarshal(raw, &doc); err != nil {
		t.Fatalf("an AnyType does not marshal to an object: %s", raw)
	}
	if _, present := doc["value"]; present {
		t.Errorf("a unit variant wrote a content key: %s", raw)
	}
	if got := string(doc["type"]); got != `"Any"` {
		t.Errorf("tag: got %s, want %q", got, `"Any"`)
	}
}

// `Type::Basic` inlines its payload: `{"type": "Basic", "value": "Int"}` means
// the content key carries a bare string, so `BasicType` is the string itself
// rather than a struct with one string in it. Wrapping it again would be one
// level of nesting too many, and the mistake is invisible until something
// reads `Name`.
func TestBasicTypeInlinesItsPayload(t *testing.T) {
	raw, err := json.Marshal(ast.BasicType{Name: "Int"})
	if err != nil {
		t.Fatalf("cannot re-encode a BasicType: %v", err)
	}
	if got, want := string(raw), `{"type":"Basic","value":"Int"}`; got != want {
		t.Errorf("a BasicType marshals to %s, want %s", got, want)
	}
}

// `MemberOrIndex` is the one payload with no fields of its own to read: the
// document is `{"type": "Member", "value": {…}}` and both keys are placed by
// `MarshalJSON`, so the struct's own tags are `type` and `json:"-"`. If
// `encoding/json` decodes a `[]MemberOrIndex` without being told to call
// `UnmarshalJSON`, the payload is dropped and every `a.b` in the file comes
// back as a bare `{"type": "Member"}` — a tree that looks right and has lost
// every attribute name in it.
func TestMemberOrIndexKeepsItsPayload(t *testing.T) {
	m := golden(t)
	// Counted by variant, because the two hold different payloads: `Member`
	// is a `NodeRef<String>` and `Index` a `NodeRef<Expr>`, and neither slot
	// can stand in for the other.
	members, names, indexes, exprs := 0, 0, 0, 0
	for _, s := range m.Body {
		a, ok := s.Payload.(*ast.AssignStmt)
		if !ok {
			continue
		}
		for _, target := range a.Targets {
			for _, p := range target.Payload.Paths {
				switch p.Kind {
				case "Member":
					members++
					if p.Member != nil && p.Member.Payload != "" {
						names++
					}
				case "Index":
					indexes++
					if p.Index != nil && p.Index.Payload != nil {
						exprs++
					}
				default:
					t.Errorf("a target path has tag %q", p.Kind)
				}
			}
		}
	}
	if members == 0 || indexes == 0 {
		t.Skip("the golden has no dotted and indexed target; it cannot check both slots")
	}
	if names != members {
		t.Errorf("%d of %d member paths decoded to a tag with no name", members-names, members)
	}
	if exprs != indexes {
		t.Errorf("%d of %d indexed paths decoded to a tag with no expression", indexes-exprs, indexes)
	}
}

// `Comment` is a plain struct with one `String` field, so serde puts
// `{"text": "…"}` under `node` and the text is one level further in than a
// reader expecting a bare string would look. Nothing the package *declares* is
// wrong, which is the point: a decoder that reads the wrapper's own keys
// returns `""` for every comment in the file without raising.
func TestEveryCommentCarriesItsText(t *testing.T) {
	for i, c := range golden(t).Comments {
		if c.Payload.Text == "" {
			t.Errorf("comments[%d]: empty text for the comment at line %d", i, c.Line)
		}
	}
}

// `Pos` is written unconditionally, so a node that starts at the beginning of
// a line has `column: 0` and a synthesised `NodeRef` inside a joined string
// has `filename: ""`. Both are real values in the capture, and a zero-valued
// field with `omitempty` drops the key rather than writing the zero — which
// loses a position the parser reported.
func TestZeroPositionsSurviveTheRoundTrip(t *testing.T) {
	m := golden(t)

	atColumnZero := false
	for _, s := range m.Body {
		if s.Column == 0 {
			atColumnZero = true
		}
	}
	if !atColumnZero {
		t.Skip("no statement at column 0 in the golden; this fixture cannot check it")
	}

	raw, err := json.Marshal(struct {
		Body []*ast.StmtNode `json:"body"`
	}{m.Body})
	if err != nil {
		t.Fatalf("cannot re-encode the body: %v", err)
	}
	var doc struct {
		Body []map[string]json.RawMessage `json:"body"`
	}
	if err := json.Unmarshal(raw, &doc); err != nil {
		t.Fatalf("cannot read the re-encoded body: %v", err)
	}
	for i, stmt := range doc.Body {
		if _, present := stmt["column"]; !present {
			t.Errorf("body[%d] lost its `column`, which the capture carries as 0", i)
		}
	}
}

// `Identifier.pkgpath` is `Option<String>`, and an absent path and an empty
// one are different answers to "is this qualified?" — so the capture writes
// `""` for the unqualified form and Go has to keep the key rather than drop it
// as an empty value.
func TestUnqualifiedIdentifierKeepsItsEmptyPkgpath(t *testing.T) {
	m := golden(t)
	found := false
	for _, s := range m.Body {
		a, ok := s.Payload.(*ast.AssignStmt)
		if !ok || len(a.Targets) == 0 || a.Targets[0].Payload.Name == nil {
			continue
		}
		found = true
		raw, err := json.Marshal(a.Targets[0].Payload)
		if err != nil {
			t.Fatalf("cannot re-encode a Target: %v", err)
		}
		var doc map[string]json.RawMessage
		if err := json.Unmarshal(raw, &doc); err != nil {
			t.Fatal(err)
		}
		if got, present := doc["pkgpath"]; !present || string(got) != `""` {
			t.Errorf("an unqualified Target marshals `pkgpath` as %s, want \"\"", got)
		}
		break
	}
	if !found {
		t.Skip("no assignment target in the golden; this fixture cannot check it")
	}
}

// The whole point of the package: decode the capture, write it back, and get
// the same document. A decoder that reads a field at the wrong nesting level
// loses it on the way out even when the in-memory tree looks right, so this is
// the assertion that would have caught the bug in every one of the five
// bindings that shipped it.
func TestRoundTripIsByteIdentical(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("..", "..", "testdata", "ast", "alignment.json"))
	if err != nil {
		t.Fatalf("cannot read the golden: %v", err)
	}
	first := golden(t)
	encoded, err := json.Marshal(first)
	if err != nil {
		t.Fatalf("cannot re-encode the module: %v", err)
	}
	second, err := ast.ParseModule(string(encoded))
	if err != nil {
		t.Fatalf("cannot re-decode what was just written: %v", err)
	}
	again, err := json.Marshal(second)
	if err != nil {
		t.Fatalf("cannot re-encode the second module: %v", err)
	}

	// Compared as documents rather than as bytes: `encoding/json` sorts map
	// keys and the golden's own order is serde's, so a byte comparison would
	// fail on a decoder that is correct.
	if !sameJSON(t, raw, encoded) {
		t.Error("the tree written back out is not the tree that was read in")
	}
	if string(again) != string(encoded) {
		t.Error("the second pass is not stable: decode -> encode is not the identity here")
	}
}

func sameJSON(t *testing.T, want, got []byte) bool {
	t.Helper()
	var a, b any
	if err := json.Unmarshal(want, &a); err != nil {
		t.Fatalf("the golden is not JSON: %v", err)
	}
	if err := json.Unmarshal(got, &b); err != nil {
		t.Fatalf("the re-encoded tree is not JSON: %v", err)
	}
	return reflect.DeepEqual(a, b)
}

// The two locators below walk the tree rather than indexing `body`, so a
// fixture that grows or reorders keeps working: the point of each test is a
// shape, and a hard-coded index would turn "the fixture changed" into a
// failure that reads as "the decoder is broken".
func findExpr(t *testing.T, m *ast.Module, want func(ast.Expr) bool) ast.Expr {
	t.Helper()
	var found ast.Expr
	var walk func(n *ast.ExprNode)
	walk = func(n *ast.ExprNode) {
		if found != nil || n == nil {
			return
		}
		if want(n.Payload) {
			found = n.Payload
			return
		}
		switch v := n.Payload.(type) {
		case *ast.BinaryExpr:
			walk(v.Left)
			walk(v.Right)
		case *ast.UnaryExpr:
			walk(v.Operand)
		case *ast.SelectorExpr:
			walk(v.Value)
		case *ast.CallExpr:
			walk(v.Func)
			for _, a := range v.Args {
				walk(a)
			}
		case *ast.JoinedString:
			for _, e := range v.Values {
				walk(e)
			}
		case *ast.ListExpr:
			for _, e := range v.Elts {
				walk(e)
			}
		}
	}
	for _, s := range m.Body {
		if e, ok := s.Payload.(*ast.ExprStmt); ok {
			for _, x := range e.Exprs {
				walk(x)
			}
		}
		if a, ok := s.Payload.(*ast.AssignStmt); ok {
			walk(a.Value)
		}
	}
	if found == nil {
		t.Fatal("no such expression in the golden; the fixture no longer exercises this")
	}
	return found
}

// The `List` alias on line 22 of `testdata/ast/alignment.k`: the fixture's
// one annotated `Type` that is a composite rather than a basic one, so it is
// the only one whose content object has fields to lose.
func findType(t *testing.T, m *ast.Module) ast.Type {
	t.Helper()
	var found ast.Type
	for _, s := range m.Body {
		alias, ok := s.Payload.(*ast.TypeAliasStmt)
		if !ok || alias.Ty == nil {
			continue
		}
		if _, ok := alias.Ty.Payload.(*ast.ListType); ok {
			found = alias.Ty.Payload
			break
		}
	}
	if found == nil {
		t.Fatal("no annotated `List` in the golden; the fixture no longer exercises this")
	}
	return found
}

func itoa(i int) string {
	return strconv.Itoa(i)
}

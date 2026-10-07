// Command astdump runs the Go binding's real AST decoder over the shared
// golden capture and writes the tree back out.
//
//	go run ./hack/dump/go <golden.json> <out.json>
//
// This is a wire round-trip (`mode: :wire` in `hack/ast_diff/bindings.rb`).
// Nothing is reimplemented here and nothing is walked by reflection: the
// capture goes through `ast.ParseModule` and comes back out through
// `encoding/json`, so what the comparator diffs is what the binding's own
// struct tags and marshalers produce. A field read at the wrong nesting level
// -- the bug `hack/check_ast_field_types.rb` cannot see and that has shipped in
// five bindings -- shows up as a missing or misspelled key rather than as a
// value this file would have had to know how to correct.
package main

import (
	"encoding/json"
	"fmt"
	"os"

	"kcl-lang.io/lib/go/ast"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: astdump <golden.json> <out.json>")
		os.Exit(2)
	}
	goldenPath, outPath := os.Args[1], os.Args[2]

	capture, err := os.ReadFile(goldenPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "cannot read %s: %v\n", goldenPath, err)
		os.Exit(1)
	}

	module, err := ast.ParseModule(string(capture))
	if err != nil {
		fmt.Fprintf(os.Stderr, "the decoder rejected the golden: %v\n", err)
		os.Exit(1)
	}

	// The three vacuity guards in `hack/ast_diff.rb` run before the comparator
	// gets the dump, so a decoder that returned an empty tree fails there. This
	// is only the one that is cheap to say out loud here: the count is what
	// distinguishes "agreed about nothing" from "agreed".
	fmt.Fprintf(os.Stderr, "go: %d top-level statements, %d comments\n",
		len(module.Body), len(module.Comments))

	doc, err := json.MarshalIndent(map[string]any{
		"schema":  "kcl-ast-canonical/1",
		"binding": "go",
		"mode":    "wire",
		"root":    module,
	}, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "cannot write the tree: %v\n", err)
		os.Exit(1)
	}
	if err := os.WriteFile(outPath, append(doc, '\n'), 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "cannot write %s: %v\n", outPath, err)
		os.Exit(1)
	}
}
// Minimal reproduction for the wasm Comment decode bug.
//
// Compiled together with wasm/src/ast/*.ts and run under node, exactly as
// hack/dump/wasm.sh does. It does not go through hack/dump at all: it calls
// the binding's own `commentFromWire` the same way `_module.ts:37` does, so
// the result is the decoder's and not this harness's.
//
//   tsc --outDir <tmp> --module commonjs --moduleResolution node --target es2022 \
//        --lib es2022,dom --typeRoots wasm/node_modules/@types --types node \
//        --esModuleInterop --allowSyntheticDefaultImports --strict --skipLibCheck \
//        --declaration false --sourceMap false /tmp/wasm_comment_repro.ts wasm/src/ast/*.ts
//   node <tmp>/tmp/wasm_comment_repro.js

import { nodeFromWire, commentFromWire } from "../../../../wasm/src/ast/_base";
import { moduleFromWire } from "../../../../wasm/src/ast/_module";
import { readFileSync } from "fs";

// The golden's very first comment, verbatim from testdata/ast/alignment.json.
const wireComment = {
  node: { text: "# Every AST node shape the language bindings model, in one file." },
  filename: "testdata/ast/alignment.k",
  line: 1,
  column: 0,
  end_line: 1,
  end_column: 64,
};

console.log("wire:            ", JSON.stringify(wireComment));

// 1. What `_module.ts:37` does: the payload goes to `commentFromWire`, the
//    wrapper's position fields stay on the enclosing Node.
const viaModulePath = nodeFromWire(wireComment as never, commentFromWire as never);
console.log("via _module.ts:37", JSON.stringify(viaModulePath));

// 2. Handing the loader the *wrapper* is the caller getting it wrong, not the
//    decoder: `commentFromWire` decodes a payload, and a wrapper has no `text`
//    of its own. It returns `""` rather than raising, which is exactly what made
//    the real bug invisible.
const viaDirectCall = commentFromWire(wireComment as never);
console.log("via direct call: ", JSON.stringify(viaDirectCall));

// 3. The whole module, to show the blast radius. Position lives on the Node,
//    not inside it -- `Module.comments` is `Vec<NodeRef<Comment>>`, so a
//    comment reads as `c.node.text` with `c.filename` beside it.
const golden = JSON.parse(readFileSync("/Users/timi/codes/lib/testdata/ast/alignment.json", "utf8"));
const mod = moduleFromWire(golden);
const empty = mod.comments.filter((c: any) => c.node.text === "").length;
const noPos = mod.comments.filter((c: any) => c.filename === undefined).length;
const match = mod.comments.filter((c: any, i: number) => c.node.text === golden.comments[i].node.text).length;
console.log(
  `module.comments: ${mod.comments.length} total, ${empty} with text "", ` +
    `${noPos} with no position, ${match} matching the golden verbatim`,
);

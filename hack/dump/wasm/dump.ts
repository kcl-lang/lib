// Cross-language AST dump for the WASM/TypeScript binding.
//
//   hack/dump/wasm.sh <golden.json> <out.json>
//
// Runs the binding's real decoder (`parseModule` from `wasm/src/ast`) over the
// shared capture and writes the tree in the shape
// `hack/ast_diff/canonical.rb` compares.
//
// The TypeScript AST types are `interface`s, so at runtime they are plain
// objects with no class behind them: the walk copies the object graph and
// mirrors an object's `type` string into `@tag`. There is no `@cls` to
// record, so the class cross-check is unavailable for this binding and the
// report says so.
//
// The build script compiles this file *together with* the binding's
// `wasm/src/ast/*.ts` into a temporary directory and runs the result under
// node. Compiling the sources rather than reaching for `wasm/dist/` matters:
// `dist/` is a build artifact and may be stale, and a dumper that silently
// checked yesterday's JavaScript would be a dumper that passes when the
// TypeScript is wrong.
//
// Nothing is renamed and nothing is reshaped.

import { readFileSync, writeFileSync } from "fs";
import { parseModule } from "../../../wasm/src/ast/index";

function dump(value: any): any {
  if (value === null || value === undefined) return value ?? null;
  if (Array.isArray(value)) return value.map(dump);
  if (typeof value !== "object") return value;

  const out: Record<string, any> = {};
  for (const [k, v] of Object.entries(value)) {
    out[k] = dump(v);
  }
  // `type` is kept as an ordinary key *and* mirrored into `@tag`; the
  // comparator drops `@`-prefixed keys and compares `type` on its own, so the
  // mirror costs nothing and gives the tag check a source.
  if (typeof value.type === "string") out["@tag"] = value.type;
  return out;
}

const [goldenPath, outPath] = process.argv.slice(2);
if (!goldenPath || !outPath) {
  console.error("usage: hack/dump/wasm.sh <golden.json> <out.json>");
  process.exit(2);
}

const moduleAst = parseModule(readFileSync(goldenPath, "utf8"));

writeFileSync(
  outPath,
  JSON.stringify(
    {
      schema: "kcl-ast-canonical/1",
      binding: "wasm",
      mode: "reflect",
      root: dump(moduleAst)
    },
    null,
    2
  ) + "\n"
);

#!/usr/bin/env bash
# Build and run the WASM binding's AST dumper.
#
#   hack/dump/wasm.sh <golden.json> <out.json>
#
# Compiles `hack/dump/wasm/dump.ts` *together with* the binding's
# `wasm/src/ast/*.ts` and runs the result under node.
#
# The sources are compiled rather than `wasm/dist/` being reused on purpose.
# `dist/` is a build artifact: it may be older than the TypeScript, and a
# harness that quietly checked stale JavaScript would report agreement for a
# decoder that no longer exists. The binding's own `tsconfig.json` is not used
# because it is rooted at `wasm/src` and this file is not under it; the flags
# below are the same ones it sets for this code (CommonJS, strict, ES2022).
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: hack/dump/wasm.sh <golden.json> <out.json>" >&2
  exit 2
fi

golden="$1"
out="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

tsc="wasm/node_modules/.bin/tsc"
if [ ! -x "$tsc" ]; then
  echo "typescript is not installed: run \`npm i\` in wasm/" >&2
  exit 3
fi

build="$(mktemp -d "${TMPDIR:-/tmp}/kcl-ast-dump-wasm.XXXXXX")"
trap 'rm -rf "$build"' EXIT

# The common root of the inputs is the repository root, so tsc mirrors the
# directory layout under `--outDir` and the relative import inside dump.ts
# keeps resolving. `--typeRoots` is needed because this file is not under
# `wasm/`, so tsc would not find `@types/node` by walking up from it; the
# dependency tree is wasm's and this dumper reuses it rather than asking for
# a second `npm i`.
"$tsc" \
  --outDir "$build" \
  --module commonjs \
  --moduleResolution node \
  --target es2022 \
  --lib es2022,dom \
  --typeRoots wasm/node_modules/@types \
  --types node \
  --esModuleInterop \
  --allowSyntheticDefaultImports \
  --strict \
  --skipLibCheck \
  --declaration false \
  --sourceMap false \
  hack/dump/wasm/dump.ts wasm/src/ast/*.ts

node "$build/hack/dump/wasm/dump.js" "$golden" "$out"

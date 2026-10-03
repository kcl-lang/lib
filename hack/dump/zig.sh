#!/usr/bin/env bash
# Build and run the Zig binding's AST dumper.
#
#   hack/dump/zig.sh <golden.json> <out.json>
#
# `zig build` is not used: it needs the protobuf code generator and the
# protobuf dependency resolved out of `build.zig.zon`, and the AST package
# needs neither — `zig/src/ast.zig` is self-contained and reaches `std` only.
# So the dumper is compiled directly with `zig build-exe` against that one
# module, which also means this checks the AST sources as they are on disk
# rather than whatever `zig-out/` happens to hold.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: hack/dump/zig.sh <golden.json> <out.json>" >&2
  exit 2
fi

golden="$1"
out="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

if ! command -v zig >/dev/null 2>&1; then
  echo "no zig on PATH" >&2
  exit 3
fi

build="$(mktemp -d "${TMPDIR:-/tmp}/kcl-ast-dump-zig.XXXXXX")"
trap 'rm -rf "$build"' EXIT

# `--dep ast -Mroot=... -Mast=zig/src/ast.zig` names the `ast` module the
# dumper's `@import("ast.zig")` resolves. The AST package is its own module
# root and pulls in `ast/*.zig` with relative paths, so it needs no further
# modules and no network.
zig build-exe \
  -OReleaseSafe \
  --cache-dir "$build/cache" \
  --global-cache-dir "$build/gcache" \
  --dep ast \
  -Mroot=hack/dump/zig/main.zig \
  -Mast=zig/src/ast.zig \
  --name astdump \
  -femit-bin="$build/astdump"

"$build/astdump" "$golden" "$out"

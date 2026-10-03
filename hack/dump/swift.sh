#!/usr/bin/env bash
# Build and run the Swift binding's AST dumper.
#
#   hack/dump/swift.sh <golden.json> <out.json>
#
# `swift run` is not used: SwiftPM wants to resolve the package graph over the
# network, and this binding is being edited by other agents, so a fetch is both
# slow and a way for the harness to fail for reasons that have nothing to do
# with the decoders. The two AST sources are standalone Foundation code with no
# dependency on the C shim or the protobuf service, so they are compiled
# directly:
#
#   swiftc -parse-as-library Sources/KclLibAST/Pos.swift \
#          Sources/KclLibAST/AstJson.swift hack/dump/swift/main.swift
#
# A dumper that compiled the *sources* rather than reusing `.build/` is on
# purpose, for the same reason `hack/dump/wasm.sh` compiles the TypeScript:
# a build artifact may be older than the code, and a harness that silently
# checked yesterday's decoder would report agreement for a decoder that no
# longer exists.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: hack/dump/swift.sh <golden.json> <out.json>" >&2
  exit 2
fi

golden="$1"
out="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "no swiftc on PATH" >&2
  exit 3
fi

build="$(mktemp -d "${TMPDIR:-/tmp}/kcl-ast-dump-swift.XXXXXX")"
trap 'rm -rf "$build"' EXIT

swiftc -O -swift-version 5 \
  -o "$build/dump" \
  swift/Sources/KclLibAST/Pos.swift \
  swift/Sources/KclLibAST/AstJson.swift \
  hack/dump/swift/main.swift

"$build/dump" "$golden" "$out"

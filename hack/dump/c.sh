#!/usr/bin/env bash
# Build and run the C binding's AST dumper.
#
#   hack/dump/c.sh <golden.json> <out.json>
#
# Nothing is linked against `libkcl`. `c/lib/kcl_lib_ast.c` is standalone C
# — the JSON parser is embedded in the header, the AST is plain structs and
# an arena — so a dump needs a C compiler, the include directory and that
# one source file. Not `cargo build --release`, not `libkcl.dylib`, not
# `c/Makefile`'s protobuf sources, none of which the decoder touches.
#
# The *source* is compiled rather than an object reused from `c/build/`, for
# the same reason `hack/dump/swift.sh` and `hack/dump/java.sh` compile
# theirs: a build artifact may be older than the code, and a harness that
# silently checked yesterday's decoder would report agreement for a decoder
# that no longer exists.
#
# No `-Werror`: a compiler stricter than the one the binding is built with
# would turn a warning in `kcl_lib_ast.c` itself into a harness failure,
# which is not a finding about the decoder. Warnings the *dumper* earns are
# still visible in the log.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: hack/dump/c.sh <golden.json> <out.json>" >&2
  exit 2
fi

golden="$1"
out="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

cc="${CC:-cc}"
if ! command -v "$cc" >/dev/null 2>&1; then
  echo "no \`${cc}\` on PATH (set CC to pick a different compiler)" >&2
  exit 3
fi
if ! "$cc" --version >/dev/null 2>&1; then
  echo "\`${cc} --version\` fails: there is a ${cc} on PATH but it cannot run" >&2
  "$cc" --version >&2 || true
  exit 3
fi

build="$(mktemp -d "${TMPDIR:-/tmp}/kcl-ast-dump-c.XXXXXX")"
trap 'rm -rf "$build"' EXIT

"$cc" -std=c99 -Wall -Wextra \
  -Ic/include \
  -o "$build/dump" \
  hack/dump/c/Dump.c c/lib/kcl_lib_ast.c

"$build/dump" "$golden" "$out"

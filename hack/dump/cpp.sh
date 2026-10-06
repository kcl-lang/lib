#!/usr/bin/env bash
# Build and run the C++ binding's AST dumper.
#
#   hack/dump/cpp.sh <golden.json> <out.json>
#
# Nothing is linked. `cpp/include/kcl_ast.hpp` and the `kcl_ast_json.hpp` it
# pulls in are both header-only and carry their own decoder, so a dump needs
# a C++17 compiler and the include directory — not `cargo build --release`,
# not cmake, not the cxx bridge. `cpp/CMakeLists.txt` builds the whole
# `kcl-lib-cpp` library around that header, and all of it is irrelevant to
# decoding an AST.
#
# `-std=c++17` is the language level `cpp/CMakeLists.txt` pins
# (`CMAKE_CXX_STANDARD 17`), so a C++20 construct in the dumper is a compile
# error here rather than something that happens to work on a newer compiler
# and fails on the one the build matrix uses.
#
# The *sources* are compiled rather than an object file reused from
# `cpp/build/`, for the same reason `hack/dump/swift.sh` and
# `hack/dump/java.sh` compile theirs: a build artifact may be older than the
# code, and a harness that silently checked yesterday's decoder would report
# agreement for a decoder that no longer exists.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: hack/dump/cpp.sh <golden.json> <out.json>" >&2
  exit 2
fi

golden="$1"
out="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

cxx="${CXX:-c++}"
if ! command -v "$cxx" >/dev/null 2>&1; then
  echo "no \`${cxx}\` on PATH (set CXX to pick a different compiler)" >&2
  exit 3
fi
if ! "$cxx" --version >/dev/null 2>&1; then
  echo "\`${cxx} --version\` fails: there is a ${cxx} on PATH but it cannot run" >&2
  "$cxx" --version >&2 || true
  exit 3
fi

build="$(mktemp -d "${TMPDIR:-/tmp}/kcl-ast-dump-cpp.XXXXXX")"
trap 'rm -rf "$build"' EXIT

# No `-Werror`: a compiler that is stricter than the one the binding is built
# with would turn a warning in `kcl_ast.hpp` itself into a harness failure,
# which is not a finding about the decoder. Warnings the *dumper* earns are
# still visible in the log.
"$cxx" -std=c++17 -Wall \
  -Icpp/include \
  -o "$build/dump" \
  hack/dump/cpp/Dump.cpp

"$build/dump" "$golden" "$out"
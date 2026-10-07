#!/usr/bin/env bash
# Build and run the Go binding's AST dumper.
#
#   hack/dump/go.sh <golden.json> <out.json>
#
# `go run` is used rather than a checked-in binary: the AST package is pure Go
# with no cgo, so it builds anywhere the toolchain does, and reading the sources
# as they are on disk is the point -- a dump of whatever `go/bin` happens to
# hold would be checking the wrong tree.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: hack/dump/go.sh <golden.json> <out.json>" >&2
  exit 2
fi

golden="$1"
out="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The harness passes repo-relative paths, but an absolute one has to stay
# absolute: prefixing the repo root onto `/tmp/x.json` would write to a path
# that does not exist and report it as a decode failure.
abspath() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s\n' "$root/$1" ;;
  esac
}
golden="$(abspath "$golden")"
out="$(abspath "$out")"

if ! command -v go >/dev/null >&1; then
  echo "no go on PATH" >&2
  exit 3
fi

cd "$root/hack/dump/go"
go run . "$golden" "$out"
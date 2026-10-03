#!/usr/bin/env bash
# Build and run the .NET binding's AST dumper.
#
#   hack/dump/dotnet.sh <golden.json> <out.json>
#
# `dotnet run` against `hack/dump/dotnet/Dump.csproj`, which project-references
# `dotnet/KclLib.AST`. The sources are compiled rather than a prebuilt DLL
# being reused, for the same reason `hack/dump/wasm.sh` compiles the
# TypeScript: a build artifact may be older than the code, and a harness that
# quietly checked a stale decoder would report agreement for a decoder that no
# longer exists.
#
# `dotnet` is not always on PATH — a `dotnet-install.sh` SDK lands in
# `~/.dotnet` and the shell that installed it may not have been the shell
# running this. So the script looks there too, and the comparator's probe
# checks the same two places so the two cannot disagree about whether this
# binding is runnable.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: hack/dump/dotnet.sh <golden.json> <out.json>" >&2
  exit 2
fi

golden="$1"
out="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

dotnet_bin="$(command -v dotnet || true)"
if [ -z "$dotnet_bin" ] && [ -x "$HOME/.dotnet/dotnet" ]; then
  dotnet_bin="$HOME/.dotnet/dotnet"
fi
if [ -z "$dotnet_bin" ]; then
  echo "no \`dotnet\` on PATH and none at \$HOME/.dotnet/dotnet" >&2
  exit 3
fi

# `--nologo` is deliberately absent: after `-v quiet` the `dotnet run` parser
# treats it as consuming the next argument, which ate `--` and shifted every
# path by one, so the dumper saw zero arguments and printed its usage.
#
# The paths are passed through as given. The `cd "$root"` above makes a
# relative one resolve against the repository, and an absolute one — which is
# what the harness passes, since it dumps into a temp dir — works either way.
"$dotnet_bin" run --project hack/dump/dotnet/Dump.csproj \
  -v quiet -- "$golden" "$out"

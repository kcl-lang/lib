#!/usr/bin/env bash
# Build and run the Java binding's AST dumper.
#
#   hack/dump/java.sh <golden.json> <out.json>
#
# `mvn` is not used. The `compile` phase in java/pom.xml is bound to
# `python3 scripts/build.py`, which builds the Rust JNI shim, and the AST
# dumper needs none of that: `com.kcl.ast` is plain Java over Jackson, and the
# whole point of the exercise is to check the decoder, not the transport. So
# this compiles the AST sources plus the dumper against the Jackson jars
# directly.
#
# It compiles the *sources* rather than reusing `target/classes`, for the same
# reason `hack/dump/swift.sh` compiles the Swift sources and
# `hack/dump/wasm.sh` compiles the TypeScript: a build artifact may be older
# than the code, and a harness that silently checked yesterday's decoder would
# report agreement for a decoder that no longer exists.
#
# The classpath is resolved with `mvn dependency:build-classpath` rather than
# hand-listed, so the dumper cannot drift onto a different Jackson than the one
# the binding's pom declares.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: hack/dump/java.sh <golden.json> <out.json>" >&2
  exit 2
fi

golden="$1"
out="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

# `java` is a stub on a machine with no JRE, so ask for the compiler by name
# and let the shell report it missing rather than running a broken launcher.
javac="$(command -v javac || true)"
java_bin="$(command -v java || true)"
if [ -z "$javac" ] || [ -z "$java_bin" ]; then
  echo "no JDK on PATH (both javac and java are needed: javac to build the dumper, java to run it)" >&2
  exit 3
fi
if ! "$java_bin" -version >/dev/null 2>&1; then
  echo "\`java -version\` fails: there is a javac on PATH but no runtime behind it" >&2
  "$java_bin" -version >&2 || true
  exit 3
fi

build="$(mktemp -d "${TMPDIR:-/tmp}/kcl-ast-dump-java.XXXXXX")"
trap 'rm -rf "$build"' EXIT

# Online, deliberately. `dependency:build-classpath` is the only way to learn
# the Jackson version the pom actually declares without duplicating it here, and
# a cold CI runner has an empty local maven repository — asking maven to resolve
# that classpath offline would fail before the dumper ever ran, and it would
# fail as a *classpath* error rather than as a decoder error. The CI job sets
# `cache: 'maven'`, so the warm path is the normal one and this is the cold
# fallback.
mvn -q -f java/pom.xml \
  dependency:build-classpath -Dmdep.outputFile="$build/cp.txt" >/dev/null

# `com.kcl.ast`, the `com.kcl.loader.*` types `JsonUtil` names, and
# `JsonUtil` itself — the binding's real entry point for turning `ast_json`
# into a tree, which is the code path a Java caller actually goes through.
#
# `com.kcl.util.SematicUtil` is deliberately left out: it is symbol/scope
# resolution over `LoadPackageResult`, which drags in the generated
# `com.kcl.api.Spec` (six figures of protoc output) and has nothing to do with
# decoding an AST. The dumper needs no part of it, and compiling it would put
# the generated protobuf on the harness's critical path for no gain.
find java/src/main/java/com/kcl/ast java/src/main/java/com/kcl/loader \
     hack/dump/java -name '*.java' > "$build/sources.txt"
echo java/src/main/java/com/kcl/util/JsonUtil.java >> "$build/sources.txt"

# `--release 8` is the language level java/pom.xml declares, so a Java 9+ API
# in the dumper or in `com.kcl.ast` is a compile error here rather than
# something that passes on a new JDK and fails on the zulu 8 the build matrix
# uses. It is also a slightly stricter check than the default: compiling at the
# running JDK's level would happily accept `List.of` or `var`.
javac -nowarn --release 8 -encoding UTF-8 \
  -cp "$(cat "$build/cp.txt")" \
  -d "$build/classes" \
  @"$build/sources.txt"

"$java_bin" -cp "$build/classes:$(cat "$build/cp.txt")" astdump.Dump "$golden" "$out"

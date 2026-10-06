#!/usr/bin/env bash
# Build and run the Kotlin binding's AST dumper.
#
#   hack/dump/kotlin.sh <golden.json> <out.json>
#
# Neither `mvn` nor `kotlinc` is required to be on PATH.
#
# `mvn` is not used for the build: kotlin/pom.xml binds its `compile` phase to
# `python3 scripts/build.py`, which builds the Rust JNI shim, and the AST
# dumper needs none of that — `com.kcl.ast` is plain Java over Jackson and
# `AstWire.kt` is plain Kotlin over the same classes. The one thing maven *is*
# used for is resolving the classpath, so the dumper cannot drift onto a
# different Kotlin or Jackson than the binding's pom declares.
#
# `kotlinc` is not used because kotlin has no Homebrew formula; the compiler
# jar the pom pins (1.9.25) comes from the local maven repository, and invoking
# `K2JVMCompiler` from it is the same compiler the build uses.
#
# The sources are compiled rather than reused from `target/classes`, for the
# same reason `hack/dump/swift.sh` compiles the Swift sources: a build artifact
# may be older than the code, and a harness that silently checked yesterday's
# decoder would report agreement for a decoder that no longer exists.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: hack/dump/kotlin.sh <golden.json> <out.json>" >&2
  exit 2
fi

golden="$1"
out="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

java_bin="$(command -v java || true)"
if [ -z "$java_bin" ]; then
  echo "no \`java\` on PATH" >&2
  exit 3
fi
if ! "$java_bin" -version >/dev/null 2>&1; then
  echo "\`java -version\` fails: there is a compiler on PATH but no runtime behind it" >&2
  "$java_bin" -version >&2 || true
  exit 3
fi
mvn_bin="$(command -v mvn || true)"
if [ -z "$mvn_bin" ]; then
  echo "no \`mvn\` on PATH (needed to resolve the declared classpath and the pinned compiler)" >&2
  exit 3
fi

build="$(mktemp -d "${TMPDIR:-/tmp}/kcl-ast-dump-kotlin.XXXXXX")"
trap 'rm -rf "$build"' EXIT

kotlin_version="$(sed -n 's:.*<kotlin.version>\(.*\)</kotlin.version>.*:\1:p' kotlin/pom.xml | head -1)"
if [ -z "$kotlin_version" ]; then
  echo "could not read <kotlin.version> out of kotlin/pom.xml" >&2
  exit 3
fi
m2="$HOME/.m2/repository"
compiler_jar="$m2/org/jetbrains/kotlin/kotlin-compiler/$kotlin_version/kotlin-compiler-$kotlin_version.jar"

# `dependency:build-classpath` is online, deliberately. It is the only way to
# learn the Jackson and protobuf versions the pom actually declares without
# duplicating them here, and resolving it offline (`-o`) fails outright on a
# cold CI runner whose local maven repository is empty — as a *classpath* error,
# before the dumper has run, which is the one place a harness failure is least
# informative. The CI job sets `cache: 'maven'`, so the warm path is the normal
# one and this is the cold fallback.
mvn -q -f kotlin/pom.xml \
  dependency:build-classpath -Dmdep.outputFile="$build/cp.txt" >/dev/null

# The compiler is a *plugin* dependency, so `dependency:build-classpath` does
# not list it and a runner that has never built this project has never
# downloaded it. `dependency:go-offline` resolves the plugin tree as well as
# the project tree, which is what puts kotlin-compiler, kotlin-stdlib and
# trove4j into the local repository in one step; run once, and only when the
# jar is already known to be missing, so the warm path costs nothing.
if [ ! -f "$compiler_jar" ]; then
  echo "kotlin-compiler $kotlin_version is not in the local maven repository; resolving it." >&2
  mvn -q -f kotlin/pom.xml dependency:go-offline >/dev/null
fi

# The resolved classpath carries *two* kotlin-stdlib jars at different
# versions: `protobuf-kotlin` drags in 1.6.0, and the pom's own
# kotlin.version brings 1.9.25 in behind kotlin-stdlib-jdk8. Left alone,
# whichever comes first wins for the whole compile, and kotlinc then reports
# the loser as
#
#     cannot access class 'com.kcl.ast.AnyType.AnyTypeEnum'.
#     Check your module classpath for missing or conflicting dependencies
#
# which names a symptom forty files away from the cause. So the pinned stdlib
# goes first and every other one is dropped. The version conflict is real and
# is in the pom, but the dumper's job is to check the AST, not to arbitrate
# the dependency tree — so it resolves it here and says so rather than letting
# a classpath problem be reported as a decoder problem.
pinned_stdlib="$HOME/.m2/repository/org/jetbrains/kotlin/kotlin-stdlib/$kotlin_version/kotlin-stdlib-$kotlin_version.jar"
if [ ! -f "$pinned_stdlib" ]; then
  echo "kotlin-stdlib $kotlin_version is not in the local maven repository." >&2
  echo "Run \`mvn -f kotlin/pom.xml dependency:go-offline\` once to fetch it." >&2
  exit 3
fi

cp_value="$pinned_stdlib"
# `|| true`: `read` reports the EOF it hits after the last entry as a failure
# when the file has no trailing newline, which `dependency:build-classpath`
# does not write, and `set -e` would take the whole script down there. The
# array is populated either way.
IFS=':' read -r -a _cp_entries < "$build/cp.txt" || true
for entry in "${_cp_entries[@]}"; do
  case "$(basename "$entry")" in
    kotlin-stdlib-*.jar) continue ;; # superseded by the pinned one above
  esac
  cp_value="$cp_value:$entry"
done

# The `kotlin-compiler` artifact is not the shaded uber-jar `kotlinc` ships, so
# it does not carry its own runtime dependencies. Two are needed before it will
# run a single line:
#
#   * kotlin-stdlib — without it the compiler dies on its first line with
#     `NoClassDefFoundError: kotlin/jvm/internal/Intrinsics`.
#   * trove4j — without it the compiler gets as far as opening the project and
#     then dies with `NoClassDefFoundError: gnu/trove/THashMap`, from the
#     IntelliJ core the file manager is built on.
#
# `kotlin-script-runtime` is on the classpath because the compiler loads it
# when it runs a script, which this dumper is close enough to for the compiler
# to want it present.
compiler_cp="$compiler_jar"
for required in \
  "org/jetbrains/kotlin/kotlin-stdlib/$kotlin_version/kotlin-stdlib-$kotlin_version.jar" \
  "org/jetbrains/kotlin/kotlin-script-runtime/$kotlin_version/kotlin-script-runtime-$kotlin_version.jar"
do
  [ -f "$m2/$required" ] || {
    echo "kotlin runtime jar missing from the local maven repository: $m2/$required" >&2
    echo "The \`dependency:go-offline\` above did not put it there; check the network and retry." >&2
    exit 3
  }
  compiler_cp="$compiler_cp:$m2/$required"
done

# trove4j is versioned independently of the compiler, so it is globbed rather
# than named. A missing trove4j is a skip, not a pass: the reason is printed
# and `ast_diff.rb` counts the binding as unable to run here.
trove_jar="$(find "$m2/org/jetbrains/intellij/deps/trove4j" -name 'trove4j-*.jar' 2>/dev/null | sort | tail -1)"
if [ -z "$trove_jar" ]; then
  echo "trove4j is not in the local maven repository; the kotlin compiler cannot start without it." >&2
  exit 3
fi
compiler_cp="$compiler_cp:$trove_jar"

# `org.jetbrains:annotations` is a *compile* dependency of the project rather
# than of the compiler, so the compiler does not carry it — and it is not
# optional at codegen time. Without it the compiler gets all the way through
# analysis and then dies in the backend:
#
#   Exception while generating code for: FUN name:main …
#   Caused by: java.lang.NoClassDefFoundError: org/jetbrains/annotations/NotNull
#
# i.e. every @NotNull it wants to write onto the dumper's `main` is missing.
# Globbed rather than named, because it is versioned independently.
annotations_jar="$(find "$m2/org/jetbrains/annotations" -name 'annotations-*.jar' 2>/dev/null | sort | tail -1)"
if [ -z "$annotations_jar" ]; then
  echo "org.jetbrains:annotations is not in the local maven repository; the kotlin compiler cannot codegen without it." >&2
  exit 3
fi
compiler_cp="$compiler_cp:$annotations_jar"

mkdir -p "$build/classes"

# Kotlin compiles the java sources alongside the kotlin ones, and the java
# sources have to be passed to kotlinc as *sources* rather than handed over as
# compiled classes. `com.kcl.ast` is a family of package-private Java members —
# `AnyType.value`, `BasicType.value`, `UnionType.value` — and kotlinc will not
# resolve a package-private member of a Java class it only has a `.class` file
# for. Left to work that out from bytecode, it reports
#
#     cannot access class 'com.kcl.ast.AnyType.AnyTypeEnum'.
#     Check your module classpath for missing or conflicting dependencies
#
# which is a classpath problem dressed as a type error, forty lines from its
# cause. `kotlin-maven-plugin` hands the java sources to kotlinc for exactly
# this reason, and so does this script.
#
# `find` on `com/kcl/ast` and `com/kcl/loader` rather than the whole tree, for
# the reason given in `hack/dump/java.sh`: `com.kcl.util.SematicUtil` drags in
# the generated `com.kcl.api.Spec` and has nothing to do with decoding an AST.
find kotlin/src/main/java/com/kcl/ast kotlin/src/main/java/com/kcl/loader \
  -name '*.java' > "$build/java-sources.txt"
echo kotlin/src/main/java/com/kcl/util/JsonUtil.java >> "$build/java-sources.txt"

# `AstBuild.kt` is included even though the dumper does not call it: it is one
# of the two halves of what this binding contributes, and compiling it here
# means a change that breaks the `New*` constructors fails the harness rather
# than waiting for the maven build.
find kotlin/src/main/kotlin/com/kcl/ast hack/dump/kotlin -name '*.kt' \
  > "$build/kt-sources.txt"

# The .kt classes. The java classes are NOT on this classpath — they are in
# the source list below, which is what makes them resolvable.
"$java_bin" -cp "$compiler_cp" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler \
  -no-stdlib -nowarn \
  -jvm-target 1.8 \
  -classpath "$cp_value" \
  -d "$build/classes" \
  @"$build/kt-sources.txt" @"$build/java-sources.txt"

# The .java classes, for the runtime classpath. kotlinc does not emit class
# files for java sources it was handed for resolution.
#
# `--release 8` matches the language level both poms declare (`<java.version>
# 1.8` and `<jvmTarget>1.8</jvmTarget>`), so a Java 9+ API in `com.kcl.ast` is
# a compile error here rather than something that passes on a new JDK and fails
# on the zulu 8 the build matrix uses.
javac -nowarn -proc:none --release 8 -encoding UTF-8 \
  -cp "$cp_value" \
  -d "$build/classes" \
  @"$build/java-sources.txt"

"$java_bin" -cp "$build/classes:$cp_value" astdump.DumpKt "$golden" "$out"

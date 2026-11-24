#!/usr/bin/env bash
# Package a Java or Kotlin JNI jar whose linux-x86_64 library runs on glibc 2.17.
#
# CentOS 7 (glibc 2.17, the RHEL 7 baseline) used to compile that one library.
# The other classifiers are built on current runners and must already sit in
# <module>/native/. This script builds only linux-x86_64, with zig as the
# linker (`cargo zigbuild --target x86_64-unknown-linux-gnu.2.17`), then
# refuses to package a library that references GLIBC newer than 2.17 or any
# GLIBCXX symbol. Rust 1.91's x86_64-unknown-linux-gnu std is itself built
# for glibc 2.17, so that floor is the same one the CentOS 7 image enforced.
#
# Usage (from the repository root): hack/package-jni-glibc217.sh java|kotlin
set -euo pipefail

module="${1:?usage: hack/package-jni-glibc217.sh java|kotlin}"
case "$module" in
  java|kotlin) ;;
  *) echo "module must be java or kotlin, got: $module" >&2; exit 2 ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root/$module"

rustup target add x86_64-unknown-linux-gnu

cargo zigbuild --release \
  --target x86_64-unknown-linux-gnu.2.17 \
  --target-dir target/zigbuild

so="target/zigbuild/x86_64-unknown-linux-gnu/release/libkcl_lib_jni.so"
if [ ! -f "$so" ]; then
  echo "missing $so" >&2
  find target/zigbuild -name 'libkcl_lib_jni.so' -print >&2 || true
  exit 1
fi

if readelf -W -V "$so" | grep -q 'GLIBCXX_'; then
  echo "$so references GLIBCXX; CentOS 7's libstdc++ cannot be assumed" >&2
  exit 1
fi

highest="$(
  readelf -W -V "$so" \
    | sed -n 's/.*GLIBC_\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' \
    | sort -t. -k1,1n -k2,2n \
    | tail -n 1
)"
if [ -z "$highest" ]; then
  echo "$so has no GLIBC versioned symbols; the glibc floor was not checked" >&2
  exit 1
fi
echo "highest GLIBC symbol in $so: $highest"
python3 - "$highest" << 'PY'
import sys
got = tuple(int(part) for part in sys.argv[1].split("."))
limit = (2, 17)
if got > limit:
    sys.exit(
        f"libkcl_lib_jni.so requires GLIBC_{sys.argv[1]}, which is newer than 2.17"
    )
PY

mkdir -p native/linux-x86_64
cp "$so" native/linux-x86_64/libkcl_lib_jni.so

# exec.skip keeps Maven from rebuilding the library with the host linker,
# which would undo the glibc 2.17 target. native/ is a resource, so the
# zig-built library and the other classifiers already in native/ are packed
# into the jar.
mvn package -DskipTests=true -Dexec.skip=true -Dcargo-build.profile=release

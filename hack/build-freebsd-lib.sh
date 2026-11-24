#!/usr/bin/env bash
#
# Build libkcl.so for FreeBSD and stage it at go/lib/freebsd-<arch>/libkcl.so.
#
# kcl-lang/kcl does not publish FreeBSD release archives yet
# (https://github.com/kcl-lang/kcl/issues/1029), so hack/download-libs.sh
# cannot fetch them. This script builds the cdylib from this repository's
# c/ crate (package kcl-lib-c) — the same artifact the Android workflow
# stages as libkcl.so — and copies it to the filename the Go loader dlopens.
#
# The loader (go/native/native_nonmusl.go) resolves four symbols from that
# file, and no others:
#   kcl_service_new
#   kcl_service_delete
#   kcl_service_call_with_length
#   kcl_free
# c/src/lib.rs re-exports the three service-handle symbols from kcl-api and
# defines kcl_free. It does not define the retired kclvm_service_new name.
#
# Usage:
#   hack/build-freebsd-lib.sh                  # native FreeBSD host
#   hack/build-freebsd-lib.sh freebsd-amd64    # one platform
#   hack/build-freebsd-lib.sh freebsd-arm64
#   hack/build-freebsd-lib.sh --all            # both
#
# A FreeBSD host builds natively with cargo. Anywhere else, the script
# cross-compiles with cargo-zigbuild, which links Zig's FreeBSD libc.
# GitHub-hosted runners have no FreeBSD VM; CI checks the Go install path
# (.github/workflows/build-libkcl-freebsd.yaml) and does not run this build.
# To cross-compile locally:
#
#   rustup target add x86_64-unknown-freebsd   # or aarch64-unknown-freebsd
#   cargo install cargo-zigbuild --locked
#   # zig on PATH. cargo-zigbuild prints the version it wants.
#   hack/build-freebsd-lib.sh freebsd-amd64

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    sed -n '3,35p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

platform_target() {
    case "$1" in
        freebsd-amd64) echo "x86_64-unknown-freebsd" ;;
        freebsd-arm64) echo "aarch64-unknown-freebsd" ;;
        *) return 1 ;;
    esac
}

host_platform() {
    local os arch
    case "$(uname -s)" in
        FreeBSD) os=freebsd ;;
        *) return 1 ;;
    esac
    case "$(uname -m)" in
        amd64|x86_64) arch=amd64 ;;
        arm64|aarch64) arch=arm64 ;;
        *) return 1 ;;
    esac
    echo "${os}-${arch}"
}

# True when this machine can compile $1 with the host linker.
is_native_target() {
    local rust_target="$1"
    case "$(uname -s)-$(uname -m)" in
        FreeBSD-amd64|FreeBSD-x86_64)
            [ "$rust_target" = "x86_64-unknown-freebsd" ]
            ;;
        FreeBSD-arm64|FreeBSD-aarch64)
            [ "$rust_target" = "aarch64-unknown-freebsd" ]
            ;;
        *)
            return 1
            ;;
    esac
}

require_symbols() {
    local so="$1" nm_bin table missing=0
    if command -v nm >/dev/null 2>&1; then
        nm_bin=nm
    elif command -v llvm-nm >/dev/null 2>&1; then
        nm_bin=llvm-nm
    else
        echo "error: nm or llvm-nm is required to verify ${so} exports" >&2
        return 1
    fi
    # GNU nm accepts --defined-only. FreeBSD nm accepts -D and not the long
    # option, so fall back rather than treating a flag error as "no symbols".
    if ! table="$("$nm_bin" -D --defined-only "$so" 2>/dev/null)"; then
        if ! table="$("$nm_bin" -D "$so" 2>/dev/null)"; then
            echo "error: ${nm_bin} could not read dynamic symbols from ${so}" >&2
            return 1
        fi
    fi
    local sym
    for sym in kcl_service_new kcl_service_delete kcl_service_call_with_length kcl_free; do
        if ! grep -Eq "(^|[[:space:]])${sym}$" <<<"$table"; then
            echo "error: ${so} does not export ${sym}" >&2
            missing=1
        fi
    done
    if grep -Eq '(^|[[:space:]])kclvm_service_new$' <<<"$table"; then
        echo "error: ${so} exports the retired symbol kclvm_service_new" >&2
        missing=1
    fi
    return "$missing"
}

build_one() {
    local platform="$1" rust_target src
    if ! rust_target="$(platform_target "$platform")"; then
        echo "error: unknown platform '${platform}'" >&2
        echo "       known: freebsd-amd64 freebsd-arm64" >&2
        return 1
    fi

    echo "==> ${platform}: cargo build --target ${rust_target}" >&2
    if command -v rustup >/dev/null 2>&1; then
        rustup target add "$rust_target" >/dev/null
    fi

    if is_native_target "$rust_target"; then
        cargo build --release --target "$rust_target" --manifest-path "$REPO_ROOT/c/Cargo.toml"
    else
        if ! command -v zig >/dev/null 2>&1; then
            echo "error: cross-compiling ${platform} needs zig on PATH" >&2
            echo "       On FreeBSD, run this script on the host instead." >&2
            return 1
        fi
        if ! cargo zigbuild --version >/dev/null 2>&1; then
            echo "error: cross-compiling ${platform} needs cargo-zigbuild" >&2
            echo "       cargo install cargo-zigbuild --locked" >&2
            return 1
        fi
        cargo zigbuild --release --target "$rust_target" --manifest-path "$REPO_ROOT/c/Cargo.toml"
    fi

    src="$REPO_ROOT/c/target/${rust_target}/release/libkcl_lib_c.so"
    if [ ! -s "$src" ]; then
        echo "error: ${src} was not produced" >&2
        return 1
    fi
    require_symbols "$src"

    local dir="$REPO_ROOT/go/lib/${platform}"
    mkdir -p "$dir"
    install -m 0755 "$src" "${dir}/libkcl.so"
    echo "    staged go/lib/${platform}/libkcl.so ($(du -h "${dir}/libkcl.so" | cut -f1))" >&2
}

PLATFORMS=()
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage 0 ;;
        --all) PLATFORMS+=(freebsd-amd64 freebsd-arm64); shift ;;
        freebsd-amd64|freebsd-arm64) PLATFORMS+=("$1"); shift ;;
        *) echo "error: unknown argument '$1'" >&2; usage 1 ;;
    esac
done

if [ "${#PLATFORMS[@]}" -eq 0 ]; then
    if host="$(host_platform)"; then
        PLATFORMS+=("$host")
    else
        echo "error: not a FreeBSD host; pass freebsd-amd64 or freebsd-arm64" >&2
        usage 1
    fi
fi

cd "$REPO_ROOT"
for platform in "${PLATFORMS[@]}"; do
    build_one "$platform"
done

echo "==> done; FreeBSD libkcl.so is staged under go/lib/"

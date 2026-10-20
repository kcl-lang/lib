#!/usr/bin/env bash
#
# Fetch the prebuilt KCL runtime binaries into go/lib/<platform>/ and
# wasm/kcl.wasm.
#
# The development branches do not carry these artifacts — they are ~370MB of
# compiled binaries reproducible from the kcl-lang/kcl release of the same
# version. Release branches get them vendored by
# .github/workflows/vendor-libs.yaml; see docs/lib-vendoring.md.
#
# Usage:
#   hack/download-libs.sh                          # host platform only
#   hack/download-libs.sh linux-arm64 darwin-arm64 # named platforms
#   hack/download-libs.sh --wasm                   # kcl.wasm (npm package)
#   hack/download-libs.sh --all                    # every platform, incl. iOS
#   hack/download-libs.sh --version v0.13.2        # pin a version
#
# --all includes the two iOS static archives, which have no prebuilt source
# and are cross-compiled from c/ with cargo (macOS hosts only).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_REPO="kcl-lang/kcl"

VERSION=""
WITH_WASM=0
PLATFORMS=()

# kcl-lang/kcl release target -> "destination:file name"
platform_dest() {
    case "$1" in
        linux-amd64)      echo "go/lib/linux-amd64:libkcl.so" ;;
        linux-arm64)      echo "go/lib/linux-arm64:libkcl.so" ;;
        linux-musl-amd64) echo "go/lib/linux-musl-amd64:libkcl.a" ;;
        linux-musl-arm64) echo "go/lib/linux-musl-arm64:libkcl.a" ;;
        darwin-amd64)     echo "go/lib/darwin-amd64:libkcl.dylib" ;;
        darwin-arm64)     echo "go/lib/darwin-arm64:libkcl.dylib" ;;
        windows-amd64)    echo "go/lib/windows-amd64:kcl.dll" ;;
        windows-arm64)    echo "go/lib/windows-arm64:kcl.dll" ;;
        wasm32-wasip1)    echo "wasm:kcl.wasm" ;;
        ios-arm64)        echo "go/lib/ios-arm64:libkcl.a" ;;
        ios-arm64-sim)    echo "go/lib/ios-arm64-sim:libkcl.a" ;;
        *)                return 1 ;;
    esac
}

# Every target published by kcl-lang/kcl's release workflow, minus iOS which is
# built locally by build_ios() below.
PREBUILT_PLATFORMS=(
    linux-amd64 linux-arm64 linux-musl-amd64 linux-musl-arm64
    darwin-amd64 darwin-arm64 windows-amd64 windows-arm64
)

usage() {
    sed -n '3,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

default_version() {
    # Keep this in lockstep with the version the SDK reports on first run.
    sed -nE 's/^const KCL_VERSION[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
        "$REPO_ROOT/go/install/install.go"
}

host_platform() {
    local os arch
    case "$(uname -s)" in
        Darwin) os=darwin ;;
        Linux)  os=linux ;;
        # Git Bash on the Windows runners, where this script runs.
        MINGW*|MSYS*|CYGWIN*) os=windows ;;
        *) echo "unsupported host $(uname -s); pass a platform explicitly" >&2; exit 1 ;;
    esac
    case "$(uname -m)" in
        arm64|aarch64) arch=arm64 ;;
        x86_64|amd64)  arch=amd64 ;;
        *) echo "unsupported host arch $(uname -m); pass a platform explicitly" >&2; exit 1 ;;
    esac
    echo "${os}-${arch}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --version=*) VERSION="${1#*=}"; shift ;;
        --wasm) WITH_WASM=1; shift ;;
        --all) PLATFORMS+=("${PREBUILT_PLATFORMS[@]}" ios-arm64 ios-arm64-sim); shift ;;
        -h|--help) usage 0 ;;
        -*) echo "unknown flag: $1" >&2; usage 1 ;;
        *) PLATFORMS+=("$1"); shift ;;
    esac
done

if [ -z "$VERSION" ]; then
    VERSION="$(default_version)"
    if [ -z "$VERSION" ]; then
        echo "could not read KCL_VERSION from go/install/install.go; pass --version" >&2
        exit 1
    fi
fi

if [ "${#PLATFORMS[@]}" -eq 0 ] && [ "$WITH_WASM" -eq 0 ]; then
    PLATFORMS+=("$(host_platform)")
fi

cd "$REPO_ROOT"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

download() {
    # $1 kcl release target, $2 expected file name
    local target="$1" name="$2"
    local ext="tar.gz"
    case "$target" in windows-*) ext="zip" ;; esac

    local asset="kcl-lib-${VERSION}-${target}.${ext}"
    local url="https://github.com/${RELEASE_REPO}/releases/download/${VERSION}/${asset}"

    echo "==> ${target}: downloading ${asset}" >&2
    if ! curl -fsSL --retry 3 -o "${TMPDIR}/${asset}" "$url"; then
        echo "error: failed to download ${url}" >&2
        echo "       does ${RELEASE_REPO} publish a ${VERSION} release?" >&2
        return 1
    fi

    local unpacked="${TMPDIR}/${target}-unpacked"
    mkdir -p "$unpacked"
    case "$ext" in
        zip)
            # Git Bash on the Windows runners ships bsdtar but not unzip.
            if command -v unzip >/dev/null 2>&1; then
                unzip -q "${TMPDIR}/${asset}" -d "$unpacked"
            elif tar --version 2>/dev/null | grep -qi 'bsdtar\|libarchive'; then
                tar -xf "${TMPDIR}/${asset}" -C "$unpacked"
            else
                python3 -c 'import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' \
                    "${TMPDIR}/${asset}" "$unpacked"
            fi
            ;;
        *)   tar -xzf "${TMPDIR}/${asset}" -C "$unpacked" ;;
    esac

    # The archives are built from inside release/lib, so the artifact sits at
    # the root; glob anyway so a future layout change is not a silent no-op.
    local found
    found="$(find "$unpacked" -type f -name "$name" -print -quit)"
    if [ -z "$found" ]; then
        echo "error: ${asset} does not contain ${name}" >&2
        return 1
    fi
    if [ ! -s "$found" ]; then
        echo "error: ${name} from ${asset} is empty" >&2
        return 1
    fi
    echo "$found"
}

stage() {
    # $1 kcl release target, $2 "dir:file"
    local target="$1" dest="$2"
    local dir="${dest%%:*}" name="${dest##*:}"
    local src
    src="$(download "$target" "$name")"

    mkdir -p "$dir"
    # Install mode 0755: the loader dlopen()s this path directly.
    install -m 0755 "$src" "${dir}/${name}"
    echo "    staged ${dir}/${name} ($(du -h "${dir}/${name}" | cut -f1))" >&2
}

build_ios() {
    # iOS has no prebuilt source: libkcl.a there is the kcl-lib-c static
    # archive built from this repository's c/ crate, matching what
    # .github/workflows/build-libkcl-mobile.yaml produces.
    local dest="$1" rust_target="$2"
    if [ "$(uname -s)" != "Darwin" ]; then
        echo "error: ${rust_target} must be cross-compiled on a macOS host" >&2
        return 1
    fi
    echo "==> ${rust_target}: cargo build --target ${rust_target}" >&2
    rustup target add "$rust_target" >/dev/null
    cargo build --release --target "$rust_target" --manifest-path c/Cargo.toml
    # Split the "dir:file" dest the way stage() does. Using it whole writes the
    # archive to a file literally named `ios-arm64:libkcl.a` sitting beside the
    # directory, which no later step looks at.
    local dir="${dest%%:*}" name="${dest##*:}"
    mkdir -p "$dir"
    install -m 0644 "c/target/${rust_target}/release/libkcl_lib_c.a" "${dir}/${name}"
    echo "    staged ${dir}/${name} ($(du -h "${dir}/${name}" | cut -f1))" >&2
}

# Guarded rather than iterated bare: an empty array under `set -u` is an
# error on the bash 3.2 that ships with macOS, and `hack/download-libs.sh
# --wasm` legitimately leaves PLATFORMS empty.
if [ "${#PLATFORMS[@]}" -gt 0 ]; then
    for platform in "${PLATFORMS[@]}"; do
        if ! dest="$(platform_dest "$platform")"; then
            echo "error: unknown platform '${platform}'" >&2
            echo "       known: ${PREBUILT_PLATFORMS[*]} wasm32-wasip1 ios-arm64 ios-arm64-sim" >&2
            exit 1
        fi
        case "$platform" in
            ios-arm64)     build_ios "$dest" aarch64-apple-ios ;;
            ios-arm64-sim) build_ios "$dest" aarch64-apple-ios-sim ;;
            *)             stage "$platform" "$dest" ;;
        esac
    done
fi

if [ "$WITH_WASM" -eq 1 ]; then
    stage wasm32-wasip1 "wasm:kcl.wasm"
    # The browser example webpack-bundles its own copy next to the entry point.
    mkdir -p wasm/examples/browser
    install -m 0644 wasm/kcl.wasm wasm/examples/browser/kcl.wasm
    echo "    staged wasm/examples/browser/kcl.wasm"
fi

echo "==> done; KCL ${VERSION} runtime binaries are in place"

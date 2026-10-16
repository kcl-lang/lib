# Prebuilt runtime binaries

The `go/lib/<platform>/` binaries and `wasm/kcl.wasm` are compiled artifacts —
about 370MB of the tree. They are **not tracked on the development branches**.
Every one of them is reproducible from the [kcl-lang/kcl][kcl] release of the
same version, so carrying them on `main` buys nothing but clone time and diff
noise.

They are vendored onto `release/*` branches by
[`.github/workflows/vendor-libs.yaml`](../.github/workflows/vendor-libs.yaml),
and release tags are cut from those branches, so anything pinning a tag gets a
self-contained tree.

## Getting the binaries

```shell
hack/download-libs.sh              # host platform only
hack/download-libs.sh --wasm       # kcl.wasm, for the npm package
hack/download-libs.sh --all        # every platform, iOS included
hack/download-libs.sh linux-arm64  # named platforms
```

The version defaults to `KCL_VERSION` in `go/install/install.go`; pass
`--version v0.13.2` to pin a different one. Platforms that
[kcl-lang/kcl][kcl] publishes are downloaded from its release; the two iOS
static archives are cross-compiled from this repository's `c/` crate with
cargo, so `--all` needs a macOS host.

A fresh clone of `main` therefore needs one command before anything that links
against the native runtime will build. Every CI job that needs it runs the
script itself.

### Platforms with no published asset

`windows-arm64` is the one platform `go/lib` ships a binary for that no kcl
release publishes yet. [kcl-lang/kcl#2219][] adds it to that repository's
release matrix, but only the first kcl tag cut after that lands will carry a
`kcl-lib-<version>-windows-arm64.zip`, and until `KCL_VERSION` here points at
such a release `hack/download-libs.sh windows-arm64` 404s. The `windows-11-arm`
leg of `dart-test.yaml` is commented out for the same reason — it used to pass
only because the binary was committed here, which is what this change stops
doing. Re-enable it once the asset ships.

`vendor-libs.yaml` fetches that platform on a best-effort basis, so cutting a
release against a kcl version that predates the asset still vendors every
other runtime instead of failing the run; the omission is reported as a
warning on the vendoring commit.

[kcl-lang/kcl#2219]: https://github.com/kcl-lang/kcl/pull/2219

## The Go build tag

`go/lib` embeds the platform binary with `//go:embed`, which is a *compile*
time dependency: without `go/lib/darwin-arm64/libkcl.dylib` on disk, a
darwin/arm64 `go build ./...` fails with

```text
lib/kcl_lib_darwin_arm64.go:10:12: pattern darwin-arm64/libkcl.dylib: no matching files found
```

To type-check or vet the tree without downloading 350MB, build with the opt-out
tag:

```shell
go build -tags no_libembed ./...
```

That selects `go/lib/kcl_lib_noembed.go`, which leaves `lib.CliLib` empty. The
SDK then reports a clear error the first time it tries to install the runtime,
rather than writing a zero-byte library to the cache directory and failing at
`dlopen` with something cryptic. This mirrors
[wasmtime-go](https://github.com/bytecodealliance/wasmtime-go), which keeps
its `build/` directory empty on `main` and downloads the archive in CI.

The other bindings — Dart, PHP, Julia, Zig — have no compile-time coupling; they
resolve the library at run time from `go/lib/<platform>/` or an environment
variable, so they only need the file to be present.

## Cutting a release

The kcl-lang/kcl release has to exist first, because that is where the binaries
come from.

1. **Publish the matching kcl-lang/kcl release.** Every platform in the table
   in [abi.md §8](abi.md#8-prebuilt-shared-libraries) needs a `kcl-lib-<tag>-<platform>`
   asset.
2. **Bump `KCL_VERSION`** in `go/install/install.go` to the version being
   released.
3. **Create and push the release branch.** The workflow derives the version from
   the branch name and refuses to run if it disagrees with `KCL_VERSION`:

   ```shell
   git switch -c release/v0.13.2 origin/main
   git push origin release/v0.13.2
   ```

   `vendor-libs.yaml` then downloads every published platform, cross-compiles
   the iOS archives, and commits the lot onto the branch.
4. **Cut the tag from the release branch**, not from `main`:

   ```shell
   git tag v0.13.2 release/v0.13.2
   git push origin v0.13.2
   ```

## Why a branch and not a force-moved tag

An earlier draft of this workflow followed `swift-release.yaml` and force-updated
the tag after the fact. That does not work here: `wasm-test.yaml` publishes
`@kcl-lib/wasm` to npm on a tag push, and `kcl.wasm` is in that package's
`files` array. A workflow that rewrites the tag *after* the push races the npm
publish, and the failure is silent — npm publishes successfully with no runtime
inside it. On a release branch the binaries are already committed before the tag
exists, so there is no ordering to get wrong.

[kcl]: https://github.com/kcl-lang/kcl

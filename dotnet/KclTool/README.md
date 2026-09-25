# KclTool — KCL CLI for .NET

`KclTool` bundles the cross-platform `kcl` command-line executable (the official
[KCL](https://github.com/kcl-lang/kcl) CLI) as a NuGet package, so .NET
applications can shell out to KCL without a separate install. See
[kcl-lang/lib#309](https://github.com/kcl-lang/lib/issues/309).

## Quick Start

```shell
dotnet add package KclTool
```

The package ships the `kcl` (or `kcl.exe` on Windows) binary and its native
dependency `libkcl` for every supported runtime identifier:

| OS      | Architecture | RID           | Sub-package                  |
| ------- | ------------ | ------------- | ---------------------------- |
| Windows | x64          | `win-x64`     | `KclTool.runtime.win-x64`    |
| macOS   | x64          | `osx-x64`     | `KclTool.runtime.osx-x64`    |
| macOS   | arm64        | `osx-arm64`   | `KclTool.runtime.osx-arm64`  |
| Linux   | x64          | `linux-x64`   | `KclTool.runtime.linux-x64`  |
| Linux   | arm64        | `linux-arm64` | `KclTool.runtime.linux-arm64`|

The native binaries are split into per-RID "runtime asset" packages
(`KclTool.runtime.<rid>`). The .NET runtime asset resolver selects the
matching sub-package at restore time and copies its
`runtimes/<rid>/native/*` files next to your assembly, so each NuGet
package stays well below NuGet's per-package size limit. You don't need
to reference the per-RID packages directly — `dotnet add package KclTool`
is enough.

## Usage

### Option A — invoke via `KclRunner` (library reference)

```csharp
using KclTool;

// --help prints KCL usage to stdout and returns the captured output.
string help = KclRunner.Run(new[] { "--help" }, capture: true);
Console.WriteLine(help);

// Pass through any flags / positional args you need.
int exitCode = KclRunner.Run(new[] { "run", "schema.k", "--format", "yaml" });
```

The helper resolves the binary for the current RID once and caches it; `libkcl`
is placed next to the executable and `KCL_LIB_HOME` is set so no extra `PATH` /
`LD_LIBRARY_PATH` setup and no first-run auto-install is required.

### Option B — invoke the binary directly

If you prefer to use the binary yourself (e.g. from a project that does not
depend on this package), reference the per-RID sub-package directly and copy
the binary out of the project's `runtimes/<rid>/native/` directory:

```shell
# In a throwaway .NET project (any TFM / `dotnet new console` works):
dotnet add package KclTool.runtime.linux-x64
dotnet restore
cp obj/Debug/net8.0/runtimes/linux-x64/native/kcl      ~/.local/bin/
cp obj/Debug/net8.0/runtimes/linux-x64/native/libkcl.so ~/.local/bin/
kcl --help
```

### Async invocation

```csharp
using KclTool;

string yaml = await KclRunner.RunAsync(new[] { "run", "schema.k", "--format", "yaml" });
```

## Bundled versions

The package ships the pre-built `kcl` binary from
[kcl-lang/cli](https://github.com/kcl-lang/cli) alongside the matching
`libkcl.{so,dylib,dll}` from [kcl-lang/lib](https://github.com/kcl-lang/lib).
The two are pinned together by the CI workflow (see
`.github/workflows/publish-kcltool.yaml`); when bumping `KCL_CLI_VERSION`,
bump `KCL_LIB_REF` to the `kcl-lang.io/lib` version the new CLI was built
against (check `kcl-lang/cli` `go.mod`).

## Package layout

| Project                            | Package ID                | Contents                                  |
| ---------------------------------- | ------------------------- | ----------------------------------------- |
| `dotnet/KclTool/`                  | `KclTool`                 | Managed assembly (`KclRunner`) + docs     |
| `dotnet/KclTool.runtime.win-x64/`  | `KclTool.runtime.win-x64` | `kcl.exe`, `kcl.dll`                      |
| `dotnet/KclTool.runtime.linux-x64/`| `KclTool.runtime.linux-x64` | `kcl`, `libkcl.so`                      |
| `dotnet/KclTool.runtime.linux-arm64/` | `KclTool.runtime.linux-arm64` | `kcl`, `libkcl.so`                  |
| `dotnet/KclTool.runtime.osx-x64/`  | `KclTool.runtime.osx-x64` | `kcl`, `libkcl.dylib`                     |
| `dotnet/KclTool.runtime.osx-arm64/`| `KclTool.runtime.osx-arm64` | `kcl`, `libkcl.dylib`                   |

The shared `Version`, `RepositoryUrl`, and `PackageLicenseExpression` are
declared in `dotnet/Directory.Build.props` so a single bump there keeps
all six packages in lockstep.

## Developing and Testing

- Install `dotnet 8.0+`

The binaries are downloaded by the CI from
[kcl-lang/cli](https://github.com/kcl-lang/cli) releases and
[kcl-lang/lib](https://github.com/kcl-lang/lib) at the pinned tag, so local
builds don't need a Rust toolchain. To smoke-test locally, populate
`dotnet/KclTool.runtime.<rid>/` (kcl + libkcl) from matching upstream
artifacts.
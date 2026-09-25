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

| OS      | Architecture | RID           |
| ------- | ------------ | ------------- |
| Windows | x64          | `win-x64`     |
| macOS   | x64          | `osx-x64`     |
| macOS   | arm64        | `osx-arm64`   |
| Linux   | x64          | `linux-x64`   |
| Linux   | arm64        | `linux-arm64` |

The binaries are placed in **two layouts** inside the NuGet package, so pick
whichever fits your workflow:

- `runtimes/<rid>/native/` — .NET automatically copies these next to the
  referencing assembly. Use the bundled `KclTool.KclRunner` helper to invoke
  them.
- `tools/<rid>/` — also packaged so the binaries can be extracted and put on
  `PATH` directly, or consumed by tools that look at the conventional NuGet
  `tools/` folder.

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

### Option B — invoke directly (tool-style)

If you prefer to use the binary yourself (e.g. from a project that does not
depend on this package), extract the contents of `tools/<rid>/` from the
NuGet package (or run `dotnet add package KclTool` and copy them from the
project's `tools/<rid>/` folder) and put `kcl` / `kcl.exe` on `PATH`:

```shell
cp tools/linux-x64/kcl      ~/.local/bin/
cp tools/linux-x64/libkcl.so ~/.local/bin/
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

## Developing and Testing

- Install `dotnet 8.0+`

The binaries are downloaded by the CI from
[kcl-lang/cli](https://github.com/kcl-lang/cli) releases and
[kcl-lang/lib](https://github.com/kcl-lang/lib) at the pinned tag, so local
builds don't need a Rust toolchain. To smoke-test locally, populate
`dotnet/KclTool/runtimes/<rid>/native/` and `dotnet/KclTool/tools/<rid>/`
from matching upstream artifacts.
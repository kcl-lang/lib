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
is placed next to the executable, so no extra `PATH` / `LD_LIBRARY_PATH` setup
is required.

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

## Developing and Testing

- Install `cargo`
- Install `dotnet 8.0+`

The `kcl` CLI binary and `libkcl` are built from
[kcl-lang/kcl](https://github.com/kcl-lang/kcl) by the CI; locally you can
populate `dotnet/KclTool/runtimes/<rid>/native/` and `dotnet/KclTool/tools/<rid>/`
from a local build of the upstream project.
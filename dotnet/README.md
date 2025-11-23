# KCL Artifact Library for .NET

This library is currently under development. Please check back later.

## Quick Start

```shell
dotnet add package KclLib
```

Write the code

```cs
using KclLib.API;

var api = new API();
var execArgs = new ExecProgramArgs();
var path = Path.Combine("test_data", "schema.k");
execArgs.KFilenameList.Add(path);
var result = api.ExecProgram(execArgs);
Console.WriteLine(result.YamlResult);
```

## Developing and Testing

- Install `cargo`
- Install `dotnet 8.0+`

```shell
cargo build --release
dotnet test
```

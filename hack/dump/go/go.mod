// The Go AST dumper, as its own module.
//
// `kcl-lang.io/lib/go` is the binding and this package is not part of it: the
// repo keeps every language's dumper under `hack/dump/<lang>/` so the
// cross-language harness has one place to look. `hack/dump/dotnet/Dump.csproj`
// refers to the binding the same way.
//
// The `replace` is the load-bearing line. Without it the module resolves
// `kcl-lang.io/lib/go` from the proxy and the dumper would be checking a
// published version of the binding rather than the sources sitting next to it,
// which is exactly the drift the harness exists to catch.
module astdump

go 1.25.0

require kcl-lang.io/lib v0.0.0

replace kcl-lang.io/lib => ../../..

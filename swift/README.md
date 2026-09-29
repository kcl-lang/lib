# KCL Artifact Library for Swift

This repo is under development, PRs welcome!

## Facade (high-level API)

For the common "run some KCL and read the result" flow, the `KclLib` module
provides an ergonomic facade over the raw protobuf RPC bindings — the same
facade surface as the Python/.NET/Java/Node.js bindings of this repo
(mirroring kcl-go's `pkg/kcl`):

```swift
import KclLib

// Inline code; throws KclError on any failure.
let result = try Kcl.run("a = {replicas = 2}")
print(result.get("a.replicas") as? Int) // Optional(2)

// Files, with options.
let fromFiles = try Kcl.runFiles(["main.k"], options: {
    var o = KclOptions()
    o.overrides = ["replicas = 3"]
    o.args = ["env=prod"] // -D key=value
    return o
}())
```

`Kcl.run` / `Kcl.runFiles` return a `KclResultList` — a collection of
per-document `KclResult` values with dotted-path `get("a.b.c")` navigation,
`toMap()` / `toList()` conversions and raw `yamlResult` / `jsonResult`
payloads. Options live in the value-type `KclOptions` struct covering the
kcl-go `With*` set: `workDir`, `args`, `overrides`, `selectors`,
`settings` (`kcl.yaml` files resolved through the native `LoadSettingsFiles`
RPC — no YAML parser is bundled), `disableNone`, `sortKeys`, `showHidden`,
`includeSchemaTypePath` / `fullTypePath`, `strictRangeCheck`, `verbose` /
`debug`, `format` (`"json"` / `"yaml"`), `errorFormat`, `externalPkgs`
(`"name=path"`), `compileOnly`, `fastEval`, `printOverrideAst`,
`disableYamlResult` and a `log_message` `logger` sink. Explicit option fields
win over settings-file values; repeated fields append after them, matching
kcl-go's `Option.Merge` order semantics.

With `includeSchemaTypePath` on, the facade rewrites `_type` attributes to
their short name (`bbb.B` → `B`), mirroring kcl-go's `DefaultHooks`; pass
`fullTypePath: true` to keep the qualified paths.

```swift
// Validate data against a schema in memory (ValidateCode RPC).
let ok = try Kcl.validate(
    code: "schema Person:\n    name: str\n    check:\n        name",
    data: "{\"name\": \"Alice\"}",
    format: "json")
```

## Plugins (host callbacks)

KCL code can call back into Swift through the plugin protocol: register a
`PluginContext`, attach it to an `API` instance (or pass it as a
`KclOptions.pluginContext` for the facade), and import the plugin from KCL.

```swift
let context = PluginContext()
context.registerPlugin("my_plugin", methods: [
    "add": { args, _ in
        ((args[0] as? NSNumber)?.intValue ?? 0)
            + ((args[1] as? NSNumber)?.intValue ?? 0)
    },
])

let api = API()
api.attachPluginContext(context)
var execArgs = ExecProgramArgs()
execArgs.kFilenameList.append("main.k")
let result = try api.execProgram(execArgs) // main.k: `import kcl_plugin.my_plugin`
api.detachPluginContext()
```

```kcl
import kcl_plugin.my_plugin

result = my_plugin.add(1, 1) # 2
```

Closures receive the positional `args` and keyword `kwargs` as JSON-decoded
Swift values and return any JSON-serializable value (`nil` becomes `None`);
throwing fails the evaluation and surfaces the message in `err_message`.
Register single methods with `registerMethod(_:name:callback:)`. The native
plugin callback resolves the context through a process-wide slot, so one
context is active at a time — attaching a context replaces the previous one.


## Developing

**Prerequisites**

+ Swift 5.8+
+ Cargo

If you build on macos, you can set the environment to prevent link errors.

```shell
# Set cargo build target on macos
export MACOSX_DEPLOYMENT_TARGET='10.13'
```

**Build**

```shell
make
```

**Test**

```shell
make test
```

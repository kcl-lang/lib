# kcl_lib — Dart / Flutter binding for KCL

A Dart language binding for the [KCL configuration language](https://kcl-lang.io).
Like the other bindings in this repository, it is a thin wrapper around the
universal protobuf dispatcher shipped as a prebuilt `libkcl` shared library —
the Dart runtime never builds any Rust code. Messages are protobuf-encoded
and decoded via the official [`protobuf`][pub-protobuf] runtime; the generated
message code under `lib/src/pb/` is checked in, following the repository
convention.

[pub-protobuf]: https://pub.dev/packages/protobuf

## Installation

From a Dart project, install directly from this repository (the package
lives under the `dart/` subdirectory):

```shell
dart pub add 'kcl_lib': \
  { git: 'https://github.com/kcl-lang/lib.git', subdir: 'dart' }
```

Or in `pubspec.yaml`:

```yaml
dependencies:
  kcl_lib:
    git: https://github.com/kcl-lang/lib.git
    path: dart
```

Requirements:

- **Dart SDK 3.0 or later** (developed and tested on Dart 3.13).
- **`libkcl` prebuilt binary for your platform.** Out of the box the binding
  locates it through the `KCL_DART_LIB` environment variable. Point it at
  either the shared library file itself or at a directory whose layout
  matches the platform key in [`go/lib/`](../go/lib/) (the CI matrix
  installs `protoc` and `protoc-gen-dart` and runs the same way):

  ```shell
  export KCL_DART_LIB="$PWD/../go/lib/darwin-arm64/libkcl.dylib"
  ```

  Or, in code:

  ```dart
  import 'package:kcl_lib/kcl_lib.dart';
  final libkcl = LibKcl.open('/path/to/libkcl.dylib');
  ```

### Platforms

| OS      | Arch    | Prebuilt under `go/lib/`     | Library       | How loaded                    |
| ------- | ------- | --------------------------- | ------------- | --------------------------- |
| macOS   | arm64   | `darwin-arm64`              | `libkcl.dylib`| `KCL_DART_LIB` (or path)    |
| macOS   | x86_64  | `darwin-amd64`              | `libkcl.dylib`| `KCL_DART_LIB` (or path)    |
| Linux   | x86_64  | `linux-amd64`               | `libkcl.so`   | `KCL_DART_LIB` (or path)    |
| Linux   | arm64   | `linux-arm64`               | `libkcl.so`   | `KCL_DART_LIB` (or path)    |
| Windows | x86_64  | `windows-amd64`             | `libkcl.dll`  | `KCL_DART_LIB` (or path)    |
| Windows | arm64   | `windows-arm64`             | `libkcl.dll`  | `KCL_DART_LIB` (or path)    |
| Android | arm64   | `android-arm64`             | `libkcl.so`   | auto (`DynamicLibrary.open`)|
| Android | x86_64  | `android-x86_64`            | `libkcl.so`   | auto (`DynamicLibrary.open`)|
| iOS     | arm64   | `ios-arm64`                 | `libkcl.a`    | auto (`DynamicLibrary.process`) — link static lib into app |
| iOS sim | arm64   | `ios-arm64-sim`             | `libkcl.a`    | auto (`DynamicLibrary.process`) — link static lib into app |

On Flutter mobile (`Platform.isIOS` / `Platform.isAndroid`) the binding
auto-resolves the right archive: iOS uses `DynamicLibrary.process()` after the
`libkcl.a` is linked into the app; Android uses `DynamicLibrary.open('libkcl.so')`
which the Android dynamic linker finds in the app's nativeLibraryDir. The
desktop flow still uses `KCL_DART_LIB`. See [Flutter mobile setup](#flutter-mobile-setup) below.

## Quickstart

The short way — the facade, which takes care of building the request payload
and splitting the multi-document result (see [Facade](#facade)):

```dart
import 'package:kcl_lib/kcl_lib.dart';

void main() {
  final results = run('alice = {age = 18}');
  print(results.first.get('alice.age')); // 18
}
```

The explicit way — one call per `spec.proto` RPC:

```dart
import 'package:kcl_lib/kcl_lib.dart';

void main() {
  // Execute a KCL file
  final result = execProgram(
    ExecProgramArgs(kFilenameList: ['test_data/schema.k']),
  );
  print(result.yamlResult);

  // Execute inline KCL code
  final inline = execProgram(
    ExecProgramArgs(kCodeList: ['alice = {age = 18}']),
  );
  print(inline.jsonResult);
}
```

Message types like `ExecProgramArgs` are protobuf structs generated from
[`../spec/spec.proto`](../spec/spec.proto); every field is a named constructor
parameter with proto3 defaults. All RPC message types are re-exported from
`package:kcl_lib/kcl_lib.dart`.

## Error semantics

The native dispatcher prefixes every error reply with `ERROR:`; the binding
strips the prefix and throws `KclError`:

```dart
try {
  execProgram(ExecProgramArgs(kFilenameList: ['file_not_found']));
} on KclError catch (err) {
  print(err.message); // "Cannot find the kcl file, please check ..."
}
```

`exec_program` and `validate_code` are **not thread-safe**, mirroring the
spec.

## API reference

Every wrapper below is a top-level function and is equivalent to
`rawCall("KclService.<Method>", encodedArgs)`. The raw escape hatch
`rawCall(rpcName, encodedArgs)` reaches any RPC — including future ones —
by fully-qualified name and raw protobuf bytes.

> **Note on service names:** [`spec/spec.proto`](../spec/spec.proto) declares
> `FormatCode`, `FormatPath`, `LintPath`, `ValidateCode`, `LoadSettingsFiles`,
> `Rename`, `RenameCode`, `Test`, `UpdateDependencies`, `Ping`, and
> `ListMethod` under `service BuiltinService`, but the prebuilt `libkcl`
> v0.13.0 ships all of them under `service KclService` (and those
> `BuiltinService.*` calls panic with `unknown method name`). The wrapper layer
> routes every call through `KclService.*`, matching the implementation.
>
> **`ListMethod` is the one exception**, and it is worth calling out because it
> is the only way to ask a core which RPCs it supports. Verified against the
> prebuilt `darwin-arm64/libkcl.dylib`:
>
> - `BuiltinService.ListMethod` → returns the full 28-entry method table.
> - `KclService.ListMethod` → **not registered**; the native dispatcher panics
>   with `unknown method name` and answers with an empty payload.
>
> `listMethod()` therefore dispatches to `BuiltinService.ListMethod`, matching
> the Java binding (`java/.../api/API.java`). The method table it returns
> reports the fully-qualified names, so its own entry appears there as
> `BuiltinService.ListMethod` — which is what makes the divergence above
> observable from the outside.

| Wrapper                          | RPC                                              |
|----------------------------------|--------------------------------------------------|
| `execProgram(args)`              | `KclService.ExecProgram`                         |
| `getVersion()`                   | `KclService.GetVersion`                          |
| `parseProgram(args)`             | `KclService.ParseProgram`                        |
| `parseFile(args)`                | `KclService.ParseFile`                           |
| `loadPackage(args)`              | `KclService.LoadPackage`                         |
| `listOptions(args)`              | `KclService.ListOptions`                         |
| `listVariables(args)`            | `KclService.ListVariables`                       |
| `overrideFile(args)`             | `KclService.OverrideFile`                        |
| `getSchemaTypeMapping(args)`     | `KclService.GetSchemaTypeMapping`                |
| `getSchemaTypeMappingUnderPath(args)` | `KclService.GetSchemaTypeMappingUnderPath`   |
| `formatCode(args)`               | `KclService.FormatCode`                          |
| `formatPath(args)`               | `KclService.FormatPath`                          |
| `lintPath(args)`                 | `KclService.LintPath`                            |
| `validateCode(args)`             | `KclService.ValidateCode`                        |
| `loadSettingsFiles(args)`        | `KclService.LoadSettingsFiles`                   |
| `rename(args)`                   | `KclService.Rename`                              |
| `renameCode(args)`               | `KclService.RenameCode`                          |
| `runTests(args)`                 | `KclService.Test`                                |
| `formatTestReport(args)`         | `KclService.FormatTestReport`                    |
| `updateDependencies(args)`       | `KclService.UpdateDependencies`                  |
| `generateToml(args)`             | `KclService.GenerateToml`                        |
| `generateKcl(args)`              | `KclService.GenerateKcl`                         |
| `generateOpenAPI(args)`          | `KclService.GenerateOpenAPI`                     |
| `generateProto(args)`            | `KclService.GenerateProto`                       |
| `generateDoc(args)`              | `KclService.GenerateDoc`                         |
| `ping(args)`                     | `KclService.Ping`                                |
| `listMethod()`                   | `BuiltinService.ListMethod`                      |

### The `Generate*` family

Five generator RPCs sit on top of the parser. Unlike the rest of the surface
they take a nested `ExecProgramArgs` / `ParseProgramArgs` payload rather than a
CLI argv:

| Wrapper | RPC | Input | Output field |
|---|---|---|---|
| `generateToml(args)` | `KclService.GenerateToml` | `execArgs` (`ExecProgramArgs`), `sortKeys` | `toml` |
| `generateKcl(args)` | `KclService.GenerateKcl` | `source`, `filename`, `format` | `kcl` |
| `generateOpenAPI(args)` | `KclService.GenerateOpenAPI` | `parseArgs` (`ParseProgramArgs`), `version` | `spec` |
| `generateProto(args)` | `KclService.GenerateProto` | `parseArgs` (`ParseProgramArgs`), `package` | `proto` |
| `generateDoc(args)` | `KclService.GenerateDoc` | `parseArgs` (`ParseProgramArgs`), `format` | `content` |

Format selectors:

- `GenerateKclArgs.format` — `"json"` / `"yaml"` / `"toml"`. Empty means infer
  from the `filename` extension, defaulting to JSON.
- `GenerateOpenAPIArgs.version` — `"v3"` (default) or `"v2"` (Swagger 2.0).
- `GenerateDocArgs.format` — `"md"` (default) / `"openapi"` / `"json-schema"`.
  `"html"` is not supported yet.

```dart
final doc = generateDoc(
  GenerateDocArgs(
    parseArgs: ParseProgramArgs(paths: ['path/to/main.k']),
    format: 'md',
  ),
);
print(doc.content);
```

## Facade

`lib/src/kcl_facade.dart` is the ergonomic layer on top of the wrappers: it
builds the `ExecProgramArgs` payload for you and splits the multi-document
YAML/JSON stream the runtime emits into per-document results.

```dart
import 'package:kcl_lib/kcl_lib.dart';

void main() {
  final results = run('alice = {age = 18}');
  print(results.length);              // 1
  print(results.first.yamlString);   // alice:\n  age: 18
  print(results.first.jsonString);   // {"alice":{"age":18}}
  print(results.first.get('alice.age')); // 18
  print(results.first.toMap());      // {alice: {age: 18}}

  // From disk, with options.
  final fromFile = runFiles(
    ['test_data/schema.k'],
    options: const KclOptions(overrides: ['app.replicas=3'], sortKeys: true),
  );
  print(fromFile.first.get('app.replicas'));
}
```

Exported surface:

| Symbol | Purpose |
|---|---|
| `run(code, {options})` | Evaluate in-memory KCL; returns a `KclResultList`. |
| `runFiles(paths, {options})` | Evaluate KCL file(s); returns a `KclResultList`. |
| `Kcl.run` / `Kcl.runFiles` | The same two entry points as statics, for parity with the other bindings. |
| `KclOptions` | Immutable options value object: `settings`, `workDir`, `overrides`, `selectors`, `externalPkgs`, `disableNone`, `sortKeys`, `showHidden`, `includeSchemaTypePath`, `strictRangeCheck`, `fastEval`, `verbose`, `debug`, `errorFormat`, `format`. |
| `KclResult` | One document: `value`, `yamlString`, `jsonString`, `get(dottedPath)`, `toMap()`, `toList()`. |
| `KclResultList` | `UnmodifiableListView<KclResult>` plus `rawJsonResult`, `rawYamlResult`, `logMessage`. |
| `splitDocuments(text)` | Split a YAML stream on `---`; throws `KclError` on a malformed separator. |
| `parseJsonStream(json)` | Decode the runtime's newline-delimited JSON stream. |

Semantics worth knowing:

- **Dotted paths.** `get('a.b')` navigates nested maps; integer segments index
  lists (`get('a.tags.0')`). Any missing segment, a non-index list segment, or
  descending into a scalar yields `null` rather than throwing.
- **YAML-only runs have no value.** With `KclOptions(format: 'yaml')` the
  runtime emits no JSON, so `value` is `null` and `get`/`toMap`/`toList` raise
  `KclError` with an explanatory message. Read `yamlString` instead.
- **Settings resolution.** `KclOptions.settings` accepts a `kcl.yaml` path, a
  `List<String>` of paths, or a `Map<String, String>` of `-E` package name to
  path. Settings files are parsed by the native `loadSettingsFiles` RPC — the
  binding adds no YAML dependency. Settings form the base and explicit option
  keys win, mirroring kcl-go's `Option.Merge`.
  External packages declared *only* in a settings file are dropped, because the
  proto `CliConfig` message carries no `package_maps` field; pass them as
  `options.externalPkgs` instead.
- **Inline sources win over settings paths.** When `run()` supplies code and a
  settings file supplied files, the files are dropped — mixing `k_code_list`
  with `k_filename_list` would make the runtime treat the code as replacement
  file content. Everything else from the settings file still applies.
- **Errors throw.** Anything the core reports — a parse error, a type error, an
  evaluation error — surfaces as `KclError`, the same exception the typed
  wrappers raise.

## Typed AST

`parseFile` and `parseProgram` return the AST as a JSON string.
`parseModule(json)` and `parseProgramAst(json)` decode it into typed objects
mirroring Rust's AST in `../kcl/crates/ast/src/ast.rs`.

```dart
import 'package:kcl_lib/kcl_lib.dart';

const source = '''
schema Person:
    name: str = "anonymous"
    age: int = 0
''';

final m = parseModule(parseFile(ParseFileArgs(path: 'main.k', source: source)).astJson);

for (final ref in m.body) {
  final s = ref.node;
  if (s is! SchemaStmt) continue;
  print('${s.name!.node} on line ${ref.pos!.line}');
  for (final a in s.body) {
    final attr = a.node;
    if (attr is SchemaAttr) print('  ${attr.name!.node}: ${attr.ty!.node}');
  }
}
```

`Node<T>` pairs a value with the `Pos` it was parsed at, mirroring Rust's
`NodeRef<T>`. `KclStmt` and `KclExpr` are **sealed**, so a `switch` over them
is exhaustive at compile time, and every node exposes the `type` tag the parser
emitted through its `tag` getter.

Three serde shapes are worth knowing, because they are the details most easily
guessed wrong:

- `Stmt` and `Expr` are `#[serde(tag = "type")]`. Because the variants are
  newtypes over a struct, serde *flattens* the struct's fields into the same
  object — an identifier is `{"type": "Identifier", "names": [...]}`, not
  `{"type": "Identifier", "identifier": {...}}`.
- `Type` is `#[serde(tag = "type", content = "value")]`, so a basic type reads
  back as `{"type": "Basic", "value": "Int"}`, **not** `{"type": "Int"}`. Use
  `BasicType` / `UnionType` / `DictType` and read the payload off the struct.
- The plain structs nested inside `NodeRef<T>` — `Identifier`, `Target`,
  `Keyword`, `Arguments`, `ConfigEntry`, `CheckExpr`, `CallExpr`, `CompClause`,
  `SchemaExpr` — carry no tag. That is why `SchemaStmt.decorators` decodes to
  a `Decorator` rather than a tagged variant, and why `SchemaExpr.name` is a
  `Node<Identifier>` rather than a `Node<KclExpr>`.

Type names match the Java binding's (`com.kcl.ast`), so a class named in the
Rust source or in `java/src/main/java/com/kcl/ast/` is the class named here:
`Compare`, `ListComp`, `DictComp`, `NumberLit`, `StringLit`, `NameConstantLit`,
`JoinedString`, `FormattedValue`, `Subscript`, `Module`, `Pos`, `Node`.

Three payloads reach this package untagged, and Java gives each of them a
second name because Jackson cannot reuse a class the `Expr` subtype table
owns. Dart's decoders dispatch on the tag by hand, so each is one class under
two names rather than a second class:

| Java | here | the same object as |
| --- | --- | --- |
| `Decorator` | `typedef Decorator = CallExpr` | `SchemaAttr.decorators` is `Vec<NodeRef<CallExpr>>` |
| `SchemaConfig` | `typedef SchemaConfig = SchemaExpr` | `UnificationStmt.value` is `NodeRef<SchemaExpr>` |
| `CheckExpr` | `CheckExpr` | one class, used tagged (`Expr::Check`) and untagged (`SchemaStmt.checks`) |

`Decorator` and `FunctionType` are also protobuf message names in
`spec.pb.dart`; the AST spelling wins in the `package:kcl_lib/kcl_lib.dart`
barrel, and the generated ones are reachable by importing `src/pb/spec.pb.dart`
directly.

An unrecognised tag decodes to `UnknownStmt` / `UnknownExpr` / `UnknownType`
with the raw payload attached, so a newer parser degrades instead of throwing.
**This is a deliberate divergence from Java**, which raises
`InvalidTypeIdException` on a tag missing from its `@JsonSubTypes` list: Dart
has no such mechanism, and keeping the payload means a file using syntax a
newer `libkcl` adds is still traversable.

`parseProgramAst` is named with an `Ast` suffix because `parseProgram` already
occupies that name in the barrel — it is the RPC wrapper that takes
`ParseProgramArgs`. It accepts both program encodings: a bare array of modules
and the `{"root": …, "pkgs": {"__main__": […]}}` envelope.

## Plugins

A plugin exposes Dart functions to KCL code. The program imports the plugin
module and then calls the method unqualified:

```kcl
import kcl_plugin.strings

result = strings.join("KCL", "KCL", 123)
```

The runtime resolves that to a `kcl_plugin.strings.join` call into the host,
so `registerPlugin` only ever sees the two halves.

```dart
import 'package:kcl_lib/kcl_lib.dart';

registerPlugin('strings', 'join', (args, kwargs) => '"KCL.KCL.123"');

final result = execProgram(ExecProgramArgs(kCodeList: [
  'import kcl_plugin.strings\nresult = strings.join("KCL", "KCL", 123)\n',
]));
print(result.yamlResult); // result: KCL.KCL.123
```

| Function | Purpose |
| --- | --- |
| `registerPlugin(plugin, method, fn)` | Adds or replaces one method. |
| `pluginRegistered(plugin, method)` | Whether a name resolves. |
| `disablePlugins()` | Empties the registry and releases the service handle. |
| `hasPlugins()` | Whether anything is registered. |

A method is called as `fn(String args, String kwargs) -> String`, where both
arguments are the raw JSON the runtime sends and the return value must be
JSON-encoded. Register methods at start-up — nothing evaluated before the
first registration can reach the plugin. Throwing is allowed: the exception is
caught at the agent boundary and reported to the runtime, so it never unwinds
into the native frames underneath.

Two properties are worth calling out:

+ **No JSON dependency.** Arguments arrive as raw JSON strings and the result
  must be JSON-encoded, so a method that ignores its arguments needs no parser
  at all. One that inspects them can use `dart:convert`.
+ **Errors are data, not crashes.** Calling a method that was never
  registered — or one that threw — yields a
  `{"__kcl_PanicInfo__": "..."}` object, matching what Go's
  `plugin.JSONError` and Python's `_call_py_method` return. Following this
  binding's [error semantics](#error-semantics), it arrives in
  `result.errMessage` rather than as a thrown `KclError`.

`call_native` is the stateless universal dispatcher and cannot carry a plugin
agent, so the first `registerPlugin` binds a `kcl_service_new` handle and every
subsequent call routes through `kcl_service_call_with_length`. The agent
itself is a `NativeCallable.isolateLocal` callback, so it runs on the mutator
thread of the isolate that registered it — the same thread that drives
`execProgram`. With nothing registered the binding keeps using `call_native`
unchanged, so programs that do not use plugins are unaffected.

## Flutter mobile setup

Mobile platforms (`Platform.isIOS` / `Platform.isAndroid`) resolve the
libkcl archive automatically — but the binary still has to make it into
the Flutter app's native bundle. The workflow `.github/workflows/build-libkcl-mobile.yaml`
cross-compiles `libkcl.so` for Android and `libkcl.a` for iOS and stages them
under `go/lib/<platform>/`.

### Android

Drop the Android `.so` next to your app's native libraries. The standard
Flutter Android layout picks it up automatically because Android's dynamic
loader searches the app's `nativeLibraryDir`:

```
android/
  app/
    src/
      main/
        jniLibs/
          arm64-v8a/
            libkcl.so      # copy from go/lib/android-arm64/libkcl.so
          x86_64/
            libkcl.so      # copy from go/lib/android-x86_64/libkcl.so
```

Then `dart:ffi`'s `DynamicLibrary.open('libkcl.so')` resolves the symbol
without further setup. If you want the file to land in a different folder,
override the loader with `LibKcl.open('/data/data/<app>/lib/libkcl.so')`.

### iOS

iOS apps cannot `dlopen()` an arbitrary `.dylib` at runtime — App Store
policy and the dynamic linker forbid it. The archive **must** be statically
linked into the app binary, and the Dart side uses `DynamicLibrary.process()`
to reach the symbol. Two options:

1. **CocoaPods** — add the `.a` to your `ios/Podfile`:
   ```ruby
   target 'Runner' do
     # ...other pods
     pod 'kcl_lib', :path => '../path/to/kcl-lang/lib'
   end
   ```
   plus an `ios/kcl_lib.podspec` that declares the vendored `libkcl.a` for
   each platform slice (`ios.arm64`, `ios.x86_64-sim`, `ios.arm64-sim`).
   The `kcl-lang/lib` repo does not currently ship a podspec — track
   [issue TBD](#) for a turnkey one.

2. **Manual Xcode setup** — drag `go/lib/ios-arm64/libkcl.a` into the
   "Frameworks, Libraries, and Embedded Content" pane, set its status to
   "Do Not Embed" (it's a static archive, not a framework), and the linker
   will pull `call_native` into the final binary. The Dart side then
   resolves it via `DynamicLibrary.process()` automatically.

   For the simulator, swap in `go/lib/ios-arm64-sim/libkcl.a` — it is
   built with the `aarch64-apple-ios-sim` target and only links into the
   simulator slice.

In both cases the Dart binding does not need any extra configuration:
on `Platform.isIOS` it calls `DynamicLibrary.process()` which finds
`call_native` in the running app.

### Building the archives locally

The CI workflow uses `cargo build --target <triple>` against
[`c/Cargo.toml`](../c/Cargo.toml). On macOS the iOS targets work out of the
box once you `rustup target add aarch64-apple-ios aarch64-apple-ios-sim`:

```bash
cargo build --release --target aarch64-apple-ios      --manifest-path c/Cargo.toml
cargo build --release --target aarch64-apple-ios-sim  --manifest-path c/Cargo.toml
# then copy c/target/<triple>/release/libkcl_lib_c.a → go/lib/<platform>/libkcl.a
```

Android requires the NDK toolchain (one-time setup, ~1 GB download) and
the matching `aarch64-linux-android` / `x86_64-linux-android` rust targets;
the CI workflow documents the exact env vars in
`.github/workflows/build-libkcl-mobile.yaml`.

## Development

### Running tests

```bash
make test
```

This runs `dart pub get` then `dart test test/`. The Makefile assumes
`KCL_DART_LIB` is already set in the environment; CI does that
automatically (see `.github/workflows/dart-test.yaml`).

To run it locally against the prebuilt binary that matches your host:

```bash
# macOS arm64 shown; use darwin-amd64 / linux-* / windows-* as appropriate.
export KCL_DART_LIB=../go/lib/darwin-arm64/libkcl.dylib
make test
# or just:
dart test
```

`KCL_DART_LIB` may point at the shared library file or at a directory laid out
like `go/lib/` (`go/lib/` works — the loader picks the platform file itself).

#### Cross-language consistency

`test/consistency_test.dart` runs the shared golden cases from
[`../tests/consistency/cases.json`](../tests/consistency/cases.json) and is
part of `make test`. To run only that runner:

```bash
dart test test/consistency_test.dart
```

It needs the shared manifest checked out alongside `dart/` (it walks up from
the current directory to find `tests/consistency/cases.json`), and it prints
the RPC table the loaded `libkcl` reports so a skipped case is explainable from
the log alone. Cases marked `new_core` in the manifest are skipped — not
failed — against a core that does not advertise their RPC.

### Regenerating the protobuf bindings

```bash
make proto
# or:
dart run tool/regen_proto.dart
```

Requires `protoc` on PATH and `protoc-gen-dart` (install with
`dart pub global activate protoc_plugin`; add `$HOME/.pub-cache/bin` to
PATH on Linux/macOS, or `%USERPROFILE%\.pub-cache\bin` on Windows).
The vendored message code under `lib/src/pb/` is regenerated and committed.

### Layout

- `lib/kcl_lib.dart` — barrel that re-exports the public API.
- `lib/src/kcl_lib.dart` — typed wrappers for every RPC, plus `KclError`
  and the `rawCall` escape hatch.
- `lib/src/kcl_facade.dart` — the high-level facade: `run` / `runFiles`,
  `KclOptions`, `KclResult`, `KclResultList`, `splitDocuments`.
- `lib/src/kcl_lib_ffi.dart` — `dart:ffi` binding of the universal
  dispatcher (`call_native`) and the plugin service handle
  (`kcl_service_*`); manages the 4 MiB scratch buffer and the `libkcl`
  lookup.
- `lib/src/kcl_plugin.dart` — plugin registry and the `NativeCallable`
  plugin agent.
- `lib/src/ast/` — the typed AST: `Node`/`Pos` plus the sealed `AstType`,
  `KclExpr` and `KclStmt` hierarchies and the flat DTOs.
- `lib/src/kcl_ast.dart` — barrel for the AST, re-exported from
  `lib/kcl_lib.dart`.
- `lib/src/pb/` — generated protobuf message code (vendored).
- `test/kcl_lib_test.dart` — end-to-end tests for all 21 RPCs plus the
  plugin round trip.
- `test/kcl_facade_test.dart` — facade unit tests (`splitDocuments`,
  `parseJsonStream`, dotted-path `get`, `toMap`/`toList`, options merging)
  plus end-to-end `run` / `runFiles` against the core.
- `test/consistency_test.dart` — cross-language consistency runner. Executes
  the shared golden cases from [`../tests/consistency/cases.json`](../tests/consistency/cases.json)
  (generated by `../tests/consistency/generate_cases.py`) and compares the
  responses field by field, so every binding agrees on the same outputs.
  Nothing about a case is hardcoded: arguments, expectations and the RPC list
  all come from the manifest. Cases flagged `new_core` are **skipped** (not
  failed) when the loaded core does not advertise their RPC, so the suite
  stays green against older `libkcl` builds. The runner finds the manifest by
  walking up from the current directory, so it works from `dart/` or from the
  repository root.
- `test/kcl_ast_test.dart` — pins the AST wire contract against a real
  fixture parsed through the FFI, so the typed AST cannot silently drift from
  the parser.
- `test/ast_contract_test.dart` — decodes the shared golden capture at
  `../testdata/ast/alignment.json` and asserts that no tag anywhere in it
  falls through as `UnknownExpr` / `UnknownStmt` / `UnknownType`. A tag the
  decoder does not recognise becomes a zero-valued node rather than an error,
  so without this the decoder could resolve nothing and still look plausible.
  It also `switch`es over the sealed `KclExpr` / `KclStmt` / `AstType`
  hierarchies with no `default` arm, which only compiles if every variant the
  Rust enums declare has a Dart counterpart.
- `test/test_data/` — fixtures copied from `../python/tests/test_data`.

## License

Apache-2.0. Same as the rest of the KCL language bindings in this repo.
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
parameter with proto3 defaults. All 21 RPC message types are re-exported from
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
> v0.13.0 ships them all under `service KclService` (and `BuiltinService.*`
> calls panic with `unknown method name`). The wrapper layer routes every
> call through `KclService.*`, matching the implementation. A future
> upstream fix that re-registers these under `BuiltinService.*` will need a
> small wrapper update; tracked as a follow-up.

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
| `updateDependencies(args)`       | `KclService.UpdateDependencies`                  |
| `ping(args)`                     | `KclService.Ping`                                |
| `listMethod()`                   | `KclService.ListMethod`                          |

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
- `lib/src/kcl_lib_ffi.dart` — `dart:ffi` binding of the universal
  dispatcher (`call_native`); manages the 4 MiB scratch buffer and the
  `libkcl` lookup.
- `lib/src/pb/` — generated protobuf message code (vendored).
- `test/kcl_lib_test.dart` — end-to-end tests for all 21 RPCs.
- `test/test_data/` — fixtures copied from `../python/tests/test_data`.

## License

Apache-2.0. Same as the rest of the KCL language bindings in this repo.
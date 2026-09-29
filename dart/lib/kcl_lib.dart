/// KCL language binding for Dart/Flutter.
///
/// Thin FFI wrapper over the prebuilt `libkcl` shared library that ships
/// under `go/lib/<platform>/` in the kcl-lang/lib checkout. See the package
/// README for installation and the `LICENSE` for terms.
///
/// ```dart
/// import 'package:kcl_lib/kcl_lib.dart';
///
/// final result = execProgram(
///   ExecProgramArgs(kFilenameList: ['test_data/schema.k']),
/// );
/// print(result.yamlResult);
/// ```
library;

export 'src/kcl_lib.dart';
export 'src/kcl_lib_ffi.dart' show LibKcl;

// `kcl_lib` deliberately does **not** export a top-level `test()` function —
// the wrapper for `BuiltinService.Test` is exposed as `runTests` to avoid a
// name collision with the test framework's `test()`.
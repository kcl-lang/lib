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

export 'src/kcl_ast.dart';
// `spec.proto` also declares messages called `Decorator` and `FunctionType`,
// and re-exporting both libraries from one barrel makes the two names
// ambiguous at every use site rather than at one. The AST wins here: the
// binding spells its AST types with the same vocabulary as the Java binding
// (`com.kcl.ast.Decorator`, `com.kcl.ast.FunctionType`), and those are the
// ones a caller walking a parsed file wants. The protobuf messages are still
// reachable, and are used by `kcl_plugin.dart`, by importing the generated
// library directly:
//
//     import 'package:kcl_lib/src/pb/spec.pb.dart' show Decorator, FunctionType;
export 'src/kcl_lib.dart' hide Decorator, FunctionType;
export 'src/kcl_lib_ffi.dart' show LibKcl;
export 'src/kcl_plugin.dart';
// The high-level facade: `run` / `runFiles` / `KclResult` / `KclResultList`
// / `KclOptions`. It is layered on `src/kcl_lib.dart` and adds no names that
// clash with the protobuf messages, so it can be re-exported wholesale.
export 'src/kcl_facade.dart';

// `kcl_lib` deliberately does **not** export a top-level `test()` function —
// the wrapper for `BuiltinService.Test` is exposed as `runTests` to avoid a
// name collision with the test framework's `test()`.
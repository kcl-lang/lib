// Low-level FFI bindings for the prebuilt `libkcl` shared library.
//
// The C ABI is a single universal dispatcher (see c/include/kcl_ffi.h):
//
//     size_t call_native(const uint8_t *name_ptr, size_t name_len,
//                         const uint8_t *args_ptr, size_t args_len,
//                         uint8_t *result_ptr);
//
// `name` is the fully-qualified RPC name (e.g. "KclService.ExecProgram"),
// `args` is the protobuf-encoded request, and the response is copied into the
// caller-supplied scratch buffer; the return value is the byte length written.
// The response is **not** NUL-terminated by the C side (the C wrapper in
// kcl_lib.h appends a NUL for safety); Dart treats it as a length-prefixed
// byte slice.
//
// Locating `libkcl`:
//   - Set the `KCL_DART_LIB` environment variable to the shared library file
//     (e.g. `go/lib/darwin-arm64/libkcl.dylib`) or to a directory whose layout
//     matches `go/lib/<platform>/` (the binding then picks the platform file).
//   - This binding never builds Rust and never copies a binary into your
//     project; you point at the library the way Julia's `KCL_JL_LIB` does.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// Matches C/C++/dotnet/Julia. The Rust side copies the response unconditionally
// and its length can exceed the request size unpredictably (e.g. ExecProgram
// JSON/YAML results for non-trivial schemas).
const int kScratchBufferSize = 4 * 1024 * 1024;

// `call_native` C signature.
typedef _CallNativeC = IntPtr Function(
  Pointer<Uint8> namePtr,
  IntPtr nameLen,
  Pointer<Uint8> argsPtr,
  IntPtr argsLen,
  Pointer<Uint8> resultPtr,
);

typedef _CallNativeDart = int Function(
  Pointer<Uint8> namePtr,
  int nameLen,
  Pointer<Uint8> argsPtr,
  int argsLen,
  Pointer<Uint8> resultPtr,
);

/// Thin wrapper over `libkcl`. One instance per process is enough; the library
/// is stateless.
class LibKcl {
  static LibKcl? _singleton;

  /// Returns the process-wide singleton, opening the library on first use.
  ///
  /// Resolution order:
  /// 1. If `KCL_DART_LIB` is set, that path wins (tests, CI, overriding the
  ///    bundled binary).
  /// 2. On iOS, the static `libkcl.a` is linked into the app binary — the
  ///    symbol lives in the running process, so [DynamicLibrary.process]
  ///    resolves it.
  /// 3. On Android, `libkcl.so` is shipped in the app's nativeLibraryDir —
  ///    [DynamicLibrary.open] with the bare filename lets the system loader
  ///    find it.
  /// 4. On every other platform, throws — desktop requires `KCL_DART_LIB`
  ///    because Flutter / Dart don't have a canonical shared-library search
  ///    path the way Android and iOS do.
  ///
  /// For tests and explicit overrides, use [LibKcl.open].
  factory LibKcl() {
    final cached = _singleton;
    if (cached != null) return cached;
    final env = Platform.environment['KCL_DART_LIB'];
    final DynamicLibrary lib;
    if (env != null && env.isNotEmpty) {
      lib = _openDynamicLibrary(env);
    } else if (Platform.isIOS) {
      lib = DynamicLibrary.process();
    } else if (Platform.isAndroid) {
      lib = DynamicLibrary.open('libkcl.so');
    } else {
      throw StateError(
        'KCL_DART_LIB is not set. Point it at the prebuilt libkcl shared '
        'library shipped under go/lib/<platform>/ in the kcl-lang/lib '
        'checkout (for example: '
        '\$KCL_DART_LIB=/path/to/kcl-lang/lib/go/lib/darwin-arm64/libkcl.dylib).',
      );
    }
    final fn = lib
        .lookup<NativeFunction<_CallNativeC>>('call_native')
        .asFunction<_CallNativeDart>();
    return _singleton = LibKcl._(lib, fn);
  }

  /// Opens `libkcl` from an explicit path or directory. Pass either the
  /// shared library file itself or a directory containing the platform file
  /// (see the module comment).
  factory LibKcl.open(String path) {
    final lib = _openDynamicLibrary(path);
    final fn = lib
        .lookup<NativeFunction<_CallNativeC>>('call_native')
        .asFunction<_CallNativeDart>();
    return LibKcl._(lib, fn);
  }

  final _CallNativeDart _call;
  final Pointer<Uint8> _scratch;

  LibKcl._(DynamicLibrary lib, this._call)
      : _scratch = calloc<Uint8>(kScratchBufferSize) {
    // lib is closed implicitly on process exit. We don't expose it: nothing
    // in this binding needs to keep the handle alive separately.
    lib.toString();
  }

  /// Resets the process-wide singleton. Intended for tests only — the
  /// underlying `DynamicLibrary` cannot be closed on every platform, so
  /// leaking the singleton is the normal case.
  static void resetForTesting() {
    final cached = _singleton;
    if (cached != null) {
      calloc.free(cached._scratch);
    }
    _singleton = null;
  }

  /// Calls `call_native` with the given RPC name and protobuf-encoded `args`.
  /// Returns the raw response bytes (no `ERROR:` decoding here — the public
  /// API in `kcl_lib.dart` does that).
  Uint8List call(String rpcName, Uint8List args) {
    final nameBytes = utf8.encode(rpcName);
    final namePtr = calloc<Uint8>(nameBytes.length + 1);
    final argsPtr = calloc<Uint8>(args.length);

    try {
      namePtr.asTypedList(nameBytes.length).setAll(0, nameBytes);
      // Null-terminate so any future C-side helpers that read with strlen
      // (e.g. the C wrapper in kcl_lib.h) see the same boundary as Julia.
      (namePtr + nameBytes.length).value = 0;

      if (args.isNotEmpty) {
        argsPtr.asTypedList(args.length).setAll(0, args);
      }

      final length = _call(
        namePtr,
        nameBytes.length,
        argsPtr,
        args.length,
        _scratch,
      );

      if (length < 0 || length > kScratchBufferSize) {
        throw StateError(
          'libkcl returned an invalid response length: $length '
          '(RPC=$rpcName, scratch=${kScratchBufferSize}B)',
        );
      }

      // Copy out of the scratch buffer before the next call overwrites it.
      return Uint8List.fromList(_scratch.asTypedList(length));
    } finally {
      calloc.free(namePtr);
      calloc.free(argsPtr);
    }
  }
}

DynamicLibrary _openDynamicLibrary(String path) {
  final f = File(path);
  if (f.existsSync()) {
    return DynamicLibrary.open(path);
  }
  final d = Directory(path);
  if (d.existsSync()) {
    // Caller pointed at a directory like `go/lib/` — pick the platform file.
    final spec = _platformFileSpec();
    final platformFile = File('${d.path}/${spec.dir}/${spec.name}.${spec.ext}');
    if (platformFile.existsSync()) {
      return DynamicLibrary.open(platformFile.path);
    }
  }
  throw StateError(
    'KCL_DART_LIB does not point to a loadable libkcl: $path. '
    'Pass the shared library file (e.g. libkcl.dylib) or a directory that '
    'contains the <platform>/libkcl.<so|dylib|dll> subdirectory.',
  );
}

class _PlatformFileSpec {
  const _PlatformFileSpec(this.dir, this.name, this.ext);
  final String dir;
  final String name;
  final String ext;
}

_PlatformFileSpec _platformFileSpec() {
  // `Abi.current()` covers the desktop and mobile platforms that have
  // prebuilt libkcl archives under go/lib/. iOS does not surface here —
  // the iOS binary is statically linked into the app via `libkcl.a`, so
  // KCL_DART_LIB is never used on iOS at runtime.
  //
  // The Windows archives ship as `kcl.dll` (no `lib` prefix), matching the
  // Go embed path in `kcl_lib_windows_*.go`. Every other platform uses the
  // standard `libkcl.<so|dylib>` naming.
  switch (Abi.current()) {
    case Abi.macosArm64:
      return const _PlatformFileSpec('darwin-arm64', 'libkcl', 'dylib');
    case Abi.macosX64:
      return const _PlatformFileSpec('darwin-amd64', 'libkcl', 'dylib');
    case Abi.linuxArm64:
      // Prefer musl (Alpine) when available, fall back to glibc.
      return const _PlatformFileSpec('linux-arm64', 'libkcl', 'so');
    case Abi.linuxX64:
      return const _PlatformFileSpec('linux-amd64', 'libkcl', 'so');
    case Abi.windowsArm64:
      return const _PlatformFileSpec('windows-arm64', 'kcl', 'dll');
    case Abi.windowsX64:
      return const _PlatformFileSpec('windows-amd64', 'kcl', 'dll');
    case Abi.androidArm64:
      return const _PlatformFileSpec('android-arm64', 'libkcl', 'so');
    case Abi.androidX64:
      return const _PlatformFileSpec('android-x86_64', 'libkcl', 'so');
    default:
      throw StateError(
        'kcl_lib does not ship a libkcl binary for the current platform '
        '(${Abi.current()}). On iOS the static lib is linked into the app '
        'and resolved via DynamicLibrary.process() — KCL_DART_LIB is not '
        'needed. See README for the Flutter integration steps.',
      );
  }
}
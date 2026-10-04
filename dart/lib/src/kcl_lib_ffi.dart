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

// Service-handle C signatures (docs/abi.md §6). `call_native` is stateless and
// cannot carry a plugin agent, so a binding that supports plugins has to open a
// service handle and dispatch through it. The reply is NUL-terminated and owned
// by the caller, who releases it with `kcl_service_free_string`.
typedef _ServiceNewC = Pointer<Void> Function(IntPtr pluginAgent);
typedef _ServiceNewDart = Pointer<Void> Function(int pluginAgent);

typedef _ServiceCallC = Pointer<Utf8> Function(
  Pointer<Void> service,
  Pointer<Utf8> method,
  Pointer<Uint8> args,
  IntPtr argsLen,
  Pointer<IntPtr> outLen,
);

typedef _ServiceCallDart = Pointer<Utf8> Function(
  Pointer<Void> service,
  Pointer<Utf8> method,
  Pointer<Uint8> args,
  int argsLen,
  Pointer<IntPtr> outLen,
);

typedef _ServiceFreeStringC = Void Function(Pointer<Utf8> reply);
typedef _ServiceFreeStringDart = void Function(Pointer<Utf8> reply);

typedef _ServiceDeleteC = Void Function(Pointer<Void> service);
typedef _ServiceDeleteDart = void Function(Pointer<Void> service);

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

  final DynamicLibrary library;
  final _CallNativeDart _call;
  final Pointer<Uint8> _scratch;

  /// Set when a plugin agent is bound; see `kcl_plugin.dart`. While it is
  /// non-null, [call] dispatches through the handle instead of `call_native`.
  Pointer<Void>? _service;

  /// Lazily resolved service-handle entry points, keyed by the dlsym name.
  final _serviceFns = <String, Object>{};

  LibKcl._(this.library, this._call)
      : _scratch = calloc<Uint8>(kScratchBufferSize);

  /// Resets the process-wide singleton. Intended for tests only — the
  /// underlying `DynamicLibrary` cannot be closed on every platform, so
  /// leaking the singleton is the normal case.
  static void resetForTesting() {
    final cached = _singleton;
    if (cached != null) {
      if (cached._service != null) {
        cached._deleteService(cached._service!);
        cached._service = null;
      }
      calloc.free(cached._scratch);
    }
    _singleton = null;
  }

  /// Whether a plugin agent is currently bound, i.e. whether [call] routes
  /// through a service handle.
  bool get hasService => _service != null;

  /// Binds `pluginAgent` — the address of the host's plugin callback — and
  /// starts routing every call through a fresh service handle. The returned
  /// handle must be passed to [unbindService] (or deleted directly) to release
  /// the native side.
  Pointer<Void> bindService(int pluginAgent) {
    final existing = _service;
    if (existing != null) {
      return existing;
    }
    final newFn = library
        .lookup<NativeFunction<_ServiceNewC>>('kcl_service_new')
        .asFunction<_ServiceNewDart>();
    _serviceFns['new'] = newFn;
    return _service = newFn(pluginAgent);
  }

  /// Stops routing through the service handle, deleting it and returning the
  /// binding to the stateless `call_native` path.
  void unbindService() {
    final svc = _service;
    if (svc == null) return;
    _deleteService(svc);
    _service = null;
  }

  void _deleteService(Pointer<Void> service) {
    final fn = _serviceFns['delete'] as _ServiceDeleteDart? ??
        library
            .lookup<NativeFunction<_ServiceDeleteC>>('kcl_service_delete')
            .asFunction<_ServiceDeleteDart>();
    _serviceFns['delete'] = fn;
    fn(service);
  }

  /// Calls the given RPC through the service handle, returning the raw
  /// response bytes (the `"ERROR:"` prefix is left for `kcl_lib.dart`).
  Uint8List callWithService(Pointer<Void> service, String rpcName,
      Uint8List args) {
    final callFn = _serviceFns['call'] as _ServiceCallDart? ??
        library
            .lookup<NativeFunction<_ServiceCallC>>(
                'kcl_service_call_with_length')
            .asFunction<_ServiceCallDart>();
    final freeFn = _serviceFns['free'] as _ServiceFreeStringDart? ??
        library
            .lookup<NativeFunction<_ServiceFreeStringC>>(
                'kcl_service_free_string')
            .asFunction<_ServiceFreeStringDart>();
    _serviceFns['call'] = callFn;
    _serviceFns['free'] = freeFn;

    final namePtr = rpcName.toNativeUtf8();
    final argsPtr = calloc<Uint8>(args.isEmpty ? 1 : args.length);
    final outLen = calloc<IntPtr>();

    try {
      if (args.isNotEmpty) {
        argsPtr.asTypedList(args.length).setAll(0, args);
      }
      final reply = callFn(service, namePtr, argsPtr, args.length, outLen);
      if (reply == nullptr) {
        throw StateError(
          'libkcl returned a null reply for $rpcName through the service handle',
        );
      }
      try {
        // The reply is always NUL-terminated, but the runtime only writes
        // `out_len` on the success path — its panic branch returns an
        // "ERROR:..." string without setting it. Recover the length from the
        // terminator in that case so the error still reaches the caller.
        final bytes = reply.toDartString().codeUnits;
        return Uint8List.fromList(
          outLen.value == 0 ? bytes : bytes.take(outLen.value).toList(),
        );
      } finally {
        freeFn(reply);
      }
    } finally {
      calloc.free(namePtr);
      calloc.free(argsPtr);
      calloc.free(outLen);
    }
  }

  /// Calls `call_native` with the given RPC name and protobuf-encoded `args`.
  /// Returns the raw response bytes (no `ERROR:` decoding here — the public
  /// API in `kcl_lib.dart` does that).
  Uint8List call(String rpcName, Uint8List args) {
    // A bound plugin agent can only travel with a service handle, so once one
    // is registered every call routes through it. With nothing bound this is
    // exactly the stateless path, leaving programs that do not use plugins
    // untouched.
    final service = _service;
    if (service != null) {
      return callWithService(service, rpcName, args);
    }

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
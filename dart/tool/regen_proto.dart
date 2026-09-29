// Regenerate the vendored Dart protobuf message code from ../spec/spec.proto.
//
// Usage (from the dart/ directory):
//     dart run tool/regen_proto.dart
//
// Equivalent to `make proto`. Requires `protoc` on PATH and `protoc-gen-dart`
// (install with `dart pub global activate protoc_plugin`, then add
// \$HOME/.pub-cache/bin to PATH). Generated `.pb.dart` / `.pbjson.dart` files
// land in lib/src/pb/.
//
// Like the Julia binding's gen script (`julia/hack/gen_pb.jl`), we strip the
// top-level `service Foo { ... }` blocks from spec.proto before invoking
// protoc. The native dispatcher routes by RPC name string (see
// c/include/kcl_ffi.h), so the service blocks are unused — and stripping
// them avoids generating a `spec.pbserver.dart` (gRPC server stubs) that
// nothing imports.

import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  for (final tool in ['protoc', 'protoc-gen-dart']) {
    final found = await _which(tool);
    if (found == null) {
      stderr.writeln(
        '$tool not found on PATH.\n'
        'Install protoc (brew install protobuf / apt-get install '
        'protobuf-compiler) and protoc-gen-dart (dart pub global activate '
        'protoc_plugin).',
      );
      exit(1);
    }
  }

  final pkgRoot = p.dirname(p.dirname(Platform.script.toFilePath()));
  final spec = p.normalize(p.join(pkgRoot, '..', 'spec', 'spec.proto'));
  final out = p.join(pkgRoot, 'lib', 'src', 'pb');

  if (!File(spec).existsSync()) {
    stderr.writeln('spec not found: $spec');
    exit(1);
  }
  Directory(out).createSync(recursive: true);

  // Strip `service` blocks into a scratch proto file so protoc_plugin only
  // emits message code (matches the Julia binding's behavior).
  final stripped = _stripServices(File(spec).readAsStringSync());
  Directory systemTemp = Directory.systemTemp;
  final tmpDir = await systemTemp.createTemp('kcl_lib_regen_');
  final tmpProto = File(p.join(tmpDir.path, 'spec.proto'));
  await tmpProto.writeAsString(stripped);

  try {
    final result = await Process.run(
      'protoc',
      [
        '-I${tmpDir.path}',
        p.normalize(tmpProto.path),
        '--dart_out=${p.absolute(out)}',
      ],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      stderr.writeln(result.stdout);
      stderr.writeln(result.stderr);
      exit(result.exitCode);
    }
  } finally {
    if (tmpDir.existsSync()) {
      await tmpDir.delete(recursive: true);
    }
  }

  stdout.writeln('Regenerated Dart protobuf code in ${p.absolute(out)}');
}

/// Drop top-level `service Foo { ... }` blocks (column-0 delimiters). The
/// native dispatcher routes by RPC name string, so the service declarations
/// are unused; dropping them avoids emitting a `spec.pbserver.dart` (gRPC
/// server stubs) that no Dart code imports.
String _stripServices(String text) {
  final out = StringBuffer();
  var inService = false;
  for (final line in text.split('\n')) {
    if (!inService) {
      if (RegExp(r'^service\s+\w+\s*\{\s*$').hasMatch(line)) {
        inService = true;
      } else {
        out.writeln(line);
      }
    } else if (line == '}') {
      inService = false;
    }
    // else: drop the line — we're inside a service block.
  }
  if (inService) {
    throw StateError('Unbalanced service block in spec.proto');
  }
  return out.toString();
}

Future<String?> _which(String tool) async {
  final result = await Process.run('which', [tool]);
  return result.exitCode == 0 ? result.stdout.toString().trim() : null;
}
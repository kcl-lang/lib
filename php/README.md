# kcl-lib — PHP binding for KCL

A PHP language binding for the [KCL configuration language](https://kcl-lang.io).
Like the other bindings in this repository, it is a thin wrapper around the
universal protobuf dispatcher shipped as a prebuilt `libkcl` shared library —
the PHP runtime never builds any Rust code. Messages are protobuf-encoded
and decoded with the official [`google/protobuf`][protobuf-php] PHP runtime;
the generated message code under `src/Api/` is checked in, following the
repository convention.

[protobuf-php]: https://github.com/protocolbuffers/protobuf/tree/main/php

## Installation

From a PHP project, install directly from this repository (the package lives
under the `php/` subdirectory):

```shell
composer require kcl-lang/kcl-lib-php:@dev
# with a VCS repository entry pointing at this monorepo's php/ directory
```

Requirements:

- **PHP 8.1 or later** with the FFI extension. On the CLI SAPI FFI is always
  enabled; under a web SAPI set `ffi.enable=true` in `php.ini` (the binding
  uses `FFI::cdef` at runtime, so `preload` is not enough there).
- **`libkcl` prebuilt binary for your platform.** By default the binding
  walks up from `src/KclLib.php` looking for the platform file under
  `go/lib/` in this checkout (`go/lib/darwin-arm64/libkcl.dylib` on Apple
  silicon, `go/lib/linux-amd64/libkcl.so` on Linux, …). Set the
  `KCL_PHP_LIB` environment variable to override it — either the shared
  library file itself or a directory whose layout matches `go/lib/`.

```shell
composer install          # in php/
```

## Usage

```php
<?php
require 'vendor/autoload.php';

use KclLib\ServiceClient;

$client = new ServiceClient();

// Run KCL code from memory
$result = $client->execProgram(['k_code_list' => ['alice = {age = 18}']]);
echo $result->getYamlResult();   // alice:\n  age: 18

// Parse a file and walk the typed AST
$parsed = $client->parseFile(['path' => 'hello.k', 'source' => "a = 1\n"]);
$module = KclLib\Ast\Ast::parseModule($parsed->getAstJson());
foreach ($module->body as $stmt) {
    // each $stmt is a KclLib\Ast\NodeRef; $stmt->node is a typed Stmt
}

// Build AST nodes ergonomically
$one = KclLib\Ast\AstBuild::numberLit(value: KclLib\Ast\AstBuild::numberLitValue('Int', 1));

// Host KCL plugins: a PHP callable receives kcl_plugin.<module>.<method>
$client = new ServiceClient(null, function (string $method, string $args, string $kwargs): string {
    return '"joined"';
});
$client->execProgram(['k_code_list' => ['import kcl_plugin.strings' . "\n" . 'result = strings.join("a", "b")']]);
```

Every RPC in `spec/spec.proto` has one method on `ServiceClient`, in the
services' declaration order. Arguments accept the generated message classes
or plain arrays (converted through the protobuf-JSON codec). A native-side
failure — an unknown RPC, malformed request, or a KCL error — arrives with
the `ERROR:` prefix and is raised as `KclLib\KclException`.

## Layout

- `src/KclLib.php` — the FFI loader: `call_native`, the 4 MiB result buffer,
  library resolution (`KCL_PHP_LIB` or `go/lib/<platform>/`), and the
  plugin-agent entry point through the service-handle API.
- `src/ServiceClient.php` — one method per RPC: serialize, call, decode, raise.
- `src/Api/` — `protoc --php_out` gencode from `spec/spec.proto` (pinned in
  `../spec/Makefile` and `Makefile` here).
- `src/Ast/` — the typed AST: one generated class per `ast.rs` struct plus
  the `Wire` decoders, `Ast::parseModule/parseProgram` entry points and the
  `AstBuild` constructors. Regenerate with `python3 tools/generate_ast.py`
  from the repository root.
- `ffi/kcl_ffi.h` — the verbatim copy of `c/include/kcl_ffi.h`; the runtime
  cdef in `KclLib` mirrors it (PHP's FFI parser has no C preprocessor).
- `tests/` — phpunit suites: the service client against the vendored dylib,
  the AST contract against the shared golden capture, and the cross-language
  consistency runner over `tests/consistency/cases.json`.

## Development

```shell
make test     # composer install && ./vendor/bin/phpunit
```

The binding is part of the repository's L3 checks: `hack/check_ast_field_types.rb`
and `hack/check_ast_constructors.rb` read the generated decoders and
constructors mechanically, and `hack/ast_diff.rb php` diffs this decoder's
output over the shared AST capture against every other binding.

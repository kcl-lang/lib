# KCL Artifact Library for Ruby

> [!WARNING]
> This is the initial version of the Ruby bindings, PRs welcome!

A Ruby library for interacting with KCL (Kusion Configuration Language) artifacts. This library
enables you to work with KCL modules, configurations, and artifacts directly from Ruby.

The gem is a thin layering on top of the same native runtime used by all the other bindings in
this repository: a Rust `cdylib` (crate `kcl-lib-ruby`, built on the [`kcl-api`](https://github.com/kcl-lang/kcl)
crate) exposes `KclLib.call` / `KclLib.call_with_plugin_agent`, which dispatch KCL RPCs by name
with protobuf-encoded request/response bytes. Everything else is plain Ruby in `lib/kcl_lib`.

## Installation

You will need the following tooling regardless of which installation approach you choose.

- **Rust** (with Cargo) - For building the native extension.
- **Ruby** >= 3.1 - The target Ruby version.
- **protoc** - Only needed if you want to re-generate `lib/kcl_lib/spec_pb.rb`.

The gem is currently packaged as source files; the native extension must be built locally:

```bash
gem install google-protobuf   # runtime dependency, pure install
make build                    # cargo build --release + copy the dylib into lib/
```

## Usage

### Quickstart

```ruby
require "kcl_lib"

args = KclLib::ExecProgramArgs.new(k_filename_list: ["./test_data/schema.k"])
api = KclLib::API.new
result = api.exec_program(args)
puts result.yaml_result
# => "app:\n  replicas: 2"
```

Execute in-memory KCL source with `k_code_list`:

```ruby
require "kcl_lib"

api = KclLib::API.new
result = api.exec_program(KclLib::ExecProgramArgs.new(k_code_list: ["alice = {age = 18}"]))
puts result.yaml_result
```

### Facade

`KclLib::Kcl` is a thin high-level layer over `KclLib::API`, mirroring kcl-go's `pkg/kcl`. It
assembles `ExecProgramArgs` from keyword options, returns a `KclLib::KclResultList` and raises
`KclLib::KclError` when the run reports an error.

```ruby
require "kcl_lib"

result = KclLib::Kcl.run("a = 1")
result.first.get("a")            # => 1

KclLib::Kcl.run_files("./test_data/schema.k").first.get_int("app.replicas")
# => 2
```

#### Options

`run` and `run_files` accept keyword options mirroring the `ExecProgramArgs` fields in
snake_case:

| Option | Type | Notes |
| --- | --- | --- |
| `:code` | `String`, `Array<String>` | in-memory KCL source |
| `:files` | `String`, `Array<String>` | KCL files to evaluate |
| `:work_dir` | `String` | working directory for relative paths |
| `:args` | `Array<String>`, `Array<Hash>` | `["env=prod"]` or `[{name: "env", value: "prod"}]`; malformed specs are skipped |
| `:overrides` | `Array<String>` | `-p`-style override specs |
| `:path_selector` | `Array<String>` | `-S`-style path selectors |
| `:external_pkgs` | `Array<String>`, `Array<Hash>` | `["name=path"]` or `[{pkg_name:, pkg_path:}]` |
| `:format` | `String` | output format, e.g. `"yaml"` to suppress the JSON result |
| `:error_format` | `String` | error message format |
| `:sort_keys` | `Boolean` | sort mapping keys in the output |
| `:disable_none` | `Boolean` | drop `None` values from the output |
| `:show_hidden` | `Boolean` | include hidden (`_`-prefixed) fields |
| `:include_schema_type_path` | `Boolean` | fully qualify schema type names |
| `:strict_range_check` | `Boolean` | reject out-of-range values |
| `:compile_only` | `Boolean` | type-check without evaluating |
| `:print_override_ast` | `Boolean` | print the override AST |
| `:verbose` | `Integer` | verbosity level |
| `:debug` | `Integer` | debug level |

#### Results

`KclLib::KclResultList` is an `Array` of `KclLib::KclResult`, one per emitted document. Each
result offers both a lenient and a strict accessor:

```ruby
result = KclLib::Kcl.run_files("./test_data/schema.k").first

result.get("app.replicas")       # => 2, nil when the path is missing
result.get("a.b", :fallback)     # => :fallback when the path is missing
result.get("items.0.name")       # integer segments index into lists

result.get_int("app.replicas")   # strict: raises on a missing path or type mismatch
result.get_str("app.name")
result.get_float("app.ratio")
result.get_bool("app.enabled")

result.to_map                    # the whole document as a Hash
result.yaml_document             # the raw YAML text of this document
```

#### Validation

```ruby
code = "schema Person:\n    name: str\n    age: int\n    check:\n        0 < age < 120\n"

KclLib::Kcl.validate(code, '{"name": "Alice", "age": 10}')       # => true
KclLib::Kcl.validate(code, "name: Alice", format: "yaml")         # => true
KclLib::Kcl.validate(code, '{"name": "Alice", "age": 1110}')     # raises KclLib::KclError
```

#### Splitting a YAML stream

`KclLib::Kcl.split_documents` mirrors kcl-go's exported `SplitDocuments`. Trailing whitespace or
`#` comments are allowed on the `---` separator line; anything else raises.

```ruby
KclLib::Kcl.split_documents("a: 1\n---\nb: 2\n")        # => ["a: 1", "b: 2"]
KclLib::Kcl.split_documents("a: 1\n--- # note\nb: 2")    # => ["a: 1", "b: 2"]
KclLib::Kcl.split_documents("a: 1\n--- b: 2\n")         # raises KclLib::KclError
```

### Error semantics

Every RPC decodes the runtime reply and raises `KclLib::KclError` when the payload is prefixed
with `ERROR:` (the convention of the Rust dispatcher, see `docs/abi.md` §4):

```ruby
require "kcl_lib"

api = KclLib::API.new
begin
  api.exec_program(KclLib::ExecProgramArgs.new(k_filename_list: ["file_not_found"]))
rescue KclLib::KclError => e
  puts e.message # => "Cannot find the kcl file ..."
end
```

### Raw calls

`KclLib::API#call` is public: any RPC name the runtime understands can be invoked with a request
message, and the decoded response message is returned.

```ruby
require "kcl_lib"

api = KclLib::API.new
result = api.call("KclService.Ping", KclLib::PingArgs.new(value: "raw"))
puts result.value # => "raw"
```

## API Reference

All 20 `KclService` RPCs are exposed as snake_case methods on `KclLib::API`. Request/response
messages are the generated protobuf classes (also re-exported under the `KclLib` namespace).

### ping

Ping the KCL service and return the same value.

```ruby
api = KclLib::API.new
result = api.ping(KclLib::PingArgs.new(value: "Hello, KCL!"))
puts result.value # => "Hello, KCL!"
```

### get_version

Return the KCL service version information.

```ruby
api = KclLib::API.new
result = api.get_version
puts result.version_info
```

### exec_program

Execute KCL files or in-memory sources and return the JSON/YAML result.

```ruby
api = KclLib::API.new
result = api.exec_program(KclLib::ExecProgramArgs.new(k_filename_list: ["schema.k"]))
puts result.yaml_result
```

### parse_program

Parse KCL program with entry files and return the AST JSON string.

```ruby
api = KclLib::API.new
result = api.parse_program(KclLib::ParseProgramArgs.new(paths: ["schema.k"]))
raise "parse failed" unless result.errors.empty?
```

### parse_file

Parse a single KCL file to a Module AST JSON string with import dependencies and parse errors.

```ruby
api = KclLib::API.new
result = api.parse_file(KclLib::ParseFileArgs.new(path: "schema.k"))
```

### Typed AST

`parse_file` and `parse_program` return the AST as a JSON string.
`KclLib::AST.parse_module` and `KclLib::AST.parse_program_ast` decode it into
typed objects mirroring Rust's AST in `../kcl/crates/ast/src/ast.rs`.

```ruby
require "kcl_lib"

m = KclLib::AST.parse_module(KclLib::API.new.parse_file(KclLib::ParseFileArgs.new(
  path: "main.k",
  source: <<~KCL
    schema Person:
        name: str = "anonymous"
        age: int = 0
  KCL
)).ast_json)

m.body.each do |ref|
  next unless ref.node.is_a?(KclLib::AST::SchemaStmt)

  puts "#{ref.node.name.node} on line #{ref.pos.line}"
  ref.node.body.each do |attr|
    a = attr.node
    puts "  #{a.name.node}: #{a.ty.node}" if a.is_a?(KclLib::AST::SchemaAttr)
  end
end
```

`AST::Node` pairs a value with the `AST::Pos` it was parsed at, mirroring Rust's
`NodeRef<T>`. Every expression and statement exposes the `type` tag the parser
emitted through `#tag`, which is the same discriminator the other bindings key
their dispatch on. Fields are readable both as methods (`stmt.op`) and through
`[]` (`stmt[:op]`), and `#to_h` round-trips back to the parser JSON.

The class names are the Java binding's
(`java/src/main/java/com/kcl/ast/`), so a table read from one binding is
readable in the next: `Compare`, `ListComp`, `DictComp`, `NumberLit`,
`StringLit`, `NameConstantLit`, `JoinedString`, `FormattedValue`, `Subscript`,
`SchemaExpr`, `CallExpr`, `CheckExpr`, `SchemaConfig`, `Decorator`, `Module`,
`Pos`, `Node`. Two of those are *twins* of a tagged variant, because the wire
has two shapes for them: `CallExpr` is the tagged `Expr::Call` while
`Decorator` is the untagged `{func, args, keywords}` a `decorators:` list
holds, and `SchemaExpr` is the tagged `Expr::Schema` while `SchemaConfig` is
the untagged `{name, args, kwargs, config}` an `UnificationStmt#value` holds.
`CheckExpr` is the exception — the payload is identical either way, so one
class serves both. `AST::KclModule` is kept as an alias for `AST::Module`.

Three serde shapes are worth knowing, because they are the details most easily
guessed wrong:

- `Stmt` and `Expr` are `#[serde(tag = "type")]`. Because the variants are
  newtypes over a struct, serde *flattens* the struct's fields into the same
  object — an identifier is `{"type": "Identifier", "names": [...]}`, not
  `{"type": "Identifier", "identifier": {...}}`.
- `Type` is `#[serde(tag = "type", content = "value")]`, so a basic type reads
  back as `{"type": "Basic", "value": "Int"}`, **not** `{"type": "Int"}`. Use
  `AST::BasicType` / `AST::UnionType` / `AST::DictType` and read the payload off
  the struct.
- The plain structs nested inside `NodeRef<T>` — `Identifier`, `Target`,
  `Keyword`, `Arguments`, `ConfigEntry`, `CheckExpr`, `Decorator`,
  `SchemaConfig`, `CompClause` — carry no tag. That is why
  `SchemaStmt#decorators` decodes to a `Decorator` rather than a tagged
  variant, and why `SchemaExpr#name` is an `AST::Node` wrapping an
  `Identifier` rather than wrapping an expression.

  A field declared as a struct rather than as an enum variant has no tag *even
  inside a tagged node*, which is the subtle case. `UnificationStmt#value` is a
  `NodeRef<SchemaExpr>`, so it arrives as a bare `{name, args, kwargs, config}`
  with no `"type"` key. The untagged decoders (`AST.schema_expr_from_wire`,
  `AST.call_expr_from_wire`, `AST.check_from_wire`, `AST.comp_clause_from_wire`)
  therefore have to be reachable on their own, and the ones that return a
  distinct class are named for the Rust struct the wire holds rather than for
  what they build.

An unrecognised tag decodes to `AST::UnknownStmt` / `AST::UnknownExpr` with the
raw payload attached, so a newer parser degrades instead of raising. A payload
with **no** tag is a different thing and raises: an untagged payload routed
through a tagged decoder has nothing to dispatch on, and it used to come back
as a plausible-looking node whose `variant` was `nil`.

`parse_program_ast` accepts both program encodings: a bare array of modules and
the `{"root": …, "pkgs": {"__main__": […]}}` envelope.

### load_package

Parse a KCL program and return the semantic model: symbols, types, scopes, definitions, etc.

```ruby
api = KclLib::API.new
result = api.load_package(
  KclLib::LoadPackageArgs.new(
    parse_args: KclLib::ParseProgramArgs.new(paths: ["schema.k"]),
    resolve_ast: true
  )
)
puts result.symbols.values.map { |s| s.ty.schema_name }
```

### list_options

Parse a KCL program and get all `option(...)` information.

```ruby
api = KclLib::API.new
result = api.list_options(KclLib::ParseProgramArgs.new(paths: ["options.k"]))
puts result.options.map(&:name)
```

### list_variables

Parse a KCL program and get all top-level variables.

```ruby
api = KclLib::API.new
result = api.list_variables(KclLib::ListVariablesArgs.new(files: ["schema.k"]))
puts result.variables["app"].variables[0].value
```

### override_file

Override a KCL file with [override specs](https://www.kcl-lang.io/docs/user_docs/guides/automation).

```ruby
api = KclLib::API.new
result = api.override_file(KclLib::OverrideFileArgs.new(file: "main.k", specs: ["b.a=2"]))
raise "override failed" unless result.result
```

### get_schema_type_mapping / get_schema_type_mapping_under_path

Get the schema type mapping defined in the program; the `_under_path` variant is keyed by
package name and includes external dependency packages.

```ruby
api = KclLib::API.new
exec_args = KclLib::ExecProgramArgs.new(k_filename_list: ["schema.k"])
result = api.get_schema_type_mapping(KclLib::GetSchemaTypeMappingArgs.new(exec_args: exec_args))
puts result.schema_type_mapping["app"].properties["replicas"].type # => "int"
```

### format_code / format_path

Format KCL source code, or a file/directory of KCL files (returns changed paths).

```ruby
api = KclLib::API.new
result = api.format_code(KclLib::FormatCodeArgs.new(source: "a   =   1"))
puts result.formatted # => "a = 1"
```

### lint_path

Lint files and return error messages including errors and warnings.

```ruby
api = KclLib::API.new
result = api.lint_path(KclLib::LintPathArgs.new(paths: ["lint_path.k"]))
puts result.results
```

### validate_code

Validate JSON/YAML data against a schema.

```ruby
code = "schema Person:\n    name: str\n    age: int\n    check:\n        0 < age < 120"
api = KclLib::API.new
result = api.validate_code(
  KclLib::ValidateCodeArgs.new(code: code, data: '{"name": "Alice", "age": 10}', format: "json")
)
puts result.success # => true
```

### load_settings_files

Load the setting file config defined in `kcl.yaml`.

```ruby
api = KclLib::API.new
result = api.load_settings_files(
  KclLib::LoadSettingsFilesArgs.new(work_dir: ".", files: ["kcl.yaml"])
)
puts result.kcl_cli_configs.strict_range_check
```

### rename / rename_code

Rename all occurrences of a symbol. `rename` rewrites files and returns the changed paths;
`rename_code` works on in-memory sources and returns the changed code.

```ruby
api = KclLib::API.new
result = api.rename_code(
  KclLib::RenameCodeArgs.new(
    package_root: "/mock/path",
    symbol_path: "a",
    source_codes: { "/mock/path/main.k" => "a = 1\nb = a" },
    new_name: "a2"
  )
)
puts result.changed_codes["/mock/path/main.k"] # => "a2 = 1\nb = a2"
```

### test

Run KCL package tests.

```ruby
api = KclLib::API.new
result = api.test(KclLib::TestArgs.new(pkg_list: ["./test_data/testing/..."]))
puts result.info.map(&:name)
```

### format_test_report

Format a test result into a human-readable report.

```ruby
api = KclLib::API.new
result = api.test(KclLib::TestArgs.new(pkg_list: ["./test_data/testing/..."]))
puts api.format_test_report(KclLib::FormatTestReportArgs.new(result: result)).report
```

### update_dependencies

Download and update dependencies defined in the `kcl.mod` file.

```ruby
api = KclLib::API.new
result = api.update_dependencies(
  KclLib::UpdateDependenciesArgs.new(manifest_path: "./test_data/update_dependencies")
)
puts result.external_pkgs.map(&:pkg_name)
```

### list_method

List the method names supported by the underlying runtime.

```ruby
api = KclLib::API.new
puts api.list_method.method_name_list
```

## Platform Notes

- **macOS**: the Homebrew Ruby is keg-only. The `Makefile` prefers
  `/opt/homebrew/opt/ruby@3.4/bin/ruby` when present (magnus 0.7.x does not compile against
  Ruby 4.0 headers yet, see "Known limitations" below), otherwise falls back to `ruby` on `PATH`.
- **Linux**: any Ruby >= 3.1 with dev headers works; rb-sys locates it from `PATH`/`RUBY`.

### Known limitations of this initial version

- magnus 0.7.x predates Ruby 4.0: it fails to compile against Ruby 4.0 headers
  (`RTypedData.typed_flag` was removed). Use Ruby 3.4 for local development and CI for now.
- The native extension is loaded from `lib/kcl_lib/kcl_ruby.bundle`, which `make build` copies
  from the Cargo `release` directory. Precompiled gems for rubygems.org are not set up yet.
- The gem metadata (authors, email, publish workflow) is a placeholder until the first release.

## Development

### Running Tests

```bash
make test
```

This builds the native extension if needed and runs the minitest suite in `test/` with the
fixtures in `test_data/`.

The two AST tests check different things, and both are load-bearing:

- `test/ast_test.rb` parses a live fixture through the service, which proves the
  decoder accepts *something* the parser emits.
- `test/ast_contract_test.rb` decodes the captured golden parse at
  `../testdata/ast/alignment.json` — the same file the C, C++, Dart, Java,
  Kotlin, Node.js, Python, .NET, WASM, Lua, Swift, Zig and Julia bindings use —
  and asserts the typed tree matches it field by field. Its final case walks
  every node in the capture and fails on any tag that fell through to
  `AST::Unknown*`.

That walk is the point. A mistyped `type` tag does not raise; it produces a
zero-valued node, so field-by-field assertions on a handful of nodes would sail
straight past a decoder that resolves nothing. A payload with *no* tag is a
different failure and does raise, so the decoder rejects it outright rather than
letting the walk miss it; the `UnificationStmt` case still asserts the value's
class and not just its presence, because a `SchemaConfig` that arrived with a
`type` key would decode just as quietly.

### Re-generating the protobuf classes

`lib/kcl_lib/spec_pb.rb` is generated from the single source of truth `../spec/spec.proto` and
vendored into this repository, like the other language bindings:

```bash
make proto
```

`lib/kcl_lib/ast.rb` is hand-written, not generated. It tracks
`../kcl/crates/ast/src/ast.rs`.

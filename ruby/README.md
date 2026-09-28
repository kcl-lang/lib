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

### Re-generating the protobuf classes

`lib/kcl_lib/spec_pb.rb` is generated from the single source of truth `../spec/spec.proto` and
vendored into this repository, like the other language bindings:

```bash
make proto
```

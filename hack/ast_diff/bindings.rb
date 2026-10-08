# frozen_string_literal: true

# One entry per binding, describing how to run its decoder over the golden
# capture and what to do with the dump it writes.
#
# The two failure modes this table has to keep apart:
#
#   * "these bindings disagree"  — a real bug in one of them. The comparator
#     fails and prints the path and the two values.
#   * "this binding could not run here" — uninteresting. The toolchain is not
#     installed, the dependency tree has not been fetched, the build artifact
#     is missing. The comparator reports it as SKIPPED with the reason and
#     moves on; it is not a failure and must never be counted as a pass.
#
# A binding is therefore *probed* before it is run. If the probe fails the
# binding is skipped; if the probe succeeds and the run fails, that is a real
# failure and the comparator says so loudly, because a dumper that crashes on
# a decoder exception is telling us the decoder raised — which for these AST
# decoders is itself the interesting signal.
#
# `extra_ok` lists keys a binding's dump may carry that the Rust wire has no
# counterpart for. Each one needs a reason: a key that silently disappears is
# a hole in the diff. `renames` does the same job for the other direction —
# a field the binding named differently from the wire, mapped to the wire's
# name so the comparison is about *values* and not about spelling.

require "open3"

module AstDiff
  ROOT = File.expand_path("../..", __dir__)

  Binding = Struct.new(:name, :probe, :argv, :mode, :extra_ok, :renames, :class_renames,
                       :note, keyword_init: true) do
    # The three tables default to empty rather than nil, so a binding that has
    # nothing to say about them does not have to spell that out.
    def initialize(extra_ok: {}, renames: {}, class_renames: nil, **rest)
      super(extra_ok: extra_ok, renames: renames,
            class_renames: class_renames || rest.fetch(:class_renames, {}), **rest)
    end

    def to_s = name
  end

  # `which` returns the absolute path of a tool, or nil.
  def self.which(*names)
    names.each do |n|
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
        candidate = File.join(dir, n)
        return candidate if File.executable?(candidate) && !File.directory?(candidate)
      end
    end
    nil
  end

  # A probe is `nil` (toolchain present) or a string explaining the skip.
  # The string is printed verbatim in the report, so it has to name the thing
  # that is missing rather than say "unavailable".
  def self.run_probe(argv)
    out, _err, status = Open3.capture3(*argv, chdir: ROOT)
    return nil if status.success?

    "probe failed: `#{argv.join(' ')}` exited #{status.exitstatus}\n#{out.lines.last(3).join}"
  rescue Errno::ENOENT => e
    "toolchain missing: #{e.message}"
  end

  module_function

  def bindings
    @bindings ||= [
      # ---------------------------------------------------------------- php
      Binding.new(
        name: "php",
        mode: :reflect,
        probe: lambda {
          php = which("php")
          return "no `php` interpreter on PATH" unless php

          return "php dependencies are not resolved (no php/vendor/autoload.php — run `composer install` in php/)" \
            unless File.file?(File.join(ROOT, "php", "vendor", "autoload.php"))

          run_probe([php, "-r", "require 'php/vendor/autoload.php'; new KclLib\\Ast\\Identifier();"])
        },
        argv: ->(golden, out) { ["php", "hack/dump/php.php", golden, out] },
        extra_ok: {
          # `LiteralType::inner_tag()` — the tag *inside* the verbatim payload
          # (`value.type`), exposed so a caller can ask "which literal kind"
          # without walking in. `ast.rs:LiteralType` has `pub value` and
          # nothing else.
          "innertag" => "a copy of value.type that the wire does not carry"
        },
        class_renames: {
          # `NumberLitValue` and `MemberOrIndex` are their own `tag + content`
          # enums; the PHP classes carry the tag in `kind` and the payload in
          # `value` / `node`, so the fields are mapped back to the wire's
          # spelling before the values are compared.
          "numberlitvalue" => { "kind" => "type" },
          "memberorindex" => { "kind" => "type", "node" => "value" }
        },
        note: "Class-based decoder walked by reflection; the tag is the " \
              "binding's own class-to-tag table in hack/dump/php.php, and " \
              "@cls is cross-checked against it by CLASS_TAGS. Position is " \
              "flat on NodeRef, which is the wire shape. The dumper loads " \
              "the composer autoloader, so php/ needs `composer install`."
      ),

      # --------------------------------------------------------------- ruby
      Binding.new(
        name: "ruby",
        mode: :reflect,
        probe: -> { run_probe(["ruby", "-Iruby/lib", "-e", "require 'kcl_lib/ast'"]) },
        argv: ->(golden, out) { ["ruby", "-Iruby/lib", "hack/dump/ruby.rb", golden, out] },
        extra_ok: {
          # `LiteralType#inner_tag` is the same string as `value["type"]`, kept
          # beside the payload so the class can answer "which literal kind is
          # this" without walking into it. `ast.rs:LiteralType` has no such
          # field: `pub value: Box<NodeRef<LiteralTypeValue>>` and nothing
          # else. It is a convenience, not a decode, and the value it holds is
          # compared against the golden's `value.type` at the next level down.
          "innertag" => "a copy of value.type that the wire does not carry"
        },
        renames: {
          # `ast.rs:UnionType` — `pub type_elements: Vec<NodeRef<Type>>`. The
          # Ruby field is `types` (ast.rb:450), which reads better in Ruby and
          # loses nothing.
          "types" => "typeelements"
        },
        note: "Struct-based decoder; position is nested under `Node#pos`."
      ),

      # ------------------------------------------------------------- python
      Binding.new(
        name: "python",
        mode: :reflect,
        probe: lambda {
          # `kcl_lib/__init__.py` does `from ._kcl_lib import *`, so importing
          # the package pulls in the compiled extension. The AST subpackage
          # does not use it, and the binding's own contract test installs the
          # same stub — so the probe installs it too rather than pretending
          # the dumper needs a built `_kcl_lib`.
          run_probe(["python3", "-c", <<~PY])
            import sys, types, os
            sys.path.insert(0, "python")
            stub = types.ModuleType("kcl_lib")
            stub.__path__ = [os.path.abspath("python/kcl_lib")]
            sys.modules["kcl_lib"] = stub
            import kcl_lib.ast
          PY
        },
        argv: ->(golden, out) { ["python3", "hack/dump/python.py", golden, out] },
        extra_ok: {
          # `_types.py:LiteralType.inner_tag` — `self.value.get("type", "")`,
          # a property that reads the tag out of the raw payload it already
          # holds. `ast.rs:LiteralType` has `pub value` and nothing else.
          "innertag" => "a copy of value.type that the wire does not carry"
        },
        renames: {
          # `ast.rs:UnionType` — `pub type_elements: Vec<NodeRef<Type>>`. The
          # Python field is `type_elements` too; `union_type` reads it.
        },
        class_renames: {
          # `NumberLitValue` and `MemberOrIndex` are their own `tag + content`
          # enums, so the wire is `{"type":"Int","value":1}` and
          # `{"type":"Member","value":{…}}`. Both classes keep the tag in a
          # field called `kind` (`_expr.py:94`, `_dto.py:400`) so the class
          # can hold the tag and the payload without a wrapper; both `to_dict`
          # methods write `kind` back out under `"type"`.
          "numberlitvalue" => { "kind" => "type" },
          "memberorindex" => { "kind" => "type" }
        },
        note: "Dataclasses, walked by reflection; the tag comes from the " \
              "binding's own `_expr_tag_for` / `_stmt_tag_for` / " \
              "`_type_tag_for` registries. `--wire` on the dumper runs the " \
              "same capture through `Module.to_dict()` instead."
      ),

      # ------------------------------------------------------------- nodejs
      Binding.new(
        name: "nodejs",
        mode: :reflect,
        probe: -> { run_probe(["node", "--version"]) },
        argv: ->(golden, out) { ["node", "hack/dump/nodejs.mjs", golden, out] },
        extra_ok: {
          # `_types.mjs:161` — `innerTag: value.type`, a copy of the inner
          # `LiteralType` tag kept beside the payload so a caller can ask
          # "which literal kind" without walking in. `ast.rs:LiteralType` has
          # `pub value` and nothing else.
          "innertag" => "a copy of value.type that the wire does not carry"
        },
        renames: {
          # `_types.mjs:58` says so in the source: "as `types` here because
          # `types` is what a caller reaches for". `ast.rs:UnionType` calls it
          # `type_elements`.
          "types" => "typeelements"
        },
        note: "Plain objects, so there is no class name to cross-check — " \
              "only the `type` value. Position is flat; `Comment` is flattened too."
      ),

      # --------------------------------------------------------------- wasm
      Binding.new(
        name: "wasm",
        mode: :reflect,
        probe: lambda {
          tsc = File.join(ROOT, "wasm", "node_modules", ".bin", "tsc")
          return "typescript is not installed (run `npm i` in wasm/)" unless File.executable?(tsc)

          run_probe(["node", "--version"])
        },
        argv: ->(golden, out) { ["bash", "hack/dump/wasm.sh", golden, out] },
        extra_ok: {
          # `_types.ts:81` — `innerTag?: string`, a copy of the tag the wire
          # keeps under `value.type`, held beside the verbatim payload.
          # `ast.rs:LiteralType` has `pub value` and nothing else.
          "innertag" => "a copy of value.type that the wire does not carry"
        },
        renames: {
          # `_types.ts:57` says so in the source: "The Rust field is
          # `type_elements`; it is exposed as `types` here because `types` is
          # what a caller reaches for". `ast.rs:UnionType` calls it
          # `type_elements`.
          "types" => "typeelements"
        },
        note: "TypeScript decoder, compiled to CommonJS and run under node. " \
              "Plain objects, so there is no class name to cross-check."
      ),

      # ---------------------------------------------------------------- lua
      Binding.new(
        name: "lua",
        mode: :reflect,
        probe: lambda {
          lua = which("lua")
          return "no `lua` interpreter on PATH" unless lua

          run_probe(["lua", "-e", "package.path = './?.lua;lua/?.lua;' .. package.path; " \
                                "require 'dkjson'; require 'kcl_lib.ast'"])
        },
        argv: ->(golden, out) { ["lua", "hack/dump/lua.lua", golden, out] },
        extra_ok: {
          # `parse_literal_type` returns `innerTag` beside the payload so a
          # caller can ask "which literal kind" without walking in.
          # `ast.rs:LiteralType` has `pub value` and nothing else.
          "innertag" => "a copy of value.type that the wire does not carry"
        },
        renames: {
          # `ast.rs:UnionType` — `pub type_elements: Vec<NodeRef<Type>>`. The
          # Lua field is `types`.
          "types" => "typeelements"
        },
        note: "Plain tables, so no class name to cross-check — only the `type` " \
              "value. Position is flat; a null list element is `false` (R14)."
      ),

      # -------------------------------------------------------------- julia
      Binding.new(
        name: "julia",
        mode: :reflect,
        probe: -> { run_probe(["julia", "--project=julia", "-e", "using KclLib"]) },
        argv: ->(golden, out) { ["julia", "--project=julia", "hack/dump/julia.jl", golden, out] },
        extra_ok: {
          # `ast.jl:381` — `inner_tag::Union{String,Nothing}` on `LiteralType`,
          # a copy of the tag the wire keeps under `value.type`, held beside the
          # verbatim payload so a caller can ask "which literal kind" without
          # walking in. `ast.rs:LiteralType` has `pub value` and nothing else.
          "innertag" => "a copy of value.type that the wire does not carry"
        },
        renames: {
          # `ast.jl:370` says so in the docstring: "`ast::Type::Union(UnionType)`.
          # The Rust field is `type_elements`." The Julia field is `types`.
          "types" => "typeelements"
        },
        note: "Struct-based decoder; the tag is a `node_type` method, not a field. " \
              "Unknown* keep the wire payload in `raw`, written out as `@raw` (R11)."
      ),

      # --------------------------------------------------------------- dart
      Binding.new(
        name: "dart",
        mode: :reflect,
        probe: lambda {
          return "no `dart` on PATH" unless which("dart")
          return "dart dependencies are not resolved (no dart/.dart_tool/package_config.json)" \
            unless File.file?(File.join(ROOT, "dart", ".dart_tool", "package_config.json"))

          nil
        },
        argv: ->(golden, out) do
          ["dart", "run", "--packages=dart/.dart_tool/package_config.json",
           "hack/dump/dart/dump.dart", golden, out]
        end,
        extra_ok: {
          # `types.dart:121` — `final String? innerTag`, a copy of the tag the
          # wire keeps under `value.type`, held beside the verbatim payload so
          # a caller can ask "which literal kind" without walking in.
          # `ast.rs:LiteralType` has `pub value` and nothing else.
          "innertag" => "a copy of value.type that the wire does not carry"
        },
        renames: {
          # `ast.rs:UnionType` — `pub type_elements: Vec<NodeRef<Type>>`. The
          # Dart field is `types` (`types.dart:97`).
          "types" => "typeelements"
        },
        note: "Sealed-class decoder; the tag is a `tag` getter on each variant. " \
              "The field walk uses `dart:mirrors`, so it reads the decoder's own " \
              "field list rather than a second copy of it. Unknown* keep the wire " \
              "payload and are written out as `@raw` (R11)."
      ),

      # ----------------------------------------------------------------- go
      Binding.new(
        name: "go",
        mode: :wire,
        probe: -> { run_probe(["go", "version"]) },
        argv: ->(golden, out) { ["bash", "hack/dump/go.sh", golden, out] },
        extra_ok: {},
        note: "Generated from ast.rs by `tools/astgen/emit_go.py`, so the field " \
              "lists cannot drift. Go has a real serializer -- the struct tags " \
              "and the four `MarshalJSON` for the inline and compact documents -- " \
              "so this is a wire round-trip. The `Node[T]` wrapper is generic but " \
              "its fifteen slot types are named, because a generic method cannot " \
              "dispatch on `T`."
      ),

      # ----------------------------------------------------------------- c
      Binding.new(
        name: "c",
        mode: :reflect,
        probe: lambda {
          # `hack/dump/c.sh` honours `CC` and falls back to `cc`, so the
          # probe asks for the same three names in the same order — probing
          # `cc` alone would report "toolchain missing" on a runner that
          # only ships clang.
          cc = which("cc") || which("clang") || which("gcc")
          return "no `cc`, `clang` or `gcc` on PATH" unless cc

          run_probe([cc, "--version"])
        },
        argv: ->(golden, out) { ["bash", "hack/dump/c.sh", golden, out] },
        extra_ok: {},
        note: "Hand-written tagged unions in `c/include/kcl_lib_ast.h` with its " \
              "own embedded JSON parser, walked by hand: C has no runtime " \
              "reflection, so `hack/dump/c/Dump.c` is a second statement of what " \
              "the header declares and the diff is what catches the two " \
              "drifting. `@cls` is the union field name. The `Pos` wrapper nests " \
              "its position under `pos`; the seven enums the header never names " \
              "are given their Rust variant names by tables in the dumper."
      ),

      # -------------------------------------------------------------- swift
      Binding.new(
        name: "swift",
        mode: :reflect,
        probe: -> { run_probe(["swiftc", "--version"]) },
        argv: ->(golden, out) { ["bash", "hack/dump/swift.sh", golden, out] },
        extra_ok: {},
        note: "Enum/struct decoder; position is nested under `NodeRef.position`."
      ),

      # ---------------------------------------------------------------- cpp
      Binding.new(
        name: "cpp",
        mode: :reflect,
        probe: lambda {
          # Same shape as c's probe: `hack/dump/cpp.sh` honours `CXX` and
          # falls back to `c++`, so ask for the same three names in the same
          # order rather than reporting a skip on a runner that only ships
          # `g++`.
          cxx = which("c++") || which("g++") || which("clang++")
          return "no `c++`, `g++` or `clang++` on PATH" unless cxx

          run_probe([cxx, "--version"])
        },
        argv: ->(golden, out) { ["bash", "hack/dump/cpp.sh", golden, out] },
        extra_ok: {},
        note: "Header-only typed AST (`cpp/include/kcl_ast.hpp`, 1987 lines) " \
              "with its own decoder, so the walk dispatches on the " \
              "`virtual const char* tag()` each variant carries. C++ has no " \
              "runtime reflection, so the field list is written out per " \
              "class in `hack/dump/cpp/Dump.cpp` — that file is a second " \
              "statement of what the header declares, and the diff is what " \
              "catches the two drifting. Position is nested under `Node::pos`."
      ),

      # ---------------------------------------------------------------- java
      Binding.new(
        name: "java",
        mode: :reflect,
        probe: lambda {
          # A JDK is needed both to build the dumper and to run it, and
          # `javac` alone is not enough: on a machine with the stub `javac`
          # but no runtime, `javac -version` succeeds and the dumper then
          # fails to start. Check the runtime, not the compiler.
          javac = which("javac")
          java = which("java")
          return "no `javac` on PATH" unless javac
          return "no `java` on PATH" unless java

          out, _err, status = Open3.capture3(java, "-version")
          return "probe failed: `java -version` exited #{status.exitstatus}\n#{out}" \
            unless status.success?

          nil
        },
        argv: ->(golden, out) { ["bash", "hack/dump/java.sh", golden, out] },
        extra_ok: {},
        note: "Jackson decoder over `com.kcl.ast.*`, walked by reflection; " \
              "position is flat on `Node`. The tag is read out of the " \
              "`@JsonSubTypes` table on the base class, so both the " \
              "`As.PROPERTY` and `As.EXTERNAL_PROPERTY` spellings are covered."
      ),

      # -------------------------------------------------------------- kotlin
      Binding.new(
        name: "kotlin",
        mode: :wire,
        probe: lambda {
          java = which("java")
          return "no `java` on PATH" unless java

          out, _err, status = Open3.capture3(java, "-version")
          return "probe failed: `java -version` exited #{status.exitstatus}\n#{out}" \
            unless status.success?

          # Deliberately *not* checking for the kotlin compiler jar. The probe
          # answers "is the toolchain fundamentally absent?", and a missing
          # `java` is; the compiler is a plugin dependency that
          # `hack/dump/kotlin.sh` fetches itself when the local maven
          # repository is cold. Probing for it here would report "no dumper
          # written" for a binding that would have run fine — which on a fresh
          # CI runner is exactly what would have happened.
          nil
        },
        argv: ->(golden, out) { ["bash", "hack/dump/kotlin.sh", golden, out] },
        extra_ok: {},
        note: "Has a real serializer — `AstWire.kt`, the mirror of " \
              "`dotnet/KclLib.AST/Wire.cs` — so this is a wire round-trip. The " \
              "decoder is the same `com.kcl.ast` classes java uses, compiled " \
              "from the kotlin source root; the writer and the `New*` builders " \
              "in `AstBuild.kt` are kotlin's own and are what this checks."
      ),

      # ---------------------------------------------------------------- zig
      Binding.new(
        name: "zig",
        mode: :wire,
        probe: -> { run_probe(["zig", "version"]) },
        argv: ->(golden, out) { ["bash", "hack/dump/zig.sh", golden, out] },
        extra_ok: {},
        note: "Has a real `Module.dump` serializer, so this is a wire round-trip."
      ),

      # ------------------------------------------------------------- dotnet
      Binding.new(
        name: "dotnet",
        mode: :wire,
        probe: lambda {
          dotnet = which("dotnet") || File.join(Dir.home, ".dotnet", "dotnet")
          return "no `dotnet` on PATH and none at #{File.join(Dir.home, '.dotnet', 'dotnet')}" \
            unless File.executable?(dotnet)

          nil
        },
        argv: ->(golden, out) do
          dotnet = which("dotnet") || File.join(Dir.home, ".dotnet", "dotnet")
          # No `--nologo`: after `-v quiet` the `dotnet run` parser treats it as
          # consuming the next argument, which eats `--` and shifts both paths
          # by one, so the dumper sees no arguments and exits 2.
          [dotnet, "run", "--project", "hack/dump/dotnet/Dump.csproj",
           "-v", "quiet", "--", golden, out]
        end,
        extra_ok: {},
        note: "Has a real `AstWriter.ToWire` serializer, so this is a wire round-trip."
      )
    ].freeze
  end

  # Bindings that have an AST decoder in this repository but that this run
  # cannot execute. Listed so the report is explicit about the gap rather
  # than quietly short. `reason` must name the blocker.
  def self.unrunnable
    {}.freeze
  end
end

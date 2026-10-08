# frozen_string_literal: true

# Constructors for the PHP binding.
#
# `php/src/Ast/AstBuild.php` is generated — every file in `php/src/Ast`
# carries the generator header, AstBuild included — and it is Kotlin's
# `AstBuild.kt` in PHP spelling: one `public static function <name>(...):
# <Struct> {` per node class, every parameter carrying the value the Rust
# parser itself produces for that field as its default. The return type is
# the class name, which is the Rust struct name, so the join the checker is
# built on needs no alias table: `identifier(...): Identifier` is judged as
# `Identifier`, `typeAliasStmt(...): TypeAliasStmt` as `TypeAliasStmt`.
#
# **Every parameter is defaulted, and that is derived, not assumed.** A
# parameter a caller may omit is written with `= <default>` — `= []` for a
# `Vec`, `= null` for an `Option`, `= ''` for a `String` — and the collector
# reads `defaulted` straight off that token, the same token PHP's engine
# reads. Rule 1 — a `Vec` field must never be a *required* parameter —
# therefore cannot fire for this binding, and that is PHP's answer rather
# than a generous reading: `configExpr()` builds a complete `ConfigExpr`
# with `items = []`, and no caller is asked to type `[]` at any level of
# the tree, which is the ceremony this checker exists to catch.
#
# **Parameters are camelCase; the fields are snake_case.** PHP promotes
# constructor parameters to properties and PSR-12 names them camelCase, so
# `type_value` arrives as `$typeValue` and `if_cond` as `$ifCond`. The
# checker's `resolve_field` already falls back to a snake_case of the
# parameter, the same join Kotlin's camelCase parameters rely on, so no
# `PARAM_ALIASES` entry is needed here. The one asymmetry that table exists
# for — `ImportStmt.rawpath`/`asname` dropping the separator their
# neighbours keep — needs no entry either: the camelCase spellings
# (`rawpath`, `asname`) squash to themselves.
#
# Nothing is filtered by name. The helpers that return something other than
# a node struct — `nodeRef`/`emptyNodeRef`/`nameRef` (a `NodeRef`, which is
# a `Node<T>` alias `ast.rs` declares no struct for), `memberOrIndex` and
# `numberLitValue` (the two `tag + content` enums, which have no struct
# behind them) and `literalType` (the `Type::Literal` arm, itself tagged) —
# are returned anyway, because a collector that drops what it cannot
# classify is a collector that reports success after it has stopped
# matching. `compare` puts them in `unmapped`, which is what they are, and
# the count is the one this file is expected to keep honest.
#
# One `ast.rs` struct this binding deliberately does not model, recorded in
# `NOT_MODELED` rather than closed here — the report prints it as
# deliberately not modeled:
#
#   * `SerializeProgram` (ast.rs:386, `root` / `pkgs`) — `Ast::parseProgram`
#     unwraps the `{"root": …, "pkgs": …}` envelope and hands back the
#     modules of `pkgs.__main__` (`Ast.php`), so the document a caller
#     receives has no type to build and `root` is dropped on the floor —
#     the same decision Go, Lua, Node.js, Python, .NET and Dart made.
#
# `IntLiteralType` is *not* here, unlike in most bindings: the emitter
# gives it its own class (its two fields, `value` and `suffix`, are a
# fixed set the wire really carries) and `AstBuild::intLiteralType` builds
# it, so a caller asking "can I build the `LiteralType::Int` payload?"
# is answered yes directly.

def check_php(path)
  files = File.directory?(path) ? Dir[File.join(path, "AstBuild.php")] : [path]

  ctors = []
  files.each do |file|
    src = File.read(file)

    # `public static function <name>(<params>): <Return> {` — the params may
    # span lines (`schemaStmt` carries fourteen of them), so the body is
    # matched across newlines and split with the shared paren-aware splitter
    # rather than a line scan. The docblock above each factory names Rust
    # structs and wire shapes, so a `$` -less parameter list is what gets
    # scanned: comments are stripped first, or a docblock mentioning
    # ``SchemaStmt`` would read as a parameter of that name.
    code = src.gsub(%r{/\*\*.*?\*/}m, "").gsub(%r{//[^\n]*}, "")
    code.scan(/public static function (\w+)\((.*?)\)\s*:\s*(\w+)\s*\{/m) do
      name = Regexp.last_match[1]
      params_text = Regexp.last_match[2]
      ret = Regexp.last_match[3]

      params = []
      defaulted = []
      split_params(params_text).each do |p|
        param = p[/\$(\w+)/, 1]
        next if param.nil?

        params << param
        defaulted << param if p.include?("=")
      end

      ctors << [ret, params, defaulted]
    end
  end

  ctors
end

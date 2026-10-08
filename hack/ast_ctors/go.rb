# frozen_string_literal: true

# Constructors for the Go binding.
#
# `go/ast` is generated — `base_gen.go dto_gen.go expr_gen.go module_gen.go
# nodes_gen.go stmt_gen.go types_gen.go`, every one of them headed "DO NOT EDIT
# BY HAND" — and there is no hand-written `AstBuild.kt` counterpart. There does
# not need to be one: in Go the keyed struct literal *is* the constructor, and
# `go/ast/ast_contract_test.go` builds one (`ast.BasicType{Name: "Int"}`, line
# 303) exactly the way a caller outside the package would. So a node's
# parameters are the exported fields of its struct, in declaration order, and
# this collector is a parse of the field declarations rather than a scan for
# call syntax — the same argument `check_python` makes about a dataclass's
# generated `__init__`.
#
# Every field is defaulted, and that is Go's answer rather than a generous
# reading of one. A composite literal is keyed and every key in it is optional:
# an omitted field keeps its zero value, which is the `nil` slice, the empty
# string and the zero `int64` a caller would otherwise have to spell at every
# level of the tree. Rule 1 — a `Vec` field must never be a *required*
# parameter — cannot fire for Go, and that is the right outcome: `Args:
# []*ExprNode{}` is not something a Go caller should ever be made to write.
#
# Three shapes in the generated source decide what counts, and the difference
# matters because two of them are near-synonyms:
#
#   * `type X struct { … }` — the constructor. Exported fields only, because
#     Go's rule is a lower-case field is not addressable from another package
#     and so is not a parameter a caller can pass. An embedded type is a field
#     too and counts under its own name, which is how a keyed literal spells
#     it: `ast.Node[ast.CallExpr]{Payload: …}`, `ast.CallExprNode{Node: …}`.
#   * `type X = Y` — a Go *type alias*, the same type under a second name
#     (`Decorator` = `CallExpr`, `KeyValuePair` = `ConfigEntry`, `SchemaConfig`
#     = `SchemaExpr`, `IdentifierExpr` = `Identifier`, `TargetExpr` =
#     `Target`). A caller writing `ast.SchemaConfig{…}` is writing
#     `ast.SchemaExpr{…}` with the same fields, so the alias is dropped rather
#     than returned under a name `ast.rs` does not declare: it would be counted
#     as an unmapped helper and duplicate coverage that is already recorded.
#     `STRUCT_ALIASES` is for a binding that *renames* a struct — an alias
#     renames nothing, and the type system cannot tell the two apart.
#   * everything else — `type X string` (the nine operator/context aliases in
#     `op_gen.go`, which are `ast.rs` enums), the `Expr`/`Stmt`/`Type`
#     interfaces (the three tagged unions), and the `fromWire` /
#     `MarshalJSON` / `UnmarshalJSON` methods, which read a document rather than
#     build one. None is a constructor, and none is a struct this scan can
#     mistake for one: a method is `func (c *X) …`, never `type X struct`.
#
# Nothing here is filtered by name. The fifteen `*Node` slot types, `Pos`,
# `Node[T]` and the six enum shims (`AnyType`, `BasicType`, `LiteralType`,
# `NamedType`, `MemberOrIndex`, `NumberLitValue`) are all returned, because a
# collector that drops what it cannot classify is a collector that reports
# success after it has stopped matching. `compare` decides what each one is:
# `Pos` and `Node` are in `NOT_NODES` and exempt, and the rest name no struct in
# `ast.rs`, so they arrive in `unmapped` — which is what they are, and is the
# count this file is expected to keep honest.
#
# Two things this collector does not see, both stated here rather than left for
# a reader to assume. There is no `func NewX(…)` constructor anywhere in
# `go/ast` — nothing in the package takes a node's fields as arguments, so
# there is no function-shaped constructor to return; if one is added, it needs
# a branch here, and Go's positional parameters are a second question this
# checker does not yet model. And `SerializeProgram`, which `ast.rs` declares
# (line 386) and `NODE_TYPES` counts, has no Go type at all: `ParseProgram`
# returns `[]*Module` after flattening `pkgs.__main__`, so the document a Go
# caller receives has no struct to build and `root` is dropped on the floor.
# `check_ast_constructors.rb` records it in `NOT_MODELED` for go, and the
# report names it as deliberately not modeled rather than as missing.

def check_go(path)
  files = File.directory?(path) ? Dir[File.join(path, "*.go")].sort : [path]

  ctors = []
  seen = {}

  files.each do |file|
    # `_test.go` is the test's scaffolding, not the binding's API, and its
    # helpers are anonymous structs a keyed literal cannot name anyway.
    next if File.basename(file).end_with?("_test.go")

    File.read(file).scan(/^type (\w+)(?:\[[^\]\n]*\])? struct \{\n(.*?)^\}/m) do
      name = Regexp.last_match[1]
      body = Regexp.last_match[2]
      # Two declarations of one name do not compile, so a repeat can only be
      # the same type reached twice — `compare` unions a struct's constructors
      # anyway, and recording it twice would inflate the count it reports.
      next if seen.key?(name)
      seen[name] = true

      params = []
      body.each_line do |raw|
        # The struct tag goes first: it is the one backticked string on the
        # line and the only place a `//` could be data rather than a comment.
        # Then the trailing comment, which is all `MissingExpr` and `AnyType`
        # carry — a unit variant has no payload and one key on the wire, which
        # for them is the tag alone. `$` and not `\z` in the second pattern:
        # the body is the whole block, so `\z` sits past the closing brace and
        # `.` stops at the newline before ever reaching it.
        line = raw.sub(/`[^`]*`/, "").sub(%r{//.*$}, "")
        text = line.strip
        next if text.empty?

        # One pattern for all three spellings a Go struct body has: `Name Type`
        # (a declared field), `Node[Arguments]` (an embedded generic — the `[`
        # alternative) and `Pos` (a bare embedded type — the `\z`).
        field = text[/\A(\w+)(?:\s+|\[|\z)/, 1]

        # Two ways this scan can lose a field, both raised rather than skipped:
        # a line that is none of the three spellings above, and a declaration
        # that wraps onto the next line. The second is the one that matters —
        # its first line balances no bracket, and read as a bare embedded type
        # the name before the wrap becomes a parameter of the wrong kind while
        # every line after it is lost outright.
        depth = 0
        text.each_char do |ch|
          depth += 1 if "<([{".include?(ch)
          depth -= 1 if ">])}".include?(ch)
        end
        raise "#{file}: cannot read this line of `type #{name} struct` as a field: #{raw.strip}" if
          field.nil? || !depth.zero?

        # Go's own rule, applied here rather than imported: an unexported
        # field is invisible to a caller in another package, so it is not a
        # parameter they can pass. None of the generated structs has one, and
        # the check keeps it that way instead of assuming it.
        params << field if field.match?(/\A[A-Z]/)
      end

      # Every key is optional and its absence is the zero value, so `defaulted`
      # is `params` — see the note above. The two lists are separate objects
      # because `compare` subtracts one from the other.
      ctors << [name, params, params.dup]
    end
  end

  ctors
end
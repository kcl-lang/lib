# frozen_string_literal: true

# Constructors for the Python binding.
#
# The Python AST is generated — `python/kcl_lib/ast/_base.py _dto.py _expr.py
# _module.py _op.py _stmt.py _types.py`, every one of them headed "DO NOT EDIT
# BY HAND". There is no hand-written `AstBuild.kt` counterpart, and there does
# not need to be one: a `@dataclass`'s generated `__init__` *is* its
# constructor. Every field of the class is a parameter a caller can pass by
# keyword, in declaration order, so the class is the whole answer and this
# collector is a parse of the field declarations rather than a scan for call
# syntax.
#
# That is why there is nothing here a reviewer has to take on trust: a field
# this collector cannot see is a field `dataclasses.fields` could not have
# seen either, so the only thing that can go wrong is the parse itself — and
# the field block is bounded on both sides (the class docstring before it, the
# first method after it), which is exactly the region `dataclasses` reads.
#
# Two shapes in the generated source decide what counts as a parameter:
#
#   * `= None` / `= ""` / `= 0` and `field(default_factory=...)` are the same
#     thing to a caller — an argument left out — so both land in `defaulted`.
#     An annotation with no `=` at all is required, which is the case rule 1
#     exists to catch, so the two have to be distinguishable and they are.
#   * a field is an annotated assignment at class-body indentation. Scanning
#     past the methods would read `from_dict`'s body, and reading the
#     docstrings would read prose that quotes `ast.rs`, so neither is read.
#
# The base classes are not special-cased: `Expr`, `Stmt` and `Type` are
# fieldless (`pass`) and are returned in their own right, so a base that ever
# grew a field shows up as a field of its own rather than silently
# disappearing into every subclass that inherits it.
#
# One `ast.rs` struct has no Python class: `SerializeProgram` (ast.rs:386).
# `parse_program` (`_base.py:242`) unwraps the `{"root": …, "pkgs": …}`
# envelope and returns `List[Module]` — the modules of `pkgs.__main__` — so
# the document a Python caller receives has no class to build and `root` is
# dropped on the floor. `check_ast_constructors.rb` records it in `NOT_MODELED`
# for python, and the report names it as deliberately not modeled rather than
# as missing.

def check_python(dir)
  # The same seven generated modules `check_ast_field_types.rb` reads, in the
  # same order, so a class defined in one and imported by another is
  # attributed once — `Expr` is defined in `_expr.py` and imported into
  # `_dto.py`.
  files = %w[_base.py _dto.py _expr.py _module.py _op.py _stmt.py _types.py]

  ctors = []
  seen = {}

  files.each do |name|
    path = File.join(dir, name)
    next unless File.exist?(path)

    # `@dataclass` immediately above `class X(...)`. The decorator is the
    # test: a bare `class` gets no `__init__` of its own, and `_op.py`'s
    # seven `str, Enum` classes are `ast.rs`'s `pub enum BinOp` and friends,
    # which have no struct for a constructor to build. The whole header line
    # is consumed so the body starts after the `:` and not inside it.
    File.read(path).scan(/^@dataclass(?:\([^)]*\))?[ \t]*\nclass[ \t]+(\w+)[^\n]*\n/) do
      klass = Regexp.last_match[1]
      next if seen.key?(klass)

      # The class body runs to the next top-level statement — a `class`, a
      # `def`, an `__all__`. One line per iteration and `[^\n]*` rather than
      # `.*`: Ruby's `/m` is dot-all, so a `.*` here would swallow the rest
      # of the file and the body would start at the first method in it.
      body = Regexp.last_match.post_match[/\A(?:[ \t][^\n]*\n|\n)*?(?=^\S|\z)/].to_s
      # The class docstring quotes `ast.rs` — `pub filename: String,`. Those
      # lines sit at eight spaces and cannot reach a four-space field pattern,
      # but an `Args:`-shaped one could, so the docstrings go first.
      body = body.gsub(/"""[\s\S]*?"""/, "").gsub(/'''[\s\S]*?'''/, "")

      params = []
      defaulted = []
      # `[field name, annotation so far]`, nil between fields. An annotation
      # that wraps onto the next line is the one thing that makes a field span
      # lines, and unbalanced brackets are how the generator spells it — they
      # are also how the loop below knows a field is not finished.
      pending = nil

      body.each_line do |line|
        # The first method ends the field block.
        break if line.match?(/\A    (?:@[a-z]|(?:async[ \t]+)?def\b)/)

        if pending
          pending[1] << " " << line.strip
        elsif (m = line.match(/\A    (\w+)[ \t]*:[ \t]*(.+?)[ \t]*\r?\n?\z/))
          pending = [m[1], +m[2]]
        else
          next
        end

        # One pass over the annotation answers both questions the checker
        # asks: a `=` at bracket depth 0 is the default (a `=` nested in
        # `Annotated[...]` is part of the type), and depth back at 0 means the
        # field is complete.
        depth = 0
        defaulted_here = false
        pending[1].each_char do |ch|
          case ch
          when "(", "[", "{" then depth += 1
          when ")", "]", "}" then depth -= 1
          when "="
            if depth.zero?
              defaulted_here = true
              break
            end
          end
        end
        next unless depth.zero?

        params << pending[0]
        defaulted << pending[0] if defaulted_here
        pending = nil
      end

      # A field whose annotation never closed is a parse that lost its default,
      # not one that has none. Recording it as required is the loud reading:
      # it can make rule 1 fire on a field that was in fact defaulted, and it
      # cannot hide one that was not.
      params << pending[0] if pending

      seen[klass] = true
      ctors << [klass, params, defaulted]
    end
  end

  ctors
end
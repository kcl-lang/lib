# frozen_string_literal: true

# Constructors for the Dart binding.
#
# `dart/lib/src/kcl_ast.dart` is 47 lines and every one of them after the header
# is an `export`: `ast/base.dart ast/dto.dart ast/expr.dart ast/module.dart
# ast/stmt.dart ast/types.dart`. So the AST lives under `dart/lib/src/ast/`, and
# this collector reads the barrel rather than a glob — the six files in the
# order the barrel lists them, which is also the order a class is defined before
# it is used in another. Nothing generates those six files; they are hand-written
# decoders, and there is no `AstBuild.kt` counterpart to look for.
#
# The question is what a Dart caller has for *building* a node, and the answer
# is a constructor declaration on the class itself, for a structural reason that
# has to be stated before the parse means anything: **Dart does not give a class
# with `final` fields and no declared constructor a default constructor.**
# `class SchemaStmt { final List<Node<KclStmt>> body; }` cannot be written
# `SchemaStmt(body: …)` — there is nothing to call. A caller can only build a
# node through a constructor the class actually declares, which is the opposite
# of Python's dataclass and Go's keyed literal, where the language manufactures
# the constructor from the field list. There is no generated-constructor argument
# to lean on here, so the parse reads what the source declares and says so.
#
# All sixty-eight AST classes declare one, and they are the same shape: a
# `const` generative constructor taking `this.<field>` formals, plus, for the ten
# classes that also appear as a wire payload, a `factory X.fromWire(Map<String,
# Object?> w)`. Sixty-eight plus ten is the seventy-eight constructors this
# collector returns, and it is the count the report should be read against: a
# collector that stopped matching would show it falling. The generative
# constructor *is* the field list — Dart's `this.x` formals are how a field is
# filled from a parameter of the same name, so the parameters are the `final`
# fields in declaration order, which is what `check_python` reads out of a
# dataclass and `check_go` out of a struct body. Both are returned, and the
# difference between them is worth writing down:
#
#   * `const X({this.a = const [], this.b})` — the node's constructor. Its
#     parameters are fields, and it is the only route to them.
#   * `factory X.fromWire(Map<String, Object?> w)` — a decoder. It reads a JSON
#     object rather than naming fields, which is the same shape `check_go`
#     declines to count in `go/ast` ("the `fromWire` / `MarshalJSON` /
#     `UnmarshalJSON` methods, which read a document rather than build one").
#     Go can decline on the strength of a shape a caller would recognise: a method
#     is `func (c *X) …`, never `type X struct`. Dart cannot, because a `factory`
#     *is* a constructor declaration, so `X.fromWire` and `X(...)` are one kind
#     of thing to the language. Each of the ten forwards to the
#     real constructor with every field it holds (`Identifier.fromWire` calls
#     `Identifier(names: …, pkgpath: …, ctx: …)`). Under the README's rule that a
#     forwarding convenience is still returned, all ten are returned with their
#     one parameter, `w`. They are inert to `compare` and provably so: `compare`
#     judges a parameter against a struct only when it matches a field, and `w`
#     matches nothing in `ast.rs`, so the triple contributes to neither
#     `settable` nor `uncovered`. What it does is put them in the constructor
#     count, which is where a collector that had stopped matching would show.
#
# ## What is a parameter, and what is a defaulted one
#
# Dart's parameter list is `(required positional) [optional positional]
# {named}`, and each of the three kinds answers the question differently. A
# parse has to read all three, because in this package `defaulted` is the
# difference between rule 1 firing and not:
#
#   * `required this.x` and a bare `this.x` before any `[` or `{` are **not**
#     defaulted. `Pos`, `Node`, `Comment`, `Member`, `Index`, `BasicType`,
#     `NamedType`, `ListType`, `DictType`, `UnionType`, `FunctionType`,
#     `LiteralType`, `KeywordExpr`, `ArgumentsExpr`, `TargetExpr`,
#     `IdentifierExpr`, `UnknownExpr`, `UnknownStmt`, `UnknownType` are written
#     this way and a caller must hand them every value.
#   * `[this.x]` is optional positional and therefore omittable by construction
#     — the same rule `parse_param` states for a Kotlin `vararg` or a Python
#     `*args`. Three parameters are: `Node.pos`, `LiteralType.innerTag` and
#     `UnknownType.value`.
#   * `{this.x = …}` and `{this.x}` are both optional named and therefore
#     omittable. The second is the subtle half: Dart has no `= null` spelling
#     for a non-nullable type, so a named parameter inside `{}` with no default
#     compiles *only* when its type is nullable, and the compiler gives it
#     `null`. So in a class where every `{}` parameter is either defaulted
#     (`this.args = const []`, `this.ctx = ''`, `this.isOptional = false`,
#     `this.rawValue = '""'`) or nullable (`Node<KclExpr>? operand`), every one
#     of them is in `defaulted`. That is not a generous reading — it is why the
#     source compiles at all — and it means rule 1, a `Vec` field must never be a
#     required parameter, cannot fire for the forty-nine constructors written in
#     the named style. `Args: []` is not something a Dart caller is ever made to
#     write, which is the outcome `check_go` and `check_java` reach the same way.
#     Six more take no parameters at all — `KclExpr`, `KclStmt`, `AstType`,
#     `MemberOrIndex`, `AnyType` and `MissingExpr`, the last of which is the only
#     route to a struct with no fields.
#
# The other kinds Dart writes are read the same way and all present here: a
# `required` named formal, a plain positional `Map<String, Object?> w`
# (`fromWire`'s only shape), and a field with an initializer. The last is not a
# parameter and no class in this package has one; the field block below checks
# for it rather than assuming, so a class that grew one would not be reported as
# having a field no caller can set.
#
# ## Three guards, because a collector that stops matching reports success
#
#   * A class with `final` fields and no constructor declaration raises. That is
#     the failure Dart's own rule makes possible and the parse would otherwise
#     read as "a node with no parameters", which `compare` would call covered.
#   * A `final` field that no constructor of its class takes raises, so a class
#     whose constructor list lost a parameter cannot quietly report a struct with
#     a field no caller can set. The union across a class's constructors, not
#     each one: `Pos` declares a generative constructor taking all five of its
#     fields *and* a `fromWire` taking a wire map, and the second is not a reason
#     the first is wrong.
#   * A class declared in two of the six files raises, so a file exported twice
#     is caught rather than double-counted.
#
# Each has been checked by breaking it on purpose rather than assumed: a
# constructorless class, a class whose constructor lost a field, a duplicate
# declaration and an unbalanced brace all raise with a message naming the file.
#
# ## Tagged enums, and the one that cannot be reached
#
# `ast.rs` declares three tagged unions and Dart models each as a `sealed class`
# with one subclass per variant: `KclExpr` for `Expr` (ast.rs:852), `KclStmt` for
# `Stmt` (ast.rs:573) and `AstType` for `Type` (ast.rs:1858). Four Dart classes
# carry an `AstType` variant *and* fill in the struct that variant's payload is:
# `ListType(innerType)` is `ast.rs:1884`'s `ListType { inner_type }`,
# `DictType(keyType, valueType)` is `ast.rs:1889`, `UnionType(types)` is
# `ast.rs:1895` and `FunctionType(paramsTy, retTy)` is `ast.rs:1870`. Because
# Dart collapses the wrapper and the payload into one class with no nesting,
# there is nothing for `WRAPPED_PAYLOADS` to register: the wrapper *is* the
# payload and every field is a parameter of the one constructor, so `compare`
# judges the union and finds the whole struct. `check_java` had to write the
# same argument at greater length for `UnionType`/`UnionTypeValue`, where Jackson
# forces the nesting.
#
# `IntLiteralType` is the exception and it is a genuine gap. `ast.rs:1901`
# declares `LiteralType` as `#[serde(tag = "type", content = "value")]` with
# arms `Bool(bool)`, `Int(IntLiteralType)`, `Float(f64)`, `Str(String)`, and
# `IntLiteralType` (ast.rs:1909) is the only arm whose payload is a struct. Dart's
# `LiteralType(value, [innerTag])` (types.dart:111) keeps the decoded payload as
# an untyped `Object?` — "the raw payload is kept verbatim rather than
# re-modelled, because it has three different shapes depending on the inner tag" —
# so there is no class, no constructor and no parameter a caller can name for
# `value: i64` / `suffix: Option<NumberBinarySuffix>`. Nothing is papered over
# here: the struct is absent from the returned constructors and is recorded in
# `check_ast_constructors.rb`'s `NOT_MODELED` table, so the report names it as
# deliberately not modeled rather than as missing. Nothing could be registered
# for it either — `WRAPPED_PAYLOADS` is keyed by *function* name for a Kotlin
# `fun`, and Dart has no free function that fills one in.
#
# `SerializeProgram` is the other entry `check_ast_constructors.rb` records in
# `NOT_MODELED` for dart, and for the same reason `check_go` records it for Go:
# `parseProgramAst`
# (module.dart:70) returns `List<Module>` after accepting either a bare array or
# the `{"root": …, "pkgs": …}` envelope, so the document a Dart caller receives
# has no struct to build and `root` (ast.rs:387) is dropped on the floor.
#
# ## What is *not* returned, and why
#
# Two `typedef`s — `typedef Decorator = CallExpr;` and `typedef SchemaConfig =
# SchemaExpr;` (expr.dart:176, expr.dart:348). A Dart `typedef` declares a second
# name for a type, not a constructor: `const Decorator(func: …)` is
# `const CallExpr(func: …)`, and the two classes are already returned. Dropping
# them is the same call `check_go` makes about `type X = Y`, and for the same
# reason — the type system cannot tell an alias from a rename, so returning one
# would count coverage that is already recorded under a name `ast.rs` does not
# declare.
#
# Everything else is returned, including the seventeen classes that reach no
# struct: `UnknownExpr`, `UnknownStmt` and `UnknownType` (a tag this package does
# not know, kept so a newer `libkcl` degrades to a readable node); `Member` and
# `Index` (the arms of `ast.rs:950`'s `MemberOrIndex`); `TargetExpr`,
# `IdentifierExpr`, `KeywordExpr` and `ArgumentsExpr` (the tagged forms of four
# untagged payloads, each a one-field wrapper around a struct that is already
# covered under its own name); `AnyType`, `BasicType`, `NamedType` and
# `LiteralType` (four arms of `ast.rs:1858`'s `Type`, carrying the payloads of
# `Any`, the `BasicType` enum, the `Identifier` struct and the nested `LiteralType`
# enum without being any of them); and the four sealed bases themselves. The
# sealed bases are returned where `check_java` skips its `abstract` classes, and
# the difference is deliberate rather than inconsistent: `abstract` forbids
# instantiation anywhere, while Dart's `sealed` forbids it *outside the declaring
# library*, and these four are declared `const` precisely so their subclasses get
# a const superclass. All seventeen name no struct in `ast.rs`, so every one of
# them arrives in `unmapped` — printed, not fatal, and visible to a reviewer —
# and none of them can claim a field or cover a struct. Nothing is filtered by
# name; `compare` decides what each one is.
#
# ## Tables this file may not edit
#
# Three entries in `check_ast_constructors.rb` would resolve names the Dart
# source is entitled to differ on, and each is reported rather than added:
# `UnionType(types)` for `ast.rs:1896`'s `type_elements`, `ImportStmt.asName`
# for `ast.rs:686`'s `asname`, and `NumberLit.valueTag` — which names no field
# at all, because `ast.rs:1478`'s `value: NumberLitValue` is the *enum*
# declared at `ast.rs:1464`, and Dart splits it into the discriminator and the
# payload. The first two are the identical renames `nodejs` and `dotnet` already
# declare; the third is the inner-tag shape `KNOWN_HELPERS` excuses for the
# outer ones. See the run report.

def check_dart(path)
  files = dart_ast_files(path)

  # Comments and strings are blanked in place rather than deleted, so the line a
  # member sits on survives and a constructor's `=>` body can still be walked to
  # its `;`.
  #
  # Blanking rather than deleting is load-bearing here for the same reason it is
  # in `check_java`: `/// Mirrors `ast::Pos` / `ast::Node<T>` —` quotes
  # `ast.rs` field-for-field, so a scan that read comments would read a struct
  # definition out of a doc comment. Preserving the line count keeps every offset
  # in the error messages below meaningful.
  #
  # The interpolation handling is not optional. `dto.dart:185` reads
  # `'ConfigEntry(${key?.node} $operation ${value?.node}${isShorthand ? '
  # ' (shorthand)' : ''})'` — a `'…'` string with a nested `'…'` inside `${…}`
  # inside it — so a scanner that ends a string at the first unescaped quote
  # would leave `)} in ${…})';` behind as code and put two unbalanced brackets
  # into the middle of the file.
  #
  # `${` therefore pushes a level and the `}` that brings it back to zero pops
  # one, and *everything* from the `${` to that `}` is blanked, the closing brace
  # included: a `${…}` is part of the surrounding string, so emitting its `}`
  # would hand the brace counter below one `}` per interpolation it had already
  # consumed and close `BinaryExpr`'s class body two members early. Newlines
  # inside a blanked span survive, so offsets and line numbers still line up with
  # the file on disk.
  strip = lambda do |src|
    out = +""
    i = 0
    n = src.length
    # The interpolation stack: one entry per open `${`, holding the brace depth
    # at which it must close. Empty means ordinary code.
    interp = []
    while i < n
      ch = src[i]
      if interp.empty?
        if src[i, 2] == "//"
          i += 2
          i += 1 while i < n && src[i] != "\n"
          out << " "
        elsif src[i, 2] == "/*"
          stop = src.index("*/", i + 2) || n
          out << src[i...stop].gsub(/[^\n]/, " ")
          i = stop + 2
        elsif src[i, 3] == "'''" || src[i, 3] == '"""'
          quote = src[i, 3]
          j = i + 3
          j += 3 while j < n && src[j, 3] != quote
          j += 3
          out << src[i...j].gsub(/[^\n]/, " ")
          i = j
        elsif ch == "'" || ch == '"'
          quote = ch
          # Built up a character at a time rather than blanked as one span,
          # because the `${` that opens an interpolation is *not* part of the
          # span the closing quote ends: emitting the whole literal in one go
          # would put its `{` back into the output and leave the class bodies
          # downstream one brace short of closing.
          blanked = +""
          j = i
          while j < n
            c = src[j]
            if c == "\\"
              blanked << "  "
              j += 2
            elsif src[j, 2] == "${"
              blanked << " "
              interp << 1
              j += 2
            elsif c == quote
              blanked << " "
              j += 1
              break
            else
              blanked << (c == "\n" ? "\n" : " ")
              j += 1
            end
          end
          out << blanked
          i = j
        else
          out << ch
          i += 1
        end
      else
        # Inside `${…}` this is ordinary Dart, so a nested string is skipped
        # rather than scanned for braces — `${map['}']}` is a string with a
        # brace in it and must not move the counter.
        if ch == "'" || ch == '"'
          quote = ch
          j = i + 1
          j += 1 while j < n && src[j] != quote && src[j] != "\n"
          out << src[i...j].gsub(/[^\n]/, " ")
          i = j
        else
          depth = interp.last
          depth += 1 if ch == "{"
          depth -= 1 if ch == "}"
          depth.zero? ? interp.pop : interp[-1] = depth
          out << (ch == "\n" ? "\n" : " ")
          i += 1
        end
      end
    end
    out
  end

  # The `{` that opens a body is the last character of the match that found it,
  # so this is called with the index of that brace and returns the text between
  # it and the matching `}` plus the index just past it. Braces balance once
  # comments and strings are gone, which is the only reason counting them is
  # enough.
  body_of = lambda do |src, open|
    depth = 0
    i = open
    n = src.length
    while i < n
      depth += 1 if src[i] == "{"
      if src[i] == "}"
        depth -= 1
        return [src[(open + 1)...i], i + 1] if depth.zero?
      end
      i += 1
    end
    raise "unbalanced braces at offset #{open}"
  end

  # The index just past a constructor, so the walk never reads a constructor's
  # own body as a second member. Dart gives a constructor one of three tails and
  # this package uses two of them: a bare `;` after a field-formal parameter list
  # (`const Comment(this.text);`) and `=> expr;` for every `fromWire` factory. The
  # third, a `{ … }` body, is handled too — it costs one call into `body_of` — and
  # so is a trailing initializer list, so a class that grew either would not make
  # the member after it unreadable.
  ctor_end = lambda do |src, close|
    i = close + 1
    n = src.length
    i += 1 while i < n && (src[i] == " " || src[i] == "\t" || src[i] == "\n" || src[i] == "\r")
    if src[i] == "{" then return body_of.call(src, i)[1] end
    if src[i, 2] == "=>"
      i += 2
      depth = 0
      while i < n
        depth += 1 if "([{".include?(src[i])
        depth -= 1 if ")]}".include?(src[i])
        if depth.zero? && src[i] == ";"
          return i + 1
        end
        i += 1
      end
      return n
    end
    i += 1 if src[i] == ";"
    # A trailing initializer list (`const X(this.a) : b = 1;`) ends at the next
    # `;` at depth zero; anything else ends at the end of the line.
    while i < n && src[i] != "\n" && src[i] != ";"
      i += 1
    end
    i += 1 if src[i] == "\n"
    i
  end

  # Split one Dart parameter list into `[name, defaulted?]` pairs.
  #
  # Three depths are tracked and each answers a different question. `<`/`>`
  # depth is what makes `Map<String, Object?> w` one parameter instead of two,
  # since that comma means nothing. The `[`/`{` stack says which optional group a
  # parameter is in, and a parameter in either group is omittable. A `=` at zero
  # depth is the default, and `required` overrides everything the group says.
  parse_params = lambda do |text|
    text = text.strip
    # A Dart parameter list has at most one optional group and it wraps the whole
    # list when present — `const Pos({required this.a, …})` rather than
    # `const Pos({this.a, …}, {this.b})`. Peeling it off first means the group a
    # parameter sits in is either the wrapper or a `[…]`/`{…}` found while
    # splitting, and `const []` in a default value cannot be mistaken for one.
    outer = nil
    if (text.start_with?("{") && text.end_with?("}")) || (text.start_with?("[") && text.end_with?("]"))
      outer = text[0]
      text = text[1..-2].to_s
    end

    segments = []
    current = +""
    groups = outer ? [outer] : []
    # The group a segment *begins* in, not the one it ends in: `Node(this.node,
    # [this.pos])` closes its `[` before the list does, and `this.pos` is still
    # an optional positional parameter.
    seg_group = groups.last
    angle = 0
    paren = 0
    i = 0
    n = text.length
    while i < n
      ch = text[i]
      if ch == "," && angle.zero? && paren.zero?
        segments << [current, seg_group]
        current = +""
        seg_group = groups.last
        i += 1
        next
      end
      # Whitespace before a parameter is dropped rather than kept, so
      # `current.empty?` stays a reliable "this segment has not started" test —
      # it is what decides which group the segment opens in, and `, [` puts a
      # space between the two.
      if current.empty? && " \t\r\n".include?(ch)
        i += 1
        next
      end

      case ch
      when "<" then angle += 1
      when ">" then angle -= 1
      when "(" then paren += 1
      when ")" then paren -= 1
      when "[", "{" then groups << ch
      when "]", "}" then groups.pop
      end
      seg_group = groups.last if current.empty?
      # The group brackets are structure, not text: `[this.pos]` declares a
      # parameter named `pos`, and keeping the brackets would leave the segment
      # ending in `]` for the name pattern below to trip over.
      current << ch unless "[{}]".include?(ch)
      i += 1
    end
    segments << [current, seg_group]

    segments.filter_map do |segment, group|
      body = segment.strip
      next if body.empty?

      # `required` is the only keyword that makes a `{…}` parameter
      # non-optional, and it is the one a named-formal class needs in order to
      # compile at all.
      required = body.sub!(/\Arequired[ \t]+/, "")
      # The default is the first `=` at depth zero, which is what keeps a `?` or
      # a `<` inside a default's own brackets from splitting the parameter.
      depth = 0
      cut = nil
      body.each_char.with_index do |c, idx|
        depth += 1 if "<([{".include?(c)
        depth -= 1 if ">])}".include?(c)
        if c == "=" && depth.zero?
          cut = idx
          break
        end
      end
      decl = (cut ? body[0...cut] : body).strip
      # `this.x`, `super.x` and a plain `int x` all end in the name; the
      # initializer formals are the common case and the last identifier is the
      # field in every spelling Dart has.
      name = decl[/(\w+)[ \t]*\z/, 1]
      raise "cannot read #{body.inspect} as a parameter" if name.nil?

      [name, !required && (group == "[" || group == "{" || !cut.nil?)]
    end
  end

  ctors = []
  declared = {}

  files.each do |file|
    src = strip.call(File.read(file))

    # `class X {`, `class Node<T> {`, `sealed class MemberOrIndex {`, `class
    # Member extends MemberOrIndex {`. The modifiers are matched and kept rather
    # than filtered by name so a class that grew `abstract` would show up as one
    # thing rather than as a difference nobody can see.
    header = /(?:^|\n)[ \t]*(?:(?:abstract|sealed|base|final|interface|mixin)[ \t]+)*class[ \t]+(\w+)[ \t]*(?:<[^{};]*?>)?[ \t]*(?:extends[ \t]+[\w.<>?]+)?[ \t]*\{/

    pos = 0
    while (m = header.match(src, pos))
      name = m[1]
      body = body_of.call(src, m.end(0) - 1).first
      if declared.key?(name)
        raise "#{name} is declared in both #{declared[name]} and #{file}"
      end
      declared[name] = file
      # The scan resumes at the `{` rather than past the body, so a class nested
      # inside another is found by the same loop rather than by a nesting rule of
      # its own. Dart needs no such rule: `check_java` has to work out that a
      # `public static class` payload fills in the struct of the class it is
      # written inside, and here a nested class is just a class whose fields are
      # read at its own member column.
      pos = m.end(0)

      # The member indentation is the shortest indentation in the body, which for
      # a uniformly formatted class is exactly the class's own member column. It
      # is the whole of the filter between a field and a local variable: the six
      # `final n = …` lines in this package are all in top-level functions, and
      # inside a class a constructor body is two columns deeper.
      indent = body.lines.filter_map { |l| l[/\A[ \t]+(?=\S)/] }.min_by(&:length).to_s

      # `final` fields, in declaration order, with any initializer noted. A field
      # with an initializer is not a parameter, and there is none in this
      # package — the check exists so that a future one is not silently read as
      # an unreachable field.
      fields = []
      body.each_line do |line|
        next unless line.start_with?(indent)

        decl = line[/\A#{Regexp.escape(indent)}(?:late[ \t]+)?final[ \t]+(.+?);[ \t]*\r?\n?\z/, 1]
        next if decl.nil?

        field = decl[/(\w+)[ \t]*(?:=|\z)/, 1]
        raise "#{file}: cannot read `final #{decl}` as a field of #{name}" if field.nil?

        fields << [field, !decl.include?("=")]
      end

      # A Dart class with `final` fields and no declared constructor has no
      # default constructor and no way to build one, so the caller has nothing.
      # That is the failure Dart's own rule makes possible, and it is raised here
      # rather than reported as a constructor with no parameters — which
      # `compare` would call complete coverage.
      ctor_re = /([ \t]*)(?:const[ \t]+|factory[ \t]+|external[ \t]+)*#{Regexp.escape(name)}(?:\.(\w+))?[ \t]*\(/
      p2 = 0
      found = []
      while (c = ctor_re.match(body, p2))
        # A constructor sits at the member column. The test is that everything
        # between the start of its line and the name is nothing but whitespace,
        # and that the whitespace adds up to the class's own member indentation —
        # so `  String toString() =>` is not read as a constructor of `String`,
        # and neither would `  Type someMethod(` be one of a class named `Type`.
        bol = c.begin(0) > 0 ? (body.rindex("\n", c.begin(0) - 1) || -1) : -1
        prefix = body[(bol + 1)...c.begin(0)]
        unless prefix.strip.empty? && c[1].length + prefix.length == indent.length
          p2 = c.end(0)
          next
        end

        open = c.end(0) - 1
        depth = 0
        j = open
        while j < body.length
          depth += 1 if body[j] == "("
          if body[j] == ")"
            depth -= 1
            break if depth.zero?
          end
          j += 1
        end
        raise "#{file}: #{name}'s parameter list does not close" if depth != 0

        found << parse_params.call(body[(open + 1)...j])
        p2 = ctor_end.call(body, j)
      end

      if found.empty?
        unless fields.all? { |(_, required)| !required }
          raise "#{file}: #{name} has final fields and declares no constructor, so a Dart " \
                "caller cannot build it - this collector reads constructors, not fields"
        end
        next
      end

      # A field no constructor of the class takes is a field no caller can set,
      # and returning the constructors without it would claim reachability that
      # does not exist. The union rather than each constructor: `Pos` declares a
      # generative constructor that takes all five of its fields *and* a
      # `fromWire` factory that takes a wire map, and the second one is not a
      # reason the first is wrong.
      taken = found.flat_map { |params| params.map(&:first) }
      fields.each do |field, required|
        next unless required
        next if taken.include?(field)

        raise "#{file}: #{name}.#{field} is a final field no constructor takes, so it is not " \
              "a parameter a caller can pass - this collector reads constructors, not fields"
      end

      # `struct` is the class name, which is `ast.rs`'s for every class that
      # names a struct; the ones that do not are what `unmapped` is for.
      found.each { |params| ctors << [name, params.map(&:first), params.select { |(_, d)| d }.map(&:first)] }
    end
  end

  ctors
end

# The six files the AST barrel exports, in the barrel's order, resolved relative
# to the barrel rather than guessed at with a glob: `dart/lib/src/kcl_ast.dart`
# is the only entry point into the AST and it names every file in it. Taking the
# order from the barrel also attributes a class to one file, which a glob over a
# directory that later grows an `ast/types_base.dart` would not guarantee, and
# the two files the barrel does *not* export — `kcl_facade.dart`'s
# `KclOptions`/`KclResult` and `kcl_lib.dart`'s `KclError` — can never be read as
# nodes.
#
# `path` may be any of `dart/`, `dart/lib/`, `dart/lib/src/`,
# `dart/lib/src/kcl_ast.dart`, `dart/lib/src/ast/` or a single `.dart` file. The
# barrel is found by walking up at most three levels and then, failing that,
# searched for under `path` — `dart/lib/` is one level *above* nothing useful and
# two levels below the barrel, so neither walk alone covers it. A directory with
# no barrel and no `.dart` in it raises rather than returning nothing: `compare`
# treats "no constructors" as a clean run, and an empty file list would be the
# quietest way for this collector to stop matching.
def dart_ast_files(path)
  raise "no such path: #{path}" unless File.exist?(path)

  root = File.expand_path(path)
  barrel = nil
  if File.file?(root)
    # Being handed the barrel itself is the clearest signal there is.
    barrel = root if File.basename(root) == "kcl_ast.dart"
    return [root] unless barrel
  else
    dir = root
    3.times do
      candidate = File.join(dir, "kcl_ast.dart")
      if File.exist?(candidate)
        barrel = candidate
        break
      end
      parent = File.dirname(dir)
      break if parent == dir

      dir = parent
    end
    barrel ||= Dir[File.join(root, "**", "kcl_ast.dart")].sort.first
  end

  files =
    if barrel
      exports = File.read(barrel).scan(/^export[ \t]+'([^']+)';/).flatten
      raise "#{barrel} exports no library" if exports.empty?

      exports.map { |rel| File.join(File.dirname(barrel), rel) }
    else
      Dir[File.join(root, "*.dart")].sort
    end

  missing = files.reject { |f| File.exist?(f) }
  raise "#{barrel} exports a file that does not exist: #{missing.join(' ')}" unless missing.empty?
  raise "no Dart source under #{root}" if files.empty?

  files
end
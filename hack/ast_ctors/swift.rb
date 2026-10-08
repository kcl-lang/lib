# frozen_string_literal: true

# Constructors for the Swift binding.
#
# `swift/Sources/KclLibAST/` is hand-written (`Pos.swift` the model,
# `AstJson.swift` the JSON walker) and there is no `AstBuild.kt`
# counterpart. There does not need to be one: a Swift struct's constructor
# *is* its initializer, and Swift spells the two cases of that the way
# `check_python` and `check_go` rely on their language's own spelling:
#
#   * an explicit `public init(a: T, b: T = …)` — the parameters are the
#     initializer's, in order, and an `= …` is exactly a defaulted one.
#     Six structs have one (`Pos`, `NodeRef`, `Comment`, `Module`,
#     `Program`, `Identifier`), and declaring one suppresses the synthesized
#     memberwise init, so the two are mutually exclusive.
#   * otherwise Swift *synthesizes* a memberwise initializer whose
#     parameters are the stored properties in declaration order. `Pos.swift`
#     declares forty-nine of them this way — `public let name: T` with no
#     initializer — which is why this file is a parse of property
#     declarations rather than a scan for call syntax. The same argument
#     `check_python` makes about a dataclass's generated `__init__` and
#     `check_go` makes about a keyed struct literal applies unchanged: a
#     field this collector cannot see is a field a Swift caller cannot pass.
#
# `defaulted` is therefore nearly empty, and that is Swift's answer rather
# than a generous reading of one. A synthesized memberwise init gives a
# parameter a default only when the stored property *has* one, and none of
# these does — not even the `Optional` ones, because `let x: T?` with no
# initial value is still a required argument. Rule 1 (a `Vec` field must
# never be a *required* parameter) therefore fires on most structs, which
# is the finding: a Swift caller spells `body: []` and `mixins: []` by hand
# at every level of the tree, exactly the ceremony the checker exists to
# catch. Only the six explicit inits above can omit anything.
#
# There is a second, sharper answer hiding behind that one, and it is why
# this file returns the memberwise init rather than nothing at all.
# Swift synthesizes it at `internal`, because the default memberwise
# initializer is `internal` unless every stored property is `public` *and*
# an explicit `public init` is written (SE-0242 makes it synthesizable
# with defaults; it does not make it public). `Pos.swift` writes
# `public let name: T` and never `public init`, so all forty-nine of
# them are reachable from inside `KclLibAST` — which is where
# `AstJson.swift` and `@testable import KclLibAST` in
# `Tests/KclLibASTTests` live — and from nowhere else. A client that
# adds `KclLibAST` as a dependency and writes
# `BinaryExpr(left: …, op: .add, right: …)` gets `initializer is
# inaccessible due to 'internal' protection level`. Six of fifty-five
# structs are buildable across the module boundary. `compare` cannot see
# access levels, so this is reported here rather than papered over; the
# fix is a `public init` per struct, which is a Swift-side change.
#
# Comments come off before anything else is read. `Pos.swift` documents
# each field with a `///` note and `AstJson.swift` quotes `ast.rs`
# verbatim — `pub kwargs: Vec<NodeRef<Keyword>>,` in a doc comment is
# prose, not a field — and a block comment, a string literal or an
# interpolated one all hide `init(`-shaped text. The stripper is a
# character scanner rather than a regex for the same reason `check_python`
# strips docstrings first.
#
# The count this file has to account for is 55 structs and 17 enums, which
# is what `swiftc -emit-module-interface-path` emits for the target and
# what this collector returns 72 constructors over: one per struct, one
# per enum. Every struct has exactly one constructor here, and the enum
# cases are not counted individually because `compare` judges an enum as
# one constructor and the cases are not separable.
#
# Nothing is filtered by name here. The six payload enums (`Stmt`, `Expr`,
# `KclTypeNode`, `MemberOrIndex`, `NumberLitValue`, `LiteralTypeValue`),
# the eleven operator/context enums and `AstJsonError` are all returned:
# a Swift caller does build a node by writing `Expr.binary(…)`, and every
# one of them names no struct in `ast.rs`, so they arrive in `compare`'s
# `unmapped` list — which is what they are, and is the count this file is
# expected to keep honest. A collector that drops what it cannot classify
# is a collector that reports success after it has stopped matching.
#
# Three things this collector does not see, stated here rather than left for
# a reader to assume:
#
#   * `AstJson.swift`'s `private func` decoders (`identifierFrom`,
#     `target`, `keyword`, …) read a `[String: Any]` and build a node. They
#     are the decoder, not an API a caller can reach, and they are free
#     functions rather than members so the type scan cannot see them.
#   * There is no `public static func make…(…) -> SomeNode` anywhere in the
#     target: a factory would have to be added as a third case here.
#   * `LiteralType`'s `Int` payload is built inside `literalTypeValue`,
#     whose return type is the `LiteralTypeValue` enum rather than the
#     struct it fills in — the tagged-enum-wrapper blind spot. It is not a
#     gap *here* only because `IntLiteralType` is also a `public struct`
#     with a memberwise init of its own, so a caller can build it directly;
#     `check_kotlin`'s `WRAPPED_PAYLOADS` entry exists for the bindings
#     where that is not true.

# The two Swift type names that name something `ast.rs` spells differently.
# A rename is a claim a reviewer can check, so each one is here with the
# declaration it is checked against rather than guessed in a regex.
SWIFT_AST_RS_NAMES = {
  # `Pos.swift:62` — "`ast::Node<T>` — `{id, node, filename, line, …}`".
  # Swift's name is a disambiguation, not a different shape, and `Node` is
  # in `NOT_NODES` so it is exempt from the rules and from the coverage
  # list alike.
  "NodeRef" => "Node",
  # `ast.rs:386` `pub struct SerializeProgram { pub root: String, pub
  # pkgs: HashMap<String, Vec<Module>> }` — the two fields `Pos.swift:114`
  # declares as `root` and `pkgs`. ast.rs's own `Program` (line 435) is the
  # resolution index, derives only `Debug, Clone, Default` and is never
  # serialized; it is in `NOT_ON_THE_WIRE`.
  "Program" => "SerializeProgram"
}.freeze

# The initializer's parameter list, split into `[name, defaulted?]` pairs.
#
# A Swift parameter's external label defaults to its internal name and is
# not part of its identity — `Module(filename: …)` passes `filename` — so
# what is returned is the name and the defaulted flag, and the type is
# dropped. `?` on a type is an optional, not a default: `NodeRef<Expr>?` is
# a value the caller still has to supply, and recording it as omittable is
# exactly the misreading rule 1 exists to catch.
def swift_params(text)
  params = []
  depth = 0
  current = +""

  text.each_char do |ch|
    case ch
    when "(", "[", "{"
      depth += 1
    when ")", "]", "}"
      depth -= 1
    when ","
      if depth.zero?
        params << current.strip
        current = +""
        next
      end
    end
    current << ch
  end
  params << current.strip

  params.reject(&:empty?).filter_map do |param|
    # A Swift parameter is spelled `name: Type`, `name: Type = default`,
    # `_ name: Type` or `_ name: Type = default` — the internal name and
    # the external label are one identifier unless `_` says otherwise, so
    # the name is the identifier *before* the colon. Reading the word after
    # the colon instead would take the type: `Identifier(names:…)` would
    # come back as a parameter called `[NodeRef<String>]`.
    name = if param.match?(/\A\s*_\s*(?:`?\w+`?)/)
             param[/\A\s*_\s*(`?\w+`?)\s*:/, 1]
           else
             param[/\A\s*(`?\w+`?)\s*:/, 1]
           end
    next nil if name.nil?

    # The `=` that makes a default sits at bracket depth 0 of what follows
    # the colon: `= []`, `= nil`, `= .load`. Past the colon, because a
    # parameter has no `= attribute` form, and at depth 0, because a
    # function type default — `= ((Int) -> Void)?` — is a value and not a
    # default for this parameter. The `>` of a `->` is not a closer.
    tail = param.split(":", 2).last.to_s
    depth = 0
    defaulted = false
    tail.each_char.with_index do |c, i|
      case c
      when "(", "[", "<", "{" then depth += 1
      when ")", "]", "}" then depth -= 1
      when ">" then depth -= 1 unless tail[i - 1] == "-"
      when "="
        if depth.zero?
          defaulted = true
          break
        end
      end
    end

    [name.delete("`"), defaulted]
  end
end

# `Pos.swift` minus comments and string literals, newline for newline, so
# that what is left is only code.
#
# A line comment can hide everything: `Pos.swift:62` is the line that names
# `ast::Node<T>`, and reading doc comments as declarations is how a
# collector ends up counting prose. The scanner is character-at-a-time
# rather than three regexes because each of the three kinds can hide the
# other two — a `//` inside a URL string, a `"` inside a doc comment, a
# `/*` inside a raw string — and getting one of them wrong is silent.
def swift_code(src)
  out = +""
  i = 0
  n = src.length
  block = 0 # `/* */` nests in Swift

  while i < n
    c = src[i]

    if block.positive?
      if c == "/" && src[i + 1] == "*"
        block += 1
        out << " "
        i += 2
      elsif c == "*" && src[i + 1] == "/"
        block -= 1
        out << " "
        i += 2
      else
        out << (c == "\n" ? "\n" : " ")
        i += 1
      end
      next
    end

    if c == "/" && src[i + 1] == "/"
      i += 2
      i += 1 while i < n && src[i] != "\n"
      next
    end

    if c == "/" && src[i + 1] == "*"
      block = 1
      out << " "
      i += 2
      next
    end

    if c == "#"
      # `#"`/`##"` raw strings: their terminator carries the same `#` run.
      j = i + 1
      j += 1 while j < n && src[j] == "#"
      if src[j] == '"'
        fences = j - i
        k = j + 1
        while k < n
          if src[k] == '"' && src[k + 1, fences] == ("#" * fences)
            k += 1 + fences
            break
          end
          k += 1
        end
        i = k
        next
      end
    end

    if c == '"'
      if src[i, 3] == '"""'
        j = i + 3
        while j < n
          if src[j] == "\\"
            j += 2
            next
          end
          if src[j, 3] == '"""'
            j += 3
            break
          end
          out << (src[j] == "\n" ? "\n" : " ")
          j += 1
        end
        i = j
        next
      end

      j = i + 1
      while j < n
        ch = src[j]
        if ch == "\n"
          break
        elsif ch == '"'
          j += 1
          break
        elsif ch == "\\"
          # `\(` opens an interpolation, which is code and can carry a
          # quote of its own; skip it to its matching paren.
          if src[j + 1] == "("
            k = j + 2
            depth = 1
            while k < n && depth.positive?
              depth += 1 if src[k] == "("
              depth -= 1 if src[k] == ")"
              k += 1
            end
            j = k
            next
          end
          j += 2
          next
        end
        j += 1
      end
      i = j
      next
    end

    out << c
    i += 1
  end

  out
end

# The `{` that opens a type's body, or nil. The header is everything up to
# it, so a generic parameter list (`NodeRef<T: Sendable>`) and an inherited
# list (`: Sendable, Equatable`) are consumed rather than mistaken for the
# body — and the list cannot itself contain a `{`.
def swift_body_start(header)
  depth = 0
  header.each_char.with_index do |c, i|
    case c
    when "<", "(" then depth += 1
    when ">", ")" then depth -= 1
    when "{"
      return i if depth.zero?
    end
  end
  nil
end

# The index of the bracket that closes the one at `open`, or nil.
#
# A `>` preceded by `-` is the arrow of a function's return type, not a
# generic close: `func dottedName() -> String {` has a `>` in it and no
# generic at all, and counting it would end the scan one token early and
# silently truncate the type's body. Swift's `->` has no spaces around it
# by convention, which is what makes the one preceding character enough.
def swift_close(src, open)
  depth = 0
  src.each_char.with_index do |c, i|
    next if i < open

    if c == ">" && src[i - 1] == "-"
      next
    elsif "([{<".include?(c)
      depth += 1
    elsif ")]}>".include?(c)
      depth -= 1
    end
    return i if depth.zero?
  end
  nil
end

# Skip a `{ … }` body in a chunk of code, reading more lines from `lines`
# until it balances. `idx` is left on the first line after it.
def swift_skip_body(lines, idx, chunk)
  depth = 0
  count = lambda do |text|
    text.each_char { |c| depth += 1 if c == "{"; depth -= 1 if c == "}" }
  end

  # A header may wrap its body onto the next line — `public init(…)` split
  # across lines — so read until the brace is in hand. Counting the whole
  # chunk rather than what follows the brace is what makes a one-line
  # `func … {` leave depth at 1 instead of 0: the body has been entered,
  # not finished.
  until chunk.include?("{")
    raise "unterminated declaration: #{chunk.strip}" if idx >= lines.length

    chunk += lines[idx]
    idx += 1
  end
  count.call(chunk)

  while depth.positive?
    raise "unterminated body" if idx >= lines.length

    chunk += lines[idx]
    count.call(lines[idx])
    idx += 1
  end
  idx
end

def check_swift(path)
  files = File.directory?(path) ? Dir[File.join(path, "*.swift")].sort : [path]

  ctors = []
  seen = {}
  decls = 0

  files.each do |file|
    code = swift_code(File.read(file))

    code.scan(/^[ \t]*(?:(?:public|internal|package|private|fileprivate|open)\s+)?(?:final\s+)?(?:indirect\s+)?(struct|enum|class|actor)\s+(`?\w+`?)/) do
      decls += 1
      kind = Regexp.last_match[1]
      name = Regexp.last_match[2].delete("`")

      header_end = Regexp.last_match.end(0)
      # The body starts at the first `{` of the header at bracket depth 0.
      # Angle brackets matter here: `struct NodeRef<T: Sendable>: Sendable`
      # has a generic parameter list and an inherited list between the name
      # and the brace, and neither is the body.
      offset = swift_body_start(code[header_end..].to_s)
      raise "#{file}: cannot find the body of `#{kind} #{name}`" if offset.nil?

      open = header_end + offset
      close = swift_close(code, open)
      raise "#{file}: `#{kind} #{name}` has no closing brace" if close.nil?

      body = code[(open + 1)...close]
      lines = body.lines

      if kind == "enum"
        # A case is how a Swift caller builds an enum, so it is returned.
        # An associated value with no label (`case binary(BinaryExpr)`) is
        # positional and takes no parameter by name; one with a label
        # (`case unknown(type: String)`) does.
        params = []
        lines.each do |raw|
          text = raw.strip
          next if text.empty?

          # Three spellings: `case name(Payload)`, `case name(label: T)`
          # and the raw-value `case name = "Wire"` — the third has already
          # lost its string to the stripper and leaves a bare `=`.
          m = text.match(/\Acase\s+(`?\w+`?)\s*(?:\(\s*(.*?)\s*\)|=\s*.*)?\s*\z/)
          raise "#{file}: cannot read this enum case: #{text}" if m.nil?

          payload = m[2]
          next if payload.nil?

          name_m = payload.match(/\A(\w+)\s*:/)
          params << name_m[1] if name_m
        end

        # The two lists are separate objects because `compare` subtracts
        # one from the other, and a case never takes a default.
        unless seen.key?(name)
          seen[name] = true
          ctors << [SWIFT_AST_RS_NAMES.fetch(name, name), params, []]
        end
        next
      end

      # Swift synthesizes the memberwise initializer only when no
      # initializer is written down, so an explicit `init` and the stored
      # properties are alternatives rather than two readings of one
      # constructor. Every declaration in between is skipped rather than
      # guessed at.
      init = nil
      props = []
      idx = 0

      while idx < lines.length
        text = lines[idx].strip
        idx += 1
        next if text.empty?

        if text.match?(/\A(?:(?:public|private|fileprivate|internal|open|final|static|class|convenience|required|override|mutating)\s+)*init\s*[!?]?\s*\(/)
          chunk = text
          while idx < lines.length && swift_close(chunk, chunk.index("(")).nil?
            chunk += lines[idx]
            idx += 1
          end
          open_paren = chunk.index("(")
          close_paren = swift_close(chunk, open_paren)
          raise "#{file}: cannot close the parameter list of `init` in #{name}" if close_paren.nil?

          init = chunk[(open_paren + 1)...close_paren]
          # …and the body, which assigns the properties and would otherwise
          # be read as declarations of its own.
          idx = swift_skip_body(lines, idx, chunk[(close_paren + 1)..].to_s)
          next
        end

        if text.match?(/\A(?:(?:public|private|fileprivate|internal|open|final|static|class|override)\s+)*func\b/)
          idx = swift_skip_body(lines, idx, text)
          next
        end

        # `Identifier.dottedName()` is a method; the scan above takes it.
        # What is left is `public let name: Type`, which is the memberwise
        # initializer's parameter list. `static` is deliberately absent: a
        # `static let` belongs to the type rather than an instance, so it
        # is not a parameter of the initializer — and a line with one falls
        # through to the raise below instead of quietly inflating `params`.
        m = text.match(/\A(?:(?:public|private|fileprivate|internal|open|lazy|weak|unowned|final|override)\s+)*(?:let|var)\s+(`?\w+`?)\s*:/)
        if m
          # An `=` after the type is a default value; one before it is not
          # a declaration at all. None of these structs has one, which is
          # why `defaulted` is empty for every synthesized init.
          tail = text.split(":", 2).last.to_s
          props << [m[1].delete("`"), tail.include?("=")]
          next
        end

        # The loud reading. A stored property whose declaration wraps onto
        # the next line leaves this scan reading the wrap as a declaration,
        # so stopping here would drop a field and every rule that depended
        # on it would still pass.
        raise "#{file}: cannot read this line of `struct #{name}` as a property: #{text}"
      end

      next if seen.key?(name)
      seen[name] = true

      pairs = init ? swift_params(init) : props
      ctors << [SWIFT_AST_RS_NAMES.fetch(name, name), pairs.map(&:first), pairs.select { |(_, d)| d }.map(&:first)]
    end
  end

  # A scan that stopped matching reports success, which is the failure this
  # checker exists to catch. No type declaration at all is the shape that
  # takes, so it is raised rather than counted.
  raise "no Swift type declarations found under #{path} - the parse stopped matching" if decls.zero?

  ctors
end
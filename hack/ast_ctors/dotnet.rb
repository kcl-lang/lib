# frozen_string_literal: true

# Constructors for the C# binding.
#
# `dotnet/KclLib.AST` is hand-written, not generated — `Base.cs Builders.cs
# Dto.cs Expr.cs Loader.cs Module.cs Stmt.cs Type.cs Wire.cs` — so unlike
# `check_python` and `check_go` there is no `__init__` / keyed literal to read
# the answer off. Three declarations in these files answer the question, and all
# three are read:
#
#   * the **primary constructor** of a `record`, `public record SchemaStmt(
#     string Type, NodeRef<string>? Doc = null, …)`. Reflection over the built
#     `KclLib.AST.dll` confirms every public record has exactly one public
#     constructor and it is this one — a record's copy constructor is
#     `protected`, and there is no `public X(…)` overload anywhere in the
#     package — so the declaration is the whole of it.
#   * the **static factories** on a record, `public static SchemaStmt Of(…)`.
#     `Builders.cs:15` calls these "the other half": each stamps the `type`
#     tag from the record's own `Tag` constant so a caller never spells
#     `"Call"` or `"NumberLit"`, and the decoder and the constructor cannot
#     disagree about which spelling is right. They forward to the primary
#     constructor, so `compare` unions them for free — they are returned, not
#     filtered, exactly as `check_kotlin` returns `AstBuild` in full.
#   * the **static methods of the three static classes**, `Ast.Expr`,
#     `AstLoader.ParseModule`, `AstWriter.ToWire`. None builds a node — they
#     wrap one (`NodeRef<object>`), decode one, or serialize one — so they are
#     returned under their declared return type and land in `unmapped`, which
#     is what they are.
#
# There is no builder and no `init`-only set beyond what the primary
# constructor already declares: the only hand-written public instance method in
# the package is `Module.ToJson()`, which returns a `string`. The `init`
# properties reflection reports on every record are the compiler's own rendering
# of its primary-constructor parameters, under the same names, so they are not a
# second spelling of the constructor and are not read twice.
#
# Three things about the source decide what gets read, and two of them are
# traps specific to this package:
#
#   * `public static` — and only `public static` plus `public record`. An
#     `internal static` member (`DtoLoader`, `ExprLoader`, `WireHelpers`, …) is
#     invisible to a caller in another assembly, which is C#'s own rule and the
#     same one `check_go` applies to an unexported Go field. It also keeps the
#     ~40 `…FromWire` decoders out: they read a document, they do not build one.
#     They are spelled `public static` inside an `internal` class, so the
#     accessibility has to be tracked per type rather than per member.
#   * `//` comments are stripped before anything is parsed. These files are
#     commented more densely than any other binding's, and the comments quote
#     `ast.rs` field-for-field — `pub filename: String,`, `Option<NodeRef<Expr>>`
#     — so an unstripped scan would read a record's own documentation as its
#     parameter list. No string literal in this package contains `//`, so the
#     naive strip is exact rather than merely close.
#   * `Pos.Default` (`public static readonly Pos Default = new("", 1, 1, 1, 1);`)
#     is the one declaration a loose `public static` scan would take for a
#     constructor. `readonly` and the `=` before the `(` both reject it.
#
# `defaulted` is what a parameter may be left out of: a `= default` in the
# signature, or a `params T[]` array, which is omittable by construction the way
# a Kotlin `vararg` is. It is read from the parameter list alone and nothing
# else — the `= ""` of `ImportStmt.RawPath` and the `= null` of `Target.Paths`
# are the same thing to a caller, and the `InitLocalsAndArguments` machinery
# underneath is not a thing this file needs to know.
#
# Parameter names come back in lowerCamelCase rather than as declared. C# has
# two spellings for the same parameter and this picks the one a caller writes:
# every `Of(…)` factory in the package already declares its parameters in
# lowerCamelCase (`Of(rawPath: …, asName: …)`), and that is the spelling a
# named argument binds to, while the PascalCase of a primary constructor is the
# spelling of the generated `init` property. The checker's one
# camelCase→snake_case pass reads either identically — `IfCond` and `ifCond`
# both reach `if_cond`, `KeyTy` and `keyTy` both reach `key_ty` — so the choice
# costs nothing on the join, and lowerCamelCase has the one property that
# PascalCase does not: it puts the tagged-enum tag parameter on `type`, which is
# what `KNOWN_HELPERS` spells it. Returning `Type` verbatim would report the tag
# as a field of `ast.rs` does not have on all forty-seven records that open with
# one, which would be a reading of this collector's own spelling rather than a
# gap in the binding.
#
# Six names here are not the `ast.rs` name, and each is the second C# name for a
# struct `ast.rs` does declare. They are listed here with their evidence because
# `STRUCT_ALIASES` is the checker's table and this file cannot add to it; until
# it does, the collector names the `ast.rs` struct directly.
#
#   `SchemaConfig`  ast.rs declares `SchemaExpr` (ast.rs:1196) with exactly
#                   these four fields, and `UnificationStmt.value` is declared
#                   with it — `Dto.cs:10` says the same of this record. The same
#                   claim `STRUCT_ALIASES` already records for Kotlin.
#   `CallDto`       ast.rs declares `CallExpr` (ast.rs:1052), held by
#                   `Expr::Call(CallExpr)` (ast.rs:859); `Dto.cs:283` calls this
#                   record "the `CallExpr` fields; the struct is untagged".
#                   `Expr.cs`'s own tagged `CallExpr` maps to the same struct by
#                   name, and the two records agree field for field.
#   `Decorator`     ast.rs declares **no** `Decorator` struct. `Dto.cs:9` calls
#                   this one, but the field it fills is
#                   `SchemaStmt.decorators: Vec<NodeRef<CallExpr>>`
#                   (ast.rs:724), so it is `CallExpr` under another name —
#                   `Expr::Call` never reaches a decorator.
#   `TargetExpr`    `Expr::Target(Target)` (ast.rs:853) and `Expr::Identifier(
#                   Identifier)` (ast.rs:854) hold `Target` (ast.rs:932) and
#                   `Identifier` (ast.rs:973). The `…Expr` suffix marks the
#                   tagged wrapper as against the plain struct of the same
#                   fields, and names nothing in `ast.rs`.
#   `IntLiteralTypeValue`
#                   `LiteralType::Int(IntLiteralType)` (ast.rs:1903), and
#                   `IntLiteralType` (ast.rs:1909) is `{ value, suffix }` —
#                   those two fields, in that order.
#   `NodeRef`       `ast::Node<T>` (ast.rs:134), renamed because C# forbids a
#                   record's positional property from sharing its type's name
#                   (`Base.cs:21`). `Node` is in `NOT_NODES`, so this entry
#                   changes nothing the rules judge; it is here so `NodeRef`
#                   does not read as an unknown type.
#
# Two things this collector cannot see, and neither is papered over here.
# `SerializeProgram` (ast.rs:386) has no C# type at all: `AstLoader.ParseProgram`
# returns `List<Module>` after flattening `pkgs.__main__`, and
# `AstLoader.WriteProgramJson` builds the envelope as a `Dictionary<string,
# object?>` and returns a `string`, so `root` is a parameter of a serializer and
# not a field anyone can set on a node. `check_ast_constructors.rb` records it
# in `NOT_MODELED` for dotnet, and the report names it as deliberately not
# modeled rather than as missing. And `LiteralType.Int(value, suffix)`
# (`Type.cs:119`) returns a `LiteralType` — a tagged-enum wrapper — while the
# struct it fills in, `IntLiteralTypeValue`, is named nowhere in that signature:
# the blind spot `WRAPPED_PAYLOADS` exists to write down. It happens not to cost
# anything here, because `IntLiteralTypeValue.Of(value, suffix)` is a complete
# constructor for the payload in its own right and is returned below under
# `IntLiteralType`.

def check_dotnet(path)
  # The AST types are all in `KclLib.AST`; nothing under `KclLib` names one —
  # `KclLib/api` reaches the API and the runner, not the tree — so this takes
  # the `dotnet/` root or the project directory and uses whichever it is given.
  dir = File.directory?(path) ? path : File.dirname(path)
  dir = File.join(dir, "KclLib.AST") if File.directory?(File.join(dir, "KclLib.AST"))

  renames = {
    "NodeRef" => "Node",
    "CallDto" => "CallExpr",
    "Decorator" => "CallExpr",
    "SchemaConfig" => "SchemaExpr",
    "TargetExpr" => "Target",
    "IdentifierExpr" => "Identifier",
    "IntLiteralTypeValue" => "IntLiteralType"
  }

  # Split a parameter list on the commas that separate parameters, ignoring the
  # ones inside a generic's angle brackets, a `params` array's brackets or a
  # default value's own string — `List<NodeRef<object>>? Keywords = null` and
  # `string RawValue = "\"\""` each carry a comma that means nothing.
  split = lambda do |text|
    params = []
    depth = 0
    quoted = false
    current = +""
    text.each_char do |ch|
      case ch
      when '"' then quoted = !quoted
      when "<", "(", "[", "{" then depth += 1 unless quoted
      when ">", ")", "]", "}" then depth -= 1 unless quoted
      when ","
        if depth.zero? && !quoted
          params << current.strip
          current = +""
          next
        end
      end
      current << ch
    end
    params << current.strip
    params.reject(&:empty?)
  end

  # One `Type Name = default` parameter, as `[name, defaulted?]`.
  #
  # C# puts the type first, so the name is the last identifier before the `=`
  # and not the first word — which is the whole of `string RawPath = ""` and of
  # `List<string>? Keywords = null`. One pass answers both questions: the `=`
  # that ends the declaration is at bracket depth 0 and outside a string, and
  # everything before it is `Type Name`.
  parse = lambda do |text|
    depth = 0
    quoted = false
    cut = text.length
    text.each_char.with_index do |ch, i|
      case ch
      when '"' then quoted = !quoted
      when "<", "(", "[", "{" then depth += 1 unless quoted
      when ">", ")", "]", "}" then depth -= 1 unless quoted
      when "="
        if depth.zero? && !quoted
          cut = i
          break
        end
      end
    end

    head = text[0...cut]
    # `params T[] names` is omittable by construction, the way a `vararg` is.
    defaulted = cut < text.length || head.start_with?("params ")
    name = head.sub(/\A(?:params|ref|out|in|readonly)\s+/, "").strip[/\b(@?\w+)\z/, 1]
    raise "cannot read #{text.strip.inspect} as a C# parameter" if name.nil?

    [name.sub(/\A@/, "").sub(/\A[A-Z]/) { |c| c.downcase }, defaulted]
  end

  # The text between the `(` at `open` and the `)` that closes it. Every
  # parameter list in this package is either on one line or continues onto the
  # next, so this is what makes `SchemaStmt`'s thirteen parameters readable.
  # Brackets inside a string are not brackets.
  balanced = lambda do |text, open|
    depth = 0
    quoted = false
    i = open
    while i < text.length
      case text[i]
      when '"' then quoted = !quoted
      when "(" then depth += 1 unless quoted
      when ")"
        unless quoted
          depth -= 1
          return text[(open + 1)...i] if depth.zero?
        end
      end
      i += 1
    end
    nil
  end

  # `NodeRef<object>`, `List<NodeRef<object>>`, `string`: the type's own name,
  # with whatever it is wrapped in taken off. This is what identifies the struct
  # a static class's method builds — `Ast.Expr` returns a `NodeRef<object>`, and
  # `compare` reads that as the wrapper it is rather than as a node.
  bare_type = lambda do |text|
    depth = 0
    stripped = +""
    text.each_char do |ch|
      if ch == "<"
        depth += 1
      elsif ch == ">"
        depth -= 1
      elsif depth.zero?
        stripped << ch
      end
    end
    stripped = stripped.sub(/\?.*\z/m, "").sub(/\[.*\z/m, "")
    stripped.strip[/\b(\w+)\z/, 1]
  end

  # One parameter list, as `[params, defaulted]`.
  read = lambda do |text|
    parsed = split.call(text).map { |p| parse.call(p) }
    [parsed.map(&:first), parsed.select { |(_, d)| d }.map(&:first)]
  end

  # A type declaration opens a scope; a static member inside a record is a
  # constructor of that record, and a static class has no record to build. The
  # accessibility is captured because it is C#'s own rule about who may pass
  # what: the `…FromWire` decoders of `internal static class WireHelpers` are
  # spelled `public static` and are unreachable from another assembly, so a
  # scope that is not `public` hides its members rather than owning them.
  decl = /(public|internal|private|protected)\s+(?:(?:sealed|abstract|partial|readonly)\s+)*(static\s+)?(?:record|class|struct)\s+(\w+)/
  # `public static`, and only to the `(` on the same line. `readonly` and the
  # `= new(…)` of `Pos.Default` are both excluded, and a declaration whose
  # parameter list wrapped before its `(` would be missed rather than misread.
  stat = /public\s+static\s+(?!readonly\b)[^=;{}()\n]*?\(/

  ctors = []
  owner = nil
  hidden = false

  Dir[File.join(dir, "*.cs")].sort.each do |file|
    src = File.read(file).gsub(%r{//[^\n]*}, "")

    at = 0
    loop do
      d = decl.match(src, at)
      s = stat.match(src, at)
      # Whichever declaration comes first is the one that owns the rest of the
      # file, so the two scans cannot both claim the same characters.
      if d && (!s || d.begin(0) <= s.begin(0))
        # A `record` with no primary constructor has no `(` before the end of
        # its own declaration line; taking the next one would borrow a method's
        # parameter list, and taking the first unconditionally is what would
        # turn `Pos` into `Pos(string, …)`.
        open = src.index("(", d.end(0))
        open = nil if open && (nl = src.index("\n", d.end(0))) && open > nl
        hidden = d[1] != "public"
        owner = hidden || d[2] ? nil : d[3]

        if open && !hidden
          text = balanced.call(src, open)
          raise "#{file}: cannot close the parameter list of `#{d[3]}`" if text.nil?
          ctors << [renames.fetch(d[3], d[3]), *read.call(text)]
          at = open + text.length + 2
        else
          at = d.end(0)
        end
      elsif s
        # A generic method names its type arguments after the name:
        # `public static NodeRef<T>? NodeFromWire<T>(…)`. None is public here,
        # but the trailing `<T>` is still not part of the name.
        head = s[0].sub(/\Apublic\s+static\s+/, "").sub(/\(\z/, "").sub(/<[^<>]*>\z/, "")
        name = head[/\b(\w+)\s*\z/, 1]
        raise "#{file}: cannot read a method name out of #{head.strip.inspect}" if name.nil?

        text = balanced.call(src, s.begin(0) + s[0].rindex("("))
        raise "#{file}: cannot close the parameter list of #{head.strip}" if text.nil?

        # Inside a record every static factory returns that record; inside a
        # static class the return type is the declaration's own.
        struct = owner || bare_type.call(head[0...-name.length])
        raise "#{file}: `#{name}` has no return type to read" if struct.nil?

        ctors << [renames.fetch(struct, struct), *read.call(text)] unless hidden
        at = s.end(0)
      else
        break
      end
    end
  end

  ctors
end
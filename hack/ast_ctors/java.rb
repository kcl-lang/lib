# frozen_string_literal: true

# Constructors for the Java binding.
#
# `java/src/main/java/com/kcl/ast` is 92 hand-written Jackson POJOs, one per
# node — 74 concrete classes, 9 `enum`s, 9 `abstract class`es, and 6 nested
# `public static class` payload classes inside the tagged-enum wrappers — and
# unlike `check_python` and `check_go` nothing generates them, so
# there is no "the generator emits the class, therefore the class *is* the
# constructor" argument to lean on. The question is what a Java caller has, and
# the answer is: a no-arg constructor, and a getter/setter pair per property.
#
#     SchemaStmt s = new SchemaStmt();
#     s.setName(name);
#     s.setBody(body);
#
# There is nothing better, and the absence is worth writing down rather than
# assuming: no builder (`grep -rn 'Builder\|@Data\|lombok'` over the package
# returns nothing) and no static factory (the only `static` members in the whole
# package are nested type declarations, `NumberBinarySuffix.allNames()` and
# `Program.MAIN_PKG`). Six constructors take arguments at all — `Pos`, `Node`,
# `NodeRef`, `Index`, `Member`, `StringLit` — and only `Pos`, `Node`, `NodeRef`
# and `StringLit` among those pass a node's own fields by name, so 70 of the 74
# concrete classes have no field-taking route at all. The setter pair is
# therefore the constructor every node has, and a node's parameters are the
# properties of its class in declaration order — the same argument `check_python`
# makes about a dataclass's generated `__init__` and `check_go` makes about a
# keyed struct literal. It also means the binding has no counterpart to
# `kotlin/.../AstBuild.kt`: the ceremony that file exists to stop is the whole of
# Java's answer, and this checker can say so because it reads what Java offers
# rather than what Java wishes it offered.
#
# Three decisions carry the rest of the file.
#
# **Every parameter is defaulted**, and that is Java's answer rather than a
# generous reading of one. `new SchemaStmt()` compiles with no arguments and
# leaves every reference null and every primitive false/zero, so a caller may
# call any subset of the setters. This is the same argument `check_go` makes
# about a Go zero value, and it has the same consequence: rule 1 — a field Rust
# *always* writes must never be a required parameter — cannot fire for Java, and
# `new ArrayList<>()` is not something a Java caller should ever be made to
# write.
#
# **Two declarations are skipped, and both are skipped structurally rather than
# by name.** An `enum` declares constants, not state: there is no setter for
# one, so there is nothing for a caller to pass. An `abstract class` cannot be
# instantiated at all, so `new Expr()` does not compile. Nine classes here are
# abstract (`Expr`, `Stmt`, `Type`, `Literal`, `LiteralTypeValue`,
# `NumberLitValue`, `MemberOrIndex`, `BinOrAugOp`, `BinOrCmpOp`) and eleven are
# enums (nine top-level, `AnyTypeEnum` and `BasicTypeEnum` nested); the keyword
# that excludes each is in the source, so this is not a filter that can rot when
# a class is renamed. What is left is the count the report should be read
# against, and it is the anti-"stopped matching" number: 74 top-level concrete
# classes plus the 6 nested payloads is 80 declarations, of which `Pos` declares
# no no-arg constructor and so contributes its argument constructor rather than a
# field one — 79 field constructors plus the 6 argument-taking ones is 85. A
# collector that fell off would show 85 falling.
#
# **One name is a rename, and this file may not write it down where it
# belongs.** Java's `Program` is `ast.rs`'s `SerializeProgram` — `root: String`
# and `pkgs: HashMap<String, List<Module>>`, against `ast.rs:386`
# `pub struct SerializeProgram { pub root: String, pub pkgs: HashMap<String,
# Vec<Module>> }`. `ast.rs` also declares a `Program` (line 435) and it is the
# resolution index — `pkgs: HashMap<String, Vec<String>>`, `modules:
# HashMap<String, Arc<RwLock<Module>>>` — which `NOT_ON_THE_WIRE` already
# excludes, and holding a binding to a constructor for it would be holding it to
# the wrong document. Kotlin's `STRUCT_ALIASES` carries exactly this entry
# (`"Program" => "SerializeProgram"`) and Java needs the same one; the table is
# in `check_ast_constructors.rb`, which this file is not allowed to edit, so the
# mapping is applied here and the need is reported rather than added. Two
# further renames were considered and deliberately *not* applied, because the
# struct is already reachable without them and a silent second spelling is worse
# than a visible duplicate: `IdentifierExpr` is `ast.rs`'s `Identifier` (the
# same three fields) and `SchemaConfig` is `SchemaExpr` (the same four), and
# both arrive in the report's `unmapped` list where a reviewer can see them.
# `TargetExpr` needed no entry at all: `Target.java` already spells the struct
# correctly, and `TargetExpr.java` is a second, unregistered copy of it.
#
# What the report's `unmapped` line collects is the rest of this file's shape,
# and none of it is dropped to make the count look better. Twenty names land
# there: the tagged-enum variant carriers `AnyType`, `BasicType`, `LiteralType`
# and `NamedType` (which carry `ast.rs:1858`'s `Type` enum's payloads without
# having a struct of their own); the scalar payloads of two more enums,
# `BoolLiteralType`, `StrLiteralType`, `FloatLiteralType`,
# `IntNumberLitValue` and `FloatNumberLitValue`; the four `*BinOr*Op` operator
# wrappers; `Index` and `Member`, the arms of `ast.rs:950`'s `MemberOrIndex`;
# `NodeRef`; `Decorator`, which `ast.rs` does not declare at all although
# `SchemaStmt.decorators` is `Vec<NodeRef<CallExpr>>` (`ast.rs:724`); and the
# three second spellings, `IdentifierExpr`, `SchemaConfig` and `TargetExpr`.
# Every one of them names an enum variant, a payload ast.rs has no struct for, or
# a duplicate — which is where a constructor for it belongs.
#
# The five nested `*Value` classes are this binding's version of the blind spot
# `WRAPPED_PAYLOADS` exists for, and they are stated rather than papered over.
# `ast.rs:1858` declares `Type` as `#[serde(tag = "type", content = "value")]`,
# so `{"type":"Union","value":{…}}` is what the tree holds; Java spells that
# nesting literally, as `UnionType` carrying a `value` of type
# `UnionTypeValue`, and `ast.rs`'s `type_elements` field lives on the *inner*
# class. A constructor whose signature names only the wrapper therefore says
# nothing about the payload, which is exactly the case that table is for — but
# the table is keyed by *function name* and Java has no function:
# `new UnionType.UnionTypeValue()` is an ordinary public class with an implicit
# no-arg constructor and setters, directly reachable by any caller. So there is
# nothing to register and nothing to hide: each nested class is returned under
# the ast.rs struct it fills in, alongside the wrapper class that carries it,
# and `compare` judges the union. `IntLiteralType` is the case where the two
# genuinely collide — `ast.rs:1909` declares `value: i64`, and Java's outer
# `IntLiteralType.value` is the wrapper while `IntLiteralTypeValue.value` is
# the `i64` — so both classes are returned under that one struct and the
# wrapper's `value` parameter is the only thing the two have in common.
# `NamedTypeValue` is the sixth nested class and is the one that reaches
# nothing: `ast.rs:1860` writes `Named(Identifier)`, an enum variant whose
# payload is the `Identifier` struct, so Java's class for it fills in a struct
# that is already covered by `Identifier.java` and is returned under a name
# `ast.rs` does not declare.

def check_java(path)
  files = File.directory?(path) ? Dir[File.join(path, "*.java")].sort : [path]

  # Comments and literals are blanked in place rather than deleted, so the line
  # a member sits on survives and can still tell a nested class's fields from
  # its enclosing class's. Blanking a comment rather than deleting it is also
  # what keeps `SchemaStmt`'s `"""Schema documents"""` javadoc — whose braces
  # are the only unbalanced pair in the package outside a class body — from
  # being read as code.
  strip = lambda do |src|
    out = +""
    i = 0
    n = src.length
    while i < n
      two = src[i, 2]
      if two == "//"
        i += 2
        i += 1 while i < n && src[i] != "\n"
        out << " "
      elsif two == "/*"
        stop = src.index("*/", i + 2) || n
        out << src[i...stop].gsub(/[^\n]/, " ")
        i = stop + 2
      elsif src[i] == '"' || src[i] == "'"
        quote = src[i]
        i += 1
        i += 1 while i < n && src[i] != quote
        i += 1
        out << " "
      else
        out << src[i]
        i += 1
      end
    end
    out
  end

  # The `{` that opens a body is the last character of the match that found it,
  # so this is called with the index of that brace and returns the text between
  # it and the matching `}` along with the index just past that `}`. Braces in
  # this package are balanced once comments and literals are gone, which is the
  # only reason counting them is enough.
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

  # `class X {`, `public class X<T> extends Y<T> {`, `enum E {` — at any
  # nesting depth, because the tagged-enum payloads are `public static class`
  # nested inside the class that carries them, and at no *name*, because the
  # modifiers are matched and tested rather than the indentation: `abstract` is
  # the word that decides whether a caller can instantiate a class, so it has to
  # be read rather than inferred.
  header = /(?:^|\n)([ \t]*)((?:(?:public|protected|private|static|final|abstract|sealed)\s+)*)(class|enum|interface)\s+(\w+)\s*(?:<[^{};]*?>)?\s*(?:extends\s+([\w.]+)\s*(?:<[^{};]*?>)?\s*)?(?:implements[^{};]*?\{)?\{/

  decls = []
  files.each do |file|
    src = strip.call(File.read(file))
    pos = 0
    # Scanning resumes at the `{` rather than past the body, so a nested class
    # is found on the next iteration of the same walk.
    while (m = header.match(src, pos))
      body, after = body_of.call(src, m.end(0) - 1)
      decls << { file: file, kind: m[3], name: m[4], super: m[5], indent: m[1],
                 modifiers: m[2].split, body: body, open: m.end(0) - 1, close: after - 1 }
      pos = m.end(0)
    end
  end

  by_name = {}
  decls.each do |d|
    raise "#{d[:file]}: #{d[:name]} is declared twice in com.kcl.ast" if by_name.key?(d[:name])

    by_name[d[:name]] = d
  end

  # The class a nested one is written inside, which is not its `extends`: a
  # payload class extends the tagged-enum *base* (`IntLiteralType extends
  # LiteralTypeValue`) while the struct it fills in belongs to the class it is
  # nested in. Containment says which that is, with no name to match on.
  decls.each do |d|
    inner = decls.select { |o| o[:file] == d[:file] && o[:open] < d[:open] && o[:close] > d[:close] }
    d[:parent] = inner.max_by { |o| o[:close] - o[:open] }&.fetch(:name)
  end

  # A class's own body, with every nested declaration cut out of it. Without
  # this, `NamedType`'s scan would read `NamedTypeValue`'s fields as its own and
  # return them twice, and each nested class's trailing `}` would be read as a
  # member line.
  own_region = lambda do |d|
    out = +""
    i = 0
    body = d[:body]
    while (m = header.match(body, i))
      out << body[i...m.begin(0)]
      i = body_of.call(body, m.end(0) - 1).last
    end
    out << body[i..].to_s
    out
  end

  # Fields, setter names and declared constructors, at the class's own member
  # indentation. The indentation is the whole of the filter: a method *body* is
  # one level deeper, and `return doc;` inside `getDoc()` has the shape of a
  # field declaration exactly, so a scan that does not stop at the member
  # indentation would return every getter's return value as a field.
  members = lambda do |d|
    indent = Regexp.escape(d[:indent] + "    ")
    name = Regexp.escape(d[:name])
    fields = []
    setters = []
    ctors = []
    own_region.call(d).each_line do |line|
      if (m = line.match(/\A\s*public\s+void\s+set(\w+)\s*\(/))
        setters << m[1]
      elsif (m = line.match(/\A\s*(?:(?:public|protected|private)\s+)?#{name}\s*\((.*?)\)\s*\{/))
        ctors << m[1]
      elsif (m = line.match(/\A#{indent}(?=\S)((?:(?:public|protected|private|static|final|transient|volatile)\s+)*)([\w$.<>\[\], ?]+?)\s+(\w+)\s*(?:=[^;]*)?;\s*\z/))
        # `Program.MAIN_PKG` is the only `static` field in the package, and it
        # is a constant of the class rather than a property of the node.
        fields << m[3] unless m[1].split.include?("static")
      end
    end
    [fields, setters, ctors]
  end
  decls.each { |d| d[:members] = members.call(d) }

  # Java fields are private and inherited through `extends`, so a class's
  # properties are its superclass's first. Recursion rather than inheritance
  # because a caller passing a `NodeRef` is passing every field `Node` has, and
  # a scan that stopped at the subclass would report `NodeRef` as a node with no
  # fields at all.
  fields_of = lambda do |d|
    return d[:fields] if d.key?(:fields)

    sup = d[:super] && by_name[d[:super]]
    d[:fields] = (sup ? fields_of.call(sup) : []) + d[:members][0]
  end
  setters_of = lambda do |d|
    return d[:setters] if d.key?(:setters)

    sup = d[:super] && by_name[d[:super]]
    d[:setters] = (sup ? setters_of.call(sup) : []) + d[:members][1]
  end

  # A field with no setter is a field a caller cannot pass, and returning it
  # anyway would be a constructor claiming reachability it does not have — the
  # reason `check_go` raises rather than skipping a line it cannot read. Java's
  # own convention is not uniform here (`boolean isMixin` is written by
  # `setMixin`, `boolean hasQuestion` by `setHasQuestion`), so both spellings
  # are accepted and the *field* name is what is returned: deriving it from the
  # setter would turn `is_mixin` into `mixin` and lose the field entirely.
  settable = lambda do |field, setters|
    stem = field.sub(/\Ais(?=[A-Z])/, "")
    setters.include?(stem[0].upcase + stem[1..])
  end

  # Split a Java parameter list on the commas that separate parameters, ignoring
  # the ones inside a generic's angle brackets: `NodeRef<Expr> index` is one
  # parameter, not two.
  split_params = lambda do |text|
    params = []
    depth = 0
    current = +""
    text.each_char do |ch|
      case ch
      when "<" then depth += 1
      when ">" then depth -= 1
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
    params.reject(&:empty?)
  end

  # `struct` is the ast.rs name. `Program` is the one rename; see the note
  # above for why it is needed and why it is here rather than in the table it
  # belongs in.
  aliases = { "Program" => "SerializeProgram" }.freeze

  ctors = []

  decls.each do |d|
    # An enum has constants, not state, and an abstract class cannot be
    # instantiated: `new Expr()` does not compile, so neither is a constructor
    # of anything. Both are decided by a keyword in the source rather than by a
    # list of names.
    next if d[:kind] != "class" || d[:modifiers].include?("abstract")

    fields = fields_of.call(d)
    setters = setters_of.call(d)
    fields.each do |field|
      next if settable.call(field, setters)

      raise "#{d[:file]}: #{d[:name]}.#{field} has no public setter, so it is not a " \
            "parameter a caller can pass - this collector reads setters, not fields"
    end

    # A nested `<X>Value` class is the payload of the `X` tagged-enum variant,
    # so it fills in the struct `X` fills in. `ast.rs` calls that struct `X`;
    # Java splits the tag and the payload across two classes, and the payload
    # is the one that holds the fields.
    base = d[:parent] && d[:name] == "#{d[:parent]}Value" ? d[:parent] : d[:name]
    struct = aliases.fetch(base, base)

    # Every property is a parameter and every one of them is omittable, but only
    # for a class a caller can instantiate with no arguments: one that declares
    # a constructor taking arguments (`Pos`) has to be handed them first, so
    # there its fields are required rather than defaulted.
    declared = d[:members][2]
    if declared.empty? || declared.any?(&:empty?)
      ctors << [struct, fields, fields.dup]
    end

    # Each constructor that takes arguments is returned as well, because a
    # caller passing `new StringLit(value, rawValue, isLongString)` is passing
    # three fields of `StringLit` by a route a caller has. None of the six is a
    # `Vec` or a `HashMap` parameter, so rule 1 is unaffected by them.
    declared.each do |text|
      params = split_params.call(text).map { |p| p[/\w+[ \t]*\z/] }.compact
      ctors << [struct, params, []] if params.any?
    end
  end

  ctors
end
# frozen_string_literal: true

# Constructors for the Node.js binding.
#
# `nodejs/src/ast/*.mjs` is *hand-written*, not generated — it carries no
# "DO NOT EDIT BY HAND" header, and the commit that last touched it
# (`0171bb2`) aligns the decoders by hand. (`tools/astgen/emit_typescript.py` is
# easy to mistake for its generator: `TS_FILES` is `_base.ts _dto.ts …` and
# `cli.py` writes it to `wasm/src/ast`, which *is* generated — and
# `python3 tools/generate_ast.py --check` reports 23 matching files, none of
# them nodejs.)
#
# So the question is not where the classes came from but what a caller has to
# build one with, and the answer is unlike every other binding's: there is no
# class and no factory. The AST is plain JS objects, a node is an object
# literal, and the loaders — `exprFromWire`, `stmtFromWire`, `targetFromWire`,
# every other `*FromWire` — take a *wire document*, not the node's fields.
# `nodeFromWire(w, load)`'s one parameter is `w`, so returning a loader as a
# constructor would report a constructor all of whose parameters name no field.
# That is the `argumentsOf(vararg names)` shape `compare` already discounts, and
# registering all thirty-odd of them would bury the real answer under `unmapped`.
#
# What a caller does instead is write the literal, and the contract saying which
# keys it owes is `index.d.mts` — `package.json` publishes it as
# `exports["./ast"].types`, so it is the AST package's type contract, not a
# private build artefact. It is also the only file in the package that can
# answer the second half of the question. The JSDoc `@typedef {Object}` blocks
# in the `.mjs` modules spell optionality as a `|undefined` in the type, which
# says what a *decoded* node holds — every loader emits all of its keys whether
# or not the wire carried them, so that file cannot distinguish a key a caller
# may omit. `index.d.mts` marks a key `?`, and that is a statement about the
# caller writing the literal, which is what `defaulted` is supposed to mean.
#
# This is Go's argument with one difference that matters. Go's keyed literal is
# also "the constructor", and every key in it is optional because an omitted
# field keeps its zero value, so `check_go` puts everything in `defaulted`. A JS
# object literal has no such hole: `{}` is not a `CallExpr`, the interface's own
# required members are what the type checker demands, and rule 1 fires on every
# `Vec` a caller would otherwise write as `[]`. That is the finding rather than
# a parsing accident — nodejs ships no builder at all, so the ceremony
# `AstBuild.kt` exists to stop is total here — and it is reported rather than
# softened, because a collector that called everything defaulted to make nodejs
# pass would be claiming a builder that does not exist.
#
# The parse is checked against a second, independent declaration of the same
# shapes: the `@typedef` in the `.mjs` modules, which is what the loaders were
# written from. Every type the contract declares must be declared there too, and
# every interface's member list must be the set the JSDoc spells out — so a
# member this parse misses, or one the contract invents, is a loud failure
# rather than a silently smaller `params`. Optionality is deliberately *not*
# cross-checked: the two disagree on exactly `CallExpr.type`, the JSDoc typing
# it `{…|undefined}` because that struct doubles as the untagged `Decorator`,
# and `type` is the variant tag `KNOWN_HELPERS` already excuses.
#
# The JS vocabulary is Java's, deliberately (`index.d.mts:10`, "The vocabulary
# is Java's"), so seven names
# differ from `ast.rs`'s: `Decorator` is `ast::CallExpr` (`index.d.mts:259` —
# `ast.rs` declares no `Decorator` at all, and `SchemaStmt.decorators` is
# `Vec<NodeRef<CallExpr>>`), `SchemaConfig` is `ast::SchemaExpr`
# (`index.d.mts:272`), and the five tagged twins `TargetExpr` /
# `IdentifierExpr` / `KeywordExpr` / `ArgumentsExpr` / `CompClauseExpr` are the
# `Expr::…` variant over the untagged struct (`index.d.mts:324, 332, 432, 468,
# 474`). `struct_for` reads those `ast::` / `Expr::` references out of the
# contract's own doc comments rather than carrying a private alias table, so
# every rename is a line a reviewer can grep for; a name with no reference is
# taken at its own spelling, which is what `compare` then checks, and a
# silently renamed type arrives in `unmapped` rather than being mapped by
# guesswork. `STRUCT_ALIASES` is the table for a binding whose *source* renames
# a struct; this one renames a type declaration, and no entry in that table
# would make the two files agree about it.
#
# Two `ast.rs` structs this binding has no constructor for, both real gaps
# rather than blind spots in the parse, and both recorded in
# `check_ast_constructors.rb`'s `NOT_MODELED` table as deliberately not
# modeled:
#
#   * `SerializeProgram` — `parseProgram` unwraps the envelope and returns the
#     modules of `pkgs.__main__` (`_module.mjs:47`), so the document a caller
#     receives has no shape to build and `root` is dropped on the floor, exactly
#     as in Go.
#   * `IntLiteralType` — the payload of `LiteralType::Int`, the only variant
#     whose payload is a struct rather than a scalar. `index.d.mts:172` types
#     `LiteralType.value` as `unknown` and `innerTag` records which arm it was,
#     so the payload rides through undecoded and no node in the tree has one to
#     set. There is nothing to put in `WRAPPED_PAYLOADS` either: unlike Kotlin's
#     `literalIntType`, no function here builds one, not even a convenience.

def check_nodejs(path)
  dir = File.directory?(path) ? path : File.dirname(path)
  decl = File.join(dir, "index.d.mts")
  raise "#{decl} not found - it is the AST package's published type contract " \
        '(package.json exports["./ast"].types)' unless File.exist?(decl)

  src = File.read(decl)

  # The interfaces, in declaration order: name => [bases, params, defaulted].
  ifaces = {}
  src.scan(/^export interface (\w+)(?:<[^>\n]*>)?(?: extends ([^\n{]+))? \{\n(.*?)^\}/m) do
    name, base_text, body = Regexp.last_match.captures
    bases = base_text.to_s.scan(/\w+/)

    params = []
    defaulted = []
    # Doc comments go first. A member this scan cannot see is a member a caller
    # cannot set, which is the failure the whole checker exists to catch, so
    # nothing is passed over quietly: a body line that is neither comment nor
    # `name: Type` raises rather than being skipped.
    body.gsub(%r{/\*\*.*?\*/}m, "").gsub(%r{//[^\n]*}, "").each_line do |raw|
      text = raw.strip
      next if text.empty?

      # The `?` is the whole optionality answer: it is the only marker in either
      # file that says a key may be *left out*, rather than that its value may
      # be undefined once written.
      m = text.match(/\A(\w+)(\?)?: /)
      raise "#{decl}: not a member of `interface #{name}`: #{text}" if m.nil?

      params << m[1]
      defaulted << m[1] if m[2]
    end

    ifaces[name] = [bases, params, defaulted]
  end

  # First guard against a parse that has quietly stopped matching: every
  # `export interface` / `export type` in the file has to come out of the scan
  # above, so a regex matching twenty of seventy-one reports the mismatch
  # instead of reporting success. `Type`, `Expr` and `Stmt` are `export type`,
  # not interfaces — unions with no members, which nothing here has to place.
  aliases = src.scan(/^export type (\w+)/).flatten
  skipped = src.scan(/^export (?:interface|type) (\w+)/).flatten - ifaces.keys - aliases
  raise "#{decl}: no constructor parsed for #{skipped.join(' ')} - " \
        "an `export interface` this scan did not match" unless skipped.empty?

  # Second guard: `extends` names a type in the same file, so a dangling base
  # is a parse that lost one.
  dangling = ifaces.values.map(&:first).flatten.uniq - ifaces.keys
  raise "#{decl}: extends a type this file does not declare: #{dangling.join(' ')}" unless dangling.empty?

  # Inherited members resolve transitively and come first: that is the order
  # the declaration reads in. It is not the order the loaders emit —
  # `Object.assign({type}, loader(w))` puts the tag first — which is why the
  # cross-check below compares member *sets* and `compare` does not care, since
  # it reduces both lists to sets anyway.
  resolve = lambda do |name|
    bases, params, defaulted = ifaces.fetch(name)
    # Two lists, not one `flat_map` of the pair: a base's `defaulted` entries
    # are strings like its `params`, so flattening the pair together would
    # interleave them and quietly mark half the inherited members omittable.
    [bases.flat_map { |base| resolve.call(base)[0] } + params,
     bases.flat_map { |base| resolve.call(base)[1] } + defaulted]
  end
  resolved = ifaces.keys.to_h { |name| [name, resolve.call(name)] }

  # Braces are counted rather than pattern-matched, twice over: a JSDoc type is
  # not a regular expression. Three of the typedefs are intersections —
  # `{CompClause & {type: 'CompClause'|undefined}}` — and `\{[^}]*\}` stops at
  # the inner brace and loses the name after it. `[open, close]`, or nil.
  braces = lambda do |text, from|
    open = text.index("{", from)
    next nil if open.nil?

    depth = 0
    text[open..-1].each_char.with_index do |ch, i|
      depth += 1 if ch == "{"
      next unless ch == "}"

      depth -= 1
      return [open, open + i] if depth.zero?
    end
    nil
  end

  # Every `@property` name in a doc block, whether the block is one line (most
  # of `_expr.mjs`) or ten.
  properties = lambda do |span|
    found = []
    at = 0
    while (tag = span.index("@property", at))
      pair = braces.call(span, tag)
      break if pair.nil?

      _, close = pair
      name = span[(close + 1)..-1].to_s[/\A[ \t]*\[?(\w+)\]?/, 1]
      found << name if name
      at = close + 1
    end
    found
  end

  # `key:` pairs at the top level of an inline object type — the `{type: …}` half
  # of an intersection typedef. Angle brackets are not counted: these bodies
  # are `{type: 'Literal'|undefined}` and a `>` with no `<` (an `=>`) would put
  # the depth negative and hide every key after it.
  inline_keys = lambda do |text|
    keys = []
    depth = 0
    text.each_char.with_index do |ch, i|
      depth += 1 if "{[(".include?(ch)
      depth -= 1 if "}])".include?(ch)
      keys << text[0...i][/(\w+)[ \t]*\z/, 1] if ch == ":" && depth.zero?
    end
    keys.compact
  end

  # The second declaration of every shape: what the loaders were written from.
  js_members = Hash.new { |h, k| h[k] = [] }
  Dir[File.join(dir, "*.mjs")].sort.each do |file|
    text = File.read(file)
    at = 0
    while (tag = text.index("@typedef", at))
      pair = braces.call(text, tag)
      raise "#{file}: unterminated @typedef" if pair.nil?

      open, close = pair
      name = text[(close + 1)..-1].to_s[/\A\s*(\w+)/, 1]
      at = close + 1
      next if name.nil?

      # The doc block this typedef lives in — the `/**` before it to the `*/`
      # after — because a one-line typedef keeps every `@property` tag on that
      # same line, and the block is what holds them either way.
      first = text.rindex("/**", close) || 0
      last = text.index("*/", close) || text.length
      js_members[name] |= properties.call(text[first...last])

      # An intersection typedef declares no `@property` of its own: it names
      # the struct it is and adds the tag beside it, which is the same shape
      # `extends` spells in the contract.
      inner = text[(open + 1)...close]
      next unless (m = inner.match(/\A(\w+)\s*&/))

      obj = inner[m.end(0)..-1].to_s.strip
      obj = obj[1..-2].to_s if obj.start_with?("{") && obj.end_with?("}")
      js_members[name] |= js_members[m[1]] | inline_keys.call(obj)
    end
  end

  # A type the runtime declares and the contract omits is the drift this
  # catches, and `MaybeNode` is the one known instance of it: `_base.mjs:34`
  # declares the optionality helper the `.mjs` spells its node types with, while
  # `index.d.mts` inlines `Node<T> | undefined` and never names it. It is not a
  # node and `ast.rs` has no struct for it.
  extra = js_members.keys - ifaces.keys - aliases - ["MaybeNode"]
  raise "#{decl}: #{extra.join(' ')} - a @typedef the .mjs modules declare and " \
        "the published contract does not" unless extra.empty?

  # The two declarations of one node drifting apart is a defect in the binding,
  # and a collector reading only one of them would report whichever it read.
  drift = resolved.reject { |name, (params, _)| js_members[name].uniq.sort == params.uniq.sort }
  raise "#{decl}: members disagree with the JSDoc @typedef in the .mjs modules: " \
        "#{drift.keys.join(' ')}" unless drift.empty?

  # The `ast.rs` struct each interface builds, read out of the doc comment the
  # contract puts directly above the declaration. `Expr::Foo(Bar)` is the
  # tagged twin of `Bar`; a bare `ast::Bar` is `Bar` in its untagged form.
  # There is no default table, because there is nothing to default to: a name
  # the contract does not tie to a struct is returned under its own spelling
  # and lands in `unmapped`, which is what it is.
  resolved.map do |name, (params, defaulted)|
    at = src.index(/^export interface #{name}\b/)
    # The doc comment sitting directly above the declaration. The comment body
    # cannot itself contain `*/` — `(?:[^*]|\*(?!/))*` — or a lazy `.*?` spans
    # from the file's first `/**` to its last `*/` and swallows the very
    # declaration whose name is being resolved. `\z` is what makes it *this*
    # comment: the adjacent one, not the nearest match from the top.
    # No match at all means the contract states no rename, and the interface's
    # own spelling is what `compare` gets to judge.
    doc = src[0...at][/(?:\/\*\*(?:[^*]|\*(?!\/))*\*\/[ \t]*\n)+[ \t\n]*\z/m].to_s
    struct = doc[/\bast::(\w+)/, 1] || doc[/Expr::\w+\((\w+)\)/, 1] || name
    [struct, params, defaulted]
  end
end
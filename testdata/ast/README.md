# AST wire contract

`alignment.k` is a single KCL file that exercises **every** node shape the
language bindings model. `alignment.json` is the `ast_json` the real parser
produces for it, captured once and committed.

Each binding's alignment test parses `alignment.k` through the native
dispatcher and asserts the invariants below against the result. The point is
not to re-test the parser — it is to stop each binding from *guessing* the
wire format, because a wrong guess fails silently: an unrecognised tag
decodes to null rather than throwing, so a binding that keys the `Type`
registry on `"Int"` instead of `"Basic"` still "works" and returns a tree
full of empty types.

The source of truth is `kcl-lang/kcl`'s `crates/ast/src/ast.rs`. This file is
a worked example of what that module actually serializes.

## The three serde shapes

`Stmt`, `Expr` and `Type` are all internally tagged, but they are tagged
*differently*, and mixing them up is the single most common bug.

### 1. `Stmt` and `Expr` — `#[serde(tag = "type")]`

Every variant carries a `type` discriminator and its payload is **flattened
into the same object**. `Expr` variants are newtypes over structs, so there
is no wrapper key:

```jsonc
// correct
{"type": "Identifier", "names": [...], "pkgpath": "", "ctx": "Load"}

// wrong - there is no "identifier" key
{"type": "Identifier", "identifier": {...}}
```

The same applies to `Target`, `Keyword`, `Arguments`, `CompClause` and
`Check`, which are *plain structs* (not variants) but still arrive flattened
under an `Expr`/`Stmt` tag. That is why `SchemaStmt.decorators` decodes to a
`CallExpr` and not to a tagged variant, and why `SchemaExpr.name` is a
`NodeRef<Identifier>` and not a `NodeRef<Expr>`.

### 2. `Type` — `#[serde(tag = "type", content = "value")]`

The payload lives under `value`, and the tag names the *shape*, not the type:

```jsonc
{"type": "Any"}
{"type": "Basic", "value": "Int"}          // BasicType is a fieldless enum
{"type": "Named", "value": {"names": [...], "pkgpath": "", "ctx": "Load"}}
{"type": "List", "value": {"inner_type": {...}}}
{"type": "Dict", "value": {"key_type": {...}, "value_type": {...}}}
{"type": "Union", "value": {"type_elements": [...]}}
{"type": "Function", "value": {"params_ty": [...], "ret_ty": {...}}}
{"type": "Literal", "value": {"type": "Int", "value": {"value": 1, "suffix": null}}}
```

Note the last one: `LiteralType` is *itself* tagged, so a literal type is
doubly nested. And there is no `Void`, `Undefined`, `None`, `SchemaRef` or
`KeyValue` variant — `BasicType` is exactly `Bool | Int | Float | Str`.

`NumberLit.value` is a third tagged enum, `NumberLitValue`, so a number
literal reads `{"type": "NumberLit", "binary_suffix": null, "value": {"type":
"Int", "value": 0}}` — the value is *not* a bare number.

### 3. Plain DTOs — no tag

`Identifier`, `Target`, `Keyword`, `Arguments`, `ConfigEntry`, `CheckExpr`,
`CallExpr`, `CompClause` and `SchemaIndexSignature` are structs with no
discriminator. `MemberOrIndex` is the exception: it is its own
`tag + content` enum, and its `value` is itself a `NodeRef`:

```jsonc
{"type": "Member", "value": {"node": "name", "filename": ..., "line": ...}}
{"type": "Index",  "value": {"node": {"type": "NumberLit", ...}, "filename": ...}}
```

## A `NodeRef<T>`

`Node<T>` is a boxed `{node, filename, line, column, end_line, end_column}`.
It serializes inline, so a `NodeRef<Expr>` is the expression object *with*
position fields mixed in — that is what "flattened" means above.

`ConfigEntry.is_shorthand` carries
`#[serde(skip_serializing_if = "is_false")]`, so the key is **absent** when
false. `Arguments.defaults` and `ty_list` are `Vec<Option<...>>` the same
length as `args`, so nulls must be preserved positionally.

## Coverage

`alignment.k` covers all 11 `Stmt` variants, all 8 `Type` variants, all 24
tagged `Expr` variants, and the untagged DTOs including both `MemberOrIndex`
arms and `SchemaIndexSignature`.

One variant is unreachable: **`Expr::Missing`** is only produced by the
parser's error recovery (`missing_expr()` is called from the error paths in
`crates/parser/src/parser/expr.rs`). A clean parse never emits it. Bindings
should still model it, because it shows up in the AST of a file that failed
to parse.

## Regenerating

The capture is normalized: `filename` fields are rewritten from the absolute
path the parser emits to the repository-relative `testdata/ast/alignment.k`,
so the file is portable across checkouts.

```shell
ruby -Iruby/lib -e '
require "kcl_lib"; require "json"
api = KclLib::API.new
rel = "testdata/ast/alignment.k"
# Spelled out rather than derived: `"#{rel}on"` looks like it appends "on" to
# make ".json" but it appends to the *whole* name and quietly writes
# `alignment.kon`, leaving the golden untouched and looking like it worked.
json = rel.sub(/\.k\z/, ".json")
r = api.parse_file(KclLib::ParseFileArgs.new(path: rel, source: File.read(rel)))
abort(r.errors.map { |e| e.messages.map(&:msg).join(";") }.join(" | ")) unless r.errors.empty?
abs = File.expand_path(rel)
File.write(json, JSON.pretty_generate(JSON.parse(r.ast_json)).gsub(abs, rel) + "\n")
puts "wrote #{json} (#{JSON.parse(File.read(json))["body"].size} body items)"
'
```

Assert against the *invariants* in this file, not a byte-for-byte diff — the
golden will move whenever the parser adds a field, and a test that fails on
an added field trains people to regenerate it without reading the diff.

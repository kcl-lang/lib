# frozen_string_literal: true

# Self-test for check_ast_field_types.rb.
#
# A checker that reports "ok" on a deliberately broken binding is worse than
# no checker at all, so every rule it claims to enforce is verified by
# re-introducing a bug that actually happened and asserting the checker names
# the right struct and field.
#
# Usage: ruby hack/test_check_ast_field_types.rb

require "fileutils"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path(__dir__))
require "check_ast_field_types"

RUBY_SRC = File.read(File.expand_path("../ruby/lib/kcl_lib/ast.rb", __dir__))
JULIA_SRC = File.read(File.expand_path("../julia/src/ast.jl", __dir__))

# Each case is [label, source, context before, the correct line, the line with
# the bug swapped in, the struct the report must name, the field it must name],
# and optionally a trailing `true` asking for that correct line to occur only
# once in the whole binding.
# The leading context matters: `body: node_list(...) { |w| stmt_from_wire(w) }`
# appears in three arms, and `String#sub` replaces the first one it finds, so
# without it half these cases would silently mutate the wrong struct.
#
# Cases marked *leaf* are a different bug class from the ones above. Those all
# change which node a field holds, which is visible in the decoder's arguments;
# a leaf case changes what the decoder does *inside*, one level below where the
# field name is checked. `Comment` is a plain struct with one `String` field, so
# the object under `node` is `{"text": "…"}` and not the text, and a decoder
# that never looks inside it turns every comment in the file into an empty
# string without raising. Four bindings shipped exactly that and the argument
# rules called all four clean, which is what these exist to prevent.
RUBY_CASES = [
  ["payload type: `SelectorExpr.attr` is an Identifier, not a String",
   RUBY_SRC, "        SelectorExpr.new(\n",
   "          attr: node_of(wire[\"attr\"]) { |w| Identifier.from_wire(w) },\n",
   "          attr: string_node(wire[\"attr\"]),\n",
   "SelectorExpr", "attr"],

  # `schema_expr_from_wire` builds a `SchemaConfig` here rather than a
  # `SchemaExpr`: Ruby has the two as separate classes, the way `Dto.cs` does,
  # because `UnificationStmt.value` is the untagged one and the tagged `Expr::Schema`
  # is not. The report is still by the Rust struct, which is `SchemaExpr` for
  # both — so the case follows the constructor, not the Rust name.
  ["payload type: `SchemaExpr.name` is an Identifier, not a String",
   RUBY_SRC, "    def self.schema_expr_from_wire(wire)\n",
   "        name: node_of(wire[\"name\"]) { |w| Identifier.from_wire(w) },\n",
   "        name: string_node(wire[\"name\"]),\n",
   "SchemaExpr", "name"],

  ["list read as single: `IfStmt.body` is a `Vec`",
   RUBY_SRC, "        IfStmt.new(\n",
   "          body: node_list(wire[\"body\"]) { |w| stmt_from_wire(w) },\n",
   "          body: node_of(wire[\"body\"]) { |w| stmt_from_wire(w) },\n",
   "IfStmt", "body"],

  ["single read as list: `IfExpr.orelse` is one `NodeRef`",
   RUBY_SRC, "        IfExpr.new(\n",
   "          orelse: node_of(wire[\"orelse\"]) { |w| expr_from_wire(w) }\n",
   "          orelse: node_list(wire[\"orelse\"]) { |w| expr_from_wire(w) }\n",
   "IfExpr", "orelse"],

  ["list read as single: `LambdaExpr.body` is a `Vec`",
   RUBY_SRC, "        LambdaExpr.new(\n",
   "          body: node_list(wire[\"body\"]) { |w| stmt_from_wire(w) },\n",
   "          body: node_of(wire[\"body\"]) { |w| stmt_from_wire(w) },\n",
   "LambdaExpr", "body"],

  ["list read as single: `SchemaExpr.args` is a `Vec`",
   RUBY_SRC, "    def self.schema_expr_from_wire(wire)\n",
   "        args: node_list(wire[\"args\"]) { |w| expr_from_wire(w) },\n",
   "        args: node_of(wire[\"args\"]) { |w| expr_from_wire(w) },\n",
   "SchemaExpr", "args"],

  # Ruby hands the payload to the block, so `Comment.new` is handed
  # `{"text": "…"}`. Reading a key that is not on it is the whole bug: the
  # argument list still *names* `text`, which is why a field-name check and an
  # argument check both pass over it.
  ["leaf payload: `Comment` is a struct, so `Module.comments` reads `text` off it",
   RUBY_SRC, "    Module = Struct.new(:filename, :doc, :body, :comments, keyword_init: true) do\n",
   "Comment.new(text: AST.str(w, \"text\"))",
   "Comment.new(text: AST.str(w, \"node\"))",
   "Module", "comments", true]
].freeze

JULIA_CASES = [
  ["list read as single: `IfStmt.body` is a `Vec`",
   JULIA_SRC, "        return IfStmt(",
   "        return IfStmt(_node_list(get(w, \"body\", nothing), stmt_from_wire),\n",
   "        return IfStmt(_node_of(get(w, \"body\", nothing), stmt_from_wire),\n",
   "IfStmt", "body"],

  ["payload type: `SchemaExpr.name` is an Identifier, not a String",
   JULIA_SRC, "schema_expr_from_wire(w) =",
   "    SchemaExpr(_node_of(get(w, \"name\", nothing), identifier_from_wire),\n",
   "    SchemaExpr(_string_node(get(w, \"name\", nothing)),\n",
   "SchemaExpr", "name"],

  ["payload type: `SchemaStmt.name` is a String, not an Identifier",
   JULIA_SRC, "        return SchemaStmt(",
   "                          _string_node(get(w, \"name\", nothing)),\n",
   "                          _node_of(get(w, \"name\", nothing), identifier_from_wire),\n",
   "SchemaStmt", "name"],

  # A read that wraps onto its continuation line. The key is on the first line
  # and the loader on the second, so a line-based collector sees a `Vec` of
  # nothing and skips the payload rule — which is how `Target.paths` went
  # unchecked until `check_julia` was split into a scope pass and a read pass.
  ["wrapped read: `Target.paths` names its loader on the next line",
   JULIA_SRC, "target_from_wire(w) = Target(_string_node(get(w, \"name\", nothing)),",
   "                              _plain_list(get(w, \"paths\", nothing),\n" \
   "                                          member_or_index_from_wire),\n",
   "                              _plain_list(get(w, \"paths\", nothing),\n" \
   "                                          identifier_from_wire),\n",
   "Target", "paths"],

  ["wrapped read: `SchemaStmt.index_signature` names its loader on the next line",
   JULIA_SRC, "                          _node_of(get(w, \"index_signature\", nothing),\n",
   "                                   schema_index_signature_from_wire))\n",
   "                                   expr_from_wire))\n",
   "SchemaStmt", "index_signature"],

  ["leaf payload: `Comment` is a struct, so `Module.comments` reads `text` off it",
   JULIA_SRC, "Decode the payload of a `NodeRef<Comment>`.\n",
   "comment_from_wire(w) = Comment(_str(w, \"text\"))\n",
   "comment_from_wire(w) = Comment(_str(w, \"node\"))\n",
   "Module", "comments", true]
].freeze

LUA_SRC = File.read(File.expand_path("../lua/kcl_lib/ast.lua", __dir__))

LUA_CASES = [
  ["payload type: `SelectorExpr.attr` is an Identifier, not a String",
   LUA_SRC, "local function parse_selector_expr(d)",
   "    attr = node_ref(d.attr, parse_identifier),\n",
   "    attr = node_ref(d.attr, scalar_loader(\"\")),\n",
   "SelectorExpr", "attr"],

  ["payload type: `SchemaExpr.name` is an Identifier, not a String",
   LUA_SRC, "local function parse_schema_expr_inner(d)",
   "    name = node_ref(d.name, parse_identifier),\n",
   "    name = node_ref(d.name, scalar_loader(\"\")),\n",
   "SchemaExpr", "name"],

  ["list read as single: `IfStmt.body` is a `Vec`",
   LUA_SRC, "local function parse_if_stmt(d)",
   "    body = node_ref_list(d.body, parse_stmt),\n",
   "    body = node_ref(d.body, parse_stmt),\n",
   "IfStmt", "body"],

  ["single read as list: `IfExpr.orelse` is one `NodeRef`",
   LUA_SRC, "local function parse_if_expr(d)",
   "    orelse = node_ref(d.orelse, parse_expr),\n",
   "    orelse = node_ref_list(d.orelse, parse_expr),\n",
   "IfExpr", "orelse"],

  ["list read as single: `LambdaExpr.body` is a `Vec`",
   LUA_SRC, "local function parse_lambda_expr(d)",
   "    body = node_ref_list(d.body, parse_stmt),\n",
   "    body = node_ref(d.body, parse_stmt),\n",
   "LambdaExpr", "body"],

  # The decoder is named after the *payload* — `parse_check`, because `Check` is
  # Dart's and Java's name for Rust `CheckExpr`. A payload table keyed on the
  # Rust struct name offers `parse_check_expr`, matches nothing, and leaves
  # every `checks` read with no payload at all.
  ["payload type: `SchemaStmt.checks` is a list of CheckExpr, not of Expr",
   LUA_SRC, "local function parse_schema_stmt(d)",
   "    checks = node_ref_list(d.checks, parse_check),\n",
   "    checks = node_ref_list(d.checks, parse_expr),\n",
   "SchemaStmt", "checks"],

  # This is the shape Lua shipped in: the decoder is named after the payload, so
  # every argument rule above matched, and only the body was wrong —
  # `scalar_loader` is Lua's string reader and `d` is an object.
  ["leaf payload: `Comment` is a struct, so `Module.comments` reads `text` off it",
   LUA_SRC, "local function parse_comment(d)\n",
   "    text = as_string(d.text, \"\"),\n",
   "    text = scalar_loader(\"\")(d),\n",
   "Module", "comments", true]
].freeze

DART_DIR = File.expand_path("../dart/lib/src/ast", __dir__)
DART_SRC = DART_FILES.to_h { |n| [n, File.read(File.join(DART_DIR, n))] }.freeze
# `Comment` is declared in `base.dart`, next to the wire helpers, and no field
# read is anywhere near it — which is why it is not in `DART_FILES`. The
# checker reads it for the leaf rule, so the scratch copies have to as well or
# the `Comment` case below would mutate a file nothing is looking at.
DART_LEAF_FILES = (DART_FILES + %w[base.dart]).freeze
DART_LEAF_SRC = DART_SRC.merge(
  "base.dart" => File.read(File.join(DART_DIR, "base.dart"))
).freeze

DART_CASES = [
  ["payload type: `SelectorExpr.attr` is an Identifier, not a String",
   DART_SRC["expr.dart"], "    case 'Selector':",
   "        attr: nodeOf<Identifier>(w['attr'], Identifier.fromWire),\n",
   "        attr: stringNode(w['attr']),\n",
   "SelectorExpr", "attr"],

  ["payload type: `SchemaExpr.name` is an Identifier, not a String",
   DART_SRC["expr.dart"], "SchemaExpr schemaExprFromWire(",
   "      name: nodeOf<Identifier>(w['name'], Identifier.fromWire),\n",
   "      name: stringNode(w['name']),\n",
   "SchemaExpr", "name"],

  ["list read as single: `IfStmt.body` is a `Vec`",
   DART_SRC["stmt.dart"], "    case 'If':",
   "        body: nodeListOf<KclStmt>(w['body'], stmtFromWire),\n",
   "        body: nodeOf<KclStmt>(w['body'], stmtFromWire),\n",
   "IfStmt", "body"],

  ["single read as list: `IfExpr.orelse` is one `NodeRef`",
   DART_SRC["expr.dart"], "    case 'If':",
   "        orelse: nodeOf<KclExpr>(w['orelse'], exprFromWire),\n",
   "        orelse: nodeListOf<KclExpr>(w['orelse'], exprFromWire),\n",
   "IfExpr", "orelse"],

  ["list read as single: `LambdaExpr.body` is a `Vec`",
   DART_SRC["expr.dart"], "    case 'Lambda':",
   "        body: nodeListOf<KclStmt>(w['body'], stmtFromWire),\n",
   "        body: nodeOf<KclStmt>(w['body'], stmtFromWire),\n",
   "LambdaExpr", "body"],

  # Dart names a decoder three ways — `CheckExpr.fromWire` on Dart's own name
  # for the struct, `memberOrIndexFromWire` as a top-level function, and
  # `Decorator` for a `CallExpr` — and a table listing only `X.fromWire` on the
  # Rust name leaves them unresolved. Swapping one for another is what a payload
  # table has to be able to see.
  ["payload type: `SchemaStmt.checks` is a list of CheckExpr, not of Expr",
   DART_SRC["stmt.dart"], "    case 'Schema':",
   "        checks: nodeListOf<CheckExpr>(w['checks'], CheckExpr.fromWire),\n",
   "        checks: nodeListOf<CheckExpr>(w['checks'], exprFromWire),\n",
   "SchemaStmt", "checks"],

  ["payload type: `SchemaStmt.decorators` is a list of CallExpr, not of Expr",
   DART_SRC["stmt.dart"], "    case 'Schema':",
   "        decorators: nodeListOf<Decorator>(w['decorators'], callExprFromWire),\n",
   "        decorators: nodeListOf<Decorator>(w['decorators'], exprFromWire),\n",
   "SchemaStmt", "decorators"],

  ["payload type: `Target.paths` is a list of MemberOrIndex, not of Identifier",
   DART_SRC["dto.dart"], "  factory Target.fromWire(Map<String, Object?> w) => Target(",
   "        paths: plainListOf<MemberOrIndex>(w['paths'], memberOrIndexFromWire),\n",
   "        paths: plainListOf<MemberOrIndex>(w['paths'], Identifier.fromWire),\n",
   "Target", "paths"],

  ["leaf payload: `Comment` is a struct, so `Module.comments` reads `text` off it",
   DART_LEAF_SRC["base.dart"], "  factory Comment.fromWire(Map<String, Object?> w) =>\n",
   "      Comment(w['text'] as String? ?? '');\n",
   "      Comment('');\n",
   "Module", "comments", true]
].freeze

PYTHON_DIR = File.expand_path("../python/kcl_lib/ast", __dir__)
PYTHON_SRC = PYTHON_FILES.to_h { |n| [n, File.read(File.join(PYTHON_DIR, n))] }.freeze

# Python spells a `Node<String>` by *omitting* the loader, so these mutations
# drop the second argument rather than swapping it for a string reader.
PYTHON_CASES = [
  ["payload type: `SelectorExpr.attr` is an Identifier, not a String",
   PYTHON_SRC["_expr.py"], '    def from_dict(cls, d: Any) -> "SelectorExpr":',
   "            attr=node_from_dict(d.get(\"attr\"), Identifier.from_dict),\n",
   "            attr=node_from_dict(d.get(\"attr\")),\n",
   "SelectorExpr", "attr"],

  # The case above only proves the *omission* convention, which resolved
  # whatever the classmethod spelled. This one swaps one classmethod for
  # another, so it is the classmethod form itself that has to be resolved — and
  # a table keyed on the snake spelling of the function form cannot do it, since
  # `Identifier.from_dict` and `Target.from_dict` are both one dotted token.
  ["payload type: `SelectorExpr.attr` is an Identifier, not a Target",
   PYTHON_SRC["_expr.py"], '    def from_dict(cls, d: Any) -> "SelectorExpr":',
   "            attr=node_from_dict(d.get(\"attr\"), Identifier.from_dict),\n",
   "            attr=node_from_dict(d.get(\"attr\"), Target.from_dict),\n",
   "SelectorExpr", "attr"],

  ["payload type: `SchemaExpr.name` is an Identifier, not a String",
   PYTHON_SRC["_dto.py"], '    def from_dict(cls, d: Any) -> "SchemaExpr":',
   "            name=node_from_dict(d.get(\"name\"), Identifier.from_dict),\n",
   "            name=node_from_dict(d.get(\"name\")),\n",
   "SchemaExpr", "name"],

  ["list read as single: `IfStmt.body` is a `Vec`",
   PYTHON_SRC["_stmt.py"], '    def from_dict(cls, d: Any) -> "IfStmt":',
   "            body=node_list_from_dict(d.get(\"body\"), stmt_from_dict),\n",
   "            body=node_from_dict(d.get(\"body\"), stmt_from_dict),\n",
   "IfStmt", "body"],

  ["single read as list: `IfExpr.orelse` is one `NodeRef`",
   PYTHON_SRC["_expr.py"], '    def from_dict(cls, d: Any) -> "IfExpr":',
   "            orelse=node_from_dict(d.get(\"orelse\"), expr_from_dict),\n",
   "            orelse=node_list_from_dict(d.get(\"orelse\"), expr_from_dict),\n",
   "IfExpr", "orelse"],

  ["list read as single: `LambdaExpr.body` is a `Vec`",
   PYTHON_SRC["_expr.py"], '    def from_dict(cls, d: Any) -> "LambdaExpr":',
   "            body=node_list_from_dict(d.get(\"body\"), stmt_from_dict),\n",
   "            body=node_from_dict(d.get(\"body\"), stmt_from_dict),\n",
   "LambdaExpr", "body"],

  # Python had this bug and the others did not, because it is the one binding
  # whose `NodeRef` loader hands the decoder the payload while its `Comment`
  # decoder went on to unwrap `node` a second time. The five comment lines above
  # the fix describe exactly that, and `node` is the token the rule looks for —
  # which is why the rule reads code and not comments.
  ["leaf payload: `Module.comments` unwraps `node` exactly once",
   PYTHON_SRC["_base.py"], "class Comment:\n",
   "        d = d if isinstance(d, dict) else {}\n        return cls(\n" \
   "            text=d.get(\"text\") or \"\",\n        )\n",
   "        d = d if isinstance(d, dict) else {}\n        return cls(\n" \
   "            text=(d.get(\"node\") or {}).get(\"text\") or \"\",\n        )\n",
   "Module", "comments", true],

  # And the other half: a decoder that drops the field read entirely decodes
  # every comment to `""` just as silently.
  ["leaf payload: `Comment` is a struct, so `Module.comments` reads `text` off it",
   PYTHON_SRC["_base.py"], "class Comment:\n",
   "            text=d.get(\"text\") or \"\",\n",
   "            text=d.get(\"body\") or \"\",\n",
   "Module", "comments", true]
].freeze

NODEJS_DIR = File.expand_path("../nodejs/src/ast", __dir__)
NODEJS_SRC = NODEJS_FILES.to_h { |n| [n, File.read(File.join(NODEJS_DIR, n))] }.freeze

# `(x) => /** @type {string} */ x` is how this binding spells a `Node<String>`,
# so the mutations below swap a loader for that identity reader rather than for
# a name.
NODEJS_CASES = [
  ["payload type: `SelectorExpr.attr` is an Identifier, not a String",
   NODEJS_SRC["_expr.mjs"], "function selectorFromWire(w) {",
   "    attr: nodeFromWire(w.attr, identifierFromWire),\n",
   "    attr: nodeFromWire(w.attr, (x) => /** @type {string} */ x),\n",
   "SelectorExpr", "attr"],

  # `SchemaExpr` is the payload of the `Schema` variant but has to decode
  # outside it too, so its fields are read by `schemaConfigFromWire` and the
  # `Schema` variant just delegates. The case is written against the function
  # that does the reading, which is where the checker looks for the field.
  ["payload type: `SchemaExpr.name` is an Identifier, not a String",
   NODEJS_SRC["_expr.mjs"], "export function schemaConfigFromWire(w) {",
   "    name: nodeFromWire(w.name, identifierFromWire),\n",
   "    name: nodeFromWire(w.name, (x) => /** @type {string} */ x),\n",
   "SchemaExpr", "name"],

  ["list read as single: `IfStmt.body` is a `Vec`",
   NODEJS_SRC["_stmt.mjs"], "function ifStmtFromWire(w) {",
   "    body: (w.body || []).map((/** @type {any} */ b) => nodeFromWire(b, stmtFromWire)),\n",
   "    body: nodeFromWire(w.body, stmtFromWire),\n",
   "IfStmt", "body"],

  ["single read as list: `IfExpr.orelse` is one `NodeRef`",
   NODEJS_SRC["_expr.mjs"], "function ifFromWire(w) {",
   "    orelse: nodeFromWire(w.orelse, exprFromWire),\n",
   "    orelse: (w.orelse || []).map((o) => nodeFromWire(o, exprFromWire)),\n",
   "IfExpr", "orelse"],

  ["payload type: `LambdaExpr.body` is a list of Stmt, not of Expr",
   NODEJS_SRC["_expr.mjs"], "function lambdaFromWire(w) {",
   "    body: (w.body || []).map((/** @type {any} */ b) => nodeFromWire(b, stmtFromWire)),\n",
   "    body: (w.body || []).map((/** @type {any} */ b) => nodeFromWire(b, exprFromWire)),\n",
   "LambdaExpr", "body"],

  ["payload type: `Module.comments` is a list of Comment, not of String",
   NODEJS_SRC["_module.mjs"], "export function moduleFromWire(w) {",
   "    comments: (w.comments || []).map(commentFromWire),\n",
   "    comments: (w.comments || []).map((c) => nodeFromWire(c, (x) => /** @type {string} */ x)),\n",
   "Module", "comments", true],

  # `_dto.checkExprFromWire` is reached through the namespace import, so the
  # payload is the last component of a qualified name. A table keyed on the bare
  # name matches nothing here.
  ["payload type: `SchemaStmt.checks` is a list of CheckExpr, not of Expr",
   NODEJS_SRC["_stmt.mjs"], "function schemaStmtFromWire(w) {",
   "    checks: (w.checks || []).map((/** @type {any} */ c) => nodeFromWire(c, _dto.checkExprFromWire)),\n",
   "    checks: (w.checks || []).map((/** @type {any} */ c) => nodeFromWire(c, exprFromWire)),\n",
   "SchemaStmt", "checks"],

  ["payload type: `Target.paths` is a list of MemberOrIndex, not of Identifier",
   NODEJS_SRC["_dto.mjs"], "export function targetFromWire(w) {",
   "    paths: (w.paths || [])\n" \
   "      .map((/** @type {any} */ p) => memberOrIndexFromWire(p))\n" \
   "      .filter((/** @type {MemberOrIndex|undefined} */ p) => p !== undefined),\n",
   "    paths: (w.paths || [])\n" \
   "      .map((/** @type {any} */ p) => identifierFromWire(p))\n" \
   "      .filter((/** @type {MemberOrIndex|undefined} */ p) => p !== undefined),\n",
   "Target", "paths"],

  # The `Type` variants read their payload from a local rather than from `w`,
  # so the key is `list.inner_type` and the receiver is not the wire object.
  ["payload type: `ListType.inner_type` is a Type, not an Expr",
   NODEJS_SRC["_types.mjs"], "    case 'List': {",
   "      return { type: 'List', innerType: nodeFromWire(list.inner_type, typeFromWire) }\n",
   "      return { type: 'List', innerType: nodeFromWire(list.inner_type, exprFromWire) }\n",
   "ListType", "inner_type"],

  ["payload type: `FunctionType.params_ty` is a list of Type, not of Expr",
   NODEJS_SRC["_types.mjs"], "    case 'Function': {",
   "        paramsTy: (fn.params_ty || []).map((/** @type {any} */ p) => nodeFromWire(p, typeFromWire)),\n",
   "        paramsTy: (fn.params_ty || []).map((/** @type {any} */ p) => nodeFromWire(p, exprFromWire)),\n",
   "FunctionType", "params_ty"],

  # The bug this binding actually shipped. `n` here is the *wrapper* — the
  # object `nodeFromWire` returned — so `n.text` is the wrapper's own key and
  # is undefined for every comment. It is the case a field-name check cannot
  # see: `text` is spelled correctly and `.text` really is read, just off the
  # wrong object.
  # The destructure has to go with the `return`: it is the other half of the
  # descent, and leaving it behind would make the mutated decoder still reach
  # under `node` — the very thing the mutation is meant to remove.
  ["leaf payload: `Module.comments` reaches under `node` before reading `text`",
   NODEJS_SRC["_base.mjs"], "export function commentFromWire(w) {\n",
   "  const { node, ...pos } = n\n" \
   "  return { ...pos, text: (node && node.text) || '' }\n",
   "  return { ...n, text: n.text || '' }\n",
   "Module", "comments", true],

  # `tsc --checkJs` put a `/** @type {any} */` on the `.map` callbacks, and the
  # collector's parameter pattern has to allow for it. If it ever stops doing so
  # the read does not fail, it *disappears*: the field leaves the comparison and
  # the only symptom is a smaller decoder count, which is the same silent
  # shrink the drift checker has its own guard against. Swapping the loader is
  # how that is caught — a read the collector cannot see reports nothing.
  ["payload type: `Arguments.args` is a list of Identifier, not of String",
   NODEJS_SRC["_dto.mjs"], "export function argumentsFromWire(w) {",
   "    args: (w.args || []).map((/** @type {any} */ a) => nodeFromWire(a, identifierFromWire)),\n",
   "    args: (w.args || []).map((/** @type {any} */ a) => nodeFromWire(a, (x) => /** @type {string} */ x)),\n",
   "Arguments", "args"],

  # The `Call` variant's decoder is a one-line forward to `_dto.decoratorFromWire`
  # — a different file, and reached through the namespace import. The collector
  # only finds this read by resolving the forward *and* taking the payload from
  # the qualified name, so this is the case that says the `CallExpr`/`Decorator`
  # pair is wired up rather than merely named.
  ["payload type: `CallExpr.func` is an Expr, not a String",
   NODEJS_SRC["_dto.mjs"], "export function decoratorFromWire(w) {",
   "    func: nodeFromWire(w.func, _expr.exprFromWire),\n",
   "    func: nodeFromWire(w.func, (x) => /** @type {string} */ x),\n",
   "CallExpr", "func"],

  # The one read in this binding that skips the `NodeRef` wrapper: `entry` is a
  # single `ConfigEntry`, so the loader is called on `w.entry` directly rather
  # than through `nodeFromWire`. A collector that only knows how to read
  # `nodeFromWire` calls does not see it at all.
  ["payload type: `DictComp.entry` is a ConfigEntry, not an Identifier",
   NODEJS_SRC["_expr.mjs"], "function dictCompFromWire(w) {",
   "    entry: _dto.configEntryFromWire(w.entry),\n",
   "    entry: _dto.identifierFromWire(w.entry),\n",
   "DictComp", "entry", true]
].freeze

TS_DIR = File.expand_path("../wasm/src/ast", __dir__)
TS_SRC = TS_FILES.to_h { |n| [n, File.read(File.join(TS_DIR, n))] }.freeze
# These files are generated (`tools/generate_ast.py`), so the target lines below
# track generator output rather than hand-written code: a re-anchor after a
# regeneration is expected, and the checker's own patterns are deliberately
# indifferent to whether the generator module-qualifies a helper.
#
# TypeScript spells a `Node<String>` as an inline identity loader, so these
# mutations swap the loader for an arrow rather than for a bare loader name.
TS_CASES = [
  ["payload type: `SelectorExpr.attr` is an Identifier, not a String",
   TS_SRC["_expr.ts"], "export function selectorExprFromWire(",
   "    attr: nodeFromWire(w.attr as never, identifierFromWire as never),\n",
   "    attr: nodeFromWire(w.attr as never, ((x: unknown) => x) as never),\n",
   "SelectorExpr", "attr"],

  ["payload type: `SchemaExpr.name` is an Identifier, not a String",
   TS_SRC["_dto.ts"], "export function schemaExprFromWire(",
   "    name: nodeFromWire(w.name as never, identifierFromWire as never),\n",
   "    name: nodeFromWire(w.name as never, ((x: unknown) => x) as never),\n",
   "SchemaExpr", "name"],

  ["list read as single: `IfStmt.body` is a `Vec`",
   TS_SRC["_stmt.ts"], "export function ifStmtFromWire(",
   "    body:\n    ((w.body as unknown[]) || []).map((e) =>\n      nodeFromWire(e as never, stmtFromWire as never),\n    ),\n",
   "    body: nodeFromWire(w.body as never, stmtFromWire as never),\n",
   "IfStmt", "body"],

  ["single read as list: `IfExpr.orelse` is one `NodeRef`",
   TS_SRC["_expr.ts"], "export function ifExprFromWire(",
   "    orelse: nodeFromWire(w.orelse as never, exprFromWire as never),\n",
   "    orelse:\n    ((w.orelse as unknown[]) || []).map((e) =>\n      nodeFromWire(e as never, exprFromWire as never),\n    ),\n",
   "IfExpr", "orelse"],

  ["list read as single: `LambdaExpr.body` is a `Vec`",
   TS_SRC["_expr.ts"], "export function lambdaExprFromWire(",
   "    body:\n    ((w.body as unknown[]) || []).map((e) =>\n      nodeFromWire(e as never, stmtFromWire as never),\n    ),\n",
   "    body: nodeFromWire(w.body as never, stmtFromWire as never),\n",
   "LambdaExpr", "body"],

  # The payload is the *second* spelling of the string reader — the list read
  # cast the wire array to `unknown[]`, so the identity loader asserts back to
  # `string` rather than annotating its parameter, and it brings parens of its
  # own. Reading it needs the call's balanced parens, not a lazy `(.+?)\)`: a
  # regex that stops at the arrow's own `)` names no payload at all, and rule 2
  # is then skipped for this read rather than satisfied.
  ["wrapped list read: `Identifier.names` is a list of String, not of Expr",
   TS_SRC["_dto.ts"], "export function identifierFromWire(",
   "    names:\n    ((w.names as unknown[]) || []).map((e) =>\n      nodeFromWire(e as never, (x) => x as unknown as string) as never,\n    ),\n",
   "    names:\n    ((w.names as unknown[]) || []).map((e) =>\n      nodeFromWire(e as never, exprFromWire as never),\n    ),\n",
   "Identifier", "names"],

  # The other direction from nodejs's case above, and the one this binding's
  # decoder was shipped wrong in: `Module.comments` reads `Comment` through
  # `nodeFromWire`, so the loader is handed the payload with `node` already
  # lifted and must *not* unwrap again. The file read `w.node?.text` anyway,
  # which is a key that is not on the payload — it decodes every comment in the
  # tree to `''` without raising, so nothing above the decoder could see it.
  ["leaf payload: `Module.comments` is handed the payload, so it must not unwrap `node`",
   TS_SRC["_base.ts"], "export function commentFromWire(\n",
   "    text: w.text ?? '',\n",
   "    text: w.node?.text ?? '',\n",
   "Module", "comments", true],

  # The one list in the tree with no loader to call: `Compare.ops` is
  # `Vec<CmpOp>`, whose elements are bare JSON strings, so it is copied with a
  # cast rather than mapped. The collector needs a spelling for that shape or
  # the field is not among the reads at all, and a field that is not among the
  # reads cannot fail the list rule.
  #
  # What this case proves is the list-ness, against the most plausible way to
  # lose it -- swapping in a node loader. It does *not* prove the spelling
  # exists: the mutation below is caught by the `nodeFromWire` pattern whether
  # the spelling is there or not. The spelling is proved by the count, which
  # goes 113 -> 114 when it is added, and stays at 113 when it is removed.
  ["bare list read: `Compare.ops` is a list of CmpOp, not a single node",
   TS_SRC["_expr.ts"], "export function compareFromWire(",
   "    ops: (w.ops as string[]) || [],\n",
   "    ops: nodeFromWire(w.ops as never, exprFromWire as never),\n",
   "Compare", "ops"]
].freeze

NET_DIR = File.expand_path("../dotnet/KclLib.AST", __dir__)
NET_SRC = NET_FILES.to_h { |n| [n, File.read(File.join(NET_DIR, n))] }.freeze

NET_CASES = [
  # `SelectorFromWire` is an expression-bodied member and boxes its `attr`, so
  # the read sits inside a `WireHelpers.Box(…)` the anchor has to step over.
  ["payload type: `SelectorExpr.attr` is an Identifier, not an Expr",
   NET_SRC["Expr.cs"], "    private static SelectorExpr SelectorFromWire(JsonElement o) => new(\n",
   "        Attr: WireHelpers.Box(WireHelpers.NodeFromWire<Identifier>(o.GetProperty(\"attr\"), DtoLoader.IdentifierFromWire!)),\n",
   "        Attr: WireHelpers.Box(WireHelpers.NodeFromWire<object>(o.GetProperty(\"attr\"), Loaders.ExprFromWire)),\n",
   "SelectorExpr", "attr"],

  ["payload type: `LambdaExpr.body` is a list of Stmt, not of Expr",
   NET_SRC["Expr.cs"], "    private static LambdaExpr LambdaFromWire(",
   "        Body: WireHelpers.NodeListFromWire<object>(o.GetProperty(\"body\"), Loaders.StmtFromWire),\n",
   "        Body: WireHelpers.NodeListFromWire<object>(o.GetProperty(\"body\"), Loaders.ExprFromWire),\n",
   "LambdaExpr", "body"],

  ["single read as list: `SchemaStmt.parent_name` is one `NodeRef`",
   NET_SRC["Stmt.cs"], "    private static SchemaStmt SchemaStmtFromWire(",
   "        ParentName: WireHelpers.NodeFromWire<Identifier>(o.GetProperty(\"parent_name\"), DtoLoader.IdentifierFromWire!),\n",
   "        ParentName: WireHelpers.OptList<object>(o, \"parent_name\"),\n",
   "SchemaStmt", "parent_name"],

  ["list read as single: `SchemaStmt.checks` is a `Vec`",
   NET_SRC["Stmt.cs"], "    private static SchemaStmt SchemaStmtFromWire(",
   "        Checks: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<CheckExpr>(o.GetProperty(\"checks\"), DtoLoader.CheckExprFromWire!)),\n",
   "        Checks: WireHelpers.BoxAll(WireHelpers.NodeFromWire<CheckExpr>(o.GetProperty(\"checks\"), DtoLoader.CheckExprFromWire!)),\n",
   "SchemaStmt", "checks"],

  # The case above only proves the list rule, which does not need the payload.
  # This one keeps the list and swaps the element, so it is `CheckExprFromWire`
  # — a decoder named after the *Rust struct*, with `CheckExpr` a two-word name
  # the payload `check` cannot be derived from — that has to resolve.
  ["payload type: `SchemaStmt.checks` is a list of CheckExpr, not of Expr",
   NET_SRC["Stmt.cs"], "    private static SchemaStmt SchemaStmtFromWire(",
   "        Checks: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<CheckExpr>(o.GetProperty(\"checks\"), DtoLoader.CheckExprFromWire!)),\n",
   "        Checks: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<CheckExpr>(o.GetProperty(\"checks\"), Loaders.ExprFromWire)),\n",
   "SchemaStmt", "checks"],

  # `Decorator` is .NET's own name for Rust `CallExpr` — the same `func`/`args`/
  # `keywords` struct under a decorator-flavoured name — so the payload can only
  # be checked if the alias is spelled out somewhere.
  ["payload type: `SchemaStmt.decorators` is a list of CallExpr, not of Expr",
   NET_SRC["Stmt.cs"], "    private static SchemaStmt SchemaStmtFromWire(",
   "        Decorators: WireHelpers.NodeListFromWire<Decorator>(o.GetProperty(\"decorators\"), DtoLoader.DecoratorFromWire!),\n",
   "        Decorators: WireHelpers.NodeListFromWire<Decorator>(o.GetProperty(\"decorators\"), Loaders.ExprFromWire),\n",
   "SchemaStmt", "decorators"],

  ["payload type: `ImportStmt.path` is a String, read as a node",
   NET_SRC["Stmt.cs"], "    private static ImportStmt ImportStmtFromWire(",
   "            Path: WireHelpers.NodeFromWire<string>(o.GetProperty(\"path\"), x => x.GetString()!),\n",
   "            Path: WireHelpers.OptString(o, \"path\"),\n",
   "ImportStmt", "path"],

  # `Type.cs` dispatches through a `Dictionary<string, Func<JsonElement, object>>`
  # instead of a `switch`, so `[ListType.Tag] = o => new ListType(…)` is the only
  # spelling of an inline arm in the whole binding — and a collector that
  # matched only `"Tag" =>` left `ListType`, `DictType`, `UnionType` and
  # `FunctionType` unreached, which is to say unchecked. The key is the
  # `Type.Tag` constant rather than the string `"List"`, so a collector that
  # wanted a string literal under the brackets found nothing here either; these
  # two cases are what make that difference visible rather than assumed.
  ["payload type: `ListType.inner_type` is a Type, not an Expr",
   NET_SRC["Type.cs"], "        [ListType.Tag] = o => new ListType(",
   "            WireHelpers.NodeFromWire<object>(o.GetProperty(\"inner_type\"), Loaders.TypeFromWire)),\n",
   "            WireHelpers.NodeFromWire<object>(o.GetProperty(\"inner_type\"), Loaders.ExprFromWire)),\n",
   "ListType", "inner_type"],

  # Same arm, with the list rule rather than the payload one: a `Vec` read
  # through the single-node helper drops the whole union apart from one member.
  ["list read as single: `UnionType.type_elements` is a `Vec`",
   NET_SRC["Type.cs"], "        [UnionType.Tag] = o => new UnionType(",
   "            WireHelpers.NodeListFromWire<object>(o.GetProperty(\"type_elements\"), Loaders.TypeFromWire)),\n",
   "            WireHelpers.NodeFromWire<object>(o.GetProperty(\"type_elements\"), Loaders.TypeFromWire)),\n",
   "UnionType", "type_elements"],

  # An arm wide enough to need one argument per line. The body has to run to the
  # paren that closes the *constructor*, not to the first `)` on the line, or
  # the read on the last line of the arm is never seen.
  ["list read as single: `UnificationStmt.target` is one `NodeRef<Identifier>`",
   NET_SRC["Stmt.cs"], "            \"Unification\" => new UnificationStmt(",
   "                Target: WireHelpers.NodeFromWire<Identifier>(el.GetProperty(\"target\"), DtoLoader.IdentifierFromWire!),\n",
   "                Target: WireHelpers.OptList<object>(el, \"target\"),\n",
   "UnificationStmt", "target"],

  ["payload type: `UnificationStmt.target` is an Identifier, not a Target",
   NET_SRC["Stmt.cs"], "            \"Unification\" => new UnificationStmt(",
   "                Target: WireHelpers.NodeFromWire<Identifier>(el.GetProperty(\"target\"), DtoLoader.IdentifierFromWire!),\n",
   "                Target: WireHelpers.NodeFromWire<Target>(el.GetProperty(\"target\"), DtoLoader.TargetFromWire!),\n",
   "UnificationStmt", "target"],

  # `SchemaConfig` is .NET's own name for Rust `SchemaExpr`, the same rename
  # Ruby, Julia and Dart made — `name`/`args`/`kwargs`/`config` field for
  # field. The payload can only be named if the alias is spelled out.
  ["payload type: `UnificationStmt.value` is a SchemaExpr, not an Expr",
   NET_SRC["Stmt.cs"], "            \"Unification\" => new UnificationStmt(",
   "                Value: WireHelpers.NodeFromWire<SchemaConfig>(el.GetProperty(\"value\"), DtoLoader.SchemaConfigFromWire!)),\n",
   "                Value: WireHelpers.NodeFromWire<object>(el.GetProperty(\"value\"), Loaders.ExprFromWire)),\n",
   "UnificationStmt", "value"],

  # `Comment` is a plain struct with one `String` field, so the object under
  # `node` is `{"text": "…"}`. Reading it as a string — which is what a
  # `NodeRef<string>` binding does — yields null for every comment in the file
  # and drops them all without raising.
  ["payload type: `Module.comments` is a list of Comment, not of String",
   NET_SRC["Module.cs"], "    private static Module ModuleFromWire(",
   "            Comments: WireHelpers.NodeListFromWire<Comment>(el.GetProperty(\"comments\"), DtoLoader.CommentFromWire!)\n",
   "            Comments: WireHelpers.NodeListFromWire<string>(el.GetProperty(\"comments\"), x => x.GetString()!)\n",
   "Module", "comments", true],

  ["list read as single: `IfStmt.orelse` is a `Vec`",
   NET_SRC["Stmt.cs"], "            \"If\" => new IfStmt(",
   "                Orelse: WireHelpers.NodeListFromWire<object>(el.GetProperty(\"orelse\"), StmtFromWire)),\n",
   "                Orelse: WireHelpers.NodeFromWire<object>(el.GetProperty(\"orelse\"), StmtFromWire)),\n",
   "IfStmt", "orelse"],

  # The bug this binding actually shipped: `CommentFromWire` is handed the
  # payload with `node` already lifted out by `NodeFromWire`, and reading it as
  # a string returns null for every comment — which `?? ""` then turns into the
  # empty string, silently, for the whole file.
  ["leaf payload: `Comment` is a struct, so `Module.comments` reads `text` off it",
   NET_SRC["Dto.cs"], "    public static Comment? CommentFromWire(JsonElement el)\n",
   "        return new Comment(WireHelpers.OptString(el, \"text\") ?? \"\");\n",
   "        return new Comment(el.GetString() ?? \"\");\n",
   "Module", "comments", true]
].freeze

ZIG_DIR = File.expand_path("../zig/src/ast", __dir__)
ZIG_SRC = ZIG_FILES.to_h { |n| [n, File.read(File.join(ZIG_DIR, n))] }.freeze

ZIG_CASES = [
  ["payload type: `SelectorExpr.attr` is an Identifier, not an Expr",
   ZIG_SRC["expr.zig"], "pub const SelectorExpr = struct {",
   "            .attr = try base.parseOptionalNodeRef(alloc, base.getField(v, \"attr\") orelse .null, dto.Identifier, dto.Identifier.parse),\n",
   "            .attr = try base.parseOptionalNodeRef(alloc, base.getField(v, \"attr\") orelse .null, Expr, parseExprPayload),\n",
   "SelectorExpr", "attr"],

  ["payload type: `SchemaExpr.name` is an Identifier, not an Expr",
   ZIG_SRC["expr.zig"], "pub const SchemaExpr = struct {",
   "            .name = try base.parseOptionalNodeRef(alloc, base.getField(v, \"name\") orelse .null, dto.Identifier, dto.Identifier.parse),\n",
   "            .name = try base.parseOptionalNodeRef(alloc, base.getField(v, \"name\") orelse .null, Expr, parseExprPayload),\n",
   "SchemaExpr", "name"],

  ["single read as list: `IfExpr.orelse` is one `NodeRef`",
   ZIG_SRC["expr.zig"], "pub const IfExpr = struct {",
   "            .orelse_ = try base.parseOptionalNodeRef(alloc, base.getField(v, \"orelse\") orelse .null, Expr, parseExprPayload),\n",
   "            .orelse_ = try base.parseNodeRefList(alloc, base.getField(v, \"orelse\") orelse .null, Expr, parseExprPayload),\n",
   "IfExpr", "orelse"],

  ["list read as single: `LambdaExpr.body` is a `Vec`",
   ZIG_SRC["expr.zig"], "pub const LambdaExpr = struct {",
   "            .body = try base.parseNodeRefList(alloc, base.getField(v, \"body\") orelse .null, stmt.Stmt, stmt.parseStmtPayload),\n",
   "            .body = try base.parseOptionalNodeRef(alloc, base.getField(v, \"body\") orelse .null, stmt.Stmt, stmt.parseStmtPayload),\n",
   "LambdaExpr", "body"],

  ["list read as single: `IfStmt.body` is a `Vec`",
   ZIG_SRC["stmt.zig"], "pub const IfStmt = struct {",
   "            .body = try base.parseNodeRefList(alloc, base.getField(v, \"body\") orelse .null, Stmt, parseStmtPayload),\n",
   "            .body = try base.parseOptionalNodeRef(alloc, base.getField(v, \"body\") orelse .null, Stmt, parseStmtPayload),\n",
   "IfStmt", "body"],

  # Both mentions of `text` have to go, and the assignment target has to be
  # part of why: `.text = ` is the member being filled in and says nothing
  # about where its value came from, so a decoder that dropped both key lookups
  # and kept the initialiser still reads `text` four times and is still wrong.
  # That is the whole reason the rule tests for a key, not for a word.
  ["leaf payload: `Comment` is a struct, so `Module.comments` reads `text` off it",
   ZIG_SRC["module.zig"], "    pub fn parse(alloc: Allocator, v: Value) Error!Comment {\n",
   "        const inner = base.getField(v, \"text\") orelse v;\n" \
   "        return .{\n" \
   "            .text = try base.dupeString(alloc, base.getString(inner, \"text\") orelse (switch (inner) {\n",
   "        const inner = base.getField(v, \"body\") orelse v;\n" \
   "        return .{\n" \
   "            .text = try base.dupeString(alloc, base.getString(inner, \"body\") orelse (switch (inner) {\n",
   "Module", "comments", true]
].freeze

SWIFT_SRC = File.read(File.expand_path("../#{SWIFT_FILE}", __dir__))

# Swift spells a `Node<String>` by naming `stringNode`, so these swap the loader
# the way the other bindings do. The two `flatMap` cases are here because that
# is the only place Swift routes a read — a list decoder reached *through*
# `flatMap` rather than called on the key, which is how
# `FunctionType.params_ty` (`Option<Vec<NodeRef<Type>>>`) is read.
SWIFT_CASES = [
  ["payload type: `SelectorExpr.attr` is an Identifier, not a String",
   SWIFT_SRC, "    case \"Selector\":\n",
   "            attr: nodeRef(dict[\"attr\"], identifierFrom) ?? NodeRef(node: Identifier(names: [])),\n",
   "            attr: stringNode(dict[\"attr\"]) ?? NodeRef(node: Identifier(names: [])),\n",
   "SelectorExpr", "attr"],

  ["payload type: `SchemaExpr.name` is an Identifier, not a String",
   SWIFT_SRC, "private func schemaExpr(_ dict: [String: Any]) -> SchemaExpr {\n",
   "        name: nodeRef(dict[\"name\"], identifierFrom) ?? NodeRef(node: Identifier(names: [])),\n",
   "        name: stringNode(dict[\"name\"]) ?? NodeRef(node: Identifier(names: [])),\n",
   "SchemaExpr", "name"],

  ["payload type: `SchemaStmt.checks` is a list of CheckExpr, not of Expr",
   SWIFT_SRC, "    case \"Schema\":\n",
   "            checks: nodeRefList(dict[\"checks\"], checkExpr),\n",
   "            checks: nodeRefList(dict[\"checks\"], expr),\n",
   "SchemaStmt", "checks"],

  ["list read as single: `IfStmt.body` is a `Vec`",
   SWIFT_SRC, "        return .if(IfStmt(\n",
   "            body: nodeRefList(dict[\"body\"], stmt),\n",
   "            body: nodeRef(dict[\"body\"], stmt),\n",
   "IfStmt", "body"],

  ["single read as list: `IfExpr.orelse` is one `NodeRef`",
   SWIFT_SRC, "        return .if(IfExpr(\n",
   "            orelse: nodeRef(dict[\"orelse\"], expr) ?? NodeRef(node: .missing(MissingExpr()))\n",
   "            orelse: nodeRefList(dict[\"orelse\"], expr)\n",
   "IfExpr", "orelse"],

  ["list read as single: `LambdaExpr.body` is a `Vec`",
   SWIFT_SRC, "    case \"Lambda\":\n",
   "            body: nodeRefList(dict[\"body\"], stmt),\n",
   "            body: nodeRef(dict[\"body\"], stmt),\n",
   "LambdaExpr", "body"],

  ["list read as single: `Module.body` is a `Vec`",
   SWIFT_SRC, "private func parseModuleObject(_ dict: [String: Any]) throws -> Module {\n",
   "        body: nodeRefList(dict[\"body\"], stmt),\n",
   "        body: nodeRef(dict[\"body\"], stmt),\n",
   "Module", "body"],

  ["closure form: `Subscript.index` is one `NodeRef`, read as a list",
   SWIFT_SRC, "    case \"Subscript\":\n",
   "            index: dict[\"index\"].flatMap { nodeRef($0, expr) },\n",
   "            index: dict[\"index\"].flatMap { nodeRefList($0, expr) },\n",
   "Subscript", "index"],

  ["closure form: `FunctionType.params_ty` is a `Vec`, read as a single node",
   SWIFT_SRC, "    case \"Function\":\n",
   "            paramsTy: payload[\"params_ty\"].flatMap { optionalNodeRefList($0, kclType).compactMap { $0 } },\n",
   "            paramsTy: payload[\"params_ty\"].flatMap { nodeRef($0, kclType) },\n",
   "FunctionType", "params_ty"],

  # The argument still *names* `text:`, which is what makes this the shape the
  # name-and-type rules cannot see: only where the value came from is wrong.
  ["leaf payload: `Comment` is a struct, so `Module.comments` reads `text` off it",
   SWIFT_SRC, "private func comment(_ dict: [String: Any]) -> Comment {\n",
   "    Comment(text: dict[\"text\"] as? String ?? \"\")\n",
   "    Comment(text: \"\" as? String ?? \"\")\n",
   "Module", "comments", true]
].freeze

# Java deserialises with Jackson, so the field *declaration* is the decoder: the
# generic argument is the payload and `List<...>` is the list decoder. That makes
# the third rule Java's alone — a field with no `@JsonProperty` is bound under
# its Java name, and a camelCase Java name never matches the snake_case key serde
# emits. Six such fields were shipped that way, so the wire-key rule is
# exercised here on the exact declarations that were wrong.
def java_cases(src)
  [
    ["payload type: `SelectorExpr.attr` is an Identifier, not an Expr",
     src["SelectorExpr.java"], "public class SelectorExpr extends Expr {\n",
     "    private NodeRef<Identifier> attr;\n",
     "    private NodeRef<Expr> attr;\n",
     "SelectorExpr", "attr"],

    ["payload type: `Module.comments` is a list of Comment, not of String",
     src["Module.java"], "public class Module {\n",
     "    private List<NodeRef<Comment>> comments;\n",
     "    private List<NodeRef<String>> comments;\n",
     "Module", "comments", true],

    ["payload type: `Target.paths` is a list of MemberOrIndex, not of Identifier",
     src["Target.java"], "public class Target {\n",
     "    private List<MemberOrIndex> paths;\n",
     "    private List<Identifier> paths;\n",
     "Target", "paths"],

    ["payload type: `LambdaExpr.body` is a list of Stmt, not of Expr",
     src["LambdaExpr.java"], "public class LambdaExpr extends Expr {\n",
     "    private List<NodeRef<Stmt>> body;\n",
     "    private List<NodeRef<Expr>> body;\n",
     "LambdaExpr", "body"],

    ["list read as single: `IfStmt.body` is a `Vec`",
     src["IfStmt.java"], "public class IfStmt extends Stmt {\n",
     "    private List<NodeRef<Stmt>> body;\n",
     "    private NodeRef<Stmt> body;\n",
     "IfStmt", "body"],

    ["list read as single: `IfStmt.orelse` is a `Vec`",
     src["IfStmt.java"], "public class IfStmt extends Stmt {\n",
     "    private List<NodeRef<Stmt>> orelse;\n",
     "    private NodeRef<Stmt> orelse;\n",
     "IfStmt", "orelse"],

    ["single read as list: `IfExpr.orelse` is one `NodeRef`",
     src["IfExpr.java"], "public class IfExpr extends Expr {\n",
     "    private NodeRef<Expr> orelse;\n",
     "    private Optional<List<NodeRef<Expr>>> orelse;\n",
     "IfExpr", "orelse"],

    # `Optional<T>` is Rust's `Option<T>` and has to be peeled before the list
    # and payload rules can see anything, so the case puts the `List` *inside*
    # the `Optional`: a collector that forgot to unwrap would see only
    # `Optional<...>` and have nothing to say.
    ["`Optional` is peeled: `ListType.inner_type` is a single node",
     src["ListType.java"], "public static class ListTypeValue {\n",
     "        private Optional<NodeRef<Type>> innerType;\n",
     "        private Optional<List<NodeRef<Type>>> innerType;\n",
     "ListType", "inner_type"],

    # The four `@JsonProperty` that were missing when this was written. Dropping
    # each one puts Jackson back on the Java field name, which is the bug.
    ["wire key: `ListType.inner_type` needs @JsonProperty to bind the snake_case key",
     src["ListType.java"], "public static class ListTypeValue {\n",
     "        @JsonProperty(\"inner_type\")\n",
     "",
     "ListType", "inner_type"],

    ["wire key: `DictType.key_type` needs @JsonProperty to bind the snake_case key",
     src["DictType.java"], "public static class DictTypeValue {\n",
     "        @JsonProperty(\"key_type\")\n",
     "",
     "DictType", "key_type"],

    ["wire key: `UnionType.type_elements` needs @JsonProperty to bind the snake_case key",
     src["UnionType.java"], "public static class UnionTypeValue {\n",
     "        @JsonProperty(\"type_elements\")\n",
     "",
     "UnionType", "type_elements"],

    ["wire key: `FunctionType.params_ty` needs @JsonProperty to bind the snake_case key",
     src["FunctionType.java"], "public static class FunctionTypeValue {\n",
     "        @JsonProperty(\"params_ty\")\n",
     "",
     "FunctionType", "params_ty"],

    # Jackson is the decoder, so the annotation is the descent: it is what says
    # which key on the object under `node` the text comes from. Point it at a
    # key the struct does not have and every comment binds to null without
    # raising — the same silent emptying, one framework layer up.
    ["leaf payload: `Comment` is a struct, so `Module.comments` reads `text` off it",
     src["Comment.java"], "public class Comment {\n",
     "    @JsonProperty(\"text\")\n",
     "    @JsonProperty(\"body\")\n",
     "Module", "comments", true]
  ]
end

# The C AST is a header of declared types and a loader that reads the wire, so
# a case can name either. Every read-site case below lands in the loader; the
# one header case lands in the type declarations, which is the only thing the
# C collector can see that no read can prove.
C_DIR_PATH = File.expand_path("../c", __dir__)
C_SRC = File.read(File.join(C_DIR_PATH, "lib/kcl_lib_ast.c"))
C_HDR = File.read(File.join(C_DIR_PATH, "include/kcl_lib_ast.h"))
CPP_HDR = File.read(File.expand_path("../#{CPP_AST_HEADER}", __dir__))
CPP_NATIVE_SRC = File.read(File.expand_path("../#{CPP_NATIVE_HEADER}", __dir__))
C_HEADER_CASE = "include/kcl_lib_ast.h"
C_SOURCE_CASE = "lib/kcl_lib_ast.c"
CPP_NATIVE_CASE = "cpp/include/#{File.basename(CPP_NATIVE_HEADER)}"

C_CASES = [
  ["payload type: `IfStmt.orelse` is a list of Stmt, not of Expr",
   C_SRC, "case KCL_STMT_KIND_IF: {\n",
   "        parse_stmt_node_list(a, kcl_json_object_get(v, \"orelse\"), &s->u.if_stmt.orelse);\n",
   "        parse_expr_node_list(a, kcl_json_object_get(v, \"orelse\"), &s->u.if_stmt.orelse);\n",
   "IfStmt", "orelse"],

  ["list read as single: `IfExpr.orelse` is one `NodeRef`",
   C_SRC, "case KCL_EXPR_KIND_IF: {\n",
   "        kcl_expr_node_t* orelse = parse_expr_node(a, kcl_json_object_get(v, \"orelse\"));\n",
   "        kcl_expr_node_t* orelse = parse_expr_node_list(a, kcl_json_object_get(v, \"orelse\"));\n",
   "IfExpr", "orelse"],

  ["payload type: `SelectorExpr.attr` is an Identifier, not an Expr",
   C_SRC, "case KCL_EXPR_KIND_SELECTOR: {\n",
   "        kcl_identifier_node_t* attr = parse_identifier_node(a, kcl_json_object_get(v, \"attr\"));\n",
   "        kcl_identifier_node_t* attr = parse_expr_node(a, kcl_json_object_get(v, \"attr\"));\n",
   "SelectorExpr", "attr"],

  ["payload type: `SchemaStmt.checks` is a list of CheckExpr, not of Expr",
   C_SRC, "case KCL_STMT_KIND_SCHEMA: {\n",
   "        parse_check_expr_node_list(a, kcl_json_object_get(v, \"checks\"), &s->u.schema_stmt.checks);\n",
   "        parse_expr_node_list(a, kcl_json_object_get(v, \"checks\"), &s->u.schema_stmt.checks);\n",
   "SchemaStmt", "checks"],

  ["payload type: `Module.comments` is a list of Comment, not of String",
   C_SRC, "static void parse_module_into(",
   "    parse_comment_node_list(a, kcl_json_object_get(v, \"comments\"), &m->comments);\n",
   "    parse_string_node_list(a, kcl_json_object_get(v, \"comments\"), &m->comments);\n",
   "Module", "comments", true],

  ["payload type: `Identifier.names` is a list of String, not of Identifier",
   C_SRC, "static kcl_identifier_t* parse_identifier(",
   "    parse_string_node_list(a, kcl_json_object_get(v, \"names\"), &id->names);\n",
   "    parse_identifier_node_list(a, kcl_json_object_get(v, \"names\"), &id->names);\n",
   "Identifier", "names"],

  # `DictComp.entry` is a bare `ConfigEntry`: the wire carries no `"type"` tag
  # and no `node` wrapper, so the `_node` form looks for a key that is not
  # there. C is where this rule cannot be left to `compare`, because a wire key
  # is a bare string literal that nothing checks.
  ["untagged payload: `DictComp.entry` needs the bare decoder, not the `_node` one",
   C_SRC, "case KCL_EXPR_KIND_DICT_COMP: {\n",
   "        kcl_config_entry_t* entry = parse_config_entry(a, kcl_json_object_get(v, \"entry\"));\n",
   "        kcl_config_entry_t* entry = parse_config_entry_node(a, kcl_json_object_get(v, \"entry\"));\n",
   "DictComp", "entry"],

  ["payload type: `Target.paths` is a list of MemberOrIndex, not of Identifier",
   C_SRC, "static kcl_target_t* parse_target(",
   "                kcl_member_or_index_t* m = parse_member_or_index(a, kcl_json_array_get(paths, i));\n",
   "                kcl_member_or_index_t* m = parse_identifier(a, kcl_json_array_get(paths, i));\n",
   "Target", "paths"],

  # The one array in the loader with no generated list loader, and so the one
  # place a wrong element count is neither a compile error nor a crash.
  ["`Target.paths` is a hand-written array, bounded by its own length",
   C_SRC, "static kcl_target_t* parse_target(",
   "    size_t n = json_is_array(paths) ? kcl_json_array_length(paths) : 0;\n",
   "    size_t n = json_is_array(paths) ? 0 : 0;\n",
   "Target", "paths"],

  # A field the loader never asks for has no read to judge, so every rule
  # above is silent about it and the struct just decodes to zeroes. The member
  # is declared, the header check is satisfied, and nothing ever fills it.
  ["never read: `Module.comments` is asked for under its Rust name",
   C_SRC, "static void parse_module_into(",
   "    parse_comment_node_list(a, kcl_json_object_get(v, \"comments\"), &m->comments);\n",
   "    parse_comment_node_list(a, kcl_json_object_get(v, \"comment\"), &m->comments);\n",
   "Module", "comments", true],

  # The mirror of the read site: a Rust field with no member in the struct is
  # invisible to every rule above, because there is no read to judge.
  ["declared field: `Module.comments` needs a member of that name",
   C_HDR, "typedef struct kcl_module {\n",
   "    kcl_comment_node_list_t comments;\n",
   "    kcl_comment_node_list_t renamed_comments;\n",
   "Module", "comments", true],

  # `parse_comment_node` is handed the whole `{"node": …}` wrapper rather than
  # the payload, unlike every other `parse_*_node` in the file — those are
  # called with the unwrapped value. Dropping the `node` hop makes it read the
  # struct off the wrapper's own keys, where there are none.
  ["leaf payload: `Module.comments` reaches under `node` before reading `text`",
   C_SRC, "static kcl_comment_node_t* parse_comment_node(kcl_arena_t* a, const kcl_json_value_t* v)\n",
   "        c->text = read_key_str(a, kcl_json_object_get(v, \"node\"), \"text\");\n",
   "        c->text = read_key_str(a, v, \"text\");\n",
   "Module", "comments", true]
].freeze

# The native C++ header has a decoder of its own — the C one is reached only
# through the `#include`, and this file is 2000 lines none of the C cases can
# see. Every shape below is one the C++ collector has to recognise, and each
# one was verified to be invisible before its pattern existed: a read the
# collector does not match is not reported wrong, it is reported *not at all*,
# and the "no decoder reaches" assertion cannot see it because the struct is
# reached by its other reads.
CPP_NATIVE_CASES = [
  # `if (auto x = parse_node<T>(…)) { out->x = std::move(*x); }` is how an optional
  # single node is written, and it is how about half of this header's are —
  # forty-eight fields, none of which any pattern matched until the two `if`
  # patterns were added. Nothing said so: the struct was reached, the field had
  # no read, and no count of fields exists anywhere to notice.
  ["payload type: `Keyword.arg` is an Identifier, not an Expr",
   CPP_NATIVE_SRC, "inline std::shared_ptr<Keyword> parse_keyword(const json::Value& value)\n",
   "    if (auto arg = parse_node<Identifier>(field(value, \"arg\"), parse_identifier)) {\n",
   "    if (auto arg = parse_node<Expr>(field(value, \"arg\"), parse_expr)) {\n",
   "Keyword", "arg"],

  ["payload type: `CompClause.iter` is an Expr, not an Identifier",
   CPP_NATIVE_SRC, "inline std::shared_ptr<CompClause> parse_comp_clause(const json::Value& value)\n",
   "    if (auto iter = parse_node<Expr>(field(value, \"iter\"), parse_expr)) {\n",
   "    if (auto iter = parse_node<Identifier>(field(value, \"iter\"), parse_identifier)) {\n",
   "CompClause", "iter"],

  # `UnificationStmt.value` is where the C++ vocabulary diverges from Rust's:
  # the header spells the untagged `SchemaExpr` struct `SchemaConfig`, and only
  # `CPP_NATIVE_STRUCT` says so. Reading it as an `Expr` is both the wrong
  # payload and, without the alias, a payload the table has no name for.
  ["payload type: `UnificationStmt.value` is a SchemaExpr, not an Expr",
   CPP_NATIVE_SRC, "if (tag == \"Unification\") {\n",
   "        if (auto value_ref = parse_node<SchemaConfig>(field(value, \"value\"), parse_schema_config)) {\n",
   "        if (auto value_ref = parse_node<Expr>(field(value, \"value\"), parse_expr)) {\n",
   "UnificationStmt", "value"],

  # `Vec<Option<NodeRef<Type>>>`, read with the loader that takes the whole
  # array. A single-node decoder here drops every element that is not an object
  # and keeps the rest unpositioned.
  ["payload type: `Arguments.ty_list` is a list of Type, not of Expr",
   CPP_NATIVE_SRC, "inline std::shared_ptr<Arguments> parse_arguments(const json::Value& value)\n",
   "    out->ty_list = parse_opt_node_list<Type>(field(value, \"ty_list\"), parse_type);\n",
   "    out->ty_list = parse_opt_node_list<Expr>(field(value, \"ty_list\"), parse_expr);\n",
   "Arguments", "ty_list"],

  # The C++ header spells a `Decorator` where Rust spells a `CallExpr`; the
  # case above and this one are the pair that fails together if the alias is
  # dropped, and neither fails on its own. The anchor is two lines because
  # `if (tag == "Schema")` opens the `SchemaExpr` arm of `parse_expr` as well
  # as the `SchemaStmt` arm of `parse_stmt`, and the `decorators` line that
  # follows the first one belongs to neither.
  ["payload type: `SchemaStmt.decorators` is a list of CallExpr, not of Expr",
   CPP_NATIVE_SRC, "    if (tag == \"Schema\") {\n        auto out = std::make_shared<SchemaStmt>();\n",
   "        out->decorators = parse_node_list<Decorator>(field(value, \"decorators\"), parse_decorator);\n",
   "        out->decorators = parse_node_list<Expr>(field(value, \"decorators\"), parse_expr);\n",
   "SchemaStmt", "decorators"],

  # `parse_string_node` is this header's `Node<String>`, and it is spelled two
  # ways: bound before it is moved, and assigned. `CPP_NATIVE_CALL` matches
  # both and names the loader `string_node`, which no payload table has, so
  # the text-scoped claim is what stops the field being read twice and the
  # nameless copy deciding the verdict.
  ["payload type: `TypeAliasStmt.type_value` is a String, not an Expr",
   CPP_NATIVE_SRC, "if (tag == \"TypeAlias\") {\n",
   "        if (auto type_value = parse_string_node(field(value, \"type_value\"))) {\n",
   "        if (auto type_value = parse_node<Expr>(field(value, \"type_value\"), parse_expr)) {\n",
   "TypeAliasStmt", "type_value"],

  ["payload type: `SchemaIndexSignature.key_name` is a String, not an Expr",
   CPP_NATIVE_SRC, "inline std::shared_ptr<SchemaIndexSignature> parse_schema_index_signature(const json::Value& value)\n",
   "    out->key_name = parse_string_node(field(value, \"key_name\"));\n",
   "    out->key_name = parse_node<Expr>(field(value, \"key_name\"), parse_expr);\n",
   "SchemaIndexSignature", "key_name"],

  # A bare `Vec<MemberOrIndex>`: no `NodeRef`, so no `parse_node_list` to read
  # it and the loop pushes the decoded element itself. `CPP_NATIVE_BARE_LIST` is
  # the only pattern that sees this line, and it is the only one of the seven
  # whose key capture comes *first* — which is why the claim takes the key
  # rather than the last capture. That cost the field its whole check once.
  ["payload type: `Target.paths` is a list of MemberOrIndex, not of Expr",
   CPP_NATIVE_SRC, "inline std::shared_ptr<Target> parse_target(const json::Value& value)\n",
   "            out->paths.push_back(*parse_member_or_index(item));\n",
   "            out->paths.push_back(*parse_expr(item));\n",
   "Target", "paths"]
].freeze

JAVA_DIR_PATH = File.expand_path("../#{JAVA_AST_DIR}", __dir__)
KOTLIN_DIR_PATH = File.expand_path("../#{KOTLIN_AST_DIR}", __dir__)
JAVA_FILES = java_ast_files(JAVA_DIR_PATH)
KOTLIN_FILES = java_ast_files(KOTLIN_DIR_PATH)
JAVA_SRC = JAVA_FILES.to_h { |n| [n, File.read(File.join(JAVA_DIR_PATH, n))] }.freeze
KOTLIN_SRC = KOTLIN_FILES.to_h { |n| [n, File.read(File.join(KOTLIN_DIR_PATH, n))] }.freeze

# Kotlin compiles the same `com.kcl.ast` Java sources, so the two trees are
# kept identical and one set of cases serves both. Asserted rather than
# assumed: if they drift, the same mutation is no longer the same bug, and
# deriving one list from the other would quietly stop testing Kotlin.
#
# Identical *modulo comments and spacing*, because the two trees are formatted
# to their own languages' conventions: Java's Javadoc is filled to 118 columns
# and Kotlin's to 76, and a re-wrap is not a difference in the AST a case
# mutates. Comparing bytes instead made the guard fire on five files that
# differ in nothing but where the line breaks fall — which is a guard that
# trains you to reformat it away rather than a guard that catches a real split.
# The property the cases depend on is that a mutation lands on the same code in
# both, and that is a property of the code, not of the prose around it.
def java_tree_code(src)
  src.gsub(%r{/\*.*?\*/}m, " ").gsub(%r{//[^\n]*}, " ").gsub(/\s+/, " ").strip
end

drift = JAVA_FILES.zip(KOTLIN_FILES)
           .reject { |a, b| java_tree_code(JAVA_SRC[a]) == java_tree_code(KOTLIN_SRC[b]) }
           .map(&:first)
abort "java/kotlin AST trees have drifted: #{drift.join(' ')}" unless drift.empty?

JAVA_CASES = java_cases(JAVA_SRC).freeze
KOTLIN_CASES = java_cases(KOTLIN_SRC).freeze

# ---------------------------------------------------------------------------
# Go
# ---------------------------------------------------------------------------

# The collector reads struct declarations, so a Go case mutates a field's
# *declared type* — the slot name and the `[]`/`*` around it are the whole of
# what the checker knows about how the field is read. The lines below are
# copied verbatim from the generated tree, alignment included: `gofmt` pads
# the tag column, and a `good` line without that padding matches nothing and
# the case passes over a rule it never exercised.
GO_SRC = Dir[File.expand_path("../#{GO_AST_DIR}/*_gen.go", __dir__)]
         .to_h { |p| [File.basename(p), File.read(p)] }.freeze

GO_CASES = [
  ["payload type: `SelectorExpr.attr` is an Identifier, not an Expr",
   GO_SRC["expr_gen.go"], "type SelectorExpr struct {\n",
   "\tAttr        *IdentifierNode `json:\"attr\"`\n",
   "\tAttr        *ExprNode       `json:\"attr\"`\n",
   "SelectorExpr", "attr"],

  ["payload type: `Module.comments` is a list of Comment, not of String",
   GO_SRC["module_gen.go"], "type Module struct {\n",
   "\tComments []*CommentNode `json:\"comments\"`\n",
   "\tComments []*StringNode  `json:\"comments\"`\n",
   "Module", "comments"],

  # `Target.paths` is a bare `Vec<MemberOrIndex>`: no `NodeRef` wrapper at all,
  # so its Go type is `[]MemberOrIndex` with no slot suffix to strip. The slot
  # table in `go_payload` has to answer for a type whose name it does not
  # manufacture, and this is the only field in the tree that asks it to.
  ["payload type: `Target.paths` is a list of MemberOrIndex, not of Identifier",
   GO_SRC["dto_gen.go"], "type Target struct {\n",
   "\tPaths   []MemberOrIndex `json:\"paths\"`\n",
   "\tPaths   []IdentifierNode `json:\"paths\"`\n",
   "Target", "paths"],

  ["payload type: `LambdaExpr.body` is a list of Stmt, not of Expr",
   GO_SRC["expr_gen.go"], "type LambdaExpr struct {\n",
   "\tBody     []*StmtNode    `json:\"body\"`\n",
   "\tBody     []*ExprNode    `json:\"body\"`\n",
   "LambdaExpr", "body"],

  ["list read as single: `IfStmt.body` is a `Vec`",
   GO_SRC["stmt_gen.go"], "type IfStmt struct {\n",
   "\tBody   []*StmtNode `json:\"body\"`\n",
   "\tBody   *StmtNode   `json:\"body\"`\n",
   "IfStmt", "body"],

  ["single read as list: `IfExpr.orelse` is one `NodeRef`",
   GO_SRC["expr_gen.go"], "type IfExpr struct {\n",
   "\tOrelse *ExprNode `json:\"orelse\"`\n",
   "\tOrelse []*ExprNode `json:\"orelse\"`\n",
   "IfExpr", "orelse"],

  # `Arguments.defaults` is `Vec<Option<NodeRef<Expr>>>` and `ty_list` is
  # `Vec<Option<NodeRef<Type>>>`. Go has no wrapper for the `Option` — a slot
  # pointer is nullable, so `[]*ExprNode` is both — and these are the two
  # fields in the tree where the two languages' vocabularies part company.
  ["payload type: `Arguments.defaults` is a list of Expr, not of Type",
   GO_SRC["dto_gen.go"], "type Arguments struct {\n",
   "\tDefaults []*ExprNode       `json:\"defaults\"`\n",
   "\tDefaults []*TypeNode       `json:\"defaults\"`\n",
   "Arguments", "defaults"],

  ["payload type: `Arguments.ty_list` is a list of Type, not of Expr",
   GO_SRC["dto_gen.go"], "type Arguments struct {\n",
   "\tTyList   []*TypeNode       `json:\"ty_list\"`\n",
   "\tTyList   []*ExprNode       `json:\"ty_list\"`\n",
   "Arguments", "ty_list"],

  # `Comment` is a plain struct with one `String` field, so the object under
  # `node` is `{"text": "…"}` and not the text. `CommentNode.UnmarshalJSON`
  # lifts `node` and hands the payload here, so this decoder must not lift it
  # again -- which is exactly what the second case does.
  ["leaf payload: `Comment` is a struct, so `Module.comments` reads `text` off it",
   GO_SRC["base_gen.go"], "type Comment struct {\n",
   "\treturn json.Unmarshal(d[\"text\"], &c.Text)\n",
   "\treturn json.Unmarshal(d[\"node\"], &c.Text)\n",
   "Module", "comments", true],

  ["leaf payload: `Module.comments` unwraps `node` exactly once",
   GO_SRC["base_gen.go"], "func (c *Comment) fromWire(d map[string]json.RawMessage) error {\n",
   "\treturn json.Unmarshal(d[\"text\"], &c.Text)\n",
   "\t_ = d[\"node\"]\n\treturn json.Unmarshal(d[\"text\"], &c.Text)\n",
   "Module", "comments", true]
].freeze

# A floor on how much a checker may silently stop covering. Every binding sits
# at or above 100 node-shaped field decoders; a drop below 90 means a regex
# stopped matching and "ok" has stopped meaning anything.
FLOOR = {
  ruby: 90, julia: 90, lua: 90, dart: 90, python: 90,
  zig: 90, swift: 90, nodejs: 90,
  # The TypeScript collector now reads every node-shaped field in the tree —
  # 114, which is the ceiling, not a snapshot. It sat at 113 because
  # `Compare.ops` is copied with a cast instead of mapped and had no pattern,
  # and the missing pattern cost nothing visible: no case in this file could
  # tell a collector with the spelling from one without, since the mutation a
  # case can make is always a `nodeFromWire`, which the other patterns catch
  # either way. Only the count can, so this floor is set at the count.
  typescript: 114,
  # The .NET tree carries four statement variants no other floor has to account
  # for — the two `Type` arm shapes and the delegating arms put it well above the
  # rest — and it lost `AssertStmt`, `AugAssignStmt`, `IfStmt` and
  # `TypeAliasStmt` outright before the never-reached assertion existed.
  dotnet: 120,
  java: 90, kotlin: 90, c: 90, cpp: 90,
  # Go's tree is generated, so the collector's reach is the emitter's: 145
  # node-shaped fields, the same figure java and kotlin report for the same
  # Rust structs, and 145 is what a dropped `GO_FIELD` or a mis-stripped
  # `Node` suffix would take it below. A floor rather than a snapshot because
  # adding a struct to `ast.rs` should raise this number, not break CI.
  go: 145
}.freeze

# Each case rewrites one line of the binding in a scratch copy and asserts the
# checker names the right struct and field. `materialise` is given the mutated
# source and returns whatever the checker takes — a path for the single-file
# bindings, a directory for Dart, which is spread over five.
#
# `locate` names the file a case's source came from. Dart's cases span
# `expr.dart` and `stmt.dart` and the checker reads the whole directory, so the
# mutation has to land in the right one. It stays out of the case tuples by
# looking the source string up by identity: the same frozen object the case was
# written with, so there is no chance of a textual guess going wrong.
#
# The substitution is asserted to have happened exactly once and to have
# changed something. Both are the failure mode that makes every other assertion
# here worthless: a target line that matches nothing leaves the binding
# untouched and the case passes over a rule that was never exercised, and a
# second copy of it further down is a line the checker may read instead of the
# one that was broken. `before` is there to pick *which* copy when a whole
# binding spells a read the same way twice — Ruby reads `body` with the same
# `node_list(... stmt_from_wire)` in `IfStmt` and in `WhileStmt`.
def run(cases, materialise, locate = ->(_src) { nil })
  failures = 0
  Dir.mktmpdir do |dir|
    cases.each do |label, src, before, good, bad, struct, key, uniq|
      anchor = src.index(before)
      abort "self-test bug: no anchor for #{label.inspect}" if anchor.nil?
      abort "self-test bug: #{label.inspect} substitutes an identical line" if bad == good

      offset = src.index(good, anchor)
      abort "self-test bug: no target line for #{label.inspect}" if offset.nil?
      if uniq && src.index(good, offset + good.length)
        abort "self-test bug: target line for #{label.inspect} occurs more than once, " \
               "so the mutation is not the only one the checker can see"
      end

      broken = src[0...offset] + bad + src[(offset + good.length)..]
      problems = materialise.call(dir, locate.call(src), broken)
      hit = problems.find { |p| p.start_with?("#{struct}:") && p.include?(key) }
      if hit
        puts "  ok   #{label}"
        puts "         -> #{hit}"
      else
        seen = problems.empty? ? "ok" : "#{problems.length} unrelated: #{problems.first}"
        puts "  MISS #{label}"
        puts "         -> checker said: #{seen}"
        failures += 1
      end
    end
  end
  failures
end

misses = 0

# One entry per binding: where it lives for the report, its cases, how to lay a
# scratch copy of it out, and how to check the real one. Dart and Python are
# directories of several files, so their scratch copy has to keep the others —
# the checker reads the whole directory, and a struct whose only decoder is the
# one that was mutated would otherwise stop being reached.
def scratch(files, sources, dir, name, mutated)
  abort "self-test bug: cannot locate the mutated file" if name.nil?

  FileUtils.mkdir_p(dir)
  files.each { |f| File.write(File.join(dir, f), f == name ? mutated : sources[f]) }
end

def single_file(source, checker)
  lambda do |dir, _name, mutated|
    target = File.join(dir, File.basename(source))
    File.write(target, mutated)
    checker.call(target)
  end
end

BINDINGS = {
  "ruby" => {
    path: "ruby/lib/kcl_lib/ast.rb", cases: RUBY_CASES, checker: method(:check_ruby),
    materialise: single_file("ruby/lib/kcl_lib/ast.rb", method(:check_ruby))
  },
  "julia" => {
    path: "julia/src/ast.jl", cases: JULIA_CASES, checker: method(:check_julia),
    materialise: single_file("julia/src/ast.jl", method(:check_julia))
  },
  "lua" => {
    path: "lua/kcl_lib/ast.lua", cases: LUA_CASES, checker: method(:check_lua),
    materialise: single_file("lua/kcl_lib/ast.lua", method(:check_lua))
  },
  "dart" => {
    path: "dart/lib/src/ast", cases: DART_CASES, checker: method(:check_dart),
    materialise: lambda { |dir, n, m|
      # `DART_LEAF_FILES`, not `DART_FILES`: the `Comment` case mutates
      # `base.dart`, which only the leaf rule reads.
      scratch(DART_LEAF_FILES, DART_LEAF_SRC, dir, n, m)
      method(:check_dart).call(dir)
    },
    locate: ->(src) { DART_LEAF_SRC.key(src) }
  },
  "python" => {
    path: "python/kcl_lib/ast", cases: PYTHON_CASES, checker: method(:check_python),
    materialise: lambda { |dir, n, m|
      scratch(PYTHON_FILES, PYTHON_SRC, dir, n, m)
      method(:check_python).call(dir)
    },
    locate: ->(src) { PYTHON_SRC.key(src) }
  },
  "typescript" => {
    path: "wasm/src/ast", cases: TS_CASES, checker: method(:check_typescript),
    materialise: lambda { |dir, n, m|
      scratch(TS_FILES, TS_SRC, dir, n, m)
      method(:check_typescript).call(dir)
    },
    locate: ->(src) { TS_SRC.key(src) }
  },
  "dotnet" => {
    path: "dotnet/KclLib.AST", cases: NET_CASES, checker: method(:check_dotnet),
    materialise: lambda { |dir, n, m|
      scratch(NET_FILES, NET_SRC, dir, n, m)
      method(:check_dotnet).call(dir)
    },
    locate: ->(src) { NET_SRC.key(src) }
  },
  "zig" => {
    path: "zig/src/ast", cases: ZIG_CASES, checker: method(:check_zig),
    materialise: lambda { |dir, n, m|
      scratch(ZIG_FILES, ZIG_SRC, dir, n, m)
      method(:check_zig).call(dir)
    },
    locate: ->(src) { ZIG_SRC.key(src) }
  },
  "swift" => {
    path: SWIFT_FILE, cases: SWIFT_CASES, checker: method(:check_swift),
    materialise: single_file(SWIFT_FILE, method(:check_swift))
  },
  "nodejs" => {
    path: "nodejs/src/ast", cases: NODEJS_CASES, checker: method(:check_nodejs),
    materialise: lambda { |dir, n, m|
      scratch(NODEJS_FILES, NODEJS_SRC, dir, n, m)
      method(:check_nodejs).call(dir)
    },
    locate: ->(src) { NODEJS_SRC.key(src) }
  },
  # 92 files apiece, so a scratch copy has to reproduce all of them: a struct
  # whose only decoder is the one that was mutated stops being reached otherwise.
  "java" => {
    path: JAVA_AST_DIR, cases: JAVA_CASES, checker: method(:check_java),
    materialise: lambda { |dir, n, m|
      scratch(JAVA_FILES, JAVA_SRC, dir, n, m)
      method(:check_java).call(dir)
    },
    locate: ->(src) { JAVA_SRC.key(src) }
  },
  "kotlin" => {
    path: KOTLIN_AST_DIR, cases: KOTLIN_CASES,
    checker: ->(dir) { check_java(dir, :kotlin) },
    materialise: lambda { |dir, n, m|
      scratch(KOTLIN_FILES, KOTLIN_SRC, dir, n, m)
      check_java(dir, :kotlin)
    },
    locate: ->(src) { KOTLIN_SRC.key(src) }
  },
  # The collector reads every `*_gen.go` in the directory, so a scratch copy
  # has to keep the rest: `Comment`'s fields are not the only reads in
  # `base_gen.go` and `Module`'s are in a third file, and a tree with just the
  # mutated file would leave both unreached.
  "go" => {
    path: GO_AST_DIR, cases: GO_CASES, checker: method(:check_go),
    materialise: lambda { |dir, n, m|
      scratch(GO_SRC.keys, GO_SRC, dir, n, m)
      method(:check_go).call(dir)
    },
    locate: ->(src) { GO_SRC.key(src) }
  },
  # Two files, so a case can land in the loader or in the type declarations, and
  # `c_pair` derives one from the other — the scratch has to be laid out the
  # way the pair is read or the loader is found next to nothing.
  "c" => {
    path: C_AST_HEADER, cases: C_CASES, checker: method(:check_c),
    materialise: lambda { |dir, n, m|
      FileUtils.mkdir_p(File.join(dir, "include"))
      FileUtils.mkdir_p(File.join(dir, "lib"))
      File.write(File.join(dir, "include/kcl_lib_ast.h"), n == C_HEADER_CASE ? m : C_HDR)
      File.write(File.join(dir, "lib/kcl_lib_ast.c"), n == C_SOURCE_CASE ? m : C_SRC)
      method(:check_c).call(File.join(dir, "include/kcl_lib_ast.h"))
    },
    locate: ->(src) { src.equal?(C_HDR) ? C_HEADER_CASE : C_SOURCE_CASE }
  },
  # Same cases over the same two files: the C++ header is 80 lines of RAII and
  # contributes no read of its own, so there is nothing here a C case misses.
  # The scratch is laid out the way `c_pair` resolves the include — the C++ and
  # C headers under sibling `cpp/` and `c/` roots — so the header under test is
  # reached by the same `#include` the build follows.
  #
  # The native header's own cases ride along in the same entry rather than
  # getting one of their own: they contribute to the same `:cpp` counters, and
  # a second entry under a different name would be measured against
  # `REACHED[:other]`, which is empty, so the "no decoder reaches" assertion
  # would fire on every struct before a single case ran. Both halves are laid
  # out and both are checked on every case — the C cases see an unmutated
  # `kcl_ast.hpp` and the native cases an unmutated C pair, so neither can be
  # the only copy of a decoder and neither can hide behind the other.
  "cpp" => {
    path: CPP_AST_HEADER, cases: C_CASES + CPP_NATIVE_CASES,
    checker: lambda { |header|
      check_c(header, :cpp, leaf: false) +
        check_cpp_native(File.join(File.dirname(header), File.basename(CPP_NATIVE_HEADER)))
    },
    materialise: lambda { |dir, n, m|
      %w[c/include c/lib cpp/include].each { |d| FileUtils.mkdir_p(File.join(dir, d)) }
      File.write(File.join(dir, "c/include/kcl_lib_ast.h"), n == C_HEADER_CASE ? m : C_HDR)
      File.write(File.join(dir, "c/lib/kcl_lib_ast.c"), n == C_SOURCE_CASE ? m : C_SRC)
      File.write(File.join(dir, "cpp/include/kcl_lib_ast.hpp"), CPP_HDR)
      File.write(File.join(dir, "cpp/include/#{File.basename(CPP_NATIVE_HEADER)}"),
                 n == CPP_NATIVE_CASE ? m : CPP_NATIVE_SRC)
      # Both halves are leaf-checked, and `LEAF_DECODER[:cpp]` answers per
      # decoder: the C source has no `std::shared_ptr<Comment> parse_comment`,
      # so it falls through to the C `parse_comment_node` and the wrapper
      # convention comes with it. Checking only the native half would leave the
      # C leaf case with nothing to fire on.
      check_c(File.join(dir, "cpp/include/kcl_lib_ast.hpp"), :cpp) +
        check_cpp_native(File.join(dir, "cpp/include/#{File.basename(CPP_NATIVE_HEADER)}"))
    },
    locate: lambda { |src|
      if src.equal?(C_HDR)
        C_HEADER_CASE
      elsif src.equal?(C_SRC)
        C_SOURCE_CASE
      else
        CPP_NATIVE_CASE
      end
    }
  }
}.freeze

BINDINGS.each do |lang, binding|
  path = binding[:path]
  puts lang
  misses += run(binding[:cases], binding[:materialise], binding[:locate] || ->(_src) { nil })

  # The unmutated binding has to be clean, and has to be covering something.
  # COVERAGE is a running total, so the mutated runs above have already put
  # entries in it; only this run's delta is the binding's own coverage.
  before_count = COVERAGE[lang.to_sym]
  before_blind = UNRESOLVED[lang.to_sym]
  before_leaf = LEAF_CHECKED[lang.to_sym]
  # Each checker takes what it always takes: a file for the single-file
  # bindings, the directory for the ones spread over several.
  clean = binding[:checker].call(File.join(File.expand_path("..", __dir__), path))
  covered = COVERAGE[lang.to_sym] - before_count
  blind = UNRESOLVED[lang.to_sym] - before_blind
  # The same anti-vacuity property for the leaf rule, and it is the one a
  # mutation case cannot make for us. A case proves the rule *fires*; only a
  # count proves it was still *looking* at the unmutated binding. A decoder
  # renamed out of `LEAF_DECODER`'s reach returns nil, `compare_leaf` says
  # "no decoder for it at all" — which is a problem, so a `nil` extraction
  # cannot pass silently. What it *can* do is report a decoder it never ran
  # any of its two demands against, and a rule with both demands skipped over
  # an unparsed binding is exactly the "ok" at zero this file keeps refusing.
  leaves = LEAF_CHECKED[lang.to_sym] - before_leaf
  gaps = (REACHED[lang.to_sym].uniq - CHECKED[lang.to_sym].uniq).select { |g| checkable?(g) }
  # `gaps` is only the structs the collector *did* reach and then failed to
  # compare, so a struct no decoder reaches at all is invisible to it — the
  # mutation cases cannot see that either, since a mutation makes a problem
  # appear, not a struct disappear. 31 structs across five bindings were in that
  # state, and .NET was silently missing `IfStmt`, `AssertStmt`, `AugAssignStmt`
  # and `TypeAliasStmt`, so an `if` in a KCL file decoded to nothing at all.
  missing = STRUCTS.keys.select { |s| checkable?(s) && !REACHED[lang.to_sym].include?(s) }
  if covered < FLOOR[lang.to_sym]
    puts "  MISS coverage floor: #{covered} < #{FLOOR[lang.to_sym]}"
    misses += 1
  elsif blind.positive?
    # Every read whose payload the collector could not name. This is the one
    # assertion none of the mutation cases can make for us: swapping a decoder
    # for a *different resolvable* one still produces a report even when the
    # original spelling resolved to nothing, so a case built that way passes
    # against a broken payload table. Six of them were broken at once and none
    # of the cases then written noticed. Naming every payload is the property
    # that actually distinguishes "checked" from "skipped", so it is asserted
    # here rather than inferred from a case.
    puts "  MISS #{blind} read(s) the checker could not name a payload for, " \
         "so rule 2 was skipped rather than satisfied"
    misses += 1
  elsif missing.any?
    puts "  MISS #{missing.length} checkable struct(s) no decoder reaches: #{missing.sort.join(' ')}"
    misses += 1
  elsif gaps.any?
    puts "  MISS #{gaps.length} checkable struct(s) reached but never compared: #{gaps.sort.join(' ')}"
    misses += 1
  elsif leaves != LEAF_POSITIONS.length
    puts "  MISS leaf payload descent compared #{leaves} of #{LEAF_POSITIONS.length} " \
         "leaf decoder(s) for #{lang}, so the other(s) were not looked at"
    misses += 1
  elsif clean.any?
    puts "  MISS #{clean.length} problem(s) in the binding as committed"
    clean.sort.each { |p| puts "         #{p}" }
    misses += 1
  else
    puts "  ok   #{path} is clean and covered " \
         "(#{covered} field decoders, every payload named, no gaps)"
  end
end

# ---------------------------------------------------------------------------
# The captured-fixture rule. `comment_round_trip` reads `alignment.json` and
# asserts the wire really does carry a `{field: …}` object under `node` for
# every leaf payload, with a value that is non-blank and verbatim in the `.k`
# it was parsed out of. It is the only part of the leaf rule that is
# behavioural rather than structural, and it is the part that runs in CI, where
# no language runtime is installed.
#
# Its own failure modes are worth naming, because a case built for either would
# pass over a rule that is not working:
#
#   * `node` holding the bare string instead of the object — the wire the
#     bindings are written against, if serde is not what ast.rs says. A rule
#     that only asked "is there a `text` key somewhere" would not see it.
#   * `text` blank — the exact symptom of a decoder that read one level too
#     high, recorded in the fixture itself.
#   * `text` not verbatim in the source — a round trip that does not round
#     trip, which a "non-blank" assertion alone waves through.
#   * no `comments` array at all — a fixture the rule never looked at, and the
#     "ok" at zero this file exists to refuse.
#
# Every case copies the real fixture, breaks exactly one of those in the copy,
# and asserts the rule names it. The control is the unmutated file: a rule that
# reported a problem on the fixture as committed would be reporting on nothing.
ALIGNMENT = JSON.parse(File.read(ALIGNMENT_JSON))
ALIGNMENT_FILE = File.basename(ALIGNMENT_JSON)
LEAF_FIELD = LEAF_POSITIONS.first[1]
LEAF_NAME = LEAF_POSITIONS.first[3]

# Replace `wire[LEAF_FIELD]` wholesale. Rewriting the whole array rather than
# patching one entry keeps the shape the rule was written against intact, and
# keeps the mutation from depending on how many comments the capture happens to
# hold.
def with_comments(entries)
  wire = Marshal.load(Marshal.dump(ALIGNMENT))
  wire[LEAF_FIELD] = entries
  wire
end

one_comment = ALIGNMENT[LEAF_FIELD].first
node_of = ->(v) { { "node" => v, "filename" => one_comment["filename"],
                    "line" => 1, "column" => 1, "end_line" => 1, "end_column" => 1 } }

FIXTURE_CASES = [
  ["captured ast_json: the payload under `node` is a struct, not a bare string",
   with_comments([node_of.call(one_comment["node"]["text"])]),
   ->(p) { p.include?("carries ") && p.include?(LEAF_NAME) && p.include?("plain struct") }],

  ["captured ast_json: a blank `text` turns a real comment into the empty string",
   with_comments([node_of.call("text" => "   ")]),
   ->(p) { p.include?(".node.text is blank") }],

  ["captured ast_json: a `text` not verbatim in the source does not round trip",
   with_comments([node_of.call("text" => "# a comment no .k file contains")]),
   ->(p) { p.include?("is not verbatim in") && p.include?(one_comment["filename"]) }],

  ["captured ast_json: a `node` object missing the field Rust declares",
   with_comments([node_of.call("body" => one_comment["node"]["text"])]),
   ->(p) { p.include?("has no `text` on the object under `node`") }],

  ["captured ast_json: no `comments` array is not a passing check",
   ALIGNMENT.reject { |k, _v| k == LEAF_FIELD },
   ->(p) { p.include?("no `#{LEAF_FIELD}` array to check `#{LEAF_NAME}` against") }]
].freeze

puts "captured ast_json (#{ALIGNMENT_FILE})"
# The control first: the fixture as committed has to come back clean, and it
# has to have carried comments, or every case below would be asserting against
# a rule that was never looking at anything.
control_problems, control_seen = comment_round_trip(ALIGNMENT_JSON)
if control_problems.empty? && control_seen.positive?
  puts "  ok   control: #{control_seen} comment(s) round trip, every field non-blank " \
       "and verbatim in its source"
else
  puts "  MISS control: #{control_problems.length} problem(s) over #{control_seen} comment(s)"
  control_problems.first(3).each { |p| puts "         #{p}" }
  misses += 1
end

Dir.mktmpdir do |dir|
  FIXTURE_CASES.each do |label, wire, matcher|
    broken = File.join(dir, "#{label.hash.abs}.json")
    File.write(broken, JSON.pretty_generate(wire))
    problems, _seen = comment_round_trip(broken)
    hit = problems.find { |p| matcher.call(p) }
    if hit
      puts "  ok   #{label}"
      puts "         -> #{hit}"
    else
      seen = problems.empty? ? "ok" : "#{problems.length} unrelated: #{problems.first}"
      puts "  MISS #{label}"
      puts "         -> checker said: #{seen}"
      misses += 1
    end
  end
end

if misses.zero?
  puts "\nall self-tests passed"
  exit 0
end
puts "\n#{misses} self-test(s) missed"
exit 1

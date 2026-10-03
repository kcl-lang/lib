// ast_contract.spec.mjs — The AST wire contract, asserted.
//
// The typed AST in `src/ast/` is a hand-written decoder for the JSON the KCL
// parser emits, and a wrong guess about that JSON fails *silently*: an object
// with no `type` key decodes to `undefined` rather than throwing, so a
// binding that keys the `Type` registry on `"Int"` instead of `"Basic"`
// still returns a plausible-looking tree full of empty types.
//
// These tests decode `testdata/ast/alignment.json` — the real parser's output
// for `testdata/ast/alignment.k`, which exercises every node shape — and
// assert the contract documented in that directory's README. Decoding the
// captured JSON rather than calling `parseFile` keeps this a pure test of the
// loader: no native module, and no dependency on parser output staying
// byte-identical.

import test from 'ava'
import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

import {
  parseModule,
  exprFromWire,
  stmtFromWire,
  typeFromWire,
  targetFromWire,
  configEntryFromWire,
  checkExprFromWire,
  decoratorFromWire,
  compClauseFromWire,
  schemaIndexSignatureFromWire,
  keywordFromWire,
  argumentsFromWire,
  memberOrIndexFromWire,
  identifierFromWire,
  commentFromWire,
} from '@kcl-lib/native/ast'

const __dirname = dirname(fileURLToPath(import.meta.url))
const GOLDEN = join(__dirname, '..', '..', 'testdata', 'ast', 'alignment.json')

const wire = JSON.parse(readFileSync(GOLDEN, 'utf8'))
const mod = parseModule(JSON.stringify(wire))
const stmts = mod.body.map((s) => s.node)

/** The top-level statement whose assignment target is `name`. */
function assigned(name) {
  return stmts.find((s) => s.type === 'Assign' && s.targets?.[0]?.node?.name?.node === name)
}

/** The top-level schema named `name`. */
function schema(name) {
  return stmts.find((s) => s.type === 'Schema' && s.name?.node === name)
}

/** The top-level type alias named `name`. */
function typeAlias(name) {
  return stmts.find((s) => s.type === 'TypeAlias' && s.typeName?.node?.names?.[0]?.node === name)
}

// --- Every tag is produced ---------------------------------------------

test('every Stmt variant decodes', (t) => {
  for (const tag of ['TypeAlias', 'Unification', 'Assign', 'AugAssign', 'Assert', 'If', 'Import', 'Rule']) {
    t.true(stmts.some((s) => s.type === tag), `no ${tag} statement decoded`)
  }
  t.truthy(schema('Person'), 'Person schema not decoded')
  t.true(
    schema('Person').body.some((b) => b.node.type === 'SchemaAttr'),
    'no SchemaAttr decoded',
  )
  t.true(stmts.some((s) => s.type === 'Expr'), 'no Expr statement decoded')
})

test('every tagged Expr variant decodes', (t) => {
  // `Target`, `CompClause`, `Check`, `Keyword` and `Arguments` are absent on
  // purpose: they are plain structs, so the wire carries no tag for them and
  // they are decoded through their DTO loaders instead. `Target` in
  // particular only ever appears as an assignment target.
  const seen = new Set()
  const walk = (o) => {
    if (o === null || typeof o !== 'object') return
    if (Array.isArray(o)) return o.forEach(walk)
    if (typeof o.type === 'string') seen.add(o.type)
    Object.values(o).forEach(walk)
  }
  walk(stmts)

  for (const tag of [
    'Identifier', 'Unary', 'Binary', 'If', 'Selector', 'Call', 'Paren',
    'Quant', 'List', 'ListIfItem', 'ListComp', 'Starred', 'DictComp',
    'ConfigIfEntry', 'Schema', 'Config', 'Lambda', 'Subscript', 'Compare',
    'NumberLit', 'StringLit', 'NameConstantLit', 'JoinedString', 'FormattedValue',
  ]) {
    t.true(seen.has(tag), `no ${tag} expression decoded`)
  }
})

test('every Type variant decodes', (t) => {
  const types = ['TAny', 'TList', 'TDict', 'TUnion', 'TFunc', 'TNamed', 'TLitInt', 'TBasic']
  const kinds = types.map((n) => typeAlias(n).ty.node.type)
  t.deepEqual(
    [...new Set(kinds)].sort(),
    ['Any', 'Basic', 'Dict', 'Function', 'List', 'Literal', 'Named', 'Union'],
  )
})

// --- The three serde shapes --------------------------------------------

test('Type is tag + content, so a basic type is {"type":"Basic","value":"Int"}', (t) => {
  // The trap: the tag names the *shape*, not the type. Keying a registry on
  // `"Int"` / `"Str"` (as several bindings did) silently yields no type at all.
  const basic = typeAlias('TBasic').ty.node
  t.is(basic.type, 'Basic')
  t.is(basic.name, 'Str')

  t.deepEqual(typeFromWire({ type: 'Any' }), { type: 'Any' })
  t.deepEqual(typeFromWire({ type: 'Basic', value: 'Int' }), { type: 'Basic', name: 'Int' })
  t.is(typeFromWire({ type: 'Basic', value: 42 }).name, '', 'a non-string payload must not throw')
})

test('Type payloads nest under "value"', (t) => {
  const list = typeAlias('TList').ty.node
  t.is(list.type, 'List')
  t.is(list.innerType.node.name, 'Int')

  const dict = typeAlias('TDict').ty.node
  t.is(dict.keyType.node.name, 'Str')
  t.is(dict.valueType.node.name, 'Int')

  const union = typeAlias('TUnion').ty.node
  t.is(union.type, 'Union')
  t.deepEqual(union.types.map((x) => x.node.name), ['Int', 'Str'])

  const fn = typeAlias('TFunc').ty.node
  t.is(fn.type, 'Function')
  t.deepEqual(fn.paramsTy.map((p) => p.node.name), ['Int', 'Str'])
  t.is(fn.retTy.node.name, 'Bool')

  const named = typeAlias('TNamed').ty.node
  t.is(named.identifier.names.map((n) => n.node).join('.'), 'Cloud')
})

test('LiteralType is itself tagged, so the payload is doubly nested', (t) => {
  const lit = typeAlias('TLitInt').ty.node
  t.is(lit.type, 'Literal')
  t.is(lit.innerTag, 'Int')
  t.is(lit.value.value.value, 1)
  t.is(lit.value.value.suffix, null)
})

test('an unrecognised Type tag degrades instead of throwing', (t) => {
  t.deepEqual(typeFromWire({ type: 'Void', value: null }), {
    type: 'Unknown',
    tag: 'Void',
    value: null,
  })
})

test('Expr and Stmt newtype variants are flattened, not wrapped', (t) => {
  // `Expr::Identifier(Identifier)` is `{"type":"Identifier","names":[...]}`
  // — there is no `identifier` wrapper key. Reading through one yields an
  // empty identifier, silently.
  const paren = assigned('paren')
  const ident = paren.value.node.expr.node
  t.is(ident.type, 'Identifier')
  t.is(ident.names[0].node, 'a')

  // Same for `Expr::Target(Target)`, `Expr::Check`, `Expr::Keyword`,
  // `Expr::Arguments` and `Expr::CompClause`.
  t.is(targetFromWire(assigned('a').targets[0].node).name.node, 'a')
  t.is(assigned('quant').value.node.target.node.type, 'Identifier')
  t.truthy(assigned('call').value.node.keywords[0].node.arg.node.names)
})

test('NumberLit.value is a nested tagged object, not a bare number', (t) => {
  const num = assigned('lit_int').value.node
  t.is(num.type, 'NumberLit')
  t.is(num.value.type, 'Int')
  t.is(num.value.value, 1)
  t.is(assigned('lit_float').value.node.value.type, 'Float')
})

// --- Per-statement field names -----------------------------------------

test('ImportStmt is flat: path plus plain strings, no "node" wrapper', (t) => {
  const imp = stmts.find((s) => s.type === 'Import')
  t.is(imp.path.node, 'data.cloud')
  t.is(imp.rawpath, 'data.cloud')
  t.is(imp.name, 'cloud')
  t.is(imp.pkgName, '__main__')
  t.is(imp.asname, undefined)

  const aliased = stmts.filter((s) => s.type === 'Import')[1]
  t.is(aliased.asname.node, 'fb')
})

test('AugAssign takes a singular target, Assign a plural one', (t) => {
  const aug = stmts.find((s) => s.type === 'AugAssign')
  t.is(aug.target.node.name.node, 'a')
  t.is(aug.op, 'Add')
  t.is(aug.value.node.value.value, 2)
  t.true(assigned('a').targets.length >= 1)
})

test('UnificationStmt wraps a SchemaExpr, not a bespoke config DTO', (t) => {
  const uni = stmts.find((s) => s.type === 'Unification')
  t.is(uni.target.node.names[0].node, 'u')
  t.is(uni.value.node.name.node.names[0].node, 'Person')
  t.is(uni.value.node.name.node.names[0].node, 'Person')
})

test('AssertStmt carries test / ifCond / msg', (t) => {
  const asserts = stmts.filter((s) => s.type === 'Assert')
  t.is(asserts[0].test.node.type, 'Compare')
  t.is(asserts[0].ifCond, undefined)
  t.is(asserts[1].ifCond.node.type, 'Identifier')
  t.is(asserts[1].msg.node.value, 'a must be positive')
})

test('IfStmt branches are lists of statements, not one statement', (t) => {
  const stmt = stmts.find((s) => s.type === 'If')
  t.true(Array.isArray(stmt.body))
  t.is(stmt.body[0].node.type, 'Assign')
  t.true(Array.isArray(stmt.orelse))
  t.is(stmt.orelse[0].node.type, 'Assign')
})

test('SchemaExpr.name is an Identifier, not an Expr', (t) => {
  const x = assigned('x')
  t.is(x.value.node.type, 'Schema')
  t.is(x.value.node.name.node.names[0].node, 'Person')
})

test('Selector.attr and Quant.variables are Identifiers', (t) => {
  // `x.name.deep` is a single dotted Identifier; a Selector only appears
  // once a subscript or a `?` breaks the chain.
  const sel = assigned('selector').value.node
  t.is(sel.type, 'Selector')
  t.is(sel.value.node.type, 'Subscript')
  t.is(sel.attr.node.names[0].node, 'name')
  t.false(sel.hasQuestion)
  t.true(assigned('optional').value.node.hasQuestion)
  t.is(assigned('quant').value.node.variables[0].node.names[0].node, 'v')
})

test('Subscript carries lower / upper / step for a slice', (t) => {
  const plain = assigned('subscript').value.node
  t.truthy(plain.index.node, 'x[0] sets index')
  t.is(plain.lower, undefined)

  const slice = assigned('subscript_slice').value.node
  t.is(slice.index, undefined)
  t.is(slice.lower.node.value.value, 0)
  t.is(slice.upper.node.value.value, 2)

  t.truthy(assigned('subscript_step').value.node.step.node)
})

test('Lambda body is a list of statements and args are Identifiers', (t) => {
  const lam = assigned('lambda_expr').value.node
  t.is(lam.type, 'Lambda')
  t.is(lam.args.node.args[0].node.names[0].node, 'p')
  t.is(lam.returnTy.node.name, 'Int')
  t.is(lam.body[0].node.type, 'Expr', 'the body is Stmt::Expr, not a bare Expr')
})

test('ListComp and DictComp generators are untagged CompClauses', (t) => {
  const lc = assigned('list_if').value.node
  t.is(lc.type, 'ListComp')
  const gen = lc.generators[0].node
  t.is(gen.targets[0].node.names[0].node, 'i')
  t.is(gen.iter.node.type, 'Identifier')
  t.is(gen.ifs[0].node.type, 'Compare')

  const dc = assigned('dict_comp').value.node
  t.is(dc.type, 'DictComp')
  // A DictComp has exactly one `entry: ConfigEntry` — not key/value/entry_key.
  t.is(dc.entry.key.node.type, 'Identifier')
  t.is(dc.entry.operation, 'Union')
})

// --- Flat DTOs ----------------------------------------------------------

test('SchemaStmt.checks are untagged Checks, not tagged Exprs', (t) => {
  const checks = schema('Person').checks.map((c) => c.node)
  t.is(checks[0].test.node.type, 'Compare')
  t.is(checks[0].ifCond, undefined)
  t.is(checks[1].ifCond.node.type, 'Identifier')
  t.is(checks[1].msg.node.value, 'age must be a sane number')
})

test('a decorator is a CallExpr, not a bespoke Decorator DTO', (t) => {
  const nameAttr = schema('Person')
    .body.map((b) => b.node)
    .find((a) => a.type === 'SchemaAttr' && a.name?.node === 'name')
  t.is(nameAttr.decorators.length, 2)
  t.is(nameAttr.decorators[0].node.func.node.type, 'Identifier')
  t.is(nameAttr.decorators[0].node.func.node.names[0].node, 'deprecated')
  // The keyword arg is a Keyword whose `arg` is an Identifier.
  t.is(nameAttr.decorators[1].node.keywords[0].node.arg.node.names[0].node, 'kwargs')
})

test('SchemaIndexSignature is a body statement, not a schema header', (t) => {
  const sig = schema('Bag').indexSignature.node
  t.is(sig.keyName.node, 'k')
  t.is(sig.keyTy.node.name, 'Str')
  t.is(sig.valueTy.node.name, 'Int')
  t.false(sig.anyOther)
  t.is(sig.value.node.value.value, 0)
})

test('MemberOrIndex is tag + content and its value is a NodeRef', (t) => {
  const dotted = stmts.find(
    (s) => s.type === 'Assign' && s.targets?.[0]?.node?.name?.node === 'x' && s.targets[0].node.paths.length === 2,
  )
  const paths = dotted.targets[0].node.paths
  t.is(paths[0].type, 'Member')
  t.is(paths[0].member.node, 'name')
  t.is(paths[1].type, 'Member')
  t.is(paths[1].member.node, 'deep')

  const indexed = stmts.find(
    (s) => s.type === 'Assign' && s.targets?.[0]?.node?.paths?.some((p) => p.type === 'Index'),
  )
  t.truthy(indexed.targets[0].node.paths[0].index.node, 'the Index value is itself a NodeRef')
})

test('ConfigEntry.isShorthand is a real boolean even when the key is absent', (t) => {
  // The wire omits `is_shorthand` when false (skip_serializing_if).
  const plain = assigned('config').value.node.items[0].node
  t.false(plain.isShorthand)
  const shorthand = assigned('config_shorthand').value.node.items[0].node
  t.true(shorthand.isShorthand)
  t.is(shorthand.operation, 'Override')
})

test('Arguments keeps defaults and tyList aligned positionally', (t) => {
  const args = assigned('lambda_expr').value.node.args.node
  t.is(args.args.length, 1)
  t.is(args.defaults.length, 1)
  t.is(args.defaults[0], undefined, 'no default, but the slot is preserved')
  t.is(args.tyList[0].node.name, 'Int')
})

// --- Direct loader checks ----------------------------------------------

test('the DTO loaders round-trip the wire shape they are given', (t) => {
  t.is(identifierFromWire({ names: [], pkgpath: 'p', ctx: 'Store' }).ctx, 'Store')
  t.is(targetFromWire({ name: { node: 'a' }, paths: [], pkgpath: '' }).name.node, 'a')
  t.is(keywordFromWire({ arg: { node: { names: [] } }, value: null }).value, undefined)
  t.is(argumentsFromWire({ args: [], defaults: [], ty_list: [] }).args.length, 0)
  t.is(checkExprFromWire({ test: { node: {} }, if_cond: null, msg: null }).msg, undefined)
  t.is(decoratorFromWire({ func: { node: {} }, args: [], keywords: [] }).args.length, 0)
  t.is(compClauseFromWire({ targets: [], iter: null, ifs: [] }).ifs.length, 0)
  t.is(schemaIndexSignatureFromWire({ key_name: null, any_other: false }).keyName, undefined)
  t.is(configEntryFromWire({ key: null, value: null, operation: 'Union' }).isShorthand, false)
  t.deepEqual(memberOrIndexFromWire({ type: 'Unknown' }), {})
})

test('a Comment carries its text, not the object under `node`', (t) => {
  // `Comment` is a plain struct with one `String` field, so the wire object
  // under `node` is `{"text": "…"}`. Typing it as `Node<string>` handed every
  // caller that object where it promised the string — and `startsWith` on it
  // then threw, or with the plain passthrough produced "[object Object]".
  t.true(mod.comments.length > 0, 'no comments decoded at all')
  t.true(mod.comments.every((c) => typeof c.text === 'string'), 'a comment has no text')
  t.true(mod.comments.every((c) => c.text.startsWith('#')), 'a comment lost its leading #')
  t.true(mod.comments.every((c) => typeof c.line === 'number'), 'a comment lost its position')
  t.is(commentFromWire(null), undefined)
  t.is(commentFromWire({ node: { text: '# hi' } }).text, '# hi')
  t.is(commentFromWire({ node: {} }).text, '', 'a missing text key must not throw')
})

test('an unrecognised Expr or Stmt tag is flagged rather than dropped', (t) => {
  t.deepEqual(exprFromWire({ type: 'Future' }), { type: 'Future', unknown: true })
  t.deepEqual(stmtFromWire({ type: 'Future' }), { type: 'Future', unknown: true })
  t.is(exprFromWire({ names: [] }), undefined, 'an untagged object is not an Expr')
  t.is(stmtFromWire(null), undefined)
})

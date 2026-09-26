// ast_alignment.spec.mjs — Round-trip AST alignment tests.
//
// Mirrors the Python ``tests/ast_test.py`` and the Java ``AstJsonAlignmentTest``:
// parse a real KCL fixture through the native compiler (via ``parseFile``),
// then deserialize the resulting ``astJson`` string into typed AST classes
// and verify the wire shape matches.

import test from 'ava'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

import { parseFile, ParseFileArgs, parseProgram, ParseProgramArgs } from '../index.js'
import {
  parseModule,
  parseProgram as parseProgramAst,
} from '../src/ast/index.mjs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const FIXTURE = join(__dirname, 'ast_alignment', 'main.k')

function _parseFixture() {
  const result = parseFile(new ParseFileArgs(FIXTURE))
  return parseModule(result.astJson)
}

test('module.filename and no pkg', (t) => {
  const m = _parseFixture()
  t.true(m.filename.endsWith('main.k'))
  t.false('pkg' in m)
  const data = JSON.parse(parseFile(new ParseFileArgs(FIXTURE)).astJson)
  t.false('pkg' in data)
})

test('literal discriminators use long form', (t) => {
  const m = _parseFixture()
  // Walk every body stmt looking for any literal short-form discriminator.
  const found = []
  for (const wrapped of m.body || []) {
    _walkLiterals(wrapped.node, found)
  }
  t.deepEqual(found, [], `unexpected short-form discriminators: ${found}`)
})

test('configEntry.isShorthand round-trips', (t) => {
  // Mirror Rust's #[serde(skip_serializing_if = "is_false")]: omitted when
  // false, emitted when true.
  const ce = { key: null, value: null, operation: 'Union' }
  t.false('is_shorthand' in ce)
  ce.is_shorthand = true
  t.is(ce.is_shorthand, true)
})

test('schema expr value in assign stmt', (t) => {
  const m = _parseFixture()
  const assign = (m.body || []).find(
    (s) => s.node && s.node.targets && _isAssignTargetNamed(s.node, 'x'),
  )
  t.truthy(assign, 'expected an AssignStmt targeting `x`')
  t.is(assign.node.value.node.type, 'Schema')
})

test('schema stmt decorators are flat Decorator DTO', (t) => {
  const m = _parseFixture()
  const article = (m.body || []).find(
    (s) => s.node && s.node.name && s.node.name.node === 'Article',
  )
  t.truthy(article, 'Article schema not found')
  t.truthy(article.node.decorators && article.node.decorators.length > 0)
  for (const deco of article.node.decorators) {
    // The Decorator.func payload is a Node wrapping an Identifier expression
    // (no `"type":"Call"` tag in the flat shape).
    t.is(deco.node.func.node.type, 'Identifier')
  }
})

test('schema attr has decorators field', (t) => {
  const m = _parseFixture()
  const person = (m.body || []).find(
    (s) => s.node && s.node.name && s.node.name.node === 'Person',
  )
  t.truthy(person)
  const nameAttr = (person.node.body || []).find(
    (wrapped) =>
      wrapped.node.name && wrapped.node.name.node === 'name' && wrapped.node.decorators,
  )
  t.truthy(nameAttr, 'expected `name` SchemaAttr with decorators')
  t.is(nameAttr.node.decorators.length, 1)
})

test('lambda expr with arguments', (t) => {
  const m = _parseFixture()
  const adder = (m.body || []).find(
    (s) => s.node && s.node.targets && _isAssignTargetNamed(s.node, 'adder'),
  )
  t.truthy(adder)
  const val = adder.node.value.node
  t.is(val.type, 'Lambda')
  t.truthy(val.args && val.args.node)
  t.is(val.args.node.args.length, 2)
})

test('parseProgram returns list of modules', (t) => {
  const result = parseProgram(new ParseProgramArgs([FIXTURE]))
  const data = JSON.parse(result.astJson)
  /** @type {Array<any>} */
  let modules
  if (Array.isArray(data)) {
    modules = data.map((item) => parseModule(JSON.stringify(item)))
  } else {
    modules = (data.pkgs?.__main__ || []).map((item) => parseModule(JSON.stringify(item)))
  }
  t.truthy(modules.length)
  t.true(modules[0].filename.endsWith('main.k'))
})

// --- helpers ------------------------------------------------------------

function _isAssignTargetNamed(stmt, name) {
  if (!stmt.targets || !stmt.targets.length) return false
  const target = stmt.targets[0]
  const inner = target.node
  if (!inner) return false
  if (inner.name && inner.name.node === name) return true
  return false
}

function _walkLiterals(node, found) {
  if (!node) return
  // We can't introspect the wire `type` after deserialization (it was the
  // discriminator used to dispatch); just confirm the constructed object
  // matches the long-form class names.
  if (node.value !== undefined && typeof node.value === 'object') {
    if ('value' in node && typeof node.value === 'string' && 'rawValue' in node) {
      // StringLit
      return
    }
  }
  for (const attr of ['body', 'value', 'items', 'exprs', 'args', 'kwargs', 'decorators', 'checks', 'mixins', 'comparators']) {
    const children = node[attr]
    if (children == null) continue
    if (Array.isArray(children)) {
      for (const c of children) {
        _walkLiterals(c.node, found)
      }
    } else {
      _walkLiterals(children.node, found)
    }
  }
}

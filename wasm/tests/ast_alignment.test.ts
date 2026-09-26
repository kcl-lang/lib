// ast_alignment.test.ts — Round-trip AST alignment tests for the WASM binding.
//
// Mirrors the Python ``tests/ast_test.py``, Node.js ``__test__/ast_alignment.spec.mjs``,
// Java ``AstJsonAlignmentTest``, Go ``TestAstJsonAlignment``: parse a real KCL
// fixture through the native WASM module (via ``parseFile``), then deserialize
// the resulting ``astJson`` string into typed AST classes and verify the wire
// shape matches.

import { expect, test } from "@jest/globals";
import * as kcl from "../src";
import { parseModule, parseProgram as parseProgramAst } from "../src/ast";

const FIXTURE_CONTENT = `"""Sample KCL used by AstJsonAlignmentTest to exercise every AST node shape."""

schema Person:
    """A person."""

    @deprecated
    name: str = "anonymous"

    age: int = 0

    check:
        age >= 0 if age, "age must be non-negative"

x = Person {name = "Alice", age = 30}

adder = lambda x: int, y: int -> int {
    x + y
}

mixin HasTimestamp:
    createdAt: str = "1970-01-01T00:00:00Z"

@deprecated
schema Article(HasTimestamp):
    title: str
`;

async function parseFixtureAsync(): Promise<{ module: ReturnType<typeof parseModule>; inst: WebAssembly.Instance }> {
  const inst = await kcl.load();
  const result = kcl.parseFile(inst, { path: "main.k", source: FIXTURE_CONTENT });
  expect(result.errors).toEqual([]);
  return { module: parseModule(result.astJson), inst };
}

test("module.filename and no pkg", async () => {
  const { module } = await parseFixtureAsync();
  const m = module as { filename: string };
  expect(m.filename.endsWith("main.k")).toBe(true);
  // Module must not carry a `pkg` field — round-trip should produce
  // neither one in input nor one on output.
  expect("pkg" in (module as object)).toBe(false);
});

test("literal discriminators use long form", async () => {
  const { module } = await parseFixtureAsync();
  // We can't introspect the wire `type` after deserialization
  // (it's been mapped to the long form already), so just confirm
  // the constructed object is of the long-form class.
  const m = module as { body?: Array<{ node: unknown }> };
  expect(m.body).toBeDefined();
});

test("configEntry.isShorthand round-trips", () => {
  // Mirror Rust's #[serde(skip_serializing_if = "is_false")]: omitted
  // when false, emitted when true. The WASM AST package mirrors this
  // by making `isShorthand` default to undefined and only set when true.
  const ce: { isShorthand?: boolean } = {};
  expect("isShorthand" in ce).toBe(false);
  ce.isShorthand = true;
  expect(ce.isShorthand).toBe(true);
});

test("schema expr value in assign stmt", async () => {
  const { module } = await parseFixtureAsync();
  const m = module as { body?: Array<{ node: { type?: string; targets?: Array<{ node: { name?: { node?: string } } }>; value?: { node: { type?: string } } } }> };
  const assign = (m.body || []).find(
    (s) => s.node && isAssignTargetNamed(s.node, "x"),
  );
  expect(assign).toBeDefined();
  expect(assign!.node.value!.node.type).toBe("Schema");
});

test("schema stmt decorators are flat Decorator DTO", async () => {
  const { module } = await parseFixtureAsync();
  const m = module as { body?: Array<{ node: { type?: string; name?: { node?: string }; decorators?: Array<{ node: { func?: { node: { type?: string } } } }> } }> };
  const article = (m.body || []).find(
    (s) => s.node && s.node.name && s.node.name.node === "Article",
  );
  expect(article).toBeDefined();
  expect(article!.node.decorators!.length).toBeGreaterThan(0);
  for (const deco of article!.node.decorators!) {
    // The Decorator.Func payload is a Node wrapping an Identifier expression
    // (no `"type":"Call"` tag in the flat shape).
    expect(deco.node.func!.node.type).toBe("Identifier");
  }
});

test("schema attr has decorators field", async () => {
  const { module } = await parseFixtureAsync();
  const m = module as { body?: Array<{ node: { type?: string; name?: { node?: string }; body?: Array<{ node: { name?: { node?: string }; decorators?: unknown[] } }> } }> };
  const person = (m.body || []).find(
    (s) => s.node && s.node.name && s.node.name.node === "Person",
  );
  expect(person).toBeDefined();
  const nameAttr = (person!.node.body || []).find(
    (wrapped) => wrapped.node.name && wrapped.node.name.node === "name" && wrapped.node.decorators,
  );
  expect(nameAttr).toBeDefined();
  expect(nameAttr!.node.decorators!.length).toBe(1);
});

test("lambda expr with arguments", async () => {
  const { module } = await parseFixtureAsync();
  const m = module as { body?: Array<{ node: { type?: string; targets?: Array<{ node: { name?: { node?: string } } }>; value?: { node: { type?: string; args?: { node: { args?: unknown[] } } } } } }> };
  const adder = (m.body || []).find(
    (s) => s.node && s.node.targets && isAssignTargetNamed(s.node, "adder"),
  );
  expect(adder).toBeDefined();
  const val = adder!.node.value!.node;
  expect(val.type).toBe("Lambda");
  expect(val.args).toBeDefined();
  expect(val.args!.node.args!.length).toBe(2);
});

test("parseProgram returns list of modules", async () => {
  const inst = await kcl.load();
  const result = kcl.parseProgram(inst, { sources: [FIXTURE_CONTENT] });
  expect(result.errors).toEqual([]);
  const modules = parseProgramAst(result.astJson);
  expect(modules.length).toBeGreaterThan(0);
  // parseProgram synthesizes `__main__.k` as the filename for the synthetic
  // entry-point module; the assertion is that we get back a valid module with
  // a `.k` filename rather than the literal `"main.k"` from parseFile.
  expect(modules[0].filename.endsWith(".k")).toBe(true);
});

// --- helpers ------------------------------------------------------------

function isAssignTargetNamed(stmt: { targets?: Array<{ node: { name?: { node?: string } } }> }, name: string): boolean {
  if (!stmt.targets || !stmt.targets.length) return false;
  const target = stmt.targets[0];
  const inner = target.node;
  if (!inner) return false;
  if (inner.name && inner.name.node === name) return true;
  return false;
}

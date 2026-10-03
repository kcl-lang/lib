// ast_contract.test.ts — The AST wire contract, asserted.
//
// The typed AST in `src/ast/` is a hand-written decoder for the JSON the KCL
// parser emits, and a wrong guess about that JSON fails *silently*: an object
// with no `type` key decodes to `undefined` rather than throwing, so a binding
// that keys the `Type` registry on `"Int"` instead of `"Basic"` still returns
// a plausible-looking tree full of empty types.
//
// These tests decode `testdata/ast/alignment.json` — the real parser's output
// for `testdata/ast/alignment.k`, which exercises every node shape — and
// assert the contract documented in that directory's README. Decoding the
// captured JSON rather than calling `parseFile` keeps this a pure test of the
// loader: no WASM instantiation, and no dependency on parser output staying
// byte-identical.

import { expect, test } from "@jest/globals";
import { readFileSync } from "fs";
import { join } from "path";

import {
  parseModule,
  exprFromWire,
  stmtFromWire,
  typeFromWire,
  targetFromWire,
  configEntryFromWire,
  checkFromWire,
  callExprFromWire,
  compClauseFromWire,
  schemaIndexSignatureFromWire,
  keywordFromWire,
  argumentsFromWire,
  memberOrIndexFromWire,
  identifierFromWire,
  commentFromWire,
} from "../src/ast";

const GOLDEN = join(__dirname, "..", "..", "testdata", "ast", "alignment.json");

// The loaders return `unknown` for the polymorphic trees — a discriminated
// union would be the alternative, but the point of these tests is the wire
// shape, not the static type, so the assertions read better untyped.
type Any = any;

const wire = JSON.parse(readFileSync(GOLDEN, "utf8"));
const mod = parseModule(JSON.stringify(wire));
const stmts: Any[] = (mod.body || []).map((s: Any) => s.node);

/** The top-level statement whose assignment target is `name`. */
function assigned(name: string): Any {
  return stmts.find((s) => s.type === "Assign" && s.targets?.[0]?.node?.name?.node === name);
}

/** The top-level schema named `name`. */
function schema(name: string): Any {
  return stmts.find((s) => s.type === "Schema" && s.name?.node === name);
}

/** The top-level type alias named `name`. */
function typeAlias(name: string): Any {
  return stmts.find((s) => s.type === "TypeAlias" && s.typeName?.node?.names?.[0]?.node === name);
}

// --- Every tag is produced ---------------------------------------------

test("every Stmt variant decodes", () => {
  for (const tag of ["TypeAlias", "Unification", "Assign", "AugAssign", "Assert", "If", "Import", "Rule"]) {
    expect(stmts.some((s) => s.type === tag)).toBe(true);
  }
  expect(schema("Person")).toBeTruthy();
  expect(schema("Person").body.some((b: Any) => b.node.type === "SchemaAttr")).toBe(true);
  expect(stmts.some((s) => s.type === "Expr")).toBe(true);
});

test("every tagged Expr variant decodes", () => {
  // `Target`, `CompClause`, `Check`, `Keyword` and `Arguments` are absent on
  // purpose: they are plain structs, so the wire carries no tag for them and
  // they are decoded through their DTO loaders instead. `Target` in
  // particular only ever appears as an assignment target.
  const seen = new Set<string>();
  const walk = (o: Any) => {
    if (o === null || typeof o !== "object") return;
    if (Array.isArray(o)) return o.forEach(walk);
    if (typeof o.type === "string") seen.add(o.type);
    Object.values(o).forEach(walk);
  };
  walk(stmts);

  for (const tag of [
    "Identifier", "Unary", "Binary", "If", "Selector", "Call", "Paren",
    "Quant", "List", "ListIfItem", "ListComp", "Starred", "DictComp",
    "ConfigIfEntry", "Schema", "Config", "Lambda", "Subscript", "Compare",
    "NumberLit", "StringLit", "NameConstantLit", "JoinedString", "FormattedValue",
  ]) {
    expect(seen.has(tag)).toBe(true);
  }
});

test("every Type variant decodes", () => {
  const types = ["TAny", "TList", "TDict", "TUnion", "TFunc", "TNamed", "TLitInt", "TBasic"];
  const kinds = types.map((n) => typeAlias(n).ty.node.type);
  expect([...new Set(kinds)].sort()).toEqual(
    ["Any", "Basic", "Dict", "Function", "List", "Literal", "Named", "Union"],
  );
});

// --- The three serde shapes --------------------------------------------

test('Type is tag + content, so a basic type is {"type":"Basic","value":"Int"}', () => {
  // The trap: the tag names the *shape*, not the type. Keying a registry on
  // `"Int"` / `"Str"` silently yields no type at all.
  const basic = typeAlias("TBasic").ty.node;
  expect(basic.type).toBe("Basic");
  expect(basic.name).toBe("Str");

  expect(typeFromWire({ type: "Any" })).toEqual({ type: "Any" });
  expect(typeFromWire({ type: "Basic", value: "Int" })).toEqual({ type: "Basic", name: "Int" });
  expect((typeFromWire({ type: "Basic", value: 42 }) as Any).name).toBe("");
});

test('Type payloads nest under "value"', () => {
  const list = typeAlias("TList").ty.node;
  expect(list.type).toBe("List");
  expect(list.innerType.node.name).toBe("Int");

  const dict = typeAlias("TDict").ty.node;
  expect(dict.keyType.node.name).toBe("Str");
  expect(dict.valueType.node.name).toBe("Int");

  const union = typeAlias("TUnion").ty.node;
  expect(union.type).toBe("Union");
  expect(union.types.map((x: Any) => x.node.name)).toEqual(["Int", "Str"]);

  const fn = typeAlias("TFunc").ty.node;
  expect(fn.type).toBe("Function");
  expect(fn.paramsTy.map((p: Any) => p.node.name)).toEqual(["Int", "Str"]);
  expect(fn.retTy.node.name).toBe("Bool");

  const named = typeAlias("TNamed").ty.node;
  expect(named.identifier.names.map((n: Any) => n.node).join(".")).toBe("Cloud");
});

test("LiteralType is itself tagged, so the payload is doubly nested", () => {
  const lit = typeAlias("TLitInt").ty.node;
  expect(lit.type).toBe("Literal");
  expect(lit.innerTag).toBe("Int");
  expect(lit.value.value.value).toBe(1);
  expect(lit.value.value.suffix).toBeNull();
});

test("an unrecognised Type tag degrades instead of throwing", () => {
  expect(typeFromWire({ type: "Void", value: null })).toEqual({
    type: "Unknown",
    tag: "Void",
    value: null,
  });
});

test("Expr and Stmt newtype variants are flattened, not wrapped", () => {
  // `Expr::Identifier(Identifier)` is `{"type":"Identifier","names":[...]}`
  // — there is no `identifier` wrapper key. Reading through one yields an
  // empty identifier, silently.
  const paren = assigned("paren");
  const ident = paren.value.node.expr.node;
  expect(ident.type).toBe("Identifier");
  expect(ident.names[0].node).toBe("a");

  // Same for `Expr::Target(Target)`, `Expr::Check`, `Expr::Keyword`,
  // `Expr::Arguments` and `Expr::CompClause`.
  expect((targetFromWire(assigned("a").targets[0].node) as Any).name.node).toBe("a");
  expect(assigned("quant").value.node.target.node.type).toBe("Identifier");
  expect(assigned("call").value.node.keywords[0].node.arg.node.names).toBeTruthy();
});

test("NumberLit.value is a nested tagged object, not a bare number", () => {
  const num = assigned("lit_int").value.node;
  expect(num.type).toBe("NumberLit");
  expect(num.value.type).toBe("Int");
  expect(num.value.value).toBe(1);
  expect(assigned("lit_float").value.node.value.type).toBe("Float");
});

// --- Per-statement field names -----------------------------------------

test('ImportStmt is flat: path plus plain strings, no "node" wrapper', () => {
  const imports = stmts.filter((s) => s.type === "Import");
  const imp = imports[0];
  expect(imp.path.node).toBe("data.cloud");
  expect(imp.rawpath).toBe("data.cloud");
  expect(imp.name).toBe("cloud");
  expect(imp.pkgName).toBe("__main__");
  expect(imp.asname).toBeUndefined();

  expect(imports[1].asname.node).toBe("fb");
});

test("AugAssign takes a singular target, Assign a plural one", () => {
  const aug = stmts.find((s) => s.type === "AugAssign");
  expect(aug.target.node.name.node).toBe("a");
  expect(aug.op).toBe("Add");
  expect(aug.value.node.value.value).toBe(2);
  expect(assigned("a").targets.length).toBeGreaterThanOrEqual(1);
});

test("UnificationStmt wraps a SchemaExpr, not a bespoke config DTO", () => {
  const uni = stmts.find((s) => s.type === "Unification");
  expect(uni.target.node.names[0].node).toBe("u");
  // `SchemaExpr` is a plain struct, so it arrives with no `"type":"Schema"`
  // tag here and has to be decoded by `schemaExprFromWire` directly.
  expect(uni.value.node.name.node.names[0].node).toBe("Person");
});

test("AssertStmt carries test / ifCond / msg", () => {
  const asserts = stmts.filter((s) => s.type === "Assert");
  expect(asserts[0].test.node.type).toBe("Compare");
  expect(asserts[0].ifCond).toBeUndefined();
  expect(asserts[1].ifCond.node.type).toBe("Identifier");
  expect(asserts[1].msg.node.value).toBe("a must be positive");
});

test("IfStmt branches are lists of statements, not one statement", () => {
  const stmt = stmts.find((s) => s.type === "If");
  expect(Array.isArray(stmt.body)).toBe(true);
  expect(stmt.body[0].node.type).toBe("Assign");
  expect(Array.isArray(stmt.orelse)).toBe(true);
  expect(stmt.orelse[0].node.type).toBe("Assign");
});

test("SchemaExpr.name is an Identifier, not an Expr", () => {
  const x = assigned("x");
  expect(x.value.node.type).toBe("Schema");
  expect(x.value.node.name.node.names[0].node).toBe("Person");
});

test("Selector.attr and Quant.variables are Identifiers", () => {
  // `x.name.deep` is a single dotted Identifier; a Selector only appears
  // once a subscript or a `?` breaks the chain.
  const sel = assigned("selector").value.node;
  expect(sel.type).toBe("Selector");
  expect(sel.value.node.type).toBe("Subscript");
  expect(sel.attr.node.names[0].node).toBe("name");
  expect(sel.hasQuestion).toBe(false);
  expect(assigned("optional").value.node.hasQuestion).toBe(true);
  expect(assigned("quant").value.node.variables[0].node.names[0].node).toBe("v");
});

test("Subscript carries lower / upper / step for a slice", () => {
  const plain = assigned("subscript").value.node;
  expect(plain.index.node).toBeTruthy();
  expect(plain.lower).toBeUndefined();

  const slice = assigned("subscript_slice").value.node;
  expect(slice.index).toBeUndefined();
  expect(slice.lower.node.value.value).toBe(0);
  expect(slice.upper.node.value.value).toBe(2);

  expect(assigned("subscript_step").value.node.step.node).toBeTruthy();
});

test("Lambda body is a list of statements and args are Identifiers", () => {
  const lam = assigned("lambda_expr").value.node;
  expect(lam.type).toBe("Lambda");
  expect(lam.args.node.args[0].node.names[0].node).toBe("p");
  expect(lam.returnTy.node.name).toBe("Int");
  expect(lam.body[0].node.type).toBe("Expr");
});

test("ListComp and DictComp generators are untagged CompClauses", () => {
  const lc = assigned("list_if").value.node;
  expect(lc.type).toBe("ListComp");
  const gen = lc.generators[0].node;
  expect(gen.targets[0].node.names[0].node).toBe("i");
  expect(gen.iter.node.type).toBe("Identifier");
  expect(gen.ifs[0].node.type).toBe("Compare");

  const dc = assigned("dict_comp").value.node;
  expect(dc.type).toBe("DictComp");
  // A DictComp has exactly one `entry: ConfigEntry` — not key/value/entry_key.
  expect(dc.entry.key.node.type).toBe("Identifier");
  expect(dc.entry.operation).toBe("Union");
});

// --- Flat DTOs ----------------------------------------------------------

test("SchemaStmt.checks are untagged Checks, not tagged Exprs", () => {
  const checks = schema("Person").checks.map((c: Any) => c.node);
  expect(checks[0].test.node.type).toBe("Compare");
  expect(checks[0].ifCond).toBeUndefined();
  expect(checks[1].ifCond.node.type).toBe("Identifier");
  expect(checks[1].msg.node.value).toBe("age must be a sane number");
});

test("a decorator is a CallExpr, not a bespoke Decorator DTO", () => {
  const nameAttr = schema("Person")
    .body.map((b: Any) => b.node)
    .find((a: Any) => a.type === "SchemaAttr" && a.name?.node === "name");
  expect(nameAttr.decorators.length).toBe(2);
  expect(nameAttr.decorators[0].node.func.node.type).toBe("Identifier");
  expect(nameAttr.decorators[0].node.func.node.names[0].node).toBe("deprecated");
  // The keyword arg is a Keyword whose `arg` is an Identifier.
  expect(nameAttr.decorators[1].node.keywords[0].node.arg.node.names[0].node).toBe("kwargs");
});

test("SchemaIndexSignature is a body statement, not a schema header", () => {
  const sig = schema("Bag").indexSignature.node;
  expect(sig.keyName.node).toBe("k");
  expect(sig.keyTy.node.name).toBe("Str");
  expect(sig.valueTy.node.name).toBe("Int");
  expect(sig.anyOther).toBe(false);
  expect(sig.value.node.value.value).toBe(0);
});

test("MemberOrIndex is tag + content and its value is a NodeRef", () => {
  const dotted = stmts.find(
    (s) => s.type === "Assign" && s.targets?.[0]?.node?.name?.node === "x" && s.targets[0].node.paths.length === 2,
  );
  const paths = dotted.targets[0].node.paths;
  expect(paths[0].type).toBe("Member");
  expect(paths[0].member.node).toBe("name");
  expect(paths[1].type).toBe("Member");
  expect(paths[1].member.node).toBe("deep");

  const indexed = stmts.find(
    (s) => s.type === "Assign" && s.targets?.[0]?.node?.paths?.some((p: Any) => p.type === "Index"),
  );
  expect(indexed.targets[0].node.paths[0].index.node).toBeTruthy();
});

test("ConfigEntry.isShorthand is a real boolean even when the key is absent", () => {
  // The wire omits `is_shorthand` when false (skip_serializing_if).
  const plain = assigned("config").value.node.items[0].node;
  expect(plain.isShorthand).toBe(false);
  const shorthand = assigned("config_shorthand").value.node.items[0].node;
  expect(shorthand.isShorthand).toBe(true);
  expect(shorthand.operation).toBe("Override");
});

test("Arguments keeps defaults and tyList aligned positionally", () => {
  const args = assigned("lambda_expr").value.node.args.node;
  expect(args.args.length).toBe(1);
  expect(args.defaults.length).toBe(1);
  expect(args.defaults[0]).toBeUndefined();
  expect(args.tyList[0].node.name).toBe("Int");
});

// --- Direct loader checks ----------------------------------------------

test("the DTO loaders round-trip the wire shape they are given", () => {
  expect(identifierFromWire({ names: [], pkgpath: "p", ctx: "Store" })!.ctx).toBe("Store");
  expect((targetFromWire({ name: { node: "a" }, paths: [], pkgpath: "" }) as Any).name.node).toBe("a");
  expect(keywordFromWire({ arg: { node: { names: [] } }, value: null })!.value).toBeUndefined();
  expect(argumentsFromWire({ args: [], defaults: [], ty_list: [] })!.args.length).toBe(0);
  expect(checkFromWire({ test: { node: {} }, if_cond: null, msg: null })!.msg).toBeUndefined();
  expect(callExprFromWire({ func: { node: {} }, args: [], keywords: [] })!.args.length).toBe(0);
  expect(compClauseFromWire({ targets: [], iter: null, ifs: [] })!.ifs.length).toBe(0);
  expect(schemaIndexSignatureFromWire({ key_name: null, any_other: false })!.keyName).toBeUndefined();
  expect(configEntryFromWire({ key: null, value: null, operation: "Union" })!.isShorthand).toBe(false);
  expect(memberOrIndexFromWire({ type: "Unknown" })).toEqual({});
});

test("an unrecognised Expr or Stmt tag is flagged rather than dropped", () => {
  expect(exprFromWire({ type: "Future" })).toEqual({ type: "Future", unknown: true });
  expect(stmtFromWire({ type: "Future" })).toEqual({ type: "Future", unknown: true });
  expect(exprFromWire({ names: [] })).toBeUndefined();
  expect(stmtFromWire(null)).toBeUndefined();
});

test("a Comment carries its text, not the object under `node`", () => {
  // `Module.comments` reads each element through `nodeFromWire`, which lifts
  // the `node` key before handing the element to `commentFromWire`. The
  // decoder was reading `w.node?.text` from that already-lifted payload — a
  // key that is not on it — so every one of the 33 comments in the tree
  // decoded to `''` and five position fields came back `undefined`, with
  // nothing raised anywhere. Position belongs to the Node, not to its payload.
  const comments: Any[] = mod.comments ?? [];
  expect(comments.length).toBe(33);

  const blank = comments.filter((c: Any) => c.node.text === "");
  expect(blank).toEqual([]);
  expect(comments.filter((c: Any) => c.filename === undefined)).toEqual([]);

  // Verbatim against the capture, not merely non-empty.
  comments.forEach((c: Any, i: number) => {
    expect(c.node.text).toBe(wire.comments[i].node.text);
  });
  expect(comments[0].node.text).toBe(
    "# Every AST node shape the language bindings model, in one file.",
  );

  // And the direction that has no defence: handed the wrapper by mistake, a
  // payload loader still returns `''` rather than raising.
  expect(commentFromWire(wire.comments[0] as Any)).toEqual({ text: "" });
  expect(commentFromWire({ text: "x" } as Any)).toEqual({ text: "x" });
});

import { expect, test } from "@jest/globals";
import { init, MemFS } from "@wasmer/wasi";
import * as kcl from "../src";

// Note: a MemFS instance cannot be shared by two WASM instances
// (@wasmer/wasi rejects the second `load()` with "recursive use of an
// object detected"), so every test builds its own sandbox.

async function loadWithMemFS(
  files: Record<string, string> = {}
): Promise<WebAssembly.Instance> {
  await init();
  const fs = new MemFS();
  for (const [path, content] of Object.entries(files)) {
    const dir = path.slice(0, path.lastIndexOf("/"));
    if (dir && dir !== "/") {
      try {
        fs.createDir(dir);
      } catch {
        // directory already exists
      }
    }
    const f = fs.open(path, { read: true, write: true, create: true });
    f.writeString(content);
    f.free();
  }
  return kcl.load({ fs });
}

test("run evaluates inline code and exposes raw results", async () => {
  const inst = await loadWithMemFS();
  const result = kcl.run(
    inst,
    'print("hello-log")\nperson = {name = "Alice", age = 18}'
  );
  expect(result.yamlResult).toBe("person:\n  name: Alice\n  age: 18");
  expect(JSON.parse(result.jsonResult)).toEqual({
    person: { name: "Alice", age: 18 },
  });
  expect(result.logMessage).toBe("hello-log\n");
  expect(result.errMessage).toBe("");
  expect(result.toObject()).toEqual({ person: { name: "Alice", age: 18 } });
});

test("get navigates dotted paths through maps and lists", async () => {
  const inst = await loadWithMemFS();
  const result = kcl.run(inst, "a = {b = {c = 42}}\nlist = [{v = 1}, {v = 2}]");
  expect(result.get("a.b.c")).toBe(42);
  expect(result.get("list.1.v")).toBe(2);
  expect(result.get("list.5.v")).toBeUndefined();
  expect(result.get("a.missing.path")).toBeUndefined();
  expect(result.get()).toEqual({
    a: { b: { c: 42 } },
    list: [{ v: 1 }, { v: 2 }],
  });
});

test("runFiles evaluates files from the sandbox filesystem", async () => {
  const inst = await loadWithMemFS({
    "/work/main.k": 'name = "from-file"\nreplicas = 2\n',
  });
  const result = kcl.runFiles(inst, ["/work/main.k"]);
  expect(result.get("name")).toBe("from-file");
  expect(result.get("replicas")).toBe(2);
});

test("runFiles accepts a single path string", async () => {
  const inst = await loadWithMemFS({ "/main.k": "a = 1\n" });
  expect(kcl.runFiles(inst, "/main.k").get("a")).toBe(1);
});

test("overrides rewrite values (the -O flag)", async () => {
  const inst = await loadWithMemFS();
  const result = kcl.run(inst, "a = 1", { overrides: ["a=99"] });
  expect(result.get("a")).toBe(99);
  expect(result.yamlResult).toBe("a: 99");
});

test("selectors filter the emitted result (the -S flag)", async () => {
  const inst = await loadWithMemFS();
  const result = kcl.run(inst, "a = 1\nb = 2", { selectors: ["b"] });
  expect(result.yamlResult).toBe("2");
  expect(result.get()).toBe(2);
});

test("args feed option() values (the -D flag)", async () => {
  const inst = await loadWithMemFS();
  const result = kcl.run(inst, 'who = option("who")', {
    args: ['who="kcl"'],
  });
  expect(result.get("who")).toBe("kcl");
});

test("format json emits JSON only", async () => {
  const inst = await loadWithMemFS();
  const result = kcl.run(inst, "a = 1", { format: "json" });
  expect(result.yamlResult).toBe("");
  expect(result.jsonResult).toBe('{"a": 1}');
  expect(result.get("a")).toBe(1);
});

test("format yaml keeps value access unavailable with a clear error", async () => {
  const inst = await loadWithMemFS();
  const result = kcl.run(inst, "a = 1", { format: "yaml" });
  expect(result.jsonResult).toBe("");
  expect(result.yamlResult).toBe("a: 1");
  expect(() => result.get("a")).toThrow(kcl.KclError);
  expect(() => result.get("a")).toThrow(/format "yaml"/);
});

test("compile errors raise KclError with the diagnostic code", async () => {
  const inst = await loadWithMemFS();
  let thrown: unknown;
  try {
    kcl.run(inst, "a = = 1");
  } catch (err) {
    thrown = err;
  }
  expect(thrown).toBeInstanceOf(kcl.KclError);
  expect((thrown as kcl.KclError).code).toBe("E1001");
  expect((thrown as Error).message).toContain("InvalidSyntax");
});

test("runtime errors raise KclError from err_message", async () => {
  const inst = await loadWithMemFS();
  let thrown: unknown;
  try {
    kcl.run(
      inst,
      "schema P:\n  age: int\n  check:\n    age > 0\n\np = P {age = -1}"
    );
  } catch (err) {
    thrown = err;
  }
  expect(thrown).toBeInstanceOf(kcl.KclError);
  expect((thrown as Error).message).toContain("Instance check failed");
});

test("settings files merge through LoadSettingsFiles", async () => {
  const inst = await loadWithMemFS({
    "/work/kcl.yaml":
      "kcl_cli_configs:\n  sort_keys: true\nkcl_options:\n  - key: who\n    value: from-settings\n",
  });
  // kcl_options from the settings file feed option(); sort_keys from the
  // settings file is applied to the emitted YAML.
  const result = kcl.run(inst, 'who = option("who")\nb = {z = 1, a = 2}', {
    settings: "/work/kcl.yaml",
    workDir: "/work",
  });
  expect(result.get("who")).toBe("from-settings");
  expect(result.yamlResult).toBe("b:\n  a: 2\n  z: 1\nwho: from-settings");
});

test("explicit options win over settings values", async () => {
  const inst = await loadWithMemFS({
    "/work/kcl.yaml": "kcl_options:\n  - key: who\n    value: from-settings\n",
  });
  const result = kcl.run(inst, 'who = option("who")', {
    settings: "/work/kcl.yaml",
    workDir: "/work",
    args: ['who="explicit"'],
  });
  expect(result.get("who")).toBe("explicit");
});

test("runFiles picks up files from settings", async () => {
  const inst = await loadWithMemFS({
    "/work/main.k": 'name = "settings-file"\n',
    "/work/kcl.yaml": "kcl_cli_configs:\n  files:\n    - /work/main.k\n",
  });
  const result = kcl.runFiles(inst, [], {
    settings: "/work/kcl.yaml",
    workDir: "/work",
  });
  expect(result.get("name")).toBe("settings-file");
});

test("run with code supersedes settings-provided files", async () => {
  const inst = await loadWithMemFS({
    "/work/main.k": 'name = "settings-file"\n',
    "/work/kcl.yaml":
      "kcl_cli_configs:\n  files:\n    - /work/main.k\nkcl_options:\n  - key: who\n    value: kept\n",
  });
  // The settings file lists /work/main.k, but inline code wins for the
  // program contents while the settings kcl_options still apply.
  const result = kcl.run(inst, 'who = option("who")\nmarker = "inline"', {
    settings: "/work/kcl.yaml",
    workDir: "/work",
  });
  expect(result.get("marker")).toBe("inline");
  expect(result.get("who")).toBe("kept");
  expect(result.get("name")).toBeUndefined();
});

test("includeSchemaTypePath exposes _type on schema instances", async () => {
  const inst = await loadWithMemFS();
  const result = kcl.run(
    inst,
    'schema Person:\n  name: str\n\nperson = Person {name = "Alice"}',
    { includeSchemaTypePath: true }
  );
  // The default (fullTypePath: false) rewrites _type to the bare schema
  // name, mirroring kcl-go's typeAttributeHook.
  expect(result.get("person._type")).toBe("Person");
  expect(result.get("person.name")).toBe("Alice");
});

test("validate checks data against a schema", async () => {
  const inst = await loadWithMemFS();
  const code =
    "schema Person:\n  name: str\n  age: int\n  check:\n    0 < age < 120";
  expect(kcl.validate(inst, code, '{"name": "Alice", "age": 10}', "json")).toBe(
    true
  );
  expect(
    kcl.validate(inst, code, '{"name": "Alice", "age": 200}', "json")
  ).toBe(false);
});

test("validate reports invalid KCL as a graceful false", async () => {
  const inst = await loadWithMemFS();
  expect(
    kcl.validate(inst, "schema Person:\n  name: str\n  check", '{"name": "x"}')
  ).toBe(false);
});

test("Kcl instance methods mirror the standalone functions", async () => {
  const inst = await loadWithMemFS({ "/main.k": "a = 7\n" });
  const facade = new kcl.Kcl(inst);
  expect(facade.run("a = 1").get("a")).toBe(1);
  expect(facade.runFiles(["/main.k"]).get("a")).toBe(7);
  expect(
    facade.validate("schema P:\n  name: str", '{"name": "x"}', "json")
  ).toBe(true);
});

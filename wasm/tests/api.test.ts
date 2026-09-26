import { expect, test } from "@jest/globals";
import { init, MemFS } from "@wasmer/wasi";
import * as kcl from "../src";

async function loadWithMemFS(
  files: Record<string, string> = {}
): Promise<{ inst: WebAssembly.Instance; fs: MemFS }> {
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
  const inst = await kcl.load({ fs });
  return { inst, fs };
}

test("ping echoes the value", async () => {
  const inst = await kcl.load();
  const result = kcl.ping(inst, { value: "hello" });
  expect(result.value).toBe("hello");
});

test("getVersion returns version information", async () => {
  const inst = await kcl.load();
  const result = kcl.getVersion(inst);
  expect(result.version).toMatch(/^\d+\.\d+\.\d+/);
  expect(result.checksum).not.toBe("");
  expect(result.gitSha).not.toBe("");
  expect(result.versionInfo).toContain("Version:");
});

test("parseProgram parses inline sources", async () => {
  const inst = await kcl.load();
  const result = kcl.parseProgram(inst, { sources: ["a = 1\nb = a"] });
  expect(result.errors).toEqual([]);
  expect(JSON.parse(result.astJson)).toBeTruthy();
});

test("parseFile parses a single file source", async () => {
  const inst = await kcl.load();
  const result = kcl.parseFile(inst, {
    path: "/mock/main.k",
    source: "schema Person:\n  name: str\n",
  });
  expect(result.errors).toEqual([]);
  expect(JSON.parse(result.astJson)).toBeTruthy();
});

test("listOptions lists option help from sources", async () => {
  const inst = await kcl.load();
  const result = kcl.listOptions(inst, {
    sources: [
      'option1 = option("option1", type="str", required=True, default="", help="option 1 help")\n',
    ],
  });
  expect(result.options).toHaveLength(1);
  expect(result.options[0].name).toBe("option1");
  expect(result.options[0].type).toBe("str");
  expect(result.options[0].required).toBe(true);
  expect(result.options[0].help).toBe("option 1 help");
});

test("lintPath reports unused imports from the sandbox filesystem", async () => {
  const { inst } = await loadWithMemFS({ "/test.k": "import math\n\na = 1\n" });
  const result = kcl.lintPath(inst, { paths: ["/test.k"] });
  expect(result.results).toEqual(["Module 'math' imported but unused"]);
});

test("lintPath reports missing files in the results", async () => {
  const inst = await kcl.load();
  const result = kcl.lintPath(inst, { paths: ["/no/such/file.k"] });
  expect(result.results[0]).toContain("Cannot find the kcl file");
});

test("renameCode returns the changed code", async () => {
  const inst = await kcl.load();
  const result = kcl.renameCode(inst, {
    packageRoot: "/mock/path",
    symbolPath: "a",
    sourceCodes: { "/mock/path/main.k": "a = 1\nb = a" },
    newName: "a2",
  });
  expect(result.changedCodes["/mock/path/main.k"]).toBe("a2 = 1\nb = a2");
});

test("getSchemaTypeMapping returns schema types from code", async () => {
  const inst = await kcl.load();
  const result = kcl.getSchemaTypeMapping(inst, {
    execArgs: { kCodeList: ["schema Person:\n  name: str\n  age: int = 18"] },
    schemaName: "Person",
  });
  const person = result.schemaTypeMapping["Person"];
  expect(person.type).toBe("schema");
  expect(person.schemaName).toBe("Person");
  expect(person.properties["name"].type).toBe("str");
  expect(person.properties["age"].default).toBe("18");
  expect(person.required).toEqual(["name", "age"]);
});

test("formatPath formats files in the sandbox filesystem", async () => {
  const { inst } = await loadWithMemFS({ "/fmt.k": "a   =   1\n" });
  const result = kcl.formatPath(inst, { path: "/fmt.k" });
  expect(result.changedPaths).toEqual(["/fmt.k"]);
});

test("overrideFile overrides files in the sandbox filesystem", async () => {
  const { inst } = await loadWithMemFS({ "/ovr.k": "a = 1\n" });
  const result = kcl.overrideFile(inst, {
    file: "/ovr.k",
    specs: ["a=2"],
  });
  expect(result.result).toBe(true);
  expect(result.parseErrors).toEqual([]);
});

test("loadSettingsFiles loads settings from the sandbox filesystem", async () => {
  const { inst } = await loadWithMemFS({
    "/kcl.yaml":
      "kcl_cli_configs:\n  strict_range_check: true\nkcl_options:\n  - key: app-name\n    value: kcl\n",
  });
  const result = kcl.loadSettingsFiles(inst, {
    workDir: "/",
    files: ["/kcl.yaml"],
  });
  expect(result.kclCliConfigs.strictRangeCheck).toBe(true);
  expect(result.kclOptions).toEqual([{ key: "app-name", value: '"kcl"' }]);
});

test("rename rewrites symbols in sandbox files", async () => {
  const { inst } = await loadWithMemFS({ "/main.k": "a = 1\nb = a\n" });
  const result = kcl.rename(inst, {
    packageRoot: "/",
    symbolPath: "a",
    filePaths: ["/main.k"],
    newName: "a2",
  });
  expect(result.changedFiles).toEqual(["/main.k"]);
});

test("loadPackage loads the semantic model", async () => {
  const inst = await kcl.load();
  const result = kcl.loadPackage(inst, {
    parseArgs: { sources: ["schema Person:\n  name: str\n"] },
    resolveAst: true,
  });
  expect(result.parseErrors).toEqual([]);
  expect(result.typeErrors).toEqual([]);
  expect(JSON.parse(result.program)).toBeTruthy();
});

test("listVariables lists variables from the sandbox filesystem", async () => {
  const { inst } = await loadWithMemFS({ "/vars.k": 'a = 1\nb = "s"\n' });
  const result = kcl.listVariables(inst, {
    files: ["/vars.k"],
    specs: ["a", "b"],
  });
  expect(result.parseErrors).toEqual([]);
  expect(result.unsupportedCodes).toEqual([]);
  expect(result.variables["a"][0].value).toBe("1");
  expect(result.variables["a"][0].opSym).toBe("=");
  expect(result.variables["b"][0].value).toBe('"s"');
  expect(result.variables["b"][0].opSym).toBe("=");
});

test("validateCode validates data against a schema", async () => {
  const inst = await kcl.load();
  const result = kcl.validateCode(inst, {
    code: "schema Person:\n  name: str\n  age: int\n  check:\n    0 < age < 120",
    data: '{"name": "Alice", "age": 10}',
  });
  expect(result.success).toBe(true);
});

test("validateCode reports invalid KCL as a graceful result", async () => {
  const inst = await kcl.load();
  const result = kcl.validateCode(inst, {
    code: "schema Person:\n  name: str\n  age: int\n  check: 0 < age < 120",
    data: '{"name": "Alice", "age": 10}',
  });
  expect(result.success).toBe(false);
  expect(result.errMessage).toMatch(/missing expression/);
});

test("updateDependencies reports it is not supported in the WASM build", async () => {
  const { inst } = await loadWithMemFS({
    "/proj/kcl.mod": '[package]\nname = "proj"\nversion = "0.1.0"\n',
  });
  expect(() => kcl.updateDependencies(inst, { manifestPath: "/proj" })).toThrow(
    /not supported in the WASM build/
  );
});

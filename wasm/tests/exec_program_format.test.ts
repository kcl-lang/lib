import { describe, expect, test } from "@jest/globals";
import { init, MemFS } from "@wasmer/wasi";

import { decodeExecProgramResult, execProgram, load } from "../src";
import { concatBytes, boolField, stringField } from "../src/protobuf";

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
  return load({ fs });
}

// Tests for the source-map fields introduced alongside kcl-lang/kcl#1546.
//
// The WASM binding gained a typed `execProgram()` helper (used by the
// high-level facade in `src/facade.ts`) alongside the regenerated
// `ExecProgramArgs` encoding; the legacy string-based `invokeKCLRun`
// entry point remains available for single-file runs with no options.
// The pure protobuf test below verifies the regenerated encoding wires
// up the new `errorFormat` (19) and `sourcemapOutput` (22) fields with
// the correct wire tags; the smoke test exercises the full WASM runtime
// to make sure end-to-end execution still works alongside the new
// field plumbing.

describe("ExecProgramArgs source-map fields", () => {
  test("stringField encodes errorFormat (19) with wire tag 0x9a 0x01", () => {
    const bytes = stringField(19, "sarif");
    expect(bytes.length).toBeGreaterThan(0);
    // Tag = (field << 3) | wire_type = (19 << 3) | 2 = 154 → varint 0x9a 0x01
    expect(bytes[0]).toBe(0x9a);
    expect(bytes[1]).toBe(0x01);
  });

  test("stringField encodes sourcemapOutput (22) with wire tag 0xb2 0x01", () => {
    const bytes = stringField(22, "/tmp/out.js.map");
    expect(bytes.length).toBeGreaterThan(0);
    // Tag = (22 << 3) | 2 = 178 → varint 0xb2 0x01
    expect(bytes[0]).toBe(0xb2);
    expect(bytes[1]).toBe(0x01);
  });

  test("stringField skips empty/undefined values to avoid wasting wire bytes", () => {
    expect(stringField(19, undefined).length).toBe(0);
    expect(stringField(22, "").length).toBe(0);
  });

  test("boolField encodes emit_attribute_metadata (21) with wire tag 0xa8 0x01", () => {
    const bytes = boolField(21, true);
    expect(bytes.length).toBe(3);
    // Tag = (21 << 3) | 0 = 168 → varint 0xa8 0x01, value 1.
    expect(bytes[0]).toBe(0xa8);
    expect(bytes[1]).toBe(0x01);
    expect(bytes[2]).toBe(1);
    expect(boolField(21, false).length).toBe(0);
  });

  // Smoke test: confirms the WASM runtime still loads and runs KCL code
  // alongside the regenerated protobuf bindings. Doesn't exercise the
  // new source-map fields directly — `invokeKCLRun` doesn't take
  // ExecProgramArgs — but guards against the binding going stale.
  test("invokeKCLRun still executes KCL through the WASM runtime", async () => {
    const { invokeKCLRun } = await import("../src");
    const inst = await load();
    const result = invokeKCLRun(inst, {
      filename: "test.k",
      source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
    });
    expect(result).toContain("Alice");
  });
});

describe("ExecProgramResult source-map decoding", () => {
  test("decodeExecProgramResult reads field 5 (sourcemap)", () => {
    // Hand-built ExecProgramResult: json_result (1), err_message (4) and
    // sourcemap (5), out of field order to prove the decoder dispatches
    // on the tag rather than positional decoding.
    const sourcemap = '{"version":3,"sources":["a.k"],"mappings":"AAAA"}';
    const buffer = concatBytes(
      stringField(5, sourcemap),
      stringField(1, '{"a": 1}'),
      stringField(4, "")
    );
    const out = decodeExecProgramResult(buffer);
    expect(out.jsonResult).toBe('{"a": 1}');
    expect(out.errMessage).toBe("");
    expect(out.sourcemap).toBe(sourcemap);
  });

  test("decodeExecProgramResult defaults sourcemap to empty", () => {
    const out = decodeExecProgramResult(stringField(1, "{}"));
    expect(out.sourcemap).toBe("");
  });

  // Requires the kcl.wasm runtime built from kcl-lang/kcl rev 65af68d,
  // which added Source Map v3 generation to ExecProgram.
  test("execProgram returns a Source Map v3 document when sourcemapOutput is set", async () => {
    const inst = await loadWithMemFS();
    const result = execProgram(inst, {
      kCodeList: ["a = 1\n"],
      sourcemapOutput: "/out.js.map",
    });
    expect(result.errMessage).toBe("");
    expect(result.sourcemap).not.toBe("");
    const map = JSON.parse(result.sourcemap);
    expect(map.version).toBe(3);
    expect(map).toHaveProperty("mappings");
  });
});

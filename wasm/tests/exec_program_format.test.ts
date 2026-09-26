import { describe, expect, test } from "@jest/globals";

import { load } from "../src";
import { stringField } from "../src/protobuf";

// Tests for the source-map fields introduced alongside kcl-lang/kcl#1546.
//
// The WASM binding exposes the `ExecProgramArgs` interface but no typed
// `execProgram()` helper — KCL execution in WASM goes through
// `invokeKCLRun` (single file, no source-map options). The pure
// protobuf test below verifies the regenerated encoding wires up the
// new `errorFormat` (19) and `sourcemapOutput` (22) fields with the
// correct wire tags; the smoke test exercises the full WASM runtime
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
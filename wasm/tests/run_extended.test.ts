import { expect, test } from "@jest/globals";
import {
  load,
  invokeKCLRunWithLogMessage,
  invokeKCLVersion,
  invokeKCLCall,
} from "../src";

test("run with log message", async () => {
  const inst = await load();
  const result = invokeKCLRunWithLogMessage(inst, {
    filename: "test.k",
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  expect(result).not.toContain("ERROR:");
  expect(result).toContain("name: Alice");
});

test("version returns a non-empty string", async () => {
  const inst = await load();
  const v = invokeKCLVersion(inst);
  expect(v).not.toBe("");
  expect(v).toMatch(/^\d+\.\d+\.\d+/);
});

test("call dispatches to Ping", async () => {
  const inst = await load();
  // PingArgs: empty message, PingResult: { value: string }
  // Protobuf wire format: field 1 (string) tag=0x0a; with empty value, no payload.
  const args = "";
  const result = invokeKCLCall(inst, {
    methodName: "KclService.Ping",
    args,
  });
  // An empty PingArgs encodes as zero bytes; the PingResult should
  // round-trip without producing an "ERROR:" prefix.
  expect(result).not.toMatch(/^ERROR:/);
});

test("call dispatches to ParseProgram with simple source", async () => {
  const inst = await load();
  // ParseProgramArgs.sources = ["a = 1"]  (field 2, repeated string).
  // Wire format: tag=0x12 (field 2 << 3 | wire type 2), length=5, "a = 1".
  const tag = new Uint8Array([0x12, 0x05]);
  const payload = new TextEncoder().encode("a = 1");
  const argsBytes = new Uint8Array(tag.length + payload.length);
  argsBytes.set(tag, 0);
  argsBytes.set(payload, tag.length);
  const args = new TextDecoder().decode(argsBytes);
  const result = invokeKCLCall(inst, {
    methodName: "KclService.ParseProgram",
    args,
  });
  expect(result).not.toMatch(/^ERROR:/);
});

test("call reports an error for unknown method", async () => {
  const inst = await load();
  const result = invokeKCLCall(inst, {
    methodName: "KclService.NotARealMethod",
    args: "",
  });
  expect(result).toMatch(/^ERROR:/);
});
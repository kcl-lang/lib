import { expect, test } from "@jest/globals";
import { load, invokeKCLRun } from "../src";

// Regression test for the runtime-error buffer size. Prior to the bump
// from 1024 to 4096 bytes, any KCL error whose rendered message exceeded
// 1 KiB was silently truncated when the WASM module trapped. We assert
// here that a long error message is delivered intact.
//
// We construct a type error where the offending literal is ~2 KiB long;
// KCL's type checker includes the literal in the error message, so the
// total rendered message comfortably exceeds the previous 1 KiB limit.
test("runtime error buffer is at least 4 KiB and not truncated", async () => {
  const longLiteral = "x".repeat(2048);
  const inst = await load();
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `value: int = "${longLiteral}"\n`,
  });
  // The run fails with an error message; the "ERROR:" prefix should be
  // preserved and the rest of the message should still be intact.
  expect(result.startsWith("ERROR:")).toBe(true);
  // The rendered error must contain enough of the long literal that it
  // clearly was not truncated to the previous 1 KiB limit. We use
  // 1500 bytes as a safe threshold that fits comfortably inside 4 KiB.
  expect(result.length).toBeGreaterThan(1500);
  // The full long literal should appear in the message.
  expect(result).toContain(longLiteral);
});

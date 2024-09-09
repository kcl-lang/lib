import { expect, test } from "@jest/globals";
import { load, invokeKCLRun } from "../src";

test("run", async () => {
  const inst = await load();
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  expect(result).toBe("p:\n  name: Alice");
});

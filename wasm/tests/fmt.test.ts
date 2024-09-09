import { expect, test } from "@jest/globals";
import { load, invokeKCLFmt } from "../src/";

test("fmt", async () => {
  const inst = await load();
  const result = invokeKCLFmt(inst, {
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  expect(result).toBe(`schema Person:
    name: str

p = Person {name = "Alice"}
`);
});

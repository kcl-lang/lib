import { expect, test } from "@jest/globals";
import { load, invokeKCLRun } from "../src";

test("run parse error test", async () => {
  const inst = await load();
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `
a =
`,
  });
  expect(result).toBe(`ERROR:error[E1001]: InvalidSyntax
---> File test.k:2:4: expected one of ["identifier", "literal", "(", "[", "{"] got newline


error[E1001]: InvalidSyntax
---> File test.k:2:4: expected one of ["identifier", "literal", "(", "[", "{"] got newline

`);
});

test("run type error test", async () => {
  const inst = await load();
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `
a: str = 1
`,
  });
  expect(result).toBe(`ERROR:
error[E2G22]: TypeError
---> File test.k:2:1: expected str, got int(1)

`);
});

test("run runtime error test", async () => {
  const inst = await load();
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `
a = [][0]
`,
  });
  expect(result).toBe("ERROR:list index out of range: 0");
});

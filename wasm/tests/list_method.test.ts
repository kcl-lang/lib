import { expect, test } from "@jest/globals";

import { builtinPing, listMethod, load } from "../src";

test("listMethod returns the registered RPC method names", async () => {
  const inst = await load();
  const result = listMethod(inst);
  expect(result.methodNameList.length).toBeGreaterThan(0);
  expect(result.methodNameList).toContain("KclService.ExecProgram");
  expect(result.methodNameList).toContain("BuiltinService.ListMethod");
});

test("builtinPing echoes the value over BuiltinService", async () => {
  const inst = await load();
  const result = builtinPing(inst, { value: "hello" });
  expect(result.value).toBe("hello");
});

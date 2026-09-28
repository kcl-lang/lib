import { expect, test } from "@jest/globals";

import { formatCode, load } from "../src";

test("formatCode formats inline source via the typed FormatCode RPC", async () => {
  const inst = await load();
  const result = formatCode(inst, { source: "a   =   1" });
  expect(new TextDecoder().decode(result.formatted)).toBe("a = 1\n");
});

test("formatCode leaves well-formatted source unchanged", async () => {
  const inst = await load();
  const source = "schema Person:\n    name: str\n";
  const result = formatCode(inst, { source });
  expect(new TextDecoder().decode(result.formatted)).toBe(source);
});

test("formatCode reports unparsable source as a graceful result", async () => {
  const inst = await load();
  // The runtime echoes the offending snippet back instead of trapping; the
  // typed wrapper must surface it as a normal (non-throwing) result.
  const result = formatCode(inst, { source: "a = =" });
  expect(new TextDecoder().decode(result.formatted)).toContain("a = =");
});

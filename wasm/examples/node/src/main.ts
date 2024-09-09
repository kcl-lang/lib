import { load, invokeKCLRun, invokeKCLFmt } from "@kcl-lang/wasm-lib";

async function run() {
  const inst = await load();
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  console.log(result);
}

async function fmt() {
  const inst = await load();
  const result = invokeKCLFmt(inst, {
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  console.log(result);
}

run();
fmt();

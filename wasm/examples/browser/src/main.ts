import { load, invokeKCLRun, invokeKCLFmt } from "@kcl-lang/wasm-lib";

const inst = await load();

async function main() {
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  console.log(result);
  const fmtResult = invokeKCLFmt(inst, {
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  console.log(fmtResult);
}

main();

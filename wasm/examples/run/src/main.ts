import { load, invokeKCLRun } from '@kcl-lang/wasm-lib'

async function main() {
  const inst = await load();
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  console.log(result)
}

main()

import {
  load,
  invokeKCLRun,
  invokeKCLFmt,
  invokeKCLRunWithLogMessage,
  invokeKCLVersion,
  invokeKCLCall,
} from "@kcl-lib/wasm";

const SOURCE = `
schema Person:
  name: str

p = Person {name = "Alice"}`;

async function main() {
  const inst = await load();

  console.log("--- run ---");
  console.log(invokeKCLRun(inst, { filename: "test.k", source: SOURCE }));

  console.log("--- fmt ---");
  console.log(invokeKCLFmt(inst, { source: SOURCE }));

  console.log("--- run with log message ---");
  console.log(
    invokeKCLRunWithLogMessage(inst, { filename: "test.k", source: SOURCE })
  );

  console.log("--- version ---");
  console.log(invokeKCLVersion(inst));

  console.log("--- call KclService.Ping ---");
  // PingArgs{value: "hello-kcl"}: field 1 (string) tag 0x0a, length 9.
  const pingArgs = "\x0a\x09hello-kcl";
  console.log(
    invokeKCLCall(inst, { methodName: "KclService.Ping", args: pingArgs })
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
